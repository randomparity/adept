# Plan — bound the gh calls in publish-forge-review and cleared-dependencies.sh

Goal: every `gh` call in these two shipped executables runs under the bound recorded in
`references/network-bounds.md`, and a bound exceeded is reported in each file's own vocabulary as
something that did not answer.

Architecture: each file gains one transcription of the reference's `bounded_call` — background,
poll, TERM, grace, KILL, reap, return 124 — and one thin local wrapper that owns capture-file
allocation and cleanup. Call sites classify 124 themselves, because each one's diagnostic differs
and four of them are writes that must report indeterminacy. Nothing is extracted across the two
files: ADR 0068 leaves a shared helper to the applier that reaches the third repetition, and this
change is the second of four.

Tech stack: Bash, `gh`, `jq`, `awk`, `mktemp`.

Spec: `docs/workflow/specs/2026-09-15-bound-forge-review-and-cleared-dependencies-design.md`

Expected implementation size: 230–310 changed lines (M) — derived from the file map below: two
new `bounded_call` transcriptions at about 32 lines each, one new `run_gh`, one rewritten
`cleared_dependency_run`, nine call-site edits, two suite additions of roughly 60 lines each, and
a one-line manifest bump.

## Global Constraints

- **Bash 3.2 is the floor.** macOS ships 3.2.57. No `mapfile`, no `readarray`, no associative
  arrays. Integer arithmetic only in the poll counters.
- `#!/usr/bin/env bash`, `set -euo pipefail`, **tab indentation**. `cleared-dependencies.sh` is
  the standing exception to `set -euo pipefail`: it is sourced, and it has none today. Do not add
  one.
- `rg` invocations in gate scripts pass `--no-config`.
- Capture a scan's exit status explicitly rather than trailing `|| true`.
- A status-discard idiom (`|| :`, `|| true`) in a shell source needs a
  `# scan-fault: deliberate — <reason>` pragma or `just scan-fault-check` fails — **except** on a
  pure builtin, and `scripts/check-scan-fault-discards.sh:45` lists `kill` and `wait` among them.
  The transcribed `kill … || :` and `wait … || :` lines therefore take no pragma, which keeps both
  copies byte-comparable against the reference.
- macOS ships no `timeout(1)`. Do not add `timeout` or `gtimeout` to any required-command list;
  ADR 0068 forbids it and issue #382 owns that list.
- No retry and no backoff anywhere. `references/network-bounds.md` line 6.
- The seven non-adaptable properties at `references/network-bounds.md:71-107` are not negotiable.
  Read them there before changing any transcribed line.
- Every value reaching `$((bound * 10))` is validated first: digits only, no leading zero, at most
  seven of them. Measured on `/bin/bash` 3.2.57 — a bound of `x[$(echo PWNED >&2)]` executes the
  substitution; `010` is read as octal 8; a twenty-digit value overflows 64 bits; and `08` is an
  arithmetic error inside the poll condition, where `set -e` is suspended, so the bounded call
  returns 0 with an empty capture and leaves its child running.
- `124` is internal. It may pass between two functions inside a file; it is never either script's
  exit status.
- Bounds: **30 s** for a call that issues one request, **120 s** for one that may issue more.
- Public repository. No absolute host paths, hostnames, addresses, or credentials in anything
  committed.

## File map

| File | Owns now | Owns after |
|---|---|---|
| `skills/quest/scripts/publish-forge-review` | Composes, posts, verifies and disposes one `WORK:REVIEW` annotation; two unbounded `gh` calls | The same, with both calls bounded and a `bounded_call` + `run_gh` pair |
| `skills/quest-log/assets/cleared-dependencies.sh` | The cleared-dependency recipe; one reading wrapper over `gh` plus three direct label writes, all unbounded | The same, with the wrapper bounded and taking a bound argument, and the three writes routed through it |
| `tests/fixtures/quest/publish-forge-review-test.sh` | 22 registered cases | 24 — two timeout cases added |
| `tests/fixtures/quest-log/cleared-dependencies-test.sh` | Sourced and direct-execution behaviour coverage | The same plus eight timeout assertions |
| `.claude-plugin/plugin.json` | the base ref's version | `version: 5.10.2`, this row's reservation in the campaign's ascending merge order |

