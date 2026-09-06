# Publication cleanup reports and continues — implementation plan

**Goal.** Stop `skills/quest/scripts/publish-forge-review` from parking a `$quest` run when its
own scratch-file cleanup fails after publication has been posted, read back, and recorded.

**Architecture.** One bash helper, invoked once per run by `$quest` step 8. It validates its
private inputs, composes one comment body, posts it, reads it back, appends
`review-publication-verified: <URL>` to a private ledger, disposes its inputs, and prints the
comment URL. Only what happens after that verified ledger line changes: disposal becomes
best-effort, its outcome is always recorded, and the exit status stops meaning "cleanup failed".
Two skill documents and one behaviour suite are updated to match.

**Tech stack.** Bash, GNU/BSD coreutils, `gh`, `jq`. Tests are a bash fixture suite driven by
fake `gh`/`trash`/`gio` binaries on `PATH`.

Design: [spec](../specs/2026-09-06-publication-cleanup-report-and-continue-design.md),
[ADR 0056](../../adr/0056-publication-cleanup-reports-and-continues.md).

Expected implementation size: 150–215 changed lines (M) — from the file map below: ~48 in the
helper, ~59 in the behaviour suite, ~55 in `skills/quest/SKILL.md` (five multi-sentence runs
replaced plus step 8's closing sentence), ~8 in `skills/forge/SKILL.md`, 1 in the manifest.

## Global Constraints

- **Bash 3.2 is the floor** (macOS ships 3.2.57). No `mapfile`, no `readarray`, no associative
  arrays. Measured on 3.2.57 under `set -euo pipefail`: `local a=()` followed by `${#a[@]}` is
  safe and yields 0, and `arr[${#arr[@]}]=value` appends. Expanding `${arr[*]}` while the array
  is empty is not done anywhere below.
- Shell style: `#!/usr/bin/env bash`, `set -euo pipefail`, **TAB** indentation, 100-character
  lines.
- Never trail `|| true` on a scan; capture exit status explicitly. `rg` in gate scripts passes
  `--no-config` (no new `rg` call is added here).
- The repository is public. No absolute host paths, hostnames, or user names in any committed
  file; plans and specs name the checkout root as `$WORK`.
- Nothing automated asserts on prose (anatomy rule 4). The behaviour suite asserts on exit
  status, ledger lines, file existence, and stderr text the helper itself emits.
- Every change bumps `version` in `.claude-plugin/plugin.json`. This is a bug fix: `4.1.1` →
  `4.1.2`.
- Guardrails, run bare: `just verify` (full), `just test <pattern>` (selected suites),
  `just commit-check`, `just shape-check`, `just version-check`.

## File map

| File | Created/changed | Answerable for |
|---|---|---|
| `skills/quest/scripts/publish-forge-review` | changed | best-effort disposal and the two ledger records |
| `tests/fixtures/quest/publish-forge-review-test.sh` | changed | pinning the new failure contract and the unchanged happy path |
| `skills/quest/SKILL.md` | changed | the `$quest` steps 5 and 8 record checks, step 8's closing forge-scratch sentence, and the recovery predicates |
| `skills/forge/SKILL.md` | changed | the retention-suppression clause that reads the record |
| `.claude-plugin/plugin.json` | changed | the version bump |
| `docs/adr/0056-…`, `docs/workflow/specs/2026-09-06-…`, `docs/workflow/plans/2026-09-06-…` | created | the design record, committed before Task 1 |

## Task 1 — Best-effort disposal with a complete ledger record

Modifies `skills/quest/scripts/publish-forge-review`. Tests via
`tests/fixtures/quest/publish-forge-review-test.sh`. This is the whole behaviour change; Task 2
updates the documents that describe it.

**Interfaces.** Consumes, unchanged: `fail(message)` — prints `publish-forge-review: <message>`
to stderr and exits 1; `append_ledger(line)` — appends to `$ledger`, reads the last line back,
and calls `fail` if either step fails; globals `disposer` (`trash` or `gio`, set by `preflight`),
`body` (the generated body path), `comment_url`.

Provides: ledger record `review-publication-disposed: <space-separated paths>`, emitted only when
at least one path was disposed and naming exactly those; ledger record
`review-publication-undisposed: <space-separated paths>`, emitted only when at least one path
remains and naming exactly those; and the contract that the **ledger**, not the exit status, says
whether publication happened — nonzero means the helper did not publish unless
`review-publication-verified:` already reached the ledger, which a ledger append or readback
failure after that line leaves true and fatal, unchanged by this task.

### Verification

- **Partial disposal after verification completes the run.** Mode: `focused-test`. Contract:
  with the summary's disposal failing, the helper exits 0, prints the verified comment URL,
  disposes the review and the body, retains the summary, and writes both records. Case:
  `case_ledger_and_disposal_failures_retain_paths` (`PFR-6`), third block. Expected red before
  the helper changes: `PFR-6 … partial disposal did not report a completed publication`, because
  the unchanged helper exits 1 and writes no disposal record. Green: `just test publish-forge-review`.
- **Total disposal failure after verification completes the run.** Mode: `focused-test`.
  Contract: with every disposal failing, the helper exits 0, writes no
  `review-publication-disposed:` line, writes exactly one `review-publication-undisposed:` line
  naming the review, summary and body in that order, leaves all three on disk, and names all
  three on stderr. Case: new `case_total_disposal_failure_completes_publication` (`PFR-20`).
  Expected red: `PFR-20 … total disposal failure did not complete the publication`, because the
  unchanged helper exits 1. Green: `just test publish-forge-review`.

### Steps

1. In `tests/fixtures/quest/publish-forge-review-test.sh`, in `write_fakes`, in the heredoc that
   writes `"$bin/dispose"`, replace `if [ "${FAIL_TRASH_ON:-}" = "$name" ]; then` with
   `if [ "${FAIL_TRASH_ON:-}" = "$name" ] || [ "${FAIL_TRASH_ON:-}" = all ]; then` so
   `FAIL_TRASH_ON=all` fails every path.

2. In `case_ledger_and_disposal_failures_retain_paths`, add `disposed_line` to the `local`
   declaration on the function's first line, then replace the whole third block — from the third
   `new_case` through the `fi` closing the `partial disposal did not retain and report the
   remaining paths` check — with:

   ```sh
   	new_case
   	run_helper required "$REVIEW" env GH_MODE=success FAIL_TRASH_ON=summary.md
   	disposed_line=$(grep '^review-publication-disposed: ' "$LEDGER") || disposed_line=''
   	if [ "$STATUS" -ne 0 ] ||
   		[ "$OUTPUT" != 'https://github.com/acme/widgets/pull/42#issuecomment-73' ] ||
   		[ -e "$REVIEW" ] || [ ! -f "$SUMMARY" ] || body_file >/dev/null ||
   		! grep -q '^review-publication-verified:' "$LEDGER" ||
   		! grep -qxF "review-publication-undisposed: $SUMMARY" "$LEDGER" ||
   		! grep -qF "$SUMMARY" "$REPO/error"; then
   		fail "$name" 'partial disposal did not report a completed publication'
   		return
   	fi
   	case $disposed_line in
   	*"$SUMMARY"*)
   		fail "$name" 'disposed record named a path that was retained'
   		return
   		;;
   	"review-publication-disposed: $REVIEW "*.publish-forge-review.*) ;;
   	*)
   		fail "$name" 'partial disposal did not record the paths it disposed'
   		return
   		;;
   	esac
   ```

   The `*"$SUMMARY"*` arm is load-bearing and must come first: the following arm's leading `*`
   spans anything between the review and body paths, so without the disjointness arm a helper
   that names the retained summary in the disposed record passes the whole suite.

3. Add this case immediately after `case_ledger_and_disposal_failures_retain_paths`, and register
   it by adding the line `case_total_disposal_failure_completes_publication` immediately after
   the existing `case_ledger_and_disposal_failures_retain_paths` line in the run list near the
   end of the file:

   ```sh
   case_total_disposal_failure_completes_publication() {
   	local name='PFR-20 total disposal failure completes the publication' body undisposed
   	new_case
   	run_helper required "$REVIEW" env GH_MODE=success FAIL_TRASH_ON=all
   	body=$(body_file) || body=''
   	undisposed=$(grep -c '^review-publication-undisposed: ' "$LEDGER") || undisposed=0
   	if [ "$STATUS" -ne 0 ] ||
   		[ "$OUTPUT" != 'https://github.com/acme/widgets/pull/42#issuecomment-73' ] ||
   		[ ! -f "$REVIEW" ] || [ ! -f "$SUMMARY" ] || [ -z "$body" ] ||
   		! grep -q '^review-publication-verified:' "$LEDGER" ||
   		grep -q '^review-publication-disposed:' "$LEDGER" ||
   		[ "$undisposed" != 1 ]; then
   		fail "$name" 'total disposal failure did not complete the publication'
   		return
   	fi
   	if ! grep -qxF "review-publication-undisposed: $REVIEW $SUMMARY $body" "$LEDGER"; then
   		fail "$name" 'undisposed record did not own every path in order'
   		return
   	fi
   	if ! grep -qF "$REVIEW" "$REPO/error" || ! grep -qF "$SUMMARY" "$REPO/error" ||
   		! grep -qF "$body" "$REPO/error" ||
   		grep -q 'successful publication left its body behind' "$REPO/error"; then
   		fail "$name" 'warning did not name every retained path without a false leak report'
   		return
   	fi
   	ok "$name"
   }
   ```

4. Confirm the expected red: `just test publish-forge-review` from the worktree root. Expect a
   nonzero exit and the two `FAIL` lines named in the Verification inventory above.

5. In `skills/quest/scripts/publish-forge-review`, replace the whole `dispose()` function, from `dispose() {` through its
   closing `}`, with:

   ```sh
   run_disposer() { # candidate
   	case $disposer in
   	trash) trash "$1" ;;
   	gio) gio trash "$1" ;;
   	esac
   }

   # Disposal runs only after the verified ledger line, so the run's product is already
   # durable and a disposer that refuses a path -- gio trash declines system-internal
   # mounts -- is reported rather than fatal. Nonzero from this helper means it did not
   # publish. Every path is attempted: a filesystem that refuses one usually refuses all
   # of them, and one odd path must not strand the rest.
   dispose() {
   	local candidate disposed=() remaining=()
   	for candidate in "$@"; do
   		# Partition on what is left on disk, not on the disposer's status: a
   		# disposer that errors after removing the path leaves nothing to retain,
   		# and the previous implementation reported remaining paths the same way.
   		if run_disposer "$candidate" || [ ! -e "$candidate" ]; then
   			disposed[${#disposed[@]}]=$candidate
   		else
   			remaining[${#remaining[@]}]=$candidate
   		fi
   	done
   	if [ "${#disposed[@]}" -gt 0 ]; then
   		append_ledger "review-publication-disposed: ${disposed[*]}"
   	fi
   	[ "${#remaining[@]}" -gt 0 ] || return 0
   	printf 'publish-forge-review: recoverable disposal failed; remaining paths: %s\n' \
   		"${remaining[*]}" >&2
   	append_ledger "review-publication-undisposed: ${remaining[*]}"
   	# The record names every retained path, the generated body included, so the exit
   	# guard's unrecorded-leak check no longer applies to it.
   	body=''
   }
   ```

6. Confirm the expected green: `just test publish-forge-review`. Expect exit 0 and
   `20 passed, 0 failed`.

7. Verify the new assertions bite, reverting after each. (a) Change
   `[ "${#remaining[@]}" -gt 0 ] || return 0` to `return 0`; `just test publish-forge-review` must
   fail `PFR-6` and `PFR-20`. (b) Change the disposed append to
   `append_ledger "review-publication-disposed: ${disposed[*]} ${remaining[*]}"` guarded by a
   non-empty `remaining`; the run must fail `PFR-6` with `disposed record named a path that was
   retained`.

8. Run `just commit-check`. Expect exit 0.

9. Commit: `fix(quest): report and continue when publication cleanup fails`.

### Acceptance criteria

- `just test publish-forge-review` exits 0 with `20 passed, 0 failed`.
- With disposal succeeding, the ledger is byte-identical to the previous behaviour: one
  `review-publication-disposed:` line naming every owned path in owned order, no
  `review-publication-undisposed:` line. `PFR-1`, `PFR-15` and `PFR-16` pass unchanged.
- A disposer failure after `review-publication-verified:` exits 0, prints the comment URL on
  stdout, warns on stderr naming exactly the retained paths, and records exactly those paths in
  a `review-publication-undisposed:` line.
- No path is named in both records — `PFR-6`'s `*"$SUMMARY"*` arm fails a helper that violates
  this — and their union is every owned path.
- Every pre-publication failure still exits nonzero and still writes neither record, and a ledger
  append or readback failure after the verified line stays fatal and unchanged.

## Task 2 — Teach the consumers the second record

Modifies `skills/quest/SKILL.md`, `skills/forge/SKILL.md`, and `.claude-plugin/plugin.json`.
Task 1 changed the ledger's record set; these are the documents that say what to assert against
it. A consumer matching only `review-publication-disposed:` reads an incomplete cleanup as no
cleanup, which is the park this change removes.

**Interfaces.** Consumes the two records defined by Task 1,
`review-publication-disposed: <paths>` and `review-publication-undisposed: <paths>`, each listing
its own subset of the helper's owned paths in owned order: the required review in `required`
mode, then the summary, then the generated body, then the payload last.

### Verification

- **The `skills/` tree stays structurally valid.** Mode: `focused-test`, as a regression check
  rather than a test of this task's own edits: `check-skill-shape.sh` rule 5 resolves the
  reference links in `skills/*/SKILL.md`, and these edits add and move none, so the requirement is
  that the repository-wide gate still passes over the edited tree. Case: `just shape-check`.
  Expected red: pointing any one of that file's existing relative links at a path that does not
  exist makes rule 5 fail and name it — produced deliberately in step 7 and reverted. Green:
  `just shape-check`.
- **The manifest declares a well-formed, higher version.** Mode: `focused-test`. Contract:
  `check-plugin-version.sh` requires `version` to exist and to be `MAJOR.MINOR.PATCH` with no
  prerelease or build suffix. Case: the repository-wide gate run, `just version-check`. Expected
  red: setting the value to `4.1.2-rc1` fails the format rule and names it. Green:
  `just version-check`.
- **The prose describing the record set.** Mode: `task-test-not-applicable`. Changed surface:
  the normative sentences in `skills/quest/SKILL.md` steps 5 and 8, step 8's closing
  forge-scratch sentence, its recovery predicate list, and the retention-suppression clause in
  `skills/forge/SKILL.md`. Reason: these sentences are
  instructions read by a model, with no executable consumer that parses them; anatomy rule 4
  forbids a gate that greps Markdown for a sentence, and a test asserting on this wording would
  be exactly that gate.

### Steps

1. In `skills/quest/SKILL.md` step 5, replace the sentence `In `publication-verified`, the
   review, summary, and body are expected to be disposed: require the exact all-and-only
   disposal record, not a readable source artifact.` with:

   > In `publication-verified`, require the helper's exact closing records and never a readable
   > source artifact: a `review-publication-disposed:` line, a `review-publication-undisposed:`
   > line, or both. A path named by the undisposed record may still be on disk, and an operator
   > who removed it does not change the check — the records are the evidence, so a cleaned
   > workspace never parks a resume.

2. In the same file, in the paragraph beginning `On a verified-publication resume`, replace the
   run of sentences from `Require it to equal the URL` through `it must own only the exact
   `REVIEW_SUMMARY` and that one body.` with:

   > Require it to equal the URL in the exact `review-publication-verified: <URL>` ledger line
   > after this handoff's `forge-result-record`, then re-read its exact closing records. Their
   > union must own all and only the helper's former paths, each record listing its own subset in
   > owned order and no path appearing in both. In `required` mode those paths are the exact
   > retained review, `REVIEW_SUMMARY`, and one helper-created body in the ledger directory. In
   > `not-required` mode they are the exact `REVIEW_SUMMARY` and that one body. An owned path may
   > contain spaces, so never decide membership by splitting a record on whitespace: reconstruct
   > the exact record text for the partition under test from the known owned paths and compare
   > whole lines.

3. In the same file, in step 8, replace the run of sentences from `Then require the subsequent
   disposal record to own all` through `named last in the record.` with:

   > Then require the helper's subsequent closing records — a `review-publication-disposed:`
   > line, a `review-publication-undisposed:` line, or both — to own between them all and only
   > its former paths, each listing its own subset in owned order and no path appearing in both:
   > in `required` mode the exact review, `REVIEW_SUMMARY`, and one helper-created
   > `.publish-forge-review.*` body beside the ledger; in `not-required` mode the exact
   > `REVIEW_SUMMARY` and that one body; and, when this run carried a payload, the exact
   > `REVIEW_PAYLOAD` in both modes, named last among the owned paths. An owned path may contain
   > spaces, so never decide membership by splitting a record on whitespace: reconstruct the exact
   > record text for the partition under test from the known owned paths and compare whole lines.
   > An `undisposed` record is a completed publication whose cleanup did not finish. Continue
   > rather than parking: the ledger, not the exit status, says whether publication happened, and
   > the helper's stderr and that record already name the retained paths. Add no field to the
   > handoff for them — the `publication-verified` format admits none — and never name them in a
   > `WORK:*` annotation, which is public.

4. In the same file, at the end of step 8, replace the sentence `Carry that URL into step 9;
   `$return-to-town` needs no forge-scratch cleanup.` with:

   > Carry that URL into step 9. `$return-to-town` needs no forge-scratch cleanup after a
   > `review-publication-disposed:` record that owns every path; after a
   > `review-publication-undisposed:` record the paths it names are still in the private
   > workspace, so report the incomplete cleanup in the private completion report without naming
   > the paths publicly. They survive only as long as the run's checkout does — a worktree
   > teardown removes them along with the ledger — and removing them sooner is the operator's.

5. In the same file, in the *Human-authorized publication recovery* predicate list, extend the
   bullet that begins `after the handoff's exact `forge-result-record`, the ledger contains no`
   so it also requires no `review-publication-undisposed:` line, alongside the existing
   `review-publication-verified:`, `review-publication-disposed:`, and
   `review-publication-recovery-authorized:` absences.

6. In `skills/forge/SKILL.md`, replace the paragraph beginning `A `review-publication-disposed`
   line suppresses retention` with:

   > A `review-publication-disposed` or `review-publication-undisposed` line suppresses retention
   > only when it is paired with this range's retained record: that record names the current
   > forge-ledger identity and exact review path, and the later closing record names that same
   > review path. Either record proves the publication happened; the undisposed one additionally
   > means the file is still on disk. Do not match a generic marker, prefix, substring, or an
   > older range's closing record. Do not infer completion from a missing review file or from the
   > historical review line alone.

7. Run `just shape-check`. Expect exit 0. To confirm the gate bites, temporarily point one
   relative link in `skills/quest/SKILL.md` at a path that does not exist, re-run, observe rule 5
   name it, and revert.

8. In `.claude-plugin/plugin.json`, change `"version": "4.1.1"` to `"version": "4.1.2"`.

9. Run `just version-check`. Expect exit 0. To confirm the gate bites, temporarily set the value
   to `4.1.2-rc1`, re-run, observe the format failure, and revert.

10. Run `just verify`. Expect exit 0. It is the full guardrail suite and takes several minutes;
   run it as a background task rather than re-invoking it after an apparent timeout.

11. Commit: `docs(quest): read both publication closing records`.

### Acceptance criteria

- `skills/quest/SKILL.md` steps 5 and 8 and its recovery predicate list all name both records,
  and each membership sentence forbids splitting a record on whitespace.
- Step 8's closing sentence no longer claims `$return-to-town` needs no forge-scratch cleanup
  unconditionally, and no step adds a handoff field or names a retained path in a `WORK:*`
  annotation.
- `skills/forge/SKILL.md` accepts either record as proof of a completed publication.
- `.claude-plugin/plugin.json` declares `4.1.2`.
- `just verify` exits 0.

## Amendments applied during the branch review

The branch review found the partition as first written short-circuited: `run_disposer "$c" ||
[ ! -e "$c" ]` never evaluates the filesystem check when the disposer exits 0, so a disposer that
reports success without removing a path recorded it as disposed. The shipped `dispose()` discards
the disposer's status (`run_disposer "$c" || :`) and classifies on `[ -e "$c" ]` alone, and a new
`PFR-21` pins both halves. `skills/quest/SKILL.md` steps 5 and 8 also gained a clause naming how a
consumer identifies the generated body, without which the whole-line reconstruction has no
terminating step.

## Rollback and deferrals

Both commits are confined to the branch and revert together — Task 2's documents describe Task
1's records, so neither is independently revertible. The version bump lands in Task 2, after the
design and Task 1 commits, so the pull request is not opened until Task 2 step 8 has landed; ADR
0022's gate compares the tree to `BASE_SHA`, not commit by commit. No `$trial-loop` deferral
exists yet; any this branch's review disposes of is recorded here with its owning record path or
tracker issue before the branch ships.

### Deferrals carried from review

- **A ledger append or readback failure after `review-publication-verified:` still parks
  permanently.** Raised by the scope audit over this design set. Valid and independent: it has a
  different root cause from #306's disposer failure, closing it means revisiting the
  publication-recovery predicates ADR 0048 deliberately drew, and this change neither introduces
  it nor changes its failure mode — it only adds a second ledger append after the verified line.
  Owner: [#312](https://github.com/randomparity/adept/issues/312) (this repository keeps no
  `docs/debt/`).
- **`finish_body_lifecycle`'s `local exit_status` / `exit_status=$?` split makes every failing run
  print `successful publication left its body behind`.** Raised by the scope audit, which held it
  out of the approved surface as adjacent work. Cut from this change rather than fixed. Owner:
  [#313](https://github.com/randomparity/adept/issues/313).
