# 0039 Capture derived guard input before searching

## Status

Accepted (2026-08-27)

## Context

The quest-log tracker fixture derives every GitHub profile operation and checks that each
issue-taking function calls `github_require_id`. It currently pipes `declare -f` into
`rg -q` under `set -o pipefail`. Once `rg` finds an early match it may close the pipe while
the producer is still writing, so the producer exits 141 and the fixture falsely reports a
missing guard. The blamed function varies with scheduling.

## Decision

Capture each complete function definition first and fail if that capture fails. Search the
captured text only after the producer has completed. Keep the derived operation list and the
existing missing-guard failure contract.

## Consequences

The assertion distinguishes failure to inspect a function from a function that lacks the
guard, and no early-closing consumer can turn a successful match into a pipeline failure.
The fixture retains Bash 3.2 compatibility and changes no tracker runtime behavior.

## Considered & rejected

- **Disable `pipefail` around the scan.** judgment: this hides a real producer failure and
  conflicts with the repository's fail-closed shell convention.
- **Keep the pipeline but remove `-q`.** judgment: correctness would depend on the search
  tool consuming all input, while capture makes producer completion explicit and separately
  checkable.
- **Leave the intermittent assertion unchanged.** verified: a forced early-match producer
  on 2026-08-27 returned `producer=141 rg=0`, reproducing the false failure mechanism.
