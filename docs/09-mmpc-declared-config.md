# 09 — MMP-C & Windows Declared Configuration

> **Heads-up:** On a modern, fully-patched Windows device there is now a **second enrollment**
> running quietly next to the classic one. Most admins have never heard of it, yet it's already on
> their devices. It increasingly owns Endpoint Privilege Management, advanced device inventory, and
> resource access — so it's now part of everyday troubleshooting.

> **Trust note:** The *desired-state model*, the *dedicated-enrollment requirement*, and the
> *refresh interval* are documented by Microsoft. The acronym expansion, the enrollment "type"
> numbers, the `*.dm.microsoft.com` host names, and the ~4-hour cadence were reverse-engineered by
> the community (primarily Rudy Ooms / call4cloud). This area changes fast between builds — verify
> against your own device before acting fleet-wide.

---

## What MMP-C is

**MMP-C** = *Microsoft Management Platform – Cloud*. It's a new cloud management plane that runs
**alongside** — not instead of — the classic Intune/OMA-DM channel. It exists to carry **Windows
Declared Configuration (WinDC)**, a new way of delivering policy.

### Imperative vs declarative — the whole point

- **Classic OMA-DM is imperative.** The server issues commands one at a time — get, set, get — and
  only checks the result at the next sync. If a setting drifts in between, nothing happens until the
  next check-in.
- **Declared Configuration is declarative and idempotent** (think Windows DSC). The server sends the
  *whole desired state* in one batch per scenario, the client validates it synchronously, and the
  **device itself** keeps it that way — non-destructively re-applying if it drifts. Same idea as
  Apple's declarative device management.

WinDC requires a **separate OMA-DM enrollment** that depends on the device already being enrolled in
a primary MDM server. So a managed device now has **two enrollments**: the classic one (the
"MS DM Server", using `*.manage.microsoft.com`) and a linked second one for Declared Configuration
(using `*.dm.microsoft.com` endpoints).

---

## What runs on it

The linked enrollment first appeared with **Endpoint Privilege Management (EPM)**, still the flagship
workload. The big change is **Windows Advanced Device Inventory (the Properties Catalog)** — because
that runs on MMP-C, the dual enrollment is now rolling out to effectively **all** managed devices
automatically. **Resource access policies** (Wi-Fi, VPN, certificates) are moving over too.

Microsoft has *signalled* that security baselines, Defender settings, and Account Protection are on
the same pipeline — but as of writing those are **not** confirmed generally available on the
Declared Configuration channel. Treat them as "coming, not here": if a baseline misbehaves today,
it's still travelling down the **classic OMA-DM channel**. Read the channel before you read the log.

---

## How to see it on a device

Confirm the second enrollment via the registry:

```
HKLM\SOFTWARE\Microsoft\Enrollments
```

You'll see **two enrollment GUIDs**:

- Under the classic Intune enrollment there's a `LinkedEnrollment` subkey with values like
  `EnrollStatus`, `LastError`, and `MMPCLocked`.
- The second GUID is the MMP-C enrollment itself, with its own folder under `EnterpriseMgmt` in Task
  Scheduler.

On the device the linked enrollment is named **`MicrosoftManagementPlatformCloud`** — that string in
the registry or a log confirms MMP-C is live.

**The engine:** the service `dcsvc` (backed by `dcsvc.dll`) processes Declared Configuration
documents. A scheduled task runs `deviceenroller.exe /DeclaredConfigurationRefresh` to reconcile
drift — by default about every **4 hours** (classic MDM is every 8). The interval is configurable via
`DeclaredConfiguration/ManagementServiceConfiguration/RefreshInterval`.

> **Logs:** Declared Configuration does **not** get its own Event Viewer log. Its events ride inside
> the normal `DeviceManagement-Enterprise-Diagnostics-Provider` channels — look for lines that say
> `MDM Declared Configuration:` or `Provider Name: (DeclaredConfiguration)`.

---

## Troubleshooting MMP-C

First confirm the second enrollment exists (registry above). If EPM works and its agent installed
within minutes, MMP-C enrolled fine.

Known failure modes (community-documented):

| Symptom | Likely cause |
| --- | --- |
| Second enrollment never starts; `0x80070002` (file not found); no dual-enrollment scheduled task | The `DiscoveryEndpoint` was never set, so `Enroll` ran with nothing to point at |
| `400 Invalid Request` | Tenant not onboarded to MMP-C |
| EPM fails with `2147749902` | A Device Health Monitoring policy failed (often a pre-Oct-2022 Windows build or missing DeviceHealthMonitoring registry keys), which blocks the whole thing |
| A Declared Configuration document fails to apply | In the Diagnostics-Provider log, a `MDM Declared Configuration:` line with `0x8000FFFF` (document-ID mismatch) or `0x86000002` (typo in an OMA-URI inside the document), plus the scenario name (e.g. `MSFTVPN`) |

---

## Why it matters going forward

The clear direction of travel is **from the imperative OMA-DM model to the declarative
MMP-C / Declared Configuration model**. Microsoft is steadily shifting workloads onto MMP-C — EPM
first, then device inventory, now resource access, with baselines and Defender signalled. Desired
state that the device enforces itself is simply more reliable than firing commands once and hoping
they stick. If you learn one new Intune internal this year, learn MMP-C.
