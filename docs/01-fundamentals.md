# 01 — Fundamentals: How Intune Actually Works

Understanding *how* a Windows device talks to Intune removes most of the guesswork from
troubleshooting. Once you know which channel owns a setting and how a device proves who it is, you
stop reading random logs and start reading the *right* one.

---

## The two management channels

On Windows there are two independent channels. They share almost nothing — different protocols,
different clocks, different logs.

### Channel 1 — Native MDM (OMA-DM → CSPs)

This is built into Windows. Intune sends commands using the **OMA-DM** protocol; the payload is
**SyncML** (an XML dialect). The device never receives raw registry keys. Instead, every setting
maps to a **Configuration Service Provider (CSP)** — a small Windows interface that knows how to
apply that one setting.

Everything that comes down this channel:

- Configuration profiles (Settings Catalog, templates, custom OMA-URI)
- Compliance policies
- Certificates, Wi-Fi, VPN
- Enrollment itself

Troubleshoot it in **Event Viewer**:
`Applications and Services Logs > Microsoft > Windows > DeviceManagement-Enterprise-Diagnostics-Provider > Admin`

### Channel 2 — Intune Management Extension (IME)

The IME (old name: "Sidecar" agent) is a real installed agent with its own Windows service
(`IntuneManagementExtension`) and **its own clock**, independent from the MDM check-in. It is
installed automatically the first time you assign any of:

- A Win32 app
- A PowerShell platform script
- A remediation (proactive remediation)
- A custom compliance script

Troubleshoot it in the IME logs:
`C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\`

### Channel 3 (emerging) — MMP-C / Declared Configuration

A newer declarative channel that runs *alongside* the classic one on modern devices. Covered in
[`09-mmpc-declared-config.md`](09-mmpc-declared-config.md). Mentioned here only so you know it
exists — increasingly, EPM, device inventory, and resource access ride on it, not on OMA-DM.

> **The single most useful habit:** decide which channel owns your problem *before* you open a log.
> A profile problem is never in the app log.

---

## How CSPs work (and why error codes look the way they do)

A CSP bridges the SyncML command Intune sends and the actual Windows setting. Commands target an
**OMA-URI** (also called a LocURI) — a path like:

```
./Device/Vendor/MSFT/Policy/Config/<Area>/<PolicyName>
```

The prefix sets the scope: `./Device` = device-targeted, `./User` = user-targeted. No prefix
defaults to device.

Each setting in a Settings Catalog profile becomes a SyncML command:

- `Replace` = set a value
- `Add` = create a node
- `Delete` = remove it — and note, **"Not configured" is literally a `Delete`**

The **Policy CSP** (the workhorse for most settings) has two paths worth knowing:

- **`Config`** — read/write, where Intune *sets* the value
- **`Result`** — read-only, where you read the *conflict-resolved* value the device actually applied

When two sources fight over a setting, the `Result` path tells you who won. This is why
**checking for a conflict** is a core troubleshooting step before blaming a policy.

---

## Check-in cadence — the "8-hour sync" myth

Microsoft states a maintenance check-in of roughly every 8 hours on the MDM channel; the IME
checks in on its own schedule; MMP-C refreshes about every 4 hours. **But you rarely wait that
long.** When you assign something or click Sync, Intune sends a **Windows Push Notification
Service (WNS)** notification that triggers a near-immediate check-in.

So "it takes 8 hours" is misleading — *targeted* changes push almost right away. Confirm this
before assuming something is broken.

On the device, enrollment creates scheduled tasks under:
`Task Scheduler Library > Microsoft > Windows > EnterpriseMgmt > {EnrollmentGUID}`

The key one is **PushLaunch**, which reacts to the WNS push and starts an OMA-DM session.

> A `LastTaskResult` of `0x82AC0204` on PushLaunch is **not** an error — it means "queued, will run
> later." Don't chase it.

---

## Estimated timing for assignments

| Action | Typical time to reach the device |
| --- | --- |
| Newly assigned policy/app after Sync or WNS push | Minutes |
| Passive MDM maintenance check-in | ~8 hours |
| MMP-C / Declared Configuration refresh | ~4 hours |
| Compliance re-evaluation | ~8 hours |
| Filter evaluation showing in admin center | Up to ~30 minutes |
| Drift to non-compliant after no check-in | ~30 days |

---

## MDM authority, scope, and licensing (the boring prerequisites that break everything)

Most "Intune bugs" are actually scope, license, or network problems. Confirm these first:

1. **License** — the user needs an Intune or Microsoft 365 license that includes Intune. Check in
   the Microsoft 365 admin center or Intune admin center.
2. **MDM user scope** — in `Microsoft Entra ID > Mobility (MDM and MAM) > Microsoft Intune`, the
   **MDM user scope** must be **All** or a group that includes the user. If it's **None**, Windows
   auto-enrollment silently won't happen.
3. **Enrollment restrictions** — `Devices > Enrollment > Enrollment restrictions`. Platform
   restrictions can block Windows (MDM) or personal devices; device-limit restrictions cap how many
   devices a user can enroll (default 15, sometimes surfaced as a lower effective cap).
4. **Network reachability** — the device must reach Intune endpoints (`*.manage.microsoft.com`),
   Entra, and (for TPM attestation) `*.microsoftaik.azure.net`. A proxy that inspects TLS on these
   breaks enrollment/attestation.

---

## Admin center and portals

- **Intune admin center:** `https://intune.microsoft.com`
- **Entra admin center:** `https://entra.microsoft.com`
- **Microsoft 365 admin center:** `https://admin.microsoft.com`

The naming has shifted over the years (Microsoft Endpoint Manager → Microsoft Intune admin center;
Azure AD → Microsoft Entra ID). Older docs use the old names; the underlying features are the same.

---

## Where to go next

- New to enrollment mechanics? → [`02-enrollment-methods.md`](02-enrollment-methods.md)
- Want the identity layer (why so many "Intune" problems are really identity)? →
  [`08-identity-prt.md`](08-identity-prt.md)
- Ready to troubleshoot? → [`../troubleshooting/methodology.md`](../troubleshooting/methodology.md)
