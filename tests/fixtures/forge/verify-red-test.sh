#!/usr/bin/env bash
# Behaviour suite for skills/forge/scripts/verify-red.
#
# Every case builds a throwaway git repository holding one implementation file and one test
# file, commits a base and then a task commit, and drives the script across that range. The
# assertions are on exit status and on the tree being exactly at HEAD afterwards -- the two
# things the orchestrator relies on -- never on message wording.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$SCRIPT_DIR/../../../scripts/test-fixture-helpers.sh"

# Hooks export repository-local Git variables that override `git -C`. Clear
# Git's complete reported set before any fixture repository is discovered.
clear_git_env

fixture_init verify-red-test

# The suite lives in tests/fixtures/ so it is excluded from the installed
# payload; the script it exercises ships under skills/.
SCRIPT="$SCRIPT_DIR/../../../skills/forge/scripts/verify-red"
[ -x "$SCRIPT" ] || fail "not executable: $SCRIPT"

# Builds a repository in a fresh directory and reports it in REPO, with BASE and HEAD set.
# impl.sh holds the implementation, impl-test.sh the test. The task commit rewrites impl.sh so
# that reverting it makes impl-test.sh fail.
make_repo() {
	REPO=$(mktemp -d "$SCRATCH/repo.XXXXXX")
	git -C "$REPO" init -q
	git -C "$REPO" config user.email fixture@example.invalid
	git -C "$REPO" config user.name Fixture
	printf 'old\n' >"$REPO/impl.sh"
	git -C "$REPO" add -A
	git -C "$REPO" commit -qm base
	BASE=$(git -C "$REPO" rev-parse HEAD)
	printf 'new\n' >"$REPO/impl.sh"
	printf '#!/usr/bin/env bash\ngrep -q new impl.sh\n' >"$REPO/impl-test.sh"
	git -C "$REPO" add -A
	git -C "$REPO" commit -qm task
	HEAD_SHA=$(git -C "$REPO" rev-parse HEAD)
}

# Runs the script inside REPO, recording its status in STATUS. Never lets a non-zero status end
# the suite -- every case here asserts on a specific code.
run_script() {
	STATUS=0
	(cd "$REPO" && "$SCRIPT" "$@") >"$SCRATCH/out" 2>"$SCRATCH/err" || STATUS=$?
}

assert_status() { # expected, label
	[ "$STATUS" -eq "$1" ] || fail "$2: expected exit $1, got $STATUS: $(cat "$SCRATCH/err")"
}

# Tracked state only, matching what the script promises: it is answerable for the paths it
# reverted, not for whatever the red command left lying around.
assert_clean() { # label
	local pending
	pending=$(git -C "$REPO" status --porcelain --untracked-files=no)
	[ -z "$pending" ] || fail "$1: tracked tree not restored: $pending"
}

# --- usage ---------------------------------------------------------------

make_repo
run_script
assert_status 2 "no arguments"

run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh
assert_status 2 "no -- separator"

run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh --
assert_status 2 "empty command"

run_script --base "$BASE" --test impl-test.sh -- true
assert_status 2 "missing --head"

# --- preconditions -------------------------------------------------------

run_script --base "$BASE" --head deadbeefdeadbeefdeadbeefdeadbeefdeadbeef \
	--test impl-test.sh -- true
assert_status 3 "unresolvable head"

run_script --base "$BASE" --head "$HEAD_SHA" --test nosuch-test.sh -- true
assert_status 3 "--test path outside the range"

printf 'dirty\n' >>"$REPO/impl.sh"
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- true
assert_status 3 "modified tree"
git -C "$REPO" checkout -- impl.sh

# --head must be the checked-out commit. Restoration puts every reverted path back to it, so a
# stale value would restore the tree to a commit it was never on -- and the check has to happen
# before any mutation, not after.
make_repo
printf 'later\n' >>"$REPO/impl.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm later
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- true
assert_status 3 "stale --head"
assert_clean "stale --head"

# An untracked file is neither the script's doing nor its business: it must not refuse to start,
# and it must not delete it.
make_repo
printf 'scratch\n' >"$REPO/notes.txt"
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- bash impl-test.sh
assert_status 0 "untracked file present"
[ -f "$REPO/notes.txt" ] || fail "untracked file present: the script removed it"

# --- verdicts ------------------------------------------------------------

make_repo
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- bash impl-test.sh
assert_status 0 "red confirmed"
assert_clean "red confirmed"
grep -q 'red-confirmed' "$SCRATCH/out" || fail "red confirmed: no verdict line"

make_repo
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- true
assert_status 1 "red not reproduced"
assert_clean "red not reproduced"

# Only the test file moves, so there is no implementation to revert.
make_repo
printf '#!/usr/bin/env bash\ntrue\n' >"$REPO/second-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm tests-only
ONLY_BASE=$HEAD_SHA
ONLY_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$ONLY_BASE" --head "$ONLY_HEAD" --test second-test.sh -- true
assert_status 4 "not separable"
assert_clean "not separable"

# --- restoration ---------------------------------------------------------

# An implementation file the task created must be removed for the run and put back after.
make_repo
printf 'helper\n' >"$REPO/added.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm add-impl
ADD_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$BASE" --head "$ADD_HEAD" --test impl-test.sh -- bash impl-test.sh
assert_status 0 "created implementation file"
assert_clean "created implementation file"
[ -f "$REPO/added.sh" ] || fail "created implementation file: not restored"

# An implementation file the task deleted must come back for the run and be removed after.
make_repo
git -C "$REPO" rm -q impl.sh
printf '#!/usr/bin/env bash\n! test -f impl.sh\n' >"$REPO/impl-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm delete-impl
DEL_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$HEAD_SHA" --head "$DEL_HEAD" --test impl-test.sh -- bash impl-test.sh
assert_status 0 "deleted implementation file"
assert_clean "deleted implementation file"
[ ! -f "$REPO/impl.sh" ] || fail "deleted implementation file: not removed again"

