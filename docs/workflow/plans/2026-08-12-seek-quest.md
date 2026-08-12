# Implementation plan: `$seek-quest` and the cheat-sheet coverage gate

**Goal.** Add a read-only `$seek-quest` skill that ranks the `status:ready`
GitHub issue queue and recommends the next issue for `$quest`, and add a
CI-backed structural gate that fails when a skill exists with no mention in
`docs/cheatsheet.md`.

**Architecture.** One new instruction-only skill file
(`skills/seek-quest/SKILL.md`, anatomy rule 1 — no script backs its ranking
logic). One existing gate script (`scripts/check-skill-shape.sh`) grows a
sixth structural rule and gains a fixture-testable optional root argument, a
pattern already established by `scripts/check-public-safety.sh`. One new
test suite (`scripts/check-skill-shape-test.sh`) exercises that gate against
synthetic fixture trees, following `scripts/check-ripgrep-config-test.sh`'s
fixture-harness shape. `docs/cheatsheet.md` gains three additive edits.

**Tech stack.** Bash 3.2, `rg`, `gh`, `git`, `jq` (already project
dependencies; no new ones added).

**Full design record:** `docs/workflow/specs/2026-08-12-seek-quest-design.md`
(traceability table, full step-by-step behavior). **Decision record:**
`docs/adr/0004-seek-quest-occupancy-signals-and-cheatsheet-gate.md`
(occupancy signals, gate placement, rejected alternatives).

## Global constraints

Transcribed from the spec's "Global constraints" section:

- Bash 3.2 is the floor for any shell touched — no `mapfile`, no
  `readarray`, no associative arrays.
- `rg` invocations pass `--no-config`.
- Shell gate scripts capture `rg`'s exit status explicitly; exit `>1` is a
  real failure, never "no matches" — never `|| true` on an `rg` call whose
  failure matters.
- `docs/cheatsheet.md` edits are additive rows/sentences only — no
  restructuring of existing tables.
- The plugin has no installer; `tests/fixtures/` (where it's used elsewhere
  in this repo) stays outside `skills/`. This plan's fixtures live in a
  `mktemp -d` scratch directory instead, following the pattern the sibling
  gate suites (`check-public-safety-test.sh`, `check-ripgrep-config-test.sh`)
  already use for testing a script against synthetic trees — not under
  `tests/fixtures/`, since nothing here needs to be inspected as a checked-in
  fixture.
- Every guardrail command below is run from `$WORK` (the repo root of the
  working checkout) unless stated otherwise.

## File map

| File | Change |
|---|---|
| `scripts/check-skill-shape.sh` | Modify: accept optional root argument; add rule 6 (cheat-sheet coverage) |
| `scripts/check-skill-shape-test.sh` | Create: fixture-based test suite for the gate, including rule 6 |
| `skills/seek-quest/SKILL.md` | Create: the new skill |
| `docs/cheatsheet.md` | Modify: three additive entries for `$seek-quest` |

## Task 1 — Cheat-sheet coverage gate: root argument, rule 6, test suite

This is one task: the root-argument change has no purpose without rule 6,
and rule 6 cannot be tested without the root-argument change, so no reviewer
could sensibly accept one half while rejecting the other.

**Files:** `scripts/check-skill-shape.sh` (modify), `scripts/check-skill-shape-test.sh` (create)

**Interfaces:** `check-skill-shape.sh` becomes `check-skill-shape.sh [root]` —
one optional positional argument, defaulting to the script's own repo root
exactly as today when omitted. No other script or `Justfile` recipe passes
an argument today (`just shape-check` runs `./scripts/check-skill-shape.sh`
bare), so this is backward compatible. The test suite is a standalone
executable invoked by `just test` via `git ls-files -z -- '*-test.sh'`; it
takes no arguments and exercises the gate as a subprocess (`"$gate" "$root"`).

### Step 1.1 — Add the optional root argument

