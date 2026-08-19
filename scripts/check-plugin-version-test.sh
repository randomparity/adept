#!/usr/bin/env bash
set -euo pipefail

# Fixture suite for scripts/check-plugin-version.sh. Each fixture is a git
# repository carrying nothing but .claude-plugin/plugin.json and whatever else a
# case needs, so the gate's verdicts are decided by the fixture rather than by
# this repository's own history.
#
# The suite inherits git-fixture isolation: a caller's GIT_DIR or GIT_INDEX_FILE
# would otherwise reach the fixtures' `git -C` and let the gate diff this
# repository instead.
#
# BASE_SHA reaches the gate through the environment, so every invocation below
# sets it explicitly -- including to empty. Inheriting the ambient value would
# make a developer who exported it for the records gate run a different suite.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

clear_git_env
fixture_init plugin-version-test

gate=$script_dir/check-plugin-version.sh

write_manifest() { # root body
	mkdir -p "$1/.claude-plugin"
	printf '%s\n' "$2" >"$1/.claude-plugin/plugin.json"
}

manifest_with() { # version
	printf '{\n  "name": "adept",\n  "version": "%s"\n}' "$1"
}

new_fixture() { # name manifest-body
	local root=$SCRATCH/$1
	mkdir -p "$root"
	git init -q -b main "$root"
	git -C "$root" config user.name 'Fixture Developer'
	git -C "$root" config user.email fixture@example.invalid
	write_manifest "$root" "$2"
	git -C "$root" add -A
	git -C "$root" commit -q -m 'base'
	printf '%s\n' "$root"
}

base_of() { # root
	git -C "$1" rev-parse HEAD
}

run_gate() { # root base -- sets RUN_OUTPUT and RUN_STATUS
	RUN_STATUS=0
	RUN_OUTPUT=$(BASE_SHA=$2 GITHUB_ACTIONS='' "$gate" "$1" 2>&1) || RUN_STATUS=$?
}

assert_passes() { # name root base
	run_gate "$2" "$3"
	[[ $RUN_STATUS -eq 0 ]] ||
		fail "$1: expected exit 0, got $RUN_STATUS: $RUN_OUTPUT"
}

assert_reports() { # name root base expected-fragment
	run_gate "$2" "$3"
	[[ $RUN_STATUS -eq 1 ]] ||
		fail "$1: expected exit 1, got $RUN_STATUS: $RUN_OUTPUT"
	[[ $RUN_OUTPUT == *"$4"* ]] ||
		fail "$1: expected '$4' in: $RUN_OUTPUT"
}

assert_faults() { # name root base expected-fragment
	run_gate "$2" "$3"
	[[ $RUN_STATUS -eq 2 ]] ||
		fail "$1: expected exit 2, got $RUN_STATUS: $RUN_OUTPUT"
	[[ $RUN_OUTPUT == *"$4"* ]] ||
		fail "$1: expected '$4' in: $RUN_OUTPUT"
}

# Rule 1: a manifest with no version at all. This is the state every ref before
# ADR 0022 is in, and the finding the adopting change clears.
missing_root=$(new_fixture missing '{
  "name": "adept"
}')
assert_reports 'no version declared' "$missing_root" "$(base_of "$missing_root")" \
	'declares no version'

# Rule 2. Each shape below is a version a person plausibly writes and the
# three-integer comparison in rule 3 cannot order.
for bad in 1.0 1 v1.0.0 1.0.0-rc.1 1.0.0+build.5 01.0.0 1.0.0.0 latest; do
	bad_root=$(new_fixture "bad-$(printf '%s' "$bad" | tr -c 'a-zA-Z0-9' '-')" \
		"$(manifest_with "$bad")")
	assert_reports "malformed version: $bad" "$bad_root" "$(base_of "$bad_root")" \
		"declares version '$bad', which is not MAJOR.MINOR.PATCH"
done

