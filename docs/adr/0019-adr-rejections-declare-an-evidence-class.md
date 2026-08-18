# 0019 — ADR rejections declare an evidence class

## Status

Accepted (2026-08-18)

## Context

`$spellcraft` requires an ADR to carry a `Considered & rejected` section and asks the ADR
review to challenge that list's completeness and honesty. Neither requires a rejection to
say how its ground was established: at `2a9d9ac`, `rg --no-config -n 'evidence'
skills/spellcraft/SKILL.md` returns five hits, none of them in the ADR section or in the
ADR-review focus.

A rejected alternative is a road nobody drives, so nobody re-tests the reason it was
rejected. An unverified rejection can therefore stand unchallenged, and any later decision
leaning on it inherits the error silently. Issue #137 reports the instance: one ADR carried
five load-bearing factual claims that turned out false, three of them rejection grounds.
The review loop did catch all three — but only because the reviewer reproduced them
independently, and only after the design had been reversed twice across five iterations.

Three settled constraints bound any fix. This repository forbids a gate asserting on prose.
`$spellcraft` bounds how long a record may run. And `rejected-with-evidence` is already a
`$trial-loop` finding disposition — eight hits across `skills/trial-loop/SKILL.md`,
`skills/quest/SKILL.md`, and `references/heed-counsel.md` at `2a9d9ac` — so it cannot also
name an ADR ground.

## Decision

Every `Considered & rejected` bullet opens with one of two tags declaring how its ground
was established:

- `verified:` — a **factual** ground, carrying the command run and what it produced. Name
  the environment wherever the result could depend on it — a commit, a released version, a
  platform — and name it durably: "this branch" is gone after the merge and the record is
  not. Where the ground is factual but no command settles it, `verified:` carries the
  source that does.
- `judgment:` — complexity, fit, taste, or cost. It carries no evidence; naming the class
  is the whole obligation beyond the ground itself.

Both are legitimate grounds. A judgment presented as a fact is not.

The tag classes the ground; the ground stays the sentence or two that sank the alternative.
What the tag **replaces** is the paragraph of justification behind that sentence, never the
sentence itself.

The `$spellcraft` ADR-review focus gains one clause: a rejection stated as fact but
carrying no evidence is a finding, as is a behaviour claim about a rejected alternative
that cannot be reproduced from what the bullet states.

`skills/spellcraft/SKILL.md` is the authority for this contract.
`skills/tome-of-lore/SKILL.md`'s ADR template restates it in one template line plus one
sentence naming `$spellcraft` as that authority.

Enforcement is by reading. No gate, script, or test checks for the tags.

## Consequences

A judgment ground costs less than the prose it displaces. A factual one often costs more,
because a command and its result run longer than the assertion they replace; what the
section buys for those lines is a rejection a later reader can re-run.

A writer who cannot evidence a factual ground has two honest exits — get the evidence, or
re-state the ground as the judgment it was — and one dishonest one, writing `verified:`
over nothing. Issue #138, the review-side half, is what closes that.

The contract covers rejection grounds only, and it is stated in two documents with nothing
detecting divergence between them. Both residuals are recorded in the design doc.

Records merged before this decision carry no tags and are not retrofitted, being immutable.
In one of those, a missing tag means "written earlier", not "unverified". In a later
record it means the rule was not followed, which is a finding for the reader who notices —
enforcement is reading, so nothing else will.

## Considered & rejected

**Require reproduction at review time (#138) and skip the tags.** verified: the repository
owner's comment on #137 settles it — reproduction without tagging leaves the next reader
unable to tell which grounds were checked.

**Cross-reference `$tome-of-lore`'s template from `$spellcraft` rather than restating the
rule.** judgment: a template is copied, not followed, so a pointer in `$spellcraft` leaves
the copied template silent about the rule — which is where the writer's hands are.

**Add a gate that checks ADRs for the tags.** judgment: a token-prefix check confirms only
that the token is present, the one part a writer skipping the work still types.

**Carry the classes in a separate `## Evidence` section.** judgment: a sixth section,
holding the class one scroll away from the claim it qualifies.

**Require "say how you know" with no fixed vocabulary.** judgment: an instruction with no
token to omit leaves a reviewer nothing to point at.

**Add a third class for a factual ground believed but not run.** judgment: a sanctioned
resting place for the claim this record exists to expose.

**Do nothing.** judgment: a clause per judgment ground and a command with its result per
factual one, against the reported instance's two design reversals across five review
iterations (#137).
