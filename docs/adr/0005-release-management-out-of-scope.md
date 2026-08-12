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
release to cut. The repository has no tags and no GitHub releases, and the only workflow it
runs is `verify.yml`.

What was never stated is whether that reasoning extends to the *target* repositories the
skills operate on. Those are not adept — one may publish a crate, another may ship images on
a tag — so a reader who looks for the release stage finds nothing and cannot tell an omission
from a decision. Issue #50 reports that ambiguity, not a feature anyone has been blocked by.
The word already appears here in two unrelated senses, which does not help: releasing an
issue whose blocker closed (`$return-to-town`, `$sort-board`), and a protected `release/*`
branch pattern (`$clear-map`).

## Decision

**adept ships no release stage, and release management is out of scope for its skills** — no
tagging, changelog, release-notes, publishing, deployment, or post-deployment verification
skill, for this repository or for the target repositories the skills operate on. The pipeline
ends at merge and cleanup, which is the whole of what it claims to do.

Four things carry it.

**There is no repetition to generalise from.** The standard this repository works to is no
utility until the third repetition. adept has not been asked to drive a release in any target
repository even once, and its own repository deliberately has none. A skill written now would
be designed against an imagined consumer.

**Release policy is repository-specific and already owned.** Semver against calver against
SHA; a changelog handwritten against one generated from commits; publishing by tag-triggered
workflow against by hand. Purpose-built tools already own the mechanics per ecosystem —
release-please, semantic-release, changesets, goreleaser, cargo-release. A skill would encode
one repository's policy and be wrong for the next, or degrade into "read this repository's
release documentation and run its release command", which is what a session does without a
skill.

**The cadence does not fit the pipeline.** `$quest` is per-issue and `$campaign` drains a
queue of them. A release batches many merges and fires when a human judges the batch ready,
not when one merges. A release step inside `$quest` or `$return-to-town` would run once per
issue, which is wrong by construction — so scope-in could only ever have meant a standalone
skill. The pipeline is complete for what it claims; it is not missing a stage.

**Publishing is an irreversible external write with no unattended path.** A pushed tag can be
fetched before anyone deletes it, and a published release notifies watchers and can be
depended on. The `risk:` taxonomy in `quest-log` puts an action that writes external state in
`risk:daytime-only`, so a release skill could never run unattended — the mode most of adept's
orchestration exists to serve.

**Revisit condition.** Reopen this when adept has driven a release by hand in a target
repository three separate times, and those three share enough policy that one instruction file
would have served all of them. That is the third-repetition rule, and it is the evidence this
decision lacks today. A new record supersedes this one; a fourth hand-run does not.

## Consequences

- The lifecycle in `docs/cheatsheet.md` and the workflow section of `README.md` are complete
  as drawn. Neither is missing a stage, and neither needs an edit.
- A target repository that needs a release keeps its own tooling. Nothing here stops a session
  running `git tag`, `gh release create`, or a repository's release recipe when asked: this
  withholds a skill, not a capability.
- `$restock` and `$warding` remain the only version-adjacent surfaces — one merges dependency
  updates, the other reports version drift and advisories. Neither publishes anything, and
  neither changes.
- There is no post-merge verification stage either. `$return-to-town` confirms the merge landed
  and reconciles cleared dependents; whether the merged code works once deployed is the target
  repository's CI's answer.
- The absence becomes findable. A reader who wonders why there is no release skill finds this
  record where this repository keeps that kind of answer, which is what issue #50 asked for.
- If the revisit condition fires, the evidence to design the skill exists by construction:
  three real hand-driven releases are three specifications.

## Considered & rejected

- **Ship a `$release` skill now — tag, changelog, `gh release create`.** The issue's first
  option, and the reading that treats the gap as real. Rejected on the four grounds above, the
  first of which is sufficient alone. The construction rules compound it: a release skill that
  is only instructions reduces to two commands a session already runs correctly, and one that
  adds value would need scripts — which anatomy rule 2 admits only for work a model cannot do
  reliably inline.
- **Record the decision as a line in `docs/cheatsheet.md` or `README.md` instead of a record
  here.** The issue's second option, and cheaper. Rejected because the complaint is that the
  omission reads as a gap rather than a decision, and a line in a which-skill-do-I-run table
  carries the outcome without the reasoning that makes it one. It also has no supersession
  mechanism, and the revisit condition is the part most worth keeping.
- **Both — this record plus a deliberately minimal release skill.** Rejected as paying the
  skill's maintenance cost to avoid making the decision. A minimal release skill is also the
  one most likely to be wrong for the next repository, because it would encode the defaults of
  the only repository available to test it against: this one, which has no releases.
- **A post-merge verification skill only, dropping tagging and changelog.** The narrowest
  scope-in. Rejected because both things it would check are already answered — `$return-to-town`
  verifies the merge landed, and ADR 0001 already records that `main` staying green is a
  property of this distribution model rather than a per-PR stage.
- **A deferral record under `docs/debt/` rather than a record here.** Rejected because a
  deferral says work is coming later, and this is a decided exclusion rather than deferred work.
  `just records` also enables only the `adr` profile, so this would additionally mean turning on
  `debt` for something that is not a deferral.
- **Leave it undecided.** Rejected as the state the issue reports. The cost was never the
  missing skill; it was that a reader could not tell absence from oversight, and every
  contributor would re-derive the question.
