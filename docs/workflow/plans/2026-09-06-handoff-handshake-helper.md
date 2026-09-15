# Hand-off handshake helper — implementation plan

Derived from [the design](../specs/2026-09-06-handoff-handshake-helper-design.md) and
[ADR 0066](../../adr/0066-compose-the-handoff-handshake.md).

**Goal.** Replace `$return-to-town`'s hand-composed merge hand-off annotation with one executable
that composes the block, computes the head SHA itself, asserts every condition the merge gate checks
against what it composed, posts the comment, and asserts them again against the copy GitHub stored.

**Architecture.** One new executable, `skills/return-to-town/scripts/publish-handoff`. It takes the
repository, issue, pull request, and a narrative file, and owns everything the gate reads: both
annotation markers and the `MERGE-READY` line. It resolves the head branch from the pull
request and, from that same read, the issues the pull request closes; it corroborates the
destination issue against that list before composing — the only check whose evidence does not come
from the `ISSUE` argument itself — and additionally refuses a resource that is a pull request.
It reads the SHA from `git ls-remote origin`, requires GitHub's `headRefOid` to agree, composes the
body, runs the repository's existing public-safety gate over it, asserts the gate's four whole-line
conditions on what it composed, posts with `gh issue comment`, re-reads the stored comment, and
asserts those four again plus byte equality. A behaviour suite
under `tests/fixtures/return-to-town/` fakes `gh` and uses a real git repository with a real bare
remote. `skills/return-to-town/SKILL.md` replaces its composition prose with the invocation.

**Tech stack.** Bash and Markdown. No dependencies, no build step. Gates are `just verify`.

**Expected implementation size: 1340–1360 changed lines (L) — summed from the file map below: the
step 1.2 transcript at 477 lines, the suite at 837 lines with its 35 enumerated cases
written, roughly 25 lines of contract text in `skills/return-to-town/SKILL.md`, and the one-line
version bump.**

The basis is the artifact this plan commits to, not an earlier draft of it: the transcript's own
length already includes the destination corroboration, so that work is not added a second time. The
ADR the file map lists is excluded on purpose — the estimate measures the implementation the plan
produces, and a decision record is a design artifact, counted in the design set the proportionality
gate measures rather than here.

The band is the complexity frozen in `WORK:SCOPE` before this design cycle, carried forward
unchanged. Only the numeric range is this plan's own estimate, and it has moved: `950–1050` when
this plan was first written, then `1080–1180`, then `1130–1240`, then `1180–1280`, and now
`1340–1360` — the last one measured from the written files rather than projected. Each earlier
raise is traceable to an accepted review finding that added checked behaviour: the destination
binding, the git-environment clearing, and the cases for both. None widened a criterion.

**The final move is a projection error, not new work, and it is classified rather than trimmed.**
The suite was projected at roughly 700 lines and came in at 837 for the same 35 enumerated cases.
Nothing in the diff is absent from the reviewed design: every case maps to a failure-table row or a
named regression, and the helper is byte-identical to the transcript at step 1.2. The estimate was
wrong; the work is required by the frozen scope. Reducing lines to meet the number would be the one
response this plan's own guardrails forbid, so the number is corrected and the miss recorded here.

The charter at `#issuecomment-5687258622` cites `1080–1180` as corroborating the `L` band. That
citation is now some 250 lines stale, though the band it corroborates is unaffected: the estimate
moved further above the 1000-line denominator, never back toward `M`.

The drift is recorded rather than quietly restated, because an estimate that ratchets while nobody
is counting is how a design stops being the thing that was reviewed. The band was `M` in the
2026-09-06 cycle — read off the issue before any file map existed, and unmeetable by any
implementation naming twenty distinct failure conditions. It was corrected at this cycle's scope
checkpoint from the completion criteria, not from this estimate: a plan estimate corroborates a
denominator and never sets one.

The suite is the larger half, and that is proportionate rather than inflated — its sibling
`tests/fixtures/quest/publish-forge-review-test.sh` runs 1046 lines for a helper of 339, and this
one covers 40 cases including one regression per defect logged in the issue. Cases 36 and 37 were
added during branch review, which constructed a second post-write failure the design had ruled out;
cases 38–40 by the security pass, which found three boundaries the threat model had not inventoried.

**How the two code files are specified here differs, deliberately.** The helper appears in full, at
step 1.2, because its exact bytes are the contract — the markers, the handshake, and the assertion
order are the deliverable. The suite is specified by an enumerated case list, at step 1.5: one line
per case naming the case and the single assertion it makes. That is a complete specification of what
the suite must do without transcribing its 800-odd lines, whose shape is mechanical once the case list and
the fixture sketch are fixed, and it is what makes the pinned pass count derivable rather than
asserted. An implementer who writes exactly the 35 enumerated cases reaches the acceptance criterion
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
  change adds a capability, so `MINOR`. The base moved twice while this branch was parked: `main`
  was at `4.1.2` when this plan was written and is at **`5.7.4`** as of 2026-09-15, so this branch
  takes **`5.8.0`**. The original `4.3.0` assignment is dead. Re-check against the base at resume —
  it may move again, and the gate requires strictly greater than the base's, not a fixed value.
- Records are numbered against the live `docs/adr/` at resume, never from an earlier assignment.
  The number this change was assigned in triage (`0043`) and the one it first took (`0057`) are
  both merged records owned by other decisions; `0065` is the highest on `main` as of 2026-09-15,
  so this change takes **`0066`**.
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
| `docs/adr/0066-compose-the-handoff-handshake.md` | new | the decision recorded alongside this plan |

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