No file moves, no owner changes, no obsolete path to remove, no compatibility path retained.
Both files keep their current responsibility; this is a clean extension of each.

## Task 1 — bound both calls in `publish-forge-review`

Creates: nothing. Modifies: `skills/quest/scripts/publish-forge-review`.
Tests: `tests/fixtures/quest/publish-forge-review-test.sh`.

**Interfaces.** Consumes nothing from earlier tasks. Defines, for this file only:
`bounded_call <seconds> <out-file> <err-file> <command…>` returning the command's status or 124;
`run_gh <seconds> <gh-args…>` returning the same and leaving the call's stdout at the path in the
global `gh_capture`. Constants `BOUND_MULTI` (120) and `BOUND_SINGLE` (30), overridden separately
by `PUBLISH_FORGE_REVIEW_BOUND_MULTI` and `PUBLISH_FORGE_REVIEW_BOUND_SINGLE`. Task 2 defines its
own copies under different names and shares nothing with these.

### Verification

- **Contract: a bound exceeded on the `gh pr comment` write exits 1 and reports indeterminacy.**
  Mode: focused-test. Observable: the script's exit status, its stderr, the fake's invocation
  count, and the retained body. Case `PFR-22` in
  `tests/fixtures/quest/publish-forge-review-test.sh`. Expected red before the script change: the
  case hangs for the fake's full 30 s because nothing bounds the call. Green:
  `just test publish-forge-review`.
- **Contract: a bound exceeded on the `gh api` readback exits 1 and does not dispose the posted
  comment's inputs.** Mode: focused-test. Case `PFR-23` in the same file. Expected red: the same
  hang. Green: the same command.
- **Contract: the bounded child is reaped rather than left running.** Mode: focused-test. `PFR-22`
  asserts `kill -0` fails against the pid the fake recorded. Expected red: the pid is still alive
  because no wrapper signalled or reaped it. Green: the same command.
- **Contract: each bound constant reaches the site the table assigns it to.** Mode: focused-test —
  the two overrides are settable apart, so `PFR-22` and `PFR-23` set them to 2 and 1 and assert
  `exceeded its 2s bound` and `readback exceeded its 1s bound` respectively. Transposing them at
  either call site turns the suite red. Green: `just test publish-forge-review`.
- **Contract: `preflight()` refuses a bound the arithmetic destination would not accept.** Mode:
  task-test-not-applicable — the guard is reached before `validate_content`, so a refusing case
  here would assert only that `preflight` ran, which `PFR-11` already covers. Its reachable half
  is exercised against the identical guard in the sibling file, where the wrapper is callable
  directly; the command-substitution half stays untested in both because observing it means
  committing the payload.

### Steps

1. In the global block at `:13-25`, add `gh_capture=''` after `body=''`.
2. Immediately below it add the two constants:

   ```bash
   # Seconds. gh pr comment issues a lookup and a mutation; gh api issues one
   # request. references/network-bounds.md carries the rule, ADR 0068 the record.
   # The two overrides exist so the behaviour suite can reach each bound without a
   # real wait, and set them apart so a transposition is observable; no caller sets
   # them.
   BOUND_MULTI=${PUBLISH_FORGE_REVIEW_BOUND_MULTI:-120}
   BOUND_SINGLE=${PUBLISH_FORGE_REVIEW_BOUND_SINGLE:-30}
   ```

3. Replace `fail()` at `:41-44` with the form that also clears the capture, since every fatal path
   in this script runs through it:

   ```bash
   fail() {
   	# Every fatal path runs through here, so this is the one place a gh capture
   	# needs removing. The composed body is deliberately retained instead, by the
   	# exit trap.
   	if [ -n "$gh_capture" ] && [ -e "$gh_capture" ]; then
   		rm -f -- "$gh_capture" ||
   			printf 'publish-forge-review: retained gh capture: %s\n' "$gh_capture" >&2
   	fi
   	printf 'publish-forge-review: %s\n' "$1" >&2
   	exit 1
   }
   ```

