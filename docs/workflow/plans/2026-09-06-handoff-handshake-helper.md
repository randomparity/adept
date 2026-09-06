# Hand-off handshake helper — implementation plan

Derived from [the design](../specs/2026-09-06-handoff-handshake-helper-design.md) and
[ADR 0056](../../adr/0056-compose-the-handoff-handshake.md).

**Goal.** Replace `$return-to-town`'s hand-composed merge hand-off annotation with one executable
that composes the block, computes the head SHA itself, posts the comment, and asserts every
condition the merge gate checks against the copy GitHub stored.

**Architecture.** One new executable, `skills/return-to-town/scripts/publish-handoff`. It takes the
repository, issue, pull request, and a narrative file, and owns everything the gate reads: both
annotation markers and the `MERGE-READY` line. It resolves the head branch from the pull request,
reads the SHA from `git ls-remote origin`, requires GitHub's `headRefOid` to agree, composes the
body, runs the repository's existing public-safety gate over it, posts with `gh issue comment`,
re-reads the stored comment, and asserts five conditions against those bytes. A behaviour suite
under `tests/fixtures/return-to-town/` fakes `gh` and uses a real git repository with a real bare
remote. `skills/return-to-town/SKILL.md` replaces its composition prose with the invocation.

**Tech stack.** Bash and Markdown. No dependencies, no build step. Gates are `just verify`.

**Expected implementation size: 950–1050 changed lines (L) — summed from the file map below: 354
(`publish-handoff`) + 638 (its suite), the two code files, plus roughly 25 lines of contract text in
`skills/return-to-town/SKILL.md` and the one-line version bump.**

The band disagrees with the `M` this run recorded in its `WORK:SCOPE` tracking metadata, and the
band is the one that is wrong there rather than here: `M` was read off the issue before any file
map existed, and the range above is what the file map and task list actually yield. The suite is
the larger half, and that is proportionate rather than inflated — its sibling
`tests/fixtures/quest/publish-forge-review-test.sh` runs 928 lines for a helper of 310, and this
one covers 28 cases including one regression per defect logged in the issue.

**How the two code files are specified here differs, deliberately.** The helper appears in full, at
step 1.2, because its exact bytes are the contract — the markers, the handshake, and the assertion
order are the deliverable. The suite is specified by an enumerated case list, at step 1.5: one line
per case naming the case and the single assertion it makes. That is a complete specification of what
the suite must do without transcribing 638 lines whose shape is mechanical once the case list and
the fixture sketch are fixed, and it is what makes the pinned pass count derivable rather than
asserted. An implementer who writes exactly the 28 enumerated cases reaches the acceptance criterion
below.

## Global constraints

- **Bash 3.2 is the floor.** macOS ships 3.2.57. No `mapfile`, no `readarray`, no associative
  arrays. Indexed arrays are fine; `"${arr[@]}"` on an empty array is fatal under `set -u`.
- Shell files start `#!/usr/bin/env bash` and `set -euo pipefail`, and indent with **tabs**.
- Capture a command's exit status explicitly rather than trailing `|| true`. `grep` and `rg` exit 1
  for "no matches" and greater than 1 for a real failure; collapsing those makes a scan that could
  not run read as one that found nothing.
- Enumerate character sets rather than writing ranges. A bash bracket expression takes its ranges
  from the locale's collation, so under a territory UTF-8 locale `[a-z]` admits accented letters.
- Exit taxonomy: **0** success, **1** a condition failed, **2** the script could not run. A fault
  must never read as a clean hand-off.
- `.claude-plugin/plugin.json` carries the plugin `version` and **every change bumps it**. This
  change adds a capability, so `MINOR`: `4.1.1` → `4.2.0`.
- The repository is public. No absolute user paths, hostnames, addresses, or credentials in any
  committed file.
- Skill-script behaviour suites live under `tests/fixtures/<skill>/`, **outside** the shipped tree.
  The whole repository is copied into the plugin cache, so a fixture inside a skill's own directory
  is reachable by that skill at runtime — which has already shipped one incident.

## File map

| File | Status | Answerable for |
|---|---|---|
| `skills/return-to-town/scripts/publish-handoff` | new | composing, posting, and verifying the hand-off block |
| `tests/fixtures/return-to-town/publish-handoff-test.sh` | new | the helper's behaviour, including one regression case per logged defect |
| `skills/return-to-town/SKILL.md` | modified | invoking the helper instead of describing the composition |
| `.claude-plugin/plugin.json` | modified | the version bump |
| `docs/adr/0056-compose-the-handoff-handshake.md` | new | the decision recorded alongside this plan |