- `scripts/check-public-safety.sh` — the path the helper invokes, and a 9-line wrapper that
  `exec`s the real scanner. The contract it inherits — takes zero or more paths to scan, exits 0
  clean, 1 on a finding, 2 on a fault — is defined in that scanner, confirmed at
  `skills/quest/scripts/check-public-safety:21-25` (`if (($# > 0)); then scan_paths=("$@")`), with
  the exit-2 fault path at `:17-18`. The wrapper is cited separately from the contract because the
  wrapper is what the code calls and the scanner is what the behaviour comes from.
- `scripts/test-fixture-helpers.sh` — sourced, provides `clear_git_env`, `fixture_init <label>`
  (sets `SCRATCH`), `fixture_scratch <prefix>` (sets `FIXTURE_SCRATCH`). Documented at
  `scripts/test-fixture-helpers.sh:20-30`; `SCRATCH` is assigned at
  `scripts/test-fixture-helpers.sh:123` and `FIXTURE_SCRATCH` at
  `scripts/test-fixture-helpers.sh:61`.

### Verification

- **Contract: the composed and posted block satisfies the merge gate's anchored conditions.**
  Mode: focused-test. Test file `tests/fixtures/return-to-town/publish-handoff-test.sh`, case
  `case_publishes_the_required_shape`. Expected red with `"$handshake"` removed from
  `compose_body`'s final `printf`: 10 cases FAIL, led by the preflight case, with
  `expected exit 0, got 1` and stderr
  `publish-handoff: the composed hand-off body is missing the handshake on its own line:
  MERGE-READY: #42 @ <sha>` — the compose-side assertion catches the omission before anything is
  posted, which is that assertion doing its job. Green command:
  `./tests/fixtures/return-to-town/publish-handoff-test.sh`, expected final line
  `publish-handoff-test: 35 passed, 0 failed`, exit 0.
- **Contract: the write destination is bound to the pull request before composing.** Mode:
  focused-test. Same file, case `case_issue_not_closed_by_pr`. Expected red with the
  `closingIssuesReferences` match removed from `resolve_destination`:
  `FAIL an ISSUE the pull request does not close is refused: expected exit 1, got 0` — with the
  check gone the run posts a complete block to the wrong issue and exits 0, which is the defect the
  control exists to close. Green command:
  `./tests/fixtures/return-to-town/publish-handoff-test.sh`, expected final line
  `publish-handoff-test: 35 passed, 0 failed`, exit 0. This is the contract the other destination
  checks cannot cover: every one of them is answered by the resource `ISSUE` selected, so only this
  one fails on a transposed-but-valid number.
- **Contract: an `ISSUE` naming a pull request is refused by name, before anything is posted.**
  Mode: focused-test. Same file, case `case_issue_is_pull_request`; the supporting cases
  `case_pr_no_closing_issue` and `case_issue_not_corroborated` cover the empty-list and
  unreadable/mismatched branches. Expected red with the `pull_request` key check removed from
  `resolve_destination`:
  `FAIL an ISSUE naming a pull request is refused before anything is posted: expected exit 1,
  got 0`. Green command as above.
- **Contract: the head SHA is read from the checkout's own origin, whatever git environment the
  caller exported.** Mode: focused-test. Same file, case `case_stray_git_env_is_cleared`. Expected
  red with the `clear_local_git_env` call removed from `resolve_head`:
  `FAIL the head SHA is read from the checkout's own origin` — the handshake carries the SHA of the
  repository `GIT_DIR` pointed at. The case asserts on the posted body's SHA rather than on a
  refusal, because the failure it guards is a silent wrong answer, not an error. Green command as
  above.
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
- **Contract: a public-safety scan that could not run is a fault, never a finding.** Mode:
  focused-test. Same file, case `case_public_safety_fault`. Expected red with the `case
  $safety_status` block replaced by `|| fail ...`: `expected exit 2, got 1`. Green command as above.
- **Contract: a fork pull request is refused by name, before the remote read.** Mode: focused-test.
  Same file, case `case_fork_pr`. Expected red without the `isCrossRepository` check: `expected exit
  1, got 0` — or, where origin lacks the branch, a pass for the wrong reason with stderr saying the
  branch moved, which is why the check precedes the remote read. Green command as above.
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

SCRIPT_DIR=${BASH_SOURCE[0]%/*}
[ "$SCRIPT_DIR" = "${BASH_SOURCE[0]}" ] && SCRIPT_DIR=.
# `CDPATH='' cd -P --` on both, and the empty assignment is the load-bearing half.
# cd consults CDPATH whenever its operand is relative and does not begin with ./
# or ../, and echoes the directory it chose -- so under a caller's exported
# CDPATH (`.` alone is enough) a relative invocation resolves the script's own
# location to a directory that environment named, and the command substitution
# captures the echo as well. These two lines run above the EXIT trap and above
# fault(), so a failure here exits 1 with cd's bare diagnostic: the status this
# script reserves for a hand-off condition, spent on something that is not one.
SCRIPT_DIR=$(CDPATH='' cd -P -- "$SCRIPT_DIR" && pwd)
ROOT=$(CDPATH='' cd -P -- "$SCRIPT_DIR/../../.." && pwd)

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
issue_html_url=''
pr_closing_refs=''
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
	# rg is here because check-public-safety.sh needs it and exits 2 without it.
	# Refusing at this preflight names the missing binary; letting it through
	# reaches that gate's fault status instead, which says nothing useful.
	for required in gh jq git grep rg iconv od awk wc tail cat tr mktemp rm; do
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
	# Shape, not just charset. Both halves become REST path segments -- twice,
	# at /repos/$repo/issues/$issue and /repos/$repo/issues/comments/<id> -- and
	# `.` is inside the permitted set above, so `../..` clears every test before
	# this one: one slash, two non-empty halves, no forbidden character. This is
	# the discipline the ISSUE argument and the comment id already get. A
	# leading `-` is refused with them: harmless at today's call sites, where
	# $repo is never a command's first token, but not a property to rely on.
	case ${repo%%/*} in
	.* | -*) fail "repository owner may not begin with a dot or a dash: $repo" ;;
	esac
	case ${repo#*/} in
	.* | -*) fail "repository name may not begin with a dot or a dash: $repo" ;;
	esac
	case $issue in
	'' | *[!0123456789]* | 0) fail "issue number is invalid: $issue" ;;
	esac
	case $pr in
	'' | *[!0123456789]* | 0) fail "pull request number is invalid: $pr" ;;
	esac
	# iconv, od, cat and tail all take this path as a bare operand, so a name
	# beginning with `-` is consumed as an option and those tools read stdin
	# instead. Three of the byte validations then return clean having never
	# opened the file -- a scan that could not run reporting as one that found
	# nothing, which is the failure this script states it exists to prevent.
	# `./` makes it a path to every one of them, and changes nothing else.
	case $notes in
	-*) notes=./$notes ;;
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