4. After `fail()`, add the transcribed mechanism and the local wrapper:

   ```bash
   # Run a command under a bound. Returns the command's own status, or 124 when the
   # bound was exceeded. stdout and stderr land in separate caller-owned files.
   # Transcribed from references/network-bounds.md; ADR 0068 carries the reasoning.
   bounded_call() { # seconds out-file err-file command...
   	local bound=$1 out=$2 err=$3 pid waited=0 grace=0 rc=0
   	shift 3
   	"$@" >"$out" 2>"$err" &
   	pid=$!
   	# Tenths, so the counter stays integer arithmetic on a Bash 3.2 floor.
   	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$((bound * 10))" ]; do
   		sleep 0.1
   		waited=$((waited + 1))
   	done
   	if kill -0 "$pid" 2>/dev/null; then
   		# TERM, then KILL only if TERM does not land. Never a bare KILL.
   		kill -TERM "$pid" 2>/dev/null || :
   		while kill -0 "$pid" 2>/dev/null && [ "$grace" -lt 20 ]; do
   			sleep 0.1
   			grace=$((grace + 1))
   		done
   		kill -KILL "$pid" 2>/dev/null || :
   		wait "$pid" 2>/dev/null || :
   		# The writer was killed mid-stream, so the capture is void. Emptying it
   		# here makes that structural: a site that parses it anyway gets nothing,
   		# not a truncated page that reads as a complete short one.
   		: >"$out"
   		return 124
   	fi
   	wait "$pid" || rc=$?
   	return "$rc"
   }

   # One bounded gh call. Its stdout is left at gh_capture for the caller to read
   # and remove; its stderr is forwarded to this script's own, which is where gh's
   # stderr went before either call was captured at all.
   run_gh() { # seconds gh-args...
   	local bound=$1 err rc=0 forward_status=0
   	shift
   	gh_capture=$(mktemp) || fail 'cannot create a gh stdout capture'
   	err=$(mktemp) || fail 'cannot create a gh stderr capture'
   	bounded_call "$bound" "$gh_capture" "$err" gh "$@" || rc=$?
   	if [ -s "$err" ]; then
   		cat "$err" >&2 || forward_status=$?
   	fi
   	# Removal precedes the forwarding verdict so a failed read still frees the
   	# capture: fail() reaches gh_capture, and this file is local to run_gh.
   	rm -f -- "$err" ||
   		printf 'publish-forge-review: retained gh stderr capture: %s\n' "$err" >&2
   	[ "$forward_status" -eq 0 ] || fail 'cannot read a gh stderr capture'
   	return "$rc"
   }
   ```

5. In `preflight()`, after the `disposer` checks and before the bundled-scanner check, add:

   ```bash
   	# Each bound separately, never the concatenation: a leading zero on the second
   	# value disappears inside it. Digits alone are not enough for the arithmetic
   	# destination -- bash reads 010 as octal 8, so a site would run under a bound
   	# nobody chose, and 08 is an arithmetic error. Measured on bash 3.2.57: that
   	# error lands in bounded_call's `while` condition, where `set -e` is suspended,
   	# so it does not abort -- the poll is abandoned, the function returns 0 with an
   	# empty capture, and the child it launched survives. The caller then reads a
   	# successful call that answered nothing, which is exactly the reading this
   	# convention exists to prevent, with the orphan the bound exists to reap. The
   	# length cap keeps the multiplication clear of 64-bit overflow.
   	for bound in "$BOUND_MULTI" "$BOUND_SINGLE"; do
   		case $bound in
   		'' | *[!0-9]* | 0?*)
   			fail 'network bound override must be a whole number of seconds with no leading zero'
   			;;
   		esac
   		[ "${#bound}" -le 7 ] ||
   			fail 'network bound override is implausibly large; give a whole number of seconds'
   	done
   ```

