#!/usr/bin/env bash
# test-fixture-helpers.sh — shared scaffold for fixture-style tests
#
# This helper is sourced by:
#   scripts/*-test.sh (5 suites, migrated in #59)
#   tests/fixtures/forge/*-test.sh (3 suites)
#   tests/fixtures/quest-log/*-test.sh (2 suites)
#   tests/fixtures/attunement/*-test.sh (1 suite)
#   tests/fixtures/bounty/*-test.sh (1 suite)
#
# Explicitly NOT used by (recorded in ADR 0003):
#   .github/scripts/check-records-test.sh
#   skills/tome-of-lore/assets/check-records-test.sh
#   → just records compares them byte-for-byte; they sit at different depths,
#     so no single relative source path resolves from both.

set -euo pipefail

# fixture_init — must be called once at top of each test file
# Sets up SCRATCH_ROOT and installs the EXIT trap that removes it.
fixture_init() {
    export SCRATCH_ROOT
    SCRATCH_ROOT="$(mktemp -d)"
    trap 'fixture_cleanup' EXIT
}

# fixture_scratch — returns a fresh subdirectory under SCRATCH_ROOT
# Usage: local workdir; workdir="$(fixture_scratch)"
fixture_scratch() {
    mktemp -d "${SCRATCH_ROOT}/XXXXXX"
}

# fixture_cleanup — removes SCRATCH_ROOT; called by EXIT trap
fixture_cleanup() {
    [[ -n "${SCRATCH_ROOT:-}" && -d "${SCRATCH_ROOT}" ]] && rm -rf "${SCRATCH_ROOT}"
}

# clear_git_env — unsets GIT_* env vars that leak from the test runner
# Mirrors: git rev-parse --local-env-vars
clear_git_env() {
    local var
    while IFS= read -r var; do
        unset "$var"
    done < <(git rev-parse --local-env-vars 2>/dev/null || true)
}

# fail — prints message to stderr and exits 1
fail() {
    echo "FAIL: $*" >&2
    exit 1
}