# A version given as a JSON number parses, so it must be rejected by shape
# rather than read as absent -- otherwise the author is told the manifest
# declares nothing while it plainly declares something.
number_root=$(new_fixture number '{
  "name": "adept",
  "version": 1
}')
assert_reports 'version as a JSON number' "$number_root" "$(base_of "$number_root")" \
	"declares version '1', which is not MAJOR.MINOR.PATCH"

# Zero fields are legal; only leading zeros are not.
zero_root=$(new_fixture zero "$(manifest_with 0.0.0)")
assert_passes 'zero fields' "$zero_root" "$(base_of "$zero_root")"

# Rule 3, the finding this gate exists for: the tree differs from the base ref
# and the version did not move. Removing the gate from the verify chain is what
# this case reddens.
stale_root=$(new_fixture stale "$(manifest_with 1.0.0)")
stale_base=$(base_of "$stale_root")
printf 'a skill edit\n' >"$stale_root/skill.md"
git -C "$stale_root" add -A
assert_reports 'change without a bump' "$stale_root" "$stale_base" \
	'the version did not increase: 1.0.0 at the base ref, 1.0.0 here'

# The same change with the bump the rule asks for.
bumped_root=$(new_fixture bumped "$(manifest_with 1.0.0)")
bumped_base=$(base_of "$bumped_root")
printf 'a skill edit\n' >"$bumped_root/skill.md"
write_manifest "$bumped_root" "$(manifest_with 1.0.1)"
git -C "$bumped_root" add -A
assert_passes 'change with a bump' "$bumped_root" "$bumped_base"

