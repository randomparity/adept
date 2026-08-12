#!/usr/bin/env bash
set -euo pipefail

# Fixture suite for scripts/check-skill-shape.sh. Each fixture is a scratch
# directory holding a minimal skills/*/SKILL.md tree, a docs/cheatsheet.md,
# and a scripts/reserved-skill-names.txt -- the three inputs the gate reads --
# so the suite exercises the gate without depending on this repository's own
# skill inventory or cheat sheet.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
gate=$script_dir/check-skill-shape.sh
tmp_prefix=${TMPDIR:-/tmp}/check-skill-shape-test.
tmp_root=$(mktemp -d "$tmp_prefix"'XXXXXX')

cleanup() {
	case $tmp_root in
	"$tmp_prefix"*) rm -R -- "$tmp_root" ;;
	*)
		printf 'check-skill-shape-test: refusing to remove unsafe path: %s\n' \
			"$tmp_root" >&2
		return 1
		;;
	esac
}
trap cleanup EXIT

fail() {
	printf 'check-skill-shape-test: %s\n' "$*" >&2
	exit 1
}

# A fixture with one minimal, valid skill and a matching cheat-sheet mention.
# Every case below starts from this baseline and adds exactly the one
# variation the case is testing, so a failure localizes to that variation.
new_baseline() { # name -> prints fixture root
	local root=$tmp_root/$1
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
# dangling reference link) and the new rule 6 all pass together. This is what
# proves the new root argument and rule 6 did not break the existing rules'
# fixture-testability, not just rule 6 in isolation.
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
# inventory has (`quest`, `quest-log`, `seek-quest` all coexist). All three
# documented -- backtick-anchoring on both ends must not let one name's
# presence be mistaken for another's.
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

# Case 6: same three names, but `quest-log` is left undocumented while
# `quest` and `seek-quest` are documented -- proving `quest-log` is not
# falsely satisfied by the substring match against `quest`'s own token.
partial_collision_root=$tmp_root/partial-collision
cp -R "$collision_root" "$partial_collision_root"
cat >"$partial_collision_root/docs/cheatsheet.md" <<'SHEET'
# Cheat sheet

| Skill | Does |
|---|---|
| `example-skill` | A minimal fixture skill |
| `quest` | Substring-collision fixture |
| `seek-quest` | Substring-collision fixture |
SHEET
assert_fails 'substring-adjacent names, one undocumented' "$partial_collision_root" \
	'quest-log: not referenced in docs/cheatsheet.md'

printf 'check-skill-shape-test: ok\n'
