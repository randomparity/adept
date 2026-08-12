#!/usr/bin/env bash
set -euo pipefail

# Fixture suite for scripts/test-fixture-helpers.sh. Every case runs a child
# shell that sources the helper, because the effects worth pinning -- the EXIT
# trap removing a scratch directory, and `fail` exiting -- are only observable
# from outside the shell that installed them.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

clear_git_env
fixture_init test-fixture-helpers-test

# Every assertion below reports through abort rather than the sourced fail,
# because fail is one of the things under test. Discharging these assertions
# through it would mean a fail that stopped exiting could not be caught here --
# and fail is now the assertion primitive of five other gate suites.
abort() {
	printf 'test-fixture-helpers-test: %s\n' "$*" >&2
	exit 1
}

helper=$script_dir/test-fixture-helpers.sh
child_tmp=$SCRATCH/child-tmp
mkdir -p "$child_tmp"

# Reads the child's body from standard input so each case reads as a script.
# The child gets its own TMPDIR, so a scratch directory the helper creates from
# TMPDIR lands under this suite's own scratch root and is observable after the
# child exits.
run_child() { # <<body -- writes $SCRATCH/child.out, returns the child's status
	local status=0
	{
		printf '#!/usr/bin/env bash\nset -euo pipefail\n'
		printf '. %q\n' "$helper"
		cat
	} >"$SCRATCH/child.sh"
	# Closing stdin is deliberate: `rm -R` on an unwritable directory prompts
	# for an override when it has a terminal, and this suite redirects the
	# child's output, so such a prompt would hang invisibly.
	TMPDIR=$child_tmp bash "$SCRATCH/child.sh" >"$SCRATCH/child.out" 2>&1 \
		</dev/null || status=$?
	return "$status"
}

# fixture_init names the scratch directory after its label, puts it under
# TMPDIR, and removes it when the child exits.
run_child <<'CHILD'
fixture_init sample
printf '%s\n' "$SCRATCH"
CHILD
created=$(cat "$SCRATCH/child.out")
case $created in
"$child_tmp"/sample.*) : ;;
*) abort "init should create a scratch directory under TMPDIR, got: $created" ;;
esac
[ ! -e "$created" ] || abort "the EXIT trap should remove $created"

# A second scratch directory registered under a different parent is removed by
# the same trap. This is the shape check-public-safety-test.sh needs: its
# repo-root fixture cannot live under TMPDIR.
extra_parent=$SCRATCH/extra
mkdir -p "$extra_parent"
# Unquoted heredoc: $extra_parent is expanded here, and the child's own
# variables are escaped.
run_child <<CHILD
fixture_init sample
fixture_scratch "$extra_parent/side."
printf '%s\n' "\$FIXTURE_SCRATCH"
CHILD
side=$(cat "$SCRATCH/child.out")
case $side in
"$extra_parent"/side.*) : ;;
*) abort "fixture_scratch should honour its prefix, got: $side" ;;
esac
[ ! -e "$side" ] || abort "the EXIT trap should remove the extra directory $side"

# The guard on the `rm -R`. Reaching into the registry is deliberate: this is
# the one line in the helper whose failure destroys data, and no public entry
# point can produce the mismatch it defends against -- mktemp always returns the
# template it was given, so the recorded path always matches the recorded
# prefix. This is the suite's one white-box case: it names fixture_scratch_paths
# and fixture_scratch_prefixes, and renaming or collapsing them means updating
# it here.
survivor=$SCRATCH/survivor
mkdir -p "$survivor"
status=0
run_child <<CHILD || status=$?
fixture_init sample
fixture_scratch_prefixes[0]=/nowhere/
fixture_scratch_paths[0]=$survivor
CHILD
[ -d "$survivor" ] || abort 'cleanup removed a path outside its registered prefix'
grep -qF "sample: refusing to remove unsafe path: $survivor" "$SCRATCH/child.out" ||
	abort "refusal should name the label and the path: $(cat "$SCRATCH/child.out")"