`skills/return-to-town/` has no `scripts/` directory today; Task 1 creates it. No new skill is
added, so `check-skill-shape.sh` rules 6 and 7 (cheatsheet and README coverage) are unaffected, and
no `references/` link is added or removed, so rule 5 is unaffected.

## Task 1 — the helper and its suite

Creates `skills/return-to-town/scripts/publish-handoff` and
`tests/fixtures/return-to-town/publish-handoff-test.sh`. One task, not two: no reviewer could accept
the helper while rejecting its suite, and `just test` discovers the suite through `git ls-files --
'*-test.sh'`, so neither is verifiable without the other.

### Interfaces

Consumed from earlier tasks: nothing; this is the first task.

Provided to later tasks, and to `skills/return-to-town/SKILL.md`:

```
skills/return-to-town/scripts/publish-handoff [--preflight] REPO ISSUE PR NOTES
```

- `REPO` — `owner/name`.
- `ISSUE` — the issue number the hand-off is recorded on, a positive integer.
- `PR` — the pull request number, a positive integer.
- `NOTES` — path to a regular readable file holding the hand-off narrative only.

Success prints one line on stdout: `preflight-ok` under `--preflight`, otherwise the verified
comment URL. Exit 0 success, 1 a condition failed, 2 the script could not run.

Consumed from the existing codebase, each confirmed to exist with the signature assumed:

- `scripts/check-public-safety.sh` — executable, takes zero or more paths to scan, exits 0 clean,
  1 on a finding, 2 on a fault. Confirmed at `scripts/check-public-safety.sh:23-27`
  (`if (($# > 0)); then scan_paths=("$@")`).
- `scripts/test-fixture-helpers.sh` — sourced, provides `clear_git_env`, `fixture_init <label>`
  (sets `SCRATCH`), `fixture_scratch <prefix>` (sets `FIXTURE_SCRATCH`). Documented at
  `scripts/test-fixture-helpers.sh:20-30`; `SCRATCH` is assigned at
  `scripts/test-fixture-helpers.sh:123` and `FIXTURE_SCRATCH` at
  `scripts/test-fixture-helpers.sh:61`.

### Verification

- **Contract: the composed and posted block satisfies the merge gate's three anchored conditions.**
  Mode: focused-test. Test file `tests/fixtures/return-to-town/publish-handoff-test.sh`, case
  `case_publishes_the_required_shape`. Expected red with `"$handshake"` removed from
  `compose_body`'s final `printf`: 3 cases FAIL, this one first, with
  `expected exit 0, got 1` and stderr
  `publish-handoff: the stored hand-off comment is missing the handshake on its own line:
  MERGE-READY: #42 @ <sha>` — the helper's own readback assertion catches the omission before the
  case inspects the posted body, which is the assertion doing its job. Green command:
  `./tests/fixtures/return-to-town/publish-handoff-test.sh`, expected final line
  `publish-handoff-test: 28 passed, 0 failed`, exit 0.
- **Contract: a narrative carrying a handshake — backticked or bare — is rejected before posting.**
  Mode: focused-test. Same file, case `case_notes_carry_handshake`. Expected red with the
  substring check removed: `FAIL regression: a backticked handshake in the notes is rejected:
  expected exit 1, got 0`. Green command as above.
- **Contract: a stored copy missing the sentinel fails and names the sentinel.** Mode:
  focused-test. Same file, case `case_stored_missing_sentinel`. Expected red with the sentinel
  `printf` removed from `compose_body`: four cases fail, including this one. Green command as
  above.
- **Contract: a stored copy carrying a carriage return is reported as a carriage return, not as a
  missing marker.** Mode: focused-test. Same file, case `case_stored_carries_cr`. Expected red with
  the CR check moved after the whole-line checks: `stderr did not mention 'carriage return'`. Green
  command as above.
- **Contract: the SHA posted is the one `git ls-remote` reports, and a disagreeing `headRefOid`
  refuses.** Mode: focused-test. Same file, case `case_head_disagrees`. Expected red without the
  comparison: `expected exit 1, got 0`. Green command as above.
- **Contract: a head branch resolving to more than one ref is refused.** Mode: focused-test. Same
  file, case `case_multiple_refs`, which pushes a second `feat/` branch and drives the fake to
  report `feat/*` as the head branch — `git ls-remote` globs its patterns, so two refs come back.
  Expected red without the `line_count` check: `expected exit 1, got 0`. Green command as above.
- **Contract: shell style and lint.** Mode: focused-test. Command
  `shellcheck -x skills/return-to-town/scripts/publish-handoff tests/fixtures/return-to-town/publish-handoff-test.sh`
  and `shfmt -d` over the same two paths, both exit 0 with no output. Expected red on a
  space-indented line: `shfmt` prints a diff and exits 1.