# Read from git rather than hardcoded: the list of repository-local variables is
# git's to define, and a hardcoded copy silently goes stale when git adds one.
clear_local_git_env() {
	local variable variables
	variables=$(git rev-parse --local-env-vars) ||
		fault 'could not read the list of git local environment variables'
	[ -n "$variables" ] ||
		fault 'git reported no local environment variables'
	while IFS= read -r variable; do
		[ -n "$variable" ] || continue
		unset "$variable"
	done <<<"$variables"
}

# The issue number decides where the block lands, and every check after the write
# is derived from it -- the expected comment-URL prefix is composed from it, and
# the readback path comes from the id in that URL -- so none of them can detect it
# being wrong. A transposed number would publish a complete block where nobody
# reads, and exit 0 printing a verified URL for it.
#
# Which is why asking the issue about itself is not enough: "does it exist", "is
# it an issue", "does it report this number" are all answered by the resource the
# argument selected, so a transposed but valid number passes every one. The
# binding that bites comes from the pull request instead -- it names the issues it
# closes, and that statement does not inherit the argument under test.
resolve_destination() {
	local issue_json is_pull number matched
	# The independent check, first, because it is the one that catches the
	# likeliest mistake. An empty list is refused rather than waved through: the
	# requirement is that the destination be corroborated before composing, and an
	# uncorroborated destination is the state this function exists to eliminate.
	# Note the ground is this script's own requirement -- references/merge-gate.md
	# imposes no closing-reference rule, and claiming it did would be inventing a
	# contract the reference does not contain.
	[ -n "$pr_closing_refs" ] ||
		fail "pull request $repo#$pr declares no closing issue, so the hand-off destination cannot be corroborated; add a 'Closes #$issue' trailer to the pull request body and re-run"
	matched=no
	# An if, not `[ ... ] && matched=yes`: under `set -e` a failing && list as the
	# last command in the loop body exits the shell, so the common case -- a
	# closing reference that is not this issue -- would abort mid-check.
	while IFS= read -r number; do
		case $number in
		'' | *[!0123456789]*)
			fault "the pull request reported an unparseable closing-issue number: $number"
			;;
		esac
		if [ "$number" = "$issue" ]; then
			matched=yes
		fi
	done <<<"$pr_closing_refs"
	[ "$matched" = yes ] ||
		fail "pull request $repo#$pr closes $(printf '%s' "$pr_closing_refs" | tr '\n' ' ')but the hand-off names issue $issue; one of the two is wrong"
	issue_json=$(gh api --hostname github.com "/repos/$repo/issues/$issue") ||
		fault "the hand-off destination could not be read: $repo#$issue -- check the ISSUE argument first, then whether GitHub is reachable"
	# GitHub serves pull requests from the issues number space and returns them
	# with a pull_request key an ordinary issue does not carry. The closing-issue
	# check above does not cover this: a pull request number may legitimately
	# appear in no closing-reference list, so a swapped ISSUE/PR pair would fail
	# there with a message about the wrong thing. Without this check the comment is
	# created before anything can object, surfacing one step later as an
	# unparseable URL rather than as the swapped argument it is.
	is_pull=$(jq -r 'if has("pull_request") then "yes" else "no" end' <<<"$issue_json") ||
		fault 'the destination response could not be parsed'
	[ "$is_pull" = no ] ||
		fail "$repo#$issue is a pull request, not an issue; the hand-off block is recorded on the issue, so ISSUE and PR appear to have been swapped"
	number=$(jq -r '.number' <<<"$issue_json") ||
		fault 'the destination response could not be parsed'
	[ "$number" = "$issue" ] ||
		fail "the destination reported number $number, not $issue"
	# Kept for read_stored_body. GitHub canonicalizes owner/name in every URL it
	# returns, so the URL of the comment this script is about to create will not
	# carry the case REPO was given. Rebuilding the expected prefix from REPO
	# therefore refuses a comment that was created correctly -- a published
	# hand-off reported as unpublished, whose remedy is to publish another one.
	# The destination's own html_url is the canonical form, from the same
	# response the checks above already trust.
	issue_html_url=$(jq -r '.html_url // empty' <<<"$issue_json") ||
		fault 'the destination response could not be parsed'
	[ -n "$issue_html_url" ] ||
		fault "the destination reported no canonical URL: $repo#$issue"
}

