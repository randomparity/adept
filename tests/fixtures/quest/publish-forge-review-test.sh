#!/usr/bin/env bash
# Behaviour tests for the one-shot forge-review publication helper.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$SCRIPT_DIR/../../../scripts/test-fixture-helpers.sh"

clear_git_env
SCRIPT="$SCRIPT_DIR/../../../skills/quest/scripts/publish-forge-review"
ORIGINAL_PATH=$PATH
SYSTEM_CAT=$(command -v cat)
SYSTEM_TAIL=$(command -v tail)
passed=0
failed=0
fixture_init publish-forge-review-test

ok() {
	passed=$((passed + 1))
	printf '  ok   %s\n' "$1"
}

fail() {
	failed=$((failed + 1))
	printf '  FAIL %s: %s\n' "$1" "$2"
}

write_fakes() {
	local bin=$1
	mkdir -p "$bin"
	cat >"$bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

state=$FAKE_STATE
case $1 in
pr)
	shift
	[ "$1" = comment ] || exit 97
	shift
	body=''
	while [ "$#" -gt 0 ]; do
		case $1 in
		--body-file)
			body=$2
			shift 2
			;;
		*) shift ;;
		esac
	done
	[ -n "$body" ] || exit 96
	printf 'comment-invocation\n' >>"$state/events"
	case ${GH_MODE:-success} in
	comment-fail) exit 1 ;;
	esac
	printf 'post\n' >>"$state/events"
	cp "$body" "$state/comment-body"
	case ${GH_MODE:-success} in
	after-write) exit 1 ;;
	missing-url) printf '\n' ;;
	malformed-url) printf '%s\n' 'https://github.com/wrong/repo/pull/42#issuecomment-nope' ;;
	*) printf '%s\n' 'https://github.com/acme/widgets/pull/42#issuecomment-73' ;;
	esac
	;;
api)
	endpoint=$2
	printf '%s\n' "$endpoint" >"$state/api-path"
	case ${GH_MODE:-success} in
	read-fail) exit 1 ;;
	read-mismatch) jq -n --arg body mismatch '{body: $body}' ;;
	*) jq -n --rawfile body "$state/comment-body" '{body: $body}' ;;
	esac
	;;
*) exit 95 ;;
esac
EOF
	cat >"$bin/cat" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${COMPOSE_SOURCE_FAIL:-}" = summary ]; then
	exit 1
fi
exec "$REAL_CAT" "$@"
EOF
	cat >"$bin/tail" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${TAIL_MODE:-success}" = fail ]; then
	exit 1
fi
exec "$REAL_TAIL" "$@"
EOF
	cat >"$bin/trash" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[ "$1" = -- ] && shift
path=$1
name=$(basename "$path")
if ! grep -q '^review-publication-verified:' "$FAKE_LEDGER"; then
	printf 'trash-before-verified\n' >>"$FAKE_STATE/events"
fi
printf 'trash %s\n' "$name" >>"$FAKE_STATE/events"
if [ "${FAIL_TRASH_ON:-}" = "$name" ]; then
	exit 1
fi
mv "$path" "$FAKE_STATE/trash/$name"
EOF
	chmod +x "$bin/cat" "$bin/gh" "$bin/tail" "$bin/trash"
}

new_case() {
	local repo
	repo=$(cd "$(mktemp -d "$SCRATCH/repo.XXXXXX")" && pwd -P)
	git -C "$repo" init -q
	git -C "$repo" config user.email test@example.com
	git -C "$repo" config user.name Test
	printf '.agent/\n' >"$repo/.gitignore"
	mkdir -p "$repo/.agent/sdd" "$repo/fakes" "$repo/state/trash"
	git -C "$repo" check-ignore -q .agent/sdd/
	write_fakes "$repo/fakes"
	printf 'safe whole-branch review\n' >"$repo/.agent/sdd/review.md"
	printf 'verdict: approve\nfindings: 0\n' >"$repo/.agent/sdd/summary.md"
	printf 'forge review closed\n' >"$repo/.agent/sdd/ledger"
	REPO=$repo
	REVIEW="$repo/.agent/sdd/review.md"
	SUMMARY="$repo/.agent/sdd/summary.md"
	LEDGER="$repo/.agent/sdd/ledger"
	STATE="$repo/state"
	FAKES="$repo/fakes"
}

