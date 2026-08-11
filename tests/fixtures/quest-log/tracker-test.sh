#!/usr/bin/env bash
set -euo pipefail

# ripgrep applies RIPGREP_CONFIG_PATH's contents as arguments ahead of the ones
# passed below, so a personal ripgreprc would otherwise steer this suite's own
# assertions -- including the ones that count recorded `gh` calls.
unset RIPGREP_CONFIG_PATH

# Hooks export repository-local Git variables that override `git -C`. Clear
# Git's complete reported set before any fixture repository is discovered.
while IFS= read -r variable; do
	[ -n "$variable" ] || continue
	unset "$variable"
done < <(git rev-parse --local-env-vars)

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source_dir=$(cd -- "$script_dir/../../../skills/quest-log/assets" && pwd -P)
# Resolved physically, because the traversal case near the end of this file
# counts the path components between the profiles directory and the root, and
# the engine resolves its own asset directory with `pwd -P`. A TMPDIR reached
# through a symlink would otherwise be counted one way and walked another,
# leaving that case passing for the wrong reason.
sandbox=$(cd -- "$(mktemp -d "${TMPDIR:-/tmp}/tracker-test.XXXXXX")" && pwd -P)
trap 'rm -rf -- "$sandbox"' EXIT

# The suite runs the engine out of an asset tree it assembles here, not the one
# it sits in. The stub profile is a test asset that reaches no installed tree, so
# staging it is what keeps the declared-degraded gate covered; assembling the
# tree also stops every case below depending on how a skill directory happens to
# be laid out once installed.
assets="$sandbox/assets"
mkdir -p "$assets/profiles"
cp "$source_dir/tracker.sh" "$assets/tracker.sh"
cp "$source_dir/profiles/github.sh" "$assets/profiles/github.sh"
cp "$script_dir/fixture-profile.sh" "$assets/profiles/fixture.sh"
chmod +x "$assets/tracker.sh"
tracker="$assets/tracker.sh"

fail() {
	printf 'tracker-test: %s\n' "$*" >&2
	exit 1
}

assert_exit() {
	local expected=$1 actual=$2 label=$3
	[[ $actual == "$expected" ]] ||
		fail "$label: expected exit $expected, got $actual"
}

assert_contains() {
	local needle=$1 file=$2
	rg -F -- "$needle" "$file" >/dev/null || fail "missing '$needle' in $file"
}

# Two grammars below are ASCII bracket expressions, and bash takes a bracket
# range from the locale's collation -- so the property worth asserting is that
# they bite under the locale a developer actually runs, not under whichever one
# this suite inherits. Pin a territory UTF-8 locale where the host has one.
# `C.UTF-8` is deliberately not accepted as a substitute: it does not reproduce
# the collation behaviour, so a suite that settled for it would pass while the
# defect was live (ADR 0023). With no such locale the accented candidates are
# rejected whatever the grammar, so the cases still pass -- they stop proving the
# property, rather than turning a portability check into a host-configuration
# check.
utf8_locale=$(locale -a 2>/dev/null |
	rg -N -m1 '^[a-z]{2}_[A-Z]{2}\.(utf8|UTF-8)$' || true)
[[ -n $utf8_locale ]] ||
	printf 'tracker-test: no territory UTF-8 locale; the accented cases prove nothing\n' >&2

# Three distinct paths default to github, and each is a place where a
# regression would silently change which tracker a write reaches.
# (a) no git root at all
mkdir -p "$sandbox/norepo"
status=0
(cd "$sandbox/norepo" && "$tracker" resolve) >"$sandbox/out" 2>"$sandbox/err" ||
	status=$?
assert_exit 0 "$status" 'resolve outside a git repo'
assert_contains 'github' "$sandbox/out"

# (b) a git root with no AGENTS.md
mkdir -p "$sandbox/noagents"
git -C "$sandbox/noagents" init -q
status=0
(cd "$sandbox/noagents" && "$tracker" resolve) >"$sandbox/out" 2>"$sandbox/err" ||
	status=$?
assert_exit 0 "$status" 'resolve with no AGENTS.md'
assert_contains 'github' "$sandbox/out"

# (c) an AGENTS.md with content but no issue-tracker line -- must reach the
# default, not the malformed-typo die
mkdir -p "$sandbox/noline"
git -C "$sandbox/noline" init -q
printf '# Instructions\n\nNothing about trackers here.\n' >"$sandbox/noline/AGENTS.md"
status=0
(cd "$sandbox/noline" && "$tracker" resolve) >"$sandbox/out" 2>"$sandbox/err" ||
	status=$?
