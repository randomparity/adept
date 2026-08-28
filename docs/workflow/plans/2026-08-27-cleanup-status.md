# Cleanup status preservation — implementation plan

**Issue:** #77

**Decision:** [ADR 0045](../../adr/0045-cleanup-faults-preserve-earned-status.md)

**Spec:** [design](../specs/2026-08-27-cleanup-status-design.md)

**Branch:** `feat/fix-cleanup-status-77`

**BASE_BRANCH:** `main`

## Goal and architecture

Make both gate-local EXIT traps treat scratch cleanup as secondary accounting: successful cleanup
returns the status already earned, while failed cleanup reports the retained path and changes only
an otherwise-clean run to fault status 2. Each gate keeps its own implementation because
`verify-push.sh` also owns an isolated Git worktree. Fixture suites inject a failing `rm` through
`PATH` and keep intentional residue beneath suite-owned scratch roots.

## Global constraints

- Shell remains compatible with Bash 3.2, uses tab indentation, `#!/usr/bin/env bash`, and
  `set -euo pipefail` where the files already carry them.
- Use only existing shell facilities and helpers; add no dependency, public API, shared cleanup
  abstraction, or target architecture.
- Exit 1 remains a content finding, exit 2 is an otherwise-clean cleanup fault, and every status
  earned before cleanup takes precedence over cleanup failure.
- `check-ripgrep-config.sh` emits `ripgrep-config: retained scratch path: <path>` after failed
  removal and keeps its distinct unsafe-path refusal diagnostic. `verify-push.sh` keeps
  `verify-push: retained cleanup path: <path>`.
- Host architecture is `x86_64`; target architectures are `none declared`; relationship is
  `no-target-declared`; userland is GNU. CI supplies the Bash 3.2/macOS arm through its macOS leg.
- Exact guardrails: `just test check-ripgrep-config verify-push` while iterating and bare
  `just verify` before shipping. CI runs the latter through `just ci` on Ubuntu and macOS.
- ADR index coupling is `not coupled`: `docs/adr/README.md` is deliberately not an index table.

## Task 1 — preserve status in the ripgrep-config gate

**Files:** modify `scripts/check-ripgrep-config-test.sh` and
`scripts/check-ripgrep-config.sh`.

**Interfaces:** consumes the suite's `SCRATCH`, `bare_root`, `gate`, and `assert_gate`/`fail`
patterns plus the production `scratch` variable. Produces the exact retained-path diagnostic and
the 0→2/nonzero→same status rule; Task 3 relies on its focused suite being green.

1. After the existing bare-invocation fixture, add a failing-removal shim and clean/finding cases:

   ```bash
   rm_shim=$SCRATCH/shim-rm
   mkdir -p "$rm_shim"
   printf '#!/usr/bin/env bash\nexit 1\n' >"$rm_shim/rm"
   chmod +x "$rm_shim/rm"

   cleanup_root=$(new_fixture cleanup-fault)
   write_source "$cleanup_root" scripts/scan.sh '#!/usr/bin/env bash
   unset RIPGREP_CONFIG_PATH
   rg --no-config -n pattern .'
   track "$cleanup_root"
   cleanup_status=0
   cleanup_output=$(PATH="$rm_shim:$PATH" TMPDIR="$SCRATCH" "$gate" "$cleanup_root" 2>&1) ||
       cleanup_status=$?
   [[ $cleanup_status -eq 2 ]] ||
       fail "clean cleanup failure: expected exit 2, got $cleanup_status: $cleanup_output"
   [[ $cleanup_output == *"ripgrep-config: retained scratch path: $SCRATCH/ripgrep-config."* ]] ||
       fail "clean cleanup failure: retained path missing: $cleanup_output"

   finding_status=0
   finding_output=$(PATH="$rm_shim:$PATH" TMPDIR="$SCRATCH" "$gate" "$bare_root" 2>&1) ||
       finding_status=$?
   [[ $finding_status -eq 1 ]] ||
       fail "finding cleanup failure: expected exit 1, got $finding_status: $finding_output"
   [[ $finding_output == *'scripts/scan.sh:4: runs rg'* ]] ||
       fail "finding cleanup failure: finding missing: $finding_output"
   [[ $finding_output == *"ripgrep-config: retained scratch path: $SCRATCH/ripgrep-config."* ]] ||
       fail "finding cleanup failure: retained path missing: $finding_output"
   ```

2. Run `just test check-ripgrep-config` bare. Expected: exit 1; the clean case observes exit 1
   rather than 2 and neither case sees the gate-owned retained-path diagnostic. Record this red
   result before editing production code.
3. Replace the production cleanup with the status-preserving implementation:

   ```bash
   cleanup() {
       local exit_status=$?
       case $scratch in
       "${TMPDIR:-/tmp}"/ripgrep-config.*)
           if rm -R -- "$scratch"; then
               exit "$exit_status"
           fi
           printf 'ripgrep-config: retained scratch path: %s\n' "$scratch" >&2
           ;;
       *) printf 'ripgrep-config: refusing cleanup outside scratch root: %s\n' "$scratch" >&2 ;;
       esac
       if [ "$exit_status" -eq 0 ]; then
           exit 2
       fi
       exit "$exit_status"
   }
   ```

4. Run `just test check-ripgrep-config` bare. Expected: exit 0 and the suite's pass line.
5. Temporarily replace the guarded `if rm ...` body with the original bare removal, rerun the
   same focused command, and require non-zero at the new cleanup assertion. Restore the guarded
   implementation and rerun to exit 0.
