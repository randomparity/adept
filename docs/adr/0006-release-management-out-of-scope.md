# 0006 — Release management is out of scope

## Status

Accepted (2026-08-12)

## Context

The pipeline ends at merge and branch cleanup: `$quest` runs `$deliver`, then
`$return-to-town`, and `$clear-map` sweeps what landed. Nothing in this tree tags a
commit, writes a changelog, publishes release notes, deploys, or verifies a deployment.

For this repository that much is settled.
[ADR 0001](0001-distribution-via-plugin-marketplace.md) took the `version` field out of the
manifests: updates track the git SHA, every push to `main` is an update, and there is no
release to cut. The repository has no tags and no GitHub releases.

What was never stated is whether that reasoning extends to the *target* repositories the
skills operate on. Those are not adept — one may publish a crate, another may ship images on
a tag — so a reader who looks for the release stage finds nothing and cannot tell an omission
from a decision. Issue #50 reports that ambiguity, not a feature anyone has been blocked by.
The question it raises is whether a standalone artifact should exist, not which pipeline stage
is missing.

## Decision

**adept ships no release stage** — no tagging, changelog, release-notes, publishing,
deployment, or post-deployment verification skill for the target repositories the skills
operate on. This withholds an artifact, not a capability: a session asked to cut a release
still follows the target repository's own procedure, the way it follows any other repo-local
recipe. This repository's own case is ADR 0001's and is not reopened here. Note that "release"
already means two other things in this tree — releasing an issue whose blocker closed
(`$return-to-town`, `$sort-board`), and a protected `release/*` branch pattern
(`$clear-map`) — and neither is a software release.

One thing carries it: **no adept session has ever been asked to drive a release in a target
repository.** The question this record settles has therefore never arisen in practice — it
reaches adept only through this issue's hypothetical. Building a stage against a request that
has never arrived would be the speculative feature the construction standards refuse, and the
ground is chosen for standing still rather than for weight: it names no counts, cites no other
repository, and changes only when the revisit condition below fires — which is exactly when
this decision should be reopened.

**Revisit condition.** Reopen this the first time an adept session is asked to drive a
release in a target repository — the ground's negation, and the first moment a real job
exists to design against. Nothing here notices the event on its own: `$warding`'s staleness
sweep selects records whose `## Status` reads `Open` and whose `review-by:` has passed, an
Accepted ADR carries neither, so a sighting is worth a new issue citing this record.

## Consequences

- README's workflow section gains a one-line pointer to this record, the convention it
  already uses for the ADRs it cites. That pointer is what makes the absence findable; the
  record alone would not, because the index here is deliberately the directory listing.
- Nothing else in `README.md` or `docs/cheatsheet.md` changes. The lifecycle they draw is
  complete — no stage is missing from it.
- `$restock` and `$warding` remain the only version-adjacent surfaces — one merges dependency
  updates, the other reports version drift and advisories. Neither publishes anything, and
  neither changes.
- There is no post-merge verification stage either, and the residual starts closer than it
  looks. Where a target repository publishes on merge to `main`, that publish is fired by the
  merge `$return-to-town` itself performs, and nothing here reads the workflow run it triggers.
  A publish that fails on registry auth, a version collision, or a missing tag permission goes
  unobserved while the session reports the issue done. That inaccurate report is adept's own
  and not the target repository's to fix; it is accepted here because watching a foreign
  workflow run is the machinery this record declines, and it is tracked as issue #65 against
  `$return-to-town`.

## Considered & rejected

- **Ship a `$release` skill now — tag, changelog, `gh release create`**, including the
  deliberately minimal version alongside this record. The issue's first option. Rejected —
  judgment: with no known request for adept to drive a release, its procedure would encode
  guesses where one real request would settle the requirements. A minimal one is the worst
  case rather than the safe one, since it would hard-code defaults nothing has chosen.
- **Ship a skill that drives each target repository's own release recipe rather than
  re-encoding policy** — tag when its workflow tags, publish when its CI publishes. This is
  the scope-in variant that survives the duplication objection, so it is weighed on the
  record's actual ground and still rejected — judgment: with no recipe-following job ever
  having arrived, formalising delegation that the Decision already states as ordinary
  practice buys enforcement nothing has asked for — status quo enforced, not a gap filled.
- **Write `references/release.md` instead of a skill.** This repository's other artifact type —
  a standard consulted rather than a procedure invoked — and the cheaper shape, carrying no
  script pressure and no invocation surface. Rejected on the same ground — judgment: it
  documents a procedure nothing has been asked to run, so the saving is in the packaging,
  not the content.
- **Write the delegation into `$attunement` — have it discover the target's release recipe the
  way it discovers guardrail commands.** The cheapest scope-in, and the closest to what already
  happens. Rejected — judgment: it is already the status quo the Decision states, so it would
  buy enforcement of a rule nothing has broken; and editing an existing skill is outside this
  issue's scope. Worth revisiting if delegation ever needs to be enforced rather than assumed.
- **Record the decision only as a line in `README.md` or `docs/cheatsheet.md`, with no record
  here.** The issue's second option, and cheaper. Rejected — judgment: a line in a
  which-skill-do-I-run table carries the outcome without the reasoning that makes it a
  decision, and has nowhere to keep the revisit condition. The line itself was not rejected —
  the Consequences take it, pointing here.
- **A post-merge verification skill only, dropping tagging and changelog.** The narrowest
  scope-in. Rejected — judgment: the same absence of any driving request, though this is the
  alternative closest to a real gap, and the part of it that is adept's own is real:
  verified: issue #65 tracks it against `$return-to-town`.
- **A deferral record under `docs/debt/` rather than a record here.** Rejected — judgment:
  the trigger here is an event — a session being asked — and `review-by:` fires on a date, so
  the sweep would re-ask the question on an arbitrary day with no new evidence to answer it.
- **Leave it undecided.** Rejected — verified: issue #50's body reports exactly this state,
  a reader who cannot tell an omission from a decision; the cost was never the missing
  skill, but the unreadability.