assert_exit 0 "$status" 'resolve with AGENTS.md lacking a declaration'
assert_contains 'github' "$sandbox/out"

# A malformed declaration is an error, not an absence: silently treating a typo
# as "no declaration" is a wrong-tracker write by another route.
mkdir -p "$sandbox/badrepo"
git -C "$sandbox/badrepo" init -q
printf 'issue-tracker: NotValid!\n' >"$sandbox/badrepo/AGENTS.md"
status=0
(cd "$sandbox/badrepo" && "$tracker" resolve) >"$sandbox/out" 2>"$sandbox/err" ||
	status=$?
assert_exit 1 "$status" 'resolve with malformed declaration'
assert_contains 'malformed' "$sandbox/err"

# More than one declaration is an error rather than first-wins.
mkdir -p "$sandbox/duprepo"
git -C "$sandbox/duprepo" init -q
printf 'issue-tracker: github\nissue-tracker: github\n' >"$sandbox/duprepo/AGENTS.md"
status=0
(cd "$sandbox/duprepo" && "$tracker" resolve) >"$sandbox/out" 2>"$sandbox/err" ||
	status=$?
assert_exit 1 "$status" 'resolve with duplicate declarations'

# A tracker with no profile is an actionable error at the operation boundary,
# never a silent fallback. Tested with --profile so it needs no profiles on
# disk, and the code path is the same one a declaration reaches.
status=0
"$tracker" view --profile nosuchtracker 1 >"$sandbox/out" 2>"$sandbox/err" ||
	status=$?
assert_exit 1 "$status" 'operation with unknown profile'
assert_contains 'nosuchtracker' "$sandbox/err"

# An unknown operation is a usage error.
status=0
"$tracker" nosuchop >"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 1 "$status" 'unknown operation'

# --- GitHub profile: reads -------------------------------------------------
# gh is reached through PATH, so a fixture bin stubs it: the suite runs with no
# network and no credentials.
mkdir -p "$sandbox/bin"
cat >"$sandbox/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"
if [[ $1 == repo && $2 == view ]]; then
	printf 'https://github.com/example/repo\n'
	exit 0
fi
if [[ $1 == issue && $2 == create ]]; then
	printf 'Creating issue in example/repo\n'
	printf 'https://github.com/example/repo/issues/101\n'
	exit 0
fi
if [[ $1 == issue && $2 == view ]]; then
	case ${GH_VIEW_SHAPE:-good} in
	malformed-parent)
		printf '%s\n' '{"number":101,"title":"T","body":"B","labels":[],"parent":"bad","state":"OPEN","url":"u"}'
		;;
	malformed-label)
		printf '%s\n' '{"number":101,"title":"T","body":"B","labels":["bad"],"parent":null,"state":"OPEN","url":"u"}'
		;;
	*)
		printf '%s\n' '{"number":101,"title":"T","body":"B","labels":[{"name":"status:ready"}],"parent":null,"state":"OPEN","url":"https://github.com/example/repo/issues/101"}'
		;;
	esac
	exit 0
fi
exit 0
FAKE_GH
chmod +x "$sandbox/bin/gh"

: >"$sandbox/calls"
GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" view --profile github --target example/repo 101 \
	>"$sandbox/out" 2>"$sandbox/err" || fail 'view exited non-zero'

jq -e '.id == "101" and .ref == "#101" and .state == "open" and .done == false
	and (.labels | index("status:ready")) != null and .parent == null' \
	>/dev/null <"$sandbox/out" || fail 'view did not normalize'

# The same invocation create-verified-issue-test.sh pins.
rg -q '^issue view ' "$sandbox/calls" || fail 'view did not call gh issue view'

# A malformed source shape must reach a deterministic message, not a jq crash.
for shape in malformed-parent malformed-label; do
	status=0
	GH_VIEW_SHAPE=$shape GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
		"$tracker" view --profile github --target example/repo 101 \
		>"$sandbox/out" 2>"$sandbox/err" || status=$?
	[[ $status != 0 ]] || fail "view accepted $shape"
	assert_contains 'malformed or incomplete JSON' "$sandbox/err"
done

# target-url strips a trailing slash and returns the canonical URL.
GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" target-url --profile github --target example/repo \
	>"$sandbox/out" 2>"$sandbox/err" || fail 'target-url exited non-zero'
assert_contains 'https://github.com/example/repo' "$sandbox/out"

# An operation needing a target says so rather than building a broken call.
status=0
PATH="$sandbox/bin:$PATH" "$tracker" target-url --profile github \
	>"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 1 "$status" 'target-url without --target'

