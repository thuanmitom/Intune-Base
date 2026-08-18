# Runbook: PowerShell Script or Remediation Doesn't Run

**Channel:** IME. **Primary evidence:** `AgentExecutor.log` (execution + output) and
`HealthScripts.log` (remediations), under `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\`.

---

## Step 0 — Know the rules that explain most "it didn't run" cases

- **Platform scripts run once** — only on first assignment or when the script content changes. They
  do **not** re-run every sign-in. (Remediations *do* run on a schedule.)
- **Only on Entra-joined or hybrid-joined devices** — not on Workplace-Registered (BYOD) ones.
- **A badly wrong system clock silently blocks execution.**
- **32-bit context by default** — the IME is a 32-bit process (it lives under
  `Program Files (x86)`), so scripts run in a 32-bit PowerShell host unless told otherwise. On
  64-bit Windows your `HKLM\SOFTWARE\...` writes land in **`WOW6432Node`** and 64-bit paths get
  redirected.

---

## Step 1 — Read `AgentExecutor.log`

Open it in CMTrace / cmtrace.dev. Look for the script's execution block, exit code, and any error
output. For remediations, cross-check `HealthScripts.log` and the cache under
`C:\Windows\IMECache\HealthScripts\<DeploymentID>`.

---

## Step 2 — Fix by pattern

### Registry / path writes seem to go "nowhere"

You're in the 32-bit host. Either:

- Set **"Run this script using the logged-on credentials" / "Run script in 64-bit PowerShell host" = Yes**, or
- From inside the script, call the true 64-bit PowerShell:
  `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe`
  (Only **`Sysnative`** reaches the real `System32` from a 32-bit process.)

### Script never runs at all on some devices

- Confirm the device is **Entra-joined / hybrid-joined**, not Entra-registered.
- Confirm the assignment target and that the IME is actually installed (it installs on first
  script/Win32/remediation assignment).
- Check the system clock.

### It ran once and won't run again after you edited it

Platform scripts only re-run when the **content changes**. Make a real change (or re-create the
assignment) to force a re-run. Use a **remediation** instead if you need scheduled recurrence.

### Org-wide: all user-targeted scripts/apps suddenly stop

The Entra service principal the IME authenticates against — **"Microsoft Intune Windows Agent"** —
can get continuously disabled. When it is, **all user-targeted scripts and apps** stop working.
Re-enabling it often doesn't stick; Microsoft's current fix is to **delete** the service principal
via Graph so Entra recreates a clean one. (Do this deliberately — it affects the whole tenant.)

---

## Step 3 — Test locally as the right context

Run the script manually in an elevated **SYSTEM** context (e.g. `PsExec -s`) and in the **same bitness**
IME uses, to reproduce what IME sees. Confirm it's idempotent and exits with a clean code.

---

## Step 4 — Record it

Log non-obvious cases in
[`../templates/case-runbook-template.md`](../templates/case-runbook-template.md).

---

## Related

- IME internals & log map → [`log-locations.md`](log-locations.md)
- App deployment (shares the IME) → [`app-deployment-errors.md`](app-deployment-errors.md)
