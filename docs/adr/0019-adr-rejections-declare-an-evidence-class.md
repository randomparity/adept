# 0019 — ADR rejections declare an evidence class

## Status

Accepted (2026-08-18)

## Context

`$spellcraft` requires an ADR to carry a `Considered & rejected` section and asks the ADR
review to challenge that list's completeness and honesty. Neither requires a rejection to
say how its ground was established, and the word `evidence` appears nowhere in the ADR
section or its review focus.

A rejected alternative is a road nobody drives, so nobody re-tests the reason it was
rejected. An unverified rejection therefore stands unchallenged for years, and any later
decision leaning on it inherits the error silently. Issue #137 reports the instance: of
five load-bearing factual claims in one ADR, three were false and all three were rejection
grounds; two reversed the design after the fact. The chosen option's claims were verified.
That asymmetry is the tell — verification tracked the author's prior belief rather than the
claim's load.

The constraint on any fix is that this repository forbids a gate asserting on prose, and
`$spellcraft` already bounds how long a record may run.

## Decision

Every `Considered & rejected` bullet opens with one of two tags declaring how its ground
was established:

- `verified:` — a **factual** ground. It carries the command run, what that command
  produced, and the environment it ran in.
- `judgment:` — complexity, fit, taste, or cost. It carries no command; naming the class
  is the whole obligation.

Both are legitimate grounds. A judgment presented as a fact is not.

The tag **replaces** the reasoning prose it summarises rather than prefixing it, so the
record's existing size bound holds. The `$spellcraft` ADR-review focus gains one clause:
a rejection stated as fact but carrying no evidence is a finding, as is a behaviour claim
about a rejected alternative that cannot be reproduced from what the bullet states.

`skills/spellcraft/SKILL.md` is the authority for this contract.
`skills/tome-of-lore/SKILL.md`'s ADR template restates it in one template line plus one
sentence — short enough that divergence between the two is visible on sight.

Enforcement is by reading. No gate, script, or test checks for the tags.

## Consequences

Every ADR written under `$spellcraft` from here on costs one clause per rejected
alternative, and gives back the paragraph of reasoning that clause displaces. A writer who
cannot produce a command for a factual ground has two honest exits — run it, or re-state
the ground as the judgment it actually was — and one dishonest one, writing `verified:`
over nothing, which this record does not close. Issue #138 is the half that makes the
reviewer check.

Records written before this decision carry no tags and are not retrofitted; they are
immutable once merged. The tags are therefore a signal whose absence means only "written
earlier", not "unverified", until the pre-#137 records age out.

Two documents now state one contract, which is a drift surface this repository normally
refuses. It is accepted here because the template in `$tome-of-lore` is where a writer
copying a record looks, and `$spellcraft` never references `$tome-of-lore` — a writer
following one of them would otherwise never see the rule.

## Considered & rejected

**Reuse `rejected-with-evidence` as the factual tag.** verified: `rg --no-config -n
'rejected-with-evidence' -g '!docs/' .` returns eight hits across
`skills/trial-loop/SKILL.md`, `skills/quest/SKILL.md`, and `references/heed-counsel.md`,
where the token names a `$trial-loop` finding disposition (this branch, ripgrep 15.2.0,
macOS 26.6.1). One token, two layers.

**Add a gate that checks ADRs for the tags.** verified: `rg --no-config -n 'Nothing
automated asserts on prose' CLAUDE.md` returns line 21, the repository anatomy rule
forbidding it (this branch, same host). `$tome-of-lore` separately documents that its
record gate cannot see substance.

**State the rule only in `$tome-of-lore`'s template.** verified: `rg --no-config -n
'tome-of-lore' skills/spellcraft/SKILL.md` exits 1 with no match (at `main`, same host),
so a writer following `$spellcraft`'s own section list never reaches the template.

**Carry the classes in a separate `## Evidence` section.** judgment: a sixth section in a
five-section record, holding the class one scroll away from the claim it qualifies — the
two drift, and the section is pure addition against a size bound this decision must respect.

**Require "say how you know" with no fixed vocabulary.** judgment: the reported failure is
prose that already reads like a technical finding. An instruction with no token to omit
leaves a reviewer nothing to point at.

**Add a third class for a factual ground believed but not run.** judgment: a sanctioned
resting place for exactly the claim this record exists to expose.

**Do nothing.** verified: `rg --no-config -n 'evidence' skills/spellcraft/SKILL.md`
returns five hits at `main`, none of them in the ADR section or the ADR-review focus (same
host) — the gap is present, not merely alleged.
