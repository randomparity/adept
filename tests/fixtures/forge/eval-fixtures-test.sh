#!/usr/bin/env bash
# Behaviour suite for tests/fixtures/forge/eval-fixtures.sh.
#
# The evaluation cases themselves are judged by a fresh evaluator, never by this suite. What is
# pinned here is that each fixture is built deterministically and has the git shape the spec's
# table claims for it -- an evaluation run against a mis-built fixture measures nothing, and
# would do so silently.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$SCRIPT_DIR/../../../scripts/test-fixture-helpers.sh"

# Hooks export repository-local Git variables that override `git -C`. Clear
# Git's complete reported set before any fixture repository is discovered.
clear_git_env

fixture_init eval-fixtures-test

SCRIPT="$SCRIPT_DIR/eval-fixtures.sh"
[ -x "$SCRIPT" ] || fail "not executable: $SCRIPT"

build() { # shape -- sets REPO
	REPO="$SCRATCH/$1"
	"$SCRIPT" "$1" "$REPO" >/dev/null
}

trailers() { # rev-range
	git -C "$REPO" log --format='%(trailers:key=Forge-Dispatch,valueonly,separator=%x2C)' "$1"
}

changed() { # rev-range
	git -C "$REPO" diff --no-renames --name-only "$1"
}

# The evaluator's non-git input has to be built too, or the cases drift between runs -- and a
# fixed report would tell the evaluator a tests-only task changed an implementation file.
assert_artefacts() { # label
	local artefact
	for artefact in inventory.md inventory-not-applicable.md inventory-dirty.md report.md; do
		[ -f "$REPO/$artefact" ] || fail "$1: $artefact not emitted"
	done
	grep -q 'impl-test.sh' "$REPO/inventory.md" || fail "$1: inventory names no test file"
	grep -q 'task-test-not-applicable' "$REPO/inventory-not-applicable.md" ||
		fail "$1: not-applicable inventory does not carry that mode"
	grep -q '>>impl-test.sh' "$REPO/inventory-dirty.md" ||
		fail "$1: dirty inventory's command does not modify a tracked path"
	grep -q 'printf "' "$REPO/inventory-dirty.md" ||
		fail "$1: dirty inventory appends a bare word, which breaks the runner before the residue check"
	grep -q "$(git -C "$REPO" rev-parse --short HEAD)" "$REPO/report.md" ||
		fail "$1: report does not name the task commit"
}

status=0
"$SCRIPT" >/dev/null 2>&1 || status=$?
[ "$status" -eq 2 ] || fail "no arguments: expected exit 2, got $status"

status=0
"$SCRIPT" nosuch "$SCRATCH/nosuch" >/dev/null 2>&1 || status=$?
[ "$status" -eq 2 ] || fail "unknown shape: expected exit 2, got $status"

build normal
[ "$(trailers -1)" = "task-4.1" ] || fail "normal: trailer is $(trailers -1)"
[ "$(changed 'HEAD~1..HEAD' | sort | tr '\n' ' ')" = "impl-test.sh impl.sh " ] ||
	fail "normal: changed set is $(changed 'HEAD~1..HEAD' | tr '\n' ' ')"

assert_artefacts normal

build tests-only
[ "$(changed 'HEAD~1..HEAD' | tr -d '\n')" = "impl-test.sh" ] ||
	fail "tests-only: changed set is $(changed 'HEAD~1..HEAD' | tr '\n' ' ')"
assert_artefacts tests-only
grep -q 'Changed: impl-test.sh' "$REPO/report.md" ||
	fail "tests-only: report claims a shape the repository does not have"

build no-trailer
[ -z "$(trailers -1)" ] || fail "no-trailer: carries $(trailers -1)"

build foreign-unit
[ "$(trailers -1)" = "task-9.1" ] || fail "foreign-unit: trailer is $(trailers -1)"
assert_artefacts foreign-unit
[ ! -f "$REPO/report-late.md" ] ||
	fail "foreign-unit: emitted a late report for a shape with no race"

build both-attempts
[ "$(trailers 'HEAD~2..HEAD' | sort | tr '\n' ' ')" = "task-4.1 task-4.2 " ] ||
	fail "both-attempts: trailers are $(trailers 'HEAD~2..HEAD' | tr '\n' ' ')"
assert_artefacts both-attempts
[ -f "$REPO/report-late.md" ] || fail "both-attempts: no late report to reconcile against"
grep -q "$(git -C "$REPO" rev-parse --short 'HEAD~1')" "$REPO/report-late.md" ||
	fail "both-attempts: the late report does not name the first attempt's commit"

status=0
"$SCRIPT" normal "$SCRATCH/normal" >/dev/null 2>&1 || status=$?
[ "$status" -eq 3 ] || fail "existing destination: expected exit 3, got $status"

printf 'eval-fixtures-test: all cases passed\n'
