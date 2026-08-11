# First-Party Skill Rewrite — Design

**Date:** 2026-08-11
**Status:** Approved
**Repo:** `randomparity/adept`

## Context

Eleven of this repo's skills descend from [obra/superpowers](https://github.com/obra/superpowers) v6.1.1 (commit `d884ae04`), carried as maintained forks under the retired `agent-config` repo's ADR 0005. Maintaining them has cost sustained effort disproportionate to their value, concentrated in one place: the `brainstorming` skill's browser visual companion — a Node HTTP server plus shell lifecycle management (`server.cjs` 723 lines, `start-server.sh` 298, `frame-template.html` 213, `helper.js` 167, `stop-server.sh` 132, and two suites). Two open bugs against it (`agent-config#77`, `#78`) are both PID-lifecycle defects, and neither is the first.

This design replaces all eleven with first-party equivalents.

## Drivers, in priority order

1. **Less machinery.** Skills that do not generate edge-case pull requests.
2. **Fit.** The inherited skills encode another project's workflow assumptions that keep getting bent toward this one.
3. **Shedding the attribution obligation.** ADR 0005's fork-maintenance policy, `docs/licenses/superpowers.md`, the MIT notice, and the re-vendor ritual are overhead. This is a welcome consequence of a genuine rewrite, not a reason to compromise drivers 1 or 2.

## 1. Disposition of the eleven

The eleven derived skills are not peers of the first-party skills — they are an inner layer the first-party skills wrap. `$design` exists largely to sequence `brainstorming` → review → `writing-plans`; `$build-tdd` sequences `test-driven-development` with `subagent-driven-development` or `executing-plans`; `$review-loop` wraps `receiving-code-review`. That coupling is itself a machinery source: each derived skill carries a large "dispatched workflow mode" section that exists solely because a first-party wrapper calls it.

Placement follows three tests. Is it a **procedure you invoke** (skill), a **standard you consult while doing something else** (reference), or **a step inside a procedure already owned elsewhere** (absorbed)?

| Derived skill | Disposition | Destination |
|---|---|---|
| `brainstorming` | absorbed | `$design` — dialogue phase |
| `writing-plans` | absorbed | `$design` — plan-writing phase |
| `executing-plans` | absorbed | `$build-tdd` — direct-execution mode |
| `subagent-driven-development` | absorbed | `$build-tdd` — subagent mode; its `sdd-workspace`, `task-brief`, `review-package` scripts move to `skills/build-tdd/scripts/` |
| `using-git-worktrees` | absorbed | `$build-tdd` — workspace setup |
| `requesting-code-review` | absorbed | `$review-loop` / `$challenge` |
| `finishing-a-development-branch` | absorbed | `$ship-pr` + `$merge-cleanup` |
| `test-driven-development` | reference | `references/trial-by-fire.md` |
| `verification-before-completion` | reference | `references/true-seeing.md` |
| `receiving-code-review` | reference | `references/heed-counsel.md` |
| `systematic-debugging` | skill, rewritten | invoked directly; nothing wraps it |

No skill exists merely so another skill can call it. Every "dispatched workflow mode" section disappears with the caller/callee split that created it.

**Net effect:** 36 skills → 26 skills plus 3 references; 1,411 lines of visual companion deleted; ADR 0005, the attribution inventory, the MIT notice, and the re-vendor process retired.

**Consequence for the global CLAUDE.md.** The user's global instructions currently name `brainstorming`, `writing-plans`, `subagent-driven-development`, and `verification-before-completion` as skills to invoke. They become: invoke `$design` before designing and `$build-tdd` before implementation; read the TDD and verification *references*. This is a deliberate weakening — a reference can be skipped where an invoked skill cannot. Accepted. That edit lands in the private `dotfiles` repo, which owns `~/.claude/CLAUDE.md`.

## 2. Independence and the attribution gate

The MIT obligation attaches to surviving upstream *expression*, not to whether anyone read the original. A strict clean-room process is not available and would be theater: the migration work already put `brainstorming`, `writing-plans`, and `subagent-driven-development` in full into an implementing session's context.

The standard is therefore **verified low similarity**, not clean-room:

