# shellcheck shell=bash
#
# Scaffold shared by the scripts/*-test.sh suites. Sourced, never executed, so
# it carries no shebang and is not itself a suite.
#
# Every suite here builds disposable fixtures in a scratch directory and needs
# the same three things around them: a directory that is removed however the
# suite exits, a refusal to remove anything else, and a diagnostic carrying the
# suite's name. Five suites had grown their own copy.
#
#   clear_git_env            unsets the variables git reports as
#                            repository-local, so a caller's GIT_DIR or
#                            GIT_INDEX_FILE cannot reach a fixture's `git -C`
#   fixture_init <label>     sets FIXTURE_LABEL, creates SCRATCH under TMPDIR,
#                            and installs the EXIT trap
#   fixture_scratch <prefix> creates a further scratch directory at
#                            "<prefix>XXXXXX", registers it for cleanup, and
#                            reports it in FIXTURE_SCRATCH -- for a fixture
#                            that cannot live under TMPDIR
#   fail <message...>        prints "<label>: <message>" on stderr, exits 1
#
# fixture_scratch reports through a variable rather than stdout because command
# substitution would register the directory in a subshell and lose it.

fixture_scratch_paths=()
fixture_scratch_prefixes=()

clear_git_env() {
	local variable
	while IFS= read -r variable; do
		[ -n "$variable" ] || continue
		unset "$variable"
	done < <(git rev-parse --local-env-vars)
}

fixture_scratch() { # prefix -- sets FIXTURE_SCRATCH
	FIXTURE_SCRATCH=$(mktemp -d "$1"'XXXXXX')
	fixture_scratch_prefixes[${#fixture_scratch_prefixes[@]}]=$1
	fixture_scratch_paths[${#fixture_scratch_paths[@]}]=$FIXTURE_SCRATCH
}

fixture_cleanup() {
	local index=0 path prefix status=0
	while [ "$index" -lt "${#fixture_scratch_paths[@]}" ]; do
		path=${fixture_scratch_paths[$index]}
		prefix=${fixture_scratch_prefixes[$index]}
		index=$((index + 1))
		case $path in
		"$prefix"*) [ ! -d "$path" ] || rm -R -- "$path" ;;
		*)
			printf '%s: refusing to remove unsafe path: %s\n' \
				"$FIXTURE_LABEL" "$path" >&2
			status=1
			;;
		esac
	done
	return "$status"
}

fixture_init() { # label
	FIXTURE_LABEL=$1
	fixture_scratch "${TMPDIR:-/tmp}/$1."
	# shellcheck disable=SC2034 # read by the sourcing suite, not by this file
	SCRATCH=$FIXTURE_SCRATCH
	trap fixture_cleanup EXIT
}

fail() {
	printf '%s: %s\n' "$FIXTURE_LABEL" "$*" >&2
	exit 1
}
