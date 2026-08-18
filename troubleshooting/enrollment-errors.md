# Runbook: Enrollment Fails

**Channel:** Native MDM. **Primary evidence:** Event Viewer → Event **76** (with a `0x8018xxxx`
code) and the **PushLaunch** scheduled task result.

---

## Step 0 — Confirm the basics (fixes ~half of cases)

- [ ] User has an active **Intune / M365 license**.
- [ ] `Entra > Mobility (MDM and MAM) > Microsoft Intune` → **MDM user scope** is **All** or a group
      including the user (not **None**).
- [ ] `Devices > Enrollment > Enrollment restrictions` → the platform + ownership type is allowed.
- [ ] User is under the **device enrollment limit** (default cap 15; check
      `Entra > Users > [user] > Devices` and remove stale registrations).
- [ ] No conflicting/leftover MDM enrollment on the device.
- [ ] Network path to enrollment endpoints is open.

---

## Step 1 — Read the evidence

Event Viewer:
`Applications and Services Logs > Microsoft > Windows > DeviceManagement-Enterprise-Diagnostics-Provider > Admin`

- **Event 75** = success, **Event 76** = failure (with the code).
- Also check Task Scheduler → `Microsoft > Windows > EnterpriseMgmt > {GUID}` → PushLaunch
  `LastTaskResult`. `0x82AC0204` there means "queued" — not an error.

For hybrid auto-enrollment, confirm the GPO actually applied:

```cmd
gpresult /r
gpresult /h C:\Temp\gpresult.html
```

The GPO is `Computer Configuration > Policies > Administrative Templates > Windows Components > MDM >
Enable automatic MDM enrollment using default Azure AD credentials` — it must be **Enabled**, with
credential type **User Credential**, and the GPO **linked to an OU that contains the computer
objects** (not just user objects).

---

## Step 2 — Match the code to the fix

| Code / symptom | Root cause | Fix |
| --- | --- | --- |
| `0x8018002b` (the classic) | UPN suffix not verified/routable (`.local`), or user out of MDM scope | Fix the UPN suffix; set MDM user scope to All / right group |
| `0x80180014` | Enrollment restriction blocks Windows (MDM) or personal devices | Allow Windows (MDM); adjust personal-device restriction; check device cap |
| `0x80180018` | No / invalid license | Assign an Intune license; confirm MDM scope |
| `0x8018000a` / `0x8007064c` | Already enrolled (cloned image, leftover work account, stale cert) | Remove existing connection; clear stale enrollment cert & orphaned `EnterpriseMgmt` tasks; re-enroll — and fix the **image** if it recurs on imaged devices |
| `0x8018002A` | No MFA-backed token for silent enrollment | Exclude *Microsoft Intune Enrollment* app from the MFA CA policy, or have the user complete MFA interactively for an MFA-backed PRT |
| `DeviceCapReached` | Device limit hit | Remove stale device records or raise the limit |
| `0x801c0003` | Entra join not authorized | Allow device join; check device quota |

---

## Step 3 — "Already enrolled" deep clean (for `0x8018000a` / `0x8007064c`)

1. `Settings > Accounts > Access work or school` — remove any existing work/school connection.
2. Remove the stale **account certificate** from the previous enrollment.
3. Delete the orphaned scheduled tasks under
   `Task Scheduler > Microsoft > Windows > EnterpriseMgmt > {old GUID}`.
4. Remove stale device objects in **Entra** and **Intune** (and Autopilot, if registered) so a fresh
   enrollment doesn't collide with a dead anchor.
5. Re-enroll.

> If this recurs across many machines, the **image** was captured with an existing enrollment. Fix
> the golden image to ship clean.

---

## Step 4 — Collect and escalate

```powershell
MdmDiagnosticsTool.exe -area "DeviceEnrollment;DeviceProvisioning;Autopilot" -zip "C:\Temp\MDMDiag.zip"
```

Or use the portal **Collect diagnostics** action. If a single device still won't enroll after ~2
hours, **re-stage it** (wipe + re-enroll). Record the case using
[`../templates/case-runbook-template.md`](../templates/case-runbook-template.md).

---

## Related

- Enrollment methods & prerequisites → [`../docs/02-enrollment-methods.md`](../docs/02-enrollment-methods.md)
- Autopilot-specific enrollment → [`../docs/07-autopilot-esp.md`](../docs/07-autopilot-esp.md)
- Identity problems masquerading as enrollment → [`../docs/08-identity-prt.md`](../docs/08-identity-prt.md)
