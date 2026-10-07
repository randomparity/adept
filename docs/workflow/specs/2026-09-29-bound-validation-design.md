# Bound validation prerequisite — issue #399

## Problem

The published `bounded_call` launches a child before evaluating its `bound` operand.
On Bash 3.2, malformed arithmetic can abandon polling without a reliable answer.
Existing appliers already validate their configurable bounds or use fixed literals.

## Scope

Clarify `references/network-bounds.md` without changing the algorithm or appliers.
Keep input validation owned by the call site and add its obligation as the eighth
non-adaptable property. Put the precondition beside the function signature so a reader
copying the mechanism sees it before child launch. No ownership transition or migration.
Exclude applier edits and retry/backoff, owned by existing maintainers and separately
approved future work respectively. Assign plugin version 5.14.4 under ADR 0022.

## Design

A bound must be a non-empty decimal whole number with no leading zero except `0`.
Reject expression syntax before Bash arithmetic, and cap digit length before multiplying
by ten; seven decimal digits fit this multiplication even in signed 32-bit arithmetic.
Sites may impose stricter ranges. Caller validation must fail with the site's existing
error vocabulary before invoking the mechanism. Known fixed 30/120 literals need no
runtime guard; existing configurable guards remain authoritative.

A second validator inside the template would duplicate correct caller guards. Retaining
caller ownership requires only the explicit precondition and property, not a new ADR.

## Success

The template states the precondition before launching the child. The property names
validation order, decimal syntax, leading-zero handling, overflow protection, and failure
ownership. The four appliers named in #399 and the fifth tracker applier remain untouched.

## Failure model

- Actors/deployments: transcribers of this reference into Bash 3.2 shipped executables.
- Invariants/assets: reject malformed bounds before arithmetic or child launch; retain
  existing caller guards and bounded-call status, capture, escalation, and reap behavior.
- Accepted classes: a transcriber ignoring an explicit prerequisite is outside this
  documentation correction; runtime enforcement remains each applier's responsibility.
- Covered elsewhere: status collisions, poll races, and latency belong to #403/#405/#406.

## Validation

The changed contract is a prose obligation with no executable consumer validating its
wording: task-test-not-applicable; do not pin sentences in tests. Manually trace valid
30/120 literals, configurable decimal bounds, and invalid empty/08/010/expression/oversized
inputs against the property and existing guards. Smoke-run a caller guard with the
verbatim mechanism on Bash 3.2 in private temporary storage, verifying malformed inputs
launch no child and a valid command preserves output/status. Run `just commit-check`;
the managed pre-push hook owns final `just ci`, with independent Ubuntu/macOS CI.
