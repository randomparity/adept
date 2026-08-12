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

# The case this suite exists for. A tracked file the lister cannot read used to
# be indistinguishable from an empty one -- both a non-zero `read` -- so it left
# the inventory silently and was never linted and never format-checked, with
# nothing reported anywhere. It must fail loudly instead.
#
# Skipped under a uid that ignores the permission bits, which is how the case
# would otherwise pass by not testing anything.
if [ "$(id -u)" -eq 0 ]; then
	printf 'list-shell-sources-test: skipping the unreadable case as root\n'
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
	# The lister's own diagnostic, not bash's redirection error, which is
	# already on stderr today and names the file while the run still exits 0.
	printf '%s\n' "$out" | grep -q '^list-shell-sources: .*scripts/hook' ||
		fail "unreadable: no diagnostic naming the file: $out"
fi

printf 'list-shell-sources-test: ok\n'
