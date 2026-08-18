# Runbook: Device Non-Compliant For No Obvious Reason

**Channel:** Native MDM (compliance) + identity (PRT). **Primary evidence:** the device's per-policy
compliance status in the portal, `dsregcmd /status`, and the Entra sign-in log's CA tab.

---

## Step 0 — The three usual suspects

Before anything else, check these — they cover most cases:

1. **0-day grace period on a single failing setting.** Every policy has a built-in
   "Mark device noncompliant" action defaulting to **0 days** — one failed setting flips the whole
   device instantly. Open the device's compliance detail and find *which setting* failed.
2. **The tenant default-policy setting.**
   `Endpoint security > Device compliance > Compliance policy settings` →
   "Mark devices with no compliance policy assigned as". If this is **Not compliant** and a device
   simply has **no policy targeted**, it's non-compliant by design (and CA blocks it).
3. **Stale check-in.** A device offline ~30 days drifts to non-compliant. Check **Last check-in** —
   but don't fully trust it (see cert note below).

---

## Step 1 — Read the two compliance states

In the device blade, and via `Troubleshooting + support`:

- **Intune compliant** — Intune's own evaluation.
- **Microsoft Entra compliant** — the signal as it reaches Entra / CA.

If **Intune = compliant** but **Entra = not compliant**, the *signal isn't flowing*, not the policy.
Suspects: stale check-in, a **PRT problem** (the compliance claim rides inside the PRT), or the
device being turned off. Go to Step 3.

If **Intune = not compliant**, a real setting failed — go to Step 2.

---

## Step 2 — Find the failing setting

1. Open the device → **Device compliance** → expand each policy → find the setting marked
   *Not compliant*.
2. Force a fresh evaluation: Company Portal → **Sync**, or
   `Settings > Accounts > Access work or school > Info > Sync`.
3. Remediate the actual setting (BitLocker on, Defender healthy, OS version, etc.).
4. Add a **grace period** (1–7 days) to the policy so the next rollout doesn't hard-block instantly.

For **custom compliance** rules, the script runs via the IME — check `AgentExecutor.log` for its
output, and remember script rules apply only on Entra-joined / hybrid-joined devices.

---

## Step 3 — Signal-flow / identity problems

```powershell
dsregcmd /status
```

- Confirm `AzureAdPrt: YES` and a fresh `AzureAdPrtUpdateTime` (< ~4h). If stale → lock/unlock the
  device to force a refresh; confirm the Entra device object isn't disabled/deleted; check TPM.
- If sync looks recent but nothing updates, verify the **Intune MDM Device CA** certificate in
  `certlm.msc` — an expired cert (`0x80190190`) blocks sync while "Last check-in" still looks OK.

---

## Step 4 — The Conditional Access compliance loop

Symptom: a device is blocked for being non-compliant, but because it's blocked it can't sync to
report itself compliant — so it stays stuck.

Fix / prevent:

- **Target compliance policies to device groups**, so compliance can be evaluated *before* user
  sign-in.
- Use **offline-licensed Store apps** for anything needed during provisioning.
- Keep a **break-glass** exclusion so an admin can always get in.

Confirm the block in `Entra > Sign-in logs` → the failed sign-in → **Conditional Access** tab →
look for `deviceNotCompliant`.

---

## Step 5 — Record it

If it was non-obvious, log the case with
[`../templates/case-runbook-template.md`](../templates/case-runbook-template.md) so the next
occurrence is a 2-minute fix.

---

## Related

- Compliance concepts → [`../docs/03-compliance-policies.md`](../docs/03-compliance-policies.md)
- Conditional Access → [`../docs/06-conditional-access.md`](../docs/06-conditional-access.md)
- PRT / identity → [`../docs/08-identity-prt.md`](../docs/08-identity-prt.md)
