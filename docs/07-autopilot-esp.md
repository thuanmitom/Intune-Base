# 07 — Windows Autopilot & the Enrollment Status Page (ESP)

Autopilot turns the OEM out-of-box experience into a fully configured, managed device with no custom
image. The **Enrollment Status Page (ESP)** blocks the device during provisioning until required
apps and policies land. Most Autopilot pain is really ESP timing, TPM attestation, or hybrid-join
fragility.

---

## The three ESP phases

1. **Device preparation** — TPM attestation, MDM enrollment, the IME gets installed.
2. **Device setup** — device-context apps, policies, and certificates assigned to the device (or an
   applicable device group).
3. **Account setup** — user signs in; user-context apps and policies apply.

Press **Shift+F10** during OOBE for a command prompt — collect logs there when it hangs.

### How ESP knows what to wait for

The DMClient CSP sends the device a set of **`Expected`** lists (expected apps, policies,
certificates). ESP blocks until each one reports back. Note: the "security policies" step doesn't
track real policies — it tracks a single dummy entry called `EntDMID`. So if that step looks odd,
that's by design.

---

## Autopilot deployment modes

| Mode | User at OOBE | Requires |
| --- | --- | --- |
| **User-driven** | Signs in during OOBE | Standard; works with Entra join or hybrid |
| **Self-deploying** | No user interaction | **Physical TPM 2.0** (attestation); great for kiosks |
| **Pre-provisioning** (formerly "white glove") | IT pre-stages, user finishes later | Physical TPM 2.0 |

Self-deploying and pre-provisioning **require a physical TPM 2.0** — a virtual TPM or TPM 1.2 does
not meet the attestation requirement.

---

## The errors you'll hit most

| Code / symptom | Cause | First fix |
| --- | --- | --- |
| **`0x800705b4`** (timeout) | TPM attestation can't complete, **or** ESP ran past its time-out (too many/too-large apps) | Confirm TPM 2.0; raise the ESP time-out; reduce required apps; exempt `*.microsoftaik.azure.net` from TLS inspection |
| **`0x80070774`** | Hybrid Entra join with "Assign user" set on the Autopilot profile; or DC unreachable | **Unassign the user** on the profile; check the ODJ Connector log for the event flow `30120 → 30130 → 30140` |
| **`0x801c03ea`** | TPM attestation failed | Update TPM firmware; `tpmtool getdeviceinformation`; confirm physical TPM 2.0 |
| **`0x801c0003`** | Entra join not authorized | Allow device join; check the device quota |
| **Stuck on "Identifying"** | Intune still computing ESP policies; never finishes if the user is unlicensed | Assign an Intune license |
| **"Another installation is in progress"** | You mixed an MSI LOB app and a Win32 app — both use TrustedInstaller, which can't run two installs at once | Don't mix them, or move to Autopilot **device preparation** |
| **Standard OOBE instead of Autopilot** | Device not registered, or profile not assigned/synced | Verify hardware hash import and profile assignment |

### TPM attestation and proxies

The attestation chain reaches the manufacturer's EK certificate service and Microsoft's attestation
service at `*.microsoftaik.azure.net`. If a proxy inspects and breaks that traffic, attestation
fails. **Exempt those URLs from TLS inspection.**

---

## Why hybrid Entra join is fragile in Autopilot

The join is asynchronous and runs in the background; the device must reach a domain controller
twice; the on-prem-to-cloud device sync can take 30+ minutes; and if the user signs in before that
sync finishes, they have no Entra user token yet — so the **user phase of ESP breaks**. Current
guidance (Microsoft and the community) leans toward **cloud-native Entra join for new devices**;
reserve hybrid for genuine domain dependencies.

---

## Autopilot diagnostics

- **Autopilot device diagnostics** are collected automatically on Autopilot failure and surface in
  the admin center under the enrollment monitor / device **Diagnostics** section.
- Event Viewer: `Applications and Services Logs > Microsoft > Windows > ModernDeployment-Diagnostics-Provider > Autopilot`.
- `Get-AutopilotDiagnostics` (Michael Niehaus' community script) builds a clean OOBE/ESP timeline.
- `MdmDiagnosticsTool.exe -area "Autopilot;DeviceEnrollment;DeviceProvisioning" -zip "C:\Temp\MDMDiag.zip"`.

---

## Stale-object cleanup (do this carefully)

A duplicate/stale device object across **Intune**, **Entra ID**, and **Windows Autopilot** can act
as a bad anchor for group membership, profile targeting, or join. If it's genuinely the cause, this
is a *coordinated* cleanup: remove the stale objects from **all three** places, then re-register and
re-enroll — deleting only one leaves a mismatched anchor. If you manually deleted the Entra device
object created during Autopilot registration, Microsoft's documented recovery is to **delete and
re-import** the device as an Autopilot device so the object is recreated. Don't use this as a
general fix for an app or ESP failure.