# --- GitHub profile: writes ------------------------------------------------
# label-edit is atomic: adds and removes travel in one invocation. Splitting
# them leaves an issue with two status labels or none, and the pipeline reads
# that label to choose its next write.
: >"$sandbox/calls"
GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" label-edit --profile github --target example/repo 101 \
	--add status:in-progress --remove status:ready \
	>"$sandbox/out" 2>"$sandbox/err" || fail 'label-edit exited non-zero'
edits=$(rg -c '^issue edit ' "$sandbox/calls" || true)
[[ ${edits:-0} == 1 ]] || fail "label-edit made ${edits:-0} invocations, expected 1"
assert_contains 'add-label' "$sandbox/calls"
assert_contains 'remove-label' "$sandbox/calls"

# create succeeds and reports the normalized identity.
: >"$sandbox/calls"
printf 'body\n' >"$sandbox/body.md"
GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" create --profile github --target example/repo \
	--title T --body-file "$sandbox/body.md" --label status:ready \
	>"$sandbox/out" 2>"$sandbox/err" || fail 'create exited non-zero'
jq -e '.id == "101" and (.url | test("issues/101$"))' >/dev/null <"$sandbox/out" ||
	fail 'create did not report identity'

# create never retries, and a failed write is partial (5) carrying any URL seen.
cat >"$sandbox/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"
if [[ $1 == issue && $2 == create ]]; then
	printf 'https://github.com/example/repo/issues/101\n'
	printf 'boom\n' >&2
	exit 1
fi
exit 0
FAKE_GH
chmod +x "$sandbox/bin/gh"
: >"$sandbox/calls"
status=0
GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" create --profile github --target example/repo \
	--title T --body-file "$sandbox/body.md" \
	>"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 5 "$status" 'create on failed write'
creates=$(rg -c '^issue create ' "$sandbox/calls" || true)
[[ ${creates:-0} == 1 ]] || fail "create retried: ${creates:-0} invocations"
assert_contains 'issues/101' "$sandbox/err"

# label-ensure treats an existing label as success, not an error.
cat >"$sandbox/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"
if [[ $1 == label && $2 == create ]]; then
	printf 'label already exists\n' >&2
	exit 1
fi
exit 0
FAKE_GH
chmod +x "$sandbox/bin/gh"
: >"$sandbox/calls"
GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" label-ensure --profile github --target example/repo \
	status:ready 0e8a16 'triaged' >"$sandbox/out" 2>"$sandbox/err" ||
	fail 'label-ensure treated an existing label as failure'

# --- declared-degraded gate -------------------------------------------------
# Total coverage is not total implementation. A profile declares each operation
# implemented or degraded to a named value, and the suite asserts the
# declaration -- so a forgotten operation cannot pass as a legitimate
# degradation.
"$tracker" declares --profile fixture label-history >"$sandbox/out" 2>&1 ||
	fail 'declares exited non-zero'
assert_contains 'degraded=unknown' "$sandbox/out"

"$tracker" declares --profile github view >"$sandbox/out" 2>&1 ||
	fail 'declares github view exited non-zero'
assert_contains 'implemented' "$sandbox/out"

status=0
"$tracker" declares --profile fixture undeclared-op >"$sandbox/out" 2>"$sandbox/err" ||
	status=$?
assert_exit 1 "$status" 'undeclared operation'

# Both directions, derived from the profile rather than a hand-kept list: an
# operation added without a declaration must fail the gate immediately, and a
# declaration naming no function must fail it too.
# Named so they do not themselves match profile_*, which would make each helper
# look like an undeclared operation. Sourcing only binds names, so no stubs for
# die or the exit constants are needed.
list_profile_functions() { # profile-path
	(
		# shellcheck source=/dev/null
		. "$1"
		declare -F | sed -n 's/^declare -f profile_//p'
	)
}
list_profile_declarations() { # profile-path
	(
		# shellcheck source=/dev/null
		. "$1"
		printf '%s\n' "$PROFILE_DECLARES" | sed -n 's/:.*//p'
	)
}

for prof in github fixture; do
	path="$assets/profiles/$prof.sh"
	while IFS= read -r fn; do
		[[ -n $fn ]] || continue
		list_profile_declarations "$path" | rg -qx -- "$fn" ||
			fail "$prof defines profile_$fn with no declaration"
	done < <(list_profile_functions "$path")
	while IFS= read -r decl; do
		[[ -n $decl ]] || continue
		list_profile_functions "$path" | rg -qx -- "$decl" ||
			fail "$prof declares '$decl' but defines no profile_$decl"
	done < <(list_profile_declarations "$path")
