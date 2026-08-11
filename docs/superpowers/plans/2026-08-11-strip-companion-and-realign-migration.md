# Strip Companion and Realign Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the skills import into `adept` without the code the rewrite design has already condemned, and bring the in-flight migration plan into `adept` aligned with that design.

**Architecture:** Two commits on the open import branch remove the visual companion and the prose-assertion blocks, after which PR #1 merges. The migration plan then moves from the repo being archived into `adept`, amended so its gate list drops the one surviving prose gate in favour of a small structural shape gate, and so the two companion bugs close as obsolete rather than transferring. Finally the two follow-up issues the spec names are filed.

**Tech Stack:** bash, `rg`, `shellcheck`, `git`, `gh`, `claude plugin validate`.

## Global Constraints

- Spec of record: `docs/superpowers/specs/2026-08-11-first-party-skill-rewrite-design.md` (in this repo). Rule numbers below refer to its §4.
- Work happens in `/Volumes/Source Code Volume/src/adept`. The source repo `/Volumes/Source Code Volume/src/agent-config` is referenced as `$OLD`; every shell block assumes `export OLD="/Volumes/Source Code Volume/src/agent-config"`. Note the space in both paths — always quote them.
- Tasks 1–2 add commits to the **existing** branch `feat/import-skills`, which is already pushed and open as PR #1. Do not create a new branch for them and do not rebase or force-push — all force pushes are denied by settings policy.
- Never push to `main`; the user's settings hook blocks it. Every push targets a feature branch.
- Every commit: conventional-commits subject ≤ 72 chars, imperative mood, ending with the trailer `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
- Deletes use `trash` (macOS), never `rm -rf`. Deleting tracked files with `git rm` is fine — that is a tracked-content operation, not a filesystem sweep.
- Run gates bare — no pipes that swallow exit codes, no `|| true`, no redirection that hides a failure.
- The validation gate is `claude plugin validate ./` with **no** `--strict`. Pass is exit 0. Exactly one warning is expected and accepted: `plugins[0] plugin.json → version: No version specified`. Any other warning is a defect.
- Shell style in this repo: tab indentation, `#!/usr/bin/env bash`, `set -euo pipefail`. `shellcheck` must be clean on anything added.
- Rule 4 forbids any gate or test that asserts on prose. Nothing in this plan may add one.

---

### Task 1: Remove the visual companion

**Files:**
- Delete: `skills/brainstorming/scripts/server.cjs`, `skills/brainstorming/scripts/start-server.sh`, `skills/brainstorming/scripts/stop-server.sh`, `skills/brainstorming/scripts/frame-template.html`, `skills/brainstorming/scripts/helper.js`
- Delete: `skills/brainstorming/visual-companion.md`
- Delete: `tests/fixtures/brainstorming/start-server-test.sh`, `tests/fixtures/brainstorming/stop-server-test.sh`
- Modify: `skills/brainstorming/SKILL.md`

**Interfaces:**
- Consumes: branch `feat/import-skills` as pushed (HEAD is `def4dd7`).
- Produces: a `skills/brainstorming/` directory containing only `SKILL.md`, and an empty-of-brainstorming `tests/fixtures/`. Task 2 edits two other suites; Task 3 merges the result.

- [ ] **Step 1: Check out the existing import branch**

```bash
cd "/Volumes/Source Code Volume/src/adept"
git checkout feat/import-skills
git pull --ff-only
git log --oneline -2
```

Expected: HEAD is `def4dd7 test(preflight): drop assertions on carriers this repo does not own`, on top of `f59dc3b feat: import 36 skills…`.

- [ ] **Step 2: Delete the companion files**

```bash
git rm -q skills/brainstorming/scripts/server.cjs \
         skills/brainstorming/scripts/start-server.sh \
         skills/brainstorming/scripts/stop-server.sh \
         skills/brainstorming/scripts/frame-template.html \
         skills/brainstorming/scripts/helper.js \
         skills/brainstorming/visual-companion.md \
         tests/fixtures/brainstorming/start-server-test.sh \
         tests/fixtures/brainstorming/stop-server-test.sh
```

- [ ] **Step 3: Confirm both directories are now gone**

