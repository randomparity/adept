# Ownership-transition execution evaluation

This is a bounded warning-signal evaluation, not a release gate or a measured
quality claim. Each run used a fresh Codex subagent context once, without
retries. The evaluator model is inherited and not exposed by the harness.
Elapsed time is recorded as `<60s`: each run completed within its single
60-second harness wait, which does not expose an exact duration.

Baseline instruction revision: `d33b3780bc6c17ba53b10f20c1273a1a34d02277`.
Revised instruction revision: `8b19732b2c783d680824b8683320e8ec1686ac8b`.
The packets and expected traits are frozen in
`docs/workflow/specs/2026-09-12-ownership-transition-execution-design.md`.

| Case | Variant | Observed route and cited relationship | Result and limitation |
|---|---|---|---|
| OT-1 | baseline | Accepted: `policy.is_eligible` owns the predicate; purchase and invoice import it; `renewal.renew` calls it. | The evaluator asked for behavior-test evidence despite the packet's stated test result. It relied on the packet's assertion that no other predicate or facade exists. |
| OT-1 | revised | Inconclusive: `renewal.renew(u) = is_eligible(u)` is a call, but invoice only shows an import. | It did not accept the packet's observable pass trait because an invoice call was not supplied. |
| OT-2 | baseline | Rejected: `invoice.py` imports `renewal.old_eligible`, which retains `u.status == "active"`. | It correctly flagged the bypass, while noting runtime coverage is unspecified. |
| OT-2 | revised | Rejected: it cited the retained `old_eligible` predicate and incomplete invoice migration. | The evaluator inaccurately described the packet's invoice import as a call and found no accepted compatibility reason. |
| OT-3 | baseline | Rejected: `renewal.eligible(u) = u.status == "active"` remains beside `renew(u) = is_eligible(u)`. | It correctly identified the independent policy; passing behavior tests do not prove migration. |
| OT-3 | revised | Rejected: it identified the retained independent `eligible` predicate as a sole-owner violation. | It could not establish a protected compatibility contract from the packet. |
| OT-4 | baseline | Accepted: `renewal.eligible(u)` delegates to `policy.is_eligible(u)` under accepted ADR A-1. | It asked to confirm an import/call already stated by the packet and could not independently prove removed predicates. |
| OT-4 | revised | Accepted: it cited the delegating facade and sole predicate in `policy.is_eligible`. | It accepted the ADR-backed facade; it still relied on the packet for complete caller migration. |

All eight runs used the frozen packet, the matched baseline or revised
instruction, and a fresh evaluator context. The observed errors and
inconclusive outcomes remain limitations; no retry or prose assertion was
added.