# The SHA is read from the remote, never from headRefOid, per
# skills/return-to-town/SKILL.md. headRefOid is then required to agree: it is a
# second independent observation, and a disagreement means the branch moved
# between the two reads -- exactly the moment a handshake must not be posted.
resolve_head() {
	local pr_json number state head_branch head_ref_oid cross ls_output line_count
	pr_json=$(gh pr view "$pr" --repo "github.com/$repo" \
		--json number,state,headRefName,headRefOid,isCrossRepository,closingIssuesReferences) ||
		fault "the pull request could not be read: $repo#$pr"
	# Read here because this is the call that already exists; consumed by
	# resolve_destination, which runs next. One number per line, empty when the
	# pull request body carries no Closes trailer.
	pr_closing_refs=$(jq -r '.closingIssuesReferences[].number' <<<"$pr_json") ||
		fault 'the pull request response could not be parsed'
	number=$(jq -r '.number' <<<"$pr_json") ||
		fault 'the pull request response could not be parsed'
	state=$(jq -r '.state' <<<"$pr_json") ||
		fault 'the pull request response could not be parsed'
	head_branch=$(jq -r '.headRefName' <<<"$pr_json") ||
		fault 'the pull request response could not be parsed'
	head_ref_oid=$(jq -r '.headRefOid' <<<"$pr_json") ||
		fault 'the pull request response could not be parsed'
	cross=$(jq -r '.isCrossRepository' <<<"$pr_json") ||
		fault 'the pull request response could not be parsed'
	[ "$number" = "$pr" ] ||
		fail "the pull request reported number $number, not $pr"
	[ "$state" = OPEN ] ||
		fail "the pull request is $state, not OPEN; a hand-off records an open pull request"
	case $head_branch in
	'' | null) fail 'the pull request reported no head branch' ;;
	esac
	# Checked before the remote read, because after it a fork is indistinguishable
	# from a moved branch: origin either lacks the branch or carries an unrelated
	# one of the same name, and "the branch moved -- re-run once it settles" is a
	# permanent refusal wearing a transient message.
	[ "$cross" = false ] ||
		fail "the pull request head branch $head_branch lives in a fork; this script reads the head SHA from the origin of the local checkout, which never carries a fork's branch under refs/heads/, so cross-fork hand-off is not supported"
	# git's local environment variables outrank the process working directory, so
	# a stray GIT_DIR or GIT_INDEX_FILE would have ls-remote read a different
	# repository's origin and return a real SHA from the wrong remote. Cleared the
	# way skills/quest/scripts/check-public-safety clears it before its own git
	# calls, and for the same reason.
	clear_local_git_env
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
	# Three-way, never two. The gate exits 0 clean, 1 on a finding, and 2 when it
	# could not run -- and `|| fail` would report a scanner that never ran as one
	# that found a credential, which is a permanent refusal wearing a transient
	# message. Its stderr is passed through rather than discarded, because on the
	# fault branch it is the only text that says why.
	safety_status=0
	"$ROOT/scripts/check-public-safety.sh" "$body" >/dev/null || safety_status=$?
	case $safety_status in
	0) ;;
	1) fail 'the composed hand-off body did not pass public-safety validation' ;;
	*) fault "the public-safety scan could not run (exit $safety_status); the body was not published" ;;
	esac
	# The gate's own conditions, checked on what this script composed, before
	# anything is posted. The premise of this whole script is that a composer's
	# output is verified rather than trusted, and that applies to its own output
	# first: without this, a composition defect is published and only then
	# detected, leaving exactly the unselectable block the change exists to
	# prevent. It also makes --preflight mean what R8 says it means.
	assert_gate_conditions "$body" 'the composed hand-off body'
}

