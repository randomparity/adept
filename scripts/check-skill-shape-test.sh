#!/usr/bin/env bash
set -euo pipefail

# Fixture suite for scripts/check-skill-shape.sh. Each fixture is a scratch
# directory holding a minimal skills/*/SKILL.md tree, a docs/cheatsheet.md,
# and a scripts/reserved-skill-names.txt -- the three inputs the gate reads --
# so the suite exercises the gate without depending on this repository's own
# skill inventory or cheat sheet.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
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

# Split from assert_fails because the cases below run the gate under a shimmed
# PATH and a redirected TMPDIR, which a helper that invokes the gate itself
# cannot carry, and because they assert the fault status rather than the finding
# status. Two of them assert twice against one run.
assert_gate() { # name expected-status expected-fragment status output
	local name=$1 expected_status=$2 expected=$3 status=$4 output=$5
	[ "$status" -eq "$expected_status" ] ||
		fail "$name: expected exit $expected_status, got $status: $output"
	case $output in
	*"$expected"*) : ;;
	*) fail "$name: expected '$expected' in: $output" ;;
	esac
}

assert_fails() { # name root expected-fragment
	local name=$1 root=$2 expected=$3 output status=0
	output=$("$gate" "$root" 2>&1) || status=$?
	assert_gate "$name" 1 "$expected" "$status" "$output"
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

# Cases 7-11 pin the gate's exit contract: 0 clean, 1 for a content finding, 2
# for a fault. A fault that borrowed exit 1 would report a violation that no
# message names, which is the whole defect -- `just verify` goes red and the
# operator has nothing to fix.
#
# The two shims are how a removal or an allocation is made to fail on demand;
# scripts/verify-push-test.sh forces its own failures the same way. Each shim
# directory holds exactly the one command its cases need, so a case takes only
# the failure it is testing.

# Case 7: the scratch directory cannot be created. The gate never ran, so
# nothing about the skills tree was decided.
mktemp_shim=$SCRATCH/shim-mktemp
mkdir -p "$mktemp_shim"
printf '#!/usr/bin/env bash\nexit 1\n' >"$mktemp_shim/mktemp"
chmod +x "$mktemp_shim/mktemp"
allocation_root=$(new_baseline allocation-fault)
allocation_status=0
allocation_output=$(PATH="$mktemp_shim:$PATH" "$gate" "$allocation_root" 2>&1) ||
	allocation_status=$?
assert_gate 'scratch directory cannot be created' 2 \
	'could not create a scratch directory' "$allocation_status" "$allocation_output"

# Case 8: the EXIT trap cannot remove the scratch directory on an otherwise
# clean run. TMPDIR points into this suite's own scratch so the directory the
# shimmed rm refuses to remove leaves with fixture_cleanup instead of
# accumulating under /tmp across runs.
rm_shim=$SCRATCH/shim-rm
mkdir -p "$rm_shim"
printf '#!/usr/bin/env bash\nexit 1\n' >"$rm_shim/rm"
chmod +x "$rm_shim/rm"
retained_root=$(new_baseline cleanup-fault)
retained_status=0
retained_output=$(PATH="$rm_shim:$PATH" TMPDIR="$SCRATCH" "$gate" "$retained_root" 2>&1) ||
	retained_status=$?
# The fragment carries the path, not just the label: the criterion is that the
# message names what was left behind, and a message printing the label alone
# would satisfy a prefix-only assertion while telling the operator nothing.
assert_gate 'clean run, cleanup fails' 2 "retained scratch path: $SCRATCH/check-skill-shape." \
	"$retained_status" "$retained_output"

# Case 9: the same failed removal on a run that already had a finding. The
# finding is the verdict; the cleanup failure reports itself without displacing
# it, so exit 1 still means what it said.
finding_root=$(new_baseline cleanup-fault-with-finding)
mkdir -p "$finding_root/skills/undocumented-skill"
cat >"$finding_root/skills/undocumented-skill/SKILL.md" <<'SKILL'
---
name: undocumented-skill
description: "A fixture skill with no cheat-sheet entry."
---
# Undocumented Skill
SKILL
finding_status=0
finding_output=$(PATH="$rm_shim:$PATH" TMPDIR="$SCRATCH" "$gate" "$finding_root" 2>&1) ||
	finding_status=$?
assert_gate 'finding survives a failed cleanup' 1 \
	'undocumented-skill: not referenced in docs/cheatsheet.md' \
	"$finding_status" "$finding_output"
assert_gate 'failed cleanup still names its path' 1 'retained scratch path:' \
	"$finding_status" "$finding_output"

# Case 10: a skills directory holding nothing. The gate has nothing to check
# rather than something to report.
empty_root=$SCRATCH/empty-skills
mkdir -p "$empty_root/skills" "$empty_root/scripts" "$empty_root/docs"
printf '# Reserved names\n' >"$empty_root/scripts/reserved-skill-names.txt"
printf '# Cheat sheet\n' >"$empty_root/docs/cheatsheet.md"
empty_status=0
empty_output=$("$gate" "$empty_root" 2>&1) || empty_status=$?
assert_gate 'empty skills directory' 2 'no skills found under' \
	"$empty_status" "$empty_output"

# Case 11: no skills directory at all. find fails rather than returning an
# empty list, and pipefail carries that status out, so this reaches a different
# branch than Case 10 does.
absent_root=$SCRATCH/absent-skills
mkdir -p "$absent_root/scripts" "$absent_root/docs"
printf '# Reserved names\n' >"$absent_root/scripts/reserved-skill-names.txt"
printf '# Cheat sheet\n' >"$absent_root/docs/cheatsheet.md"
absent_status=0
absent_output=$("$gate" "$absent_root" 2>&1) || absent_status=$?
assert_gate 'absent skills directory' 2 'could not enumerate' \
	"$absent_status" "$absent_output"

# Cases 12-16 cover the scans that decide a verdict from an exit status. Each
# one collapses "could not run" into an answer if left unguarded, and the two
# membership loops collapse it in opposite directions -- so a single shim run
# against two fixtures proves each loop separately. Cases 12 and 13 assert the
# rule name in the message, not just that something faulted: ADR 0005 wants a
# fault to say which site stopped, and one shared message would let either loop
# satisfy both cases.
grep_shim=$SCRATCH/shim-grep
mkdir -p "$grep_shim"
printf '#!/usr/bin/env bash\nexit 2\n' >"$grep_shim/grep"
chmod +x "$grep_shim/grep"

# Case 12: rule 3's reserved-name loop. A failed scan read as "no collision"
# drops a finding silently, which is the direction nobody would notice.
reserved_root=$(new_baseline reserved-scan-fault)
printf '# Reserved names\nexample-skill\n' >"$reserved_root/scripts/reserved-skill-names.txt"
reserved_status=0
reserved_output=$(PATH="$grep_shim:$PATH" "$gate" "$reserved_root" 2>&1) || reserved_status=$?
assert_gate 'reserved-name scan fault' 2 'rule 3 reserved-name scan of' \
	"$reserved_status" "$reserved_output"

# Case 13: rule 4's invocation loop, reached with the reserved list left empty
# so Case 12's loop does not run first. Here a failed scan read as "no such
# skill" invents a finding against a skill that is present.
invocation_root=$(new_baseline invocation-scan-fault)
cat >>"$invocation_root/skills/example-skill/SKILL.md" <<'SKILL'

This one invokes `$example-skill`, which does exist.
SKILL
invocation_status=0
invocation_output=$(PATH="$grep_shim:$PATH" "$gate" "$invocation_root" 2>&1) || invocation_status=$?
assert_gate 'invocation scan fault' 2 'rule 4 invocation scan of' \
	"$invocation_status" "$invocation_output"

# Case 14: a collating pipeline that could not run. sed is used at exactly one
# site, so shimming it isolates that guard.
#
# The reference-link collation carries the same clause and has no case: it runs
# `sort`, which three earlier lines also run, so a sort shim always trips one of
# those first. That guard is covered by inspection, not by this suite.
sed_shim=$SCRATCH/shim-sed
mkdir -p "$sed_shim"
printf '#!/usr/bin/env bash\nexit 1\n' >"$sed_shim/sed"
chmod +x "$sed_shim/sed"
collate_root=$(new_baseline collate-fault)
collate_status=0
collate_output=$(PATH="$sed_shim:$PATH" "$gate" "$collate_root" 2>&1) || collate_status=$?
assert_gate 'invocation list cannot be collated' 2 'could not collate the invocation list' \
	"$collate_status" "$collate_output"

# Case 15: the skill count cannot be taken. wc runs at one site too, and the
# count it produces is what decides whether the tree holds any skills at all --
# an unguarded failure here would exit 1 with nothing printed.
wc_shim=$SCRATCH/shim-wc
mkdir -p "$wc_shim"
printf '#!/usr/bin/env bash\nexit 1\n' >"$wc_shim/wc"
chmod +x "$wc_shim/wc"
count_root=$(new_baseline count-fault)
count_status=0
count_output=$(PATH="$wc_shim:$PATH" "$gate" "$count_root" 2>&1) || count_status=$?
assert_gate 'skill count cannot be taken' 2 'could not count' \
	"$count_status" "$count_output"

# Case 16: an rg scan that could not run. rg decides four rules here and all
# four convert its exit >1 the same way, so one shim pins the conversion; the
# shim exits 2 at the first site the gate reaches, which is rule 2's frontmatter
# read. Discriminating the other three would need a shim that faults on one
# pattern and answers normally on the rest -- more machinery than the shared
# two-line branch they use is worth.
rg_shim=$SCRATCH/shim-rg
mkdir -p "$rg_shim"
printf '#!/usr/bin/env bash\nexit 2\n' >"$rg_shim/rg"
chmod +x "$rg_shim/rg"
rg_root=$(new_baseline rg-scan-fault)
rg_status=0
rg_output=$(PATH="$rg_shim:$PATH" "$gate" "$rg_root" 2>&1) || rg_status=$?
assert_gate 'rg scan fault' 2 'rg exit 2' "$rg_status" "$rg_output"

printf 'check-skill-shape-test: ok\n'