6. Replace the body of `post_comment()` at `:240-249` with the following. Note that
   `post_comment` is itself still called as `comment_url=$(post_comment)` at `:328`, and stays
   that way: that command substitution captures the *function's* stdout, not `gh`'s, so it bounds
   nothing and blocks nothing. What it does mean is that `gh_capture` and `fail()`'s removal of it
   are subshell-local on this path — which is correct, because the subshell is where the capture
   was created, and the parent's `gh_capture` stays empty throughout.

   ```bash
   post_comment() {
   	local post_status=0 candidate
   	run_gh "$BOUND_MULTI" pr comment "$pr" --repo "github.com/$repo" \
   		--body-file "$body" || post_status=$?
   	case $post_status in
   	0) ;;
   	124)
   		# A bound does not make a write atomic. Report indeterminacy, never
   		# failure, and never retry.
   		fail "comment creation exceeded its ${BOUND_MULTI}s bound; the comment may or may not have been created; inspect the pull request before any further attempt"
   		;;
   	*) fail 'comment creation did not complete' ;;
   	esac
   	candidate=$(awk 'NF { count += 1; value = $0 } END { if (count == 1) print value }' \
   		"$gh_capture") || fail 'comment creation returned no readable identity'
   	rm -f -- "$gh_capture" ||
   		printf 'publish-forge-review: retained gh capture: %s\n' "$gh_capture" >&2
   	gh_capture=''
   	[ -n "$candidate" ] || fail 'comment creation returned no usable identity'
   	printf '%s\n' "$candidate"
   }
   ```

7. In `read_comment()` at `:251-264`, drop `response` from the locals, replace the `gh api`
   command substitution and its status check with:

   ```bash
   	run_gh "$BOUND_SINGLE" api --hostname github.com "$endpoint" || api_status=$?
   	case $api_status in
   	0) ;;
   	124)
   		fail "comment readback exceeded its ${BOUND_SINGLE}s bound; the annotation was posted but could not be verified"
   		;;
   	*) fail 'comment readback failed' ;;
   	esac
   ```

   and change the `jq` line to read the capture file rather than a here-string, then clear it:

   ```bash
   	jq -e --rawfile expected "$body" '.body == $expected' "$gh_capture" >/dev/null ||
   		fail 'comment readback did not match the checked body'
   	rm -f -- "$gh_capture" ||
   		printf 'publish-forge-review: retained gh capture: %s\n' "$gh_capture" >&2
   	gh_capture=''
   ```

8. In `tests/fixtures/quest/publish-forge-review-test.sh`, extend the fake `gh` heredoc at `:36`.
   In the `pr comment` branch, after the `comment-invocation` line is appended and before the
   `comment-fail` case, add `comment-hang) printf '%s\n' $$ >"$state/hang-pid"; exec sleep 30 ;;`
   to the `case ${GH_MODE:-success}` block. In the `api` branch, after the endpoint is recorded,
   add a `read-hang` arm doing the same. `exec` is what makes TERM reach the blocking process
   rather than a shell that spawned it.
9. Add case `PFR-22`: `new_case`, then
   `run_helper required "$REVIEW" env GH_MODE=comment-hang PUBLISH_FORGE_REVIEW_BOUND_MULTI=2
    PUBLISH_FORGE_REVIEW_BOUND_SINGLE=1`. Assert
   `STATUS` is 1; that `$REPO/error` matches `exceeded its 2s bound` and `may or may not have been
   created`; that `comment_invocation_count` is 1, proving no retry; that `post_count` is 0; that
   `assert_retained` passes; that the ledger carries no `review-publication-verified:` line; and
   that `kill -0 "$(cat "$STATE/hang-pid")"` fails, proving the child was reaped.
10. Add case `PFR-23`: `new_case`, then
    `run_helper required "$REVIEW" env GH_MODE=read-hang PUBLISH_FORGE_REVIEW_BOUND_MULTI=2
    PUBLISH_FORGE_REVIEW_BOUND_SINGLE=1`. Assert
    `STATUS` is 1; that `$REPO/error` matches `readback exceeded its 1s bound`; that `post_count`
    is 1; that `assert_retained` passes; and that the ledger carries no
    `review-publication-verified:` line.
11. Register both cases in the runner list at the foot of the file, beside the existing
    `case_*` entries.
