#!/usr/bin/env bash
set -euo pipefail

# Fixture suite for scripts/list-shell-sources.sh. Each fixture is a throwaway
# git repository holding a copy of the lister and the tracked files under test,
# so the cases exercise the same `git ls-files` walk the repository uses without
# depending on this repository's own contents.
#
# The inventory this script prints is what `just lint` and `just format-check`
# check, so a file it drops is a file no gate ever reads. That is the failure
# these cases are aimed at: classification answers three ways -- a shell source,
# not a shell source, or a file that could not be read -- and only the first two
# may be silent.
#
# The suite inherits git-fixture isolation: a caller's GIT_DIR or GIT_INDEX_FILE
# would otherwise reach the fixture's `git ls-files` and list this repository.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

clear_git_env
fixture_init list-shell-sources-test

lister=$script_dir/list-shell-sources.sh

# The lister's own copy is tracked in every fixture, so no fixture is ever
# empty: the empty-inventory guard would otherwise decide the cases below that
# are about one file.
new_fixture() { # name
	local root=$SCRATCH/$1
	mkdir -p "$root/scripts"
	cp "$lister" "$root/scripts/list-shell-sources.sh"
	chmod +x "$root/scripts/list-shell-sources.sh"
	git init -q -b main "$root"
	git -C "$root" config user.name 'Fixture Developer'
	git -C "$root" config user.email fixture@example.invalid
	git -C "$root" add -- scripts/list-shell-sources.sh
	printf '%s\n' "$root"
}

# printf rather than a here-document: one case needs a file with no trailing
# newline, which a here-document cannot produce.
write_tracked() { # root relative-path content
	local root=$1 path=$2
	mkdir -p "$(dirname "$root/$path")"
	printf '%s' "$3" >"$root/$path"
	git -C "$root" add -- "$path"
}

listing() { # root mode -- prints the inventory, one path per line
	(cd "$1" && ./scripts/list-shell-sources.sh "$2")
}

lists() { # listing-output path
	printf '%s\n' "$1" | grep -qxF "$2"
}

# A Bash shebang is what makes an extensionless file a shell source; anything
# else under the same walk is simply not one.
extensionless=$(new_fixture extensionless)
write_tracked "$extensionless" scripts/hook '#!/usr/bin/env bash
echo hi
'
write_tracked "$extensionless" scripts/notes 'plain text, not a script
'
out=$(listing "$extensionless" --tabs)
lists "$out" scripts/hook ||
	fail "extensionless: a bash shebang was not recognised: $out"
if lists "$out" scripts/notes; then
	fail "extensionless: a plain text file was listed: $out"
fi

# A shebang with no trailing newline. `read` reports a non-zero status at a
# clean EOF as well as on a failure, and the first line is still in the variable
# either way, so a fault test written on the status alone would drop this file.
no_newline=$(new_fixture no_newline)
write_tracked "$no_newline" scripts/hook '#!/usr/bin/env bash'
out=$(listing "$no_newline" --tabs)
lists "$out" scripts/hook ||
	fail "no_newline: a shebang without a trailing newline was dropped: $out"

# An empty tracked file is the ordinary negative: there is no first line to
# match, it is not a shell source, and that must stay silent.
empty=$(new_fixture empty)
write_tracked "$empty" scripts/placeholder ''
out=$(listing "$empty" --tabs)
if lists "$out" scripts/placeholder; then
	fail "empty: an empty file was listed as a shell source: $out"
fi

# A tracked binary. `read` yields nothing from a leading NUL and reports the
# same non-zero status as an unreadable file, so deciding the fault from that
# status plus the file's size reds the gates on an asset nobody was asking
# about. The open is what separates them, and it succeeds here.
binary=$(new_fixture binary)
printf '\000\001\002' >"$binary/scripts/asset"
git -C "$binary" add -- scripts/asset
status=0
out=$(listing "$binary" --tabs 2>&1) || status=$?
[ "$status" -eq 0 ] ||
	fail "binary: a readable binary file was reported as a fault: $out"