run_helper() {
	local mode=$1 source=$2
	shift 2
	STATUS=0
	OUTPUT=$(PATH="$FAKES:$ORIGINAL_PATH" \
		FAKE_STATE="$STATE" FAKE_LEDGER="$LEDGER" REAL_CAT="$SYSTEM_CAT" \
		REAL_TAIL="$SYSTEM_TAIL" \
		"$@" "$SCRIPT" acme/widgets 42 "$mode" "$source" "$LEDGER" "$SUMMARY" \
		2>"$REPO/error") || STATUS=$?
}

post_count() {
	if [ -f "$STATE/events" ]; then
		grep -c '^post$' "$STATE/events" || :
	else
		printf '0\n'
	fi
}

comment_invocation_count() {
	if [ -f "$STATE/events" ]; then
		grep -c '^comment-invocation$' "$STATE/events" || :
	else
		printf '0\n'
	fi
}

body_file() {
	local candidate
	for candidate in "$REPO/.agent/sdd"/.publish-forge-review.*; do
		[ -f "$candidate" ] && {
			printf '%s\n' "$candidate"
			return
		}
	done
	return 1
}

assert_retained() {
	local name=$1
	body_file >/dev/null || {
		fail "$name" 'body was not retained'
		return 1
	}
	if [ ! -f "$REVIEW" ] || [ ! -f "$SUMMARY" ]; then
		fail "$name" 'review or summary was not retained'
		return 1
	fi
}

assert_no_post() {
	local name=$1
	if [ "$(post_count)" != 0 ]; then
		fail "$name" 'posted a comment'
		return 1
	fi
}

case_required_safe_review() {
	local name='PFR-1 required review is verified before disposal' expected verified_line
	new_case
	expected="$REPO/expected"
	{
		printf '%s\n' '<!-- WORK:REVIEW -->'
		cat "$SUMMARY"
		printf '\n## Forge whole-branch review\n'
		sed 's/^/    /' "$REVIEW"
		printf '%s\n' '<!-- REVIEW:COMPLETE -->'
	} >"$expected"
	run_helper required "$REVIEW" env GH_MODE=success
	if [ "$STATUS" -ne 0 ]; then
		fail "$name" "exited $STATUS"
		return
	fi
	if [ "$OUTPUT" != 'https://github.com/acme/widgets/pull/42#issuecomment-73' ]; then
		fail "$name" 'stdout was not the verified comment URL'
		return
	fi
	if [ "$(post_count)" != 1 ] ||
		[ "$(cat "$STATE/api-path")" != '/repos/acme/widgets/issues/comments/73' ]; then
		fail "$name" 'did not post and read the exact comment identity once'
		return
	fi
	if ! cmp -s "$expected" "$STATE/comment-body"; then
		fail "$name" 'checked, posted, and read-back bodies differed'
		return
	fi
	verified_line='review-publication-verified: https://github.com/acme/widgets/pull/42'
	verified_line="$verified_line#issuecomment-73"
	if ! grep -qxF "$verified_line" "$LEDGER" ||
		grep -q '^trash-before-verified$' "$STATE/events"; then
		fail "$name" 'disposal was not authorized by the verified ledger line'
		return
	fi
	if [ -e "$REVIEW" ] || [ -e "$SUMMARY" ] || body_file >/dev/null; then
		fail "$name" 'an artifact remained after successful disposal'
		return
	fi
	if [ "$(grep -c '^trash ' "$STATE/events")" != 3 ] ||
		! grep -q '^review-publication-disposed:' "$LEDGER"; then
		fail "$name" 'did not close the disposal lifecycle'
		return
	fi
	ok "$name"
}

