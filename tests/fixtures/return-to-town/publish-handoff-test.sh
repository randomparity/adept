#!/usr/bin/env bash
# Behaviour tests for the merge hand-off publication helper.
#
# `gh` is faked on PATH and driven by GH_MODE. `git` is not faked: the SHA the
# whole contract turns on is what `git ls-remote` returns, so the fixture builds
# a real repository with a real bare remote and the helper reads it for real.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$SCRIPT_DIR/../../../scripts/test-fixture-helpers.sh"

clear_git_env
SCRIPT="$SCRIPT_DIR/../../../skills/return-to-town/scripts/publish-handoff"
ORIGINAL_PATH=$PATH
REPO=acme/widgets
ISSUE=308
PR=42
BRANCH=feat/publish-handoff-308
MARKER='<!-- WORK:TRAJECTORY -->'
SENTINEL='<!-- TRAJECTORY:COMPLETE -->'
passed=0
failed=0
fixture_init publish-handoff-test

ok() {
	passed=$((passed + 1))
	printf '  ok   %s\n' "$1"
}

fail_case() {
	failed=$((failed + 1))
	printf '  FAIL %s: %s\n' "$1" "$2"
}

write_fake_gh() {
	local bin=$1
	mkdir -p "$bin"
	cat >"$bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

state=$FAKE_STATE
case $1 in
pr)
	shift
	[ "$1" = view ] || exit 97
	shift
	number=$1
	shift
	pr_repo=''
	while [ "$#" -gt 0 ]; do
		case $1 in
		--repo)
			pr_repo=$2
			shift 2
			;;
		*) shift ;;
		esac
	done
	printf '%s\n' "$pr_repo" >"$state/pr-repo"
	printf 'pr-view\n' >>"$state/events"
	case ${GH_MODE:-success} in
	pr-view-fail) exit 1 ;;
	esac
	jq -n \
		--argjson number "${FAKE_PR_NUMBER:-$number}" \
		--arg state "${FAKE_PR_STATE:-OPEN}" \
		--arg branch "$FAKE_BRANCH" \
		--arg oid "$(cat "$state/head-ref-oid")" \
		--argjson cross "${FAKE_CROSS:-false}" \
		--argjson closes "${FAKE_CLOSES:-[]}" \
		'{number: $number, state: $state, headRefName: $branch,
		  headRefOid: $oid, isCrossRepository: $cross,
		  closingIssuesReferences: $closes}'
	;;
issue)
	shift
	[ "$1" = comment ] || exit 96
	shift
	issue_number=$1
	shift
	body=''
	issue_repo=''
	while [ "$#" -gt 0 ]; do
		case $1 in
		--repo)
			issue_repo=$2
			shift 2
			;;
		--body-file)
			body=$2
			shift 2
			;;
		*) shift ;;
		esac
	done
	[ -n "$body" ] || exit 95
	printf '%s\n' "$issue_repo" >"$state/issue-repo"
	printf '%s\n' "$issue_number" >"$state/issue-number"
	# Real gh accepts a host-qualified --repo and still returns a plain
	# https://github.com/<owner>/<name>/... URL, so the fake must not echo the
	# host prefix back into the path. It also canonicalizes owner/name rather
	# than echoing the case it was given, which FAKE_CANONICAL_REPO reproduces.
	url_repo=${FAKE_CANONICAL_REPO:-${issue_repo#github.com/}}
	printf 'comment-invocation\n' >>"$state/events"
	case ${GH_MODE:-success} in
	comment-fail) exit 1 ;;
	esac
	printf 'post\n' >>"$state/events"
	cp "$body" "$state/comment-body"
	case ${GH_MODE:-success} in
	no-url) printf '\n' ;;
	two-urls) printf 'one\ntwo\n' ;;
	foreign-url) printf '%s\n' 'https://github.com/other/repo/issues/9#issuecomment-73' ;;
	nonnumeric-url) printf '%s\n' "https://github.com/$url_repo/issues/$issue_number#issuecomment-nope" ;;
	*) printf '%s\n' "https://github.com/$url_repo/issues/$issue_number#issuecomment-73" ;;
	esac
	;;