if lists "$out" scripts/asset; then
	fail "binary: a binary file was listed as a shell source: $out"
fi

# A tracked path that is not in the worktree at all. git lists it, so something
# is meant to be there; the `[[ -f ]]` guard this replaces answered "not a
# regular file" and dropped it as silently as the unreadable case below.
missing=$(new_fixture missing)
write_tracked "$missing" scripts/hook '#!/usr/bin/env bash
'
rm -- "$missing/scripts/hook"
status=0
out=$(listing "$missing" --tabs 2>&1) || status=$?
[ "$status" -ne 0 ] ||
	fail "missing: a tracked path absent from the worktree was dropped at exit 0: $out"
printf '%s\n' "$out" | grep -q '^list-shell-sources: scripts/hook is tracked but nothing is there' ||
	fail "missing: the diagnostic does not point at the deletion: $out"

# A sparse checkout leaves tracked paths deliberately absent from the worktree
# and marks them skip-worktree, which `git ls-files` still lists. Treating those
# as a fault would make the repository uncommittable for anyone using a sparse
# checkout or assume-unchanged -- both supported configurations, and both
# indistinguishable from the `missing` case above by anything but git's own tag.
sparse=$(new_fixture sparse)
write_tracked "$sparse" scripts/hook '#!/usr/bin/env bash
'
git -C "$sparse" -c user.name=t -c user.email=t@e.invalid commit -qm base
git -C "$sparse" update-index --skip-worktree scripts/hook
rm -- "$sparse/scripts/hook"
status=0
out=$(listing "$sparse" --tabs 2>&1) || status=$?
[ "$status" -eq 0 ] ||
	fail "sparse: a skip-worktree path was reported as a fault: $out"
if lists "$out" scripts/hook; then
	fail "sparse: a path absent by design was listed as a shell source: $out"
fi

# The walk that produces the inventory. `git ls-files -z` read through a process
# substitution reported the loop's status, so a listing that stopped partway
# yielded a short inventory at exit 0 -- this script's own producer carrying the
# defect its consumers were rewired to avoid.
walk=$(new_fixture walk)
write_tracked "$walk" scripts/hook '#!/usr/bin/env bash
'
stub_bin=$SCRATCH/git-walk-fault-bin
mkdir -p "$stub_bin"
real_git=$(command -v git)
cat >"$stub_bin/git" <<STUB
#!/usr/bin/env bash
if [ "\$1" = ls-files ] && [ "\$2" = -z ]; then
  printf 'scripts/hook\0'
  printf 'fatal: fixture-fault: simulated index read error\n' >&2
  exit 128
fi
exec "$real_git" "\$@"
STUB
chmod +x "$stub_bin/git"
status=0
out=$(cd "$walk" && PATH="$stub_bin:$PATH" ./scripts/list-shell-sources.sh --tabs 2>&1) || status=$?
[ "$status" -ne 0 ] ||
	fail "walk: a listing that stopped partway produced an inventory at exit 0: $out"
printf '%s\n' "$out" | grep -q "^list-shell-sources: could not list the repository's tracked files" ||
	fail "walk: no diagnostic for a failed listing: $out"

# A tracked path replaced by a FIFO. git only ever stores regular files,
# symlinks and gitlinks, so this cannot come from the index -- it comes from
# the worktree, where anything can be put at a tracked path. It is the one
# shape that must not reach the open: opening a FIFO for reading blocks until a
# writer appears, which would hang every gate that consumes this list.
#
# What this case pins is the verdict, not the hang. Measured on bash 3.2: with
# the guard removed the open sometimes returns instead of blocking, because the
# process substitution feeding the loop delivers a SIGCHLD that interrupts it --
# a race, which is exactly what the guard removes. Against the `[[ -f ]]` test
# this branch replaced it reddens outright, since that answered 1 and dropped
# the path in silence.
fifo=$(new_fixture fifo)
write_tracked "$fifo" scripts/hook '#!/usr/bin/env bash
'
rm -- "$fifo/scripts/hook"
mkfifo "$fifo/scripts/hook"
status=0
out=$(listing "$fifo" --tabs 2>&1) || status=$?
rm -- "$fifo/scripts/hook"
[ "$status" -ne 0 ] ||
	fail "fifo: a tracked path replaced by a FIFO was dropped at exit 0: $out"
