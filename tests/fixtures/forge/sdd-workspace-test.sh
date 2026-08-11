#!/usr/bin/env bash
# Regression tests for sdd-workspace's ignore-file contract.
#
# The path move to .agent/ is already covered by check-skill-layout.sh, which
# scans all shipped content -- reverting a path here fails that gate. What no
# gate can see is the behaviour: that the ignore file is written at .agent/ and
# not .agent/sdd/, that a tracked ignore file is never modified, that a tracked
# ignore file which already covers the workspace is not treated as fatal, and
# that an unanswerable git query stops the run instead of clobbering. Those are
# what this suite pins (ADR 0027).

set -euo pipefail

# Hooks export repository-local Git variables that override `git -C`. Clear
# Git's complete reported set before any fixture repository is discovered.
while IFS= read -r variable; do
	[ -n "$variable" ] || continue
	unset "$variable"
done < <(git rev-parse --local-env-vars)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# The suite lives in tests/fixtures/ so it is excluded from the installed
# payload; the script it exercises ships under skills/.
SCRIPT="$SCRIPT_DIR/../../../skills/forge/scripts/sdd-workspace"

passed=0
failed=0
workdir=$(mktemp -d "${TMPDIR:-/tmp}/sdd-workspace-test.XXXXXX")
trap 'rm -rf "$workdir"' EXIT

ok() {
	passed=$((passed + 1))
	printf '  ok   %s\n' "$1"
}

fail() {
	failed=$((failed + 1))
	printf '  FAIL %s: %s\n' "$1" "$2"
}

# A fresh repository per case: these tests turn on index state, so sharing one
# would let an earlier case decide a later one's result.
new_repo() {
	local dir
	# `pwd -P`, because git reports a resolved toplevel: on macOS TMPDIR sits under
	# /var, a symlink to /private/var, so an unresolved fixture path would never
	# equal what the script prints.
	dir=$(cd "$(mktemp -d "$workdir/repo.XXXXXX")" && pwd -P)
	git -C "$dir" init -q
	git -C "$dir" config user.email test@example.com
	git -C "$dir" config user.name 'Test'
	printf 'seed\n' >"$dir/README.md"
	git -C "$dir" add README.md
	git -C "$dir" commit -qm 'seed'
	printf '%s\n' "$dir"
}

# --- the ordinary path -------------------------------------------------------

case_untracked_repo() {
	local name='untracked repo gets a self-ignoring .agent/.gitignore'
	local repo out
	repo=$(new_repo)

	if ! out=$(cd "$repo" && "$SCRIPT" 2>&1); then
		fail "$name" "script exited non-zero: $out"
		return
	fi
	[ "$out" = "$repo/.agent/sdd" ] ||
		{
			fail "$name" "printed '$out', wanted '$repo/.agent/sdd'"
			return
		}
	[ -d "$repo/.agent/sdd" ] ||
		{
			fail "$name" 'workspace directory was not created'
			return
		}
	# At .agent/, never .agent/sdd/ -- a per-subdirectory ignore file would leave
	# a sibling .agent/campaigns/ written later by $campaign uncovered.
	[ -f "$repo/.agent/.gitignore" ] ||
		{
			fail "$name" 'ignore file is not at .agent/.gitignore'
			return
		}
	[ ! -e "$repo/.agent/sdd/.gitignore" ] ||
		{
			fail "$name" 'ignore file was written per-subdirectory'
			return
		}
	[ "$(cat "$repo/.agent/.gitignore")" = '*' ] ||
		{
			fail "$name" 'ignore file does not contain *'
			return
		}
	[ -z "$(git -C "$repo" status --porcelain)" ] ||
		{
			fail "$name" "working tree is dirty: $(git -C "$repo" status --porcelain)"
			return
		}

	ok "$name"
}

case_sibling_state_covered() {
	local name='a sibling .agent/campaigns/ is ignored by the same file'
	local repo
	repo=$(new_repo)
	(cd "$repo" && "$SCRIPT" >/dev/null)

	mkdir -p "$repo/.agent/campaigns"
	printf 'manifest\n' >"$repo/.agent/campaigns/x.md"
	if git -C "$repo" check-ignore -q .agent/campaigns/x.md; then
		ok "$name"
	else
		fail "$name" 'campaign manifest is not ignored'
	fi
}

case_idempotent_no_residue() {
	local name='re-running leaves no temp residue'
	local repo residue
	repo=$(new_repo)
	(cd "$repo" && "$SCRIPT" >/dev/null)
	(cd "$repo" && "$SCRIPT" >/dev/null)

	residue=$(find "$repo/.agent" -maxdepth 1 -name '.gitignore.*' | wc -l | tr -d ' ')
	if [ "$residue" = 0 ]; then
		ok "$name"
	else
		fail "$name" "$residue temp file(s) left behind"
	fi
}

# --- the tracked-ignore-file paths -------------------------------------------