api)
	shift
	endpoint=''
	while [ "$#" -gt 0 ]; do
		case $1 in
		--hostname) shift 2 ;;
		*)
			endpoint=$1
			shift
			;;
		esac
	done
	printf '%s\n' "$endpoint" >"$state/api-path"
	# Two endpoints share this arm and differ only in the segment after
	# `issues`, so dispatch on the path shape. A prefix match would answer the
	# readback with an issue object.
	case $endpoint in
	*/issues/comments/*) ;;
	*/issues/*)
		printf 'issue-read\n' >>"$state/events"
		case ${FAKE_ISSUE_MODE:-present} in
		absent) exit 1 ;;
		esac
		want=${endpoint##*/}
		# The canonical issue URL, which the helper uses to build the comment-URL
		# prefix. Derived from the endpoint, then overridden by
		# FAKE_CANONICAL_REPO exactly as GitHub overrides the requested case.
		path_repo=${endpoint#/repos/}
		path_repo=${path_repo%%/issues/*}
		issue_url="https://github.com/${FAKE_CANONICAL_REPO:-$path_repo}/issues/$want"
		case ${FAKE_ISSUE_MODE:-present} in
		mismatch) jq -n --argjson n "$((want + 1))" --arg u "$issue_url" '{number: $n, html_url: $u}' ;;
		pull) jq -n --argjson n "$want" --arg u "$issue_url" '{number: $n, html_url: $u, pull_request: {url: "x"}}' ;;
		no-url) jq -n --argjson n "$want" '{number: $n}' ;;
		*) jq -n --argjson n "$want" --arg u "$issue_url" '{number: $n, html_url: $u}' ;;
		esac
		exit 0
		;;
	esac
	printf 'api\n' >>"$state/events"
	case ${GH_MODE:-success} in
	read-fail) exit 1 ;;
	drop-sentinel) grep -vxF -- '<!-- TRAJECTORY:COMPLETE -->' "$state/comment-body" >"$state/served" ;;
	drop-marker) grep -vxF -- '<!-- WORK:TRAJECTORY -->' "$state/comment-body" >"$state/served" ;;
	drop-handshake) grep -v '^MERGE-READY:' "$state/comment-body" >"$state/served" ;;
	add-cr) sed 's/$/\r/' "$state/comment-body" >"$state/served" ;;
	mangle-body) printf 'something else entirely\n' >"$state/served" ;;
	*) cp "$state/comment-body" "$state/served" ;;
	esac
	jq -n --rawfile body "$state/served" '{body: $body}'
	;;
*) exit 94 ;;
esac
EOF
	chmod +x "$bin/gh"
}

# One fixture per case, so no case can observe another's leftovers.
new_case() { # -- sets CASE, WORK, STATE, BIN, NOTES, HEAD_SHA
	local root
	fixture_scratch "$SCRATCH/case."
	root=$FIXTURE_SCRATCH
	CASE=$root
	WORK="$root/work"
	STATE="$root/state"
	BIN="$root/bin"
	NOTES="$root/notes.md"
	mkdir -p "$STATE"
	write_fake_gh "$BIN"
	git init --quiet --bare "$root/origin.git"
	git init --quiet "$WORK"
	printf 'seed\n' >"$WORK/file.txt"
	git -C "$WORK" add file.txt
	git -C "$WORK" -c user.email=t@example.invalid -c user.name=Test \
		commit --quiet -m 'seed'
	git -C "$WORK" remote add origin "$root/origin.git"
	git -C "$WORK" push --quiet origin "HEAD:refs/heads/$BRANCH"
	HEAD_SHA=$(git -C "$WORK" rev-parse HEAD)
	printf '%s\n' "$HEAD_SHA" >"$STATE/head-ref-oid"
	printf 'outcome: handed off - PR #%s green+mergeable, awaiting human merge\nguardrails: just verify passed\n' \
		"$PR" >"$NOTES"
}

run_helper() { # [args...] -- sets RUN_STATUS, RUN_OUT, RUN_ERR
	local closes
	# Built here, not in a ${VAR:-default}: a literal `}` inside such a default
	# closes the expansion early and the JSON reaches jq as `[{"number": 308]}`,
	# which fakes a failure that has nothing to do with the helper.
	closes=${FAKE_CLOSES:-}
	if [ -z "$closes" ]; then
		closes=$(printf '[{"number": %s}]' "$ISSUE")
	fi
	RUN_STATUS=0
	set +e
	(
		cd "$WORK" || exit 90
		# Exported deliberately, and only by the case that tests it: git's
		# local env vars outrank the working directory, which is the whole
		# point of case_stray_git_env_is_cleared.
		if [ -n "${STRAY_GIT_DIR:-}" ]; then
			export GIT_DIR="$STRAY_GIT_DIR"
		fi
		PATH="$BIN:$ORIGINAL_PATH" \
			FAKE_STATE=$STATE FAKE_BRANCH=${FAKE_BRANCH:-$BRANCH} \
			FAKE_CROSS=${FAKE_CROSS:-false} \
			FAKE_CLOSES="$closes" \
			FAKE_ISSUE_MODE="${FAKE_ISSUE_MODE:-present}" \
			FAKE_CANONICAL_REPO="${FAKE_CANONICAL_REPO:-}" \
			"$SCRIPT" "$@"
	) >"$CASE/out" 2>"$CASE/err"
	RUN_STATUS=$?
	set -e
	RUN_OUT=$(cat "$CASE/out")
	RUN_ERR=$(cat "$CASE/err")
}

expect_status() { # label expected
	if [ "$RUN_STATUS" -eq "$2" ]; then
		return 0
	fi
	fail_case "$1" "expected exit $2, got $RUN_STATUS (stderr: $RUN_ERR)"
	return 1
}

expect_stderr() { # label substring
	case $RUN_ERR in
	*"$2"*) return 0 ;;
	esac
	fail_case "$1" "stderr did not mention '$2' (stderr: $RUN_ERR)"
	return 1
}

# --- argument and notes validation -----------------------------------------

case_usage() {
	local label='no arguments is a fault, not a finding'
	new_case
	run_helper
	expect_status "$label" 2 || return 0
	expect_stderr "$label" 'usage: publish-handoff' || return 0
	ok "$label"
}

case_bad_repo() {
	local label='a repository that is not owner/name is rejected'
	new_case
	run_helper acme "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'repository is invalid' || return 0
	run_helper a/b/c "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	run_helper 'acme/wid gets' "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	ok "$label"
}

case_bad_numbers() {
	local label='a non-positive issue or pull request number is rejected'
	new_case
	run_helper "$REPO" 0 "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'issue number is invalid' || return 0
	run_helper "$REPO" "$ISSUE" 4x "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'pull request number is invalid' || return 0
	ok "$label"
}

case_notes_unreadable() {
	local label='missing, empty, and non-regular notes are rejected'
	new_case
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/absent.md"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'not a readable regular file' || return 0
	: >"$CASE/empty.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/empty.md"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'hand-off notes are empty' || return 0
	ln -s "$NOTES" "$CASE/link.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/link.md"
	expect_status "$label" 1 || return 0
	ok "$label"
}

case_notes_bytes() {
	local label='notes carrying NUL, CR, or non-UTF-8 are rejected'
	new_case
	printf 'outcome: fine\0more\n' >"$CASE/nul.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/nul.md"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'NUL byte' || return 0
	printf 'outcome: fine\r\n' >"$CASE/cr.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/cr.md"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'carriage return' || return 0
	printf 'outcome: \377\376 bad\n' >"$CASE/latin.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/latin.md"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'not UTF-8 text' || return 0
	ok "$label"
}

case_notes_too_large() {
	local label='notes over the size cap are rejected before anything is posted'
	new_case
	awk 'BEGIN { for (i = 0; i < 900; i += 1) print "0123456789" }' >"$CASE/big.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/big.md"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'over the 8192-byte limit' || return 0
	[ ! -f "$STATE/events" ] || {
		fail_case "$label" 'the helper called gh before rejecting oversized notes'
		return 0
	}
	ok "$label"
}

case_notes_carry_markers() {
	local label='notes carrying either annotation marker are rejected'
	new_case
	printf 'outcome: fine\n%s\n' "$MARKER" >"$CASE/marker.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/marker.md"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'this script writes both markers' || return 0
	printf 'outcome: fine\n%s\n' "$SENTINEL" >"$CASE/sentinel.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/sentinel.md"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'this script writes both markers' || return 0
	ok "$label"
}

# Issue #308 defect 1: the handshake was wrapped in backticks, which no
# line-anchored pattern sees. The substring check is what closes it.
case_notes_carry_handshake() {
	local label='regression: a backticked handshake in the notes is rejected'
	new_case
	# shellcheck disable=SC2016 # the backticks are the defect under test, not a substitution
	printf 'outcome: fine\n`MERGE-READY: #%s @ %s`\n' "$PR" "$HEAD_SHA" >"$CASE/tick.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/tick.md"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'this script composes that line itself' || return 0
	printf 'outcome: fine\nMERGE-READY: #%s @ %s\n' "$PR" "$HEAD_SHA" >"$CASE/bare.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/bare.md"
	expect_status "$label" 1 || return 0
	ok "$label"
}

case_notes_unsafe() {
	local label='a body failing public-safety is rejected before posting'
	new_case
	# Split literal, as scripts/check-public-safety-test.sh does throughout: a
	# denied pattern written whole would make this suite trip the very gate it
	# is checking the helper calls.
	printf 'outcome: fine\nworktree: /Us%s/example-user/src/adept\n' 'ers' \
		>"$CASE/unsafe.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/unsafe.md"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'public-safety validation' || return 0
	case $(cat "$STATE/events" 2>/dev/null || true) in
	*post*)
		fail_case "$label" 'the helper posted a body that failed public-safety'
		return 0
		;;
	esac
	ok "$label"
}

# A fork's head branch is never under the local origin's refs/heads/, so without
# this check the case surfaces later as "the branch moved" -- a permanent refusal
# wearing a transient message, whose stated remedy is to re-run forever.
case_fork_pr() {
	local label='a pull request whose head is in a fork is rejected, naming the fork'
	new_case
	FAKE_CROSS=true run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'lives in a fork' || return 0
	case $(cat "$STATE/events" 2>/dev/null || true) in
	*post*)
		fail_case "$label" 'the helper posted for a fork pull request'
		return 0
		;;
	esac
	ok "$label"
}

# The public-safety gate exits 0 clean, 1 on a finding, 2 when it could not run.
# Collapsing 2 into the finding branch would report a scanner that never ran as
# one that found a credential -- and re-running, the remedy given for every other
# exit 1, would never clear it.
case_public_safety_fault() {
	local label='a public-safety scan that could not run is a fault, not a finding'
	new_case
	printf '#!/usr/bin/env bash\nexit 2\n' >"$BIN/rg"
	chmod +x "$BIN/rg"
	run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 2 || return 0
	expect_stderr "$label" 'public-safety scan could not run' || return 0
	case $(cat "$STATE/events" 2>/dev/null || true) in
	*post*)
		fail_case "$label" 'the helper posted after a scan it could not run'
		return 0
		;;
	esac
	ok "$label"
}

# --- head resolution --------------------------------------------------------

case_pr_not_open() {
	local label='a pull request that is not OPEN is rejected'
	new_case
	FAKE_PR_STATE=CLOSED run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'is CLOSED, not OPEN' || return 0
	ok "$label"
}

case_pr_number_mismatch() {
	local label='a pull request reporting another number is rejected'
	new_case
	FAKE_PR_NUMBER=99 run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'reported number 99' || return 0
	ok "$label"
}

case_branch_absent() {
	local label='a head branch absent from origin is rejected'
	new_case
	git -C "$WORK" push --quiet origin ":refs/heads/$BRANCH"
	run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'has no refs/heads/' || return 0
	ok "$label"
}

# A branch name is passed to `git ls-remote` as a ref pattern, and git globs
# patterns. GitHub will not return a headRefName containing `*`, so this guard
# is defence on the parse of an external response rather than a reachable path
# -- but it is testable, because the fake controls the name.
case_multiple_refs() {
	local label='a head branch matching several refs is rejected'
	new_case
	git -C "$WORK" push --quiet origin 'HEAD:refs/heads/feat/other-308'
	FAKE_BRANCH='feat/*' run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'expected exactly one' || return 0
	ok "$label"
}

case_head_disagrees() {
	local label='a headRefOid disagreeing with the remote tip is rejected'
	new_case
	printf '%s\n' 0000000000000000000000000000000000000000 >"$STATE/head-ref-oid"
	run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'the branch moved' || return 0
	expect_stderr "$label" "$HEAD_SHA" || return 0
	ok "$label"
}

# --- preflight --------------------------------------------------------------

case_preflight() {
	local label='preflight validates and composes without posting'
	new_case
	run_helper --preflight "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 0 || return 0
	[ "$RUN_OUT" = preflight-ok ] || {
		fail_case "$label" "stdout was '$RUN_OUT', expected preflight-ok"
		return 0
	}
	case $(cat "$STATE/events" 2>/dev/null || true) in
	*post*)
		fail_case "$label" 'preflight posted a comment'
		return 0
		;;
	esac
	ok "$label"
}

# --- the published block ----------------------------------------------------

case_publishes_the_required_shape() {
	local label='the posted body carries both markers and a bare handshake line'
	local expected first last
	new_case
	run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 0 || return 0
	[ "$RUN_OUT" = "https://github.com/$REPO/issues/$ISSUE#issuecomment-73" ] || {
		fail_case "$label" "stdout was '$RUN_OUT', expected the verified comment URL"
		return 0
	}
	expected="MERGE-READY: #$PR @ $HEAD_SHA"
	grep -qxF -- "$expected" "$STATE/comment-body" || {
		fail_case "$label" "the posted body carries no whole line '$expected'"
		return 0
	}
	first=$(head -n 1 "$STATE/comment-body")
	[ "$first" = "$MARKER" ] || {
		fail_case "$label" "the posted body opens with '$first', not the marker"
		return 0
	}
	last=$(tail -n 1 "$STATE/comment-body")
	[ "$last" = "$SENTINEL" ] || {
		fail_case "$label" "the posted body ends with '$last', not the sentinel"
		return 0
	}
	if LC_ALL=C od -An -v -t x1 "$STATE/comment-body" | grep -q ' 0d'; then
		fail_case "$label" 'the posted body contains a carriage return'
		return 0
	fi
	grep -qF -- 'outcome: handed off' "$STATE/comment-body" || {
		fail_case "$label" 'the posted body dropped the narrative'
		return 0
	}
	[ "$(cat "$STATE/issue-number")" = "$ISSUE" ] || {
		fail_case "$label" 'the comment was posted on the wrong issue'
		return 0
	}
	ok "$label"
}

case_notes_without_trailing_newline() {
	local label='notes with no trailing newline still yield a bare handshake line'
	new_case
	printf 'outcome: handed off' >"$CASE/nonl.md"
	run_helper "$REPO" "$ISSUE" "$PR" "$CASE/nonl.md"
	expect_status "$label" 0 || return 0
	grep -qxF -- "MERGE-READY: #$PR @ $HEAD_SHA" "$STATE/comment-body" || {
		fail_case "$label" 'the handshake was joined to the narrative'
		return 0
	}
	ok "$label"
}

# --- readback assertions ----------------------------------------------------

# Issue #308 defects 2 and 3: the sentinel was never emitted, twice, and nothing
# noticed. The readback is what notices.
case_stored_missing_sentinel() {
	local label='regression: a stored copy without the sentinel fails, naming it'
	new_case
	GH_MODE=drop-sentinel run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'missing the closing sentinel' || return 0
	expect_stderr "$label" "$SENTINEL" || return 0
	ok "$label"
}

case_stored_missing_marker() {
	local label='a stored copy without the opening marker fails, naming it'
	new_case
	GH_MODE=drop-marker run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'missing the opening marker' || return 0
	ok "$label"
}

case_stored_missing_handshake() {
	local label='a stored copy without the handshake fails, quoting the line'
	new_case
	GH_MODE=drop-handshake run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" "missing the handshake on its own line: MERGE-READY: #$PR @ $HEAD_SHA" ||
		return 0
	ok "$label"
}

case_stored_carries_cr() {
	local label='a stored copy carrying a carriage return fails, naming it'
	new_case
	GH_MODE=add-cr run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'carriage return' || return 0
	ok "$label"
}

case_stored_differs() {
	local label='a stored copy differing from the composed body fails'
	new_case
	GH_MODE=mangle-body run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	ok "$label"
}

# --- GitHub transport -------------------------------------------------------

case_comment_creation_fails() {
	local label='a failed comment creation is reported, not assumed posted'
	new_case
	GH_MODE=comment-fail run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'was not created' || return 0
	ok "$label"
}

case_readback_fails() {
	local label='a failed readback is reported rather than passing on trust'
	new_case
	GH_MODE=read-fail run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'could not be read back' || return 0
	ok "$label"
}

case_bad_comment_url() {
	local label='a comment URL naming another target or no id is rejected'
	new_case
	GH_MODE=foreign-url run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'does not name' || return 0
	GH_MODE=nonnumeric-url run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'no numeric comment id' || return 0
	GH_MODE=no-url run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'no usable comment URL' || return 0
	GH_MODE=two-urls run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	ok "$label"
}

case_pr_view_fails() {
	local label='a pull request that cannot be read is a fault, not a finding'
	new_case
	GH_MODE=pr-view-fail run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 2 || return 0
	expect_stderr "$label" 'could not be read' || return 0
	ok "$label"
}

# The minimal PATH carries bash alone: `#!/usr/bin/env bash` resolves the
# interpreter through PATH too, so an empty one fails at exec with 127 and never
# reaches the check under test.
case_missing_command() {
	local label='a missing required command is a fault naming the command'
	local minimal
	new_case
	minimal="$CASE/minbin"
	mkdir -p "$minimal"
	ln -s "$(command -v bash)" "$minimal/bash"
	RUN_STATUS=0
	set +e
	(
		cd "$WORK" || exit 90
		PATH="$minimal" FAKE_STATE=$STATE FAKE_BRANCH=$BRANCH \
			"$SCRIPT" "$REPO" "$ISSUE" "$PR" "$NOTES"
	) >"$CASE/out" 2>"$CASE/err"
	RUN_STATUS=$?
	set -e
	RUN_ERR=$(cat "$CASE/err")
	expect_status "$label" 2 || return 0
	expect_stderr "$label" 'required command is unavailable' || return 0
	ok "$label"
}

# Issue #308 defect 4: a worker died mid-hand-off. The helper cannot resurrect
# it; what it guarantees is that the successor's remedy is simply to run again,
# because every run appends a fresh complete block and latest-complete-wins.
case_rerun_is_safe() {
	local label='regression: re-running after an unverified attempt posts a fresh complete block'
	new_case
	GH_MODE=read-fail run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 0 || return 0
	grep -qxF -- "$MARKER" "$STATE/comment-body" || {
		fail_case "$label" 'the second attempt did not post a complete block'
		return 0
	}
	grep -qxF -- "$SENTINEL" "$STATE/comment-body" || {
		fail_case "$label" 'the second attempt did not post a complete block'
		return 0
	}
	grep -qxF -- "MERGE-READY: #$PR @ $HEAD_SHA" "$STATE/comment-body" || {
		fail_case "$label" 'the second attempt did not post the handshake'
		return 0
	}
	ok "$label"
}

# The transposition case, and the one the whole destination binding exists for.
# Every other check in resolve_destination passes here: the issue is real, open,
# not a pull request, and reports the number asked for. Only the pull request's
# own statement of what it closes disagrees.
case_issue_not_closed_by_pr() {
	local label='an ISSUE the pull request does not close is refused, naming both'
	new_case
	FAKE_CLOSES='[{"number": 999}]' run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" '999' || return 0
	expect_stderr "$label" "$ISSUE" || return 0
	case $(cat "$STATE/events" 2>/dev/null || true) in
	*post*)
		fail_case "$label" 'the helper posted to an issue the pull request does not close'
		return 0
		;;
	esac
	ok "$label"
}

case_pr_no_closing_issue() {
	local label='a pull request declaring no closing issue is refused as uncorroborated'
	new_case
	FAKE_CLOSES='[]' run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'Closes #' || return 0
	case $(cat "$STATE/events" 2>/dev/null || true) in
	*post*)
		fail_case "$label" 'the helper posted without corroborating the destination'
		return 0
		;;
	esac
	ok "$label"
}

case_issue_not_corroborated() {
	local label='an unreadable destination is a fault and a mismatched one is a finding'
	new_case
	FAKE_ISSUE_MODE=absent run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 2 || return 0
	expect_stderr "$label" 'could not be read' || return 0
	case $(cat "$STATE/events" 2>/dev/null || true) in
	*post*)
		fail_case "$label" 'the helper posted to an unreadable destination'
		return 0
		;;
	esac
	new_case
	FAKE_ISSUE_MODE=mismatch run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'not 308' || return 0
	case $(cat "$STATE/events" 2>/dev/null || true) in
	*post*)
		fail_case "$label" 'the helper posted to a mismatched destination'
		return 0
		;;
	esac
	ok "$label"
}

case_issue_is_pull_request() {
	local label='an ISSUE naming a pull request is refused before anything is posted'
	new_case
	FAKE_ISSUE_MODE=pull run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 1 || return 0
	expect_stderr "$label" 'is a pull request, not an issue' || return 0
	case $(cat "$STATE/events" 2>/dev/null || true) in
	*post*)
		fail_case "$label" 'the helper posted to a pull request'
		return 0
		;;
	esac
	ok "$label"
}

# Asserts the right answer rather than a refusal: the failure this guards is a
# silent wrong SHA, not an error. A second repository with a different commit on
# the same branch name is what GIT_DIR points at.
case_stray_git_env_is_cleared() {
	local label='the head SHA is read from the checkout own origin, not from GIT_DIR'
	local decoy decoy_sha posted
	new_case
	decoy="$CASE/decoy"
	git init --quiet "$decoy"
	printf 'decoy\n' >"$decoy/file.txt"
	git -C "$decoy" add file.txt
	git -C "$decoy" -c user.email=t@example.invalid -c user.name=Test \
		commit --quiet -m 'decoy'
	git init --quiet --bare "$CASE/decoy-origin.git"
	git -C "$decoy" remote add origin "$CASE/decoy-origin.git"
	git -C "$decoy" push --quiet origin "HEAD:refs/heads/$BRANCH"
	decoy_sha=$(git -C "$decoy" rev-parse HEAD)
	if [ "$decoy_sha" = "$HEAD_SHA" ]; then
		fail_case "$label" 'the decoy repository produced the same SHA, so the case proves nothing'
		return 0
	fi
	STRAY_GIT_DIR="$decoy/.git" run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 0 || return 0
	posted=$(grep '^MERGE-READY:' "$STATE/comment-body" 2>/dev/null || true)
	case $posted in
	*"$HEAD_SHA"*) ok "$label" ;;
	*"$decoy_sha"*)
		fail_case "$label" 'the handshake carried the SHA from the repository GIT_DIR named'
		;;
	*) fail_case "$label" "no usable handshake was posted (got: $posted)" ;;
	esac
}

# GitHub canonicalizes owner/name in every URL it returns, so the URL of a
# comment the helper just created does not carry the case the caller supplied.
# Deriving the expected prefix from the REPO argument turns that into an exit 1
# on a hand-off that was in fact published -- a success reported as a failure,
# whose documented remedy is to re-run and post another one.
case_repo_case_variant_is_canonicalized() {
	local label='a case-variant REPO still verifies against the canonical comment URL'
	local variant
	new_case
	variant=$(printf '%s' "$REPO" | tr '[:lower:]' '[:upper:]')
	FAKE_CANONICAL_REPO="$REPO" run_helper "$variant" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 0 || return 0
	[ "$RUN_OUT" = "https://github.com/$REPO/issues/$ISSUE#issuecomment-73" ] || {
		fail_case "$label" "expected the canonical comment URL, got: $RUN_OUT"
		return 0
	}
	ok "$label"
}

# The prefix now comes from the destination response, so a response without one
# is a fault rather than a silently empty prefix that matches any URL.
case_destination_url_missing() {
	local label='a destination response carrying no html_url is a fault'
	new_case
	FAKE_ISSUE_MODE=no-url run_helper "$REPO" "$ISSUE" "$PR" "$NOTES"
	expect_status "$label" 2 || return 0
	expect_stderr "$label" 'canonical URL' || return 0
	case $(cat "$STATE/events" 2>/dev/null || true) in
	*post*)
		fail_case "$label" 'the helper posted despite an unusable destination response'
		return 0
		;;
	esac
	ok "$label"
}

case_usage
case_bad_repo
case_bad_numbers
case_notes_unreadable
case_notes_bytes
case_notes_too_large
case_notes_carry_markers
case_notes_carry_handshake
case_notes_unsafe
case_fork_pr
case_public_safety_fault
case_pr_not_open
case_pr_number_mismatch
case_branch_absent
case_multiple_refs
case_head_disagrees
case_preflight
case_publishes_the_required_shape
case_notes_without_trailing_newline
case_stored_missing_sentinel
case_stored_missing_marker
case_stored_missing_handshake
case_stored_carries_cr
case_stored_differs
case_comment_creation_fails
case_readback_fails
case_bad_comment_url
case_pr_view_fails
case_missing_command
case_rerun_is_safe
case_issue_not_closed_by_pr
case_pr_no_closing_issue
case_issue_not_corroborated
case_issue_is_pull_request
case_stray_git_env_is_cleared
case_repo_case_variant_is_canonicalized
case_destination_url_missing

printf 'publish-handoff-test: %s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