printf '%s\n' "$out" | grep -q '^list-shell-sources: scripts/hook is tracked but is not a regular file' ||
	fail "fifo: the diagnostic does not say it is not a regular file: $out"

# A tracked symlink whose target is gone. `-e` follows the link and is false,
# exactly as it is for an absent path, so without its own branch the diagnostic
# tells the developer to stage a deletion that is not there.
dangling=$(new_fixture dangling)
ln -s missing-target "$dangling/scripts/hook"
git -C "$dangling" add -- scripts/hook
status=0
out=$(listing "$dangling" --tabs 2>&1) || status=$?
[ "$status" -ne 0 ] ||
	fail "dangling: a symlink with no target was dropped at exit 0: $out"
printf '%s\n' "$out" | grep -q '^list-shell-sources: scripts/hook is a symlink whose target is missing' ||
	fail "dangling: the diagnostic does not name the broken symlink: $out"

# A submodule's gitlink is the one non-file git emits here as a matter of
# course, and it is a directory. It is the ordinary negative, not a fault: with
# the open deciding and nothing naming this case, every repo with a submodule
# would red its own gates.
gitlink=$(new_fixture gitlink)
git init -q -b main "$gitlink/vendor"
git -C "$gitlink/vendor" config user.name 'Fixture Developer'
git -C "$gitlink/vendor" config user.email fixture@example.invalid
printf 'seed\n' >"$gitlink/vendor/README.md"
git -C "$gitlink/vendor" add -- README.md
git -C "$gitlink/vendor" commit -qm seed
git -C "$gitlink" add -- vendor 2>/dev/null
git -C "$gitlink" ls-files -s -- vendor | grep -q '^160000 ' ||
	fail "gitlink: the fixture did not produce a gitlink entry"
status=0
out=$(listing "$gitlink" --tabs 2>&1) || status=$?
[ "$status" -eq 0 ] ||
	fail "gitlink: a submodule entry was reported as a fault: $out"
if lists "$out" vendor; then
	fail "gitlink: a submodule entry was listed as a shell source: $out"
fi

# The case this suite exists for. A tracked file the lister cannot read used to
# be indistinguishable from an empty one -- both a non-zero `read` -- so it left
# the inventory silently and was never linted and never format-checked, with
# nothing reported anywhere. It must fail loudly instead.
#
# Skipped under a uid that ignores the permission bits, which is how the case
# would otherwise pass by not testing anything. The skip reaches the summary
# line, not just this one: a green run that tested nothing here must not read
# like one that did.
skipped=''
if [ "$(id -u)" -eq 0 ]; then
	skipped=' (permission cases skipped as root)'
	printf 'list-shell-sources-test: skipping the permission cases as root\n' >&2
else
	unreadable=$(new_fixture unreadable)
	write_tracked "$unreadable" scripts/hook '#!/usr/bin/env bash
