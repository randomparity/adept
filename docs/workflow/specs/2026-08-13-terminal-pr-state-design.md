# Terminal pull-request state before mergeability

## Summary

Make `$return-to-town` recognize an already-merged pull request from its authoritative
terminal state before interpreting GitHub's lazily computed mergeability fields. The
governing decision is
[ADR 0009](../../adr/0009-terminal-pr-state-precedes-mergeability.md).

## Requirements traceability

| # | Source | Contract |
|---|---|---|
| 1 | Issue #76 Expected | The status snapshot queries `state` and `mergedAt` with the existing check and mergeability fields |
| 2 | Issue #76 Expected and Proposed approach | `state: MERGED` is handled before `mergeable` or `mergeStateStatus` |
| 3 | Issue #76 Expected | An already-merged PR proceeds directly to post-merge cleanup without polling computed fields |

## Behavior

At entry to the operator-merge path and the shared “After a merge” path,
`$return-to-town` takes one explicit-field snapshot containing `state`, `mergedAt`,
`mergeable`, `mergeStateStatus`, and `statusCheckRollup`. It branches in this order:

1. `MERGED`: treat the pull request as conclusively merged regardless of computed-field
   values, complete operator-path tracking when applicable, and proceed to cleanup.
2. `CLOSED`: stop without merge or post-merge cleanup and report that the pull request was
   closed unmerged.
3. `OPEN`: retain the existing requirement that checks are green and the pull request is
   mergeable; only this branch interprets or polls computed fields.

`mergedAt` is included in the displayed snapshot as corroborating evidence. It does not
replace `state` as the branch discriminator.

## Error handling

A failed `gh pr view` remains a failed status read and cannot authorize cleanup. Missing or
unexpected `state` values likewise cannot fall through to the merged path. An open pull
request with `UNKNOWN` computed fields retains the existing bounded recheck behavior.

## Verification

Because repository policy forbids gates that assert on prose, use a fresh behavioral review
with three fixed packets:

- V1: `state=MERGED`, non-null `mergedAt`, computed fields `UNKNOWN`; expected result is
  immediate post-merge tracking/cleanup with no poll.
- V2: `state=OPEN`, green checks, `mergeable=MERGEABLE`, `mergeStateStatus=CLEAN`; expected
  result is the existing handoff or authorized-merge behavior.
- V3: `state=CLOSED`, null `mergedAt`; expected result is a stop without post-merge cleanup.

Then run `just verify` and `git diff --check`.

## Non-goals

- No change to the green-and-mergeable requirement for open pull requests.
- No change to merge authorization, merge method, issue closure, or cleanup ordering.
- No new script, dependency, compatibility shim, or prose-sensitive automated test.

## Global constraints

- Skills remain instruction-only Markdown; no supporting executable is added.
- The implementation file is `skills/return-to-town/SKILL.md`.
- GitHub reads use explicit JSON fields.
- `just verify` is the guardrail suite; CI invokes the same chain as `just ci`.
- `BASE_BRANCH` is `main`; branch is `feat/merged-state-first-76`.
- Host architecture is `arm64`; no target architecture is declared, so the relationship is
  `no-target-declared`.

