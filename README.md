# Intune Knowledge Base & Troubleshooting Runbook

A personal, field-oriented knowledge base for **Microsoft Intune** device management and
enrollment troubleshooting. It is built to be a working reference you can open mid-incident:
understand the concept, find the right log, decode the error, apply the fix, and record the case
for next time.

> **Scope:** Windows is the primary focus (the platform that generates the most tickets), with
> notes on iOS/iPadOS, Android, and macOS where relevant. Content reflects the Intune service as
> of mid-2026, including newer plumbing such as **MMP-C / Windows Declared Configuration**.

> **Disclaimer:** This is an independent, community-oriented reference. It is *not* official
> Microsoft documentation. Product internals (registry layouts, enrollment "type" numbers, some
> MMP-C behavior) were reverse-engineered by the community and shift between Windows builds —
> always verify against your own build before acting fleet-wide. Where an official Microsoft Learn
> page exists, it is the source of truth.

---

## How to use this repo

There are three ways in, depending on what you need right now:

1. **Learning the platform** → start in [`docs/`](docs/). Read `01-fundamentals.md` first; it
   explains the two management channels that make everything else make sense.
2. **Fixing a live problem** → go straight to [`troubleshooting/`](troubleshooting/). Start with
   [`methodology.md`](troubleshooting/methodology.md), then jump to the symptom-specific runbook.
3. **Looking up an error code** → open
   [`troubleshooting/error-code-reference.md`](troubleshooting/error-code-reference.md).

For recurring or nasty cases, copy [`templates/case-runbook-template.md`](templates/case-runbook-template.md)
into a new file and log the case so future-you doesn't start from zero.

---

## The one mental model to internalize first

On Windows, Intune talks to a device over **two separate channels** that barely know about each
other. Almost every confused troubleshooting session comes from not knowing which channel owns the
setting you're chasing:

| Channel | Carries | Where you troubleshoot it |
| --- | --- | --- |
| **Native MDM channel** (OMA-DM → CSPs) | Configuration profiles, compliance, certificates, Wi-Fi/VPN | **Event Viewer** → `DeviceManagement-Enterprise-Diagnostics-Provider` |
| **Intune Management Extension (IME)** | Win32 apps, PowerShell scripts, remediations | **IME logs** → `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\` |

A **third** channel is now rolling out on modern devices — **MMP-C / Declared Configuration** —
which carries Endpoint Privilege Management, advanced device inventory, and (increasingly) resource
access. See [`docs/09-mmpc-declared-config.md`](docs/09-mmpc-declared-config.md).

> If a *configuration profile* is broken → MDM channel + Event Viewer.
> If a *Win32 app or a script* is broken → IME + its logs.
> Two problems, two places.

---

## Contents

### `docs/` — Knowledge base

| File | Topic |
| --- | --- |
| [`01-fundamentals.md`](docs/01-fundamentals.md) | How Intune works: the two channels, CSPs/OMA-DM, check-in cadence, MDM authority, licensing |
| [`02-enrollment-methods.md`](docs/02-enrollment-methods.md) | Enrollment methods across Windows / iOS / Android / macOS, ownership models, prerequisites |
| [`03-compliance-policies.md`](docs/03-compliance-policies.md) | Compliance engine, default policy, grace periods, evaluation cycles |
| [`04-configuration-profiles.md`](docs/04-configuration-profiles.md) | Settings Catalog, CSPs, OMA-URI, profile conflicts |
| [`05-app-deployment.md`](docs/05-app-deployment.md) | Win32 app lifecycle, detection rules, return codes, GRS retry, LOB & Store apps |
| [`06-conditional-access.md`](docs/06-conditional-access.md) | How CA consumes compliance, the compliance loop trap |
| [`07-autopilot-esp.md`](docs/07-autopilot-esp.md) | Autopilot phases, Enrollment Status Page, hybrid join fragility |
| [`08-identity-prt.md`](docs/08-identity-prt.md) | `dsregcmd`, the PRT, the two device certificates you must not confuse |
| [`09-mmpc-declared-config.md`](docs/09-mmpc-declared-config.md) | The new declarative channel and how to see it on a device |

### `troubleshooting/` — Runbooks

| File | Use when |
| --- | --- |
| [`methodology.md`](troubleshooting/methodology.md) | Always — the 4-step method that keeps you out of rabbit holes |
| [`log-locations.md`](troubleshooting/log-locations.md) | You need to know *which* log and *where* it lives |
| [`diagnostic-tools.md`](troubleshooting/diagnostic-tools.md) | You need to collect logs or decode something fast |
| [`error-code-reference.md`](troubleshooting/error-code-reference.md) | You have a hex/decimal code and need meaning + first fix |
| [`enrollment-errors.md`](troubleshooting/enrollment-errors.md) | A device fails to enroll |
| [`compliance-issues.md`](troubleshooting/compliance-issues.md) | A device is non-compliant for no obvious reason |
| [`app-deployment-errors.md`](troubleshooting/app-deployment-errors.md) | A Win32/LOB/Store app fails or reports wrongly |
| [`sync-checkin-issues.md`](troubleshooting/sync-checkin-issues.md) | A device stops syncing / stale check-in |
| [`script-remediation-issues.md`](troubleshooting/script-remediation-issues.md) | A platform script or remediation doesn't run |

### `scripts/` — PowerShell helpers

| Script | Purpose |
| --- | --- |
| [`Collect-IntuneDiagnostics.ps1`](scripts/Collect-IntuneDiagnostics.ps1) | Wrap `MdmDiagnosticsTool.exe` to gather a full diagnostic zip |
| [`Force-IntuneSync.ps1`](scripts/Force-IntuneSync.ps1) | Trigger both the MDM and IME channels |
| [`Get-DeviceIdentityState.ps1`](scripts/Get-DeviceIdentityState.ps1) | Parse `dsregcmd /status` into the fields that matter |
| [`Reset-Win32AppGRS.ps1`](scripts/Reset-Win32AppGRS.ps1) | **Test devices only** — clear the Win32 app retry cooldown |
| [`Decode-IntuneErrorCode.ps1`](scripts/Decode-IntuneErrorCode.ps1) | Convert a portal decimal / hex code to plain-English text |

### `templates/`

| File | Purpose |
| --- | --- |
| [`case-runbook-template.md`](templates/case-runbook-template.md) | A structured template for logging future cases |

---

## Quick reference card

**Force a full sync (device side):** `Settings > Accounts > Access work or school > Info > Sync`,
or **Company Portal > Sync** (this triggers *both* channels; the portal's Sync action only triggers MDM).

**Collect logs, no user involvement:** `MdmDiagnosticsTool.exe -area "DeviceEnrollment;DeviceProvisioning;Autopilot" -zip "C:\Temp\MDMDiag.zip"`

**Check device identity:** `dsregcmd /status` — read *Device State*, *Device Details*, *SSO State*.

**Default check-in cadence:** MDM ~8 hours, IME on its own schedule, MMP-C ~4 hours — but a
targeted assignment or a manual Sync pushes a near-instant check-in via WNS.

**Admin center:** [intune.microsoft.com](https://intune.microsoft.com)

---

## License

Released under the [MIT License](LICENSE). Use it, fork it, adapt it for your own runbook.

## Contributing

This is primarily a personal reference, but corrections and additional real-world cases are
welcome. See [`CONTRIBUTING.md`](CONTRIBUTING.md).