echo hi
'
	chmod 000 "$unreadable/scripts/hook"
	status=0
	out=$(listing "$unreadable" --tabs 2>&1) || status=$?
	chmod 644 "$unreadable/scripts/hook"
	[ "$status" -ne 0 ] ||
		fail "unreadable: an unreadable file was dropped at exit 0: $out"
	# The lister's own diagnostic, and only that one: bash's own redirection
	# error used to reach stderr while the run still exited 0, and the fix puts
	# it behind a redirection so this script's message is the whole interface.
	printf '%s\n' "$out" | grep -q '^list-shell-sources: .*scripts/hook' ||
		fail "unreadable: no diagnostic naming the file: $out"
	if printf '%s\n' "$out" | grep -q 'Permission denied'; then
		fail "unreadable: bash's own redirection error leaked: $out"
	fi

	# Zero bytes and unreadable. Nothing can be read from it either way, which
	# is what makes it the case a content test decides wrongly: it is empty, so
	# it looks like the ordinary negative, and the gate never learns the file
	# was there.
	unreadable_empty=$(new_fixture unreadable_empty)
	write_tracked "$unreadable_empty" scripts/hook ''
	chmod 000 "$unreadable_empty/scripts/hook"
	status=0
	out=$(listing "$unreadable_empty" --tabs 2>&1) || status=$?
	chmod 644 "$unreadable_empty/scripts/hook"
	[ "$status" -ne 0 ] ||
		fail "unreadable_empty: an unreadable empty file was dropped at exit 0: $out"
	printf '%s\n' "$out" | grep -q '^list-shell-sources: cannot open scripts/hook' ||
		fail "unreadable_empty: no diagnostic naming the file: $out"

	# An unsearchable parent, where the file is intact and the path to it is
	# not. Distinct from the cases above because no permission bit on the file
	# itself is involved, so a fix that reasoned about the file's own mode
	# would miss it.
	unsearchable=$(new_fixture unsearchable)
	write_tracked "$unsearchable" scripts/nested/hook '#!/usr/bin/env bash
'
	chmod 000 "$unsearchable/scripts/nested"
	status=0
	out=$(listing "$unsearchable" --tabs 2>&1) || status=$?
	chmod 755 "$unsearchable/scripts/nested"
	[ "$status" -ne 0 ] ||
		fail "unsearchable: a file behind an unsearchable directory was dropped at exit 0: $out"
	printf '%s\n' "$out" | grep -q '^list-shell-sources: .*scripts/nested/hook' ||
		fail "unsearchable: no diagnostic naming the file: $out"

	# A symlink whose target exists and cannot be read. `-L` alone would call
	# this a broken link and send the developer looking for a missing target
	# rather than at the permissions that are actually wrong.
	link_unreadable=$(new_fixture link_unreadable)
	write_tracked "$link_unreadable" scripts/target '#!/usr/bin/env bash
'
	ln -s target "$link_unreadable/scripts/hook"
	git -C "$link_unreadable" add -- scripts/hook
	chmod 000 "$link_unreadable/scripts/target"
	status=0
	out=$(listing "$link_unreadable" --tabs 2>&1) || status=$?
	chmod 644 "$link_unreadable/scripts/target"
	[ "$status" -ne 0 ] ||
		fail "link_unreadable: an unreadable link target was dropped at exit 0: $out"
	if printf '%s\n' "$out" | grep -q 'whose target is missing'; then
		fail "link_unreadable: a readable link to an unreadable target read as broken: $out"
	fi
	printf '%s\n' "$out" | grep -q '^list-shell-sources: cannot open scripts/' ||
		fail "link_unreadable: no permissions diagnostic: $out"
fi

# The lister's exit status only reaches a verdict if its consumers read it, and
# `while ... done < <(lister)` reports the loop's status instead -- which is why
# the lint and format-check recipes capture the list to a file first. This runs
# the repository's real recipes against a fixture whose lister emits a partial
# list and then fails, which is exactly the shape a status-blind recipe passes.
just_real=$(command -v just || true)
if [ -z "$just_real" ]; then
	fail "just is not installed, so the recipe recipes cannot be exercised"
fi
recipe_root=$(cd "$script_dir/.." && pwd -P)
partial=$SCRATCH/partial
mkdir -p "$partial/scripts"
cat >"$partial/scripts/list-shell-sources.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'scripts/list-shell-sources.sh\0'
printf 'stub: discovery stopped partway\n' >&2
exit 1
STUB
chmod +x "$partial/scripts/list-shell-sources.sh"
for recipe in lint format-check; do
	status=0
	out=$("$just_real" --working-directory "$partial" --justfile "$recipe_root/Justfile" \
		"$recipe" 2>&1) || status=$?
	[ "$status" -ne 0 ] ||
		fail "$recipe: a lister that failed partway did not fail the recipe: $out"
