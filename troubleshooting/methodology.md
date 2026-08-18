# Troubleshooting Methodology

Tools are not a method. Follow this order every time — it keeps you from rabbit-holing and it's what
separates a 10-minute fix from a 2-hour one.

---

## The 4 steps

### 1. Scope it before you touch it

Most "Intune bugs" are not bugs — they're scope, license, or network. Before opening a single log,
answer:

- **One device or many?** (A fleet-wide pattern points to policy/assignment; one device points to
  that device.)
- **Is the user licensed?** (Intune/M365 license assigned.)
- **Is the user in MDM scope?** (`Entra > Mobility (MDM and MAM) > MDM user scope`.)
- **Is the assignment correct?** (Right group, right include/exclude filters, right intent. Allow up
  to ~30 min for filter evaluation to show.)
- **Are the required network endpoints reachable?** (`*.manage.microsoft.com`, Entra,
  `*.microsoftaik.azure.net` for TPM.)

### 2. Force a sync, then read the *right* log

Pick the channel first (see [`../docs/01-fundamentals.md`](../docs/01-fundamentals.md)):

- **Profiles / CSPs / compliance / enrollment** → Event Viewer,
  `DeviceManagement-Enterprise-Diagnostics-Provider`.
- **Win32 apps / scripts / remediations** → IME logs (`AppWorkload.log`,
  `IntuneManagementExtension.log`, `AgentExecutor.log`), read with CMTrace.
- **EPM / device inventory / resource access** → remember MMP-C exists (a *second* enrollment with
  its own 4-hour clock).

Then force a sync so you're reading fresh data:
Company Portal → **Sync** (triggers both channels), or
`Settings > Accounts > Access work or school > Info > Sync`.

> The admin center's **Sync** action triggers the **MDM channel only** — it does **not** force the
> IME. To force the IME, restart the `IntuneManagementExtension` service.

### 3. Translate the code, find the *root cause*

- Convert the portal decimal → hex, look it up
  ([`error-code-reference.md`](error-code-reference.md), or
  [`../scripts/Decode-IntuneErrorCode.ps1`](../scripts/Decode-IntuneErrorCode.ps1)).
- **Check for a conflict before you blame the policy.** Two profiles fighting over one setting is one
  of the most common causes; the CSP `Result` path (or the portal Conflict state) shows who won.

### 4. Re-stage if you pass ~2 hours (single device only)

If **one** device keeps fighting you past about two hours, wipe and re-enroll it. Your time is worth
more than one stubborn machine. (For a **fleet-wide** problem, keep digging — re-staging one device
proves nothing.)

---

## Decode an error code fast

Most codes aren't random — read the **family** and jump straight to the area:

| Family | Area |
| --- | --- |
| `0x8018xxxx` | Enrollment / MDM (MENROLL). Look at Event **76**. |
| `0x87D1xxxx` | A Win32 app (e.g. `0x87D1041C` = installed but not detected). |
| `0x80072Fxx` | WinHTTP / certificate / TLS. Sync & check-in problems. |
| `0x800705b4` | A timeout — usually TPM attestation or ESP running past its limit. |

For configuration **profiles**, the rule is `0x87D10000 + <SyncML status>`. So `0x87D10194` →
`0x194` = 404 = CSP node not found.

Plain-English text for any Win32 / HRESULT code, in PowerShell:

```powershell
[ComponentModel.Win32Exception]0x80070005   # -> Access is denied
```

---

## Pitfalls that waste hours (learn these once)

- **Reading the wrong log.** A profile problem is never in the app log. Pick the channel first.
- **Confusing the two certificates.** `MS-Organization-Access` (Entra identity) vs
  `Microsoft Intune MDM Device CA` (management channel). They fail independently.
- **Trusting "Last check-in."** It can look healthy while a cert has already expired. Verify the
  cert, not the timestamp.
- **Fixing a Win32 app and expecting an instant retry.** The GRS cooldown (~24h) means nothing
  happens until the window passes. Clear it on a test device or wait.
- **Forgetting the 32-bit context.** IME scripts run in a 32-bit host by default; `HKLM\SOFTWARE\...`
  writes land in `WOW6432Node`. Use the 64-bit host option or `Sysnative`.
- **Hardening baselines that disable `dmwappushservice`.** That silently stops all MDM sync.
- **Forgetting MMP-C exists.** For EPM / inventory / Wi-Fi-VPN issues, there's a second enrollment
  now, with its own logs and clock.
- **Chasing one device forever.** Past two hours on a single machine, re-stage it.