### Steps

**1.1** Create the directory: `mkdir -p skills/return-to-town/scripts tests/fixtures/return-to-town`.

**1.2** Write `skills/return-to-town/scripts/publish-handoff` with exactly this content:

```bash
#!/usr/bin/env bash
# Compose, post, and verify the merge hand-off WORK:TRAJECTORY annotation.
#
# The merge gate (references/merge-gate.md part 4) admits a hand-off only when
# one comment satisfies three anchored whole-line conditions at once: the
# opening marker, the closing sentinel, and a MERGE-READY line carrying this
# pull request's number and the exact head SHA. Composing that by hand failed
# four times in one campaign run -- a backticked handshake, a missing sentinel
# twice, and a worker that died partway -- and every failure surfaced one actor
# away, in the orchestrator's gate, as "zero matching blocks".
#
# So the caller supplies the narrative and nothing else. This script writes both
# markers and the handshake line, computes the SHA itself, and asserts every
# condition against the copy GitHub stored rather than the copy it composed --
# the composed copy proves nothing about what the gate will read.
#
# Exit 0 success, 1 a condition failed, 2 the script could not run. Every
# nonzero exit names the condition: "which of the three failed" is precisely
# what the orchestrator otherwise has to work out by re-reading the body.
set -euo pipefail

MARKER='<!-- WORK:TRAJECTORY -->'
SENTINEL='<!-- TRAJECTORY:COMPLETE -->'
MAX_NOTES_BYTES=8192
MAX_BODY_BYTES=32768

SCRIPT_DIR=${BASH_SOURCE[0]%/*}
[ "$SCRIPT_DIR" = "${BASH_SOURCE[0]}" ] && SCRIPT_DIR=.
SCRIPT_DIR=$(cd "$SCRIPT_DIR" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)

operation=publish
repo=''
issue=''
pr=''
notes=''
workspace=''
body=''
stored=''
handshake=''
head_sha=''
response=''

# A finding and a fault are different verdicts and get different statuses. Exit
# 1 means the hand-off is not publishable and says why; exit 2 means this script
# could not decide, which must never read as a clean hand-off.
fail() { # message
	printf 'publish-handoff: %s\n' "$1" >&2
	exit 1
}

fault() { # message
	printf 'publish-handoff: %s\n' "$1" >&2
	exit 2
}

# Under `set -e` an EXIT trap's non-zero return becomes the shell's exit status,
# so a scratch directory this cannot remove must not silently become the finding
# status -- it reports itself and takes exit 2 only on a run that was otherwise
# clean, leaving a real verdict its own. The prefix guard is defence in depth on
# the one recursive removal here: $workspace is what mktemp returned from a fixed
# template and no code reassigns it.
#
# shellcheck disable=SC2329 # run by the EXIT trap, not called directly
cleanup() {
	local exit_status=$?
	if [ -n "$workspace" ] && [ -d "$workspace" ]; then
		case $workspace in
		"${TMPDIR:-/tmp}"/publish-handoff.*)
			if ! rm -Rf -- "$workspace"; then
				printf 'publish-handoff: retained scratch path: %s\n' "$workspace" >&2
				if [ "$exit_status" -eq 0 ]; then
					exit 2
				fi
			fi
			;;
		*)
			printf 'publish-handoff: refusing cleanup outside the scratch root: %s\n' \
				"$workspace" >&2
			if [ "$exit_status" -eq 0 ]; then
				exit 2
			fi
			;;
		esac
	fi
	exit "$exit_status"
}
trap cleanup EXIT

require_commands() {
	local required
	for required in gh jq git grep iconv od awk wc tail cat mktemp rm; do
		command -v "$required" >/dev/null 2>&1 ||
			fault "required command is unavailable: $required"
	done
	[ -x "$ROOT/scripts/check-public-safety.sh" ] ||
		fault "public-safety check is unavailable: $ROOT/scripts/check-public-safety.sh"
}

validate_arguments() {
	if [ "${1-}" = --preflight ]; then
		operation=preflight
		shift
	fi
	[ "$#" -eq 4 ] ||
		fault 'usage: publish-handoff [--preflight] REPO ISSUE PR NOTES'
	repo=$1
	issue=$2
	pr=$3
	notes=$4
	# Enumerated rather than a range: a bash bracket expression takes its ranges
	# from the locale's collation, so under a territory UTF-8 locale [A-Za-z]
	# admits accented letters this must not accept in a path segment.
	case $repo in
	*/*/*) fail "repository is invalid, expected owner/name: $repo" ;;
	*/*) ;;
	*) fail "repository is invalid, expected owner/name: $repo" ;;
	esac
	[ -n "${repo%%/*}" ] && [ -n "${repo#*/}" ] ||
		fail "repository is invalid, expected owner/name: $repo"
	case $repo in
	*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._/-]*)
		fail "repository carries a character that is not permitted in owner/name: $repo"
		;;
	esac
	case $issue in
	'' | *[!0123456789]* | 0) fail "issue number is invalid: $issue" ;;
	esac
	case $pr in
	'' | *[!0123456789]* | 0) fail "pull request number is invalid: $pr" ;;
	esac
}

make_workspace() {
	workspace=$(mktemp -d "${TMPDIR:-/tmp}/publish-handoff.XXXXXX") ||
		fault 'could not create a scratch directory'
	body="$workspace/body"
	stored="$workspace/stored"
}

# od answers three ways and awk collapses two of them, so both statuses are read
# explicitly: a scan that could not run must never report as a scan that found
# nothing.
contains_byte() { # byte path -- 0 present, 1 absent
	local byte=$1 path=$2 od_status awk_status statuses
	if LC_ALL=C od -An -v -t x1 "$path" |
		awk -v byte="$byte" '{ for (i = 1; i <= NF; i += 1) if ($i == byte) found = 1 }
			END { exit found ? 0 : 1 }'; then
		statuses=("${PIPESTATUS[@]}")
	else
		statuses=("${PIPESTATUS[@]}")
	fi
	od_status=${statuses[0]}
	awk_status=${statuses[1]}
	[ "$od_status" -eq 0 ] || fault "could not read $path to check its bytes"
	case $awk_status in
	0) return 0 ;;
	1) return 1 ;;
	*) fault "byte validation of $path failed (awk exit $awk_status)" ;;
	esac
}

byte_count_of() { # label path
	local count
	count=$(wc -c <"$2") || fault "$1 could not be measured: $2"
	count=${count//[[:space:]]/}
	case $count in
	'' | *[!0123456789]*) fault "$1 size could not be read: $2" ;;
	esac
	printf '%s\n' "$count"
}

grep_whole_line() { # line path label -- 0 present, 1 absent
	local scan_status=0
	grep -qxF -- "$1" "$2" || scan_status=$?
	case $scan_status in
	0) return 0 ;;
	1) return 1 ;;
	*) fault "scanning $3 failed (grep exit $scan_status)" ;;
	esac
}

validate_notes() {
	local count marker scan_status
	[ -f "$notes" ] && [ ! -L "$notes" ] && [ -r "$notes" ] ||
		fail "hand-off notes are not a readable regular file: $notes"
	[ -s "$notes" ] || fail "hand-off notes are empty: $notes"
	count=$(byte_count_of 'hand-off notes' "$notes")
	[ "$count" -le "$MAX_NOTES_BYTES" ] ||
		fail "hand-off notes are $count bytes, over the $MAX_NOTES_BYTES-byte limit: $notes"
	iconv -f UTF-8 -t UTF-8 "$notes" >/dev/null 2>&1 ||
		fail "hand-off notes are not UTF-8 text: $notes"
	if contains_byte 00 "$notes"; then
		fail "hand-off notes contain a NUL byte: $notes"
	fi
	if contains_byte 0d "$notes"; then
		fail "hand-off notes contain a carriage return: $notes"
	fi
	for marker in "$MARKER" "$SENTINEL"; do
		if grep_whole_line "$marker" "$notes" 'the hand-off notes for an annotation marker'; then
			fail "hand-off notes already carry the whole line $marker; this script writes both markers"
		fi
	done
	# Substring, not an anchored line. The defect this closes wrote the
	# handshake inside backticks, which no line-anchored pattern sees, and the
	# narrative has no legitimate reason to contain the token at all.
	scan_status=0
	grep -qF -- 'MERGE-READY:' "$notes" || scan_status=$?
	case $scan_status in
	0) fail "hand-off notes mention MERGE-READY:; this script composes that line itself, so the notes must not contain it" ;;
	1) ;;
	*) fault "scanning the hand-off notes for a handshake line failed (grep exit $scan_status)" ;;
	esac
}

# The SHA is read from the remote, never from headRefOid, per
# skills/return-to-town/SKILL.md. headRefOid is then required to agree: it is a
# second independent observation, and a disagreement means the branch moved
# between the two reads -- exactly the moment a handshake must not be posted.
resolve_head() {
	local pr_json number state head_branch head_ref_oid ls_output line_count
	pr_json=$(gh pr view "$pr" --repo "$repo" \
		--json number,state,headRefName,headRefOid) ||
		fault "the pull request could not be read: $repo#$pr"
	number=$(jq -r '.number' <<<"$pr_json") ||
		fault 'the pull request response could not be parsed'
	state=$(jq -r '.state' <<<"$pr_json") ||
		fault 'the pull request response could not be parsed'
	head_branch=$(jq -r '.headRefName' <<<"$pr_json") ||
		fault 'the pull request response could not be parsed'
	head_ref_oid=$(jq -r '.headRefOid' <<<"$pr_json") ||
		fault 'the pull request response could not be parsed'
	[ "$number" = "$pr" ] ||
		fail "the pull request reported number $number, not $pr"
	[ "$state" = OPEN ] ||
		fail "the pull request is $state, not OPEN; a hand-off records an open pull request"
	case $head_branch in
	'' | null) fail 'the pull request reported no head branch' ;;
	esac
	ls_output=$(git ls-remote origin "refs/heads/$head_branch") ||
		fault "git ls-remote could not read refs/heads/$head_branch from origin; run this from the checkout whose origin is $repo"
	[ -n "$ls_output" ] ||
		fail "origin has no refs/heads/$head_branch, which is the pull request's head branch"
	line_count=$(printf '%s\n' "$ls_output" | wc -l) ||
		fault 'could not count the refs origin reported'
	line_count=${line_count//[[:space:]]/}
	[ "$line_count" -eq 1 ] ||
		fail "origin reported $line_count refs for refs/heads/$head_branch; expected exactly one"
	head_sha=${ls_output%%$'\t'*}
	case $head_sha in
	*[!0123456789abcdef]* | '')
		fail "origin reported a head that is not a 40-character lowercase SHA: $head_sha"
		;;
	esac
	[ ${#head_sha} -eq 40 ] ||
		fail "origin reported a head that is not a 40-character lowercase SHA: $head_sha"
	[ "$head_sha" = "$head_ref_oid" ] ||
		fail "the branch moved: origin has $head_sha for refs/heads/$head_branch but the pull request reports $head_ref_oid; re-run once the branch settles"
	handshake="MERGE-READY: #$pr @ $head_sha"
}

compose_body() {
	local last_byte count
	printf '%s\n' "$MARKER" >"$body" ||
		fault 'the hand-off body could not be composed'
	cat "$notes" >>"$body" ||
		fault "the hand-off notes could not be read: $notes"
	# Command substitution strips trailing newlines, so an empty result means
	# the notes already end with one.
	last_byte=$(tail -c 1 "$notes") ||
		fault "the hand-off notes could not be read: $notes"
	if [ -n "$last_byte" ]; then
		printf '\n' >>"$body" || fault 'the hand-off body could not be composed'
	fi
	# The blank line is for the reader, not the gate: without it the handshake
	# is absorbed into the narrative's last rendered paragraph, while still
	# matching the anchored pattern in the raw body.
	printf '\n%s\n%s\n' "$handshake" "$SENTINEL" >>"$body" ||
		fault 'the hand-off body could not be composed'
	count=$(byte_count_of 'the composed hand-off body' "$body")
	[ "$count" -le "$MAX_BODY_BYTES" ] ||
		fail "the composed hand-off body is $count bytes, over the $MAX_BODY_BYTES-byte limit"
	"$ROOT/scripts/check-public-safety.sh" "$body" >/dev/null 2>&1 ||
		fail 'the composed hand-off body did not pass public-safety validation'
}

post_comment() {
	local output post_status=0 candidate
	output=$(gh issue comment "$issue" --repo "$repo" --body-file "$body") || post_status=$?
	[ "$post_status" -eq 0 ] ||
		fail "the hand-off comment was not created on $repo#$issue"
	candidate=$(printf '%s\n' "$output" |
		awk 'NF { count += 1; value = $0 } END { if (count == 1) print value }')
	[ -n "$candidate" ] ||
		fail 'creating the hand-off comment returned no usable comment URL'
	printf '%s\n' "$candidate"
}

read_stored_body() { # url
	local url=$1 expected_prefix comment_id endpoint api_status=0
	expected_prefix="https://github.com/$repo/issues/$issue#issuecomment-"
	case $url in
	"$expected_prefix"*) comment_id=${url#"$expected_prefix"} ;;
	*) fail "the hand-off comment URL does not name $repo#$issue: $url" ;;
	esac
	# The id becomes a REST path segment below, so it is digits or nothing.
	case $comment_id in
	'' | *[!0123456789]*) fail "the hand-off comment URL carries no numeric comment id: $url" ;;
	esac
	endpoint="/repos/$repo/issues/comments/$comment_id"
	response=$(gh api --hostname github.com "$endpoint") || api_status=$?
	[ "$api_status" -eq 0 ] ||
		fail "the stored hand-off comment could not be read back: $endpoint"
	jq -r '.body' <<<"$response" >"$stored" ||
		fail "the stored hand-off comment could not be parsed: $endpoint"
}

# Every assertion runs against GitHub's stored copy. The three whole-line checks
# name the gate's three conditions individually so a failure says which one; the
# last is the catch-all no individual assertion can stand in for.
#
# The carriage-return check runs first deliberately. A CR at the end of every
# line defeats all three whole-line patterns at once, and reporting the first of
# them -- "missing the opening marker", of a body whose opening marker is right
# there -- is the same misdiagnosis one actor away that this script exists to
# remove. A CR explains the other three, so it is the finding worth reporting.
assert_stored_body() {
	if contains_byte 0d "$stored"; then
		fail 'the stored hand-off comment contains a carriage return, which defeats the merge gate anchored match'
	fi
	grep_whole_line "$MARKER" "$stored" 'the stored hand-off comment' ||
		fail "the stored hand-off comment is missing the opening marker on its own line: $MARKER"
	grep_whole_line "$SENTINEL" "$stored" 'the stored hand-off comment' ||
		fail "the stored hand-off comment is missing the closing sentinel on its own line: $SENTINEL"
	grep_whole_line "$handshake" "$stored" 'the stored hand-off comment' ||
		fail "the stored hand-off comment is missing the handshake on its own line: $handshake"
	jq -e --rawfile expected "$body" '.body == $expected' <<<"$response" >/dev/null ||
		fail 'the stored hand-off comment differs from the body this script composed'
}

validate_arguments "$@"
require_commands
make_workspace
validate_notes
resolve_head
compose_body
if [ "$operation" = preflight ]; then
	printf 'preflight-ok\n'
	exit 0
fi
comment_url=$(post_comment)
read_stored_body "$comment_url"
assert_stored_body
printf '%s\n' "$comment_url"
```

