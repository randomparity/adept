#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

clear_git_env
fixture_init git-fixture-isolation-test

repo_root=$(cd "$script_dir/.." && pwd -P)

ambient=$SCRATCH/ambient
worktree_one=$SCRATCH/external-one
worktree_two=$SCRATCH/external-two

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

run_suite() {
	local suite=$1 slug before after output state_diff status=0
	slug=${suite//\//-}
	before=$SCRATCH/before
	after=$SCRATCH/after
	output=$SCRATCH/$slug.output
	state_diff=$SCRATCH/$slug.state-diff

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

snapshot_state "$SCRATCH/before"

suites=(
	tests/fixtures/forge/sdd-workspace-test.sh
	tests/fixtures/forge/task-brief-test.sh
	tests/fixtures/forge/review-package-test.sh
	tests/fixtures/quest-log/tracker-test.sh
	.github/scripts/check-records-test.sh
	skills/tome-of-lore/assets/check-records-test.sh
	scripts/check-ripgrep-config-test.sh
	scripts/check-public-safety-test.sh
	scripts/check-plugin-version-test.sh
	scripts/list-shell-sources-test.sh
)

for suite in "${suites[@]}"; do
	run_suite "$suite"
done

# The cases above prove each suite clears the selectors when git answers. These prove the
# two that cannot use clear_git_env stop when it does not. Every other suite above sources
# the helper, whose two failure shapes are pinned in test-fixture-helpers-test.sh; the
# check-records-test.sh pair carries its own copy of the same clearing, because `just
# records` compares .github/scripts/ against skills/tome-of-lore/assets/ byte for byte and
# the two sit at different depths, so no single relative source path resolves from both. A git
# that cannot answer has to stop them rather than leave them building fixtures with the
# ambient GIT_DIR still set.
twins=(
	.github/scripts/check-records-test.sh
	skills/tome-of-lore/assets/check-records-test.sh
)

stub_bin=$SCRATCH/stub-bin
mkdir -p "$stub_bin"

# Each stub answers the one call under test and refuses everything after it. That refusal is
# what keeps a reverted fix cheap to detect: a suite that read the answer through a process
# substitution and carried on reddens at its next git call instead of building seven
# thousand fixtures on its way to the same verdict.
assert_twins_stop() { # <diagnostic> -- $stub_bin/git is already written
	local suite status output
	for suite in "${twins[@]}"; do
		output=$SCRATCH/twin.output
		status=0
		PATH="$stub_bin:$PATH" "$repo_root/$suite" >"$output" 2>&1 || status=$?
		if [ "$status" -eq 0 ]; then
			cat "$output" >&2
			fail "$suite continued after a git that could not answer"
		fi
		if ! grep -qF "$1" "$output"; then
			cat "$output" >&2
			fail "$suite: expected the diagnostic '$1'"
		fi
		if grep -qF 'unexpected call' "$output"; then
			cat "$output" >&2
			fail "$suite ran a further git command after the failed read"
		fi
		printf '  ok   %s stops on %s\n' "$suite" "$1"
	done
}

cat >"$stub_bin/git" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = rev-parse ] && [ "${2:-}" = --local-env-vars ]; then
	printf 'stub git: cannot report the local env vars\n' >&2
	exit 128
fi
printf 'stub git: unexpected call: %s\n' "$*" >&2
exit 127
STUB
chmod +x "$stub_bin/git"
assert_twins_stop 'cannot read git local env vars'

# The same failure wearing a zero exit status.
cat >"$stub_bin/git" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = rev-parse ] && [ "${2:-}" = --local-env-vars ]; then
	exit 0
fi
printf 'stub git: unexpected call: %s\n' "$*" >&2
exit 127
STUB
chmod +x "$stub_bin/git"
assert_twins_stop 'git reported no local env vars'

printf 'git-fixture-isolation-test: all %s suites passed\n' "${#suites[@]}"
