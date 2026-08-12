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

printf 'list-shell-sources-test: ok%s\n' "$skipped"