6. Stage only both ripgrep-config paths and commit
   `fix: preserve ripgrep gate status during cleanup`.

**Acceptance:** clean cleanup failure is exit 2; a real content finding stays exit 1; both name
the retained scratch path; the successful path remains green; the controlled fault proves the
new assertions bite.

**Rollback:** revert production and fixture changes together. Suite scratch cleanup owns the
intentional retained directories because `TMPDIR` is below `SCRATCH`.

## Task 2 — account for ordinary verify-push removal failure

**Files:** modify `scripts/verify-push-test.sh` and `scripts/verify-push.sh`.

**Interfaces:** consumes `run_verifier`, `new_repo`, `OBJECT`, the existing fake `just`, and
`FAIL_CI`. Produces `cleanup_failed=1` for both worktree-removal and scratch-root-removal failure,
with exit 2 only when `status` was 0; Task 3 relies on the focused suite being green.

1. Beside the existing failing-Git cleanup cases, add a separate failing-`rm` shim and runner:

   ```bash
   RM_FAIL_BIN=$SCRATCH/failing-rm
   mkdir -p "$RM_FAIL_BIN"
   printf '#!/usr/bin/env bash\nexit 1\n' >"$RM_FAIL_BIN/rm"
   chmod +x "$RM_FAIL_BIN/rm"

   run_verifier_with_rm() {
       local input=$1
       printf '%b' "$input" | (
           cd "$REPO"
           PATH="$RM_FAIL_BIN:$BIN:$PATH" TMPDIR="$SCRATCH" JUST_LOG="$LOG" \
                   SOURCE_REPO="$REPO" "$VERIFIER"
       )
   }

   new_repo
   rm_cleanup_status=0
   rm_cleanup_output=$(run_verifier_with_rm \
       "refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\n" \
       2>&1) || rm_cleanup_status=$?
   [[ $rm_cleanup_status -eq 2 && \
       $rm_cleanup_output == *"verify-push: retained cleanup path: $SCRATCH/verify-push."* ]] ||
       fail "scratch removal failure should exit 2 and name its path: $rm_cleanup_output"

   new_repo
   export FAIL_CI=1
   rm_failure_status=0
   rm_failure_output=$(run_verifier_with_rm \
       "refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\n" \
       2>&1) || rm_failure_status=$?
   unset FAIL_CI
   [[ $rm_failure_status -eq 73 && \
       $rm_failure_output == *"verify-push: retained cleanup path: $SCRATCH/verify-push."* ]] ||
       fail "scratch removal failure should preserve CI exit 73: $rm_failure_output"
   ```

2. Run `just test verify-push` bare. Expected: exit 1; the ordinary scratch removal still aborts
   the trap at the shim's exit 1 and does not emit the retained-path diagnostic. Record this red
   result before editing production code.
3. Replace the cleanup accounting tail with:

   ```bash
   cleanup() {
       local status=$? cleanup_failed=0
       if ((retain_cleanup)); then
           printf 'verify-push: retained cleanup path: %s\n' "$TEMP_ROOT" >&2
           exit "$status"
       fi
       if ((worktree_added)) && ! git -C "$ROOT" worktree remove --force "$WORKTREE"; then
           printf 'verify-push: retained cleanup path: %s\n' "$TEMP_ROOT" >&2
           cleanup_failed=1
       elif ! rm -R "$TEMP_ROOT"; then
           printf 'verify-push: retained cleanup path: %s\n' "$TEMP_ROOT" >&2
           cleanup_failed=1
       fi
       if ((status != 0)); then
           exit "$status"
       fi
       ((cleanup_failed == 0)) || exit 2
   }
   ```

4. Update the existing worktree-removal case to require exit 2, not merely non-zero, because its
   otherwise-clean cleanup fault follows the same contract. Run `just test verify-push` bare.
   Expected: exit 0 and the suite's pass line.
5. Temporarily restore the bare ordinary `rm -R "$TEMP_ROOT"`, rerun the focused command, and
   require non-zero at the new scratch-removal assertion. Restore the accounted branch and rerun
   to exit 0.
6. Stage only both verify-push paths and commit
   `fix: account for verify-push scratch cleanup`.

**Acceptance:** ordinary scratch-removal and worktree-removal failures are exit 2 after clean CI;
CI exit 73 survives either cleanup failure; every retained tree is named; controlled mutation
proves the new assertions bite.

**Rollback:** revert production and test changes together. The suite's EXIT fixture cleanup uses
the real outer PATH and removes retained test roots beneath `SCRATCH`.

## Task 3 — finish repository integration

**Files:** modify `.claude-plugin/plugin.json`; no other source change is expected.

**Interfaces:** consumes both green focused suites and the base plugin version `2.12.2`. Produces
installable patch version `2.12.3` and final guardrail evidence for delivery.

1. Change `.claude-plugin/plugin.json` version from `2.12.2` to `2.12.3`; no invocation contract
   or capability is added, so this is a PATCH.
2. Run `just test check-ripgrep-config verify-push` bare. Expected: exit 0 with exactly both
   selected suites passing.
3. Run `git diff --check` bare, then `just verify` bare. Expected: both exit 0; all record,
   commit, shape, manifest, unit, workflow, and prek checks pass without warnings.
4. Stage only `.claude-plugin/plugin.json` and commit `chore: bump plugin version for cleanup fix`.

**Acceptance:** version `2.12.3` is parseable and greater than the base version; both mutation
proofs were observed red; focused and full guardrails pass.

**Rollback:** restore `2.12.2` only when reverting both implementation commits. Leaving behavior
changes at the old version would prevent installed plugin caches from receiving them.