**1.3** `chmod +x skills/return-to-town/scripts/publish-handoff`.

**1.4** The suite is written after the helper, so no case can be observed red against an absent
helper. Every red in this task is therefore a guard-removal red, taken in step 1.6 against a helper
that is present and whose individual guards are removed one at a time. There is no `127` observation
to take, and none is claimed.

**1.5** Write `tests/fixtures/return-to-town/publish-handoff-test.sh`. Its scaffold:
`fixture_init publish-handoff-test`; a `write_fake_gh` emitting a `gh` that handles `pr view`,
`issue comment`, and `api`, branching on `GH_MODE` and reading `FAKE_PR_STATE`, `FAKE_PR_NUMBER`,
and `FAKE_BRANCH`; a `new_case` that builds a bare `origin.git` and a `work` clone, pushes
`refs/heads/feat/publish-handoff-308`, and records the real SHA into the fake's `head-ref-oid` state
file; a `run_helper` that runs the script from `work` with the fake on `PATH` and honours a
per-case `FAKE_BRANCH` override; and `expect_status` / `expect_stderr` assertion helpers. `chmod +x`
it.

The 28 cases, one line each — case name, then the single thing it asserts:

1. `case_usage` — no arguments exits 2 naming the usage line.
2. `case_bad_repo` — `acme`, `a/b/c`, and `acme/wid gets` each exit 1 naming the repository.
3. `case_bad_numbers` — issue `0` and PR `4x` each exit 1 naming which number.
4. `case_notes_unreadable` — absent, empty, and symlinked notes each exit 1.
5. `case_notes_bytes` — notes carrying NUL, CR, or non-UTF-8 each exit 1 naming the byte class.
6. `case_notes_too_large` — 9000-byte notes exit 1 naming the cap, and `gh` was never called.
7. `case_notes_carry_markers` — notes carrying either marker as a whole line exit 1.
8. `case_notes_carry_handshake` — notes carrying the handshake backticked, and bare, each exit 1.
9. `case_notes_unsafe` — notes carrying a denied path exit 1 naming public-safety, having posted
   nothing. Build the denied string as a split literal, as `scripts/check-public-safety-test.sh`
   does, or this suite trips the gate it is checking the helper calls.
