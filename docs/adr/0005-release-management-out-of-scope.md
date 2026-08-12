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
The question it raises is whether a standalone artifact should exist, not which pipeline stage
is missing: a release batches many merges and fires when a human judges the batch ready, so it
was never going to sit inside a per-issue run.

## Decision

**adept ships no release stage, and release management is out of scope for its skills** — no
tagging, changelog, release-notes, publishing, deployment, or post-deployment verification
skill for the target repositories the skills operate on. This repository's own case is
ADR 0001's and is not reopened here. Note that "release" already means two other things in this
tree — releasing an issue whose blocker closed (`$return-to-town`, `$sort-board`), and a
protected `release/*` branch pattern (`$clear-map`) — and neither is a software release.

Two things carry it.

**Nothing has asked for it.** adept has not been asked to drive a release in any target
repository even once, so an artifact written now would be designed against an imagined
consumer: its shape chosen by guesswork, its correctness untestable. The construction rules
compound that — a release skill that is only instructions reduces to two commands a session
already runs correctly, and one that adds value would need scripts, which anatomy rule 2
admits only for work a model cannot do reliably inline.

**Release policy is repository-specific and already owned.** Semver against calver against
SHA; a changelog handwritten against one generated from commits; publishing by tag-triggered
workflow against by hand. Purpose-built tools already own the mechanics per ecosystem —
release-please, semantic-release, changesets, goreleaser, cargo-release.

**Revisit condition.** Reopen this the first time adept is actually asked to drive a release in
a target repository. That is when the question stops being hypothetical and the evidence this
decision lacks starts to exist, and reopening is not building: one real need settles what an
artifact would have to do, and whether that generalises is the superseding record's question.
Nothing here will notice on its own — those releases happen in other repositories and leave no
trace in this one, `$warding`'s review-by sweep reads `docs/debt/` rather than `docs/adr/`, and
the issue that produced this record closes with it. A sighting is therefore worth a new issue
citing this record. The gap runs the other way too, and is worth saying plainly: the premise
that no such release has been driven is an observation about sessions, not a fact any artifact
here can confirm.

## Consequences

- README's workflow section gains a one-line pointer to this record, the convention it already
  uses for ADRs 0001, 0002 and 0003. That pointer is what makes the absence findable; the
  record alone would not, because the index here is deliberately the directory listing.
- Nothing else in `README.md` or `docs/cheatsheet.md` changes. The lifecycle they draw is
  complete — no stage is missing from it.
- A target repository that needs a release keeps its own tooling, and nothing here stops a
  session running `git tag`, `gh release create`, or that repository's release recipe when
  asked. This withholds an artifact, not a capability.
- `$restock` and `$warding` remain the only version-adjacent surfaces — one merges dependency
  updates, the other reports version drift and advisories. Neither publishes anything, and
  neither changes.
- There is no post-merge verification stage either. `$return-to-town` confirms the merge landed
  and reconciles cleared dependents; what happens to the code after it is deployed is the target
  repository's own responsibility, and adept deliberately claims no visibility into a deployed
  system.

## Considered & rejected

- **Ship a `$release` skill now — tag, changelog, `gh release create`** — including the
  deliberately minimal version of it alongside this record. The issue's first option, and the
  reading that treats the gap as real. Rejected on both grounds above, the first sufficient
  alone: there is no target repository whose release this one has been asked to drive, so the
  skill's shape would be imagined. A minimal one is the worst case rather than the safe one,
  because it would encode the defaults of the only repository available to test it against —
  this one, which has no releases.
- **Write `references/release.md` instead of a skill.** This repository's other artifact type,
  a standard consulted while doing something else rather than a procedure invoked, and the
  shape that best survives the policy objection: "read this repository's release documentation
  and follow it" is legitimate content for a reference where it is degenerate content for a
  skill. Rejected on the first ground alone — with no observed release to describe, its content
  would be imagined the same way.
- **Record the decision only as a line in `README.md` or `docs/cheatsheet.md`, with no record
  here.** The issue's second option, and cheaper. Rejected because a line in a
  which-skill-do-I-run table carries the outcome without the reasoning that makes it a
  decision, and has nowhere to keep the revisit condition. The line itself was not rejected —
  the Consequences take it, pointing here.
- **A post-merge verification skill only, dropping tagging and changelog.** The narrowest
  scope-in, and the one least exposed to the policy objection. Rejected on the first ground
  too — nobody has asked. `$return-to-town` already verifies the merge landed, and watching a
  deployed system is a capability adept neither has nor claims.
- **A deferral record under `docs/debt/` rather than a record here.** Rejected because a
  deferral says work is coming later, and this is a decided exclusion. `just records` also
  enables only the `adr` profile, so this would mean turning on `debt` for something that is
  not a deferral.
- **Leave it undecided.** Rejected as the state the issue reports: the cost was never the
  missing skill, but that a reader could not tell absence from oversight.