post_comment() {
	local output post_status=0 candidate
	# Host-qualified, as publish-forge-review does. A bare owner/name resolves
	# against gh's configured default host, while the readback below pins
	# github.com -- so on a workstation defaulting to an Enterprise instance the
	# comment would be created on one host and looked for on another.
	output=$(gh issue comment "$issue" --repo "github.com/$repo" --body-file "$body") || post_status=$?
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
	# From the destination's canonical URL, never from the REPO argument --
	# see resolve_destination.
	expected_prefix="$issue_html_url#issuecomment-"
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

# The merge gate's four whole-line conditions, checked against whichever copy is
# named. compose_body runs this on what this script wrote; assert_stored_body
# runs it again on what GitHub stored, because only the second says what the
# gate will read.
#
# The carriage-return check runs first deliberately. A CR at the end of every
# line defeats all three whole-line patterns at once, and reporting the first of
# them -- "missing the opening marker", of a body whose opening marker is right
# there -- is the same misdiagnosis one actor away that this script exists to
# remove. A CR explains the other three, so it is the finding worth reporting.
assert_gate_conditions() { # path label
	local path=$1 label=$2
	if contains_byte 0d "$path"; then
		fail "$label contains a carriage return, which defeats the merge gate anchored match"
	fi
	grep_whole_line "$MARKER" "$path" "$label" ||
		fail "$label is missing the opening marker on its own line: $MARKER"
	grep_whole_line "$SENTINEL" "$path" "$label" ||
		fail "$label is missing the closing sentinel on its own line: $SENTINEL"
	grep_whole_line "$handshake" "$path" "$label" ||
		fail "$label is missing the handshake on its own line: $handshake"
}

assert_stored_body() {
	assert_gate_conditions "$stored" 'the stored hand-off comment'
	# Reaching here means all four gate conditions hold on GitHub's copy, so a
	# gate-valid block IS on the issue. A difference now is a storage or
	# transport normalization, not a broken hand-off -- and re-running would
	# reproduce it forever while appending another complete block, so the
	# message says to verify rather than retry.
	jq -e --rawfile expected "$body" '.body == $expected' <<<"$response" >/dev/null ||
		fail 'the stored hand-off comment differs byte-for-byte from the body this script composed, though every gate condition holds on it; a usable block is on the issue -- inspect it and proceed rather than re-running'
}

validate_arguments "$@"
require_commands
make_workspace
validate_notes
resolve_head
resolve_destination
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

The fake's `api` arm now serves two distinct paths and must dispatch on which one it was given,
because the helper reads both through `gh api`:

- `/repos/<owner>/<name>/issues/<n>` — the destination read. Default response is a well-formed
  issue object `{"number": <n>}` with **no** `pull_request` key. `FAKE_ISSUE_MODE=absent` makes it
  exit nonzero; `FAKE_ISSUE_MODE=mismatch` makes it report a `number` that is not `<n>`; and
  `FAKE_ISSUE_MODE=pull` makes it return `{"number": <n>, "pull_request": {"url": "..."}}` — an
  otherwise-correct payload differing from the default only in that key, so case 32 bites on the
  key and nothing else.
- `/repos/<owner>/<name>/issues/comments/<id>` — the existing readback. Its `GH_MODE` branches are
  unchanged.

Dispatch on the path shape rather than on argument position: the two differ only in the segment
after `issues`, and a fake that matched a prefix would answer the readback with an issue object.

The 35 cases, one line each — case name, then the single thing it asserts:

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
10. `case_fork_pr` — `FAKE_CROSS=true` exits 1 naming the fork, having posted nothing. Checked
    before the remote read, or a fork is indistinguishable from a moved branch.
11. `case_public_safety_fault` — an `rg` stub exiting 2 makes the public-safety gate fault; the
    helper exits **2** naming that the scan could not run, having posted nothing. Collapsing that
    into exit 1 would report a scanner that never ran as one that found a credential.
12. `case_pr_not_open` — a `CLOSED` pull request exits 1 naming the state.
13. `case_pr_number_mismatch` — a pull request reporting `99` exits 1 naming it.
14. `case_branch_absent` — a head branch deleted from origin exits 1.
15. `case_multiple_refs` — a second `feat/` branch plus `FAKE_BRANCH=feat/*` exits 1 naming
    "expected exactly one"; `git ls-remote` globs its patterns, which is what makes this reachable.
16. `case_head_disagrees` — a `headRefOid` of all zeroes exits 1 naming both SHAs.
17. `case_preflight` — `--preflight` exits 0 printing `preflight-ok`, having posted nothing.
18. `case_publishes_the_required_shape` — exit 0; stdout is the comment URL; the posted body opens
    with the marker, ends with the sentinel, carries the handshake as a whole line for the real
    SHA, retains the narrative, carries no CR, and went to the right issue.
19. `case_notes_without_trailing_newline` — notes with no final newline still yield a whole-line
    handshake.
20. `case_stored_missing_sentinel` — a stored copy with the sentinel stripped exits 1 naming it.
21. `case_stored_missing_marker` — a stored copy with the marker stripped exits 1 naming it.
22. `case_stored_missing_handshake` — a stored copy with the handshake stripped exits 1 quoting the
    expected line.
23. `case_stored_carries_cr` — a stored copy with CR on every line exits 1 naming the carriage
    return, **not** the marker it also defeats.
24. `case_stored_differs` — a stored copy replaced wholesale exits 1.
25. `case_comment_creation_fails` — a failing `gh issue comment` exits 1 naming creation.
26. `case_readback_fails` — a failing `gh api` exits 1 naming the readback.
27. `case_bad_comment_url` — a foreign URL, a non-numeric id, no URL, and two URLs each exit 1.
28. `case_pr_view_fails` — a failing `gh pr view` exits **2**, not 1.
29. `case_missing_command` — a PATH holding only a `bash` symlink exits 2 naming the command.
    `#!/usr/bin/env bash` resolves the interpreter through PATH, so an empty PATH fails at exec
    with 127 and never reaches the check.
30. `case_rerun_is_safe` — after a readback failure, a second run posts a fresh complete block
    carrying both markers and the handshake, and exits 0.
31. `case_issue_not_closed_by_pr` — **the transposition case, and the one that matters most.** The
    fake reports `closingIssuesReferences` naming a *different* issue number, and the destination
    resolves to a perfectly valid open issue that is not a pull request. Exits 1 naming both the
    issue the hand-off was given and the one the pull request closes. Asserts `gh issue comment`
    was never called. Every other check in `resolve_destination` passes here, which is the point:
    without the closing-reference binding this case exits 0.
32. `case_pr_no_closing_issue` — `closingIssuesReferences` empty exits 1 naming that the
    destination cannot be corroborated and naming the `Closes #<n>` trailer as the remedy, having
    posted nothing.
33. `case_issue_not_corroborated` — two sub-assertions, as cases 2–5 bundle theirs. An `ISSUE` the
    fake reports as not found exits **2** naming the destination that could not be read — exit 2
    rather than 1 for the reason `case_pr_view_fails` takes it: `gh` does not separate "no such
    resource" from "could not reach GitHub", and the script does not guess. An `ISSUE` whose
    resolved payload reports a different `number` exits **1** naming both numbers. Both assert
    `gh issue comment` was never called.
34. `case_issue_is_pull_request` — an `ISSUE` the fake resolves to a resource carrying a
    `pull_request` key exits 1 naming the swapped argument, having posted nothing. The fake must
    return an otherwise well-formed issue payload whose `number` matches **and** list that number
    in `closingIssuesReferences`, so the case bites on the `pull_request` key alone and not on some
    other mismatch.
35. `case_stray_git_env_is_cleared` — a second bare repository is created with a different commit
    on the same branch name, `GIT_DIR` is exported to point at it, and the helper still posts a
    handshake carrying the SHA from the *checkout's* origin. Asserts on the posted body's SHA, not
    on an error: the failure this guards is a silent wrong answer, so the case has to observe the
    right answer rather than a refusal.
36. `case_repo_case_variant_is_canonicalized` — **added during branch review, which constructed the
    defect it covers.** The fake gains `FAKE_CANONICAL_REPO`, reproducing GitHub's canonicalization
    of `owner/name` in every URL it returns; the helper is invoked with an uppercase `REPO`, which
    the argument grammar permits. Exits 0 and prints the *canonical* comment URL. Observed red
    before the fix with the real message — `the hand-off comment URL does not name ACME/WIDGETS#308`
    — after the comment had already been created and was gate-valid.
37. `case_destination_url_missing` — a destination response carrying no `html_url` exits **2**
    naming the missing canonical URL, having posted nothing. Without the guard the prefix is
    `#issuecomment-`, which a `case` pattern anchors at the start, so it matches no absolute URL:
    the helper still fails closed, but only *after* the comment has been created — reproducing the
    post-write exit 1 that R13 exists to remove. The guard moves that refusal ahead of the write,
    which is what the case asserts by requiring exit 2 and an events log carrying no `post`.

Cases 38–40 were added by the `$detect-evil` pass, which is why each names a boundary rather than a
gate condition:

38. `case_repo_path_segments` — `../..`, `acme/..`, `./x`, `-x/y` and `.hidden/x` each exit 1
    naming the repository, having posted nothing. Observed red at **exit 0**: `../..` carries one
    slash and two non-empty halves and every character is in the permitted set, so before the fix
    the helper accepted it and published a complete block.
39. `case_notes_option_shaped` — a notes file literally named `-s`, containing invalid UTF-8, is
    refused naming the byte class. Observed red at exit 2 with `tail: invalid option -- s`, which
    is the proof rather than a detail: `iconv`, `od` and `cat` had all already returned clean on a
    file they never opened, and only the fourth tool objected.
40. `case_cdpath_does_not_steer_resolution` — the helper is copied into a fake plugin root inside
    the work repository and invoked by a **relative** path with `CDPATH` exported to a decoy root
    that satisfies the same relative operand. Exits 0 and posts a complete block. Observed red at
    exit 1 with `cd:` naming the *decoy* root, which shows both halves of the defect: the value was
    doubled, and it was steered.

**1.6** Verify the tests bite. For each of these, introduce the fault, run
`./tests/fixtures/return-to-town/publish-handoff-test.sh`, observe the named red, then revert:

| Fault | Expected red |
|---|---|
| drop `"$SENTINEL"` from `compose_body`'s final `printf` | every case that reaches composition fails, led by the preflight case, stderr naming the missing sentinel on the **composed** body — observed `24 passed, 11 failed` |
| drop `"$handshake"` from `compose_body`'s final `printf` | every case that reaches composition fails, led by `FAIL preflight validates and composes without posting`, stderr naming the missing handshake on the **composed** body — observed `24 passed, 11 failed` |
| replace the notes `grep -qF 'MERGE-READY:'` with `scan_status=1` | `FAIL regression: a backticked handshake in the notes is rejected: expected exit 1, got 0` |
| move the CR check after the whole-line checks in `assert_gate_conditions` | `FAIL a stored copy carrying a carriage return fails, naming it`, with stderr naming the opening marker instead |
| collapse the `case $safety_status` block back to `\|\| fail ...` | `FAIL a public-safety scan that could not run is a fault, not a finding: expected exit 2, got 1` |
| delete the `[ "$cross" = false ]` check | `FAIL a pull request whose head is in a fork is rejected, naming the fork: expected exit 1, got 0` |
| delete the `pull_request` key check in `resolve_destination` | `FAIL an ISSUE naming a pull request is refused before anything is posted: expected exit 1, got 0` |
| delete the `closingIssuesReferences` match in `resolve_destination` | `FAIL an ISSUE the pull request does not close is refused: expected exit 1, got 0` — the case posts a complete block to the wrong issue and exits 0, which is the defect this control exists to close |
| delete the `clear_local_git_env` call in `resolve_head` | `FAIL the head SHA is read from the checkout's own origin` — the case exports a `GIT_DIR` pointing at a second repository and the handshake binds that repository's SHA |

The second row exists because the others bite narrow guards and would leave the task's primary
contract — that the composed and posted block satisfies every byte-level gate condition — with no
bite evidence at all. That case is the whole point of the change, so it is the one that least
deserves an exemption from the repository's own "verify tests bite" standard.

The first two rows state their red qualitatively rather than pinning a number. The compose-side
assertion added in R5 catches either omission at `--preflight`, before any case reaches its own body
inspection, so the failure count is whatever the case list happens to contain that reaches
composition — a figure this plan cannot derive from the case list without also modelling each
case's early-exit path, and a pinned prediction that the run then contradicts is a verification
defect rather than a finding about the code. The counts above are recorded from the step 1.6 run,
not predicted: an earlier draft of this plan pinned `10 cases FAIL` for both, and the observed
figure is 11. The stderr text is the load-bearing half and it is pinned, because that is what
proves the compose-side assertion fired rather than some later check.

**1.7** Run `shellcheck -x` and `shfmt -d` over both new files. Expect no output and exit 0 from
each.

**1.8** Run `./tests/fixtures/return-to-town/publish-handoff-test.sh` bare. Expect the final line
`publish-handoff-test: 35 passed, 0 failed` and exit 0. Run it by path, not through `just test`:
the recipe discovers suites from `git ls-files`, so a brand-new file is invisible to it until
staged or committed. `just test publish-handoff` is the check to run after step 1.9's commit.

**1.9** Commit: `feat(return-to-town): compose and verify the hand-off handshake`.

**1.10** Now that the suite is tracked, run `just test publish-handoff` bare. Expect exit 0 and the
same pass line.

### Acceptance criteria

- `publish-handoff` exists, is executable, and passes `shellcheck -x` and `shfmt -d`.
- The suite exists under `tests/fixtures/return-to-town/`, is discovered by
  `just test publish-handoff` once committed, and passes with `35 passed, 0 failed`.
- Each of the nine faults in step 1.6 was observed red and reverted.
- Every row of the design's failure table has a case **except the two the design exempts by name**:
  the non-SHA-from-`ls-remote` guard, and the compose-side assertion that the body carries both
  markers and the handshake. Both are unreachable by any input to this suite, and both are covered
  instead by step 1.6's controlled faults — the second by its first two rows. Any other uncovered
  row is a defect in the suite, not an exemption.

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
- **Contract: the documented invocation resolves the way a consumer's would.** Mode: focused-test.
  The observable contract is that every mention of the helper in `SKILL.md` is plugin-root-qualified
  and that the qualified path names an executable. Command: the script given at step 2.5, run bare
  from the repository root; expected exit 0 with no output. Three expected reds, each observed
  against a real input: `skills/return-to-town/SKILL.md never names the helper` when Task 2 has not
  run, `<file> names the helper without the plugin-root prefix` on a repository-relative call site,
  and a silent `test -x` exit 1 when the qualified path names nothing executable. The check reads
  the document rather than restating the path, which is what lets the second red occur at all.
  This is a structural observation about a path in a fenced command block, not an assertion about
  prose wording, so anatomy rule 4 is not engaged — and it is a one-time task check, not a gate
  added to `just verify`.
- **Contract: the prose replacement itself.** Mode: task-test-not-applicable. The changed surface is
  the hand-off instruction *text* in `skills/return-to-town/SKILL.md` — that it no longer tells a
  reader to compose markers by hand, and that it names the working-directory requirement. No
  executable or structural observation can fail meaningfully on the wording, and anatomy rule 4
  forbids a gate that asserts on prose: no test may check that a document contains a given
  sentence. The structural half of this task is the separate entry above, which can fail.

### Steps

**2.1** In `skills/return-to-town/SKILL.md`, replace the second paragraph of *Record the author
handshake* — the one beginning `**That comment carries the handshake.**` and running to
`it never authorizes a merge.` — with text that: names
`skills/return-to-town/scripts/publish-handoff` as what composes and posts the block; states that
the caller writes the narrative only and must not write either marker or the handshake; states that
the helper reads the SHA from `git ls-remote`, requires GitHub's `headRefOid` to agree, and asserts
both the composed and the stored copy; states the exit taxonomy; and states that a nonzero exit
holds both paths and does not by itself mean nothing was posted, since some conditions are checked
after the comment is created. **State the re-run rule in its bounded form**: a nonzero exit is
re-run *once*, and an identical second failure is deterministic — stop re-running and inspect the
issue. If a complete block is there, proceed from it; if there is none, nothing was posted, so
report the failure and stop. Both halves are needed: the bound reaches the pre-write exits as well,
and at those there is nothing to proceed from. The stored-copy condition that reports a usable
block already on the issue is the named example, not the whole set; a blanket "re-run on nonzero"
instruction sends the caller into an unbounded loop of public comments at every post-write exit.
(Branch review falsified the enumerated form this step originally carried, by constructing a second
such exit, and then caught the pre-write hole the first correction opened. See the specification's
*What this does and does not close*.)

**Also state where the notes file goes.** The step introduces an artifact the prose version never
had, and nothing removes it. Say to write it outside the checkout, in a directory of its own
(`mktemp -d`), and to remove it after exit 0. Two reasons: an untracked file left in the branch's
worktree makes this same skill's `git worktree remove` refuse, and its own prose forbids the
`--force` that would clear it; and a bare `/tmp` is world-writable on a shared host, while the
narrative is read again after two network round trips, so the published bytes would not be the
bytes that were checked. The security pass raised the second against the first draft of this
step, which named `"${TMPDIR:-/tmp}"`.

**Also update the paragraph immediately above it**, which currently reads "post a `WORK:TRAJECTORY`
comment on the issue with `outcome: ...`, guardrail status, and any surprises". Its content list is
exactly what the caller must now put in the notes file, so keep the list and change the verb: the
caller *writes that narrative to a notes file*, and the helper posts it. Left as it is, that
sentence still instructs the reader to post the comment — which is to write the opening marker —
directly above a block telling them to invoke a helper that writes it for them, and Task 2's first
acceptance criterion would be false. Keep the other surrounding paragraphs.

**2.2** Add the invocation, in a fenced `sh` block, immediately after that paragraph. **Resolve the
executable through `$CLAUDE_PLUGIN_ROOT`, not through a repository-relative path.** This project
ships only as a plugin: the harness copies the whole repository into the plugin cache, so at run
time the helper is under the plugin root while the calling agent's working directory must be the
consumer's own checkout — it has to be, because the helper reads the head SHA with `git ls-remote
origin` from there. A repository-relative path does not exist at that working directory; the
command would fail at exec and the hand-off would silently fall back to hand composition, which is
the whole defect this change removes. `skills/quest-log/SKILL.md` states the resolution rule and
`skills/return-to-town/SKILL.md` already follows it about a hundred lines below this edit site.

```sh
"$CLAUDE_PLUGIN_ROOT/skills/return-to-town/scripts/publish-handoff" --preflight <owner/name> <issue> <PR> <notes-file>
"$CLAUDE_PLUGIN_ROOT/skills/return-to-town/scripts/publish-handoff" <owner/name> <issue> <PR> <notes-file>
```

**2.3** In the same step, state the working-directory requirement in prose beside the block: run it
from the checkout whose `origin` is the repository being handed off. The path and the working
directory are two different directories, and naming only one of them is what makes the mistake
easy.

**2.4** Run `./scripts/check-skill-shape.sh` bare. Expect `all rules pass`, exit 0.

**2.5** Run this bare, from the repository root. It reads `SKILL.md` and derives the path from the
document — a check that restates the path instead cannot fail on the defect it exists to catch,
which is exactly how the criterion it replaces went wrong:

```sh
CLAUDE_PLUGIN_ROOT="$PWD" bash -c '
set -euo pipefail
file=skills/return-to-town/SKILL.md
scan() { # pattern -- prints the matching-line count, or faults
	local count status=0
	count=$(grep -cF -- "$1" "$file") || status=$?
	case $status in
	0) printf "%s\n" "$count" ;;
	1) printf "0\n" ;;
	*) printf "could not scan %s (grep exit %s)\n" "$file" "$status" >&2; exit 2 ;;
	esac
}
total=$(scan "skills/return-to-town/scripts/publish-handoff")
rooted=$(scan "\$CLAUDE_PLUGIN_ROOT/skills/return-to-town/scripts/publish-handoff")
[ "$total" -gt 0 ] || { printf "%s never names the helper\n" "$file" >&2; exit 1; }
[ "$total" -eq "$rooted" ] || { printf "%s names the helper without the plugin-root prefix\n" "$file" >&2; exit 1; }
test -x "$CLAUDE_PLUGIN_ROOT/skills/return-to-town/scripts/publish-handoff"
'
```

Two details that are easy to get wrong and were checked by running it. The `\$` in the second
`scan` call is required: the script is handed to `bash -c`, so that inner shell expands an
unescaped `$CLAUDE_PLUGIN_ROOT` and the grep would search for the *expanded* path rather than the
literal text the document must contain. And `grep -c` exits 1 on no matches, so the count is
captured with its status read explicitly — collapsing that would make a scan that could not run
read as a document that does not mention the helper.

Expect exit 0 and no output. Three expected reds, each observed against a real input before this
plan was written:

| Input | Output | Exit |
|---|---|---|
| `SKILL.md` before Task 2 | `skills/return-to-town/SKILL.md never names the helper` | 1 |
| a call site written repository-relative | `<file> names the helper without the plugin-root prefix` | 1 |
| correct call site, helper absent from the plugin root | *(none — `test -x`)* | 1 |

**2.6** Commit: `docs(return-to-town): invoke the hand-off helper`.

### Acceptance criteria

- The composition instructions are gone; nothing in `SKILL.md` still tells a reader to write the
  markers or the handshake by hand.
- **The invocation in `SKILL.md` resolves the executable through `$CLAUDE_PLUGIN_ROOT`, and the
  step names the working-directory requirement separately.** The original criterion here — that the
  path named in `SKILL.md` exists in the tree — was replaced because it could not fail on the defect
  it was meant to catch: a repository-relative path *does* exist in the tree; it just is not where
  the caller runs. Its first replacement could not fail either, for a different reason: it restated
  the path rather than reading the document. The criterion is step 2.5's check exiting 0, and step
  2.5 records the three inputs on which it exits 1.
- `./scripts/check-skill-shape.sh` exits 0.

### Rollback

Revert the single file; Task 1's helper becomes unused but harmless.

## Task 3 — the decision record and the version bump

Creates `docs/adr/0066-compose-the-handoff-handshake.md` and modifies `.claude-plugin/plugin.json`.

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

**3.1** Write `docs/adr/0066-compose-the-handoff-handshake.md` with the five required
sections — `## Status`, `## Context`, `## Decision`, `## Consequences`, `## Considered & rejected` —
a `## Status` body of `Accepted (2026-09-06)`, and an H1 carrying the record's number. Every
`Considered & rejected` bullet names its alternative and opens its ground with `verified:` or
`judgment:`.