done

# A degraded operation must actually return its declared value, not merely be
# listed as degraded.
declared=$("$tracker" declares --profile fixture label-history)
[[ $declared == degraded=* ]] || fail 'fixture label-history is not declared degraded'
observed=$("$tracker" label-history --profile fixture 1 label)
[[ $observed == "${declared#degraded=}" ]] ||
	fail "fixture label-history returned '$observed', declared '${declared#degraded=}'"

# --- error payload contract -------------------------------------------------
# Assert exit codes by value and parse the object: a substring match would pass
# on any non-zero exit, which is how a wrong class stays invisible.
assert_error() { # file expected-class label
	local file=$1 class=$2 label=$3
	jq -e --arg c "$class" '.error == $c' >/dev/null <"$file" ||
		fail "$label: error class is not '$class' (payload: $(cat "$file"))"
}

cat >"$sandbox/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"
case ${GH_FAIL:-none} in
notfound) printf 'gh: issue not found\n' >&2; exit 1 ;;
auth) printf 'gh: HTTP 401 authentication required\n' >&2; exit 1 ;;
transport) printf 'gh: dial tcp: i/o timeout\n' >&2; exit 1 ;;
esac
exit 0
FAKE_GH
chmod +x "$sandbox/bin/gh"

# Case-folding must not inherit a caller's territory locale. The wrapper keeps
# this regression focused on the tr boundary: it records the locale received by
# tr, then delegates to the system implementation so the classification still
# proves the not-found/auth/transport contract under a non-C UTF-8 locale.
cat >"$sandbox/bin/tr" <<'FAKE_TR'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n ${TR_LOCALE:-} ]]; then
	printf '%s\n' "${LC_ALL-}" >"$TR_LOCALE"
fi
exec /usr/bin/tr "$@"
FAKE_TR
chmod +x "$sandbox/bin/tr"

for failure in notfound auth transport; do
	case $failure in
	notfound)
		expected_exit=2
		expected_class=not-found
		;;
	auth)
		expected_exit=3
		expected_class=auth
		;;
	transport)
		expected_exit=4
		expected_class=transport
		;;
	esac
	status=0
	TR_LOCALE="$sandbox/tr-locale" GH_FAIL=$failure GH_CALL_LOG="$sandbox/calls" \
		PATH="$sandbox/bin:$PATH" LC_ALL="$utf8_locale" \
		"$tracker" view --profile github --target example/repo 101 \
		>"$sandbox/out" 2>"$sandbox/err" || status=$?
	assert_exit "$expected_exit" "$status" "$failure under a UTF-8 locale"
	assert_error "$sandbox/err" "$expected_class" "$failure under a UTF-8 locale"
	[[ $(cat "$sandbox/tr-locale") == C ]] ||
		fail "$failure case-fold inherited locale '$(cat "$sandbox/tr-locale")'"
done

status=0
GH_FAIL=notfound GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" view --profile github --target example/repo 101 \
	>"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 2 "$status" 'view against a missing issue'
assert_error "$sandbox/err" not-found 'not-found'

status=0
GH_FAIL=auth GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" view --profile github --target example/repo 101 \
	>"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 3 "$status" 'view with expired auth'
assert_error "$sandbox/err" auth 'auth'

status=0
GH_FAIL=transport GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" view --profile github --target example/repo 101 \
	>"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 4 "$status" 'view with a transport failure'
assert_error "$sandbox/err" transport 'transport'

# A missing positional is a usage error carrying the contract's object, not a
# raw bash unbound-variable abort leaking a local path.
status=0
PATH="$sandbox/bin:$PATH" "$tracker" view --profile github --target example/repo \
	>"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 1 "$status" 'view with no issue id'
assert_error "$sandbox/err" usage 'missing positional'

# label-edit names what it requested so a caller can repair a half-applied delta.
status=0
GH_FAIL=transport GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" label-edit --profile github --target example/repo 101 \
	--add status:ready >"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 5 "$status" 'label-edit on a failed write'
jq -e '.partial.requested_adds | index("status:ready")' >/dev/null <"$sandbox/err" ||
	fail 'label-edit partial does not name the requested adds'

# Removing a label the issue does not carry is a success.
GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" label-edit --profile github --target example/repo 101 \
	--remove not-present >"$sandbox/out" 2>"$sandbox/err" ||
	fail 'removing an absent label was treated as failure'

