#!/usr/bin/env bash
# Behaviour tests for review-package's output contract and error paths.
#
# review-package had no coverage before the first-party rewrite, so these were
# written against the pre-rewrite script and proven to fail against mutated
# copies of it. That ordering is what makes them a regression check rather than
# a description of whatever the rewrite produced.
#
# Nothing here asserts the text of a diagnostic, and nothing asserts the wording
# of the status line beyond the path it has to name. What is pinned is the exit
# status, which stream carried output, where the file landed, and the structure
# written into it -- the headings are file content the reviewer reads, not
# messages, so they are frozen while the diagnostics are not.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$SCRIPT_DIR/../../../scripts/test-fixture-helpers.sh"

# Hooks export repository-local Git variables that override `git -C`. Clear
# Git's complete reported set before any fixture repository is discovered.
clear_git_env

# The suite lives in tests/fixtures/ so it is excluded from the installed
# payload; the script it exercises ships under skills/.
SCRIPT="$SCRIPT_DIR/../../../skills/forge/scripts/review-package"
WORKSPACE="$SCRIPT_DIR/../../../skills/forge/scripts/sdd-workspace"

passed=0
failed=0
fixture_init review-package-test

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

# A fresh repository per case, entered before the script runs. review-package
# resolves BASE and HEAD against the ambient repository, so a case left in the
# checkout would review adept's own history instead of the fixture's.
#
# `pwd -P`, because git reports a resolved toplevel: on macOS TMPDIR sits under
# /var, a symlink to /private/var, so an unresolved fixture path would never
# equal what sdd-workspace prints.
new_repo() {
	local dir
	dir=$(cd "$(mktemp -d "$SCRATCH/repo.XXXXXX")" && pwd -P)
	git -C "$dir" init -q
	git -C "$dir" config user.email test@example.com
	git -C "$dir" config user.name 'Test'
	printf 'seed\n' >"$dir/README.md"
	git -C "$dir" add README.md
	# A file long enough for the context width to be observable. The edit below
	# lands on ledger-15, so ten lines of context reaches ledger-05 and three
	# lines does not -- which is what lets a case distinguish -U10 from a
	# narrower setting instead of merely asserting a diff body exists.
	seq -f 'ledger-%02g' 1 30 >"$dir/ledger.txt"
	git -C "$dir" add README.md ledger.txt
	git -C "$dir" commit -qm 'seed'
	printf 'second\n' >>"$dir/README.md"
	printf 'new file\n' >"$dir/added.txt"
	sed 's/^ledger-15$/ledger-15-CHANGED/' "$dir/ledger.txt" >"$dir/ledger.next"
	mv "$dir/ledger.next" "$dir/ledger.txt"
	git -C "$dir" add README.md added.txt ledger.txt
	git -C "$dir" commit -qm 'second commit'
	printf '%s\n' "$dir"
}

# --- the ordinary path -------------------------------------------------------

case_writes_named_outfile() {
	local name='writes the named outfile and reports it on stdout'
	local repo out got status=0
	repo=$(new_repo)
	out="$repo/pkg.diff"
	got=$(cd "$repo" && "$SCRIPT" HEAD~1 HEAD "$out" 2>/dev/null) || status=$?
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

case_package_carries_its_sections() {
	local name='the package carries its four sections'
	local repo out section
	repo=$(new_repo)
	out="$repo/pkg.diff"
	(cd "$repo" && "$SCRIPT" HEAD~1 HEAD "$out" >/dev/null 2>&1)
	# File content the reviewer navigates by, not diagnostics: frozen.
	for section in '# Review package:' '## Commits' '## Files changed' '## Diff'; do
		if ! grep -qF "$section" "$out"; then
			fail "$name" "missing section: $section"
			return
		fi
	done
	ok "$name"
}

case_package_carries_the_range_content() {
	local name='the package carries the commits, the stat and the diff'
	local repo out
	repo=$(new_repo)
	out="$repo/pkg.diff"
	(cd "$repo" && "$SCRIPT" HEAD~1 HEAD "$out" >/dev/null 2>&1)
	if ! grep -qF 'second commit' "$out"; then
		fail "$name" 'the commit subject is absent'
		return
	fi
	# A summary line only --stat emits. Asserting the filename instead would
	# pass on a package with no stat at all, because the diff body names every
	# changed file too.
	if ! grep -qE '^[[:space:]]*[0-9]+ files? changed' "$out"; then
		fail "$name" 'the diffstat summary is absent'
		return
	fi
	if ! grep -q '^+new file' "$out"; then
		fail "$name" 'the diff body is absent'
		return
	fi
	# Ten lines of context either side of the ledger-15 edit reaches ledger-05.
	# This is the only case that fails if the context width narrows, and the
	# width is the whole reason the script passes -U10 rather than defaulting.
	if ! grep -qE '^[ +-]ledger-05$' "$out"; then
		fail "$name" 'the wide context is absent -- did -U10 change?'
		return
	fi
	ok "$name"
}

case_default_path_uses_workspace() {
	local name='default outfile lands in the sdd workspace, named for the range'
	local repo dir from to expected status=0
	repo=$(new_repo)
	dir=$(cd "$repo" && "$WORKSPACE")
	# Ask git for the abbreviation rather than slicing seven characters: the
	# width moves with core.abbrev and with repository size.
	from=$(git -C "$repo" rev-parse --short HEAD~1)
	to=$(git -C "$repo" rev-parse --short HEAD)
	expected="$dir/review-$from..$to.diff"
	(cd "$repo" && "$SCRIPT" HEAD~1 HEAD >/dev/null 2>&1) || status=$?
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
	expect_error "$name" "$repo" 2 HEAD && ok "$name"
}

case_too_many_arguments() {
	local name='too many arguments exits 2'
	local repo
	repo=$(new_repo)
	expect_error "$name" "$repo" 2 HEAD~1 HEAD a b && ok "$name"
}

case_unresolvable_base() {
	local name='an unresolvable BASE exits 2'
	local repo
	repo=$(new_repo)
	expect_error "$name" "$repo" 2 no-such-ref HEAD "$repo/out.diff" && ok "$name"
}

case_unresolvable_head() {
	local name='an unresolvable HEAD exits 2'
	local repo
	repo=$(new_repo)
	expect_error "$name" "$repo" 2 HEAD~1 no-such-ref "$repo/out.diff" && ok "$name"
}

case_bad_base_writes_nothing() {
	local name='a rejected range writes no package'
	local repo out status=0
	repo=$(new_repo)
	out="$repo/out.diff"
	(cd "$repo" && "$SCRIPT" no-such-ref HEAD "$out" >/dev/null 2>&1) || status=$?
	if [ "$status" -ne 2 ]; then
		fail "$name" "exited $status, wanted 2"
		return
	fi
	if [ -e "$out" ]; then
		fail "$name" 'a package was written for a rejected range'
		return
	fi
	ok "$name"
}

printf 'review-package\n\n'
case_writes_named_outfile
case_package_carries_its_sections
case_package_carries_the_range_content
case_default_path_uses_workspace
case_too_few_arguments
case_too_many_arguments
case_unresolvable_base
case_unresolvable_head
case_bad_base_writes_nothing

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
