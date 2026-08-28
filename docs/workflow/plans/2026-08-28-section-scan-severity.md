# Implement E-SECTION-SCAN full-severity reporting

Goal: make required-section scan faults fail the record gate even when the affected record is
grandfathered as non-conforming at the base ref. The existing `check_sections` status branch
remains the single implementation point; a PATH-shadowed grep fixture proves the base/downgrade
case without changing the validator's interface. Production and test mirrors move together.

Tech stack: Bash 3.2-compatible shell, git-backed shell fixtures, Just guardrails.

## Global Constraints

- Bash 3.2 is the floor.
- Target userlands are GNU/Linux and macOS/BSD; no target architecture is declared.
- Add no dependency, generalized guard, abstraction, or new public contract.
- `.github/scripts/` and `skills/tome-of-lore/assets/` checker and test files must remain
  byte-identical.
- Preserve the existing `E-SECTION-SCAN` diagnostic and three-way grep status handling.
- Full guardrail: `just verify`; CI wrapper: `just ci`; focused suite:
  `./.github/scripts/check-records-test.sh`.
- Every repository change requires a patch version increase in
  `.claude-plugin/plugin.json`.

## Task 1: Prove the grandfathered scan-fault regression

Files:

- Modify `.github/scripts/check-records-test.sh`.
- Mirror it byte-for-byte to `skills/tome-of-lore/assets/check-records-test.sh`.

Interfaces:

- Consumes the existing `case_dir`, `base_of`, and `run_case` test helpers and the fixture's
  `docs/debt/0001-valid.md` path.
- Produces a focused case whose expected public behavior is exit 1 with
  `E-SECTION-SCAN`, and an explicit assertion that the output does not contain
  `W-LEGACY-SHAPE` for that fault.
- Task 2 relies on this case failing against the current `err` call and passing after the
  one-line channel correction.

Steps:

1. In the existing `-- grandfathering --` group, create a `legacy_section_scan_fault` fixture.
   Rewrite `target:` as `- target:`, commit it, and capture `b=$(base_of "$d")`, matching the
   adjacent legacy fixtures.
2. Set `stub_bin=$SCRATCH/grep-legacy-section-fault-bin`, create the directory, capture
   `real_grep=$(command -v grep)`, and write `$stub_bin/grep` with an unquoted heredoc so the
   real binary path is installed now while the stub-time parameters remain escaped. Run
   `chmod +x "$stub_bin/grep"` before invoking the case. The complete heredoc body is:

   ```bash
   #!/usr/bin/env bash
   if [ "\$1" = -qxF ] && [ "\$2" = "## Status" ] &&
     [ "\$3" = docs/debt/0001-valid.md ]; then
     printf 'grep: fixture-fault: required-section scan failed\n' >&2
     exit 2
   fi
   exec "$real_grep" "\$@"
   ```

   The exact working-tree path condition leaves the base pass's temporary blob readable, so
   the committed legacy marker establishes downgrade mode before the tree pass faults.
3. Invoke:

   ```bash
   run_case "legacy record section scan fault stays an error" 1 E-SECTION-SCAN "$d" \
     BASE_SHA="$b" PATH="$stub_bin:$PATH"
   ```

   Then scan `$d/.err` with an explicitly captured grep status and fail the fixture if an
   `E-SECTION-SCAN` line is relabelled as `W-LEGACY-SHAPE`. Reuse the suite's existing
   `printf`, `passed`, and `failed` reporting pattern; do not add a helper for one case.
4. Copy the completed test file to its skill asset mirror and verify:

   ```bash
   cmp -s .github/scripts/check-records-test.sh \
     skills/tome-of-lore/assets/check-records-test.sh
   ```

   Expected: exit 0.
5. Allocate a caller-owned scratch directory and run the focused suite against the unchanged
   production code, passing that directory as the suite's positional argument:

   ```bash
   red_scratch=$(mktemp -d "${TMPDIR:-/tmp}/quest-90-red.XXXXXX")
   ./.github/scripts/check-records-test.sh "$red_scratch"
   ```

   Expected: non-zero, with the new case reporting that `E-SECTION-SCAN` was downgraded to
   `W-LEGACY-SHAPE`. This is the controlled red proof; do not commit it separately. After
   recording that output, verify the basename starts with `quest-90-red.` and its parent is
   exactly `${TMPDIR:-/tmp}`, then remove only that owned tree with
   `find "$red_scratch" -depth -delete`. Confirm `[ ! -e "$red_scratch" ]` before Task 2.

Acceptance: the new test deterministically distinguishes the current downgraded behavior from
the required error behavior, including on hosts running as root.

Rollback: revert the two identical test-file edits together; retain no fixture scratch state.

## Task 2: Route E-SECTION-SCAN through the full-severity channel

Files:

- Modify `.github/scripts/check-records.sh`.
- Mirror it byte-for-byte to `skills/tome-of-lore/assets/check-records.sh`.
- Modify `.claude-plugin/plugin.json` from version `2.12.4` to `2.12.5`.

Interfaces:

- Consumes Task 1's failing behavior test.
- Preserves `check_sections file label`, its return behavior, diagnostic code, and message.
- Produces the existing full-severity error channel required by the regression and by the
  record-checking recipes.

Steps:

1. Replace only the fault arm and add the governing explanation:

   ```bash
   *)
     # err_full, not err: a scan fault describes the scan, not the record, so it must not
     # be downgraded to W-LEGACY-SHAPE for a record already non-conforming at the base ref.
     err_full "E-SECTION-SCAN: $label: could not scan $file for section '$section' (grep exit $grep_status)"
     continue
     ;;
   ```

2. Sweep all `E-*-SCAN` emissions in `.github/scripts/check-records.sh`,
   `.github/scripts/profiles/adr.sh`, and `.github/scripts/profiles/debt.sh`. Confirm that this
   `E-SECTION-SCAN` call is the only remaining record-checker scan fault using the downgradable
   `err` channel. Do not change migrator `report_failure` calls or already-full-severity sites.
3. Copy the checker to its skill asset mirror and update the manifest version to `2.12.5`.
4. Run:

   ```bash
   ./.github/scripts/check-records-test.sh
   ```

   Expected: exit 0 and the suite summary reports the matching suites passed.
5. Run:

   ```bash
   just records
   just verify
   ```

   Expected: both exit 0; `just records` proves the shared assets are byte-identical and
   `just verify` completes the full local guardrail suite without warnings.
6. Stage only the four implementation/test mirrors and manifest, re-read the diff, and commit:

   ```text
   fix(records): keep section scan faults at full severity
   ```

Acceptance: all four issue criteria are satisfied; the focused regression bites before the
production change and passes afterward; every record-checker `E-*-SCAN` site uses a
non-downgradable failure channel; mirrors are identical; the plugin version is installable.

Rollback: revert the implementation commit; no migration or external cleanup is required.