10. `case_pr_not_open` — a `CLOSED` pull request exits 1 naming the state.
11. `case_pr_number_mismatch` — a pull request reporting `99` exits 1 naming it.
12. `case_branch_absent` — a head branch deleted from origin exits 1.
13. `case_multiple_refs` — a second `feat/` branch plus `FAKE_BRANCH=feat/*` exits 1 naming
    "expected exactly one"; `git ls-remote` globs its patterns, which is what makes this reachable.
14. `case_head_disagrees` — a `headRefOid` of all zeroes exits 1 naming both SHAs.
15. `case_preflight` — `--preflight` exits 0 printing `preflight-ok`, having posted nothing.
16. `case_publishes_the_required_shape` — exit 0; stdout is the comment URL; the posted body opens
    with the marker, ends with the sentinel, carries the handshake as a whole line for the real
    SHA, retains the narrative, carries no CR, and went to the right issue.
17. `case_notes_without_trailing_newline` — notes with no final newline still yield a whole-line
    handshake.
18. `case_stored_missing_sentinel` — a stored copy with the sentinel stripped exits 1 naming it.
19. `case_stored_missing_marker` — a stored copy with the marker stripped exits 1 naming it.
20. `case_stored_missing_handshake` — a stored copy with the handshake stripped exits 1 quoting the
    expected line.
