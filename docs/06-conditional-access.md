# 06 — Conditional Access & Compliance

Conditional Access (CA) lives in **Microsoft Entra ID**, not Intune — but it's where Intune
compliance becomes an access decision. Understanding the handoff prevents the most frustrating
lockouts.

---

## The handoff: how CA consumes compliance

1. Intune evaluates the device against your compliance policies → **Intune compliant** state.
2. That state flows to Entra as the **Microsoft Entra compliant** signal, carried inside the
   device's **Primary Refresh Token (PRT)** (see [`08-identity-prt.md`](08-identity-prt.md)).
3. A CA policy with the grant control **Require device to be marked as compliant** reads that signal
   at sign-in and allows or blocks.

Because the compliance claim rides *inside* the PRT, a **broken PRT can look like a compliance
problem** — the device is fine, but the signal never reaches Entra.

---

## The compliance loop trap

A device is blocked for being non-compliant. But because it's blocked, it can't reach the Intune
service to sync and report itself compliant — so it stays blocked. A self-perpetuating loop.

**How to avoid / break it:**

- **Target compliance policies to devices** (device groups), so compliance can be evaluated *before*
  the user signs in — not only after.
- Use **offline-licensed Store apps** for anything needed during provisioning.
- Keep an **exclusion** or a break-glass account so an admin can always get in to remediate.

---

## Diagnosing a CA block

1. Go to `Entra ID > Identity > Monitoring & health > Sign-in logs`.
2. Find the blocked sign-in, open the **Conditional Access** tab.
3. Look for the policy showing **Failure** and expand it to see which **grant control** wasn't
   satisfied.
4. If the failure reason is **`deviceNotCompliant`**, the blocker is Intune compliance — go to
   [`../troubleshooting/compliance-issues.md`](../troubleshooting/compliance-issues.md).

---

## Grace periods and CA

A device **In Grace Period** still counts as **compliant** for CA — access is allowed while the user
remediates. Only after the grace period expires does the device transition to **Non-compliant** and
CA blocks apply. This is why adding grace periods to compliance policies (see
[`03-compliance-policies.md`](03-compliance-policies.md)) is essential before a rollout.

---

## Common CA gotchas that look like Intune problems

- **MDM user scope excludes the user** → the device never enrolls → CA that requires compliance
  blocks them. Fix the scope, not the CA policy.
- **The Microsoft Intune Enrollment cloud app is not excluded** from a CA policy that requires MFA →
  silent enrollment can't obtain the required token (you may see enrollment error `0x8018002A`). The
  user completes MFA interactively to get an MFA-backed PRT, then enrollment proceeds.
- **Default "no policy = not compliant"** tenant setting (see compliance doc) → a device with no
  compliance policy targeted is blocked even though nothing is technically "wrong" with it.

> Rule of thumb: when CA blocks a device, first confirm whether the block is *identity* (PRT, MFA,
> token) or *compliance* (a real failing setting). The sign-in log's CA tab tells you which.