Edit `scripts/check-skill-shape.sh` line 20. Before:

```bash
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```

After:

```bash
root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
```

Run: `just shape-check`

Expect: identical output to before the edit —
`check-skill-shape: 26 skills, all rules pass` and exit 0. This proves the
default-argument path is unchanged before anything else in this task
touches the script.

### Step 1.2 — Write the failing test suite

Create `scripts/check-skill-shape-test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Fixture suite for scripts/check-skill-shape.sh. Each fixture is a scratch
# directory holding a minimal skills/*/SKILL.md tree, a docs/cheatsheet.md,
# and a scripts/reserved-skill-names.txt -- the three inputs the gate reads --
# so the suite exercises the gate without depending on this repository's own
# skill inventory or cheat sheet.
#
# The suite inherits git-fixture isolation: a caller's GIT_DIR or
# GIT_INDEX_FILE is irrelevant here since the gate never calls git, but the
# convention is kept for consistency with the repo's other fixture suites.

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

printf 'check-skill-shape-test: ok\n'
```

Make it executable: `chmod +x scripts/check-skill-shape-test.sh`

Run: `./scripts/check-skill-shape-test.sh`

Expect **failure** (case 2 fails first): the gate does not yet implement
rule 6, so `assert_fails 'undocumented skill' ...` finds the gate exits 0
(pass) instead of 1, and the suite exits nonzero with
`check-skill-shape-test: undocumented skill: expected exit 1, got 0: ...`.
This confirms the test can fail before rule 6 exists.

### Step 1.3 — Implement rule 6

Edit `scripts/check-skill-shape.sh`. Insert the new rule immediately before
the closing summary block (before line 131's `if [ "$status" -eq 0 ]; then`),
after rule 5's closing `done <"$workspace/links"`:

```bash
# Rule 6: every skill name is referenced in docs/cheatsheet.md. This is what
# makes a skill added without documentation fail fast instead of going
# unnoticed -- the same inventory-vs-reference shape as rule 4, pointed at
# docs/cheatsheet.md instead of at skills/*/SKILL.md. Membership only: no
# wording, table-shape, or description-text assertion, per repository anatomy
# rule 4 (nothing here greps for a sentence).
while IFS= read -r name; do
	coverage_status=0
	rg --no-config -qF -- "\`$name\`" "$root/docs/cheatsheet.md" || coverage_status=$?
	if [ "$coverage_status" -gt 1 ]; then
		printf 'check-skill-shape: scanning docs/cheatsheet.md failed (rg exit %s)\n' \
			"$coverage_status" >&2
		exit 1
	fi
	if [ "$coverage_status" -eq 1 ]; then
		report "$name: not referenced in docs/cheatsheet.md"
	fi
done <"$names"
```

Run: `./scripts/check-skill-shape-test.sh`

Expect: `check-skill-shape-test: ok` and exit 0 — all four cases pass.

### Step 1.4 — Confirm the real repo is unaffected

Run: `just shape-check`

Expect: `check-skill-shape: 26 skills, all rules pass` and exit 0 — unchanged
from Step 1.1, because every existing skill already has a cheat-sheet
mention (verified during design).

Run: `just test`

Expect: every discovered `*-test.sh` suite passes, including the new
`check-skill-shape-test.sh`, ending with `test: N suites passed` (N one more
than before this task).

### Step 1.5 — Commit

```
git add scripts/check-skill-shape.sh scripts/check-skill-shape-test.sh
git commit -m "feat: gate skill directories on cheat-sheet coverage"
```

**Acceptance criteria:**
- `check-skill-shape.sh [root]` behaves identically to today when called with
  no argument.
- `./scripts/check-skill-shape-test.sh` passes standalone and via `just test`.
- `just shape-check` on the real repo tree still reports all skills passing.
- Rule 6 reports the exact string `<name>: not referenced in docs/cheatsheet.md`
  for a missing skill and nothing for a covered one, regardless of wording
  changes elsewhere in the document.

## Task 2 — Write `skills/seek-quest/SKILL.md`

**Files:** `skills/seek-quest/SKILL.md` (create)

**Interfaces:** None consumed from other tasks. Produces the skill file
`shape-check`'s inventory (Task 1's rule 1/2/4/5, and rule 6 once Task 3
lands) evaluates by directory name `seek-quest` and frontmatter `name:
seek-quest`.