**3.2** Do **not** add an index row. `docs/adr/README.md` deliberately carries no index table and
the adr profile warns `W-INDEX-TABLE` if one appears.

**3.3** Link the record from the spec and from this plan's header.

**3.4** Bump `.claude-plugin/plugin.json` `version` to `5.8.0` (from whatever the refreshed base
carries; it was `4.1.2` at the time of writing). `MINOR`, because this
change adds a capability — a new helper — and removes or renames nothing.

**3.5** Run `just records` and `./scripts/check-plugin-version.sh` bare. Expect exit 0 from each.

**3.6** Commit: `docs(adr): record the hand-off handshake composer`.

### Acceptance criteria

- The record carries all five sections and every rejected alternative carries an evidence tag.
- No row was added to `docs/adr/README.md`.
- `.claude-plugin/plugin.json` declares `5.8.0`, and it is strictly greater than the base's.
- `just records` and `./scripts/check-plugin-version.sh` both exit 0.

### Rollback

Remove the record and restore the base's version.

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

**No `deferred-tracked` findings, and no deferral record.** Across the 2026-09-06 design cycle's
three rounds and this cycle's two independent passes, every finding was `accepted-fixed` bar one
`rejected-with-evidence`. `docs/debt/` does not exist in this repository and this change does not
create it — the debt profile exempts no `README.md`, so the directory cannot be added empty, and it
would have to arrive in the same commit as a first deferral record there is no call for.

Any deferral a `$trial-loop` run on this branch disposes of gets appended here with its owning
record path or tracker issue.

### Unowned residuals surfaced, not deferred

These are not deferrals: nothing here is owned, scheduled, or tracked, and this change neither
creates nor widens any of them. They are recorded so the pull request can route them.

1. **`references/merge-gate.md` part 4 points readers at a selection recipe that does not
   discriminate the way part 4's own `jq` does.** The general recipe at
   `skills/quest-log/SKILL.md:523-530` tests only the two markers, so a park note posted after a
   hand-off is what `last` returns there. Both files are read-only in this change. **No owner** —
   #235 was checked and does not cover it, and no other open issue does. See ADR 0066.
2. **The park path keeps the sentinel-omission exposure the hand-off path loses.** It stays prose;
   this change does not touch it. Recorded in ADR 0066's Consequences.