12. Run `just test publish-forge-review`. The quiet default prints only
    `ok   tests/fixtures/quest/publish-forge-review-test.sh` and `test: 1 suites passed`; run
    `just test -v publish-forge-review` to see the per-case `ok   PFR-22 …` and `ok   PFR-23 …`
    lines and confirm the failure count is zero.
13. Run `just lint format-check scan-fault-check`. Expect each to exit 0 with no findings; a
    missing `scan-fault` pragma on any `kill … || :` line fails the third.
14. Commit: `fix(quest): bound the gh calls in publish-forge-review`.

**Acceptance.** Both `gh` calls run through `bounded_call`; neither remains in a command
substitution; a bound exceeded exits 1 with a diagnostic naming the call and the bound; the write
says the comment may or may not exist; the suite proves both paths and the reap; the required-
command list at `:48` is unchanged.

## Task 2 — bound every call in `cleared-dependencies.sh`, and bump the manifest

Creates: nothing. Modifies: `skills/quest-log/assets/cleared-dependencies.sh`,
`.claude-plugin/plugin.json`. Tests: `tests/fixtures/quest-log/cleared-dependencies-test.sh`.

**Interfaces.** Consumes nothing from Task 1 — the two files share no code by design.
Defines, for this file only: `cleared_dependency_bounded_call <seconds> <out-file> <err-file>
<command…>`, returning the command's status or 124; and the existing
`cleared_dependency_run`, whose signature becomes `cleared_dependency_run <seconds>
<gh-args…>`, still setting `cleared_dependency_out` and `cleared_dependency_err` and now
returning 124 on a bound exceeded. Globals `cleared_dependency_bound_single` (30) and
`cleared_dependency_bound_multi` (120), assigned with `:=`.

### Verification

- **Contract: a bound exceeded on a blocker read is reported as unreadable, never as missing.**
  Mode: focused-test — `cleared_dependency_body_verdict` returns 1, `cleared_dependency_reason`
  contains `unreadable blocker #1` and `did not answer`, and contains neither `missing blocker`
  nor `CLOSED`. Expected red: the fake blocks and the suite hangs. Green:
  `just test cleared-dependencies`.
- **Contract: a bound exceeded on the paginated listing exits 1 and changed no labels.** Mode:
  focused-test — sourced, `reconcile_cleared_dependencies plan` returns 1 and its stderr carries
  `cannot list open dependents`, `did not answer`, and `no labels changed`; and again through
  direct execution, where the process exits 1. Expected red: the same hang. Green: the same
  command.
- **Contract: a bound exceeded on `gh label create` reports the label may or may not exist and
  attempts no edit.** Mode: focused-test — `apply_cleared_dependency` returns 1, its stderr
  matches `may or may not exist`, and `$gh_log` stays empty. Expected red: the same hang. Green:
  the same command.
- **Contract: a bound exceeded on the `gh issue edit` label write reports the labels may or may
  not have been changed and performs no verification read or restore.** Mode: focused-test —
  `apply_cleared_dependency` returns 1, its stderr matches `may or may not have been changed`, and
  `$gh_log` records no `--add-label status:blocked` restore. Expected red: the same hang. Green:
  the same command.
- **Contract: a bound exceeded on the pre-write dependent read at `:201` reports it unreadable.**
  Mode: focused-test — `apply_cleared_dependency` returns 1 and its stderr matches
  `unreadable dependent #101` and `did not answer`. Expected red: the same hang. Green: the same
  command.
- **Contract: a bound exceeded on the post-write verification read at `:241` reports it
  unreadable and does not restore.** Mode: focused-test — `apply_cleared_dependency` returns 1,
  its stderr matches `verification unreadable for #101` and `did not answer`, and `$gh_log`
  records no restoring `--add-label status:blocked`: a call that did not answer is not evidence
  the write went wrong. Expected red: the same hang. Green: the same command.
- **Contract: a bound exceeded on the best-effort restore at `:186` reports indeterminacy without
  masking the primary error.** Mode: focused-test — `apply_cleared_dependency` returns 1, stderr
  carries both `conflicting status write` and
  `restoring #101 to status:blocked ... may or may not have been changed`, and `$gh_log` holds
  exactly one edit line. Expected red: the same hang. Green: the same command.