```bash
ls skills/brainstorming/
ls tests/fixtures/
```

Expected: `skills/brainstorming/` contains only `SKILL.md` (git removes the now-empty `scripts/` directory). `tests/fixtures/` contains `github-tracking`, `issue`, `preflight`, `subagent-driven-development` — no `brainstorming`.

- [ ] **Step 4: Remove the dispatched-mode table row**

In `skills/brainstorming/SKILL.md`, delete this entire line:

```
| Checklist 2 / **Visual Companion** offer | Never applies — it requires a browser a human is looking at. Do not offer it. |
```

- [ ] **Step 5: Renumber the remaining dispatched-mode table rows**

Removing checklist item 2 shifts every later item down by one. In the same table, apply these four replacements:

| Find (start of row) | Replace with |
|---|---|
| `\| Checklist 3 — ask clarifying questions one at a time` | `\| Checklist 2 — ask clarifying questions one at a time` |
| `\| Checklist 5 — approval after each design section` | `\| Checklist 4 — approval after each design section` |
| `\| Checklist 8 / **User Review Gate**` | `\| Checklist 7 / **User Review Gate**` |
| `\| Checklist 9 / terminal state` | `\| Checklist 8 / terminal state` |

Leave the rest of each row unchanged.

- [ ] **Step 6: Delete checklist item 2 and renumber items 3–9**

Delete this line entirely:

```
2. **Offer the visual companion just-in-time** — NOT upfront. The first time a question would genuinely be clearer shown than described, offer it then (its own message); on approval its browser tab opens for you. If no visual question ever arises, never offer it. See the Visual Companion section below.
```

Then renumber the remaining items so the list reads 1–8. After this step the checklist must be exactly:

```
1. **Explore project context** — check files, docs, recent commits
2. **Ask clarifying questions** — one at a time, understand purpose/constraints/success criteria
3. **Propose 2-3 approaches** — with trade-offs and your recommendation
4. **Present design** — in sections scaled to their complexity, get user approval after each section
5. **Write design doc** — save to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and commit
6. **Spec self-review** — quick inline check for placeholders, contradictions, ambiguity, scope (see below)
7. **User reviews written spec** — ask user to review the spec file before proceeding
8. **Transition to implementation** — invoke writing-plans skill to create implementation plan
```

- [ ] **Step 7: Fix the sentence naming which items change**

Replace:

```
You MUST create a task for each of these items and complete them in order. In dispatched mode, items 2, 3, 5, 8 and 9 change — see the table above before you create the tasks, so the list you build is the one you can actually finish.
```

with:

```
You MUST create a task for each of these items and complete them in order. In dispatched mode, items 2, 4, 7 and 8 change — see the table above before you create the tasks, so the list you build is the one you can actually finish.
```

- [ ] **Step 8: Delete the Visual Companion section**

Delete everything from the line `## Visual Companion` to the end of the file, inclusive. That section currently runs to the last line of `SKILL.md` (`` `skills/brainstorming/visual-companion.md` ``), so the file's new final content is the end of the `## Key Principles` section. Remove any trailing blank lines the deletion leaves, so the file ends with a single newline after its last sentence.

- [ ] **Step 9: Prove no reference survives**

```bash
rg -n 'visual.companion|Visual Companion|server\.cjs|start-server|stop-server|frame-template|helper\.js' .
```

Expected: no output. If anything matches outside `.git/`, fix it before continuing.

- [ ] **Step 10: Prove the checklist numbering is self-consistent**

```bash
rg -n '^[0-9]+\. \*\*' skills/brainstorming/SKILL.md
rg -n 'Checklist [0-9]' skills/brainstorming/SKILL.md
```

Expected: the first command prints items numbered 1 through 8 with no gaps or repeats. The second prints exactly four rows, referencing Checklist 2, 4, 7 and 8 — every one of which is a real item number from the first command.

- [ ] **Step 11: Validate the plugin still loads**

```bash
claude plugin validate ./
```

Expected: exit 0, exactly one warning (the accepted `version` one).

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -F - <<'EOF'
feat(brainstorming): remove the browser visual companion

