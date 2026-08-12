# 0005 — Release management is out of scope

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

The question is about a standalone skill rather than a missing stage. `$quest` is per-issue
and `$campaign` drains a queue of them; a release batches many merges and fires when a human
judges the batch ready. A release step inside `$quest` or `$return-to-town` would run once per
issue, so the pipeline's ending is not where the answer lies.

## Decision

**adept ships no release stage, and release management is out of scope for its skills** — no
tagging, changelog, release-notes, publishing, deployment, or post-deployment verification
skill, for this repository or for the target repositories the skills operate on.

Two things carry it.

**There is no repetition to generalise from.** The standard this repository works to is no
utility until the third repetition. adept has not been asked to drive a release in any target
repository even once, and its own repository deliberately has none. A skill written now would
be designed against an imagined consumer, and the construction rules compound that: a release
skill that is only instructions reduces to two commands a session already runs correctly, and
one that adds value would need scripts — which anatomy rule 2 admits only for work a model
cannot do reliably inline.

**Release policy is repository-specific and already owned.** Semver against calver against
SHA; a changelog handwritten against one generated from commits; publishing by tag-triggered
workflow against by hand. Purpose-built tools already own the mechanics per ecosystem —
release-please, semantic-release, changesets, goreleaser, cargo-release. A skill would encode
one repository's policy and be wrong for the next, or degrade into "read this repository's
release documentation and run its release command", which is what a session does without a
skill.

**Revisit condition.** Reopen this when adept has driven a release by hand in a target
repository three separate times, and those three share enough policy that one instruction file
would have served all of them — the third-repetition rule, and the evidence this decision
lacks today. Nothing counts to three: those releases happen in other repositories and leave no
trace in this one, `$warding`'s review-by sweep reads `docs/debt/` rather than `docs/adr/`, and
no other sweep watches this record. So reopening depends on a reader raising it, and issue #50
is where a sighting is worth writing down. The gap runs the other way too, and is worth saying
plainly: the premise that no such release has been driven is an observation about sessions, not
a fact any artifact here can confirm.

## Consequences

- README's workflow section gains a one-line pointer to this record, the convention it already
  uses for ADRs 0001, 0002 and 0003. That pointer is what makes the absence findable; the
  record alone would not, because the index here is deliberately the directory listing.
- Nothing else in `README.md` or `docs/cheatsheet.md` changes. The lifecycle they draw is
  complete — no stage is missing from it.
- A target repository that needs a release keeps its own tooling. Nothing here stops a session
  running `git tag`, `gh release create`, or a repository's release recipe when asked: this
  withholds a skill, not a capability.
- `$restock` and `$warding` remain the only version-adjacent surfaces — one merges dependency
  updates, the other reports version drift and advisories. Neither publishes anything, and
  neither changes.
- There is no post-merge verification stage either. `$return-to-town` confirms the merge landed
  and reconciles cleared dependents; whether the merged code works once deployed is the target
  repository's own CI's answer.

## Considered & rejected

- **Ship a `$release` skill now — tag, changelog, `gh release create`.** The issue's first
  option, and the reading that treats the gap as real. Rejected on both grounds above, the
  first of which is sufficient alone: there is no target repository whose release this one has
  been asked to drive, so the skill would be designed against an imagined consumer.
- **Record the decision only as a line in `README.md` or `docs/cheatsheet.md`, with no record
  here.** The issue's second option, and cheaper. Rejected because a line in a
  which-skill-do-I-run table carries the outcome without the reasoning that makes it a
  decision, and has nowhere to keep the revisit condition. The line itself was not rejected —
  the Consequences take it, pointing here.
- **Both — this record plus a deliberately minimal release skill.** Rejected as paying the
  skill's maintenance cost to avoid making the decision.
- **A post-merge verification skill only, dropping tagging and changelog.** The narrowest
  scope-in. Rejected because `$return-to-town` already verifies the merge landed, and whether
  deployed code works is the target repository's CI's answer rather than a skill's.
- **A deferral record under `docs/debt/` rather than a record here.** Rejected because a
  deferral says work is coming later, and this is a decided exclusion. `just records` also
  enables only the `adr` profile, so this would mean turning on `debt` for something that is
  not a deferral.
- **Leave it undecided.** Rejected as the state the issue reports: the cost was never the
  missing skill, but that a reader could not tell absence from oversight.
