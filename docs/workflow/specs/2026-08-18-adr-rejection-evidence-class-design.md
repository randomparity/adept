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
| R2 | A **factual** ground carries the command run and what it produced, plus the environment wherever the result could depend on it, named durably. Where the ground is factual but no command settles it, `verified:` carries the source that does. | #137 proposal step 1, as settled by ADR 0019 |
| R3 | A **judgment** ground says so with the token `judgment:`, and is legitimate without a command. Naming which class it is — complexity, fit, taste, cost — is optional colour, not the obligation. | #137 acceptance criterion 3; ADR 0019, "naming the class is the whole obligation" |
| R3b | The `$spellcraft` text states the non-exemption rule to the **writer**: the tag classes the ground and does not exempt a factual premise sitting inside it, so a `judgment:` resting on an unrun behaviour claim is the same defect wearing the other label. | ADR 0019 Decision; without it R4 finds against a writer for a rule their instructions never carried |
| R3c | Where a ground is both factual and judgment, the `$spellcraft` text says the bullet leads with `verified:`. | necessary consequence of R2 + R3: one tag opens the ground, and the factual half is the half that owes evidence |
| R4 | The ADR-review focus names as a finding a rejection stated as fact but carrying no evidence, and a rejected-alternative behaviour claim that cannot be reproduced from what the bullet states — whichever tag precedes it. Where a record carries no tags at all, the clause yields one observation that the record predates the contract rather than a finding per bullet. | #137 acceptance criterion 2, proposal step 2; non-retrofit consequence in ADR 0019 |
| R4b | The added focus clause states that a `verified:` ground's command and result are the ground rather than argument, so the focus's existing size clause does not read as an instruction to cut them. | necessary consequence of R4: the ADR reviewer sees only the focus string |
| R5 | `skills/tome-of-lore/SKILL.md`'s ADR template states the same requirement, so the two statements of the contract cannot drift. | dispatch brief criterion 4 |
| R6 | The existing size discipline holds. The `$spellcraft` text says what the tag displaces — the paragraph of justification behind the ground, never the sentence or two that states the ground — and carries one one-line example bullet per tag, a `verified:` one and a `judgment:` one. R6 is met when the displacement sentence and both examples are present; it is not a claim about record length. | #137 acceptance criterion 4 |
| R7 | `just verify` passes. | `CLAUDE.md`, *Verifying a change* |

## Non-requirements

- Making the reviewer *reproduce* a rejection's claim, and any dispatch or stop condition
  serving that — issue #138, the review-side half. `skills/trial-loop/SKILL.md` is
  untouched here; needing to change it means the work has crossed into #138.
- Any gate that checks an ADR's prose for the tags. Barred by `CLAUDE.md` anatomy rule 4.
- An ADR index row. `docs/adr/README.md` deliberately carries no index table.

## Design

### The vocabulary

Every `Considered & rejected` bullet names its alternative, then opens the ground that sank
it with one of two tags:

- `verified:` — a factual ground, carrying the command run and what it produced, plus the
  environment wherever the result could depend on it (a commit, a released version, a
  platform). The environment must be named durably: "this branch" is deleted on merge and
  the record is not. Where the ground is factual but no command settles it — a documented
  platform limit, an absent upstream API, a decision someone made — `verified:` carries
  the source that settles it instead.
- `judgment:` — complexity, fit, taste, or cost. No command; the token is the point, and
  naming which of the four applies is optional.

Two tags, not a spectrum. A third class ("plausible", "assumed") would be a place for an
unverified factual claim to hide with a blessing, which is the defect being closed.

The tag classes the ground, so it does not exempt a factual premise sitting inside that
ground (R3b): a `judgment:` resting on an unrun behaviour claim is the same defect wearing
the other label, and R4's reproduction clause bites on it. Where an alternative is sunk by
both a measured fact and a judgment, the bullet leads with `verified:` and states the
judgment after it (R3c) — the factual half is the half that owes evidence.