case_public_safety_stops_publication() {
	local name='PFR-2 unsafe content and scan faults retain evidence' private_root='/Users'
	new_case
	printf '%s\n' "$private_root/alice/private" >"$REVIEW"
	run_helper required "$REVIEW" env GH_MODE=success
	if [ "$STATUS" -eq 0 ] || ! assert_no_post "$name" || ! assert_retained "$name"; then
		return
	fi
	new_case
	mkdir -p "$REPO/scan-fault"
	printf '%s\n' '#!/usr/bin/env bash' 'exit 2' >"$REPO/scan-fault/rg"
	chmod +x "$REPO/scan-fault/rg"
	run_helper required "$REVIEW" env GH_MODE=success PATH="$REPO/scan-fault:$FAKES:$ORIGINAL_PATH"
	if [ "$STATUS" -eq 0 ] || ! assert_no_post "$name" || ! assert_retained "$name"; then
		return
	fi
	ok "$name"
}

case_compose_source_failure_stops_publication() {
	local name='PFR-8 compose-time source failure retains evidence'
	new_case
	run_helper required "$REVIEW" env GH_MODE=success COMPOSE_SOURCE_FAIL=summary
	if [ "$STATUS" -eq 0 ] || ! assert_no_post "$name" || ! assert_retained "$name" ||
		grep -q 'review-publication-verified\|review-publication-disposed' "$LEDGER"; then
		fail "$name" 'summary copy failure reached publication or disposed evidence'
		return
	fi
	ok "$name"
}

case_publication_modes() {
	local name='PFR-3 both modes and required-review validation'
	new_case
	run_helper not-required 'review was not required after verified scope' env GH_MODE=success
	if [ "$STATUS" -ne 0 ] || [ -e "$SUMMARY" ] ||
		grep -qF 'safe whole-branch review' "$STATE/comment-body" ||
		! grep -qF 'review was not required after verified scope' "$STATE/comment-body"; then
		fail "$name" 'not-required mode did not publish the summary-only result'
		return
	fi
	new_case
	run_helper required "$REPO/no-such-review" env GH_MODE=success
	if [ "$STATUS" -eq 0 ] || ! assert_no_post "$name"; then
		return
	fi
	: >"$REVIEW"
	run_helper required "$REVIEW" env GH_MODE=success
	if [ "$STATUS" -eq 0 ] || ! assert_no_post "$name"; then
		return
	fi
	ok "$name"
}

case_comment_failures_never_retry() {
	local name='PFR-4 comment failure and ambiguity never retry'
	local mode
	new_case
	run_helper required "$REVIEW" env GH_MODE=comment-fail
	if [ "$STATUS" -eq 0 ] || [ "$(comment_invocation_count)" != 1 ] ||
		[ "$(post_count)" != 0 ] || [ -e "$STATE/comment-body" ] ||
		! assert_retained "$name"; then
		fail "$name" 'pre-write comment failure did not retain evidence without writing'
		return
	fi
	for mode in missing-url malformed-url after-write; do
		new_case
		run_helper required "$REVIEW" env GH_MODE="$mode"
		if [ "$STATUS" -eq 0 ] || [ "$(post_count)" != 1 ] || ! assert_retained "$name"; then
			return
		fi
	done
	ok "$name"
}

case_readback_rejects_unverified_comments() {
	local name='PFR-5 failed or mismatched readback retains all evidence'
	local mode
	for mode in read-fail read-mismatch; do
		new_case
		run_helper required "$REVIEW" env GH_MODE="$mode"
		if [ "$STATUS" -eq 0 ] || ! assert_retained "$name" ||
			grep -q 'review-publication-verified\|review-publication-disposed' "$LEDGER"; then
			fail "$name" 'claimed verified publication after a bad readback'
			return
		fi
	done
	ok "$name"
}