A Node HTTP server plus shell PID lifecycle -- 1,411 lines across
server.cjs, start-server.sh, stop-server.sh, frame-template.html and
helper.js -- to offer browser mockups during a design conversation. Two
open bugs against it (agent-config#77, #78) are both defects in the
"is the previous instance still alive" logic, which exists only because
something had to survive between invocations.

The rewrite design bans long-lived processes by construction (spec §4
rule 3), so this capability has no successor rather than a replacement.
The skill keeps its terminal dialogue, which is what it was doing well.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
```

---

### Task 2: Remove the prose-assertion blocks

**Files:**
- Modify: `tests/fixtures/preflight/architecture-awareness-test.sh`
- Modify: `tests/fixtures/issue/create-verified-issue-test.sh`

**Interfaces:**
- Consumes: Task 1's branch state.
- Produces: two suites that assert only on executable behaviour. Task 3 merges them.

Rule 4 forbids automated assertions on prose. Both suites currently grep a `SKILL.md` for sentences and table rows. The executable-behaviour assertions in both files are untouched — those are the tests worth having.

- [ ] **Step 1: Remove the preflight suite's SKILL.md block**

In `tests/fixtures/preflight/architecture-awareness-test.sh`, delete the assignment, its two explanatory comment lines, the whole `for expected in … done` loop, and the now-orphaned comment block that follows. Concretely, delete from the line:

```bash
preflight="$ROOT/skills/preflight/SKILL.md"
```

through the end of the comment paragraph that begins `# The projection assertions that stood here`, leaving the file ending with:

```bash
printf 'architecture-awareness-test: all assertions passed\n'
```

The deleted loop asserts 17 phrases and Markdown table rows against the skill document, including `'| 4 | Host is in the effective target set | `included` |'`.

- [ ] **Step 2: Run the preflight suite**

```bash
./tests/fixtures/preflight/architecture-awareness-test.sh
echo "EXIT=$?"
```

Expected: the detector and resolver cases all print `ok`, the final line is `architecture-awareness-test: all assertions passed`, and `EXIT=0`.

- [ ] **Step 3: Confirm no variable was orphaned**

```bash
shellcheck tests/fixtures/preflight/architecture-awareness-test.sh
echo "EXIT=$?"
```

Expected: `EXIT=0` with no output. `ROOT` is still used by `DETECTOR` and `RESOLVER`, and `FIXTURE` by the case helpers, so neither should be reported unused. If shellcheck flags an unused variable, remove that assignment too and re-run both this step and Step 2.

- [ ] **Step 4: Remove the issue suite's SKILL.md block**

In `tests/fixtures/issue/create-verified-issue-test.sh`, delete these eight lines exactly:

```bash
skill_file="$skill_root/SKILL.md"
assert_contains 'scripts/create-verified-issue.sh' "$skill_file"
assert_contains 'Retain the populated temporary body file' "$skill_file"
assert_contains 'verified URL is the only success result' "$skill_file"
assert_contains 'Do not retry, replace, or create a duplicate' "$skill_file"
if rg -n 'gh issue create --repo|gh issue create --parent' "$skill_file" >/dev/null; then
	fail 'SKILL.md retains a direct issue-create bypass'
fi
```

- [ ] **Step 5: Run the issue suite and check for an orphaned variable**

```bash
./tests/fixtures/issue/create-verified-issue-test.sh
echo "EXIT=$?"
shellcheck tests/fixtures/issue/create-verified-issue-test.sh
echo "SHELLCHECK=$?"
```

Expected: both `EXIT=0` and `SHELLCHECK=0`. `skill_root` is assigned near the top of the file and may now be unused — if shellcheck reports it, delete its assignment line too and re-run this step.

- [ ] **Step 6: Prove no prose assertion remains in any suite**

```bash
rg -n 'SKILL\.md' tests/
```

Expected: no output.

- [ ] **Step 7: Run every suite**

```bash
for s in tests/fixtures/*/*-test.sh skills/decision-records/assets/check-records-test.sh; do
	printf '== %s ... ' "$s"
	if "./$s" >/dev/null 2>&1; then echo PASS; else echo FAIL; fi
done
```

Expected: 6 lines, all `PASS` — `github-tracking` × 2, `issue`, `preflight`, `subagent-driven-development`, and `decision-records`. The two brainstorming suites are gone as of Task 1.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -F - <<'EOF'
test: stop asserting on skill prose

Two suites grepped a SKILL.md for sentences and Markdown table rows --
17 phrases in the preflight suite, 4 plus a forbidden-pattern check in
the issue suite. Pinning prose makes every wording improvement a test
failure, and the gate class it belongs to produced false reds under
bracketed paths, non-UTF-8 bytes and personal ripgrep configs.

Spec §4 rule 4: nothing automated asserts on prose. The executable
behaviour assertions in both suites are unchanged.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
```

---

### Task 3: Merge PR #1

**Files:** none (GitHub state only).

**Interfaces:**
- Consumes: Tasks 1–2 committed on `feat/import-skills`.
- Produces: `main` carrying the skills import. Task 4's relocated plan describes work against this `main`.

- [ ] **Step 1: Push**

```bash
git push origin feat/import-skills
```

- [ ] **Step 2: Update the PR body to describe what it now does**

The PR was opened before Tasks 1–2 existed and its body still promises the companion and the prose assertions. Rewrite it to describe the diff as it now stands:

```bash
gh pr edit 1 --title "feat: import the skills tree, without the companion or prose assertions" --body "$(cat <<'BODY'
Imports the 36 development-workflow skills from the retired `agent-config` repo into this plugin.

## Fixtures move out of the shipped tree

A plugin has no installer -- the whole repo is copied into the plugin cache -- so a fixture inside a skill's own directory is reachable by that skill at runtime. That has caused a real incident before: a stub issue-tracker profile shipped, was selectable, and returned fabricated issues. The five `testdata/` trees (which carry their suites as well as their fixtures) now live under `tests/fixtures/<skill>/`, each resolving its subject through `../../../skills/...`.

## The visual companion does not come across

1,411 lines of Node server and shell PID lifecycle, with two open bugs both in the "is the previous instance still alive" class. The rewrite design bans long-lived processes by construction, so this has no successor.

## Nothing asserts on prose

Three blocks of `SKILL.md` grepping are gone: the cross-repo projection assertions, the preflight suite's 17 phrase-and-table-row checks, and the issue suite's 4 phrase checks plus forbidden-pattern scan. Executable behaviour assertions are untouched.

## Verification

    6/6 suites pass
    claude plugin validate ./  -> exit 0, one accepted warning (no version field)
    shellcheck clean on every edited suite
    rg 'SKILL\.md' tests/  -> no output
BODY
)"
```

- [ ] **Step 3: Confirm mergeable, then merge**

```bash
gh pr view 1 --json mergeable,mergeStateStatus
gh pr merge 1 --rebase
```

Expected: `mergeable: MERGEABLE` before merging. There is no CI in this repo yet — the migration plan's Task 3 adds it — so the local suite runs from Task 2 Step 7 and the validation run are this merge's evidence.

- [ ] **Step 4: Sync local main**

```bash
git checkout main
git pull --ff-only
git branch -d feat/import-skills
git remote prune origin
ls skills | wc -l
```

Expected: 36 skills on `main`, and the local feature branch deleted.

---

### Task 4: Relocate and realign the migration plan

**Files:**
- Create: `docs/superpowers/plans/2026-08-11-adept-dotfiles-separation.md` (moved from `$OLD/docs/superpowers/plans/`)
- Modify (within that file): the Task 3 gate list, the Task 3 `Justfile` recipe block, the Task 11 issue disposition, and the "deliberately not carried" section

**Interfaces:**
- Consumes: `main` after Task 3.
- Produces: the migration plan living in `adept`, aligned with the rewrite spec. Its Tasks 3–12 are executed later, not by this plan.

The migration plan currently exists only as an untracked file in the repo being archived. It must move here, and three things in it now contradict the rewrite spec.

- [ ] **Step 1: Branch and copy the plan in**

```bash
git checkout -b docs/realign-migration-plan
mkdir -p docs/superpowers/plans
cp "$OLD/docs/superpowers/plans/2026-08-11-adept-dotfiles-separation.md" \
   docs/superpowers/plans/2026-08-11-adept-dotfiles-separation.md
