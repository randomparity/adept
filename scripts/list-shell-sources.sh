#!/usr/bin/env bash
set -euo pipefail

# Prints the repository's tracked shell sources, one per line (NUL-separated
# with -z). A tracked file is a shell source when its name ends in .sh or its
# first line is a Bash shebang, which covers extensionless executables such as
# scripts/pre-push-hook and the sdd-workspace helpers. The lint and format-check
# recipes consume this list, so wiring a new script into the gates requires no
# recipe edit.
#
# --tabs (default) prints the sources formatted at the repository default.
# --two-space prints the subset formatted with `shfmt -i 2`: .github/scripts/
# and its byte-identical twins under skills/tome-of-lore/assets/.
# --all prints both subsets.
#
# Two ways to fail closed, both exit 1. An empty subset list means discovery
# broke, not that nothing needs checking. A tracked file that cannot be read is
# one this script cannot classify, and dropping it would leave it out of an
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

# 0 a shell source, 1 not one, 2 the file could not be read.
#
# `read` reports a non-zero status three ways that used to collapse into "not a
# shell source": a clean EOF on an empty file, a clean EOF on a last line with
# no trailing newline -- where the line is in the variable and the file is a
# shell source after all -- and a redirection or read that failed outright. Only
# the third is a fault, and it is separated by the two facts the status does not
# carry: whether anything was read, and whether there was anything to read.
is_shell_source() {
	local path=$1 first_line='' status=0
	case $path in
	*.sh) return 0 ;;
	esac
	[[ -f $path ]] || return 1
	IFS= read -r first_line <"$path" || status=$?
	if ((status != 0)) && [[ -z $first_line && -s $path ]]; then
		return 2
	fi
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
		printf 'list-shell-sources: cannot read %s to classify it; dropping it would leave a tracked script neither linted nor format-checked\n' \
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
