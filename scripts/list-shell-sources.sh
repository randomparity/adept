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
# There is no `[[ -f $path ]]` guard ahead of it, and its absence is the point.
# git lists the path, so something is meant to be there; a test that answers
# "not a regular file" collapses a tracked file missing from the worktree, one
# behind an unsearchable directory, and a broken symlink into the same silent
# negative as a text file, which is the defect one line further down. Let the
# open report each of them. A submodule's gitlink is the one ordinary non-file
# git emits here, and it is a directory, so it is named rather than opened.
is_shell_source() {
	local path=$1 first_line=''
	case $path in
	*.sh) return 0 ;;
	esac
	[[ -d $path ]] && return 1
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

found=0
while IFS= read -r -d '' path; do
	source_status=0
	is_shell_source "$path" || source_status=$?
	case $source_status in
	0) ;;
	1) continue ;;
	*)
		printf 'list-shell-sources: cannot open %s to classify it; dropping it would leave a tracked script neither linted nor format-checked\n' \
			"$path" >&2
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
done < <(git ls-files -z)

((found)) || {
	printf 'list-shell-sources: no %s shell sources found\n' "$mode" >&2
	exit 1
}
