# Bound publish-handoff's five network calls — implementation plan

**Goal.** Bound every network call `skills/return-to-town/scripts/publish-handoff` makes, so an
unreachable remote produces a named exit 2 rather than an indefinite block, and so the calls after
the write report honestly what they could not verify.

**Architecture.** One shipped Bash executable gains the `bounded_call` idiom recorded in
`references/network-bounds.md` plus two thin wrappers: `bounded_network_call` (capture slot in the
existing scratch workspace; passes captured stderr through on every status but 124) and
`timed_out` (an exceeded bound becomes the script's existing `fault`, exit 2). Each of the five
sites stops capturing into a command substitution and reads its value back out of the stdout
capture file. The suite gains five timeout cases over a fake `gh` that hangs, plus an opt-in `git`
shim for the one `git` site.

**Tech stack.** Bash, run under `/bin/bash` 3.2.57 on macOS and under whatever `env bash` resolves
on CI Linux. `gh`, `jq`, `git`, `rg`, `shellcheck`, `shfmt`, `just`.

Expected implementation size: 250–300 changed lines (M) — counted from this plan's own blocks:
~115 in the executable (36-line transcribed `bounded_call`, ~25 of wrappers, ~11 of constant and
header comment, ~43 across the five restructured sites), ~12 in `SKILL.md`, ~144 in the fixture,
and one manifest value. That sits just above the frozen 250-line M denominator, which bounds the
*design* against the change it governs and is neither an implementation budget nor resized here.

## Global Constraints

Transcribed from `CLAUDE.md` and the frozen scope record, values and all.

- **Bash 3.2 is the floor.** macOS ships 3.2.57. No `mapfile`, no `readarray`, no associative
  arrays.
- Shell is bash with **tab indentation**, `#!/usr/bin/env bash`, and `set -euo pipefail`.
- `rg` invocations in gate scripts pass `--no-config`.
- Capture a scan's exit status explicitly rather than trailing `|| true`. **ADR 0047 gates this**:
  `scripts/check-scan-fault-discards.sh` fails a trailing `|| true` or `|| :` on any command that
  is not a pure builtin, absent a `# scan-fault: deliberate — <reason>` pragma. `kill` and `wait`
  are exempt builtins; `cat`, `grep`, `awk`, `jq` and `gh` are not.
- Prefer ≤100 lines per function, cyclomatic complexity ≤8, 100-character lines.
- The repository is **public**: no host-specific configuration, absolute user paths, local
  hostnames or addresses, auth headers, API keys, or session state. Specs and plans name the
  checkout root as `$WORK`.
- **Bound: 30 seconds** for a call that issues one request; 120 for one that may issue more. All
  five sites here issue one request each, so all five take 30. The bound is not exact — a
  30-second bound fires at roughly 32 — and must not be documented as a deadline.
- **`124` is internal.** It is never a script's exit status.
- **Classification for this caller:** `fault` — exit 2, its "could not run" class.
- **Excluded convention-wide:** retry, backoff, bounding non-network subprocesses, and adding a
  binary to `require_commands`.
- `.claude-plugin/plugin.json` version for this pull request is exactly **5.10.1**.
- Guardrails: `just test <pattern>` for a focused run, `just verify` for the full local suite,
  `just ci` in CI and in the managed pre-push hook. Run them bare.

## File map

| Path | Owns today | Owns after |
|---|---|---|
| `skills/return-to-town/scripts/publish-handoff` | composes, posts and verifies the hand-off annotation over five unbounded network calls | the same, with every network call bounded and every timeout classified |
| `skills/return-to-town/SKILL.md` | the helper's contract prose, including an unqualified re-run rule and a paragraph saying the calls are unbounded | the same contract, with the re-run rule qualified at its own sentence and the unbounded paragraph replaced by the timeout rule |
| `tests/fixtures/return-to-town/publish-handoff-test.sh` | 40 behaviour cases over a fake `gh` and a real `git` | the same, plus two fixture helpers, four `gh` hang modes and five timeout cases |
| `.claude-plugin/plugin.json` | `5.10.0` | `5.10.1` |

No ownership transition: ADR 0068 leaves extraction to whichever applier reaches the third
repetition, and this one is among three running in parallel that cannot observe that count.

**Fixture margins, fixed for both tasks.** Every timeout case runs a copy of the helper whose one
bound constant is rewritten to **2 seconds** against a fake that hangs for **30**: 15x on the
bound firing, 60x on the calls that must *succeed* in those cases (~30 ms each). A case added
later is counted against both.

## Task 1 — bound the three pre-write reads

Creates nothing. Modifies `skills/return-to-town/scripts/publish-handoff` and
`tests/fixtures/return-to-town/publish-handoff-test.sh`.

**Interfaces.** Defines, for Task 2 to consume:

- `bounded_call <seconds> <out-file> <err-file> <command...>` → the command's own status, or 124.
- `bounded_network_call <slot> <command...>` → same statuses; sets globals `call_out` and
  `call_err` to `$workspace/<slot>.out` and `$workspace/<slot>.err`.
- `timed_out <call-description> <consequence>` → prints and exits 2; never returns.
- Globals `NETWORK_BOUND_SECONDS`, `call_out`, `call_err`.
- Fixture function `short_bound_helper` → sets global `HELPER_PATH` to a copy of the script whose
  bound is 2 seconds; returns non-zero if the constant could not be rewritten.
- Fixture function `write_fake_git <bin-dir>` → installs a `git` shim that hangs on `ls-remote`
  and execs the real `git` for everything else.

**Verification.**

All three cases live in `tests/fixtures/return-to-town/publish-handoff-test.sh`, take
`Mode: focused-test`, and go green under `just test publish-handoff`. Run after step 7 and before
step 8, each reports `FAIL <its label>: the bound constant could not be rewritten`, because
`NETWORK_BOUND_SECONDS` does not exist for the fixture's `sed` to find. That red names the missing
constant rather than a bare status, so a broken fixture cannot produce the same line.

- Contract: *an exceeded bound on `gh pr view` exits 2 naming the call.* Case
  `case_pr_view_times_out`.
- Contract: *an exceeded bound on the destination read exits 2 naming the destination.* Case
  `case_issue_read_times_out`.
- Contract: *an exceeded bound on `git ls-remote` exits 2 naming the ref.* Case
  `case_ls_remote_times_out`.

### Steps

Steps 1–7 build the failing cases; step 8 onward implements against them.

1. In `tests/fixtures/return-to-town/publish-handoff-test.sh`, amend the file header comment's
   second sentence so it reads: `` `git` is not faked, except in the one case that bounds `git
   ls-remote`: the SHA the whole contract turns on is what `git ls-remote` returns, so the fixture
   builds a real repository with a real bare remote and the helper reads it for real. ``

2. In the fake `gh`'s `pr` arm, extend the existing mode switch so it reads:

   ```bash
   	case ${GH_MODE:-success} in
   	pr-view-fail) exit 1 ;;
   	# A partial object first, for a later site that parses a capture on the 124
   	# path -- nothing here does, and the spec says so rather than claiming this
   	# case observes the discard.
   	hang-pr-view)
   		printf '{"number": 4'
   		exec sleep 30
   		;;
   	esac
   ```

3. In the fake `gh`'s `api` arm, add `hang) exec sleep 30 ;;` to the
   `case ${FAKE_ISSUE_MODE:-present}` that already carries `absent) exit 1 ;;`.

4. In `new_case`, add `HELPER_PATH=''` beside the other assignments, so a case that sets the
   global cannot leak it into the next case.

5. Add both fixture helpers immediately after `run_helper`:

   ```bash
   # The shipped bound is 30 seconds, which no test can wait for, so a case that has
   # to reach it runs a copy of the script with that one assignment rewritten to 2.
   # The root gets a stub public-safety gate, not a symlink: check-public-safety.sh
   # is itself a shim execing $ROOT/skills/quest/scripts/check-public-safety computed
   # from its own location, so a symlinked scripts/ resolves back here and finds no
   # skills/quest -- case_cdpath_does_not_steer_resolution stubs it for that reason.
   # The grep is the point: a renamed constant fails loudly here rather than silently
   # restoring a 30-second wait nothing would ever hit.
   short_bound_helper() { # -- sets HELPER_PATH
   	local root copy
   	root="$CASE/bounded-root"
   	copy="$root/skills/return-to-town/scripts/publish-handoff"
   	mkdir -p "$root/skills/return-to-town/scripts" "$root/scripts"
   	printf '#!/usr/bin/env bash\nexit 0\n' >"$root/scripts/check-public-safety.sh"
   	chmod +x "$root/scripts/check-public-safety.sh"
   	sed 's/^NETWORK_BOUND_SECONDS=30$/NETWORK_BOUND_SECONDS=2/' "$SCRIPT" >"$copy"
   	grep -qxF 'NETWORK_BOUND_SECONDS=2' "$copy" || return 1
   	chmod +x "$copy"
   	HELPER_PATH=$copy
   }

   # Only the ls-remote case installs this. Everything but ls-remote is the real git,
   # whose path is baked in here because the shim shadows it on PATH.
   write_fake_git() { # bin
   	local bin=$1
   	cat >"$bin/git" <<EOF
   #!/usr/bin/env bash
   set -euo pipefail
   if [ "\${1:-}" = ls-remote ]; then
   	exec sleep 30
   fi
   exec '$(command -v git)' "\$@"
   EOF
   	chmod +x "$bin/git"
   }
   ```

6. Add the three read cases immediately before `case_missing_command`:

   ```bash
   # --- bounded network calls ---------------------------------------------------

   case_pr_view_times_out() {
   	local label='a pull request read that exceeds the bound is a named fault'
   	new_case
   	short_bound_helper || {
   		fail_case "$label" 'the bound constant could not be rewritten'
   		return 0
   	}
   	GH_MODE=hang-pr-view run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
   	expect_status "$label" 2 || return 0
   	expect_stderr "$label" "reading pull request $REPO#$PR" || return 0
   	expect_stderr "$label" 'network bound' || return 0
   	expect_stderr "$label" 'nothing was posted' || return 0
   	[ ! -e "$STATE/comment-body" ] || {
   		fail_case "$label" 'a comment was posted despite the timed-out read'
   		return 0
   	}
   	ok "$label"
   }

   case_issue_read_times_out() {
   	local label='a destination read that exceeds the bound is a named fault'
   	new_case
   	short_bound_helper || {
   		fail_case "$label" 'the bound constant could not be rewritten'
   		return 0
   	}
   	FAKE_ISSUE_MODE=hang run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
   	expect_status "$label" 2 || return 0
   	expect_stderr "$label" "reading the hand-off destination $REPO#$ISSUE" || return 0
   	expect_stderr "$label" 'network bound' || return 0
   	ok "$label"
   }

   case_ls_remote_times_out() {
   	local label='an origin read that exceeds the bound is a named fault'
   	new_case
   	short_bound_helper || {
   		fail_case "$label" 'the bound constant could not be rewritten'
   		return 0
   	}
   	write_fake_git "$BIN"
   	run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
   	expect_status "$label" 2 || return 0
   	expect_stderr "$label" "reading refs/heads/$BRANCH from origin" || return 0
   	expect_stderr "$label" 'network bound' || return 0
   	# The "nothing was posted" guard lives in case_pr_view_times_out alone: all
   	# three time out ahead of compose_body, so one case settles the pre-write path.
   	ok "$label"
   }
   ```

7. Register the three cases in the invocation list at the bottom of the file, immediately after
   `case_pr_view_fails`. Run `just test publish-handoff` and confirm the three expected red lines
   above, then stop and implement.

8. In `skills/return-to-town/scripts/publish-handoff`, extend the header comment that ends
   `"...what the orchestrator otherwise has to work out by re-reading the body."` with a blank
   comment line and:

   ```bash
   # Every network call here is bounded (references/network-bounds.md). A call that
   # exceeded its bound reported nothing, so it is exit 2 -- "could not run" -- and
   # never exit 1, which would claim a condition was checked and found false. Past
   # the write a bound cannot make the call atomic: a timeout on the create, or on
   # the readback after it, leaves a comment this script cannot verify, and the
   # diagnostic says which rather than guessing either way.
   ```

9. Below `MAX_NOTES_BYTES=8192`, add:

   ```bash
   # Each of the five network calls below issues exactly one request, so each takes
   # the 30-second bound in references/network-bounds.md. Not a deadline: the poll
   # loop's own overhead accumulates and a 30-second bound fires at roughly 32.
   NETWORK_BOUND_SECONDS=30
   ```

10. In the variable block, add `call_out=''` and `call_err=''` beside the existing declarations.
    Leave `response=''` alone — Task 2 replaces it, and removing it here would leave a
    `response_file` no Task-1 step reads, which `shellcheck -x` reports as SC2034 and
    `Justfile:115` turns into a red gate.

11. Immediately after `make_workspace`, add `bounded_call`. Its body is not authored here:
    transcribe the fenced `bounded_call` block from `references/network-bounds.md` — the lines
    between its ```` ```bash ```` and closing fence — into the script unchanged, so the repository
    has one canonical copy of the idiom and no second place for it to drift. Then make exactly two
    comment edits inside the transcribed body, changing no executable line:

    - Shorten the `rc, not status` comment to drop its cross-file line citation, leaving:
      `# rc, not status: under zsh` + backtick + `status` + backtick + ` is a read-only special parameter.`
    - Extend the `# TERM, then KILL only if TERM does not land. Never a bare KILL.` comment with
      the reason, so the line reads across two comment lines:

      ```bash
   		# TERM, then KILL only if TERM does not land. Never a bare KILL: SIGKILL
   		# cannot be handled, so a git severed by it never tears down the ssh or
   		# git-remote-https it spawned and the transport outlives this call.
      ```

    Verify the transcription with
    `diff <(sed -n '/^bounded_call() {/,/^}$/p' references/network-bounds.md) <(sed -n '/^bounded_call() {/,/^}$/p' skills/return-to-town/scripts/publish-handoff)`
    and expect only the two comment hunks above.

12. Immediately after `bounded_call`, add the two wrappers:

    ```bash
    # One bounded network call. On return the stdout capture is $call_out and the
    # stderr capture $call_err. Returns 124 for an exceeded bound, the command's own
    # status otherwise: the caller classifies, because only it knows whether the call
    # was a write. Capturing stderr to a file would stop it reaching the terminal --
    # gh writes non-fatal material there while exiting 0 -- so it is passed through
    # on every status but 124, where a partial diagnostic would read as an answer.
    bounded_network_call() { # slot command...
    	local slot=$1 rc=0
    	shift
    	call_out="$workspace/$slot.out"
    	call_err="$workspace/$slot.err"
    	bounded_call "$NETWORK_BOUND_SECONDS" "$call_out" "$call_err" "$@" || rc=$?
    	if [ "$rc" -ne 124 ] && [ -s "$call_err" ]; then
    		# Not a colon-discard: cat is not a pure builtin, so ADR 0047's gate
    		# would refuse one here, and a diagnostic this could not relay is worth
    		# a line of its own rather than silence.
    		cat -- "$call_err" >&2 ||
    			printf 'publish-handoff: the call diagnostic at %s could not be read\n' \
    				"$call_err" >&2
    	fi
    	return "$rc"
    }

    # A timeout is a fault, never a finding: the call reported nothing, so it never
    # reported that a condition was checked and found false. Exit 2 is this script's
    # "could not run" class, which is the row references/network-bounds.md assigns it.
    timed_out() { # call-description consequence
    	fault "$1 exceeded the ${NETWORK_BOUND_SECONDS}-second network bound; $2"
    }
    ```

13. In `resolve_head`, replace the `pr_json=$(gh pr view ...)` assignment and its `|| fault` with:

    ```bash
    	bounded_network_call pr-view gh pr view "$pr" --repo "github.com/$repo" \
    		--json number,state,headRefName,headRefOid,isCrossRepository,closingIssuesReferences ||
    		rc=$?
    	[ "$rc" -ne 124 ] ||
    		timed_out "reading pull request $repo#$pr" 'nothing was posted'
    	[ "$rc" -eq 0 ] ||
    		fault "the pull request could not be read: $repo#$pr"
    	pr_out=$call_out
    ```

    Change the function's `local` line to `local number state head_branch head_ref_oid cross
    pr_out ls_output line_count rc=0` — `pr_json` is gone and `pr_out` and `rc` are new.

14. In `resolve_head`, change each of the six `jq` reads from `<<<"$pr_json"` to the file operand
    `"$pr_out"`: `.closingIssuesReferences[].number`, `.number`, `.state`, `.headRefName`,
    `.headRefOid`, and `.isCrossRepository`. Leave every message unchanged.

15. In `resolve_head`, replace the `ls_output=$(git ls-remote ...)` assignment and its `|| fault`
    with:

    ```bash
    	rc=0
    	bounded_network_call ls-remote git ls-remote origin "refs/heads/$head_branch" || rc=$?
    	[ "$rc" -ne 124 ] ||
    		timed_out "reading refs/heads/$head_branch from origin" 'nothing was posted'
    	[ "$rc" -eq 0 ] ||
    		fault "git ls-remote could not read refs/heads/$head_branch from origin; run this from the checkout whose origin is $repo"
    	ls_output=$(cat "$call_out") ||
    		fault 'the refs origin reported could not be read'
    ```

    Everything below it — the emptiness check, `wc -l`, the SHA shape checks, the `headRefOid`
    agreement check, and the handshake composition — is unchanged.

16. In `resolve_destination`, replace the `issue_json=$(gh api ...)` assignment and its `|| fault`
    with:

    ```bash
    	bounded_network_call issue-read gh api --hostname github.com "/repos/$repo/issues/$issue" ||
    		rc=$?
    	[ "$rc" -ne 124 ] ||
    		timed_out "reading the hand-off destination $repo#$issue" 'nothing was posted'
    	[ "$rc" -eq 0 ] ||
    		fault "the hand-off destination could not be read: $repo#$issue -- check the ISSUE argument first, then whether GitHub is reachable"
    	issue_out=$call_out
    ```

    Change the function's `local` line to `local is_pull number matched issue_out rc=0`, and change
    its three `jq` reads from `<<<"$issue_json"` to the file operand `"$issue_out"`:
    `if has("pull_request") then "yes" else "no" end`, `.number`, and `.html_url // empty`.

17. Run `shfmt -d skills/return-to-town/scripts/publish-handoff`,
    `shellcheck -x skills/return-to-town/scripts/publish-handoff`, and
    `./scripts/check-scan-fault-discards.sh`. Expect no output and exit 0 from all three.

18. Run `just test publish-handoff`. Expect `publish-handoff-test: 43 passed, 0 failed` and
    exit 0.

**Acceptance criteria.** Three read sites bounded; `pr_json`, `issue_json` and the `git ls-remote`
command substitution are gone; three timeout cases pass; `shellcheck -x`, `shfmt -d` and the
scan-fault gate clean; `require_commands` byte-identical.

## Task 2 — bound the write and the readback, and state the rule

Creates nothing. Modifies `skills/return-to-town/scripts/publish-handoff`,
`skills/return-to-town/SKILL.md`, `tests/fixtures/return-to-town/publish-handoff-test.sh`, and
`.claude-plugin/plugin.json`.

**Interfaces.** Consumes from Task 1: `bounded_network_call <slot> <command...>` (sets `call_out`
and `call_err`, returns 124 on an exceeded bound), `timed_out <call-description> <consequence>`,
the globals `NETWORK_BOUND_SECONDS` and `call_out`, and the fixture's `short_bound_helper`.
Defines the global `response_file`, read only within this task.

**Verification.**

Both cases take `Mode: focused-test` and go green under `just test publish-handoff`. Run after
step 3 and before step 4, each waits out the fake's full 30-second sleep because the site is still
unbounded, then fails: the write case at `expected exit 2, got 0`, the readback case at
`expected exit 2, got 1` (an empty stored body fails the gate assertions). A bare status is
ambiguous, so both also assert stderr substrings no other failure produces.

- Contract: *an exceeded bound on `gh issue comment` exits 2, reports the write as indeterminate,
  and prints no URL.* Case `case_comment_write_times_out`.
- Contract: *an exceeded bound on the readback exits 2 and names the created comment's URL.* Case
  `case_readback_times_out`.
- Contract: *the re-run rule covers a timeout, at the sentence the criterion names and in the
  paragraph below it.* Mode: `task-test-not-applicable` — the changed surface is instruction
  prose, and CLAUDE.md anatomy rule 4 forbids a gate asserting on a sentence.
- Contract: *the manifest declares version 5.10.1 exactly*. Mode: `focused-test`.
  `just version-check`, expected to exit 0.

### Steps

Steps 1–3 build the failing cases; step 4 onward implements against them.

1. In the fake `gh`'s `issue` arm, add one arm to the URL-emitting mode switch — the one whose
   last arm is the default `issuecomment-73` URL, which runs after `cp "$body"
   "$state/comment-body"` has already recorded the write. Place it immediately before that
   default arm, changing no other arm:

   ```bash
   	# The comment is recorded above and a plausible URL is emitted before the
   	# hang, which is the real hazard: the write landed and its response did not
   	# arrive. The case then proves the helper reported neither as settled.
   	hang-comment)
   		printf '%s\n' "https://github.com/$url_repo/issues/$issue_number#issuecomment-73"
   		exec sleep 30
   		;;
   ```

2. In the fake `gh`'s `api` arm, add `hang-readback) exec sleep 30 ;;` to the
   `case ${GH_MODE:-success}` that already carries `read-fail) exit 1 ;;`.

3. Add the two post-write cases immediately after `case_ls_remote_times_out`, then register both
   in the invocation list immediately after `case_ls_remote_times_out`. Run
   `just test publish-handoff` and confirm the two expected red lines above, then stop and
   implement.

   ```bash
   case_comment_write_times_out() {
   	local label='a write that exceeds the bound reports an indeterminate comment'
   	new_case
   	short_bound_helper || {
   		fail_case "$label" 'the bound constant could not be rewritten'
   		return 0
   	}
   	GH_MODE=hang-comment run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
   	expect_status "$label" 2 || return 0
   	expect_stderr "$label" "creating the hand-off comment on $REPO#$ISSUE" || return 0
   	expect_stderr "$label" 'network bound' || return 0
   	expect_stderr "$label" 'may or may not have landed' || return 0
   	# The fake recorded the write and emitted a URL before hanging. Both assertions
   	# below are the contract: the helper must not claim nothing was posted, and it
   	# must not print a verified URL it never verified.
   	[ -e "$STATE/comment-body" ] || {
   		fail_case "$label" 'the fixture did not record the write it is meant to model'
   		return 0
   	}
   	[ -z "$RUN_OUT" ] || {
   		fail_case "$label" "stdout carried '$RUN_OUT' for an unverified write"
   		return 0
   	}
   	ok "$label"
   }

   case_readback_times_out() {
   	local label='a readback that exceeds the bound names the comment it could not verify'
   	new_case
   	short_bound_helper || {
   		fail_case "$label" 'the bound constant could not be rewritten'
   		return 0
   	}
   	GH_MODE=hang-readback run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
   	expect_status "$label" 2 || return 0
   	expect_stderr "$label" 'reading back the stored hand-off comment' || return 0
   	expect_stderr "$label" "https://github.com/$REPO/issues/$ISSUE#issuecomment-73" || return 0
   	expect_stderr "$label" 'was not verified' || return 0
   	[ -z "$RUN_OUT" ] || {
   		fail_case "$label" "stdout carried '$RUN_OUT' for an unverified comment"
   		return 0
   	}
   	ok "$label"
   }
   ```

4. In `post_comment`, replace the `output=$(gh issue comment ...)` assignment and the two lines
   below it with:

   ```bash
   	bounded_network_call comment gh issue comment "$issue" --repo "github.com/$repo" \
   		--body-file "$body" || post_status=$?
   	# A bound cannot make a write atomic. Killed after GitHub created the comment
   	# but before its URL came back, this call leaves a published block the script
   	# cannot see -- so it is indeterminate, not a failure, and it is not retried.
   	[ "$post_status" -ne 124 ] ||
   		timed_out "creating the hand-off comment on $repo#$issue" \
   			"the write may or may not have landed and this script cannot tell; inspect $repo#$issue before re-running, because a re-run appends another comment"
   	[ "$post_status" -eq 0 ] ||
   		fail "the hand-off comment was not created on $repo#$issue"
   	# A scan that could not run is a fault, not a finding: the empty-candidate
   	# check below is the condition, and awk failing is not that condition.
   	candidate=$(awk 'NF { count += 1; value = $0 } END { if (count == 1) print value }' "$call_out") ||
   		fault 'the comment-creation response could not be scanned for a URL'
   ```

   Change the function's `local` line to `local post_status=0 candidate` — `output` is gone. Leave
   the `[ -n "$candidate" ] || fail ...` check and the trailing `printf` unchanged.

5. In the variable block, replace `response=''` with `response_file=''`.

6. In `read_stored_body`, replace the `response=$(gh api ...)` assignment and the two lines below
   it with:

   ```bash
   	bounded_network_call readback gh api --hostname github.com "$endpoint" || api_status=$?
   	# Post-write, and here the create already returned a URL: what a timeout costs
   	# is the verification, not the comment. Reporting it as a failed readback would
   	# understate a published block nobody has checked.
   	[ "$api_status" -ne 124 ] ||
   		timed_out "reading back the stored hand-off comment $endpoint" \
   			"the comment was created at $url and its stored copy was not verified; inspect it rather than re-running, because a re-run appends another comment"
   	[ "$api_status" -eq 0 ] ||
   		fail "the stored hand-off comment could not be read back: $endpoint"
   	response_file=$call_out
   	jq -r '.body' "$response_file" >"$stored" ||
   		fail "the stored hand-off comment could not be parsed: $endpoint"
   ```

7. In `assert_stored_body`, change the final check's here-string to the file operand:

   ```bash
   	jq -e --rawfile expected "$body" '.body == $expected' "$response_file" >/dev/null ||
   ```

   Leave its `fail` message unchanged.

8. Run `shfmt -d skills/return-to-town/scripts/publish-handoff`,
   `shellcheck -x skills/return-to-town/scripts/publish-handoff`, and
   `./scripts/check-scan-fault-discards.sh`. Expect no output and exit 0 from all three.

9. In `skills/return-to-town/SKILL.md`, qualify the re-run instruction at its own sentence. Replace
   `Re-run it once rather than diagnosing the block by hand.` with:

   ```markdown
   Re-run it once — unless the exit names an exceeded network bound — rather than diagnosing the
   block by hand.
   ```

10. In the same file, replace the two-sentence paragraph beginning `"Those network calls carry no
    bound today..."` with:

    ```markdown
    Every network call it makes is bounded per
    [network bounds](../../references/network-bounds.md), and a call that exceeds its bound exits 2
    naming itself. **A timeout is not a re-run condition.** The instruction above covers conditions
    the helper checked and found false; a timeout checked nothing. Read which call the diagnostic
    names: the three before the write report that nothing was posted, the readback names the
    comment it created and could not verify, and only the write itself may or may not have landed.
    Inspect the issue in every case. If a complete block is there the hand-off is published:
    proceed from it. If there is none, re-run once. Never re-run on the timeout alone.
    ```

11. Set `"version": "5.10.1"` in `.claude-plugin/plugin.json`.

12. Run `just test publish-handoff`. Expect `publish-handoff-test: 45 passed, 0 failed` and exit 0.

13. Run `just verify`. Expect exit 0.

**Acceptance criteria.** Both post-write sites bounded; `output` and `response` are gone; the
write reports indeterminate and the readback names the created comment; five timeout cases pass;
`SKILL.md` qualifies the re-run rule at its own sentence and no longer says the calls are
unbounded; the manifest is 5.10.1; `just verify` exits 0.

## Deferrals carried into this plan

None — every design-review finding was `accepted-fixed` in the artifacts above.