# Commit a .agent/.gitignore with the given contents, then run the script.
repo_tracking_ignore() {
	local dir
	dir=$(new_repo)
	mkdir -p "$dir/.agent"
	printf '%s\n' "$1" >"$dir/.agent/.gitignore"
	git -C "$dir" add -f .agent/.gitignore
	git -C "$dir" commit -qm 'repo tracks its own .agent/.gitignore'
	printf '%s\n' "$dir"
}

case_tracked_and_covering_succeeds() {
	local name='tracked ignore file that already covers the workspace is not fatal'
	local repo
	repo=$(repo_tracking_ignore '*')

	if (cd "$repo" && "$SCRIPT" >/dev/null 2>&1); then
		# The tracked file must come back byte-identical.
		if [ "$(cat "$repo/.agent/.gitignore")" = '*' ] &&
			[ -z "$(git -C "$repo" status --porcelain)" ]; then
			ok "$name"
		else
			fail "$name" 'the tracked ignore file was modified'
		fi
	else
		fail "$name" 'refused to run even though the workspace was already ignored'
	fi
}

case_tracked_and_exposing_refuses() {
	local name='tracked ignore file that leaves the workspace exposed refuses'
	local repo got=0 out
	repo=$(repo_tracking_ignore 'unrelated-entry')

	out=$(cd "$repo" && "$SCRIPT" 2>&1) || got=$?
	if [ "$got" != 1 ]; then
		fail "$name" "exited $got, wanted 1"
		return
	fi
	case "$out" in
	*'refusing to modify it'*) ;;
	*)
		fail "$name" "message did not name the refusal: $out"
		return
		;;
	esac
	[ "$(cat "$repo/.agent/.gitignore")" = 'unrelated-entry' ] ||
		{
			fail "$name" 'the tracked ignore file was overwritten'
			return
		}

	ok "$name"
}

case_outside_a_repository_stops() {
	local name='a directory that is not a repository stops the run'
	local dir got=0
	dir=$(mktemp -d "$workdir/bare.XXXXXX")

	(cd "$dir" && "$SCRIPT" >/dev/null 2>&1) || got=$?
	if [ "$got" != 0 ]; then
		# and it must not have created state on the way out
		if [ ! -e "$dir/.agent" ]; then
			ok "$name"
		else
			fail "$name" 'created .agent/ outside a repository'
		fi
	else
		fail "$name" 'exited 0 outside a repository'
	fi
}

case_unanswerable_git_query_stops() {
	local name='an unanswerable git query stops rather than clobbering'
	local repo got=0 out
	repo=$(new_repo)
	# rev-parse --show-toplevel does not read the index, so it still succeeds while
	# ls-files exits 128. That is the gap a boolean test of ls-files would fold
	# into "untracked" and write straight through.
	chmod 000 "$repo/.git/index"

	out=$(cd "$repo" && "$SCRIPT" 2>&1) || got=$?
	chmod 644 "$repo/.git/index"

	if [ "$got" != 1 ]; then
		fail "$name" "exited $got, wanted 1"
		return
	fi
	case "$out" in
	*'cannot determine whether'*) ok "$name" ;;
	*) fail "$name" "message did not name the unanswered query: $out" ;;
	esac
}

case_failed_write_leaves_no_residue() {
	local name='a failed ignore write leaves no temp file behind'
	local repo got=0 residue
	repo=$(new_repo)
	# An unwritable target makes the rename fail after the temp file exists --
	# the window the EXIT trap covers. Portable POSIX permissions rather than a
	# signal, so the case is deterministic instead of timing-dependent.
	mkdir -p "$repo/.agent/.gitignore"
	chmod 500 "$repo/.agent/.gitignore"

	(cd "$repo" && "$SCRIPT" >/dev/null 2>&1) || got=$?
	chmod 700 "$repo/.agent/.gitignore"

	if [ "$got" = 0 ]; then
		fail "$name" 'exited 0 despite an unwritable ignore path'
		return
	fi
	residue=$(find "$repo/.agent" -maxdepth 1 -name '.gitignore.*' | wc -l | tr -d ' ')
	if [ "$residue" = 0 ]; then
		ok "$name"
	else
		fail "$name" "$residue temp file(s) survived the failed write"
	fi
}

printf 'sdd-workspace\n\n'
case_untracked_repo
case_sibling_state_covered
case_idempotent_no_residue
case_tracked_and_covering_succeeds
case_tracked_and_exposing_refuses
case_outside_a_repository_stops
# Both remaining cases make a path unreadable or unwritable to reach their
# branch, and root ignores those bits -- they would pass while proving nothing,
# so skip them loudly rather than bank a false green (ADR 0023).
if [ "$(id -u)" -eq 0 ]; then
	printf '  skip run as root: the permission-dependent cases prove nothing\n'
else
	case_unanswerable_git_query_stops
	case_failed_write_leaves_no_residue
fi

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
