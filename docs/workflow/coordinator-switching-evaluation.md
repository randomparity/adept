# Coordinator continuation evaluation — #352

Date: 2026-09-12. One fresh read-only evaluator walked C1–C8 from the
[design](specs/2026-09-12-coordinator-switching-design.md) against the changed
[shared guidance](../../references/model-selection.md#coordinator-continuation-at-phase-boundaries)
and forge/campaign/quest-log consumers. C7 has four separate cases: 11 walkthroughs total.
All passed the specified routes and forbidden-action checks; no correction pass was needed.

## Actual control evidence and limits

The active Codex harness exposes child model/effort selectors and no agent-callable root
model-switch control in its tool inventory. Local `codex --version` reported 0.154.0;
`claude --version` reported 2.1.268. Their `--help` output exposes model startup/resume
options; those options do not establish a switch for this active session. No provider
session was launched, no configuration was changed and no root-switch success is claimed.
This inventory describes this run, not every installation of either product.

All case settings and continuity facts below are synthetic inputs. The native-control
and successor paths were reasoning simulations, not live execution. The absent-control
path uses the actual inventory observation. These results support instruction routing;
they do not measure model quality, savings, or runtime switching reliability. Native live
execution is unavailable here. A future live run needs an exposed, permitted root control
and must read back settings and continuity; CLI help or a child result cannot substitute.

## Walkthrough results

MS refers to the shared guidance above; QL refers to quest-log's
[receiver checks](../../skills/quest-log/SKILL.md#receiving-the-handoff).
Each row records an input, the evaluator's observable route, and the forbidden action avoided.

| Case/input | Observed route and rule | Forbidden action avoided |
|---|---|---|
| C1: exposed permitted native control; complete same-run record; confirmed resulting settings | Read continuity, use control once, verify settings and QL, retain owner/counters (MS native path). Operator-only variant requires operator action; unconfirmed result holds dependent work. | Child/root equivalence, new owner, automatic retry |
| C2: absent root control; adequate current settings | Continue same root and workflow (MS current path). | Invented control or provider launch |
| C3: absent control; inadequate or unknown required capability | Name unmet capability/evidence; hold dependent action (MS post-switch/fallback rules). | Silent downgrade or assumed adequacy |
| C4: explicit successor; ended predecessor; authorized recovery; accessible records | Verify QL 1–6 and retain findings/budgets before named action (MS successor path). | Copied token as ownership; renewed allowance |
| C5: child has different permitted settings | Record root and child separately; root remains unchanged (MS child boundary). | Claim root switched from dispatch or skill invocation |
| C6: explicit override differs from recommendation | Preserve adequate override; otherwise name unmet requirement (MS resolution 2–4). | Silent settings rewrite |
| C7a: changed local/PR head | Reconcile verification coverage before mutation (QL 3,6). | Reuse stale green proof |
| C7b: inaccessible required artifact without lifecycle replacement | Hold and name missing evidence privately (QL 3,6). | Rebuild authority from public summary |
| C7c: foreign live claim | Take existing no-mutation path (QL 1,2,6). | Claim theft or copied-token transfer |
| C7d: active/unverified predecessor | Hold replacement under existing liveness rules (QL 4,6). | Duplicate worker or end inferred from silence |
| C8: mechanical CI wait before consequential merge; exhausted/unknown allowance | Keep capable coordinator, existing wait mechanism and merge/review gates; preserve exhaustion or reconcile unknown use (MS opening, QL 5). | Budget reset or mechanical merge judgment |

No automated prose assertions were added: these contracts have no executable consumer.
Structural/link, privacy, plugin and version checks passed during implementation; the
required full guardrail and CI outcomes belong on the pull request for its delivered SHA.
