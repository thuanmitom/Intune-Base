# 03 — Compliance Policies

A compliance policy is a set of rules a device must satisfy to be considered "compliant." On its
own, compliance just produces a status. It becomes powerful when **Conditional Access** consumes
that status to allow or block access (see [`06-conditional-access.md`](06-conditional-access.md)).

---

## How the compliance engine thinks

Compliance is **device-centric**, not user-centric. A user can be blocked because *a* device they
use is non-compliant — even if their other devices are fine.

Two compliance states matter and they are **not** the same:

- **Intune compliant** — Intune's own evaluation of the device against your policies.
- **Microsoft Entra compliant** — the compliance signal as it reaches Entra (and therefore
  Conditional Access). A device can show Intune-compliant but Entra-not-compliant if the signal
  isn't flowing (stale check-in, PRT problem, device turned off).

Windows compliance is evaluated across these categories: device health, device properties,
Configuration Manager compliance (co-managed), system security, Microsoft Defender, and custom
compliance (your own script).

---

## The built-in default policy — the silent tripwire

There is a **tenant-level setting** at
`Endpoint security > Device compliance > Compliance policy settings`:

**"Mark devices with no compliance policy assigned as"**

- **Compliant (default)** — devices with no policy assigned are treated as compliant. Safe for
  onboarding, but weak for security.
- **Not compliant** — devices with no policy assigned are treated as non-compliant.

If you set this to **Not compliant** *and* use Conditional Access requiring compliance, then any
device that simply has **no compliance policy targeted** gets locked out — a very common
self-inflicted outage. When you flip this on, make sure every enrolled device is actually covered
by a policy.

---

## Grace periods — add them before you roll out

Every compliance policy has a built-in action, **"Mark device noncompliant,"** with a default of
**0 days**. That means the instant one setting fails, the device is non-compliant — and if CA
requires compliance, access is blocked immediately.

Add a **grace period** (commonly 1–7 days). During the grace period the device shows
**In Grace Period** rather than Non-compliant, and CA policies that require compliance still allow
access — giving users time to remediate without an instant lockout (and saving your helpdesk during
a rollout).

> **In Grace Period still counts as compliant for Conditional Access.**

---

## Evaluation timing

- Compliance re-checks roughly **every 8 hours**. A freshly enrolled device can lag before it
  reports compliant.
- A device that hasn't checked in for about **30 days** drifts to non-compliant — the classic
  "back from holiday" ticket.
- After changing a setting on the device, there's a delay before Intune reflects the new state;
  force a sync to speed it up.

---

## Custom compliance (Windows)

For rules the built-in settings don't cover, use a **custom compliance script** (PowerShell) plus a
**JSON** file that defines the expected values and the remediation message shown to the user. The
script runs via the IME, so its execution is logged in the IME logs, and script rules apply only
where the IME runs (Entra-joined / hybrid-joined, not merely Entra-registered).

---

## Common compliance settings by platform (starter set)

| Setting | Windows | iOS/iPadOS | Android | macOS |
| --- | --- | --- | --- | --- |
| Minimum OS version | ✅ | ✅ | ✅ | ✅ |
| Require BitLocker / encryption | ✅ | ✅ (device encryption) | ✅ | ✅ (FileVault) |
| Require Secure Boot | ✅ | — | — | — |
| Require a password/PIN + complexity | ✅ | ✅ | ✅ | ✅ |
| Jailbreak / root detection | — | ✅ | ✅ | — |
| Require Defender / threat level | ✅ | via MDE | via MDE | via MDE |
| Firewall enabled | ✅ | — | — | ✅ |

Keep the first policy minimal, confirm devices report compliant, then tighten. Rolling out a strict
policy with a 0-day grace period against an unprepared fleet is how you flood the helpdesk.

---

## When a device is non-compliant and you don't know why

Go to [`../troubleshooting/compliance-issues.md`](../troubleshooting/compliance-issues.md). The
usual suspects: 0-day grace period on a single failing setting, the default-policy tenant setting,
a stale check-in, or a PRT problem feeding a bad compliance claim into Conditional Access.
