# Runbook: App Fails or Reports Wrongly

**Channel:** IME (Win32/scripts) or native MDM (MSI LOB / Store). **Primary evidence:**
`AppWorkload.log` and `IntuneManagementExtension.log` under
`C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\`, read with CMTrace.

---

## Step 0 — Confirm the app type first

`Apps > All apps` → the **Type** column. Win32, MSI LOB, and Store apps use different install
mechanisms and fail in different ways. This runbook focuses on **Win32** (the most common); notes on
the others at the end.

---

## Step 1 — Narrow it in the portal

Open the app → the failing device → review: installation status, **applicability**, **detection**,
dependencies, supersedence, assignment context, and the error code. For Autopilot/ESP failures,
compare the app's context with the ESP phase (Device setup tracks device-context required apps).

Allow up to ~30 minutes for filter evaluation to appear. Verify the app is actually assigned to the
correct object.

---

## Step 2 — Read the IME log

On the device, open `AppWorkload.log` (and `IntuneManagementExtension.log`) in CMTrace / cmtrace.dev.
Search for `[Win32App]`, `GRSManager`, `ReevaluationScheduleManager`. The log shows:

- Whether the app was considered **applicable**.
- The **exact command line** executed.
- The installer **exit code**.
- **Detection rule** evaluation (`ApplicationDetected: True/False`).

Tip: run Petri Paavola's `Get-IntuneManagementExtensionDiagnostics -ConvertAllKnownGuidsToClearText`
to turn the GUID soup into a readable timeline.

---

## Step 3 — Diagnose by pattern

### "Installed but reported as failed" (`0x87D1041C`)

The installer returned success, but the **detection rule** didn't find the app. The detection rule
is the source of truth — and it's almost always wrong: wrong path, wrong version operator, wrong
registry value, or a mismatched **MSI ProductCode**. Fix the detection rule to match the real
installed artifact.

### The app won't retry after you fixed it (GRS)

After a failure, IME retries **3× at 5-minute intervals**, then locks the app into the **GRS
cooldown (~24h)**, skipping it every sync. So "I fixed it and nothing happened" usually means it's in
cooldown. On a **test device**, clear the state:
[`../scripts/Reset-Win32AppGRS.ps1`](../scripts/Reset-Win32AppGRS.ps1). Clearing GRS only resets the
timer — it doesn't fix the underlying failure.

### "Source file not found" mid-install (e.g. error 1311/1603 in a wrapper)

The IME cleans `C:\Windows\IMECache\<AppId>` a few seconds after detection. A wrapper that references
files from there *after* detection fails. **Bundle all files inside the package** and expand them
yourself first.

### A good install reported as failed on exit code

Any exit code **not** in the return-code list = Failed. The classic trap: `3010` (soft reboot) not
mapped as success. Map `3010` (and `1641`, `1707`) correctly.

### "Another installation is in progress" (`1618`)

Two TrustedInstaller-based installs at once — usually an **MSI LOB app mixed with a Win32 app**.
Don't mix them, or move to Autopilot **device preparation**.

### Dependency / architecture failures

`0x80073CF3` (dependency/conflict/architecture) or `0x80073CF2` (invalid package data). Check x86 vs
x64, missing/conflicting dependencies, or a different version already installed. For MSIX/AppX,
check the `AppXDeployment-Server` event log.

---

## Step 4 — Reproduce as SYSTEM

Win32 apps install in the **SYSTEM** context. Open a SYSTEM prompt (e.g. `PsExec -s -i cmd`) and run
the **exact** install command. If it fails there, the problem is the installer/command under SYSTEM —
not Intune. If genuine user interaction is required, `serviceui.exe` can surface a prompt, but prefer
silent installs.

---

## Step 5 — Force a clean retry (test device) and record

1. Fix the root cause (detection rule / command / return codes).
2. Clear GRS on the test device and restart the IME service (script above).
3. Watch `AppWorkload.log` live.
4. Log the case: [`../templates/case-runbook-template.md`](../templates/case-runbook-template.md).

---

## MSI LOB & Store apps (brief)

- **MSI LOB** travels down the native MDM channel (EnterpriseDesktopAppManagement CSP), not the IME —
  so look in Event Viewer, not `AppWorkload.log`.
- **Store apps** also use the native channel; offline-licensed variants are useful for ESP/Autopilot.
- **Apple VPP / managed apps** surface `0x87D13Bxx` codes — often user-cancel or "update available"
  (see [`error-code-reference.md`](error-code-reference.md)).

---

## Related

- Win32 lifecycle & detection → [`../docs/05-app-deployment.md`](../docs/05-app-deployment.md)
- Log map → [`log-locations.md`](log-locations.md)
