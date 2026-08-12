#!/usr/bin/env bash
set -euo pipefail

# Fixture suite for scripts/check-skill-shape.sh. Each fixture is a scratch
# directory holding a minimal skills/*/SKILL.md tree, a docs/cheatsheet.md,
# and a scripts/reserved-skill-names.txt -- the three inputs the gate reads --
# so the suite exercises the gate without depending on this repository's own
# skill inventory or cheat sheet.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

fixture_init check-skill-shape-test
gate=$script_dir/check-skill-shape.sh

# A fixture with one minimal, valid skill and a matching cheat-sheet mention.
# Every case below starts from this baseline and adds exactly the one
# variation the case is testing, so a failure localizes to that variation.
new_baseline() { # name -> prints fixture root
	local root=$SCRATCH/$1
	mkdir -p "$root/skills/example-skill" "$root/scripts" "$root/docs"
	cat >"$root/skills/example-skill/SKILL.md" <<'SKILL'
---
name: example-skill
description: "A minimal fixture skill."
---
# Example Skill

Nothing here references another skill or a reference file.
SKILL
	printf '# Reserved names\n' >"$root/scripts/reserved-skill-names.txt"
	cat >"$root/docs/cheatsheet.md" <<'SHEET'
# Cheat sheet

| Skill | Does |
|---|---|
| `example-skill` | A minimal fixture skill |
SHEET
	printf '%s\n' "$root"
}

assert_passes() { # name root
	local name=$1 root=$2 output
	if ! output=$("$gate" "$root" 2>&1); then
		fail "$name: expected pass, got: $output"
	fi
}

assert_fails() { # name root expected-fragment
	local name=$1 root=$2 expected=$3 output status=0
	output=$("$gate" "$root" 2>&1) || status=$?
	[ "$status" -eq 1 ] || fail "$name: expected exit 1, got $status: $output"
	case $output in
	*"$expected"*) : ;;
	*) fail "$name: expected '$expected' in: $output" ;;
	esac
}

# Case 1: the baseline fixture alone -- rules 1-5 (SKILL.md exists, name:
# frontmatter matches, no reserved-name collision, no dangling $invocation, no
# dangling reference link) and the new rule 6 all pass together.
baseline_root=$(new_baseline baseline)
assert_passes 'minimal valid fixture, all rules' "$baseline_root"

# Case 2: a skill directory with no cheat-sheet mention at all.
missing_root=$(new_baseline missing)
mkdir -p "$missing_root/skills/undocumented-skill"
cat >"$missing_root/skills/undocumented-skill/SKILL.md" <<'SKILL'
---
name: undocumented-skill
description: "A fixture skill with no cheat-sheet entry."
---
# Undocumented Skill
SKILL
assert_fails 'undocumented skill' "$missing_root" \
	'undocumented-skill: not referenced in docs/cheatsheet.md'

# Case 3: the same skill, now mentioned as a backtick-wrapped token anywhere
# in the cheat sheet -- proving the check is membership, not table position.
documented_root=$(new_baseline documented)
mkdir -p "$documented_root/skills/newly-documented"
cat >"$documented_root/skills/newly-documented/SKILL.md" <<'SKILL'
---
name: newly-documented
description: "A fixture skill with a cheat-sheet entry in prose, not a table."
---
# Newly Documented Skill
SKILL
cat >>"$documented_root/docs/cheatsheet.md" <<'SHEET'

See `newly-documented` for details, mentioned only in this sentence.
SHEET
assert_passes 'documented skill, prose mention' "$documented_root"

# Case 4: wording elsewhere in the cheat sheet changes beside an
# already-referenced skill's token -- the verdict for that skill must not
# move, proving the check is structural and not sensitive to prose.
worded_root=$(new_baseline worded)
cat >"$worded_root/docs/cheatsheet.md" <<'SHEET'
# Cheat sheet

| Skill | Does |
|---|---|
| `example-skill` | Rewritten description text, nothing like the original |

Some unrelated prose paragraph was added here too.
SHEET
assert_passes 'reworded surrounding prose' "$worded_root"

# Case 5: substring-adjacent skill names, the real shape this repo's own
# inventory has (`quest`, `quest-log`, `seek-quest` all coexist), all three
# documented and passing. This is the baseline fixture Case 6 mutates below
# to actually exercise backtick-anchoring.
collision_root=$(new_baseline collision)
mkdir -p "$collision_root/skills/quest" "$collision_root/skills/quest-log" \
	"$collision_root/skills/seek-quest"
for name in quest quest-log seek-quest; do
	cat >"$collision_root/skills/$name/SKILL.md" <<SKILL
---
name: $name
description: "A substring-collision fixture skill."
---
# ${name}
SKILL
done
cat >"$collision_root/docs/cheatsheet.md" <<'SHEET'
# Cheat sheet

| Skill | Does |
|---|---|
| `example-skill` | A minimal fixture skill |
| `quest` | Substring-collision fixture |
| `quest-log` | Substring-collision fixture |
| `seek-quest` | Substring-collision fixture |
SHEET
assert_passes 'substring-adjacent names, all documented' "$collision_root"

# Case 6: same three names, but the *shorter* name (`quest`) is left
# undocumented while the two longer names that contain it as a substring
# (`quest-log`, `seek-quest`) are documented. An un-anchored search for
# `quest` would false-match inside the `quest-log`/`seek-quest` tokens' own
# backtick-delimited text and wrongly pass; backtick-anchoring on both ends
# is what keeps `quest` correctly flagged as undocumented.
partial_collision_root=$SCRATCH/partial-collision
cp -R "$collision_root" "$partial_collision_root"
cat >"$partial_collision_root/docs/cheatsheet.md" <<'SHEET'
# Cheat sheet

| Skill | Does |
|---|---|
| `example-skill` | A minimal fixture skill |
| `quest-log` | Substring-collision fixture |
| `seek-quest` | Substring-collision fixture |
SHEET
assert_fails 'substring-adjacent names, shorter name undocumented' "$partial_collision_root" \
	'quest: not referenced in docs/cheatsheet.md'

printf 'check-skill-shape-test: ok\n'