This step deliberately runs **before** Task 3 updates the cheat sheet, so
`just shape-check` demonstrates rule 6 firing on a real, non-fixture
addition — the same proof Step 1.2's fixture gives synthetically, now shown
against this actual change.

### Step 2.1 — Create the skill directory and file

Create `skills/seek-quest/SKILL.md` with exactly this content (transcribed
from `docs/workflow/specs/2026-08-12-seek-quest-design.md`'s "`$seek-quest`
skill body" section, with the frontmatter this repo's `check-skill-shape.sh`
rule 2 requires):

```markdown
---
name: seek-quest
description: "Rank the status:ready GitHub issue queue and recommend the next issue to work, excluding untriaged, occupied, or blocked candidates. Use when asked to pick the next issue, choose what to work on next, or select from the ready backlog before running $quest."
---
# Recommend the Next Ready Issue

Rank the `status:ready` GitHub issue queue and recommend the top candidate for
`$quest`. **Read-only** — this skill writes nothing to GitHub, git, or the
filesystem, exactly like `$divination`. It never invokes `$quest` or
`$sort-board`; recommending and acting are separate explicit steps, and this
skill only recommends.

Input: an optional caller-supplied risk allowlist and/or effort allowlist
(e.g. "risk:night-safe only", "effort S or M"). No input narrows nothing.

## Steps

1. **Resolve repo.** `gh repo view --json nameWithOwner --jq .nameWithOwner` →
   `owner/name`; pass `--repo <owner/name>` on every subsequent `gh` call.

2. **Fetch the open queue.**
   `gh issue list --repo <owner/name> --state open --json number,title,labels,assignees,createdAt,body --limit 500`.
   If exactly 500 rows return, warn that the sweep is truncated at the limit
   rather than treating it as the complete backlog.

3. **Classify.**
   - Drop every `epic`-labeled issue.
   - **Untriaged**: no `status:*` label at all, or `status:needs-triage`.
   - **Ready pool**: `status:ready`.
   - Everything else (`status:in-progress`, `status:in-review`,
     `status:awaiting-merge`, `status:blocked`, `status:needs-human`) takes
     no further part below.

4. **Triage-freshness checkpoint.** If the untriaged set is non-empty, report
   its count and issue numbers, then ask exactly one question with two
   options: *"Run `$sort-board` on these first"* or *"Continue ranking the
   ready-only pool now."* Never run `$sort-board` yourself either way. If the
   user picks "continue," carry `ready-only: true` into the report. If the
   untriaged set is empty, continue with `ready-only: false`.

5. **Eligibility filter — completeness.** From the ready pool, keep only
   issues carrying exactly one label in each of `priority:*`, `risk:*`, and
   `effort:*`. Report (but do not rank) any ready issue failing this, naming
   the dimension and how: `#N ready but incompletely classified (missing
   risk:)` for zero labels in a dimension, `#N ready but ambiguously
   classified (two priority: labels)` for more than one.

6. **Eligibility filter — occupancy and blocked-dependency.** Apply these
   signals to what remains from Step 5:
   - Drop any issue whose `assignees` array is non-empty.
   - Fetch branches once: `git ls-remote --heads origin` (or `git branch -a`
     if no `origin` remote is configured). For each surviving candidate
     issue number `N`, drop it if any branch name ends in `-N` anchored to
     end-of-string (a hyphen immediately followed by the digits of `N` and
     nothing after — this is what `$quest`'s `feat/<slug>-<issue-number>`
     convention guarantees, and the anchor is what keeps `#5` from matching
     `...-56` or `...-156`).
   - Fetch open PRs once:
     `gh pr list --repo <owner/name> --state open --json number,body,headRefName --limit 200`.
     If exactly 200 rows return, warn that PR occupancy detection is
     truncated at the limit. For each surviving candidate `N`, drop it if
     any open PR's body contains, case-insensitively and at a word boundary
     (so "discloses" does not match `closes`), one of `close`, `closes`,
     `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`,
     followed by optional whitespace, then `#N` and a non-digit character
     or end of string — the optional whitespace matches `$deliver`'s own
     `Closes #<issue-number>` convention, and the trailing boundary keeps
     `#5` from matching a body that says `closes #56` — or if any PR's
     `headRefName` matches the same anchored branch-suffix rule as above.
   - For each surviving candidate, scan its `body` line by line for the
     `quest-log` dependency contract's three states:
     - **No line begins `Blocked by #`.** This check passes.
     - **At least one line is a canonical whole-line `Blocked by #M`
       record** (case-sensitive, no leading/trailing content, decimal
       digits after `#`). Resolve every referenced `M` with
       `gh issue view M --repo <owner/name> --json state`. Drop the
       candidate unless every canonical reference resolves closed.
     - **A line begins exactly `Blocked by #` but fails that grammar.**
       Malformed and holds the issue blocked regardless of any other
       canonical line present: drop the candidate.
     Only the first branch allows the candidate through; the other two fail
     closed.
   - Report every dropped issue with its reason (`assigned`, `branch
     <name>`, `PR #<n>`, or `blocked by #<m>`) — nothing is silently
     dropped.

