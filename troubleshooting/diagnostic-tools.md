# Diagnostic Tools

Start with what's already on the device or in the portal; reach for community tools only when the
built-ins don't get you there.

---

## Built-in (always available)

### `MdmDiagnosticsTool.exe` — the in-box collector

Ships with Windows. Gathers logs, registry exports, and event logs into one package plus an HTML
summary. This is also what the portal's **Collect diagnostics** runs under the hood.

```powershell
# Collect enrollment, provisioning and Autopilot data into one zip
MdmDiagnosticsTool.exe -area "DeviceEnrollment;DeviceProvisioning;Autopilot" -zip "C:\Temp\MDMDiag.zip"
```

Save output somewhere writable (e.g. `C:\Temp`). Areas you can combine include `DeviceEnrollment`,
`DeviceProvisioning`, `Autopilot`, `TPM`, and more.

### Collect diagnostics — the portal remote action

Open a Windows device in the admin center → **Collect diagnostics**. Pulls the full log set without
bothering the user (device must be online), up to **25 devices** at once. Results stay **~28 days**
in the device **Diagnostics** section.

### `dsregcmd /status` — identity state

The first command for any "is it really Intune?" question. Read Device State (join type), Device
Details (cert, TPM), and SSO State (PRT). See [`../docs/08-identity-prt.md`](../docs/08-identity-prt.md).

### `tpmtool getdeviceinformation` — TPM health

Confirm a physical **TPM 2.0** for self-deploying / pre-provisioning Autopilot and for attestation.

### Decode any Win32/HRESULT code

```powershell
[ComponentModel.Win32Exception]0x80070005   # -> Access is denied
```

Microsoft's `Err.exe` does the same from a command line.

---

## CMTrace / cmtrace.dev — log viewer

CMTrace (from ConfigMgr) or the free browser version **cmtrace.dev** colour errors red, follow the
file live, and include a built-in error-code lookup. Essential for reading IME logs.

---

## Community tools (well-known, community-maintained)

> These are third-party. Review before running in production; behavior can change between versions.

| Tool | Author | What it does |
| --- | --- | --- |
| **Get-IntuneManagementExtensionDiagnostics** | Petri Paavola | Rebuilds the IME log into a readable timeline; `-ConvertAllKnownGuidsToClearText` swaps GUIDs for real names |
| **IntuneDebugToolkit** | MSEndpointMgr | Windows GUI: Win32 redeploy button, SyncML viewer, registry change monitor, bundled CMTrace |
| **SyncML Viewer** | Oliver Kieselbach | Live OMA-DM protocol tracing; newer versions can trigger an MMP-C sync and decode an Autopilot hardware hash |
| **IntuneDeviceTroubleshooter** | Jannik Reinhard | Pulls a device's compliance/config/app state from Microsoft Graph into one pane; one-click sync/restart |
| **Get-AutopilotDiagnostics** | Michael Niehaus | Clean OOBE/ESP timeline from Autopilot logs |
| **OA3Tool.exe** | Windows ADK | Decodes an Autopilot hardware "hash" (a base64 list of hardware attributes) |
| **ErrorHunter / MSNugget lookup** | Community | Browser lookup translating Win32/HRESULT/SyncML codes to plain English |

---

## Network tracing (advanced, last resort)

- **OMA-DM channel:** Fiddler is fine here — captures the SyncML traffic.
- **PRT flow:** **do not** use Fiddler (it breaks the flow). Use `netsh trace` instead.

---

## What this repo adds

The [`../scripts/`](../scripts/) folder wraps the most common of these into repeatable helpers:

- [`Collect-IntuneDiagnostics.ps1`](../scripts/Collect-IntuneDiagnostics.ps1)
- [`Force-IntuneSync.ps1`](../scripts/Force-IntuneSync.ps1)
- [`Get-DeviceIdentityState.ps1`](../scripts/Get-DeviceIdentityState.ps1)
- [`Reset-Win32AppGRS.ps1`](../scripts/Reset-Win32AppGRS.ps1) (test devices only)
- [`Decode-IntuneErrorCode.ps1`](../scripts/Decode-IntuneErrorCode.ps1)