# A refusal reddens the suite. Three of the five migrated suites already
# returned 1 here and, under the `set -e` every suite runs, that return is the
# shell's exit status; the other two only warned, and this unifies them on the
# stricter answer -- a fixture that could not be removed is not a pass.
[ "$status" -eq 1 ] || abort "a refused cleanup should redden the suite, got $status"

# One unremovable fixture must not strand the ones registered after it.
# check-public-safety-test.sh's second fixture lives inside the working tree and
# is always last, so an abort partway through leaves a directory in the repo.
#
# The case makes a removal fail by taking write permission off a directory, so
# it proves nothing where mode bits do not bite -- as root, or on a filesystem
# that ignores them -- and is skipped there rather than asserted falsely. This
# is the shape check-public-safety-test.sh uses for its own mode-000 fixture.
if [ "$(id -u)" -ne 0 ]; then
	blocker_parent=$SCRATCH/blocker
	mkdir -p "$blocker_parent"
	status=0
	run_child <<CHILD || status=$?
fixture_init sample
fixture_scratch "$blocker_parent/late."
late=\$FIXTURE_SCRATCH
mkdir "\$SCRATCH/child"
chmod 500 "\$SCRATCH"
printf '%s\n' "\$late"
CHILD
	# The child's own line comes first; the trap's diagnostics follow it,
	# because run_child merges stderr into the same file.
	late=$(head -1 "$SCRATCH/child.out")
	chmod 700 "$child_tmp"/sample.* 2>/dev/null || :
	[ "$status" -eq 1 ] ||
		abort "a failed removal should redden the suite, got $status"
	[ ! -e "$late" ] || abort "cleanup stopped at the failure and stranded $late"
else
	printf 'test-fixture-helpers-test: SKIP unremovable-fixture case: running as\n'
	printf 'test-fixture-helpers-test: root, which removes a mode-500 directory\n'
	printf 'test-fixture-helpers-test: anyway. This run did not check it.\n'
fi

# fail prefixes the label and exits 1.
status=0
run_child <<'CHILD' || status=$?
fixture_init sample
fail 'something went wrong'
printf 'unreachable\n'
CHILD
[ "$status" -eq 1 ] || abort "fail should exit 1, got $status"
[ "$(cat "$SCRATCH/child.out")" = 'sample: something went wrong' ] ||
	abort "unexpected fail output: $(cat "$SCRATCH/child.out")"

# clear_git_env unsets the repository-local selectors a caller may have
# exported, so a fixture's `git -C` is not overridden.
GIT_DIR=$SCRATCH/ambient.git GIT_INDEX_FILE=$SCRATCH/ambient.index run_child <<'CHILD'
clear_git_env
printf '%s %s\n' "${GIT_DIR:-unset}" "${GIT_INDEX_FILE:-unset}"
CHILD
[ "$(cat "$SCRATCH/child.out")" = 'unset unset' ] ||
	abort "clear_git_env left git selectors set: $(cat "$SCRATCH/child.out")"

# A git that cannot answer must stop the suite rather than leave it building
# fixtures with the ambient selectors still set.
fake_bin=$SCRATCH/fake-bin
mkdir -p "$fake_bin"
printf '#!/usr/bin/env bash\nexit 1\n' >"$fake_bin/git"
chmod +x "$fake_bin/git"
status=0
run_child <<CHILD || status=$?
PATH=$fake_bin:\$PATH
clear_git_env
printf 'reached\n'
CHILD
[ "$status" -ne 0 ] || abort 'a git that cannot answer should stop the suite'
grep -qF 'cannot read git local env vars' "$SCRATCH/child.out" ||
	abort "expected a diagnostic, got: $(cat "$SCRATCH/child.out")"
! grep -qF reached "$SCRATCH/child.out" ||
	abort 'clear_git_env returned after a failing git'

printf 'test-fixture-helpers-test: ok\n'
