# Scoped ownership choices in feature design — issue #361

Charter: issue #361 `WORK:SCOPE` token `q361-7e3b9c41`; operator-approved
exclusions and epic #360 direction are retained there. Design denominator: 250
changed lines (M), from the three coordinated skill contracts and bounded evaluation.

## Problem

Current instructions favor extending established patterns and treat restructuring mainly
as an unwieldy-file split. A feature can therefore preserve duplicated policy or misplaced
ownership despite passing behavioral tests. The scope freeze does not explicitly investigate
responsibilities and callers, so design can mistake the current file layout for authority.

## Scope and behavior

`$quest` inspects the responsibilities affected by each criterion, direct callers, and
shared dependencies before freezing the permitted surface. The investigation stops at the
affected behavior; it is not a repository inventory. Its existing scope fields capture the
current and intended ownership, possible caller migration and obsolete paths, and protected
public, persisted, security, or accepted-decision contracts where relevant. Unrelated cleanup
and contract changes without external authority return to SCOPE CHECKPOINT.

`$spellcraft` compares a clean extension with a credible reuse, move, consolidation,
replacement, or deletion when evidence shows duplicate policy, misplaced responsibility, or
avoidable indirection. No relocation is required for a clean extension. The existing spec
and file map link each intended owner, caller migration, removal, and retained compatibility
path to a criterion and reason. Light specs fit this into their existing sections and caps.
The same comparison applies to plan choices; a small file count is not a scope argument.

`$oathbind` checks that those links actually form a complete, authorized transition,
including affected callers and justified leftovers. It compares the smallest viable design
without treating a move itself as unauthorized expansion. It still checkpoints unapproved
public or persisted contracts, accepted-decision conflicts, and unrelated restructuring.
Implementation and branch-review enforcement remain issue #362.

### Failure model

- Actor: designer or auditor using incomplete repository evidence.
- Boundary: issue/epic authority versus current source layout and generated design.
- Failure: a missed caller, compatibility path, or contract can make a plan incomplete;
  a gratuitous move can enlarge the change.
- Response: preserve the uncertainty in existing scope/design/audit content and use the
  existing checkpoint when a criterion or protected contract cannot justify the change.

## Decision

[ADR 0061](../../adr/0061-scoped-ownership-is-a-design-choice.md) records the choice to
make bounded ownership changes available within existing authority and artifacts.

## Change surface

| File | Responsibility |
|---|---|
| `skills/quest/SKILL.md` | Investigate affected ownership before scope freeze and carry the result in existing fields |
| `skills/spellcraft/SKILL.md` | Compare extension and ownership alternatives; map selected transition in existing spec/plan |
| `skills/oathbind/SKILL.md` | Audit authorized owner, caller, and obsolete-path coverage |
| `.claude-plugin/plugin.json` | Apply reserved 5.5.0 version |
| `docs/workflow/evals/2026-09-12-scoped-ownership.md` | Record bounded matched-input baseline/revised decisions and limitations |

## Success and verification

The duplicated-policy case should select a coherent owner and caller migration, or cite
evidence that consolidation is inappropriate. The clean-extension case should avoid
gratuitous moves. Read both decisions and plans for protected-contract handling and
unjustified leftover paths; report failures and uncertainty. Run `just verify` for
structural and repository gates. No gate asserts on instructional prose.

### AI surface evaluation plan

User: a feature designer. Trigger: feature scoping/design. Inputs: a synthetic repository
case and either baseline or revised skill instructions. Output: a proposed scope/design
decision, file map, and validation plan. Allowed sources: the case packet and supplied
instructions. Disallowed: invented contracts, unrequested sibling work, or silent changes
to public/persisted/security contracts or accepted decisions. Fallback: checkpoint on
insufficient evidence. Budget: two cases × two instruction variants, one fresh context per
run, no retries; elapsed time and model/harness are reported. Success signal: observed
decisions and transition completeness, not presence of prescribed phrases.

Failure modes are duplicated policy left in two owners (severity 4), gratuitous move in
the clean case (4), omitted caller migration or unjustified compatibility path (4), and
silent protected-contract rewrite (5). Freeze these cases before implementation:

| ID | Input and setup | Observable pass traits | Forbidden traits | Gate |
|---|---|---|---|---|
| OW-1 | Synthetic Python checkout: `purchase.py` and `renewal.py` each decide eligibility from the same status rules; `invoice.py` calls renewal; a new `suspended` status must be handled consistently. A public `eligible(user)` signature is protected by an accepted decision. | One policy owner or a cited reason consolidation is inappropriate; both entry points and `invoice.py` accounted for; obsolete duplicate removed or justified; public signature preserved. | Two independently maintained policy rules, missing caller migration, silent public-signature change. | warn |
| OW-2 | Synthetic Python notifier: `notify.py` alone owns delivery preferences; one new `digest` preference fits its current interface and callers. | Extend that owner with focused validation and no gratuitous move. | New policy layer or relocation without a criterion. | warn |

Run each packet unchanged under the pre-change `origin/main` instruction revision and the
revised commit, using fresh model contexts. A protected-signature conflict is a separate
probe within OW-1: ask whether an internal consolidation may remove `eligible(user)`;
the correct answer checkpoints that removal while still deciding the internal ownership
option. If the output collapses these decisions or the case cannot expose the conflict,
mark that dimension inconclusive rather than passed. Record both revision SHAs and raw
outputs privately; the public report summarizes decisions and limitations. Repo guardrails
remain blocking.

## Exclusions

Issue #362 owns implementation and branch-review transition enforcement; #363 owns
standing authority; #364 owns four-language evaluation. Unrelated restructuring requires
a scope checkpoint. Existing claim, tracking, review, and merge protocols remain unchanged.
