# Log Locations — The Map

Pick the channel first, then the log. Everything for **apps and scripts** lives under one folder;
everything for **profiles, CSPs, and enrollment** lives in **Event Viewer**.

---

## IME logs (apps, scripts, remediations)

**Folder:** `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\`
**Best viewer:** CMTrace (ships with ConfigMgr) or the browser version at `cmtrace.dev` — colours
errors red and follows the file live.
**Rotation:** each file caps at ~3 MB, then rotates (renamed with a timestamp; a new file starts).
Newly-enrolled devices start with tiny logs that grow as apps/scripts/policies land.

| Log file | What it's for |
| --- | --- |
| `IntuneManagementExtension.log` | Main IME log: check-ins, policy requests, processing, reporting — the big picture |
| `AppWorkload.log` | Win32 app install detail (primary Win32 log on current builds, service release 2408+) |
| `AppActionProcessor.log` | Detection & applicability (requirement) checks |
| `AgentExecutor.log` | PowerShell platform-script & remediation execution, with output |
| `HealthScripts.log` | Remediation (proactive remediation) run detail |
| `Win32AppInventory.log` | Win32 app inventory collector |
| `Sensor.log` | Endpoint Analytics data collector |
| `ClientHealth.log` | Health of the IME agent itself |

> `AgentExecutor.exe` lives in `C:\Program Files (x86)\Microsoft Intune Management Extension` — note
> the **(x86)**: the IME is a 32-bit process, which is why scripts default to a 32-bit host.

> Remediation scripts are cached under `C:\Windows\IMECache\HealthScripts\<DeploymentID>`.

### Increasing IME log size (deep troubleshooting)

```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IntuneWindowsAgent\Logging
  LogMaxSize     (bytes)  – larger per-file size
  LogMaxHistory  (count)  – more archived files retained
```

---

## Event Viewer (profiles, CSPs, enrollment)

**MDM / profiles / enrollment:**
`Applications and Services Logs > Microsoft > Windows > DeviceManagement-Enterprise-Diagnostics-Provider > Admin`
Turn on the **Debug** channel with `View > Show Analytic and Debug Logs` for more detail.

Useful event IDs:

| Event ID | Meaning |
| --- | --- |
| `75` | Enrollment **success** |
| `76` | Enrollment **failure** (carries the `0x8018xxxx` code) |
| `208 / 813 / 814` | OMA-DM session & policy applied |
| `809` | A policy failed with an "Unknown Win32 error code" (line often prints the decoded error) |

**Identity / PRT:** `Microsoft > Windows > AAD > Operational` — PRT flow bracketed by event `1006`
(start) and `1007` (end).

**Autopilot:** `Microsoft > Windows > ModernDeployment-Diagnostics-Provider > Autopilot`.

**Auto-enrollment scheduled task result:** Task Scheduler →
`Microsoft > Windows > EnterpriseMgmt > {EnrollmentGUID}` — the **PushLaunch** task.
`LastTaskResult = 0x82AC0204` is *not* an error (it means "queued").

---

## MMP-C / Declared Configuration

No dedicated Event Viewer log. Its events ride inside the normal
`DeviceManagement-Enterprise-Diagnostics-Provider` channels — grep for `MDM Declared Configuration:`
or `Provider Name: (DeclaredConfiguration)`. Confirm the enrollment under
`HKLM\SOFTWARE\Microsoft\Enrollments` (two GUIDs; look for `MicrosoftManagementPlatformCloud`).

---

## Reading an IME log like a pro

1. **Turn GUIDs into names.** Petri Paavola's `Get-IntuneManagementExtensionDiagnostics` with
   `-ConvertAllKnownGuidsToClearText` rebuilds the log as a readable timeline of every app, script,
   and ESP phase.
2. **Know the lifecycle markers.** For Win32 apps, search for `[Win32App]`, `GRSManager`, and
   `ReevaluationScheduleManager`. A line saying an app "is not expired" means it's still in its GRS
   cooldown window.
3. **Open it in a proper viewer.** CMTrace / `cmtrace.dev` for red-highlighted errors, live follow,
   and a built-in error-code lookup.

> With verbose IME logging enabled, the log can contain the download URL, AES key, and IV to decrypt
> the `.intunewin` — useful, but it writes secrets to disk. Turn verbose logging back off and clean
> up afterwards.

---

## Collecting logs remotely (no user involvement)

- **Portal:** open the Windows device in the admin center → **Collect diagnostics** (runs
  `MdmDiagnosticsTool` under the hood; up to 25 devices at once; results kept ~28 days, in the device
  **Diagnostics** section).
- **Locally / scripted:** `MdmDiagnosticsTool.exe -area "DeviceEnrollment;DeviceProvisioning;Autopilot" -zip "C:\Temp\MDMDiag.zip"`.

See [`diagnostic-tools.md`](diagnostic-tools.md) for the full toolbox.
