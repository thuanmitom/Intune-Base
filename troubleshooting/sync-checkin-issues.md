# Runbook: Device Stops Syncing / Stale Check-In

**Channel:** Native MDM (+ identity). If a device hasn't checked in for over a day, it can't receive
policy — so this cascades into "profiles not applying," "still non-compliant," etc.

---

## Step 0 — Force a sync, both channels

- Device: `Settings > Accounts > Access work or school > Info > Sync`, or **Company Portal > Sync**
  (triggers **both** MDM and IME).
- Portal: the device **Sync** action triggers the **MDM channel only** — it does **not** force the
  IME. To force the IME, restart the `IntuneManagementExtension` service.

If a manual sync works, the channel is fine — investigate what stopped automatic check-ins (Step 2/3).

---

## Step 1 — Check the identity layer

```powershell
dsregcmd /status
```

- `AzureAdPrt: YES` and fresh `AzureAdPrtUpdateTime`? If stale, lock/unlock; check the Entra device
  object isn't disabled/deleted; check TPM health.
- Join type as expected (cloud-native vs hybrid)?

A broken PRT can stop sync, sign-in, and compliance reporting all at once.

---

## Step 2 — The certificate trap (`0x80190190`)

**"Last check-in" can look recent while the certificate is already expired.** If sync fails with a
cert error like `0x80190190`, it's the **Intune MDM Device CA** certificate (the management-channel
cert), *not* the Entra device cert.

- Verify the cert directly in `certlm.msc` (Personal store) rather than trusting the timestamp.
- If expired, **re-enroll** the device.

(These two certs fail independently — see [`../docs/08-identity-prt.md`](../docs/08-identity-prt.md).)

---

## Step 3 — The `dmwappushservice` trap

The **`dmwappushservice`** ("Device Management WAP Push Message Routing Service") orchestrates MDM
sync sessions. If a **hardening baseline disabled it before enrollment**, the **PushLaunch** and
**PushRenewal** scheduled tasks are never created and the device **silently stops syncing — with no
error logged**.

Fix:

1. Set the service to **Automatic (Delayed Start)** and **start** it.
2. Re-trigger enrollment / sync so the scheduled tasks get created.

> Hardening that breaks management isn't hardening. Audit baselines for services that MDM depends on.

---

## Step 4 — Confirm the scheduled tasks exist

Task Scheduler → `Microsoft > Windows > EnterpriseMgmt > {EnrollmentGUID}`:

- **PushLaunch** reacts to the WNS push and starts the OMA-DM session.
- `LastTaskResult = 0x82AC0204` = "queued, will run later" — **not** an error.

If the `{EnrollmentGUID}` folder or these tasks are missing, enrollment plumbing is broken (often the
`dmwappushservice` cause above) — re-enroll.

---

## Step 5 — Network path

Confirm the device reaches `*.manage.microsoft.com`, Entra endpoints, and WNS. A proxy that inspects
TLS on these breaks the channel. For deep analysis, Fiddler can trace the OMA-DM channel (but **not**
the PRT flow — use `netsh trace` for PRT).

---

## Step 6 — Collect / re-stage / record

```powershell
MdmDiagnosticsTool.exe -area "DeviceEnrollment;DeviceProvisioning" -zip "C:\Temp\MDMDiag.zip"
```

If a single device won't recover after ~2 hours, re-stage it. Record the case in
[`../templates/case-runbook-template.md`](../templates/case-runbook-template.md).

---

## Related

- Log map → [`log-locations.md`](log-locations.md)
- Identity / certs → [`../docs/08-identity-prt.md`](../docs/08-identity-prt.md)
