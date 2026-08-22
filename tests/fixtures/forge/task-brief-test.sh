#!/usr/bin/env bash
# Behaviour tests for task-brief's extraction contract and error paths.
#
# task-brief had no coverage before the first-party rewrite, so these were
# written against the pre-rewrite script and proven to fail against mutated
# copies of it. That ordering is what makes them a regression check rather than
# a description of whatever the rewrite produced.
#
# Nothing here asserts the text of a diagnostic. The rewrite is licensed to
# change wording and not behaviour, so the assertions are exit status, which
# stream carried output, the resolved output path, and what the extractor picked
# out of the plan.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$SCRIPT_DIR/../../../scripts/test-fixture-helpers.sh"

# Hooks export repository-local Git variables that override `git -C`. Clear
# Git's complete reported set before any fixture repository is discovered.
clear_git_env

# The suite lives in tests/fixtures/ so it is excluded from the installed
# payload; the script it exercises ships under skills/.
SCRIPT="$SCRIPT_DIR/../../../skills/forge/scripts/task-brief"
WORKSPACE="$SCRIPT_DIR/../../../skills/forge/scripts/sdd-workspace"

passed=0
failed=0
fixture_init task-brief-test

ok() {
	passed=$((passed + 1))
	printf '  ok   %s\n' "$1"
}

# Shadows the helper's fail deliberately: this suite reports every case and
# totals at the end rather than exiting on the first failure.
fail() {
	failed=$((failed + 1))
	printf '  FAIL %s: %s\n' "$1" "$2"
}

# A fresh repository per case, entered before the script runs: task-brief
# resolves its default output path through sdd-workspace, which reads the
# ambient repository. A case that stayed in the checkout would write there.
#
# `pwd -P`, because git reports a resolved toplevel: on macOS TMPDIR sits under
# /var, a symlink to /private/var, so an unresolved fixture path would never
# equal what the script prints.
new_repo() {
	local dir
	dir=$(cd "$(mktemp -d "$SCRATCH/repo.XXXXXX")" && pwd -P)
	git -C "$dir" init -q
	git -C "$dir" config user.email test@example.com
	git -C "$dir" config user.name 'Test'
	printf 'seed\n' >"$dir/README.md"
	git -C "$dir" add README.md
	git -C "$dir" commit -qm 'seed'
	printf '%s\n' "$dir"
}

# The plan every extraction case reads. Task 1 and Task 10 both exist so the
# multi-digit boundary is exercised; the fenced block holds a line that looks
# like a heading and must not be treated as one; heading depths differ.
write_plan() {
	cat >"$1" <<'PLAN'
# A plan

Preamble that belongs to no task.

## Task 1 — first

first body line

```sh
# Task 99 inside a fence is not a heading
echo hello
```

still first

## Task 10 — tenth

tenth body

#### Task 2 — second at depth four

second body

PLAN
}

# --- the ordinary path -------------------------------------------------------

case_writes_named_outfile() {
	local name='writes the named outfile and reports it on stdout'
	local repo out got status=0
	repo=$(new_repo)
	write_plan "$repo/plan.md"
	out="$repo/brief.md"
	got=$(cd "$repo" && "$SCRIPT" plan.md 1 "$out" 2>/dev/null) || status=$?
	if [ "$status" -ne 0 ]; then
		fail "$name" "exited $status"
		return
	fi
	if [ ! -s "$out" ]; then
		fail "$name" 'wrote no content'
		return
	fi
	case "$got" in
	*"$out"*) ;;
	*)
		fail "$name" "stdout did not name the outfile: $got"
		return
		;;
	esac
	if [ "$(printf '%s\n' "$got" | wc -l | tr -d ' ')" != 1 ]; then
		fail "$name" 'stdout was not a single line'
		return
	fi
	ok "$name"
}

case_default_path_uses_workspace() {
	local name='default outfile lands in the sdd workspace'
	local repo dir expected status=0
	repo=$(new_repo)
	write_plan "$repo/plan.md"
	dir=$(cd "$repo" && "$WORKSPACE")
	expected="$dir/task-1-brief.md"
	(cd "$repo" && "$SCRIPT" plan.md 1 >/dev/null 2>&1) || status=$?
	if [ "$status" -ne 0 ]; then
		fail "$name" "exited $status"
		return
	fi
	if [ -s "$expected" ]; then
		ok "$name"
	else
		fail "$name" "nothing at $expected"
	fi
}

# --- extraction semantics ----------------------------------------------------

# Each of these reads the brief rather than the diagnostics, so none of them
# constrains the rewrite's wording.
extract() {
	local repo=$1 n=$2 out
	out="$repo/brief-$n.md"
	(cd "$repo" && "$SCRIPT" plan.md "$n" "$out" >/dev/null 2>&1)
	cat "$out"
}

case_multi_digit_boundary() {
	local name='Task 1 does not swallow Task 10'
	local repo body
	repo=$(new_repo)
	write_plan "$repo/plan.md"
	body=$(extract "$repo" 1)
	case "$body" in
	*'tenth body'*)
		fail "$name" 'Task 1 captured Task 10'
		return
		;;
	esac
	case "$body" in
	*'first body line'*) ok "$name" ;;
	*) fail "$name" 'Task 1 missed its own body' ;;
	esac
}