R6's "replaces rather than appends" governs what the tag displaces: the paragraph of
justification behind the ground, never the sentence or two that states the ground itself —
`$spellcraft` already requires that sentence. It is not a promise that every bullet
shrinks, either: a judgment ground costs less than the reasoning it displaces, and a
factual one often costs more, because a command and its result run longer than the
assertion they replace. What those lines buy is a rejection a later reader can re-run.

`verified:` and `judgment:` are new tokens. They deliberately avoid
`rejected-with-evidence`, which `references/heed-counsel.md:14` and
`skills/trial-loop/SKILL.md` already bind to a `$trial-loop` **finding disposition** —
a different object at a different layer.

### Where it is stated

Two places, both normative, because they are the two documents a writer reads:

1. `skills/spellcraft/SKILL.md`, immediately after the paragraph that bounds record size
   (the one ending "State the decision and stop.") and before the paragraph on ADR
   numbering — so the "replaces prose" framing lands where the size discipline is stated
   (R6). The five-section list above it, the numbering paragraph, and the spec self-review
   subsection are not disturbed.
2. `skills/tome-of-lore/SKILL.md`, at the ADR template's `Considered & rejected`
   placeholder line inside the fenced block — the line currently reading "Alternatives, and
   why each was not chosen." — extended in place to state the requirement, plus one
   sentence of prose immediately **below the closing fence** naming `$spellcraft` as the
   authority. The naming sentence stays outside the fence: text inside it is copied
   verbatim into every new record, and a sentence about which skill owns the rule is
   instruction, not record content. The five section headings, the status-line paragraph,
   and the supersession-banner block are not disturbed.

A cross-reference alone would not do: a template is copied rather than followed, so a
pointer sitting in `$spellcraft` leaves the copied template silent about the rule.

### Enforcement

Reading, not tooling. The ADR-review focus in `$spellcraft` step 2 gains one clause
covering R4, and it is passed to `$trial-loop` exactly as the rest of that focus already
is. No gate, no script, no test — `CLAUDE.md` anatomy rule 4 forbids one, and the gate in
`$tome-of-lore` already documents that it cannot see substance.

The added clause must also qualify the size clause already in that focus ("a record
arguing for its decision at greater length than the decision governs is a finding, and its
remedy is cutting rather than more text"). Otherwise one focus string supports both "this
rejection carries no evidence — add the command" and "this record is too long — cut", with
the evidence lines the obvious thing to cut. The reviewer runs in file-list mode against
the ADR with only the focus string, so the reconciliation has to be in the focus, not in
the writer-facing guidance: a `verified:` ground's command and result are the ground, not
argument, and are not what the size clause cuts.

The clause also has to survive being pointed at a pre-contract record. `$spellcraft` step 2
builds its changed-ADR set with `git diff --name-only <BASE_BRANCH>...HEAD -- docs/adr/`,
and a supersession adds a banner to the superseded record's own file — so a merged,
pre-contract ADR lands in the review set on every supersession PR. An unqualified clause
fires on each of that record's untagged bullets, and a merged record permits no edit but
the banner, so the loop burns iterations on findings nobody may fix. ADR 0019 states the
non-retrofit policy, but the reviewer never reads ADR 0019.

Whatever handles this has to be readable **from the record alone**: the reviewer gets one
file path and the focus string — no diff, no base ref, no adoption date. "The bullets this
change writes" is a test it cannot run, and a date threshold is one it cannot resolve,
since `$spellcraft` ships to repositories that adopt the contract on their own schedule.
What is readable is whether the record carries any tags at all. A wholly untagged record
predates the contract, so the clause yields one observation to that effect instead of a
finding per bullet. The residual is a post-contract writer who ignores the rule entirely
and gets one observation rather than several findings — still surfaced, just once.

## Testing

The change is skill prose. It is verified by:

- `just verify` — the repository guardrail suite, which covers skill shape, link
  resolution, public safety, and record form (R7).
- Reading the two edits back against the table above, requirement by requirement. R6 is
  the one with a concrete artifact: the `$spellcraft` text carries a one-line `verified:`
  example and a one-line `judgment:` example, or it does not.
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