21. `case_stored_carries_cr` — a stored copy with CR on every line exits 1 naming the carriage
    return, **not** the marker it also defeats.
22. `case_stored_differs` — a stored copy replaced wholesale exits 1.
23. `case_comment_creation_fails` — a failing `gh issue comment` exits 1 naming creation.
24. `case_readback_fails` — a failing `gh api` exits 1 naming the readback.
25. `case_bad_comment_url` — a foreign URL, a non-numeric id, no URL, and two URLs each exit 1.
26. `case_pr_view_fails` — a failing `gh pr view` exits **2**, not 1.
27. `case_missing_command` — a PATH holding only a `bash` symlink exits 2 naming the command.
    `#!/usr/bin/env bash` resolves the interpreter through PATH, so an empty PATH fails at exec
    with 127 and never reaches the check.
28. `case_rerun_is_safe` — after a readback failure, a second run posts a fresh complete block
    carrying both markers and the handshake, and exits 0.

**1.6** Verify the tests bite. For each of these, introduce the fault, run
`./tests/fixtures/return-to-town/publish-handoff-test.sh`, observe the named red, then revert:

| Fault | Expected red |
|---|---|
| drop `"$SENTINEL"` from `compose_body`'s final `printf` | 4 cases FAIL |
| replace the notes `grep -qF 'MERGE-READY:'` with `scan_status=1` | `FAIL regression: a backticked handshake in the notes is rejected` |
| move the CR check after the whole-line checks in `assert_stored_body` | `FAIL a stored copy carrying a carriage return fails, naming it` |
| drop `"$handshake"` from `compose_body`'s final `printf` | 3 cases FAIL, led by `FAIL the posted body carries both markers and a bare handshake line`, stderr naming the missing handshake |