```

- [ ] **Step 2: Drop `check-skill-layout.sh` from the carried gate list**

In the copied plan's Task 3, the "Files" block lists the scripts to copy. Replace:

```
- Create: `adept/scripts/` — copied subset: `check-skill-layout.sh` (+test), `check-public-safety.sh` (+test), `check-ripgrep-config.sh` (+test), `verify-push.sh` (+test), `git-fixture-isolation-test.sh`, `list-shell-sources.sh`, `pre-push-hook`, `reserved-skill-names.txt`
```

with:

```
- Create: `adept/scripts/` — copied subset: `check-public-safety.sh` (+test), `check-ripgrep-config.sh` (+test), `verify-push.sh` (+test), `git-fixture-isolation-test.sh`, `list-shell-sources.sh`, `pre-push-hook`, `reserved-skill-names.txt`
- Create: `adept/scripts/check-skill-shape.sh` — new, written in this task (see Step 4). Replaces `check-skill-layout.sh`.
```

Then, in the same Task's "Not carried" line, add `check-skill-layout.sh` to the list and give it its own reason. Replace:

```
- **Not carried** (they model the retired installer): `check-deployed-membership.sh`, `check-deployed-references.sh`, `check-carrier-drift.sh`, `check-shared-standards.sh`, `claude-settings-hooks-test.sh`, `claude-settings-posix-guard-test.sh` (the last two move to dotfiles in Task 8), and their test suites.
```

with:

```
- **Not carried** (they model the retired installer): `check-deployed-membership.sh`, `check-deployed-references.sh`, `check-carrier-drift.sh`, `check-shared-standards.sh`, `claude-settings-hooks-test.sh`, `claude-settings-posix-guard-test.sh` (the last two move to dotfiles in Task 8), and their test suites.
- **Not carried** (rewrite spec §4 rule 4 — nothing automated asserts on prose): `check-skill-layout.sh` (563 lines) and `check-skill-layout-test.sh` (753 lines). Its encoding and content-scanning rules are the gate class that produced false reds under bracketed checkout paths, non-UTF-8 bytes and personal ripgrep configuration. The structural subset worth keeping is re-implemented as `check-skill-shape.sh` in Step 4 — roughly 50 lines against 1,316.
```

- [ ] **Step 3: Swap the recipe in the plan's `Justfile` block**

In the plan's Task 3 Step 3 (the `Justfile` content), replace:

```just
skills-check:
  ./scripts/check-skill-layout.sh