7. **Apply caller constraints, then rank.** Drop any remaining candidate
   whose `risk:`/`effort:` value is not in a supplied allowlist; no supplied
   constraint means no filter on that dimension. Sort what remains by
   `priority:` ascending numeric order (`P0` most urgent, `P3` least), then
   by `createdAt` ascending (oldest first) as the first tie-break, then by
   issue `number` ascending as the final tie-break (`createdAt` is not
   guaranteed unique for batch-created issues; `number` always is).

8. **Empty-queue and winner-revalidation gates.**
   - If the ranked list from Step 7 is empty, direct the user to
     `$sort-board` regardless of whether the untriaged set was empty —
     `$sort-board` also re-evaluates `status:blocked` candidates for
     cleared dependencies, so it is the right next step whether the empty
     pool comes from untriaged, blocked, or unclassified issues. Point at
     whatever Step 3/5/6 dropped as the reason.
   - Otherwise, walk the ranked list from the top. For each candidate,
     re-run Step 6's status/dependency checks via a fresh
     `gh issue view <candidate> --repo <owner/name> --json labels,body`.
     Keep a candidate that survives as one of the report's surviving
     candidates; drop and note why one that doesn't. Continue until three
     candidates survive or the ordering is exhausted — a demoted winner is
     backfilled from further down the list, not just dropped from the
     count. If revalidation leaves zero survivors, fall back to the first
     gate above.

9. **Report.** Present the surviving ranked candidates (up to three) as
   `#N — title (priority:P_, risk:_, effort:_, created <date>)`, name the
   winner explicitly (the first survivor), and give a one-line ordering
   rationale. When `ready-only: true`, prefix the recommendation with "best
   among currently ready issues (N untriaged issues were not considered)."
   State that invoking `$quest <winner>` is a separate, explicit next
   action — this skill does not do it.

## Hard constraints

- `gh`, `git ls-remote`/`git branch`, and `Read` only — no `gh issue edit`,
  no comments, no labels, no branches created, no file writes, no invoking
  `$quest` or `$sort-board`.
- Explicit `--json` fields on every `gh` read; no unbounded `gh issue list`
  without `--limit` and a truncation check.