done

# The `test` recipe carries the same shape over a different discovery: it reads
# `git ls-files` rather than the lister, so its stub is a PATH shim rather than
# a script copy. The shim answers `ls-files` with a partial list and a non-zero
# status and forwards every other subcommand to the real git, so nothing else
# the recipe or just may ask git is disturbed. The fixture holds the one suite
# the shim names, executable and passing: a status-blind recipe runs it, counts
# one, and reports a green run over a suite set it never finished discovering.
git_stub=$SCRATCH/git-stub
mkdir -p "$git_stub"
cat >"$git_stub/git" <<STUB
#!/usr/bin/env bash
set -euo pipefail
if [ "\${1-}" = ls-files ]; then
	printf 'scripts/partial-test.sh\0'
	printf 'git-stub: discovery stopped partway\n' >&2
	exit 1
fi
exec "$real_git" "\$@"
STUB
chmod +x "$git_stub/git"
partial_suites=$SCRATCH/partial-suites
mkdir -p "$partial_suites/scripts"
cat >"$partial_suites/scripts/partial-test.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'partial-test: pass\n'
STUB
chmod +x "$partial_suites/scripts/partial-test.sh"
status=0
out=$(PATH=$git_stub:$PATH "$just_real" \
	--working-directory "$partial_suites" --justfile "$recipe_root/Justfile" \
	test 2>&1) || status=$?
[ "$status" -ne 0 ] ||
	fail "test: a discovery that failed partway did not fail the recipe: $out"
# A non-zero status alone would also be satisfied by a recipe that never
# reached the discovery at all -- a mistyped justfile path, a shim that could
# not execute. The shim's own diagnostic proves the recipe got as far as
# `git ls-files`, and the absence of the summary proves it did not go on to
# report a pass over what that discovery had already emitted.
printf '%s\n' "$out" | grep -q 'git-stub: discovery stopped partway' ||
	fail "test: the recipe never reached the stubbed discovery: $out"
if printf '%s\n' "$out" | grep -q 'suites passed'; then
	fail "test: the recipe reported a pass over a partial discovery: $out"
fi
# Failing at the end is not the same as failing before the damage. A recipe
# that ran the suites it did receive and only then noticed the discovery had
# died satisfies both checks above, so the suite's own marker has to be absent
# too: the discovery must stop the run before anything from a short list runs.
if printf '%s\n' "$out" | grep -q 'partial-test: pass'; then
	fail "test: the recipe ran a suite from a discovery that had already failed: $out"
fi

# Capturing the list to a file makes that file the read loop's stdin, so the
# recipe runs each suite with stdin closed. Without that a suite reading stdin
# consumes the entries queued behind it and the run truncates -- the same green
# partial pass by a second route -- and a suite that prompted would instead hang
# an interactive run on the terminal. This fixture discovers cleanly and asserts
# the guarantee from inside a suite. Two entries are load-bearing: after the
# loop reads a single-entry list there is nothing left to consume, so the
# unclosed case would look identical to the closed one.
git_whole=$SCRATCH/git-whole
mkdir -p "$git_whole"
cat >"$git_whole/git" <<STUB
#!/usr/bin/env bash
set -euo pipefail
if [ "\${1-}" = ls-files ]; then
	printf 'scripts/first-test.sh\0scripts/second-test.sh\0'
	exit 0
fi
exec "$real_git" "\$@"
STUB
chmod +x "$git_whole/git"
whole_suites=$SCRATCH/whole-suites
mkdir -p "$whole_suites/scripts"
cat >"$whole_suites/scripts/first-test.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [ -t 0 ]; then
	printf 'first-test: stdin is the terminal\n' >&2
	exit 1
fi
if IFS= read -r -n 1 byte; then
	printf 'first-test: stdin carried readable input: %s\n' "$byte" >&2
	exit 1