- **Contract: the manifest version is strictly greater than the base ref's.** Mode: focused-test —
  `bash -c 'BASE_SHA=$(git merge-base HEAD main) just version-check'`, expected to exit 0. A bare
  `just version-check` cannot observe this contract on a workstation: `BASE_SHA` is unset there, so
  the gate checks only that the field exists and parses, and the base ref's own version would
  satisfy it. Supplying the fork point is what makes the strictly-greater rule run locally, and it
  is the same rule CI hard-gates.
- **Contract: a bound the arithmetic destination would reject is refused before the call.** Mode:
  focused-test — the leading-zero half is reachable and costs nothing to commit: the suite sets
  `cleared_dependency_bound_single=08`, and `cleared_dependency_body_verdict` must return 1 with
  `not a whole number of seconds` and without `did not answer`, proving the refusal precedes the
  call rather than following a launched child. Green: `just test cleared-dependencies`.
- **Contract: a bound carrying a command substitution is refused.** Mode:
  task-test-not-applicable — observing this half means committing a `$(…)` payload to a fixture
  for a guard whose whole job is that the payload never runs. The behaviour was measured on
  `/bin/bash` 3.2.57 instead and is recorded in Global Constraints; the same `case` arm the
  focused entry above exercises is what rejects it.
- **Contract: `cleared_dependency_run`'s new leading argument.** Mode: task-test-not-applicable —
  a call site that forgets the bound passes its first `gh` word to the guard above, which refuses
  it, so every one of the suite's existing cases fails loudly; there is no separate observation to
  add.

### Steps

1. After the global block at `:22-30`, add:

   ```bash
   # Seconds. 30 for a call that issues one request, 120 for one that may issue
   # more; references/network-bounds.md carries the rule and ADR 0068 the record.
   # `:=` rather than `=` because the behaviour suite's direct-execution leg exports
   # these into a subprocess, and an unconditional assignment here would overwrite
   # the exported value before any call read it.
   : "${cleared_dependency_bound_single:=30}"
   : "${cleared_dependency_bound_multi:=120}"
   ```

2. Immediately before `cleared_dependency_run` at `:74`, add the mechanism, transcribed verbatim
   from `references/network-bounds.md:26-56` with exactly two changes: rename the function to
   `cleared_dependency_bounded_call`, because sourcing publishes the name and every other function
   in this file carries that prefix, and replace the reference's leading comment with:

   ```bash
   # Run a command under a bound. Returns the command's own status, or 124 when the
   # bound was exceeded. Trap-free: this file is sourced, so it cannot take the EXIT
   # trap slot from whichever skill sourced it, and the mechanism needs none.
   # Transcribed from references/network-bounds.md; ADR 0068 carries the reasoning.
   ```

   Take no other liberty. The reference's own inline comments, its `rc`-not-`status` local, its
   tenth-second poll, its two-second grace window, its `: >"$out"` void, and its `|| rc=$?` all
   come across unchanged, and no `# scan-fault: deliberate — …` pragma is added — see Global
   Constraints. Keeping it byte-comparable against that line range is what makes the drift ADR
   0068 predicts detectable later.

