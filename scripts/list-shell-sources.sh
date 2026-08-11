#!/usr/bin/env bash
set -euo pipefail

# Prints the repository's tracked shell sources, one per line (NUL-separated
# with -z). A tracked file is a shell source when its name ends in .sh or its
# first line is a Bash shebang, which covers extensionless executables such as
# scripts/pre-push-hook and the sdd-workspace helpers. The lint, format-check,
# and format recipes consume this list, so wiring a new script into the gates
# requires no recipe edit.
#
# --tabs (default) prints the sources formatted at the repository default.
# --two-space prints the subset formatted with `shfmt -i 2`: .github/scripts/
# and its byte-identical twins under skills/tome-of-lore/assets/.
# --all prints both subsets. Either subset list fails closed when empty: an
# empty inventory means discovery broke, not that nothing needs checking.

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

is_shell_source() {
	local path=$1 first_line
	case $path in
	*.sh) return 0 ;;
	esac
	[[ -f $path ]] || return 1
	IFS= read -r first_line <"$path" || return 1
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
	is_shell_source "$path" || continue
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
