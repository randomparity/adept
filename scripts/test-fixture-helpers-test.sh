#!/usr/bin/env bash
set -euo pipefail

# Fixture suite for scripts/test-fixture-helpers.sh. Every case runs a child
# shell that sources the helper, because the effects worth pinning -- the EXIT
# trap removing a scratch directory, and `fail` exiting -- are only observable
# from outside the shell that installed them.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

clear_git_env
fixture_init test-fixture-helpers-test

# Every assertion below reports through abort rather than the sourced fail,
# because fail is one of the things under test. Discharging these assertions
# through it would mean a fail that stopped exiting could not be caught here --
# and fail is now the assertion primitive of nine other suites.
abort() {
	printf 'test-fixture-helpers-test: %s\n' "$*" >&2
	exit 1
}

# Every parent-side path reaching a generated child body goes through this.
# These paths descend from TMPDIR, so an unquoted one splits the generated line
# on any whitespace in it -- and a child that dies mid-body can leave a case
# asserting against a half-built state instead of reddening.
q() { printf '%q' "$1"; }

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
fixture_scratch $(q "$extra_parent/side.")
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
fixture_scratch_paths[0]=$(q "$survivor")
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
# it proves nothing where mode bits do not bite -- as root, or on a mount that
# ignores them (SMB/CIFS, exFAT, some container and WSL mounts). Probe for the
# property itself rather than for root: the probe answers both, and asserting
# either falsely would redden `just verify` with a message naming a cleanup
# defect that does not exist.
mode_probe=$SCRATCH/mode-probe
mkdir -p "$mode_probe"
chmod 500 "$mode_probe"
mode_bits_bite=1
if (: >"$mode_probe/canary") 2>/dev/null; then
	mode_bits_bite=0
fi
chmod 700 "$mode_probe"

if [ "$mode_bits_bite" -eq 1 ]; then
	blocker_parent=$SCRATCH/blocker
	mkdir -p "$blocker_parent"
	status=0
	run_child <<CHILD || status=$?
fixture_init sample
fixture_scratch $(q "$blocker_parent/late.")
late=\$FIXTURE_SCRATCH
mkdir "\$SCRATCH/child"
chmod 500 "\$SCRATCH"
printf '%s\n' "\$late"
CHILD
	# The child's own line comes first; the trap's diagnostics follow it,
	# because run_child merges stderr into the same file.
	late=$(head -1 "$SCRATCH/child.out")
	chmod 700 "$child_tmp"/sample.* 2>/dev/null || :
	# Pin what the child reported before trusting it. A child that died at
	# fixture_scratch, mkdir or chmod also exits 1 and also leaves no
	# directory at whatever text landed on line 1, so without these the case
	# reports green having exercised nothing.
	case $late in
	"$blocker_parent"/late.*) : ;;
	*) abort "child did not report its late fixture: $(cat "$SCRATCH/child.out")" ;;
	esac
	grep -qF 'sample: cleanup failed for' "$SCRATCH/child.out" ||
		abort "cleanup should report the failure: $(cat "$SCRATCH/child.out")"
	[ "$status" -eq 1 ] ||
		abort "a failed removal should redden the suite, got $status"
	[ ! -e "$late" ] || abort "cleanup stopped at the failure and stranded $late"
else
	printf 'test-fixture-helpers-test: SKIP unremovable-fixture case: this user and\n'
	printf 'test-fixture-helpers-test: TMPDIR write into a mode-500 directory, so a\n'
	printf 'test-fixture-helpers-test: removal cannot be made to fail. This run did\n'
	printf 'test-fixture-helpers-test: not check it.\n'
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
run_child <<CHILD
export GIT_DIR=$(q "$SCRATCH/ambient.git")
export GIT_INDEX_FILE=$(q "$SCRATCH/ambient.index")
clear_git_env
printf '%s %s\n' "\${GIT_DIR:-unset}" "\${GIT_INDEX_FILE:-unset}"
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
PATH=$(q "$fake_bin"):\$PATH
clear_git_env
printf 'reached\n'
CHILD
[ "$status" -ne 0 ] || abort 'a git that cannot answer should stop the suite'
grep -qF 'cannot read git local env vars' "$SCRATCH/child.out" ||
	abort "expected a diagnostic, got: $(cat "$SCRATCH/child.out")"
! grep -qF reached "$SCRATCH/child.out" ||
	abort 'clear_git_env returned after a failing git'

# The same failure wearing a zero exit status: a git that answers with nothing
# has not told the suite there is nothing to clear.
printf '#!/usr/bin/env bash\nexit 0\n' >"$fake_bin/git"
status=0
run_child <<CHILD || status=$?
export GIT_DIR=$(q "$SCRATCH/ambient.git")
PATH=$(q "$fake_bin"):\$PATH
clear_git_env
printf 'reached with GIT_DIR=%s\n' "\${GIT_DIR:-unset}"
CHILD
[ "$status" -ne 0 ] || abort 'a git that answers with nothing should stop the suite'
grep -qF 'git reported no local env vars' "$SCRATCH/child.out" ||
	abort "expected a diagnostic, got: $(cat "$SCRATCH/child.out")"
! grep -qF reached "$SCRATCH/child.out" ||
	abort 'clear_git_env returned having cleared nothing'