1. **Write from the process, not the text.** Source material is the user's global CLAUDE.md, the first-party skills (`$design`, `$build-tdd`, `$work-issue`, `$review-loop`), and the behavior inventories of §5. Ideas are not copyrightable; expression is. Re-express.
2. **Verify before removing the notice.** Fetch `obra/superpowers` at `d884ae04` and mechanically compare each rewritten file against its upstream ancestor using shingled n-gram overlap, not inspection. Any passage above a low threshold is rewritten or cited. Only when clean do ADR 0005, `docs/licenses/superpowers.md`, and the MIT notice come out — in the same commit as the check's recorded output.
3. **Fallback.** If verification is awkward for a given file, retaining attribution for that file is an acceptable outcome. Driver 3 never overrides drivers 1 or 2.

Attribution removal is a gated step at the end, not an assumption baked into the rewrite. If the gate fails, the rewrite remains fully valuable.

## 3. Naming

The end-state naming is a D&D-themed set, applied as the final step.

### Surviving skills

| Current | New |
|---|---|
| `campaign` | `campaign` (unchanged) |
| `work-issue` | `quest` |
| `epic` | `saga` |
| `issue` | `bounty` |
| `triage-issues` | `sort-board` |
| `scope` | `divination` |
| `groom` | `warding` |
| `preflight` | `attunement` |
| `design` | `spellcraft` |
| `scope-audit` | `oathbind` |
| `codex-fleet` | `summon-swarm` |
| `build-tdd` | `forge` |
| `systematic-debugging` | `detect-curse` |
| `challenge` | `gauntlet` |
| `threat-scan` | `detect-evil` |
| `review-loop` | `trial-loop` |
| `simplify-changes` | `dispel` |
| `ship-pr` | `deliver` |
| `merge-cleanup` | `return-to-town` |
| `merge-dependabot` | `restock` |
| `clean-branches` | `clear-map` |
| `recover-orphans` | `resurrection` |
| `github-tracking` | `quest-log` |
| `decision-records` | `tome-of-lore` |
| `retro` | `bards-tale` |
| `compound` | `grimoire` |

### References

| Current skill | New reference |
|---|---|
| `test-driven-development` | `references/trial-by-fire.md` |
| `receiving-code-review` | `references/heed-counsel.md` |
| `verification-before-completion` | `references/true-seeing.md` |

**Collision fix:** the original mapping assigned `attune` to `verification-before-completion` and `attunement` to `preflight` — near-identical names firing at similar workflow moments. `attunement` suits preflight (attuning to the repo before work), so verification becomes **`true-seeing`**, the divination that reveals what is actually there — which is precisely "evidence before assertions."

### Absorbed names become internal vocabulary

The seven absorbed skills lose standalone existence but keep their themed names as named phases inside whatever absorbs them:

| Absorbed name | Phase within |
|---|---|
| `council` (brainstorming) | `spellcraft` |
| `inscribe` (writing-plans) | `spellcraft` |
| `cast` (executing-plans) | `forge` |
| `party` (subagent-driven-development) | `forge` |
| `pocket-dimension` (using-git-worktrees) | `forge` |
| `petition-council` (requesting-code-review) | `trial-loop` |
| `long-rest` (finishing-a-development-branch) | `deliver` + `return-to-town` |

`forge` runs a *party* in a *pocket dimension*, or *casts* directly.

**The rename lands last.** Renaming before the collapse would rename seven directories that then get deleted and re-point cross-references twice. It is a single mechanical pass over directories, `name:` frontmatter, and every `$invocation`, gated by a check proving no stale name resolves.

## 4. Skill anatomy

These four rules govern every skill in this repo and belong in the repo's `CLAUDE.md` as binding policy. They are construction rules, not intentions — "be more careful" is what produced the backlog they replace.

1. **A skill is instructions, not a program.** The default artifact is one `SKILL.md`. Supporting files are the exception and must be argued for.

2. **Executable code clears a bar or it does not ship.** A script is permitted only when it does something a model cannot do reliably inline — a deterministic file operation that would otherwise burn context or be performed inconsistently. `sdd-workspace`, `task-brief`, `review-package`, and `detect-host-architecture` clear this bar. A browser mockup server does not.

3. **No long-lived processes.** No servers, no port binding, no PID files, no lockfiles, no daemon lifecycle, no liveness checks against a previous invocation. Every script runs and exits. This rule alone retires the bug class behind `agent-config#77` and `#78`, which exists only because something had to survive between invocations.

4. **Nothing automated asserts on prose.** No gate greps Markdown for a sentence; no test pins a table row. This retires `check-skill-layout.sh` (563 lines plus a 753-line suite), `check-carrier-drift.sh`, and `check-shared-standards.sh`, with no replacement. Prose correctness is a reading problem; regexes that disagree produce false reds under bracketed paths, non-UTF-8 bytes, and personal ripgrep configuration — all observed.