# --- every declared-implemented operation is actually exercised --------------
# A name-symmetry check passes whether the function works, silently no-ops, or
# posts a malformed body. link-parent shipped broken behind exactly that gap.
cat >"$sandbox/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"
if [[ ${GH_FAIL:-none} == notfound ]]; then
	printf 'gh: Not Found (HTTP 404)\n' >&2
	exit 1
fi
if [[ $1 == issue && $2 == view ]]; then
	case " $* " in
	*" comments "*) printf '%s\n' '{"comments":[{"body":"first"},{"body":"second"}]}' ;;
	*" body "*) printf 'existing body\r\nBlocked by #7\r\n' ;;
	*) printf '%s\n' '{"number":101,"title":"T","body":"B","labels":[],"parent":null,"state":"OPEN","url":"u","updatedAt":"2026-01-01T00:00:00Z"}' ;;
	esac
	exit 0
fi
if [[ $1 == api ]]; then
	case " $* " in
	*"/timeline"*) printf '2026-01-02T03:04:05Z\n' ;;
	*"/sub_issues"*) printf '{}\n' ;;
	*) printf '5039780970\n' ;;
	esac
	exit 0
fi
if [[ $1 == search ]]; then
	printf '%s\n' '["101","102"]'
	exit 0
fi
exit 0
FAKE_GH
chmod +x "$sandbox/bin/gh"
run_op() { # label -- args...
	local label=$1
	shift 2
	: >"$sandbox/calls"
	GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
		"$tracker" "$@" >"$sandbox/out" 2>"$sandbox/err" ||
		fail "$label exited non-zero: $(cat "$sandbox/err")"
}

run_op comment-list -- comment-list --profile github --target example/repo 101
jq -e 'length == 2 and .[0] == "first"' >/dev/null <"$sandbox/out" ||
	fail 'comment-list did not return the comment bodies'

run_op label-history -- label-history --profile github --target example/repo 101 status:ready
assert_contains '2026-01-02T03:04:05Z' "$sandbox/out"
rg -q -- '--slurp' "$sandbox/calls" ||
	fail 'label-history did not aggregate pages before filtering'

run_op search -- search --profile github --target example/repo --label status:ready \
	--updated-before 2026-01-01
jq -e 'length == 2' >/dev/null <"$sandbox/out" || fail 'search did not return ids'
rg -q 'updated:' "$sandbox/calls" || fail 'search dropped the updated-before predicate'

run_op comment-add -- comment-add --profile github --target example/repo 101 "$sandbox/body.md"
rg -q '^issue comment ' "$sandbox/calls" || fail 'comment-add did not comment'

run_op state-set -- state-set --profile github --target example/repo 101 closed
rg -q '^issue close ' "$sandbox/calls" || fail 'state-set closed did not close'
run_op state-set-open -- state-set --profile github --target example/repo 101 open
rg -q '^issue reopen ' "$sandbox/calls" || fail 'state-set open did not reopen'

# link-parent must send the child's database id, typed -- not its issue number.
run_op link-parent -- link-parent --profile github --target example/repo 43 4
rg -q -- '-F sub_issue_id=5039780970' "$sandbox/calls" ||
	fail 'link-parent did not send a typed database id'
rg -q -- 'sub_issue_id=43' "$sandbox/calls" &&
	fail 'link-parent sent the issue number instead of the database id'

# link-blocks is idempotent against a CRLF body.
run_op link-blocks -- link-blocks --profile github --target example/repo 7 101
edits=$(rg -c '^issue edit ' "$sandbox/calls" || true)
[[ ${edits:-0} == 0 ]] ||
	fail 'link-blocks rewrote a body that already carried the link (CRLF guard)'

# view now carries a real updated timestamp rather than a permanent null.
run_op view-updated -- view --profile github --target example/repo 101
jq -e '.updated == "2026-01-01T00:00:00Z"' >/dev/null <"$sandbox/out" ||
	fail 'view did not populate updated'

# gh's real 404 wording classifies as not-found on the REST paths too.
status=0
GH_FAIL=notfound GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" label-history --profile github --target example/repo 101 status:ready \
	>"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 2 "$status" 'label-history against a missing repo'
assert_error "$sandbox/err" not-found "gh's real 404 wording"

# The label guard exists because the value is spliced into a jq program, and its
# character set is ASCII by construction. Written as a range it is not: under a
# territory UTF-8 locale `[A-Za-z]` admits accented letters, so `statusé` reached
# the splice through a guard whose comment says it restricts the label to the
# characters GitHub labels use. Rejection here is what makes the enumeration in
# the profile load-bearing; reverting it to a range turns this case red.
status=0
GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" LC_ALL="${utf8_locale:-C}" \
	"$tracker" label-history --profile github --target example/repo 101 'statusé' \
	>"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 1 "$status" 'label-history with an accented label'