# A bump is a bump wherever it lands, and the comparison is numeric per field
# rather than lexical -- 1.2.10 sorts before 1.2.9 as text.
for pair in '1.0.0 2.0.0' '1.0.0 1.1.0' '1.2.9 1.2.10' '1.9.0 2.0.0'; do
	from=${pair%% *}
	to=${pair##* }
	field_root=$(new_fixture "field-${from//./-}-${to//./-}" "$(manifest_with "$from")")
	field_base=$(base_of "$field_root")
	printf 'a skill edit\n' >"$field_root/skill.md"
	write_manifest "$field_root" "$(manifest_with "$to")"
	git -C "$field_root" add -A
	assert_passes "bump $from -> $to" "$field_root" "$field_base"
done

# A version that moves backwards is not a bump. Equal already fails above; this
# is the case a hand-edited manifest reaches.
back_root=$(new_fixture backwards "$(manifest_with 2.0.0)")
back_base=$(base_of "$back_root")
printf 'a skill edit\n' >"$back_root/skill.md"
write_manifest "$back_root" "$(manifest_with 1.9.9)"
git -C "$back_root" add -A
assert_reports 'version moved backwards' "$back_root" "$back_base" \
	'the version did not increase: 2.0.0 at the base ref, 1.9.9 here'

# Rule 3 asks for a bump only when something changed. A tree identical to the
# base ref owes nothing, or the gate would be unsatisfiable on a re-run.
clean_root=$(new_fixture clean "$(manifest_with 1.0.0)")
assert_passes 'tree matches the base ref' "$clean_root" "$(base_of "$clean_root")"

# An untracked file is not in the tree the plugin cache receives, so it demands
# no bump. `git diff` reports tracked paths only, and this pins that.
untracked_root=$(new_fixture untracked "$(manifest_with 1.0.0)")
printf 'scratch\n' >"$untracked_root/notes.txt"
assert_passes 'untracked file only' "$untracked_root" "$(base_of "$untracked_root")"

# The bootstrap: a base ref that declared no version. Any accepted version
# satisfies rule 3, because there is nothing to compare against. This is the
# state of the change that adopts ADR 0022.
boot_root=$(new_fixture bootstrap '{
  "name": "adept"
}')
boot_base=$(base_of "$boot_root")
write_manifest "$boot_root" "$(manifest_with 1.0.0)"
git -C "$boot_root" add -A
assert_passes 'base ref declared no version' "$boot_root" "$boot_base"

# The same, one step earlier: the base ref had no manifest at all.
nomanifest_root=$SCRATCH/no-manifest
mkdir -p "$nomanifest_root"
git init -q -b main "$nomanifest_root"
git -C "$nomanifest_root" config user.name 'Fixture Developer'
git -C "$nomanifest_root" config user.email fixture@example.invalid
printf 'readme\n' >"$nomanifest_root/README.md"
git -C "$nomanifest_root" add -A
git -C "$nomanifest_root" commit -q -m 'base'
nomanifest_base=$(base_of "$nomanifest_root")
write_manifest "$nomanifest_root" "$(manifest_with 1.0.0)"
git -C "$nomanifest_root" add -A
assert_passes 'base ref had no manifest' "$nomanifest_root" "$nomanifest_base"

# A malformed version in history cannot be ordered and cannot be fixed by the
# change under review, so the run reports a fault rather than accusing the
# author of not bumping.
badbase_root=$(new_fixture bad-base "$(manifest_with 1.0)")
badbase_base=$(base_of "$badbase_root")
write_manifest "$badbase_root" "$(manifest_with 1.0.1)"
git -C "$badbase_root" add -A
assert_faults 'malformed version at the base ref' "$badbase_root" "$badbase_base" \
	"is '1.0', which is not MAJOR.MINOR.PATCH — cannot compare"

# A base ref that is not a commit leaves rule 3 undecided. Reporting a finding
# would send the author to bump a version that was never the problem.
badref_root=$(new_fixture bad-ref "$(manifest_with 1.0.0)")
assert_faults 'BASE_SHA is not a commit' "$badref_root" \
	'0000000000000000000000000000000000000000' 'is not a commit in this repository'

# A manifest that will not parse is a fault, and specifically not the rule 1
# finding: an author told the manifest declares no version would go looking for
# a missing field rather than for the syntax error.
broken_root=$(new_fixture broken "$(manifest_with 1.0.0)")
write_manifest "$broken_root" '{ "name": "adept", '
assert_faults 'unparseable manifest' "$broken_root" "$(base_of "$broken_root")" \
	'could not parse'

# No manifest at all stops the gate rather than reddening it over content.
absent_root=$(new_fixture absent "$(manifest_with 1.0.0)")
rm -f -- "$absent_root/.claude-plugin/plugin.json"
assert_faults 'manifest absent' "$absent_root" "$(base_of "$absent_root")" \
	'no plugin manifest at'

# BASE_SHA unset outside CI: rules 1 and 2 still decide, rule 3 does not run and
# the run says so. A gate that reported a clean full pass here would claim to
# have checked the bump rule it skipped.
unset_root=$(new_fixture unset-base "$(manifest_with 1.0.0)")
status=0
output=$(BASE_SHA='' GITHUB_ACTIONS='' "$gate" "$unset_root" 2>&1) || status=$?
[[ $status -eq 0 ]] || fail "unset BASE_SHA: expected exit 0, got $status: $output"
[[ $output == *'the bump rule did not run'* ]] ||
	fail "unset BASE_SHA: unexpected message: $output"

# Rules 1 and 2 still bite with no base ref, so the reduced run is a narrower
# check rather than a disabled one.
unset_bad_root=$(new_fixture unset-base-bad "$(manifest_with 1.0)")
status=0
output=$(BASE_SHA='' GITHUB_ACTIONS='' "$gate" "$unset_bad_root" 2>&1) || status=$?
[[ $status -eq 1 ]] ||
	fail "unset BASE_SHA with a bad version: expected exit 1, got $status: $output"

# Inside CI the same emptiness is fatal. Without this the bump rule could be
# switched off for every pull request by dropping one `env:` line, silently.
ci_root=$(new_fixture ci-no-base "$(manifest_with 1.0.0)")
status=0
output=$(BASE_SHA='' GITHUB_ACTIONS=true "$gate" "$ci_root" 2>&1) || status=$?
[[ $status -eq 2 ]] || fail "empty BASE_SHA in CI: expected exit 2, got $status: $output"
[[ $output == *'BASE_SHA is empty in CI'* ]] ||
	fail "empty BASE_SHA in CI: unexpected message: $output"

printf 'plugin-version-test: pass\n'