fi
printf 'first-test: stdin is closed\n'
STUB
printf '#!/usr/bin/env bash\nset -euo pipefail\nprintf "second-test: pass\\n"\n' \
	>"$whole_suites/scripts/second-test.sh"
chmod +x "$whole_suites/scripts/first-test.sh" "$whole_suites/scripts/second-test.sh"
status=0
out=$(PATH=$git_whole:$PATH "$just_real" \
	--working-directory "$whole_suites" --justfile "$recipe_root/Justfile" \
	test 2>&1) || status=$?
[ "$status" -eq 0 ] ||
	fail "test: a discovery that completed did not pass the recipe: $out"
printf '%s\n' "$out" | grep -q 'first-test: stdin is closed' ||
	fail "test: a suite was not run with its stdin closed: $out"
printf '%s\n' "$out" | grep -qF 'test: 2 suites passed' ||
	fail "test: the recipe did not run every discovered suite: $out"

# --- scratch-file allocation and cleanup ------------------------------------
# Both halves of the same defect: under the lister's `set -e` an unguarded
# `tracked=$(mktemp)` exits on mktemp's own status and an unguarded EXIT trap
# returns rm's, and exit 1 is the status every consumer reads as "discovery
# broke, distrust this list". So a scratch file this host could not create or
# could not remove reddened the gates with a complete inventory already on
# stdout and only rm's own line to explain it.
#
# The rm shim removes the file for real and then reports failure. A shim that
# merely refused would strand a scratch file outside SCRATCH on every run:
# `mktemp` is called bare here, and on macOS a bare mktemp resolves through the
# per-user temp directory and ignores TMPDIR, so pointing TMPDIR into the
# fixture would not reclaim it. What the cases assert is the status and the
# diagnostic, and both are decided by the removal's status alone.
real_rm=$(command -v rm)
rm_stub=$SCRATCH/rm-fail-bin
mkdir -p "$rm_stub"
cat >"$rm_stub/rm" <<STUB
#!/usr/bin/env bash
"$real_rm" "\$@" || :
printf 'rm-stub: simulated removal failure\n' >&2
exit 1
STUB
chmod +x "$rm_stub/rm"

mktemp_stub=$SCRATCH/mktemp-fail-bin
mkdir -p "$mktemp_stub"
cat >"$mktemp_stub/mktemp" <<'STUB'
#!/usr/bin/env bash
printf 'mktemp-stub: no usable temp directory\n' >&2
exit 1
STUB
chmod +x "$mktemp_stub/mktemp"

# A clean run whose cleanup fails. The inventory is correct and complete, so the
# one thing that must not happen is the finding status.
cleanup_clean=$(new_fixture cleanup_clean)
write_tracked "$cleanup_clean" scripts/hook '#!/usr/bin/env bash
'
status=0
out=$(cd "$cleanup_clean" && PATH="$rm_stub:$PATH" \
	./scripts/list-shell-sources.sh --tabs 2>&1) || status=$?
[ "$status" -eq 2 ] ||
	fail "cleanup_clean: a failed removal on a clean run exited $status, not the fault status 2: $out"
printf '%s\n' "$out" | grep -q '^list-shell-sources: retained scratch path: ' ||
	fail "cleanup_clean: the retained scratch path was not named: $out"
lists "$out" scripts/hook ||
	fail "cleanup_clean: the inventory was not printed: $out"

# The same failed removal over a run that had already found a real fault. The
# fault status outranks nothing here: exit 1 is the answer the run earned and
# cleanup must not overwrite it, in either direction.
cleanup_faulted=$(new_fixture cleanup_faulted)
write_tracked "$cleanup_faulted" scripts/hook '#!/usr/bin/env bash
'
"$real_rm" -- "$cleanup_faulted/scripts/hook"
status=0
out=$(cd "$cleanup_faulted" && PATH="$rm_stub:$PATH" \
	./scripts/list-shell-sources.sh --tabs 2>&1) || status=$?