- Every exclusion in Steps 5–6 is reported with its reason; nothing is
  silently dropped from the candidate pool.
- Ground every ranking claim in label data or issue text actually read —
  never infer priority, risk, or effort beyond what a label states.
- Fail stop, not silent, on a `gh`/`git` command in Steps 1–2, 6, or 8 that
  could not run (auth failure, rate limit, no network, no `origin` remote).
  Report which command failed and its error text rather than treating the
  failure as a zero-result success.
```

### Step 2.2 — Confirm rule 6 fires on the real, undocumented addition

Run: `./scripts/check-skill-shape.sh`

Expect **failure**: exit 1, with
`check-skill-shape: seek-quest: not referenced in docs/cheatsheet.md` among
the output lines. This is the real-world proof that rule 6 works, ahead of
Task 3 fixing it.

### Step 2.3 — Commit

```
git add skills/seek-quest/SKILL.md
git commit -m "feat: add seek-quest skill to recommend the next ready issue"
```

**Acceptance criteria:**
- `skills/seek-quest/SKILL.md` exists with frontmatter `name: seek-quest`
  matching its directory.
- `./scripts/check-skill-shape.sh` fails with exactly the
  `not referenced in docs/cheatsheet.md` reason for `seek-quest` and no
  other new failures (rules 1, 2, 3, 4, 5 all still pass for this file).

## Task 3 — Document `$seek-quest` in `docs/cheatsheet.md`

**Files:** `docs/cheatsheet.md` (modify)

**Interfaces:** Consumes nothing beyond the skill name `seek-quest` from
Task 2. Its only observable effect other tasks depend on is making Task 1's
rule 6 pass for this skill.

### Step 3.1 — Add the "Start here" row

In the `## Start here` table, insert a new row immediately above the
`| My backlog needs type/priority/status labels | \`/sort-board\` |`
row:

```markdown
| I want the next issue to work, chosen for me | `/seek-quest` |
```

### Step 3.2 — Add the "Planning & backlog" row

In the `## Planning & backlog` table, insert a new row immediately after the
`sort-board` row:

```markdown
| `seek-quest` | Rank the `status:ready` queue and recommend the next issue to run `$quest` on |
```

### Step 3.3 — Add the lifecycle cross-reference sentence

In the `## Full lifecycle: \`/quest\`` section, immediately after the closing
code fence of the lifecycle diagram and before the `\`/campaign\` runs this
same lifecycle...` paragraph, add one sentence as its own paragraph:

```markdown
Have no specific issue in mind? `$seek-quest` ranks the `status:ready` queue
and recommends one before you start the lifecycle above — a separate,
read-only step, not a new stage of `/quest` itself.
```

### Step 3.4 — Confirm the gate now passes

Run: `./scripts/check-skill-shape.sh`

Expect: `check-skill-shape: 27 skills, all rules pass` and exit 0.

Run: `just verify`

Expect: every recipe in the `verify` chain
(`records commit-check shape-check ripgrep-config-check plugin-check test
actions-check`) passes, ending with the `prek run --all-files --stage
pre-commit --dry-run` line reporting success.

### Step 3.5 — Commit

```
git add docs/cheatsheet.md
git commit -m "docs: add seek-quest to the skill cheat sheet"
```

**Acceptance criteria:**
- `./scripts/check-skill-shape.sh` passes with `27 skills, all rules pass`.
- `just verify` passes end to end.
- The three edits are additive only — no existing table row, column, or
  sentence in `docs/cheatsheet.md` was restructured or reworded.

## Rollback

Every task is a small number of additive commits on
`feat/seek-quest-skill-56`; reverting any task's commit(s) with `git revert`
cleanly undoes it without touching the others, since Task 2 and Task 3 only
add new file content and Task 1's script edit is additive (a new optional
argument, a new rule appended after rule 5). No migration, no persisted
state, and no data to clean up — this is documentation and a CI script.
