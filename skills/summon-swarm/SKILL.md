---
name: summon-swarm
description: "Offload high-volume, well-specified generation to parallel OpenAI Codex CLI workers. Use when a job splits into independent worker-sized tasks (content batches, test generation, bulk refactors) and Codex CLI is installed and logged in — The current Codex session decomposes, briefs, spawns worker `codex exec` runs in parallel, and review-gates every output. Not for judgment-dense work this session should do itself, or for coordinating workers on one complex change."
---

# Codex Fleet

The current session is the orchestrator: it decomposes, briefs, and reviews.
Parallel OpenAI Codex CLI workers are the fleet. The orchestrator handles
judgment; worker processes handle volume. A clear spec plus high volume can go
to workers; a fuzzy spec or expensive-if-wrong work stays in this session.
Nothing ships unreviewed.

Reserve `subagent` for a literal harness/API capability, never a workflow role.

Adapted from `suede-codex-fleet` in
[JasonColapietro/suede-creator-skills](https://github.com/JasonColapietro/suede-creator-skills) (MIT).

## Preflight (before the first spawn)

1. `which codex && codex --version` — CLI present.
2. `codex login status` — must show logged in.
3. The workspace root has an `AGENTS.md`. Codex auto-loads it; it carries
   conventions, context, hard bans, and output format so briefs stay short.
   If missing, write it first — it is the highest-leverage file in the system.
4. The workspace has `briefs/` and `out/` directories (create as needed). When the
   workspace root sits inside a git repo you raise PRs from, keep worker output out of
   `git status` and out of a PR diff **before the first spawn** — it is high-volume and
   otherwise lands in whatever commit runs next. Ignore `out/` always. Ignore `briefs/`
   too *unless* this is a persistent fleet workspace whose reviewed briefs you keep as
   templates (see *Fleet workspaces*) — that is the one case they belong in git. Write
   a self-ignoring `.gitignore` into the directory (`printf '*\n' > out/.gitignore`).
   `out/` is a caller-named worker deliverable directory rather than scratch state, so
   it keeps its own per-directory ignore file and does not move under `.agent/`. Do not
   use `.git/info/exclude` — a sandboxed agent may be denied writes to `.git/`
   entirely, so it is not a fallback. Verify with
   `git check-ignore -q out/.` — note the trailing `/.`: a bare
   `git check-ignore -q out` reports *not ignored* even when every file inside is,
   because `*` in a child `.gitignore` matches the directory's contents and not the
   directory itself.

## The loop

1. **Decompose.** Split the job into independent worker-sized tasks.
   Independent means no worker needs another worker's output.
2. **Brief.** One markdown file per task in `briefs/`. Worker processes never see the
   orchestrator conversation, so each brief is self-contained: job, inputs (file
   paths), exact deliverable, acceptance criteria the worker must self-check,
   and the exact output path in `out/`.
3. **Spawn.** One `codex exec` per brief, in parallel, in the background:

   ```bash
   codex exec -C <workspace> --sandbox workspace-write --skip-git-repo-check \
     -o <workspace>/out/<run-name>-final-message.txt \
     "Read AGENTS.md at the workspace root, then execute the brief at briefs/<brief>.md exactly. Write the deliverable to the output file the brief names, run the brief's acceptance-criteria self-check, and state pass/fail per criterion in your final message."
   ```

   - `-C` sets the worker's root; `--skip-git-repo-check` is required outside
     git repos.
   - `--sandbox workspace-write` only — never `danger-full-access`. Workers
     write files; they do not push, deploy, or touch secrets.
   - Leave the model default unless the user asks to override with `-m`.
4. **Review gate (orchestrator, mandatory).** Read every `out/` file against the
   brief's acceptance criteria and the `AGENTS.md` hard bans. Worker
   self-checks are evidence, not verdicts. If output passes all criteria but
   has surface defects (typos, a wrong label), edit the file directly — do not
   respawn for a comma.
5. **Delta, don't regenerate.** If output fails 1–2 criteria, send a one-line
   correction: `codex exec resume <session-id> "<delta>"` (the session id is
   printed at run start; `resume --last` is ambiguous with parallel runs). If
   it fails 3+ criteria or violates an `AGENTS.md` hard ban, respawn with the
   delta appended to the brief. Regenerating from scratch wastes the
   subscription and loses what was right.
6. **Ship.** Assemble the reviewed survivors into the final deliverable.
   Report what was spawned, what passed, what got fixed.

## Brief template

```markdown
# Brief <id> — <task name>

Read `AGENTS.md` in the workspace root first. This brief only adds the task.

## Job
<one paragraph: what and why>

## Inputs
<file paths the worker must read>

## Deliverable
<exact structure, counts, variants, labels>

## Acceptance criteria (self-check before finishing)
<numbered, mechanically checkable: limits, bans, required elements>

## Output
Write to `out/<file>.md`. <structure spec>
```

## Fleet workspaces

Keep a persistent workspace per recurring fleet job (a test-generation fleet,
a refactor fleet) instead of rebuilding context every run. The workspace root
holds the `AGENTS.md` contract, `briefs/`, and `out/`. A brief whose output
passed review cleanly is the template for the next run of the same shape.

When workers edit files inside a git repo, the worktree rules from the global
standards apply: each worker's workspace must be its own external worktree,
never a shared working directory.

## Hard boundaries

- Never ship worker output without the orchestrator review gate.
- Workers never run `git push`, deploys, or credentialed commands.
- Secrets never go into briefs or `AGENTS.md`; workers get file paths, not
  tokens.
- If output violates a hard ban, the fix is the orchestrator's edit or a delta run —
  never "close enough".

## Troubleshooting

- `codex exec` refuses to start outside a repo → add `--skip-git-repo-check`.
- Not logged in / usage errors → `codex login status`, then run `codex login`
  interactively.
- Worker wrote nothing to `out/` → read the `-o` final-message file and the
  task output log; usually a sandbox denial or a brief pointing at a wrong
  path.
- Parallel runs are independent processes; spawn each with its own background
  shell call and collect on completion.
