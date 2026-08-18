# 0019 — ADR rejections declare an evidence class

## Status

Accepted (2026-08-18)

## Context

`$spellcraft` requires an ADR to carry a `Considered & rejected` section and asks the ADR
review to challenge that list's completeness and honesty. Neither requires a rejection to
say how its ground was established; the word `evidence` appears nowhere in the ADR section
or in its review focus.

A rejected alternative is a road nobody drives, so nobody re-tests the reason it was
rejected. An unverified rejection stands unchallenged for years, and any later decision
leaning on it inherits the error silently. Issue #137 reports the instance: one ADR carried
five load-bearing factual claims that turned out false, three of them rejection grounds,
two of which reversed the design after the fact. Each read as a technical finding. None had
been run.

Two things already settled constrain any fix: this repository forbids a gate asserting on
prose, and `$spellcraft` bounds how long a record may run.

## Decision

Every `Considered & rejected` bullet opens with one of two tags declaring how its ground
was established:

- `verified:` — a **factual** ground. It carries the command run, what that command
  produced, and the environment it ran in, named so a later reader can return to it: a
  commit, a released version, a platform, never "this branch". Where the ground is factual
  but no command settles it — a documented platform limit, an absent upstream API, a
  decision someone made — `verified:` carries the source that settles it instead of a
  command.
- `judgment:` — complexity, fit, taste, or cost. It carries no evidence; naming the class
  is the whole obligation.

Both are legitimate grounds. A judgment presented as a fact is not.

The tag **replaces** the reasoning prose it summarises rather than prefixing it, so the
record's existing size bound holds. The `$spellcraft` ADR-review focus gains one clause: a
rejection stated as fact but carrying no evidence is a finding, as is a behaviour claim
about a rejected alternative that cannot be reproduced from what the bullet states.

`skills/spellcraft/SKILL.md` is the authority for this contract.
`skills/tome-of-lore/SKILL.md`'s ADR template restates it in one template line plus one
sentence naming `$spellcraft` as that authority, so a reader who finds either finds the
other.

Enforcement is by reading. No gate, script, or test checks for the tags.

## Consequences

Each rejected alternative costs one clause, and gives back the reasoning that clause
displaces.

A writer who cannot evidence a factual ground has two honest exits — get the evidence, or
re-state the ground as the judgment it always was — and one dishonest one, writing
`verified:` over nothing. This record does not close that. Issue #138, the review-side
half, is what makes the reviewer check.

The contract covers rejection grounds only. #137's instance also carried false load-bearing
claims outside the `Considered & rejected` list, and those stay untagged. That residual is
accepted: rejections are the claims nobody re-tests, and tagging every factual sentence in
a record would bloat exactly what the size bound protects.

Records merged before this decision carry no tags and are not retrofitted, being immutable.
A missing tag therefore means "written earlier", not "unverified", until those records age
out.

The contract is stated in two documents and nothing detects divergence between them. That
is a drift surface this repository normally refuses.

## Considered & rejected

**Reuse `rejected-with-evidence` as the factual tag.** verified: `rg --no-config -n
'rejected-with-evidence' -g '!docs/' .` returns eight hits across
`skills/trial-loop/SKILL.md`, `skills/quest/SKILL.md`, and `references/heed-counsel.md`,
where the token names a `$trial-loop` finding disposition (at `2a9d9ac`, ripgrep 15.2.0,
macOS 26.6.1). One token, two layers.

**Cross-reference `$tome-of-lore`'s template from `$spellcraft` rather than restating the
rule, avoiding the drift surface above.** verified: `rg --no-config -n 'tome-of-lore'
skills/spellcraft/SKILL.md` and `rg --no-config -n 'spellcraft'
skills/tome-of-lore/SKILL.md` both exit 1 with no match (at `2a9d9ac`, same host), so one
clause closes the gap — in one direction only. A template is copied, not followed: a
pointer in `$spellcraft` leaves the copied template silent about the rule, which is where
the writer's hands are.

**Add a gate that checks ADRs for the tags.** judgment: cost against a false green.
`CLAUDE.md` welcomes a structural gate and a token-prefix check is structural, but it can
only confirm the token is present — the one part a writer skipping the work still types.
It would buy a green that means less than reading does. #137's scope excludes it.

**Carry the classes in a separate `## Evidence` section.** judgment: a sixth section in a
five-section record, holding the class one scroll away from the claim it qualifies.

**Require "say how you know" with no fixed vocabulary.** judgment: the reported failure is
prose that already reads like a technical finding. An instruction with no token to omit
leaves a reviewer nothing to point at.

**Add a third class for a factual ground believed but not run.** judgment: a sanctioned
resting place for exactly the claim this record exists to expose.

**Do nothing.** judgment: one clause per bullet, against an unverified rejection ground
standing for years and reversing a later design twice. The trade is not close. That the gap
is real is not in dispute — verified: `rg --no-config -n 'evidence'
skills/spellcraft/SKILL.md` returns five hits at `2a9d9ac`, none of them in the ADR section
or the ADR-review focus (same host).