The fourth row exists because the first three bite three narrow guards and leave the task's primary
contract — that the composed and posted block satisfies all three gate conditions — with no bite
evidence at all. That case is the whole point of the change, so it is the one that least deserves an
exemption from the repository's own "verify tests bite" standard.

**1.7** Run `shellcheck -x` and `shfmt -d` over both new files. Expect no output and exit 0 from
each.

**1.8** Run `./tests/fixtures/return-to-town/publish-handoff-test.sh` bare. Expect the final line
`publish-handoff-test: 28 passed, 0 failed` and exit 0.

**1.9** Commit: `feat(return-to-town): compose and verify the hand-off handshake`.

### Acceptance criteria

- `publish-handoff` exists, is executable, and passes `shellcheck -x` and `shfmt -d`.
- The suite exists under `tests/fixtures/return-to-town/`, is discovered by
  `just test publish-handoff`, and passes.
- Each of the three faults in step 1.6 was observed red and reverted.
- Every row of the design's failure table has a case.

### Rollback

Both files are new and nothing yet invokes the helper, so removing the two paths restores the tree.

## Task 2 — put the helper into the hand-off contract

Modifies `skills/return-to-town/SKILL.md`.

### Interfaces

Consumes from Task 1: the invocation and exit taxonomy given in Task 1's Interfaces block.
Provides to later tasks: nothing.

### Verification

- **Contract: `check-skill-shape.sh` still passes over the edited skill.** Mode: focused-test.
  Command `./scripts/check-skill-shape.sh`, expected output
  `check-skill-shape: <n> skills, all rules pass`, exit 0. Expected red if the edit introduced a
  broken `../../references/` link: `reference link does not resolve: <path>`, exit 1.
- **Contract: the prose replacement itself.** Mode: task-test-not-applicable. The changed surface is
  the hand-off instruction text in `skills/return-to-town/SKILL.md`. No executable or structural
  observation can fail meaningfully on it, and anatomy rule 4 forbids a gate that asserts on prose —
  no test may check that a document contains a given sentence. The structural half of the change
  (that the invoked path exists) is covered by the criterion below rather than by a prose assertion.