assert_error "$sandbox/err" usage 'accented label'
assert_contains 'label cannot be queried safely' "$sandbox/err"

# The two classes differ by exactly one character -- the space, which the second
# admits and the first does not -- so a label cannot begin with one. Written as
# two constants that is a difference a later edit can erase in either direction,
# and only one direction is caught by the loop below.
status=0
GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" label-history --profile github --target example/repo 101 ' status:ready' \
	>"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 1 "$status" 'label-history with a leading-space label'
assert_error "$sandbox/err" usage 'leading-space label'

# The same grammar still admits every character a GitHub label actually uses, so
# the enumeration is not quietly narrower than the range it replaced.
for label in status:ready 'has space' dot.name slash/x under_score dash-x; do
	status=0
	GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" LC_ALL="${utf8_locale:-C}" \
		"$tracker" label-history --profile github --target example/repo 101 "$label" \
		>"$sandbox/out" 2>"$sandbox/err" || status=$?
	assert_exit 0 "$status" "label-history with the label '$label'"
done

# --- stderr must never become the payload -----------------------------------
# gh prints its release-update notice on stderr while exiting 0. Merging the
# streams made that notice part of the value.
cat >"$sandbox/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"
printf 'A new release of gh is available: 2.60.0\n' >&2
if [[ $1 == repo && $2 == view ]]; then
	printf 'https://github.com/example/repo\n'
	exit 0
fi
if [[ $1 == issue && $2 == view ]]; then
	printf '%s\n' '{"number":101,"title":"T","body":"B","labels":[],"parent":null,"state":"OPEN","url":"u","updatedAt":"2026-01-01T00:00:00Z"}'
	exit 0
fi
exit 0
FAKE_GH
chmod +x "$sandbox/bin/gh"

run_op target-url-noise -- target-url --profile github --target example/repo
[[ $(cat "$sandbox/out") == 'https://github.com/example/repo' ]] ||
	fail "stderr noise leaked into the payload: $(cat "$sandbox/out")"

run_op view-noise -- view --profile github --target example/repo 101
jq -e '.id == "101"' >/dev/null <"$sandbox/out" ||
	fail 'stderr noise broke the view payload'

# --- link-blocks actually writes when the link is absent --------------------
cat >"$sandbox/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"
if [[ $1 == issue && $2 == view ]]; then
	printf 'a body with no link\n'
	exit 0
fi
if [[ $1 == issue && $2 == edit ]]; then
	for arg in "$@"; do
		[[ -f $arg ]] && cp "$arg" "$GH_BODY_COPY"
	done
	exit 0
fi
exit 0
FAKE_GH
chmod +x "$sandbox/bin/gh"
: >"$sandbox/calls"
GH_BODY_COPY="$sandbox/written-body" GH_CALL_LOG="$sandbox/calls" \
	PATH="$sandbox/bin:$PATH" \
	"$tracker" link-blocks --profile github --target example/repo 7 101 \
	>"$sandbox/out" 2>"$sandbox/err" || fail 'link-blocks write path failed'
rg -q '^issue edit ' "$sandbox/calls" ||
	fail 'link-blocks did not write when the link was absent'
assert_contains 'Blocked by #7' "$sandbox/written-body"
assert_contains 'a body with no link' "$sandbox/written-body"

# A non-numeric blocker never reaches the regex it would be spliced into.
status=0
PATH="$sandbox/bin:$PATH" "$tracker" link-blocks --profile github \
	--target example/repo 'x)|(' 101 >"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 1 "$status" 'link-blocks with a non-numeric blocker'
assert_error "$sandbox/err" usage 'non-numeric blocker'

# --- every operation taking an issue selector calls the guard ---------------
# Derived from the profile rather than a hand-kept list, like the declaration
# gate above: an operation added later that takes an issue selector and forgets
# github_require_id fails here, where a list of today's operations would not.
# target_url and label_ensure are exempt because their contracts name no issue.
# search is exempt for a different reason and is not covered: its --parent is an
# issue selector, deliberately left unguarded because GitHub's parent-issue:
# qualifier accepts forms this contract does not define. That is open, and this
# repository's deferral record 0011 owns it.
# Presence, not arity: an operation taking two selectors that guards one and
# forgets the other passes here, which is why the per-selector cases below name
# both of link-parent's.
guard_exempt='^(target_url|label_ensure|search)$'
while IFS= read -r op; do
	[[ -n $op ]] || continue
	[[ $op =~ $guard_exempt ]] && continue
	(
		# shellcheck source=/dev/null
		. "$assets/profiles/github.sh"
		declare -f "profile_$op"
	) | rg -q 'github_require_id' ||
		fail "github's profile_$op takes an issue selector but never calls github_require_id"
