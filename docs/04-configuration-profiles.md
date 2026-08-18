# 04 — Configuration Profiles, CSPs & OMA-URI

Configuration profiles travel down the **native MDM channel** (see
[`01-fundamentals.md`](01-fundamentals.md)). Every setting resolves to a **CSP**, and every profile
error you see in the portal is really a **SyncML status** with an underlying Win32 code.

---

## Profile types (Windows)

- **Settings Catalog** — the modern, preferred way. A flat searchable list of thousands of
  settings, each mapping to a CSP node. Use this by default.
- **Templates** — curated groupings (e.g. Device restrictions, Endpoint protection). Older model,
  still useful for some scenarios.
- **Custom (OMA-URI)** — you specify the OMA-URI path and value yourself. Use only when a setting
  isn't in the Settings Catalog. Powerful and easy to get wrong.

---

## Anatomy of an OMA-URI

```
./Device/Vendor/MSFT/Policy/Config/<Area>/<PolicyName>
```

- `./Device` vs `./User` — the scope. No prefix defaults to device.
- `Vendor/MSFT/...` — the CSP path.
- The **data type** (String / Integer / Boolean / etc.) must match what the CSP expects, or the
  node is rejected.

The Policy CSP exposes a **`Config`** path (where Intune writes) and a **`Result`** path (read-only,
the conflict-resolved value the device actually applied). When two profiles disagree, `Result` shows
who won.

---

## How a setting is delivered on the wire

Each setting becomes a SyncML command — usually a `Replace` (set), `Add` (create node), or
`Delete` (remove). "Not configured" is literally a `Delete`. Microsoft recommends each setting be
wrapped in an `Atomic` block so it applies as one transaction. Example command:

```xml
<Replace>
  <CmdID>2</CmdID>
  <Item>
    <Meta><Format>chr</Format><Type>text/plain</Type></Meta>
    <Target><LocURI>./Device/Vendor/MSFT/Policy/Config/AppVirtualization/AllowAppVClient</LocURI></Target>
    <Data><Enabled/></Data>
  </Item>
</Replace>
```

You can watch these commands live with a **SyncML tracer** (e.g. Oliver Kieselbach's SyncML Viewer)
— the fastest way to prove whether a setting was actually delivered or silently dropped.

---

## Profile conflicts — check this before blaming a policy

When two profiles set the same setting to different values, the portal shows a **Conflict** state.
The device applies one value (readable via the CSP `Result` path) and reports the conflict. Two
profiles fighting over one setting is one of the most common causes of "my policy isn't applying."

**Before changing anything:** open the setting's per-device status and look for **Conflict**.
Resolve by removing the duplicate assignment or aligning the values.

---

## Reading profile errors (SyncML status codes)

Profile errors show in the portal as a long **decimal** status. It's a SyncML status wrapped in a
Win32 code. The decoding rule for configuration profiles:

```
0x87D10000 + <SyncML status code>
```

Worked example: portal value `-2016345708` → `0x87D10194` in hex → `0x87D10000 + 0x194` →
`0x194` = **404**. The setting failed because the **CSP node was not found**.

Common SyncML statuses you'll see:

| SyncML status | Meaning | Typical cause |
| --- | --- | --- |
| **404** | Node not found / not applicable | CSP not supported on that platform or Windows edition/build |
| **405** | Wrote to a read-only node | Targeted a `Result`/read-only path |
| **418** | Node already exists | An `Add` where the node is already present |
| **500** | Server/CSP internal failure | On the **firewall compliance** setting this is often **benign & transient** — the MDM agent starts before the firewall service finishes initializing at boot; clears next sync |

> Not every "Error" is a real problem. A transient `500` on firewall settings right after boot is a
> classic false alarm — re-check after the next sync before you touch anything.

---

## Where to troubleshoot

- Event Viewer:
  `Applications and Services Logs > Microsoft > Windows > DeviceManagement-Enterprise-Diagnostics-Provider > Admin`
  Turn on the **Debug** channel (`View > Show Analytic and Debug Logs`) for more detail.
- Useful event IDs: `208 / 813 / 814` = OMA-DM session and policy applied; `809` = a policy failed
  with an "Unknown Win32 error code" (the line usually prints the decoded error).

For a decode helper, see [`../scripts/Decode-IntuneErrorCode.ps1`](../scripts/Decode-IntuneErrorCode.ps1)
and the [`error-code-reference.md`](../troubleshooting/error-code-reference.md).

---

## Group Policy analytics (migration aid)

In the admin center, **Group Policy analytics** imports your on-prem GPO settings and reports which
ones a cloud MDM provider (including Intune) supports. It's the practical starting point when
translating legacy GPOs into Settings Catalog profiles.