3. Rewrite `cleared_dependency_run` at `:74-87`. Keep the whole comment block at `:46-73`,
   amending only its scratch-file paragraph to say two files rather than one, and add a sentence
   recording why a bound exceeded discards `gh`'s partial stderr:

   ```bash
   cleared_dependency_run() { # bound gh-args...
   	local bound=$1 subcommand=$2 out err rc=0
   	cleared_dependency_out=
   	cleared_dependency_err=
   	shift
   	# Validated before it reaches $((bound * 10)): bash evaluates an arithmetic
   	# operand as an expression, so a value carrying a command substitution would
   	# run it. This is the only entry point, so one guard covers every call.
   	case $bound in
   	'' | *[!0-9]*)
   		cleared_dependency_err='the tracker command bound is not a whole number of seconds'
   		return 1
   		;;
   	esac
   	out=$(mktemp) || {
   		cleared_dependency_err='no scratch file for the tracker command'
   		return 1
   	}
   	err=$(mktemp) || {
   		rm -f -- "$out" ||
   			printf 'retained scratch path: %s\n' "$out" >&2
   		cleared_dependency_err='no scratch file for the tracker command'
   		return 1
   	}
   	cleared_dependency_bounded_call "$bound" "$out" "$err" gh "$@" || rc=$?
   	if [ "$rc" -eq 124 ]; then
   		# The stdout capture is void and the stderr capture is a fragment of
   		# whatever gh had written when it was signalled. An authored diagnostic
   		# says what actually happened, and cannot accidentally carry the
   		# 'not found' substring that the blocker read treats as an answer.
   		cleared_dependency_err="gh $subcommand exceeded its ${bound}s bound and did not answer"
   	else
   		cleared_dependency_out=$(<"$out")
   		cleared_dependency_err=$(<"$err")
   	fi
   	rm -f -- "$out" "$err" ||
   		printf 'retained scratch paths: %s %s\n' "$out" "$err" >&2
   	return "$rc"
   }
   ```

4. At `:102` pass the single-request bound:
   `cleared_dependency_run "$cleared_dependency_bound_single" issue view "$blocker" --repo "$repo" --json state --jq .state`.
   Do the same at `:201` and `:241`, whose calls are `issue view "$number" --repo "$repo" --json
   number,state,body,labels`.
5. At `:287` pass the multi-request bound and state what the number means:

   ```bash
   	# 120 s bounds the whole paginated call rather than each request: gh exposes
   	# no per-request timeout, so the effective per-page allowance shrinks as the
   	# repository's open-issue count grows.
   	cleared_dependency_run "$cleared_dependency_bound_multi" api --paginate --slurp -X GET \
   		"repos/$repo/issues?state=open&per_page=100" || {
   ```

6. Replace `ensure_cleared_dependency_label` at `:169-178` with:

   ```bash
   ensure_cleared_dependency_label() { # repo
   	local repo=$1 rc=0 merged safe
   	cleared_dependency_run "$cleared_dependency_bound_single" label create 'status:ready' \
   		--repo "$repo" --color 0e8a16 \
   		--description 'triaged, eligible for work' || rc=$?
   	case $rc in
   	0) return 0 ;;
   	124)
   		# A bound does not make a write atomic. Report indeterminacy, never
   		# failure, and never retry.
   		printf 'creating status:ready exceeded its %ss bound; the label may or may not exist\n' \
   			"$cleared_dependency_bound_single" >&2
   		return 1
   		;;
   	esac
   	# This call captures a diagnostic and discards it on success, so its streams
   	# are merged after the call rather than in a 2>&1 redirect.
   	merged=$cleared_dependency_out$cleared_dependency_err
   	[[ $merged == *'already exists'* ]] && return 0
   	safe=$(printf '%s' "$merged" | cleared_dependency_safe_text)
   	printf 'cannot create status:ready: %s — grant label-write scope\n' "$safe" >&2
   	return 1
   }
   ```

7. Replace the `gh issue edit` block in `restore_cleared_dependency_blocked` at `:186-192`. Drop
   `err` from the locals and add `rc=0 merged`:

   ```bash
   	cleared_dependency_run "$cleared_dependency_bound_multi" issue edit "$number" \
   		--repo "$repo" "${remove_args[@]}" --add-label 'status:blocked' || rc=$?
   	case $rc in
   	0) ;;
   	124)
   		printf 'restoring #%s to status:blocked after %s exceeded its %ss bound; its labels may or may not have been changed\n' \
   			"$number" "$reason" "$cleared_dependency_bound_multi" >&2
   		return 1
   		;;
   	*)
   		merged=$cleared_dependency_out$cleared_dependency_err
   		safe=$(printf '%s' "$merged" | cleared_dependency_safe_text)
   		printf 'cannot restore #%s to status:blocked after %s: %s\n' \
   			"$number" "$reason" "$safe" >&2
   		return 1
   		;;
   	esac
   ```