**Structural gates survive.** A gate checking *shape* — every skill directory has a `SKILL.md`, every `$invocation` resolves — is deterministic and catches real breakage, especially during the rename sweep. That is different in kind from asserting a document contains a given sentence.

## 5. Regression guard and testing

The risk in a from-scratch rewrite is silently dropping hard-won lessons that live in unremarkable sentences: "one question at a time," "run it to make sure it fails," "a flake that passes on re-run is not evidence." Rule 4 forbids testing prose, so the guard is a design artifact.

**Behavior inventory, extracted before writing.** For each of the eleven, extract what it makes the agent *do* — observable behaviors, not wording. It serves three purposes at once:

- **Regression guard** — the rewritten skill is read against it.
- **Independence mechanism** — writing from an extracted behavior list rather than source text is how genuinely new expression arises, which §2's similarity gate then confirms.
- **YAGNI filter** — behaviors examined and rejected are deleted deliberately rather than carried forward by inertia. Driver 2 in practice.

**Testing overall:** behavior tests for surviving scripts (deterministic, already exist), a structural shape gate, and human review against the behavior inventory.

**Evals deferred.** `claude plugin eval` runs cases against a plugin and scores them, testing whether invoking a skill actually changes agent behavior — the opposite of prose assertion, and the right long-term instrument. It is deferred because graders are LLM-scored and therefore non-deterministic, and adopting them as a gate means signing up for grader tuning: a new treadmill in the shape of the old one. Tracked as a follow-up issue (below); revisit as an experiment on one or two skills after the rewrite.

## 6. Sequencing

The rewrite follows the in-flight migration rather than replacing it. Finishing the migration is what retires `install.sh`, the original complaint, and takes days where a careful eleven-skill rewrite takes weeks.

1. **Revise and merge the skills-import PR.** Strip the visual companion (`server.cjs`, `start-server.sh`, `stop-server.sh`, `frame-template.html`, `helper.js`, `visual-companion.md`, and their two suites) and the prose-assertion blocks in the preflight and issue suites per rule 4. The result is installable immediately and never contains code already condemned. The attribution obligation does come across, and leaves at step 5.
2. **Finish the migration** — repo gates (minus the prose gates rule 4 retires), Codex manifest, ADR 0001, then `dotfiles` under chezmoi. The CLAUDE.md edit from §1 lands here.
3. **Cut over and archive `agent-config`.** Issues `#77` and `#78` close as obsolete rather than transferring; their subject no longer exists.
4. **The rewrite** — behavior inventories for all eleven, then skill by skill, each its own pull request against a working repo.
5. **Similarity gate, then attribution removal** — one commit, with the check's output recorded.
6. **Rename sweep** — the §3 mapping in a single mechanical pass, gated on no stale name resolving.

### Decomposition

This spec is too large for one implementation plan and is not intended to become one. It decomposes along the step boundaries above:

- **Steps 1–3** are already covered by the existing migration plan (`agent-config` → `adept` + `dotfiles`), amended by step 1's strip list. No new plan needed.
- **Step 4** is its own plan, and likely its own sequence of plans: eleven behavior inventories followed by eleven rewrites is not one reviewable unit. The natural cut is by absorbing destination — `$design` (2 inventories), `$build-tdd` (3), `$review-loop`/`$challenge` (1), `$ship-pr`/`$merge-cleanup` (1), the 3 references, and `systematic-debugging` — six plans, each producing a working skill set.
- **Steps 5 and 6** are each one small plan: a verification gate, and a mechanical rename.

Each unit leaves the repo installable and the skill set usable. No step depends on a later one having landed.

## Follow-up issues to file in this repo

- **`claude plugin eval` experiment** (§5) — try evals on one or two skills; adopt broadly only if stable.
- **Cross-repo drift gap** — the `preflight` skill and the standards documents now live in separate repos with nothing verifying they agree. The old `check-carrier-drift.sh` / `check-shared-standards.sh` covered this within one repo; the split removes that coverage and rule 4 declines to restore it as a prose gate. Needs a decision, not a regex.

## Out of scope

- **`decision-records` (4,311 lines) and `github-tracking` (2,266 lines)** are first-party and untouched by this design. Together they exceed everything being deleted. Noted only as the place to look if maintenance burden persists after this work.
- Unrelated refactoring of the surviving first-party skills.