### Steps

**2.1** In `skills/return-to-town/SKILL.md`, replace the second paragraph of *Record the author
handshake* — the one beginning `**That comment carries the handshake.**` and running to
`it never authorizes a merge.` — with text that: names
`skills/return-to-town/scripts/publish-handoff` as what composes and posts the block; states that
the caller writes the narrative only and must not write either marker or the handshake; states that
the helper reads the SHA from `git ls-remote`, requires GitHub's `headRefOid` to agree, and asserts
the stored copy; states the exit taxonomy; and states that a nonzero exit holds both paths, is
re-run rather than diagnosed by hand, and does not by itself mean nothing was posted — three of the
conditions are checked after the comment is created. Keep the surrounding paragraphs.

**2.2** Add the invocation, in a fenced `sh` block, immediately after that paragraph:

```sh
skills/return-to-town/scripts/publish-handoff --preflight <owner/name> <issue> <PR> <notes-file>
skills/return-to-town/scripts/publish-handoff <owner/name> <issue> <PR> <notes-file>
```

**2.3** Run `./scripts/check-skill-shape.sh` bare. Expect `all rules pass`, exit 0.

**2.4** Commit: `docs(return-to-town): invoke the hand-off helper`.

### Acceptance criteria

- The composition instructions are gone; nothing in `SKILL.md` still tells a reader to write the
  markers or the handshake by hand.
- The path named in `SKILL.md` exists in the tree.
- `./scripts/check-skill-shape.sh` exits 0.

### Rollback

Revert the single file; Task 1's helper becomes unused but harmless.

## Task 3 — the decision record and the version bump

Creates `docs/adr/0056-compose-the-handoff-handshake.md` and modifies `.claude-plugin/plugin.json`.

### Interfaces

Consumes: nothing. Provides: nothing.

### Verification

- **Contract: the record satisfies the ADR gate.** Mode: focused-test. Command
  `RECORD_PROFILES="adr" ./.github/scripts/check-records.sh`, exit 0. Expected red on a record
  missing a required section: the gate reports `E-SECTION` naming the file, exit 1.
- **Contract: the version is a strictly greater `MAJOR.MINOR.PATCH`.** Mode: focused-test. Command
  `./scripts/check-plugin-version.sh`, exit 0. Expected red on a malformed value: the gate names the
  rule it failed, exit 1.

### Steps

**3.1** Write `docs/adr/0056-compose-the-handoff-handshake.md` with the five required
sections — `## Status`, `## Context`, `## Decision`, `## Consequences`, `## Considered & rejected` —
a `## Status` body of `Accepted (2026-09-06)`, and an H1 carrying the record's number. Every
`Considered & rejected` bullet names its alternative and opens its ground with `verified:` or
`judgment:`.

**3.2** Do **not** add an index row. `docs/adr/README.md` deliberately carries no index table and
the adr profile warns `W-INDEX-TABLE` if one appears.

**3.3** Link the record from the spec and from this plan's header.

**3.4** Bump `.claude-plugin/plugin.json` `version` from `4.1.1` to `4.2.0`. `MINOR`, because this
change adds a capability — a new helper — and removes or renames nothing.

**3.5** Run `just records` and `./scripts/check-plugin-version.sh` bare. Expect exit 0 from each.

**3.6** Commit: `docs(adr): record the hand-off handshake composer`.

### Acceptance criteria

- The record carries all five sections and every rejected alternative carries an evidence tag.
- No row was added to `docs/adr/README.md`.
- `.claude-plugin/plugin.json` declares `4.2.0`.
- `just records` and `./scripts/check-plugin-version.sh` both exit 0.

### Rollback

Remove the record and restore `4.1.1`.

## Task 4 — full guardrails

### Verification

- **Contract: the whole guardrail suite.** Mode: focused-test. Command `just verify`, run bare,
  expected exit 0. Expected red for any regression this change introduced in `lint`,
  `format-check`, `public-safety`, `scan-fault-check`, `shape-check`, `ripgrep-config-check`,
  `plugin-check`, `version-check`, `test`, or `actions-check`: the failing recipe names itself and
  the run exits non-zero.

### Steps

**4.1** Run `just verify` bare — no pipe, no `|| true`. A pipeline returns the last exit code and
would hide the failure.

**4.2** Fix anything red, commit each fix separately, and re-run.

### Acceptance criteria

- `just verify` exits 0.

## Deferrals

None recorded by the design review. Any deferral a `$trial-loop` run on this branch disposes of
gets appended here with its owning record path or tracker issue.
