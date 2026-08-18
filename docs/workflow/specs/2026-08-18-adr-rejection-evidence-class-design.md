# ADR rejections declare an evidence class — design

Issue: [#137](https://github.com/randomparity/adept/issues/137)
Decision record: [ADR 0019](../../adr/0019-adr-rejections-declare-an-evidence-class.md)

## Problem

`$spellcraft` requires an ADR to carry a `Considered & rejected` section and asks the
ADR review to challenge that list's completeness and honesty. Neither requires a
rejection to say **how its ground was established**.

That leaves the highest-risk claims in a decision record unmarked. A rejected
alternative is a road nobody drives, so nobody re-tests the reason it was rejected. An
unverified rejection can stand unchallenged for years, and any later decision leaning on
it inherits the error silently.

The reported instance (issue #137, from a session on `randomparity/hmc-mcp`) had five
load-bearing factual claims turn out false, three of them rejection grounds, two of which
reversed the design after the fact. Each read as a technical finding. None had been run.
The chosen option's claims *were* verified — verification tracked the author's prior
belief rather than the claim's load.

## Requirements

| # | Requirement | Source |
|---|---|---|
| R1 | The ADR section of `skills/spellcraft/SKILL.md` requires an evidence class on every `Considered & rejected` bullet. | #137 acceptance criterion 1 |
| R2 | A **factual** ground carries inline evidence — the command run, the observed result, and the environment it ran in. | #137 proposal step 1 |
| R3 | A **judgment** ground (complexity, fit, taste, cost) says so in those words, and is legitimate without a command. | #137 acceptance criterion 3 |
| R4 | The ADR-review focus names as a finding a rejection stated as fact but carrying no evidence, and a rejected-alternative behaviour claim that cannot be reproduced from what the bullet states. | #137 acceptance criterion 2, proposal step 2 |
| R5 | `skills/tome-of-lore/SKILL.md`'s ADR template states the same requirement, so the two statements of the contract cannot drift. | dispatch brief criterion 4 |
| R6 | The existing size discipline holds: the guidance shows the evidence tag **replacing** reasoning prose, not appended to it. | #137 acceptance criterion 4 |
| R7 | `just verify` passes. | `CLAUDE.md`, *Verifying a change* |

## Non-requirements

- Making the reviewer *reproduce* a rejection's claim, and any dispatch or stop condition
  serving that — issue #138, the review-side half. `skills/trial-loop/SKILL.md` is
  untouched here; needing to change it means the work has crossed into #138.
- Any gate that checks an ADR's prose for the tags. Barred by `CLAUDE.md` anatomy rule 4.
- An ADR index row. `docs/adr/README.md` deliberately carries no index table.

## Design

### The vocabulary

Every `Considered & rejected` bullet opens with one of two tags:

- `verified:` — a factual ground, carrying the command run, what it produced, and the
  environment it ran in, named durably (a commit, a released version, a platform) so a
  later reader can return to it. "This branch" is not an environment: the branch is
  deleted on merge, and the record is immutable. Where the ground is factual but no
  command settles it — a documented platform limit, an absent upstream API, a decision
  someone made — `verified:` carries the source that settles it instead.
- `judgment:` — complexity, fit, taste, or cost. No command; the label is the point.

Two tags, not a spectrum. A third class ("plausible", "assumed") would be a place for an
unverified factual claim to hide with a blessing, which is the defect being closed.

`verified:` and `judgment:` are new tokens. They deliberately avoid
`rejected-with-evidence`, which `references/heed-counsel.md:14` and
`skills/trial-loop/SKILL.md` already bind to a `$trial-loop` **finding disposition** —
a different object at a different layer.

### Where it is stated

Two places, both normative, because they are the two documents a writer reads:

1. `skills/spellcraft/SKILL.md`, immediately after the paragraph that bounds record size —
   so the "replaces prose" framing lands where the size discipline is stated (R6).
2. `skills/tome-of-lore/SKILL.md`, in the shipped ADR template block, where a writer
   copying the template sees it (R5).

The tome-of-lore statement is the template line plus one sentence naming the two tags and
naming `$spellcraft` as the authority for them. It is not a second, fuller specification.
A cross-reference alone would not do: a template is copied rather than followed, so a
pointer sitting in `$spellcraft` leaves the copied template silent about the rule.

### Enforcement

Reading, not tooling. The ADR-review focus in `$spellcraft` step 2 gains one clause
covering R4, and it is passed to `$trial-loop` exactly as the rest of that focus already
is. No gate, no script, no test — `CLAUDE.md` anatomy rule 4 forbids one, and the gate in
`$tome-of-lore` already documents that it cannot see substance.

## Testing

The change is skill prose. It is verified by:

- `just verify` — the repository guardrail suite, which covers skill shape, link
  resolution, public safety, and record form (R7).
- ADR 0019 itself, whose `Considered & rejected` section is written to the new contract.
  It is the first record under the rule and the worked example of it; a rule its own
  founding record cannot follow is the wrong rule.
- Reading: `$trial-loop` against ADR 0019, this spec, and the plan.

## Risks

- **Drift between the two statements.** Nothing detects it — anatomy rule 4 forbids a
  gate. Reduced, not closed, by keeping tome-of-lore's to a template line plus one
  sentence that names `$spellcraft` as the authority, so a reader who finds either finds
  the other.
- **Claims outside the rejection list stay untagged.** The reported instance also carried
  false load-bearing claims elsewhere in the record. Accepted residual: rejections are the
  claims nobody re-tests, and tagging every factual sentence would bloat what R6 protects.
- **Tag theatre** — `verified:` written without running anything. Not closed here by
  construction; R4's review clause is what catches it, and issue #138 is the half that
  makes the reviewer check. Stated so the residual is on the record rather than assumed
  away.
