# shellcheck shell=bash
#
# Scaffold shared by the behaviour suites under scripts/ and tests/fixtures/
# alike. Sourced, never executed, so it carries no shebang and is not itself a
# suite.
#
# Every suite here builds disposable fixtures in a scratch directory and needs
# the same three things around them: a directory that is removed however the
# suite exits, a refusal to remove anything else, and a diagnostic carrying the
# suite's name. Twelve suites had grown their own copy.
#
# Two groups stay out. The check-records-test.sh pair cannot join:
# `just records` compares .github/scripts/ and skills/tome-of-lore/assets/ byte
# for byte, and the two sit at different depths, so no single relative source
# path resolves from both. The gates themselves -- check-skill-shape.sh,
# check-ripgrep-config.sh, verify-push.sh -- keep their own cleanup deliberately;
# a production gate sourcing a file named test-fixture-helpers.sh is worse
# layering than the duplication it would remove.
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
	local variable variables
	# Reading through process substitution would hide a git that could not
	# answer: the loop reads nothing, the function returns 0, and the caller
	# builds fixtures with the ambient GIT_DIR still set -- a scan that could
	# not run reported as one that found nothing.
	variables=$(git rev-parse --local-env-vars) || {
		printf 'test-fixture-helpers: cannot read git local env vars\n' >&2
		exit 1
	}
	# Empty output is the same failure wearing a zero exit status: git has
	# always named at least GIT_DIR here, so nothing to clear means the answer
	# did not arrive rather than that there was nothing to do.
	[ -n "$variables" ] || {
		printf 'test-fixture-helpers: git reported no local env vars\n' >&2
		exit 1
	}
	while IFS= read -r variable; do
		[ -n "$variable" ] || continue
		unset "$variable"
	done <<<"$variables"
}

fixture_scratch() { # prefix -- sets FIXTURE_SCRATCH
	FIXTURE_SCRATCH=$(mktemp -d "$1"'XXXXXX')
	# The two registries are parallel and must only ever be appended together
	# here: fixture_cleanup bounds its loop on the paths array and indexes the
	# prefixes array with it, so a divergence dereferences an unset index under
	# `set -u` inside an EXIT trap and aborts cleanup mid-loop.
	fixture_scratch_prefixes[${#fixture_scratch_prefixes[@]}]=$1
	fixture_scratch_paths[${#fixture_scratch_paths[@]}]=$FIXTURE_SCRATCH
}

# A fixture this function could not remove reddens the suite. Every sourcing
# suite runs `set -e`, and under it an EXIT trap's non-zero return becomes the
# shell's exit status (checked on bash 3.2.57 and 5.3.15; without `set -e` it is
# discarded instead). So `status` is set at both ends deliberately rather than
# inherited from whatever the loop's last command returned -- writing the
# removal as `[ -d "$path" ] && rm -R -- "$path"` would leave the trap returning
# 1 whenever the last path was already gone, reddening every clean run.
#
# Each entry is independent: one failure must not skip the entries after it,
# because check-public-safety-test.sh registers a fixture inside the working
# tree and it is always last.
#
# The prefix guard is unreachable by construction -- mktemp returns the template
# it was handed, and fixture_scratch records that same template as the prefix --
# so it is defence in depth on the one `rm -R` here, not a live check. The five
# copies it replaces re-derived the prefix at cleanup time and compared it
# against a variable suite code could reassign, which is what made theirs live.
fixture_cleanup() {
	local index=0 path prefix status=0
	while [ "$index" -lt "${#fixture_scratch_paths[@]}" ]; do
		path=${fixture_scratch_paths[$index]}
		prefix=${fixture_scratch_prefixes[$index]}
		index=$((index + 1))
		case $path in
		"$prefix"*)
			if [ -d "$path" ] && ! rm -R -- "$path"; then
				printf '%s: cleanup failed for %s\n' \
					"$FIXTURE_LABEL" "$path" >&2
				status=1
			fi
			;;
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