done < <(list_profile_declarations "$assets/profiles/github.sh")

# --- every positional naming an issue is a number ---------------------------
# Callers compose these from issue references read out of GitHub bodies, which
# any account can write, and label-history and link-parent interpolate them into
# a REST path segment. One case per selector the operations take today; the
# derived check above is what covers an operation added later.
assert_rejects_id() { # label -- tracker-args...
	local label=$1 status=0
	shift 2
	: >"$sandbox/calls"
	GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
		"$tracker" "$@" >"$sandbox/out" 2>"$sandbox/err" || status=$?
	assert_exit 1 "$status" "$label with a non-numeric id"
	assert_error "$sandbox/err" usage "$label with a non-numeric id"
	[[ ! -s $sandbox/calls ]] || fail "$label reached gh with a non-numeric id"
}

assert_rejects_id view -- view --profile github --target example/repo x
assert_rejects_id comment-list -- comment-list --profile github --target example/repo x
assert_rejects_id label-history -- label-history --profile github --target example/repo \
	'1/../../victim/secret/issues/1' status:ready
assert_rejects_id label-edit -- label-edit --profile github --target example/repo x \
	--add status:ready
assert_rejects_id comment-add -- comment-add --profile github --target example/repo x \
	"$sandbox/body.md"
assert_rejects_id state-set -- state-set --profile github --target example/repo x closed
assert_rejects_id link-parent-child -- link-parent --profile github --target example/repo \
	'1/../../victim/secret/issues/1' 4
assert_rejects_id link-parent-parent -- link-parent --profile github --target example/repo \
	43 '4/../../victim/secret/issues/4'
assert_rejects_id link-blocks-blocked -- link-blocks --profile github --target example/repo \
	7 x
assert_rejects_id create-parent -- create --profile github --target example/repo \
	--title T --body-file "$sandbox/body.md" --parent x

# --- a failure that cannot have written is not partial ----------------------
cat >"$sandbox/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"
printf '%s\n' "${GH_ERR_TEXT:-boom}" >&2
exit 1
FAKE_GH
chmod +x "$sandbox/bin/gh"

# 401: nothing was written, so claiming the issue may exist is worse than
# reporting the failure.
status=0
GH_ERR_TEXT='gh: HTTP 401: Bad credentials' GH_CALL_LOG="$sandbox/calls" \
	PATH="$sandbox/bin:$PATH" \
	"$tracker" create --profile github --target example/repo --title T \
	--body-file "$sandbox/body.md" >"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 3 "$status" 'create against bad credentials'
assert_error "$sandbox/err" auth 'create auth failure is not partial'

# A transport failure genuinely may have written, so it stays partial.
status=0
GH_ERR_TEXT='dial tcp: i/o timeout' GH_CALL_LOG="$sandbox/calls" \
	PATH="$sandbox/bin:$PATH" \
	"$tracker" create --profile github --target example/repo --title T \
	--body-file "$sandbox/body.md" >"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 5 "$status" 'create on a transport failure'
assert_error "$sandbox/err" partial 'create transport failure stays partial'

# --- every search predicate is scoped to --target ---------------------------
cat >"$sandbox/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"
printf '[]\n'
exit 0
FAKE_GH
chmod +x "$sandbox/bin/gh"
for pred in --label --parent --updated-before --text; do
	: >"$sandbox/calls"
	GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
		"$tracker" search --profile github --target example/repo \
		"$pred" 'x repo:victim/secret' >/dev/null 2>&1 || true
	rg -q 'repo:victim/secret[^"]*$' "$sandbox/calls" &&
		fail "$pred escaped --target scoping"
done

# --- comment-list validates before iterating --------------------------------
cat >"$sandbox/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"
printf '%s\n' '{"comments":"not-an-array"}'
exit 0
FAKE_GH
chmod +x "$sandbox/bin/gh"
status=0
GH_CALL_LOG="$sandbox/calls" PATH="$sandbox/bin:$PATH" \
	"$tracker" comment-list --profile github --target example/repo 101 \
	>"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 4 "$status" 'comment-list against a malformed payload'
assert_error "$sandbox/err" transport 'comment-list malformed is transport, not partial'