case_fenced_heading_is_not_a_heading() {
	local name='a Task line inside a fence does not end the task'
	local repo body
	repo=$(new_repo)
	write_plan "$repo/plan.md"
	body=$(extract "$repo" 1)
	case "$body" in
	*'still first'*) ok "$name" ;;
	*) fail "$name" 'the fenced Task line truncated the body' ;;
	esac
}

case_body_ends_at_next_heading() {
	local name='a body stops at the next Task heading'
	local repo body
	repo=$(new_repo)
	write_plan "$repo/plan.md"
	body=$(extract "$repo" 10)
	case "$body" in
	*'second body'*)
		fail "$name" 'Task 10 ran into Task 2'
		return
		;;
	esac
	case "$body" in
	*'tenth body'*) ok "$name" ;;
	*) fail "$name" 'Task 10 missed its own body' ;;
	esac
}

case_any_heading_depth_matches() {
	local name='a task heading matches at any depth'
	local repo body
	repo=$(new_repo)
	write_plan "$repo/plan.md"
	body=$(extract "$repo" 2)
	case "$body" in
	*'second body'*) ok "$name" ;;
	*) fail "$name" 'the depth-four heading did not match' ;;
	esac
}

case_final_task_runs_to_eof() {
	local name='the final task runs to end of file'
	local repo out
	repo=$(new_repo)
	printf '# Plan\n\n## Task 7 — last\n\nlast body\n' >"$repo/plan.md"
	out="$repo/brief.md"
	(cd "$repo" && "$SCRIPT" plan.md 7 "$out" >/dev/null 2>&1)
	if grep -q 'last body' "$out"; then
		ok "$name"
	else
		fail "$name" 'the final task lost its body'
	fi
}

# --- error paths -------------------------------------------------------------

# Asserts the status and that the complaint went to stderr, never its wording.
expect_error() {
	local name=$1 repo=$2 want=$3
	shift 3
	local err out status=0
	err="$repo/stderr"
	out=$(cd "$repo" && "$SCRIPT" "$@" 2>"$err") || status=$?
	if [ "$status" -ne "$want" ]; then
		fail "$name" "exited $status, wanted $want"
		return 1
	fi
	if [ ! -s "$err" ]; then
		fail "$name" 'said nothing on stderr'
		return 1
	fi
	if [ -n "$out" ]; then
		fail "$name" "wrote to stdout on the error path: $out"
		return 1
	fi
	return 0
}

case_too_few_arguments() {
	local name='too few arguments exits 2'
	local repo
	repo=$(new_repo)
	expect_error "$name" "$repo" 2 plan.md && ok "$name"
}

case_too_many_arguments() {
	local name='too many arguments exits 2'
	local repo
	repo=$(new_repo)
	write_plan "$repo/plan.md"
	expect_error "$name" "$repo" 2 plan.md 1 a b && ok "$name"
}

case_missing_plan_file() {
	local name='a missing plan file exits 2'
	local repo
	repo=$(new_repo)
	expect_error "$name" "$repo" 2 absent.md 1 "$repo/out.md" && ok "$name"
}

case_task_not_found() {
	local name='an absent task exits 3'
	local repo
	repo=$(new_repo)
	write_plan "$repo/plan.md"
	expect_error "$name" "$repo" 3 plan.md 42 "$repo/out.md" && ok "$name"
}

case_not_found_leaves_empty_outfile() {
	local name='exit 3 leaves the outfile behind, empty'
	local repo out status=0
	repo=$(new_repo)
	write_plan "$repo/plan.md"
	out="$repo/out.md"
	(cd "$repo" && "$SCRIPT" plan.md 42 "$out" >/dev/null 2>&1) || status=$?
	if [ "$status" -ne 3 ]; then
		fail "$name" "exited $status, wanted 3"
		return
	fi
	# The awk redirect creates the file before the emptiness test runs. That is
	# observable behaviour a caller can trip over, so it is pinned rather than
	# left to chance.
	if [ ! -e "$out" ]; then
		fail "$name" 'no outfile was created'
		return
	fi
	if [ -s "$out" ]; then
		fail "$name" 'the outfile was not empty'
		return
	fi
	ok "$name"
}

# task-brief already fails closed on an unwritable destination -- the awk
# redirect's failure trips `set -e` and the script exits 1 -- but nothing
# pinned that, so a sibling rewrite could have silently changed it. This is
# the same case review-package's suite gained when its write stopped being
# checked: exit 1, stderr only, no success line.
case_unwritable_destination() {
	local name='an unwritable destination exits nonzero'
	local repo dir
	repo=$(new_repo)
	fixture_scratch task-brief-locked
	dir="$FIXTURE_SCRATCH/locked"
	mkdir "$dir"
	chmod 555 "$dir"
	write_plan "$repo/plan.md"
	# The if, not `&&`, so a red run keeps the suite's report-everything shape.
	if expect_error "$name" "$repo" 1 plan.md 1 "$dir/out.md"; then
		ok "$name"
	fi
}

printf 'task-brief\n\n'
case_writes_named_outfile
case_default_path_uses_workspace
case_multi_digit_boundary
case_fenced_heading_is_not_a_heading
case_body_ends_at_next_heading
case_any_heading_depth_matches
case_final_task_runs_to_eof
case_too_few_arguments
case_too_many_arguments
case_missing_plan_file
case_task_not_found
case_not_found_leaves_empty_outfile
case_unwritable_destination

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
