# Case: <short title, e.g. "Win32 app installs but reports failed on new laptops">

> Copy this file into a new dated file (e.g. `templates/cases/2026-08-17-win32-detection.md` or a
> `cases/` folder of your own) whenever you solve something non-obvious. Future-you will thank you.

| Field | Value |
| --- | --- |
| **Date** | YYYY-MM-DD |
| **Reported by** | |
| **Scope** | One device / a group / fleet-wide |
| **Platform / OS build** | Windows 11 23H2 / iOS / … |
| **Join type** | Cloud-native / Hybrid / Entra-registered |
| **Component** | Enrollment / Compliance / Config profile / Win32 app / Script / Sync / Autopilot / MMP-C |
| **Error code(s)** | e.g. `0x87D1041C` |
| **Status** | Open / Resolved / Workaround |

---

## Symptom

What the user/admin actually saw. Portal status, on-device message, exact error code, when it
started, what changed recently.

## Scope check (Step 1 of the method)

- [ ] One device or many?
- [ ] User licensed?
- [ ] In MDM scope?
- [ ] Assignment correct (group / filter / intent)?
- [ ] Network endpoints reachable?

## Evidence gathered

Which channel, which log, what it showed. Paste the key log lines (redact secrets).

```
<relevant log excerpt>
```

- Command(s) run: `dsregcmd /status`, `MdmDiagnosticsTool.exe ...`, etc.
- Portal path(s) checked:

## Root cause

The actual cause — not the symptom. (e.g. "Detection rule checked `C:\Program Files\App\app.exe` but
the 32-bit installer put it under `Program Files (x86)`.")

## Fix applied

Exact steps taken to resolve. Include any registry/portal changes and whether a sync / GRS reset /
re-enroll was needed.

1.
2.
3.

## Verification

How you confirmed it's fixed (fresh sync, log shows success, portal green, user confirmed).

## Prevention / follow-up

What stops this recurring (fix the image, adjust the baseline, add a grace period, update the
detection rule template, document a gotcha). Link any related case files.

## References

- Internal: `docs/...`, `troubleshooting/...`
- External: Microsoft Learn / blog links used
