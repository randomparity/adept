#!/usr/bin/env bash
set -euo pipefail

# Prints the repository's tracked shell sources, one per line (NUL-separated
# with -z). A tracked file is a shell source when its name ends in .sh or its
# first line is a Bash shebang, which covers extensionless executables such as
# scripts/pre-push-hook and the sdd-workspace helpers. The lint and format-check
# recipes and the ripgrep-config gate consume this list, so wiring a new script
# into the gates requires no recipe edit.
#
# --tabs (default) prints the sources formatted at the repository default.
# --two-space prints the subset formatted with `shfmt -i 2`: .github/scripts/
# and its byte-identical twins under skills/tome-of-lore/assets/.
# --all prints both subsets.
#
# Two ways to fail closed, both exit 1. An empty subset list means discovery
# broke, not that nothing needs checking. A tracked file that cannot be opened
# is one this script cannot classify, and dropping it would leave it out of an
# inventory whose whole purpose is that no script escapes the gates.
#
# The second one covers every tracked file this script has to open to classify
# -- everything without a `.sh` name, since whether such a file is a script is
# exactly what an unopenable one does not say. So deleting a tracked file
# without staging the deletion reds `just lint`, `just format-check` and the
# `commit-check` hook until it is staged or the file is restored. That is the
# intended reading of an inventory that cannot be trusted, not a broken gate --
# the diagnostic names which case it is. A `.sh` file is classified by name and
# never opened here, so an unopenable one reaches shellcheck and shfmt instead
# and fails there.

mode='tabs'
nul=0
for arg in "$@"; do
	case $arg in
	--tabs) mode='tabs' ;;
	--two-space) mode='two-space' ;;
	--all) mode='all' ;;
	-z) nul=1 ;;
	*)
		printf 'usage: list-shell-sources.sh [--tabs|--two-space|--all] [-z]\n' >&2
		exit 2
		;;
	esac
done

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Regexes in variables: bash 3.2 (the macOS system shell) mis-parses some
# quoted regex literals inside [[ =~ ]].
bash_shebang='^#![[:space:]]*([^[:space:]]*/)?bash([[:space:]]|$)'
env_bash_shebang='^#![[:space:]]*([^[:space:]]*/)?env[[:space:]]+(-S[[:space:]]+)?bash([[:space:]]|$)'

# 0 a shell source, 1 not one, 2 the file could not be opened.
#
# `read` alone cannot answer this. It reports a non-zero status for three
# unrelated things -- a clean EOF on an empty file, a clean EOF on a last line
# with no trailing newline (where the line was read and the file may well be a
# shell source), and a file that could not be opened at all -- and only the last
# is a fault. Testing that status was how an unreadable file left the inventory
# silently, and testing it plus the file's content misreads a tracked binary
# whose first byte is NUL as unreadable, which is a false red on the gates.
#
# So the fault comes from the open, which is the operation that can fail and
# whose status says only whether it did. `read`'s status then decides nothing.
# The braces rather than a subshell keep the descriptor in this shell, and put
# bash's own "Permission denied" behind the redirection -- this script's
# diagnostic is its interface.
#
# The `[[ -f $path ]]` guard this replaces answered "not a regular file" and
# returned the ordinary negative, which collapsed a tracked file missing from
# the worktree, one behind an unsearchable directory and a broken symlink into
# the same silence as a text file -- the defect one line further down. Those
# three reach the open and are reported.
#
# Two shapes must not reach it. A directory is a submodule's gitlink, the one
# non-file git emits here as a matter of course, and it is the ordinary
# negative. Anything else that exists but is not a regular file -- a FIFO left
# where a tracked file used to be is the reachable one -- would block the open
# forever and hang every gate that consumes this list, so it is reported
# instead. Both tests follow symlinks, which is what the open would have done.
is_shell_source() {
	local path=$1 first_line=''
	case $path in
	*.sh) return 0 ;;
	esac
	[[ -d $path ]] && return 1
	[[ -e $path && ! -f $path ]] && return 2
	{ exec 3<"$path"; } 2>/dev/null || return 2
	IFS= read -r first_line <&3 || :
	exec 3<&-
	[[ $first_line =~ $bash_shebang || $first_line =~ $env_bash_shebang ]]
}

is_two_space() {
	case $1 in
	.github/scripts/* | skills/tome-of-lore/assets/*) return 0 ;;
	*) return 1 ;;
	esac
}

# The walk that produces everything below it, captured rather than read from a
# process substitution. `while ... done < <(git ls-files -z)` reports the loop's
# status and never git's, so a listing that stopped partway yielded a short
# inventory and exit 0 -- the same silent miss this script's other two failure
# modes exist to prevent, in its own producer. It is why the lint and
# format-check recipes capture this script's output in turn.
tracked=$(mktemp)
trap 'rm -f "$tracked"' EXIT
git ls-files -z >"$tracked" || {
	printf 'list-shell-sources: could not list the repository'\''s tracked files\n' >&2
	exit 1
}

found=0
while IFS= read -r -d '' path; do
	source_status=0
	is_shell_source "$path" || source_status=$?
	case $source_status in
	0) ;;
	1) continue ;;
	# One fault, four remedies, so four messages. What the script cannot do is
	# the same every time -- say what the file is -- but "stage the deletion",
	# "fix the symlink", "replace the FIFO" and "fix the permissions" are not
	# one instruction, and a message covering all four reads as a broken gate
	# to whoever hits the common one.
	*)
		# Some tracked paths are meant to be absent. A sparse checkout marks
		# what it left out with skip-worktree (`S`), and assume-unchanged shows
		# as a lowercase tag; both are supported configurations, and failing on
		# them would make the repository uncommittable for anyone using one.
		# `git ls-files -v` is asked only about a path that already faulted, so
		# the ordinary walk pays nothing. A probe that answers nothing falls
		# through to the diagnostics rather than deciding.
		#
		# [[:lower:]] rather than [a-z]: under en_US.UTF-8 collation the range
		# a-z matches uppercase letters too, so [a-z] swallowed the ordinary
		# `H` tag and made every fault silent -- the defect this script is
		# about, reintroduced by the guard against it.
		case $(git ls-files -v -- "$path" 2>/dev/null) in
		S* | [[:lower:]]*) continue ;;
		esac
		if [[ -e $path && ! -f $path ]]; then
			printf 'list-shell-sources: %s is tracked but is not a regular file, so it cannot be classified\n' \
				"$path" >&2
		elif [[ -L $path && ! -e $path ]]; then
			printf 'list-shell-sources: %s is a symlink whose target is missing, so it cannot be classified\n' \
				"$path" >&2
		elif [[ -e $path ]]; then
			printf 'list-shell-sources: cannot open %s to classify it; check the permissions on it and on its parent directories\n' \
				"$path" >&2
		else
			printf 'list-shell-sources: %s is tracked but nothing is there to open; restore it, or stage the deletion\n' \
				"$path" >&2
		fi
		exit 1
		;;
	esac
	case $mode in
	tabs) is_two_space "$path" && continue ;;
	two-space) is_two_space "$path" || continue ;;
	esac
	found=1
	if ((nul)); then
		printf '%s\0' "$path"
	else
		printf '%s\n' "$path"
	fi
done <"$tracked"

((found)) || {
	printf 'list-shell-sources: no %s shell sources found\n' "$mode" >&2
	exit 1
}