# The `-f` on the cleanup `rm`. A git fixture holds mode-444 loose objects, and
# without `-f` rm asks to override each one whenever it has a terminal, so the
# trap fails and the suite reddens for a developer running it by hand while
# passing under `just verify`. run_child cannot reach this: it closes stdin
# deliberately, and with stdin closed rm removes an unwritable file without
# asking, so the case would pass with or without the flag. Hence the pty.
#
# script(1) has two incompatible argument orders and neither host is guaranteed
# to have it, so probe and skip loudly rather than redden somewhere it is
# missing. The probe turns on a marker the probed command writes, never on an
# exit status: util-linux before 2.39 takes the first positional as its
# typescript file and silently discards the rest, so the BSD form there runs an
# interactive shell instead of the command and still exits 0. Classifying on
# that status would redden every such host -- Ubuntu 22.04, Debian 12, RHEL 9 --
# with a message naming a cleanup defect that does not exist.
#
# The util-linux form is tried first for the same reason. It is the one whose
# misfire is harmless: macOS script has no -c and exits on the unknown option
# without spawning anything, whereas the BSD form's misfire is the interactive
# shell above, which a login file setting `ignoreeof` turns into a hang.
#
# Every script(1) call closes its own stdin. script forwards its stdin to the
# pty it allocates, so the child still sees a terminal and the case still bites;
# what closing prevents is script draining the caller's stdin. `just test` feeds
# the suite list to a `while read` loop on stdin, and a script that inherits it
# swallows the remaining suites -- the run then reports the suites it reached
# and exits 0, which is a green board for a test pass that never happened.
pty_marker=$SCRATCH/pty-probe-marker
pty_probe=$SCRATCH/pty-probe.sh
cat >"$pty_probe" <<PROBE
#!/usr/bin/env bash
: >$(q "$pty_marker")
PROBE
chmod +x "$pty_probe"

pty_style=none
# util-linux re-parses this argument through \$SHELL -c, so the path is quoted
# for that shell the way every other generated path in this file is.
script -q -c "$(q "$pty_probe")" /dev/null >/dev/null 2>&1 </dev/null || :
if [ -e "$pty_marker" ]; then
	pty_style=util-linux
else
	script -q /dev/null "$pty_probe" >/dev/null 2>&1 </dev/null || :
	if [ -e "$pty_marker" ]; then
		pty_style=bsd
	fi
fi

if [ "$pty_style" != none ]; then
	pty_child=$SCRATCH/pty-child.sh
	{
		printf '#!/usr/bin/env bash\nset -euo pipefail\n'
		printf '. %q\n' "$helper"
		cat <<CHILD
fixture_init sample
printf '%s\n' "\$SCRATCH" >$(q "$SCRATCH/pty-path")
mkdir "\$SCRATCH/objects"
printf 'object\n' >"\$SCRATCH/objects/loose"
chmod 444 "\$SCRATCH/objects/loose"
CHILD
	} >"$pty_child"

	# The child's own exit status is what this case turns on, and script(1)
	# reports it only on util-linux and only with -e. A wrapper that records it
	# needs neither flag nor version, and reports through the same marker-file
	# evidence the probe above relies on.
	pty_wrapper=$SCRATCH/pty-wrapper.sh
	cat >"$pty_wrapper" <<WRAPPER
#!/usr/bin/env bash
TMPDIR=$(q "$child_tmp") bash $(q "$pty_child") >$(q "$SCRATCH/pty-child.out") 2>&1
printf '%s\n' "\$?" >$(q "$SCRATCH/pty-status")
WRAPPER
	chmod +x "$pty_wrapper"

	case $pty_style in
	bsd) script -q /dev/null "$pty_wrapper" >/dev/null 2>&1 </dev/null || : ;;
	util-linux)
		script -q -c "$(q "$pty_wrapper")" /dev/null >/dev/null 2>&1 </dev/null || :
		;;
	esac

	[ -s "$SCRATCH/pty-status" ] ||
		abort 'the child under a terminal never reported its status'
	# The wrapper writes pty-status unconditionally, so a status alone does not
	# prove the child reached fixture_init. Without this the `cat` below fails
	# under `set -e` and the suite dies unlabelled, naming no case.
	[ -f "$SCRATCH/pty-path" ] ||
		abort "the child under a terminal never reported its scratch directory: $(cat "$SCRATCH/pty-child.out")"
	pty_path=$(cat "$SCRATCH/pty-path")
	case $pty_path in
	"$child_tmp"/sample.*) : ;;
	*) abort "child did not report its scratch directory: $pty_path" ;;
	esac
	[ "$(cat "$SCRATCH/pty-status")" -eq 0 ] ||
		abort "a read-only fixture should not redden a suite run from a terminal: $(cat "$SCRATCH/pty-child.out")"
	[ ! -e "$pty_path" ] ||
		abort "cleanup under a terminal stranded the read-only fixture at $pty_path"
else
	printf 'test-fixture-helpers-test: SKIP terminal-cleanup case: no usable\n'
	printf 'test-fixture-helpers-test: script(1) on this host, so a pty could not\n'
	printf 'test-fixture-helpers-test: be allocated. This run did not check it.\n'
fi

printf 'test-fixture-helpers-test: ok\n'
