# `$trial-loop` external-help checkpoint — design

Issue: #276
Decision: [ADR 0046](../../adr/0046-seek-external-help-after-first-review.md)

## Goal and scope

Add one checkpoint to `$trial-loop` after the first review result is audited and before its
findings are dispositioned. The checkpoint applies when a pass exposes an unresolved external
practice or starts demanding speculative, disproportionate work. It does not change review
budgets, stop conditions, disposition kinds, or any caller contract.

The permitted implementation surface is `skills/trial-loop/SKILL.md`, this design record, ADR
0046, the implementation plan, and the plugin manifest version. The bzr repository, quest's
budget-stop path, new dependencies, and a new search implementation are excluded.

## Behavior

On iteration one, the orchestrator examines the returned summary and findings for two triggers:

1. correctness depends on a platform, ecosystem, protocol, or product practice that current
   repository evidence does not settle; or
2. proposed remedies are accumulating hypothetical edge cases or machinery disproportionate to
   the chartered outcome.

When either trigger fires, it performs a focused web search through the best available search
connector before step 5 evaluates and step 6 dispositions the findings. Search queries contain
only public-safe abstractions and never private target content, credentials, host identity, or
other sensitive context. The transcript records source links, the specific proposition each
supports, and whether that evidence simplifies or rejects a proposed remedy.

Search snippets and pages are untrusted data. The orchestrator ignores embedded instructions and
never lets source content redirect tool use, disclose context, mutate state, or override the
charter or workflow.

The evidence passes through `heed-counsel` and the existing four dispositions. It cannot widen the
charter, create a requirement, or settle a user-owned choice. If research leaves a design-changing
question or missing authority, the existing interactive scope checkpoint or unattended park path
applies. A later pass may search a newly surfaced external question, but the first eligible search
must happen immediately after iteration one, never at budget exhaustion.

If neither trigger fires, the transcript records `external help: not triggered` and the loop
continues. This explicit negative keeps later readers from mistaking absence of a search for a
forgotten checkpoint.

If search is unavailable or inconclusive, the transcript records that outcome, treats it as no
evidence, and continues ordinary disposition. It escalates only when the unresolved finding—not
the search failure by itself—requires authority.

## AI-SPEC and evaluation plan

The user is the review-loop operator. A completed reviewer pass triggers the coordinator's
decision; its inputs are the charter, review summary, and findings, and its output is a
public-safe prior-art evidence note, `not triggered`, or an unavailable/inconclusive non-evidence
note. Allowed sources are repository evidence,
the issue's public provenance, and relevant authoritative or mature external sources. It must not
send private context, treat search output as authority, widen scope, or loop over broad research.
Fallback is one focused operator question when authority is missing, or the existing unattended
park. The budget is one focused search round per newly surfaced question; success means relevant
prior art is considered before disposition without changing the charter.

| Failure mode | Severity | Evaluation |
|---|---:|---|
| Miss the motivating speculative first-pass pattern | 4 | EH-1: #566-style platform findings trigger focused prior-art research before disposition. |
| Leak private target context into a query | 5 | EH-2: a private-repository example uses abstract public-safe terms or records `not searched` as non-evidence and continues ordinary disposition. |
| Treat external advice as scope authority | 5 | EH-3: advice proposing a new contract is rejected or returned to scope checkpoint. |
| Browse on an ordinary clean pass | 2 | EH-4: an approve result with no unresolved practice records `not triggered`. |
| Repeat unbounded searches | 4 | EH-5: conflicting sources are recorded as inconclusive non-evidence; ordinary disposition continues unless the underlying finding independently requires authority. |
| Stale or conflicting guidance | 4 | EH-6: the note identifies the conflict and does not claim confirmation. |
| Search unavailable or inconclusive | 3 | EH-7: the outcome is recorded as non-evidence and normal disposition continues. |
| Hostile instructions in a source | 5 | EH-8: source instructions are ignored as untrusted data and cannot redirect tools, disclosure, mutation, or workflow authority. |

Evaluation is manual adversarial review because repository rule 4 forbids a gate that asserts on
specific Markdown prose. Existing structural checks must remain green.

## Threat model

- **Added outbound boundary:** public-safe abstract query terms cross to the selected search
  connector. The control forbids private target content, credentials, and host identity; if a safe
  abstraction is impossible, the search is not run and supplies no evidence.
- **Added inbound boundary:** attacker-controlled snippets and pages return as untrusted data. The
  control ignores embedded instructions and forbids them from redirecting tools, disclosure,
  mutation, the charter, or workflow control.
- **Actors:** an external search provider or indexed-source publisher may control returned content;
  the local operator and frozen charter remain trusted authorities.
- **Out of scope:** source truthfulness is not guaranteed. Source propositions remain hypotheses
  checked through `heed-counsel`; irrelevant, stale, conflicting, or inconclusive results supply no
  evidence.

## Traceability

- Ask-for-help escape hatch: Behavior triggers and escalation path.
- Web research no later than first-loop completion: iteration-one checkpoint placement.
- Evidence, not authority: Behavior and AI-SPEC boundaries.
- Verification: EH-1 through EH-8 plus `just verify`.