```

with:

```just
shape-check:
  ./scripts/check-skill-shape.sh
```

and in the same block replace the `verify` line:

```just
verify: records commit-check skills-check ripgrep-config-check plugin-check test actions-check
```

with:

```just
verify: records commit-check shape-check ripgrep-config-check plugin-check test actions-check
```

Also update the plan's Task 3 "Interfaces / Produces" line, replacing the recipe name `skills-check` with `shape-check`, and its Step 6 sentence naming likely failures, replacing `check-skill-layout.sh` path assumptions (Step 2 missed one)` with `check-skill-shape.sh` rejecting a skill whose frontmatter name and directory disagree`.

- [ ] **Step 4: Insert the shape gate as a new step in the plan's Task 3**

Add this as a new step in the copied plan's Task 3, immediately after its Step 2 (the path-repointing step). It is written into the plan for later execution — do not create the script in this repo now.

````markdown
- [ ] **Step 2b: Write the structural shape gate**

`scripts/check-skill-shape.sh` (entire file; tabs, not spaces):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Structural rules only. Rule 4 of the rewrite spec forbids any gate that
# asserts on prose, so nothing here reads a document's wording -- only whether
# the pieces that must exist do, and whether names resolve.
#
# rg gets --no-config throughout: it reads RIPGREP_CONFIG_PATH ahead of its own
# arguments, so a developer's personal ripgreprc would otherwise steer a gate's
# verdict.
#
# Bash 3.2 is the floor. macOS ships 3.2.57 and no script in this repo uses a
# bash 4 feature, so there is no mapfile and no associative array here.
# Membership is a sorted file plus a fixed whole-line grep.
#
# Every scan captures rg's status explicitly rather than trailing `|| true`.
# rg exits 1 for "no matches" and >1 for a real failure; collapsing those makes
# a scan that could not run read as a scan that found nothing.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0

report() {
	printf 'check-skill-shape: %s\n' "$1" >&2
	status=1
}

workspace="$(mktemp -d "${TMPDIR:-/tmp}/check-skill-shape.XXXXXX")"
trap 'rm -R "$workspace"' EXIT

names="$workspace/names"
find "$root/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort >"$names"

count="$(wc -l <"$names" | tr -d ' ')"
if [ "$count" -eq 0 ]; then
	printf 'check-skill-shape: no skills found under %s/skills\n' "$root" >&2
	exit 1
fi

# Rule 1: every skill directory has a SKILL.md.
# Rule 2: its `name:` frontmatter matches the directory name.
while IFS= read -r name; do
	skill_file="$root/skills/$name/SKILL.md"
	if [ ! -f "$skill_file" ]; then
		report "$name: no SKILL.md"
		continue
	fi
	declared=''
	name_status=0
	# -r is --replace, not recursive: capture the value and emit only it. \K is
	# avoided deliberately -- it is PCRE2-only and needs rg -P, which not every
	# rg build carries.
	declared="$(rg --no-config -m1 -N -o -r '$1' '^name: *(\S+)' "$skill_file")" || name_status=$?
	if [ "$name_status" -gt 1 ]; then
		printf 'check-skill-shape: reading %s failed (rg exit %s)\n' "$skill_file" "$name_status" >&2
		exit 1
	fi
	if [ -z "$declared" ]; then
		report "$name: SKILL.md has no name: frontmatter"
	elif [ "$declared" != "$name" ]; then
		report "$name: SKILL.md declares name: $declared"
	fi
done <"$names"

# Rule 3: no skill name collides with a harness-reserved name.
reserved_status=0
rg --no-config -v '^#|^$' "$root/scripts/reserved-skill-names.txt" |
	sort -u >"$workspace/reserved" || reserved_status=$?
if [ "$reserved_status" -gt 1 ]; then
	printf 'check-skill-shape: reading the reserved-name list failed (exit %s)\n' "$reserved_status" >&2
	exit 1
fi
while IFS= read -r reserved; do
	if grep -qxF -- "$reserved" "$names"; then
		report "$reserved: collides with a reserved harness name"
	fi
done <"$workspace/reserved"

# Rule 4: every `$invocation` resolves to a skill that exists. This is what
# makes the rename sweep safe -- a stale $name is otherwise silent until
# someone runs it.
#
# Only the backticked form is scanned. It is the convention in 244 of 293
# references, and the bare form collides with ordinary shell variables in
# fenced examples ($root, $path, $err, $c), which would make this gate cry wolf
# on every skill that documents a command. Measured against the current tree,
# the backticked rule has zero false positives.
refs_status=0
rg --no-config -o -N '`\$[a-z][a-z0-9-]*`' "$root"/skills/*/SKILL.md \
	>"$workspace/raw" || refs_status=$?
if [ "$refs_status" -gt 1 ]; then
	printf 'check-skill-shape: scanning invocations failed (rg exit %s)\n' "$refs_status" >&2
	exit 1
fi
# shellcheck disable=SC2016 # the $ is a literal to strip, not an expansion
sed 's/.*`\$//;s/`//' "$workspace/raw" | sort -u >"$workspace/refs"
while IFS= read -r ref; do
	if ! grep -qxF -- "$ref" "$names"; then
		report "\$$ref is invoked but no such skill exists"
	fi
