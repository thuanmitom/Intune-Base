# Error Code Reference

A fast lookup for the codes that actually come up. For anything not here, decode it (below) or use
Microsoft's **App installation error codes** / **Windows enrollment errors** pages, which are the
canonical, always-current lists.

---

## How to decode a code

### Read the family, jump to the area

| Family | Area | Where to look |
| --- | --- | --- |
| `0x8018xxxx` | Enrollment / MDM (MENROLL) | Event Viewer, Event **76** |
| `0x87D1xxxx` | Win32 app | IME `AppWorkload.log` |
| `0x87D3xxxx` | Win32 app (install/process phase) | IME `AppWorkload.log` |
| `0x80072Fxx` | WinHTTP / certificate / TLS | Sync & check-in |
| `0x800705b4` | Timeout | TPM attestation or ESP |
| `0x801cxxxx` | Entra join / device registration | `dsregcmd`, AAD Operational log |

### Configuration-profile codes

Portal shows a long **decimal**. Convert to hex; the rule is:

```
0x87D10000 + <SyncML status>
```

Example: `-2016345708` → `0x87D10194` → `0x194` = **404** (CSP node not found).

Common SyncML statuses: `404` node not found/not applicable · `405` wrote to a read-only node ·
`418` node already exists · `500` server/CSP failure (often benign & transient on firewall settings
right after boot).

### Plain-English text for any Win32/HRESULT code

```powershell
[ComponentModel.Win32Exception]0x80070005   # -> Access is denied
```

---

## Enrollment codes

| Code | Meaning | First fix |
| --- | --- | --- |
| `0x8018000a` / `0x8007064c` | Device already enrolled (leftover work account, cloned image, stale enrollment) | Remove existing connection under *Access work or school*; clear the stale enrollment cert & orphaned `EnterpriseMgmt` tasks; re-enroll |
| `0x80180014` | MDM enrollment blocked by an enrollment restriction / personal devices blocked | `Devices > Enrollment` → allow Windows (MDM); check personal-device restriction & device cap |
| `0x80180018` | No or invalid license | Assign an Intune license; confirm user in MDM scope |
| `0x8018002b` | Unverified / non-routable UPN suffix (e.g. `.local`), or user out of MDM scope | Fix the UPN suffix; set MDM user scope to All or the right group |
| `0x8018002A` | No MFA-backed token for silent enrollment | Exclude the *Microsoft Intune Enrollment* app from the MFA CA policy, or have the user complete MFA interactively to get an MFA-backed PRT |
| `DeviceCapReached` | User hit the device enrollment limit | Remove stale device records or raise the limit |
| `0x801c0003` | Entra join not authorized | Allow device join; check device quota |
| `0x80180002b` (Event 76) | Auto-enroll failed | Check UPN suffix + MDM scope; confirm the auto-enrollment GPO (hybrid) |

---

## Autopilot / TPM codes

| Code | Meaning | First fix |
| --- | --- | --- |
| `0x800705b4` | Timeout — TPM attestation or ESP ran past its limit | Confirm TPM 2.0; raise ESP time-out; reduce required apps; exempt `*.microsoftaik.azure.net` from TLS inspection |
| `0x801c03ea` | TPM attestation failed | Update TPM firmware; `tpmtool getdeviceinformation`; confirm physical TPM 2.0 |
| `0x80070774` | Hybrid join: domain mismatch / DC unreachable | Unassign user on the Autopilot profile; check ODJ Connector events `30120 → 30130 → 30140` |

---

## Win32 app codes

| Code | Meaning | First fix |
| --- | --- | --- |
| `0x87D1041C` | Installed but detection rule didn't find it | Fix detection rule (path, version operator, registry, MSI ProductCode); mind the GRS cooldown |
| `0x87D1FDE8` | Generic IME install failure / will retry | Fix detection; test the install as SYSTEM; read `AppWorkload.log` |
| `0x87D300C9` | Unmonitored process in progress, may time out | Check install command/parameters |
| `0x87D300CD` | User logged off while the app policy was processing | Retry; consider device context |
| `0x80073CF3` | Dependency / conflict / architecture mismatch | Check x86 vs x64, dependencies, existing version |
| `0x80073CF2` | Invalid package data | Repackage / verify the source |
| `1618` (exit) | Another install already running (TrustedInstaller busy) | Don't mix MSI LOB + Win32; IME retries later |
| `3010` (exit) | Soft reboot = success | **Map 3010 as success** in the return-code list |

---

## Apple app codes (VPP / managed apps)

| Code | Meaning |
| --- | --- |
| `0x87D13B60` | Scheduled for install but needs a redemption code (user canceled) |
| `0x87D13B63` | User rejected the app update offer |
| `0x87D13B66` | App was managed but expired or removed by the user |
| `0x87D13B9F` | An app update is available (often shows "failed" though installed) |
| `0x87D1077C` | App license failed to install (often offline Store-for-Business licensing) |

---

## Sync / certificate codes

| Code | Meaning | First fix |
| --- | --- | --- |
| `0x80190190` | Sync fails — expired **Intune MDM Device CA** certificate | Check the cert directly in `certlm.msc`; re-enroll if expired. **Don't trust "Last check-in."** |
| `0x82AC0204` | PushLaunch task "queued, will run later" | **Not an error** — ignore |

---

## MMP-C / Declared Configuration codes

| Code | Meaning |
| --- | --- |
| `0x80070002` | File not found — `DiscoveryEndpoint` never set, so the linked enrollment can't start |
| `400 Invalid Request` | Tenant not onboarded to MMP-C |
| `2147749902` | Device Health Monitoring policy failed (old build / missing DHM registry keys) — blocks EPM |
| `0x8000FFFF` | Declared Configuration document-ID mismatch |
| `0x86000002` | Typo in an OMA-URI inside a Declared Configuration document |

---

## Related lookups when this list doesn't help

- **Win32 / HRESULT** — decode with `[ComponentModel.Win32Exception]<code>` or `Err.exe`
- **MsiExec / Windows Installer** — 1xxx exit codes
- **Windows Update** — `0x8024xxxx`
- **Entra ID (AADSTS…)** — sign-in error codes in the Entra sign-in logs

See also [`../scripts/Decode-IntuneErrorCode.ps1`](../scripts/Decode-IntuneErrorCode.ps1).
