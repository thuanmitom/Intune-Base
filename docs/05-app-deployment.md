# 05 — App Deployment

Application deployment is the single most common source of Intune support tickets — it outpaces
compliance, enrollment, and profile issues by a wide margin. The reason: an app install has four
phases (download → decrypt/unpack → install → detect), each can fail independently, and the portal
error rarely tells you which one broke.

---

## App types (confirm the type first)

Different app types use different install mechanisms and fail in different ways. Always confirm the
type in `Apps > All apps` (the **Type** column) before troubleshooting.

| Type | Delivered by | Notes |
| --- | --- | --- |
| **Win32 app** (`.intunewin`) | **IME** | The most flexible and the most failure-prone. Detection rules decide success. |
| **Line-of-business (MSI)** | Native MDM (EnterpriseDesktopAppManagement CSP) | Simpler MSI-only; uses TrustedInstaller. |
| **Microsoft Store app** | Native MDM | Modern Store apps; offline-licensed variants useful for ESP/Autopilot. |
| **Managed Google Play / Apple VPP** | Platform connectors | Mobile app stores. |

---

## The Win32 app journey (`.intunewin`)

The `.intunewin` file is a ZIP encrypted by the Content Prep Tool (AES-256 CBC). The keys live in
`Detection.xml` inside the package — but they are **not shipped to the client inside the package**.
The IME receives the keys from the Intune service by policy when it requests the app, which is why
you can't just unzip a `.intunewin` and read it.

On the device:

1. **Download** — IME downloads the `.bin` to `Content\Incoming`.
2. **Verify & decrypt** — hash-check, then decrypt (the `.bin` layout is a 32-byte HMAC + 16-byte
   IV + ciphertext, so a decoder skips the first 48 bytes).
3. **Unpack** — to `C:\Windows\IMECache\<AppId>`.
4. **Install** — run your install command, capture the exit code.
5. **Detect** — re-run the **detection rule**. This is the source of truth for "installed or failed."

> The IME cleans the `IMECache` folder a few seconds after detection. If your installer is a wrapper
> that references files from that folder *after* detection, it fails with "source file not found."
> Fix: bundle all files inside the package and expand them yourself first.

The primary Win32 logs on current builds are `AppWorkload.log` (install detail) and
`AppActionProcessor.log` (detection/applicability), under
`C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\`.

---

## Detection rules — where most "failures" actually live

The **detection rule**, not the installer exit code, decides whether Intune reports success. The
classic error `0x87D1041C` means: **the installer returned success, but the detection rule did not
find the app afterward.** Almost always the detection rule is wrong:

- Wrong file path
- Wrong version operator/value
- Wrong registry value
- A mismatched MSI **ProductCode**

Fix the detection rule to match the *real* installed artifact, then clear GRS or wait out the
cooldown (below).

---

## Return codes — map them correctly

Any exit code **not** in the app's configured return-code list is treated as **Failed**. The classic
trap is a `3010` soft-reboot code that nobody mapped as success.

| Return code | Meaning in Intune |
| --- | --- |
| `0` | Success |
| `1707` | Success (legacy installer success code) |
| `3010` | **Soft reboot** — success; reboot batched (deferred until after the ESP). **Must be mapped as success.** |
| `1641` | **Hard reboot** — success; IME reboots the device immediately |
| `1618` | **Retry** — another installation is already running (TrustedInstaller busy); IME tries again later |

---

## The GRS retry trap

After a failed install, the IME does **not** keep retrying every check-in. It retries a failed app
**three times at five-minute intervals**, then locks it into the **Global Retry Schedule (GRS)** — a
roughly **24-hour cooldown** during which it skips the app on every sync.

So when you fix the detection rule and *nothing happens*, the app usually isn't broken — it's in its
cooldown window. This single fact prevents more wasted time than almost anything else.

To force an immediate retry **on a test device**, clear the IME's Win32 state and restart the
service — see [`../scripts/Reset-Win32AppGRS.ps1`](../scripts/Reset-Win32AppGRS.ps1). Clearing GRS
only resets the *retry timer*; it does **not** fix the underlying failure.

---

## Selected app error codes

**Win32 / IME (Windows):**

| Code | Meaning | First move |
| --- | --- | --- |
| `0x87D1041C` | Installed but detection rule didn't find it | Fix detection rule; mind GRS |
| `0x87D1FDE8` | Generic IME install failure / will retry | Fix detection; test install as SYSTEM; read `AppWorkload.log` |
| `0x87D300C9` | Unmonitored process in progress, may time out | Check install command/parameters |
| `0x87D300CD` | User logged off while the app policy was processing | Retry; consider device-context |
| `0x80073CF3` | Dependency / conflict / architecture mismatch | Check x86 vs x64, dependencies, existing version |
| `0x80073CF2` | Invalid package data | Repackage / verify the source |

**Apple (iOS/macOS VPP & managed apps):**

| Code | Meaning |
| --- | --- |
| `0x87D13B60` | Scheduled for install but needs a redemption code (user canceled) |
| `0x87D13B63` | User rejected the app update offer |
| `0x87D13B66` | App was managed but expired or removed by the user |
| `0x87D13B9F` | An app update is available (often shows "failed" though the app is installed) |
| `0x87D1077C` | App license failed to install (often offline Store-for-Business licensing) |

The canonical, always-current list is Microsoft's
**App installation error codes for Microsoft Intune** page on Microsoft Learn.

---

## Testing an install like the IME does

Win32 apps install in the **SYSTEM** context by default. To reproduce a failure the way IME sees it,
open a **SYSTEM** command prompt (e.g. via PsExec `-s`) and run the exact install command. If it
fails there, the problem is the installer/command line under SYSTEM — not Intune. If user
interaction is genuinely required, `serviceui.exe` can surface a prompt from SYSTEM into the user
session, but prefer silent installs.

For the full runbook, see
[`../troubleshooting/app-deployment-errors.md`](../troubleshooting/app-deployment-errors.md).
