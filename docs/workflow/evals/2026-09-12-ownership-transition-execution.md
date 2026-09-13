# Ownership-transition execution evaluation

This is a bounded warning-signal evaluation, not a release gate or a measured
quality claim. Each retained result used a fresh Codex subagent context once,
without retries. The evaluator model is inherited and not exposed by the
harness. Elapsed time is recorded as `<60s`: each run completed within its
single 60-second harness wait, which does not expose an exact duration.

Baseline forge, quest, and implementer instruction revision:
`284a0ea697feb3c34e9882235aca1e6465ac8406` (`origin/main` before #362).
Revised instruction revision: `8b19732b2c783d680824b8683320e8ec1686ac8b`.
The packets and expected traits are frozen in
`docs/workflow/specs/2026-09-12-ownership-transition-execution-design.md`.

| Case | Variant | Observed route and cited relationship | Result and limitation |
|---|---|---|---|
| OT-1 | baseline | Accepted: `policy.is_eligible` owns `u.status == "active"`; purchase, `renewal.renew`, and invoice import or call it. | The packet alone supplies structural migration evidence; tests do not directly prove every independent predicate was removed. |
| OT-1 | revised | Inconclusive: `renewal.renew(u) = is_eligible(u)` is a call, but invoice only shows an import. | It did not accept the packet's observable pass trait because an invoice call was not supplied. |
| OT-2 | baseline | Rejected: invoice imports `renewal.old_eligible`, whose independent `u.status == "active"` predicate remains. | Passing tests do not prove the required migration or duplicate removal. |
| OT-2 | revised | Rejected: it cited the retained `old_eligible` predicate and incomplete invoice migration. | The evaluator inaccurately described the packet's invoice import as a call and found no accepted compatibility reason. |
| OT-3 | baseline | Rejected: `renewal.eligible(u) = u.status == "active"` remains beside `renew(u) = is_eligible(u)`. | The result relies only on the supplied packet; no files or tests were inspected. |
| OT-3 | revised | Rejected: it identified the retained independent `eligible` predicate as a sole-owner violation. | It could not establish a protected compatibility contract from the packet. |
| OT-4 | baseline | Accepted: `renewal.eligible(u) = policy.is_eligible(u)` preserves ADR A-1 while all callers delegate to policy. | Passing tests do not independently prove every caller migrated. |
| OT-4 | revised | Accepted: it cited the delegating facade and sole predicate in `policy.is_eligible`. | It accepted the ADR-backed facade; it still relied on the packet for complete caller migration. |

The four baseline rows were rerun from the pre-change forge, quest, and
implementer instructions after a provenance correction; the original baseline
observations are superseded and omitted. All retained rows use the frozen
packet, matched instruction, and a fresh evaluator context. The observed error
and inconclusive outcome in the revised rows remain limitations; no retry or
prose assertion was added.