done <"$workspace/refs"

if [ "$status" -eq 0 ]; then
	printf 'check-skill-shape: %s skills, all rules pass\n' "$count"
fi
exit "$status"
```

Run it:

```bash
chmod +x scripts/check-skill-shape.sh
./scripts/check-skill-shape.sh
```

Expected: `check-skill-shape: 36 skills, all rules pass`, exit 0. Also run `shellcheck scripts/check-skill-shape.sh` — expected clean, exit 0.

This script was written and verified against the real tree on 2026-08-11 under the system bash (3.2.57) before being recorded here. Reproduce that proof — a gate that cannot fail is not a gate. Revert after each mutation:

| Mutation | Expected output |
|---|---|
| `mv skills/retro/SKILL.md skills/retro/SKILL.md.bak` | `check-skill-shape: retro: no SKILL.md`, exit 1 |
| change `name: retro` to `name: bards-tale` | `check-skill-shape: retro: SKILL.md declares name: bards-tale`, exit 1 |
| append ``See `$nosuchskill` for details.`` to any `SKILL.md` | `check-skill-shape: $nosuchskill is invoked but no such skill exists`, exit 1 |

Rule 3 needs no mutation: it is proved by the reserved-names file holding 160 entries with no current skill among them.

The second mutation is worth noticing — it is exactly the rename sweep's failure mode, caught by the gate that makes the sweep safe.
````

- [ ] **Step 5: Change the Task 11 disposition of the companion bugs**

In the copied plan's Task 11, issues `77` and `78` are listed among those transferring to `adept`. They must close instead — their subject no longer exists as of Task 1 of this plan.

In Task 11 Step 1's close list, add `77, 78`. In Step 3's transfer list, remove `77, 78` and delete the parenthetical clause `(#77/#78 concern the brainstorming skill's server scripts, which live in adept's skills/brainstorming/` … `)`, replacing it with a note that `#167` spans gate scripts in both repos.

Then add this sentence to Task 11 Step 1, after the existing `#118` note:

```
For #77 and #78, the close comment names the reason precisely: the brainstorming visual companion was deleted rather than fixed, because the rewrite design bans long-lived processes by construction (spec §4 rule 3). Both bugs are defects in exactly the liveness logic that ban removes.
```

- [ ] **Step 6: Add the retired prose gate to the plan's "deliberately not carried" section**

In the copied plan's closing "Deliberately not carried" list, add:

```
- **`check-skill-layout.sh` + suite (1,316 lines)** — retired by rewrite spec §4 rule 4. Replaced by `check-skill-shape.sh` (~50 lines), which keeps the structural rules (a SKILL.md exists, its declared name matches its directory, no reserved-name collision, every `$invocation` resolves) and drops the content-scanning rules that generated the false reds. The encoding rules go with it: a plugin cache copies bytes, and a mis-encoded document is visibly broken rather than silently wrong.
```

- [ ] **Step 7: Check the amended plan is self-consistent**

```bash
rg -n 'check-skill-layout|skills-check' docs/superpowers/plans/2026-08-11-adept-dotfiles-separation.md
```

Expected: matches appear **only** in the two "not carried" entries added in Steps 2 and 6, which name the retired gate deliberately. No remaining match may be a `Files:` entry, a copy loop, a `Justfile` recipe, or a `verify` dependency.

```bash
rg -n 'check-skill-shape|shape-check' docs/superpowers/plans/2026-08-11-adept-dotfiles-separation.md
```

Expected: at least five matches — the Files entry, the not-carried cross-reference, the recipe, the `verify` dependency, and Step 2b.

- [ ] **Step 8: Commit and open a PR**

```bash
git add docs/superpowers/plans/2026-08-11-adept-dotfiles-separation.md
git commit -F - <<'EOF'
docs: bring the migration plan here, aligned with the rewrite spec

The plan lived only as an untracked file in the repo it retires. Three
things in it now contradict the rewrite design: it carried
check-skill-layout.sh and its suite (1,316 lines of content scanning),
wired that gate into just verify, and transferred the two visual
companion bugs to a repo where their subject no longer exists.

Replaces the gate with check-skill-shape.sh -- a structural check that a
SKILL.md exists, its declared name matches its directory, no name
collides with a reserved one, and every $invocation resolves. That last
rule is what makes the planned rename sweep safe.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
git push -u origin docs/realign-migration-plan
gh pr create --fill
gh pr merge --rebase
```

- [ ] **Step 9: Remove the stale copy from the archived repo's working tree**

The original is untracked in `$OLD` and would otherwise be the only copy anyone finds there.

```bash
trash "$OLD/docs/superpowers/plans/2026-08-11-adept-dotfiles-separation.md"
ls "$OLD/docs/superpowers/plans/"
```

Expected: the directory no longer contains the separation plan. It is recoverable from Trash, and the authoritative copy is now committed in `adept`.

---

### Task 5: File the follow-up issues

**Files:** none (GitHub state only).

**Interfaces:**
- Consumes: the spec's "Follow-up issues to file" section.
- Produces: two open issues in `randomparity/adept`, referenced by the spec.

- [ ] **Step 1: File the evals experiment issue**

```bash
gh issue create --repo randomparity/adept \
  --title "Experiment: does claude plugin eval give stable skill regression coverage?" \
  --body "$(cat <<'BODY'
The rewrite design (`docs/superpowers/specs/2026-08-11-first-party-skill-rewrite-design.md` §5) defers evals rather than rejecting them.

`claude plugin eval` runs cases (`evals/**/case.yaml`, or `prompt.md` plus `graders/*.md`) against a plugin and scores them. It tests whether invoking a skill actually changes agent behaviour, which is the thing worth testing and the opposite of asserting on prose (§4 rule 4 forbids the latter).

It was deferred for one reason: graders are LLM-scored and therefore non-deterministic, and adopting them as a gate means signing up for grader tuning -- a new treadmill in the shape of the one this work is removing.

## What this issue asks for

Try it on one or two skills after the rewrite, and answer:

- Does the same eval, run five times against an unchanged skill, return the same verdict every time?
- When a skill is deliberately broken, does the eval redden?
- What does one run cost in tokens and wall-clock?

Adopt broadly only if runs are stable. If they flake, close this and record why -- a flake that passes on re-run is not evidence.

Blocked on the rewrite landing (spec §6 step 4).
BODY
)"
```

- [ ] **Step 2: File the cross-repo drift issue**

```bash
gh issue create --repo randomparity/adept \
  --title "No check that the preflight skill and the standards documents agree" \
  --body "$(cat <<'BODY'
The `agent-config` split puts the `preflight` skill in this repo and the standards documents it is supposed to agree with (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) in the private `dotfiles` repo. Nothing verifies they still agree.

## How the gap opened

The old repo held both, and two gates covered the coupling: `check-carrier-drift.sh` and `check-shared-standards.sh`. Neither survives the split -- they cannot read across repos. A third check lived inside the preflight suite itself, asserting that the skill's architecture rules were mirrored into five carrier documents; it was removed in commit `def4dd7` for the same reason.

So the coupling is real and now entirely unguarded. If the preflight skill's architecture contract changes and CLAUDE.md doesn't, nothing says so.

## What this issue is not

It is not a request for a new prose gate. Spec §4 rule 4 forbids that, and the removed gates are precisely the class that produced false reds under bracketed paths, non-UTF-8 bytes and personal ripgrep configs.

## What it needs

A decision, not a regex. Options worth weighing:

- Accept the drift risk and rely on reading -- two documents, changed rarely.
- Move the architecture contract wholly into one place so there is nothing to mirror.
- Have `dotfiles` own a periodic reconciliation step rather than a blocking gate.

Related: `agent-config#152`, which flagged the same class of coupling before the split.
BODY
)"
```

- [ ] **Step 3: Confirm both are open**

```bash
gh issue list --repo randomparity/adept --state open --json number,title --limit 10
```

Expected: exactly two issues, matching the titles above.

---

## Deliberately not in this plan

- **The migration itself** (its Tasks 3–12). This plan only relocates and realigns that document; executing it is the next unit of work.
- **The rewrite** (spec §6 steps 4–6). Behavior inventories, the eleven rewrites, the similarity gate, and the rename sweep each get their own plan.
- **Writing `check-skill-shape.sh` in this repo.** Its complete source is embedded in the amended migration plan's Task 3 Step 2b, where the rest of the gate suite is created. Creating it here would leave it wired into nothing until that task runs.
- **adept's `CLAUDE.md`** carrying the four anatomy rules. That belongs with the rewrite, whose rules it states; adding it now would describe a repo that does not yet exist.
