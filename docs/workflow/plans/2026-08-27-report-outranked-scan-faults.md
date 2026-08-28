# Report outranked scan faults — implementation plan

**Issue:** #87

**Decision:** [ADR 0043](../../adr/0043-report-outranked-scan-faults.md)

**Spec:** [design](../specs/2026-08-27-report-outranked-scan-faults-design.md)

**Branch:** `feat/report-outranked-scan-faults-87`

**BASE_BRANCH:** `main`

## Global constraints

- Shell remains compatible with Bash 3.2, uses tab indentation, `#!/usr/bin/env bash`, and
  `set -euo pipefail` where a file already carries them.
- Use only existing shell facilities and helpers; add no dependency or public API.
- `.github/scripts/check-records.sh` stays byte-identical to
  `skills/tome-of-lore/assets/check-records.sh`; their `check-records-test.sh` suites also stay
  byte-identical.
- Status `3` means `positive-with-fault`. It reports the last fault encountered, emits a warning,
  and preserves the status-0 action and process verdict.
- Exact guardrails: focused `./.github/scripts/check-records-test.sh`; mirrored record gate
  `just records`; full repository suite `just verify`. CI invokes the same suite through
  `just ci`.
- Host architecture is `x86_64`; no target architecture is declared; relationship is
  `no-target-declared`. The host uses GNU userland. Repository targets are not inferred from it.
- ADR index coupling is `not coupled`: `docs/adr/README.md` is deliberately a directory policy,
  not an index table.

## Task 1 — add failing regression coverage

**Files:** modify `.github/scripts/check-records-test.sh`; mirror the exact file to
`skills/tome-of-lore/assets/check-records-test.sh` only after the focused test is red.

**Interfaces:** consumes existing helpers `write_ls_files_stub`, `run_case`, `expect_match`,
`expect_error_code`, and the `renumber_match_outranks_fault` fixture. Produces assertions for
`W-RENUMBER-SCAN`, `W-GATE-WITNESS-SCAN`, last-fault selection, and unchanged positive actions;
Task 2 must satisfy them without changing their expected codes.

1. Extend `renumber_match_outranks_fault` so two earlier candidate index reads fault with
   distinguishable paths before `docs/debt/0006-b.md` matches. Keep expected exit `0`, then assert
   `.err` contains `::warning::W-RENUMBER-SCAN:`, names the later faulting candidate and its exit,
   and `.out` still names the real renumber destination. The path assertion specifically proves
   the predicate copied its local `fault_path` into caller-visible `renumber_fault_path`.
2. Add a gate fixture whose protected set is empty, whose first two `ls-tree` witnesses fault with
   distinguishable paths, and whose later workflow witness finds the former gate basename. Assert
   exit `1`, `E-GATE-EMPTY-SET`, `W-GATE-WITNESS-SCAN` naming the second fault, and absence of
   `E-GATE-WITNESS-SCAN`.
3. Run `./.github/scripts/check-records-test.sh` bare. Expected: non-zero, with the first new
   warning assertion failing because neither caller emits the new code. This red result is the
   TDD proof; do not alter production code before observing it.
4. Apply the same completed edits to the skill asset mirror and confirm
   `cmp -s .github/scripts/check-records-test.sh skills/tome-of-lore/assets/check-records-test.sh`.

**Acceptance:** both fixtures reach a later positive witness after earlier injected faults; the
focused suite is demonstrably red for the missing warnings; both test mirrors are identical.

**Rollback:** revert only the two fixture edits; no scratch tree is retained by a completed suite.

## Task 2 — implement the fourth predicate outcome

**Files:** modify `.github/scripts/check-records.sh`; mirror it exactly to
`skills/tome-of-lore/assets/check-records.sh`.

**Interfaces:** consumes Task 1's exact warning codes and ADR 0043's status-3 contract. Preserves
`renumbered_to`, `renumber_fault_path`, `gate_witness_path`, and `path_exists_status` for callers.
Produces status `3` from `renumbered_elsewhere` and `gate_existed_at`; Task 3 relies on both script
mirrors being identical and the focused suite being green.

1. In each predicate's positive-result branch, return `3` when `fault_status` is non-zero and
   return `0` otherwise. In `renumbered_elsewhere`, copy both local retained values before return:
   `path_exists_status=$fault_status` and `renumber_fault_path=$fault_path`. In
   `gate_existed_at`, copy `fault_status` to `path_exists_status`; its caller-visible
   `gate_witness_path` already changes with every fault.
2. In the `renumbered_elsewhere` caller, add a status-3 case that emits
   `warn_full "W-RENUMBER-SCAN: $record: found renumber destination $renumbered_to after an incomplete search (could not read $renumber_fault_path, exit $path_exists_status)"`
   and then prints the same renumber note as status 0.
3. In the `gate_existed_at` caller, add a status-3 case that emits
   `warn_full "W-GATE-WITNESS-SCAN: $gate_witness_path: a later witness established that a gate existed at $base after this read failed (git exit $path_exists_status)"`
   and then emits the same `E-GATE-EMPTY-SET` error as status 0.
4. Apply the same production edits to its skill asset mirror. Run
   `cmp -s .github/scripts/check-records.sh skills/tome-of-lore/assets/check-records.sh`.
5. Run `./.github/scripts/check-records-test.sh` bare. Expected: exit 0 and the suite's
   `0 failed` summary.

**Acceptance:** status 3 preserves the positive verdict/action; one full-severity warning reports
the last retained fault; ordinary statuses 0, 1, and 2 retain their behavior; mirrors match.

**Rollback:** revert the caller and predicate cases together; a partial rollback would leave a
status value without a consumer or a consumer no predicate can reach.

## Task 3 — prove the tests bite and finish repository integration

**Files:** modify `.claude-plugin/plugin.json`; no other source file is expected.

**Interfaces:** consumes Task 2's green focused suite and identical mirrors. Produces installable
plugin version `2.12.1` and final guardrail evidence for delivery.

1. Temporarily neutralise only the `renumbered_elsewhere` status-3 caller warning. Run
   `./.github/scripts/check-records-test.sh` bare and require non-zero with the new
   `W-RENUMBER-SCAN` assertion failing. Restore the exact production line without committing the
   mutation.
2. Temporarily neutralise only the `gate_existed_at` status-3 caller warning. Run
   `./.github/scripts/check-records-test.sh` bare and require non-zero with the new
   `W-GATE-WITNESS-SCAN` assertion failing. Restore the exact production line without committing
   the mutation.
3. Run `./.github/scripts/check-records-test.sh` again. Expected: exit 0 with every suite assertion
   passing and the summary reporting `0 failed`.
4. Change `.claude-plugin/plugin.json` version from `2.12.0` to `2.12.1`; this is a PATCH because
   no invocation contract or capability is added.
5. Run `git diff --check`, then `just records`, then `just verify`, all bare. Expected: exit 0;
   record mirrors compare byte-identically; all record tests pass; all repository gates and prek
   checks pass without warnings.

**Acceptance:** both controlled faults turn the focused suite red; the restored implementation is
green; version `2.12.1` is parseable and greater than the base version; full guardrails pass.

**Rollback:** restore `2.12.0` only when reverting the entire branch. Never leave implementation
changes at the old version because installed plugin caches would not receive them.
