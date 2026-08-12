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
is missing.

## Decision

**adept ships no release stage** — no tagging, changelog, release-notes, publishing,
deployment, or post-deployment verification skill for the target repositories the skills
operate on. This repository's own case is ADR 0001's and is not reopened here. Note that
"release" already means two other things in this tree — releasing an issue whose blocker
closed (`$return-to-town`, `$sort-board`), and a protected `release/*` branch pattern
(`$clear-map`) — and neither is a software release.

One thing carries it: **there is nothing to build against.** The checkable evidence says so.
No skill under `skills/` covers tagging, changelog, or deploy; this repository has no tags and
no GitHub releases; and issue #50 reports an ambiguity rather than blocked work. The stronger
claim — that no session has ever driven a release in a target repository — is an observation
about sessions, not a fact any artifact here can confirm. Either way, an artifact written now
would take its shape from guesswork rather than from a release anyone has seen.

That is a decision for want of evidence, not a judgment that release work is foreign to adept's
purpose. The difference matters, because the arguments that would support the stronger reading
do not survive this repository: varying per-repository policy is exactly what `$attunement`
exists to discover at runtime, a purpose-built tool already owning the mechanics is the premise
`$restock` is built on, and thinness is no objection either — `$deliver` is 91 instruction-only
lines around `git push` and `gh pr create`, which anatomy rule 1 makes the preferred shape. Each
of them, turned on a release skill, would condemn something already shipped.

**Revisit condition.** Reopen this the first time adept is actually asked to drive a release in
a target repository — the point at which the question stops being hypothetical and the missing
evidence starts to exist. Reopening is not building: one real need settles what an artifact
would have to do, and whether that generalises is the superseding record's question. Nothing
here will notice on its own — those releases happen elsewhere, `$warding`'s review-by sweep
reads `docs/debt/` rather than `docs/adr/`, and the issue that produced this record closes with
it — so a sighting is worth a new issue citing this record. The premise runs on the same
shortage: that no such release has been driven is an observation about sessions, not a fact any
artifact here can confirm.

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
- There is no post-merge verification stage either, and the residual starts closer than it
  looks. `$return-to-town` confirms the merge landed and reconciles cleared dependents, but
  where a target repository publishes on merge to `main` — release-please and semantic-release
  both do — that publish is fired by the merge `$return-to-town` itself performs, and nothing
  here reads the workflow run it triggers. A publish that fails on registry auth, a version
  collision, or a missing tag permission goes unobserved while the session reports the issue
  done. That inaccurate report is adept's own and not the target repository's to fix; it is
  accepted here because watching a foreign workflow run is the machinery this record declines,
  and it is tracked as issue #65 against `$return-to-town`.

## Considered & rejected

- **Ship a `$release` skill now — tag, changelog, `gh release create`** — including the
  deliberately minimal version alongside this record. The issue's first option. Rejected on the
  ground above: no target repository's release has been driven from here, so the skill's shape
  would be imagined. A minimal one is the worst case rather than the safe one, since it would
  encode the defaults of the only repository available to test it against — this one, which has
  no releases.
- **Write `references/release.md` instead of a skill.** This repository's other artifact type —
  a standard consulted rather than a procedure invoked — and the cheaper shape, carrying no
  script pressure and no invocation surface. Rejected on the same ground: with no observed
  release to describe, its content would be imagined the same way, and a reference nobody
  consults is upkeep without a reader.
- **Record the decision only as a line in `README.md` or `docs/cheatsheet.md`, with no record
  here.** The issue's second option, and cheaper. Rejected because a line in a
  which-skill-do-I-run table carries the outcome without the reasoning that makes it a
  decision, and has nowhere to keep the revisit condition. The line itself was not rejected —
  the Consequences take it, pointing here.
- **A post-merge verification skill only, dropping tagging and changelog.** The narrowest
  scope-in. Rejected on the same ground — nobody has asked — but it is the alternative closest
  to a real gap, and the part of it that is adept's own is tracked as issue #65 rather than
  dismissed.
- **A deferral record under `docs/debt/` rather than a record here.** Rejected because a
  deferral says work is coming later, and this is a decided exclusion. `just records` also
  enables only the `adr` profile, so this would mean turning on `debt` for something that is
  not a deferral.
- **Leave it undecided.** Rejected as the state the issue reports: the cost was never the
  missing skill, but that a reader could not tell absence from oversight.
