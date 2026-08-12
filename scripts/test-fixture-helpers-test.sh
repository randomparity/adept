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
	TMPDIR=$child_tmp bash "$SCRATCH/child.sh" >"$SCRATCH/child.out" 2>&1 ||
		status=$?
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
# point can produce the mismatch it defends against.
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
# The refusal warns; it does not decide the suite's verdict. This is what all
# five migrated suites did before the extraction, and an `exit` added to the
# trap is what would break it.
[ "$status" -eq 0 ] || abort "a refused cleanup should not change the exit status, got $status"

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

printf 'test-fixture-helpers-test: ok\n'