# --- --profile cannot escape the profiles directory -------------------------
# The flag bypasses the AGENTS.md route, whose grammar is enforced in
# resolve_tracker, and the name is concatenated into a path and sourced. Without
# the same grammar on the flag, a relative name runs an arbitrary file in the
# engine's process. The number of levels is computed from profiles/ rather than
# assumed: a fixed count stops reaching the root once a checkout sits deeper than
# it, and the case would then pass against an unguarded engine while still
# reading as traversal coverage.
cat >"$sandbox/evil.sh" <<EVIL
printf 'sourced\n' >"$sandbox/pwned"
EVIL
slashes=$(printf '%s' "$assets/profiles" | tr -cd /)
traversal=$(printf '../%.0s' $(seq "${#slashes}"))${sandbox#/}/evil
# The computed name must actually reach the planted file, or every assertion
# below passes against an unguarded engine too -- a wrong depth is rejected as a
# missing profile and reads exactly like a rejected traversal.
[[ -f "$assets/profiles/$traversal.sh" ]] ||
	fail 'the traversal name does not resolve to the planted file'
status=0
PATH="$sandbox/bin:$PATH" "$tracker" view --profile "$traversal" \
	--target example/repo 101 >"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 1 "$status" 'view with a traversing profile name'
assert_error "$sandbox/err" usage 'traversing profile name'
# The grammar, named: an unknown-but-well-formed profile also exits 1 as usage,
# so without this the only discriminating assertion is the marker below.
assert_contains 'profile name must match' "$sandbox/err"
[[ ! -e $sandbox/pwned ]] || fail '--profile sourced a file outside profiles/'

# The two routes must admit the same set — that agreement is the whole argument
# for a grammar over a containment test — and the character class is written
# three times in tracker.sh, twice as an rg pattern and once as a bash test.
# Relate the routes rather than testing each: widening one copy alone leaves
# every other case here green. `resolve` is the flag route's cheapest exercise,
# since the grammar is checked at parse time, before resolve short-circuits.
#
# Run under a non-C UTF-8 locale where the host has one. A bash bracket
# expression takes its ranges from the locale's collation, so a range like
# [a-z] admits githéb under en_US.UTF-8 and rejects it under C or C.UTF-8 --
# an ASCII-only default would hide exactly the divergence githéb is here to
# catch. With no such locale the accented candidates are rejected by both
# routes, so the loop still passes; it just stops proving this property.
mkdir -p "$sandbox/grammar"
git -C "$sandbox/grammar" init -q
agreement_locale=$(locale -a 2>/dev/null | rg -v '^C[.@]' | rg -m 1 -i '\.utf-?8$' || true)
for candidate in github my-tracker jira2 Bad has_underscore ../x dot.name '' 'two words' \
	githéb ПРОФИЛЬ profilé; do
	printf 'issue-tracker: %s\n' "$candidate" >"$sandbox/grammar/AGENTS.md"
	declared=accepted
	(cd "$sandbox/grammar" && LC_ALL="${agreement_locale:-C}" "$tracker" resolve) \
		>"$sandbox/out" 2>"$sandbox/err" || declared=rejected
	flagged=accepted
	LC_ALL="${agreement_locale:-C}" "$tracker" resolve --profile "$candidate" \
		>"$sandbox/out" 2>"$sandbox/err" || flagged=rejected
	[[ $declared == "$flagged" ]] ||
		fail "profile name '$candidate': declaration route $declared, --profile route $flagged"
done

# An empty value is a usage error too, not a silent fall-through to the
# declaration: --profile '' asked for a profile and named none.
status=0
PATH="$sandbox/bin:$PATH" "$tracker" view --profile '' --target example/repo 101 \
	>"$sandbox/out" 2>"$sandbox/err" || status=$?
assert_exit 1 "$status" 'view with an empty profile name'
assert_error "$sandbox/err" usage 'empty profile name'

# --- a CRLF declaration is valid, not malformed -----------------------------
mkdir -p "$sandbox/crlf"
git -C "$sandbox/crlf" init -q
printf 'issue-tracker: github\r\n' >"$sandbox/crlf/AGENTS.md"
status=0
(cd "$sandbox/crlf" && "$tracker" resolve) >"$sandbox/out" 2>"$sandbox/err" ||
	status=$?
assert_exit 0 "$status" 'resolve with a CRLF declaration'
[[ $(cat "$sandbox/out") == github ]] ||
	fail "CRLF declaration resolved to '$(cat "$sandbox/out")'"

printf 'tracker-test: all assertions passed\n'