# A path containing a space survives the NUL-delimited read.
make_repo
printf 'old\n' >"$REPO/with space.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm spaced-base
SPACE_BASE=$(git -C "$REPO" rev-parse HEAD)
printf 'new\n' >"$REPO/with space.sh"
printf '#!/usr/bin/env bash\ngrep -q new "with space.sh"\n' >"$REPO/impl-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm spaced-task
SPACE_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$SPACE_BASE" --head "$SPACE_HEAD" --test impl-test.sh -- bash impl-test.sh
assert_status 0 "path with a space"
assert_clean "path with a space"

# A rename is a delete and an add inside one range, and both halves have to be undone. The probe
# reads the rename's *source* at its base content, so it exits 0 only when the source really was
# restored -- which the script then reports as red-not-reproduced, exit 1. Asserting exit 1 here
# is what makes the case bite: drop --no-renames from the script and the source is never restored,
# the probe fails, and this asserts 1 against an actual 0.
make_repo
git -C "$REPO" mv impl.sh renamed.sh
printf '#!/usr/bin/env bash\ngrep -q new renamed.sh\n' >"$REPO/impl-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm rename-impl
REN_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$HEAD_SHA" --head "$REN_HEAD" --test impl-test.sh -- grep -q new impl.sh
assert_status 1 "rename source restored to its base content"
assert_clean "rename source restored to its base content"
[ -f "$REPO/renamed.sh" ] || fail "rename: destination not restored"
[ ! -f "$REPO/impl.sh" ] || fail "rename: source left behind after restoration"

# Every focused entry's test file is passed on every invocation. Otherwise a sibling entry's test
# file is classified as implementation and reverted, and the command then fails because its helper
# vanished rather than because the implementation did -- a vacuous red-confirmed. The helper reads
# the reverted implementation, so with both files passed the command exits 0 and the script says
# red-not-reproduced (exit 1); drop one --test and the helper is gone, the command dies, and this
# asserts 1 against an actual 0.
make_repo
printf 'helper() { grep -q old impl.sh; }\n' >"$REPO/helper-test.sh"
printf '#!/usr/bin/env bash\n. ./helper-test.sh\nhelper\n' >"$REPO/impl-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm sibling-test
SIB_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$BASE" --head "$SIB_HEAD" --test impl-test.sh --test helper-test.sh \
	-- bash impl-test.sh
assert_status 1 "sibling test file preserved"
assert_clean "sibling test file preserved"

# A command that modifies a tracked path this script did not revert gets its own exit, so the
# residue is reported against the command that made it rather than stopping the next entry.
make_repo
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- \
	bash -c 'printf tainted >>impl-test.sh; exit 1'
assert_status 6 "command modified a tracked path"
grep -q 'red-confirmed' "$SCRATCH/out" ||
	fail "command modified a tracked path: verdict not reported alongside the residue"
grep -q 'impl-test.sh' "$SCRATCH/err" ||
	fail "command modified a tracked path: the residue path is not named"

# A command that could not run is not a failing test. 127 (not found) and 126 (not executable)
# are indistinguishable from a real failure by exit status, so they stop instead of confirming.
make_repo
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- verify-red-no-such-command
assert_status 3 "red command not found"
assert_clean "red command not found"

make_repo
printf '#!/usr/bin/env bash\ntrue\n' >"$REPO/not-exec.sh"
chmod 0644 "$REPO/not-exec.sh"
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- ./not-exec.sh
assert_status 3 "red command not executable"
assert_clean "red command not executable"

# A red command that writes an artifact must still report the verdict, not an unrestored tree.
make_repo
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- \
	bash -c 'mkdir -p .cache && : >.cache/x && bash impl-test.sh'
assert_status 0 "command wrote an untracked artifact"
assert_clean "command wrote an untracked artifact"

# Two --test paths, where only one of them is what the command actually reads.
make_repo
printf '#!/usr/bin/env bash\ntrue\n' >"$REPO/extra-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm second-test
TWO_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$BASE" --head "$TWO_HEAD" --test impl-test.sh --test extra-test.sh \
	-- bash impl-test.sh
assert_status 0 "two --test paths"
assert_clean "two --test paths"

# Exit 5 is constructed, not waited for: once restoration is scoped to the reverted paths no
# benign fixture reaches it, and an exit code with no case is how the loudest stop in the
# contract ships untested. The red command makes the implementation's directory unwritable, so
# restoration cannot put the file back.
make_repo
mkdir -p "$REPO/pkg"
git -C "$REPO" mv impl.sh pkg/impl.sh
printf '#!/usr/bin/env bash\ngrep -q new pkg/impl.sh\n' >"$REPO/impl-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm move-into-pkg
PKG_BASE=$(git -C "$REPO" rev-parse HEAD)
printf 'newer\n' >"$REPO/pkg/impl.sh"
# The named test file has to move inside the range under test, or the run stops at the
# untouched---test precondition before it ever reaches restoration.
printf '#!/usr/bin/env bash\ngrep -q newer pkg/impl.sh\n' >"$REPO/impl-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm change-in-pkg
PKG_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$PKG_BASE" --head "$PKG_HEAD" --test impl-test.sh -- \
	bash -c 'chmod 0500 pkg; exit 1'
chmod 0700 "$REPO/pkg"
assert_status 5 "restoration blocked"
grep -q 'could not restore' "$SCRATCH/err" ||
	fail "restoration blocked: no restoration diagnostic on stderr"

printf 'verify-red-test: all cases passed\n'
