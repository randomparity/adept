#!/usr/bin/env bash
set -euo pipefail

while IFS= read -r variable; do
	[ -n "$variable" ] || continue
	unset "$variable"
done < <(git rev-parse --local-env-vars)

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp_prefix=${TMPDIR:-/tmp}/git-fixture-isolation-test.
tmp_root=$(mktemp -d "$tmp_prefix"'XXXXXX')

cleanup() {
	case $tmp_root in
	"$tmp_prefix"*)
		[ ! -d "$tmp_root" ] || rm -R -- "$tmp_root"
		;;
	*)
		printf 'git-fixture-isolation-test: refusing to remove unsafe path: %s\n' \
			"$tmp_root" >&2
		return 1
		;;
	esac
}
trap cleanup EXIT

ambient=$tmp_root/ambient
worktree_one=$tmp_root/external-one
worktree_two=$tmp_root/external-two

git init -q -b main "$ambient"
git -C "$ambient" config user.name 'Ambient Developer'
git -C "$ambient" config user.email ambient@example.invalid
printf 'ambient seed\n' >"$ambient/README.md"
git -C "$ambient" add README.md
git -C "$ambient" commit -qm 'ambient seed'
git -C "$ambient" worktree add -qb external-one "$worktree_one"
git -C "$ambient" worktree add -qb external-two "$worktree_two"

ambient_git_dir=$(git -C "$ambient" rev-parse --absolute-git-dir)
common_dir=$ambient_git_dir
worktree_one_git_dir=$(git -C "$worktree_one" rev-parse --absolute-git-dir)
worktree_two_git_dir=$(git -C "$worktree_two" rev-parse --absolute-git-dir)
worktree_one_index=$worktree_one_git_dir/index

snapshot_worktree() {
	local path=$1 git_dir=$2 destination=$3
	mkdir -p "$destination"
	git --git-dir="$git_dir" rev-parse HEAD >"$destination/head"
	git --git-dir="$git_dir" --work-tree="$path" ls-files --stage >"$destination/index"
	git --git-dir="$git_dir" --work-tree="$path" \
		status --porcelain=v1 --untracked-files=all >"$destination/status"
	cksum "$path/README.md" >"$destination/readme"
}

snapshot_state() {
	local destination=$1
	mkdir -p "$destination"
	git config --file "$common_dir/config" --list --show-origin \
		>"$destination/common-config"
	git config --file "$common_dir/config" user.name >"$destination/user-name"
	git config --file "$common_dir/config" user.email >"$destination/user-email"
	git --git-dir="$common_dir" worktree list --porcelain >"$destination/worktrees"
	snapshot_worktree "$ambient" "$ambient_git_dir" "$destination/ambient"
	snapshot_worktree "$worktree_one" "$worktree_one_git_dir" \
		"$destination/external-one"
	snapshot_worktree "$worktree_two" "$worktree_two_git_dir" \
		"$destination/external-two"
}

fail() {
	printf 'git-fixture-isolation-test: %s\n' "$*" >&2
	exit 1
}

run_suite() {
	local suite=$1 slug before after output state_diff status=0
	slug=${suite//\//-}
	before=$tmp_root/before
	after=$tmp_root/after
	output=$tmp_root/$slug.output
	state_diff=$tmp_root/$slug.state-diff

	if [ -d "$after" ]; then
		rm -R -- "$after"
	fi
	env GIT_DIR="$worktree_one_git_dir" \
		GIT_COMMON_DIR="$common_dir" \
		GIT_WORK_TREE="$worktree_one" \
		GIT_INDEX_FILE="$worktree_one_index" \
		GIT_CONFIG="$common_dir/config" \
		"$repo_root/$suite" >"$output" 2>&1 || status=$?

	snapshot_state "$after"
	if ! diff -ru "$before" "$after" >"$state_diff"; then
		cat "$output" >&2
		cat "$state_diff" >&2
		fail "$suite changed the disposable ambient repository"
	fi
	if [ "$status" -ne 0 ]; then
		cat "$output" >&2
		fail "$suite exited $status under the hook-shaped environment"
	fi
	printf '  ok   %s\n' "$suite"
}

snapshot_state "$tmp_root/before"

suites=(
	tests/fixtures/forge/sdd-workspace-test.sh
	tests/fixtures/quest-log/tracker-test.sh
	.github/scripts/check-records-test.sh
	skills/tome-of-lore/assets/check-records-test.sh
	scripts/check-ripgrep-config-test.sh
	scripts/check-public-safety-test.sh
)

for suite in "${suites[@]}"; do
	run_suite "$suite"
done

printf 'git-fixture-isolation-test: all %s suites passed\n' "${#suites[@]}"