[ "$status" -eq 1 ] ||
	fail "cleanup_faulted: a failed removal displaced the run's own exit 1 with $status: $out"
printf '%s\n' "$out" | grep -q '^list-shell-sources: scripts/hook is tracked but nothing is there' ||
	fail "cleanup_faulted: the run's own diagnostic was lost: $out"

# The allocation half. Nothing is listed and nothing can be, so the only
# question is whether the status says "this list is short" or "there is no
# list", and whether anything says it under this script's own prefix.
allocation=$(new_fixture allocation)
write_tracked "$allocation" scripts/hook '#!/usr/bin/env bash
'
status=0
out=$(cd "$allocation" && PATH="$mktemp_stub:$PATH" \
	./scripts/list-shell-sources.sh --tabs 2>&1) || status=$?
[ "$status" -eq 2 ] ||
	fail "allocation: a scratch file that could not be created exited $status, not 2: $out"
printf '%s\n' "$out" | grep -q '^list-shell-sources: could not create a scratch file' ||
	fail "allocation: no diagnostic under the script's own prefix: $out"

# The recipes carry the same two halves over their own scratch files, and they
# are where the unguarded form read worst: `just test` printed its summary line
# and then exited 1, so the summary and the verdict disagreed. The lister is
# stubbed out here so the failing rm reaches only the recipe's own cleanup --
# with the real lister in place its cleanup fails first and the recipe never
# gets far enough to have a clean run to protect.
#
# The two listed files are indentation-neutral so one pair satisfies both
# `shfmt` invocations format-check makes, and shellcheck-clean so lint's verdict
# is the recipe's cleanup and not a finding in a fixture.
recipe_clean=$SCRATCH/recipe-clean
mkdir -p "$recipe_clean/scripts" "$recipe_clean/.github/scripts"
cat >"$recipe_clean/scripts/list-shell-sources.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case ${1-} in
--tabs) printf 'scripts/tabbed.sh\0' ;;
--two-space) printf '.github/scripts/twospace.sh\0' ;;
*) printf 'scripts/tabbed.sh\0.github/scripts/twospace.sh\0' ;;
esac
STUB
chmod +x "$recipe_clean/scripts/list-shell-sources.sh"
printf '#!/usr/bin/env bash\nset -euo pipefail\nprintf "tabbed\\n"\n' \
	>"$recipe_clean/scripts/tabbed.sh"
printf '#!/usr/bin/env bash\nset -euo pipefail\nprintf "twospace\\n"\n' \
	>"$recipe_clean/.github/scripts/twospace.sh"
for recipe in lint format-check; do
	status=0
	out=$(PATH="$rm_stub:$PATH" "$just_real" --working-directory "$recipe_clean" \
		--justfile "$recipe_root/Justfile" "$recipe" 2>&1) || status=$?
	[ "$status" -eq 2 ] ||
		fail "$recipe: a failed cleanup on a clean run exited $status, not the fault status 2: $out"
	printf '%s\n' "$out" | grep -q "^$recipe: retained scratch path: " ||
		fail "$recipe: the retained scratch path was not named: $out"
done

# The `test` recipe over the discovery fixture that already passes above, so the
# suites run and the summary prints before cleanup is reached. Both halves are
# asserted here: the summary must still be there -- the run really did pass --
# and the status must still say the recipe could not finish cleanly.
status=0
out=$(PATH="$rm_stub:$git_whole:$PATH" "$just_real" \
	--working-directory "$whole_suites" --justfile "$recipe_root/Justfile" \
	test 2>&1) || status=$?
[ "$status" -eq 2 ] ||
	fail "test: a failed cleanup on a passing run exited $status, not the fault status 2: $out"
printf '%s\n' "$out" | grep -qF 'test: 2 suites passed' ||
	fail "test: the passing run's summary was lost: $out"
printf '%s\n' "$out" | grep -q '^test: retained scratch path: ' ||
	fail "test: the retained scratch path was not named: $out"

printf 'list-shell-sources-test: ok%s\n' "$skipped"