8. Replace the `gh issue edit` block in `apply_cleared_dependency` at `:234-240`. Drop `err` from
   its locals and add `rc`:

   ```bash
   	rc=0
   	cleared_dependency_run "$cleared_dependency_bound_multi" issue edit "$number" \
   		--repo "$repo" "${remove_args[@]}" --add-label 'status:ready' || rc=$?
   	case $rc in
   	0) ;;
   	124)
   		printf 'label update for #%s exceeded its %ss bound; the labels may or may not have been changed; inspect its status labels\n' \
   			"$number" "$cleared_dependency_bound_multi" >&2
   		return 1
   		;;
   	*)
   		safe=$(printf '%s' "$cleared_dependency_out$cleared_dependency_err" |
   			cleared_dependency_safe_text)
   		printf 'label update failed for #%s: %s; inspect its status labels\n' \
   			"$number" "$safe" >&2
   		return 1
   		;;
   	esac
   ```

9. In `tests/fixtures/quest-log/cleared-dependencies-test.sh`, add seven hang arms to the fake `gh`
   function, each a bare `exec sleep 30`: `hang-api` in the `api` branch, `hang-label` in the
   `label create` branch, `hang-edit` in the `issue edit` branch, `hang-blocker` in the
   `issue view` branch's `1)` arm, and, in that branch's `101)` arm, `hang-dependent` when
   `$ready_state` does not exist and `hang-verify` when it does — which is how that arm already
   distinguishes the pre-write read at `:201` from the post-write read at `:241`. The seventh,
   `hang-restore`, behaves as `conflict` everywhere except the `issue edit` branch, where it hangs
   only when `$* == *'--add-label status:blocked'*`: that label is carried by `:186` and not by
   `:234`, and the fake already discriminates on it at `:54`. Record no pid here: this fake is a
   shell function, so `$$` inside it is the *test's* pid, not the backgrounded subshell's. Only
   `publish-forge-review-test.sh`, whose fake is an executable script, can record its own pid
   meaningfully.
10. Add the seven sourced assertions the Verification inventory names, each preceded by
    `cleared_dependency_bound_single=1 cleared_dependency_bound_multi=1` and followed by a restore
    to 30 and 120, and each resetting `fake_mode=normal` afterwards. Place them after the existing
    scratch-file case, which is their nearest neighbour in subject.
11. For the direct-execution leg, add a case after the usage case at `:337-346` that runs the file
    with `cleared_dependency_bound_multi=1` exported and `fake_mode=hang-api`, asserting exit 1
    and that stderr carries `cannot list open dependents`. `fake_mode` is already in the `export`
    list at `:307`, so setting it before the run reaches the subprocess. Reset `fake_mode=normal`
    afterwards so the zsh probe that follows is unaffected.
12. Run `just test cleared-dependencies`. The quiet default prints only
    `ok   tests/fixtures/quest-log/cleared-dependencies-test.sh` and `test: 1 suites passed`; the
    suite's own `cleared-dependencies-test: pass` line is visible under `just test -v`.
13. Set `.claude-plugin/plugin.json`'s `version` to exactly `5.10.2`, the value the campaign
    dispatch reserved for this row's place in the merge order; do not renumber it if a sibling's
    version lands first. Never write that literal at the end of a sentence in a Markdown file:
    `check-public-safety`'s private-address pattern `(^|[^[:alnum:]])10\.[0-9]{1,3}\.` requires a
    dot after the patch component, so a sentence-final version matches it and fails
    `just public-safety`, while the same version followed by anything else does not.
14. Run `just verify`. Expect exit 0. On a workstation the version gate checks only that the
    field exists and is `MAJOR.MINOR.PATCH`, because `BASE_SHA` is unset locally; CI checks the
    strictly-greater rule.
15. Commit: `fix(quest-log): bound the gh calls in cleared-dependencies.sh`.

**Acceptance.** All four wrapper callers and all three direct writes pass a bound; the paginated
site states its bound's meaning; a bound exceeded never reads as a missing blocker or an empty
listing; the three writes report indeterminacy without retrying; the file installs no trap and
adds no `set -e`; the suite covers both sourced and executed modes; the manifest reads `5.10.2`
exactly.