case_ledger_and_disposal_failures_retain_paths() {
	local name='PFR-6 ledger and partial disposal failures retain exact evidence'
	new_case
	rm "$LEDGER"
	mkdir "$LEDGER"
	run_helper required "$REVIEW" env GH_MODE=success
	if [ "$STATUS" -eq 0 ] || ! assert_retained "$name" ||
		! grep -qF 'https://github.com/acme/widgets/pull/42#issuecomment-73' "$REPO/error"; then
		fail "$name" 'ledger failure did not retain the verified comment identity'
		return
	fi
	new_case
	run_helper required "$REVIEW" env GH_MODE=success TAIL_MODE=fail
	if [ "$STATUS" -eq 0 ] || ! assert_retained "$name" ||
		! grep -q '^review-publication-verified:' "$LEDGER" ||
		grep -q '^review-publication-disposed:' "$LEDGER" ||
		! grep -qF 'https://github.com/acme/widgets/pull/42#issuecomment-73' "$REPO/error"; then
		fail "$name" 'ledger readback failure did not retain verified publication evidence'
		return
	fi
	new_case
	run_helper required "$REVIEW" env GH_MODE=success FAIL_TRASH_ON=summary.md
	if [ "$STATUS" -eq 0 ] || [ -e "$REVIEW" ] || [ ! -f "$SUMMARY" ] ||
		! body_file >/dev/null || ! grep -q 'review-publication-verified' "$LEDGER" ||
		grep -q 'review-publication-disposed' "$LEDGER" ||
		! grep -qF "$SUMMARY" "$REPO/error" || ! grep -qF "$(body_file)" "$REPO/error"; then
		fail "$name" 'partial disposal did not retain and report the remaining paths'
		return
	fi
	ok "$name"
}

case_markers_stay_payload_and_summary_markers_fail() {
	local name='PFR-7 markers are payload while summary markers are rejected'
	local marker
	new_case
	printf '%s\n' '<!-- WORK:REVIEW -->' '<!-- REVIEW:COMPLETE -->' 'verdict: approve' >"$REVIEW"
	run_helper required "$REVIEW" env GH_MODE=success
	if [ "$STATUS" -ne 0 ] || [ "$(grep -c '^<!-- WORK:REVIEW -->$' "$STATE/comment-body")" != 1 ] ||
		[ "$(grep -c '^<!-- REVIEW:COMPLETE -->$' "$STATE/comment-body")" != 1 ] ||
		! grep -qxF '    <!-- WORK:REVIEW -->' "$STATE/comment-body" ||
		! grep -qxF '    <!-- REVIEW:COMPLETE -->' "$STATE/comment-body" ||
		! grep -qxF '    verdict: approve' "$STATE/comment-body"; then
		fail "$name" 'marker-like review content escaped its indented payload'
		return
	fi
	for marker in '<!-- WORK:REVIEW -->' '<!-- REVIEW:COMPLETE -->'; do
		new_case
		printf '%s\n' "$marker" >"$SUMMARY"
		run_helper required "$REVIEW" env GH_MODE=success
		if [ "$STATUS" -eq 0 ] || ! assert_no_post "$name" || [ -e "$(body_file 2>/dev/null || :)" ]; then
			fail "$name" 'summary marker reached GitHub or created a body'
			return
		fi
	done
	for marker in '<!-- WORK:REVIEW -->' '<!-- REVIEW:COMPLETE -->'; do
		new_case
		printf '%s\r\n' "$marker" >"$SUMMARY"
		run_helper required "$REVIEW" env GH_MODE=success
		if [ "$STATUS" -eq 0 ] || ! assert_no_post "$name" || [ -e "$(body_file 2>/dev/null || :)" ] ||
			[ ! -f "$REVIEW" ] || [ ! -f "$SUMMARY" ]; then
			fail "$name" 'CRLF summary marker reached GitHub or disposed evidence'
			return
		fi
	done
	ok "$name"
}

printf 'publish-forge-review\n\n'
case_required_safe_review
case_public_safety_stops_publication
case_compose_source_failure_stops_publication
case_publication_modes
case_comment_failures_never_retry
case_readback_rejects_unverified_comments
case_ledger_and_disposal_failures_retain_paths
case_markers_stay_payload_and_summary_markers_fail

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
