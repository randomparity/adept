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

# Case 17: a run that has both a finding and a scan fault. The header states the
# precedence as deliberate -- a scan fault outranks a finding, because the rules
# the failed scan decides are undecided -- and nothing else asserts it, so a
# later change making the finding win would pass every other case here.
#
# Rule 2 reports first (a second skill whose name: disagrees with its directory),
# then rule 3's loop runs against a non-empty reserved list and the grep shim
# faults it. The finding must still be printed and the status must be the fault.
precedence_root=$(new_baseline fault-outranks-finding)
mkdir -p "$precedence_root/skills/mislabelled"
cat >"$precedence_root/skills/mislabelled/SKILL.md" <<'SKILL'
---
name: not-the-directory-name
description: "A fixture skill whose frontmatter disagrees with its directory."
---
# Mislabelled
SKILL
cat >>"$precedence_root/docs/cheatsheet.md" <<'SHEET'

Also `mislabelled`, so rule 6 is not what decides this case.
SHEET
printf '# Reserved names\nexample-skill\n' >"$precedence_root/scripts/reserved-skill-names.txt"
precedence_status=0
precedence_output=$(PATH="$grep_shim:$PATH" "$gate" "$precedence_root" 2>&1) || precedence_status=$?
assert_gate 'fault outranks finding, status' 2 'rule 3 reserved-name scan of' \
	"$precedence_status" "$precedence_output"
assert_gate 'fault outranks finding, finding still printed' 2 \
	'mislabelled: SKILL.md declares name: not-the-directory-name' \
	"$precedence_status" "$precedence_output"

# Cases 18-24 cover the five loops that read a scratch file, and the two halves
# of the guard in front of them. Every way an input goes unreadable fails *open*
# on bash 3.2 -- the loop body is skipped, the run carries on, and a rule nobody
# checked reports the passing answer -- and an unopenable path is only one of
# them: a directory opens and then fails at the first `read`, and a regular file
# this process may not read fails an open that no `-f` test would reach.
#
# Cases 18-22 give each loop its own case rather than one shared case and an
# argument, and each asserts the rule name so no two sites can satisfy each
# other's assertion. Cases 23 and 24 take the other two shapes at one site,
# since both halves live in the one shared helper.
#
# The shims differ from cases 12-16's: those make a command fail, these let it
# succeed and then unlink the file the next loop is about to open, which is the
# outside interference the gate cannot otherwise be made to see. Each case gets
# its own TMPDIR so the shim's glob resolves to that run's scratch directory and
# not to one cases 8 and 9 deliberately left behind under $SCRATCH.
real_sort=$(command -v sort)
real_sed=$(command -v sed)

probe_case() { # name shim-command shim-body fixture expected-fragment
	local name=$1 shim_command=$2 shim_body=$3 fixture=$4 expected=$5
	local shim=$SCRATCH/shim-$fixture tmp=$SCRATCH/tmp-$fixture root status=0 output
	mkdir -p "$shim" "$tmp"
	printf '#!/usr/bin/env bash\n%s\n' "$shim_body" >"$shim/$shim_command"
	chmod +x "$shim/$shim_command"
	root=$(new_baseline "$fixture")
	output=$(PATH="$shim:$PATH" TMPDIR="$tmp" "$gate" "$root" 2>&1) || status=$?
	assert_gate "$name" 2 "$expected" "$status" "$output"
}

# Case 18: rule 1 and 2's loop. wc runs once, immediately before that loop, so a
# shim that answers with a count and then unlinks the list leaves the loop with
# nothing to open. The count it prints has to be non-zero or the gate stops at
# the empty-tree fault instead.
probe_case 'rule 1 and 2 list cannot be read' wc \
	"printf '1\n'
rm -f \"\$TMPDIR\"/check-skill-shape.*/names" \
	rule12-input-fault 'the rule 1 and 2 skill-name list could not be read'

# Case 19: rule 3's loop. sort writes the reserved list, so the shim sorts as
# usual and unlinks the result afterwards -- deterministically, because the
# shell opened the redirect before the shim started and the shim's own sort has
# already finished writing. The earlier sort calls unlink a path that does not
# exist yet, which -f absorbs.
probe_case 'rule 3 reserved list cannot be read' sort \
	"sort_status=0
