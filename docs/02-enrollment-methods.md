# 02 — Enrollment Methods

Each enrollment method is designed for a specific platform and ownership model. Pick the method
that matches how the device was procured and who owns it, then confirm the prerequisites before you
touch a device.

---

## Ownership models

- **Corporate-owned** — procured by the org. Unlocks the fullest management surface. Marked
  corporate either by enrollment method (Autopilot, ADE) or by adding the device's identifier
  (IMEI/serial) to `Devices > Enrollment > Corporate device identifiers`.
- **Personal / BYOD** — owned by the user. More limited management, privacy-preserving; often
  managed with app-level policies (MAM) rather than full device enrollment.

Ownership matters: when a device enrolls as corporate, you gain management features not available on
personal devices.

---

## Windows

| Method | Best for | Notes |
| --- | --- | --- |
| **Entra join + automatic enrollment** | New corporate PCs; remote/BYOD | User signs in with a work account during OOBE (or via `Settings > Accounts > Access work or school`). Requires MDM user scope set to All/Some. Less lifecycle control than Autopilot. |
| **Windows Autopilot** (user-driven, self-deploying, pre-provisioned) | Zero-touch corporate provisioning | Uses the OEM image — no custom image or re-imaging needed. Requires the device's hardware hash to be registered, an Autopilot deployment profile, and automatic enrollment enabled. |
| **Hybrid Entra join + GPO auto-enroll** | Domain-joined estates mid-migration | Uses a Group Policy: `Computer Configuration > Policies > Administrative Templates > Windows Components > MDM > Enable automatic MDM enrollment using default Azure AD credentials`. **Fragile** — avoid for *new* devices where you can (see below). |
| **Bulk enrollment (provisioning package)** | Many corporate devices at once | Build a package with Windows Configuration Designer (or via the Windows ADK); applied during OOBE, joins Entra and enrolls automatically. |
| **Company Portal (Entra registered)** | BYOD wanting MAM | Registers the device and enrolls for app-level policies. |

### Capturing an Autopilot hardware hash

```powershell
# On the target device (elevated)
Install-Script -Name Get-WindowsAutoPilotInfo -Force
Get-WindowsAutoPilotInfo -OutputFile C:\Temp\AutopilotHWID.csv
```

Then upload the CSV under `Devices > Enroll devices > Windows > Windows Autopilot devices > Import`.
The hardware "hash" is not really a hash — it is a base64 list of hardware attributes (decodable
with `OA3Tool.exe` from the Windows ADK).

### Why hybrid Entra join is fragile

The join is asynchronous and happens in the background; the device must reach a domain controller
twice; the on-prem-to-cloud device sync can take 30+ minutes; and if the user signs in before that
sync finishes, they have no Entra user token yet — so the user phase of the Enrollment Status Page
breaks. Microsoft's current guidance leans toward **cloud-native (Entra join) for new devices**;
reserve hybrid for genuine domain-dependency scenarios.

### Enabling automatic MDM enrollment

`Microsoft Entra ID > Mobility (MDM and MAM) > Microsoft Intune`:

- **MDM user scope** = **All** (or a specific group) — this is what makes Entra-joined devices
  auto-enroll.
- For BYOD auto-enrollment, the same scope setting applies.

---

## iOS / iPadOS

| Method | Best for |
| --- | --- |
| **Automated Device Enrollment (ADE)** | Corporate devices via Apple Business Manager / Apple School Manager — hands-off, supervised |
| **Apple Configurator** | Corporate devices enrolled over USB from a Mac |
| **BYOD / Company Portal (user enrollment or device enrollment)** | Personal devices; user enrollment is privacy-preserving |

Prerequisites: an **Apple MDM push certificate** (renew annually — expiry breaks *all* Apple
management), and for ADE an Apple Business/School Manager token.

---

## Android

| Method | Best for |
| --- | --- |
| **Android Enterprise — fully managed** | Corporate devices, full control |
| **Android Enterprise — dedicated (kiosk)** | Single-purpose / shared devices |
| **Android Enterprise — corporate-owned with work profile (COPE)** | Corporate devices with a personal space |
| **Android Enterprise — personally-owned work profile (BYOD)** | Personal devices, work data isolated |

Prerequisite: a **managed Google Play** connection (Android Enterprise binding).

---

## macOS

| Method | Best for |
| --- | --- |
| **Automated Device Enrollment (ADE)** | Corporate Macs via Apple Business/School Manager |
| **Device enrollment (Company Portal)** | User-initiated corporate or BYOD |

Same Apple push certificate prerequisite as iOS.

---

## Pre-enrollment checklist (all platforms)

- [ ] Device runs a **currently supported OS version**
- [ ] User has an **Intune license** assigned
- [ ] **MDM user scope** includes the user (Windows) / platform connector configured (Apple/Android)
- [ ] **Enrollment restrictions** allow the platform and ownership type
- [ ] User is under the **device enrollment limit**
- [ ] For Autopilot/ADE: hardware identifiers registered in advance
- [ ] Network path to Intune/Entra endpoints is open (no TLS break on `*.manage.microsoft.com`, `*.microsoftaik.azure.net`)

If enrollment still fails, go to [`../troubleshooting/enrollment-errors.md`](../troubleshooting/enrollment-errors.md).
