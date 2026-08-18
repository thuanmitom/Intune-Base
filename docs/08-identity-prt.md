# 08 — Identity, the PRT & Device Certificates

A large share of "Intune is broken" tickets are really **identity** problems: the device can't prove
who it is, so sync, enrollment, or Conditional Access fails. Learn this layer and you'll solve
problems that never appear in an Intune log.

---

## Your first command, always

```powershell
dsregcmd /status
```

Read three sections:

### Device State — the join type

- `AzureAdJoined` — is the device Entra joined?
- `DomainJoined` — is it on-prem AD domain joined?
- `EnterpriseJoined` — on-prem Entra (rare)

Combinations:

| AzureAdJoined | DomainJoined | Meaning |
| --- | --- | --- |
| YES | NO | **Cloud-native** (Entra joined) |
| YES | YES | **Hybrid** Entra joined |
| NO | (WorkplaceJoined: YES in User State) | **Entra registered** (BYOD) |

### Device Details

- The device certificate thumbprint.
- `TpmProtected: YES` — the private key lives in the TPM.

### SSO State — the PRT

- `AzureAdPrt: YES/NO`
- `AzureAdPrtUpdateTime` — if it's more than ~4 hours old, the PRT is failing to refresh.
- `AcquirePrtDiagnostics` — extra detail when acquisition fails.

> **Fast move:** locking and unlocking the device forces a PRT refresh attempt.

---

## The Primary Refresh Token (PRT)

The PRT is the key artifact behind single sign-on. It's an opaque blob issued to the device's token
brokers. What matters for troubleshooting is how it's protected:

1. At registration, the device generates a **device key** and a **transport key**, both bound to the
   **TPM**.
2. Entra issues the PRT plus a session key encrypted to the transport key — so **only that device's
   TPM can decrypt it**. That session key signs later token requests.
3. **CloudAP** (the Cloud Authentication Provider, loaded into LSASS) caches and renews the PRT
   about every **4 hours** — which is exactly what `AzureAdPrtUpdateTime` reflects.

So when the TPM has a problem, or the device object is **deleted or disabled**, the PRT can't refresh
— and because **device-compliance claims for Conditional Access ride inside the PRT**, a broken PRT
cascades into sign-in prompts, CA blocks, and sync failures all at once.

To dig deeper: `dsregcmd /status` SSO State, then Event Viewer under
`Microsoft > Windows > AAD > Operational` — the PRT flow is bracketed by event **1006** (start) and
**1007** (end).

> Microsoft says explicitly **not** to use Fiddler to capture PRT traffic — use `netsh trace`
> instead. Fiddler breaks the PRT flow. (Fiddler is fine for the OMA-DM channel.)

---

## The two device certificates you must not confuse

A managed, Entra-joined device has **two** certificates doing very different jobs. Mixing them up
wastes hours.

| Certificate | Job | If it breaks |
| --- | --- | --- |
| **MS-Organization-Access** | The **Entra device identity**. Issued at registration, ~10-year lifetime. Its presence *is* the Entra join; it's what gets the device a PRT. | Remove it and the device is effectively unjoined — no PRT, dropped from Entra. |
| **Microsoft Intune MDM Device CA** | Authenticates the **OMA-DM management channel** to Intune. | Sync dies with **`0x80190190`** even though the Entra join is still fine. |

They fail **independently**. A device can be perfectly Entra-joined with a healthy PRT and *still*
have an expired MDM certificate that blocks all sync.

> **Don't trust "Last check-in."** It can look recent while the MDM cert is already expired. Verify
> the certificate directly in `certlm.msc` rather than trusting the timestamp.

---

## Quick identity triage

1. `dsregcmd /status` → confirm join type, `AzureAdPrt: YES`, and a fresh `AzureAdPrtUpdateTime`.
2. If PRT is stale → lock/unlock; check the Entra device object isn't disabled/deleted; check TPM
   health (`tpmtool getdeviceinformation`).
3. If sync fails but PRT is healthy → check the **Intune MDM Device CA** certificate in `certlm.msc`;
   if expired, re-enroll.
4. If Conditional Access blocks despite a compliant device → the compliance claim in the PRT is the
   suspect; refresh the PRT and confirm the device object is healthy.

See also [`../scripts/Get-DeviceIdentityState.ps1`](../scripts/Get-DeviceIdentityState.ps1) for a
parsed summary of `dsregcmd /status`.