\"$real_sort\" \"\$@\" || sort_status=\$?
rm -f \"\$TMPDIR\"/check-skill-shape.*/reserved
exit \"\$sort_status\"" \
	rule3-input-fault 'the rule 3 reserved-name list could not be read'

# Case 20: rule 4's loop, on the same sort shim aimed at the invocation list.
# The list is collated by `sed ... | sort -u >refs`, whose two stages run
# concurrently, so unlinking from the sed end would depend on losing a race with
# the sort still writing. Unlinking from the sort end has no race to lose: that
# shim writes the file itself and removes it afterwards.
probe_case 'rule 4 invocation list cannot be read' sort \
	"sort_status=0
\"$real_sort\" \"\$@\" || sort_status=\$?
rm -f \"\$TMPDIR\"/check-skill-shape.*/refs
exit \"\$sort_status\"" \
	rule4-input-fault 'the rule 4 invocation list could not be read'

# Case 21: rule 5's loop, reached by the same sort shim aimed at the link list.
# Rules 3 and 4 run in between and must not fault first, which they do not:
# their own lists are written before this shim's target exists.
probe_case 'rule 5 link list cannot be read' sort \
	"sort_status=0
\"$real_sort\" \"\$@\" || sort_status=\$?
rm -f \"\$TMPDIR\"/check-skill-shape.*/links
exit \"\$sort_status\"" \
	rule5-input-fault 'the rule 5 reference-link list could not be read'

# Case 22: rule 6's loop, which reads the same $names file rule 1 and 2 read.
# That is why the two messages differ, and why this case cannot be folded into
# Case 18: the sed shim unlinks the list after rule 1 and 2's loop has already
# consumed it, so only the rule 6 probe can fire.
#
# That last part holds because the baseline fixture has no `$invocation` and an
# empty reserved list. Give it one and rule 4's membership grep, which re-reads
# the same $names, faults first -- loudly, on its own message, so the case would
# fail rather than pass for the wrong reason, but it is a property of the
# fixture and not of the design.
probe_case 'rule 6 list cannot be read' sed \
	"sed_status=0
\"$real_sed\" \"\$@\" || sed_status=\$?
rm -f \"\$TMPDIR\"/check-skill-shape.*/names
exit \"\$sed_status\"" \
	rule6-input-fault 'the rule 6 skill-name list could not be read'

# Cases 23 and 24 pin the guard's two halves against each other. Rule 1 and 2's
# site stands for all five in both: each half is one line of the one shared
# helper, so a case per site would pin the same line five times.
#
# Case 23: a directory at the input path opens without error and then fails at
# the first `read` with the loop body never running -- the identical fail-open
# shape, reached without an unopenable path, so an open on its own would let
# this through.
#
# This shim globs the scratch directory rather than the file, because the path
# has to be recreated after the unlink and a glob through the removed name
# matches nothing.
probe_case 'rule 1 and 2 list replaced by a directory' wc \
	"printf '1\n'
for d in \"\$TMPDIR\"/check-skill-shape.*; do
	rm -f \"\$d/names\"
	mkdir \"\$d/names\"
done" \
	rule12-input-directory \
	'the rule 1 and 2 skill-name list could not be read (no regular file at that path)'

# Case 24: the open half, and the only case that reaches it. Every case above
# unlinks its input, which fails the regular-file test first, so without this one
# the open could be deleted outright and the suite would stay green. A regular
# file the process may not read is what only the open can see.
#
# chmod 000 does not deny root, so on a root runner this would assert something
# the environment cannot produce -- a spurious red, not a defect. Skipped there
# and said aloud, the same guard .github/scripts/check-records-test.sh puts on
# its own chmod cases.
if [ "$(id -u)" -eq 0 ]; then
	printf 'check-skill-shape-test: skip %s (running as root; chmod 000 does not deny access)\n' \
		'rule 1 and 2 list unreadable'
else
	probe_case 'rule 1 and 2 list unreadable' wc \
		"printf '1\n'
chmod 000 \"\$TMPDIR\"/check-skill-shape.*/names" \
		rule12-input-unreadable 'the rule 1 and 2 skill-name list could not be read'
fi

printf 'check-skill-shape-test: ok\n'
