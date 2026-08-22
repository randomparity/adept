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
3. The workspace root carries an instruction file the Codex CLI auto-loads
   (`AGENTS.md` by default); it holds conventions, context, hard bans, and output
   format so briefs stay short. If an instruction file already exists, treat it as
   the contract: never overwrite it and never create a second one beside it. Some
   repos deliberately keep a single instruction file and forbid duplicates —
   writing `AGENTS.md` there would violate the very policy you are working under.
   Write an `AGENTS.md` only when none exists and nothing in the repo's own
   instructions objects; where the policy forbids one, carry conventions, hard
   bans, and output format in each brief instead.
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
3. **Spawn.** Cap the fleet at 5 workers running in parallel — the same bound
   `$campaign` and `$restock` use. More than 5 tasks run in waves of 5: launch the
   next wave only after every worker in the current wave has ended (approved,
   fixed, or surfaced as blocked), and send all of a wave's spawns together before
   collecting. One `codex exec` per brief, in parallel, in the background:

   ```bash
   codex exec -C <workspace> --sandbox workspace-write --skip-git-repo-check \
     -o <workspace>/out/<run-name>-final-message.txt \
    "If the workspace root has an instruction file, read it first, then execute the brief at briefs/<brief>.md exactly. Write the deliverable to the output file the brief names, run the brief's acceptance-criteria self-check, and state pass/fail per criterion in your final message."
   ```

   - `-C` sets the worker's root; `--skip-git-repo-check` is required outside
     git repos.
   - `--sandbox workspace-write` only — never `danger-full-access`. Workers
     write files; they do not push, deploy, or touch secrets.
   - Leave the model default unless the user asks to override with `-m`.
   - Before waiting on any worker, persist its spawn to a fleet manifest at
     `<workspace>/out/sessions.tsv` — one row per worker: run name, session id
     (printed at run start), brief path, `-o` output path, status (`running`).
     Update the row when the worker ends (`done`, `failed`, `blocked`). When the
     single respawn launches, overwrite that row's session id and reset the status
     to `running`, so resume-after-death sees at most one live attempt per brief.
     Terminal scrollback dies with the orchestrator; this manifest is what lets a
     fresh session resume a dead run.
4. **Review gate (orchestrator, mandatory).** Read every `out/` file against the
   brief's acceptance criteria and the workspace instruction file's hard bans.
   Worker self-checks are evidence, not verdicts. Output that meets every criterion
   is approved; anything else is needs-attention and routes through step 5. If
   output passes all criteria but has surface defects (typos, a wrong label), edit
   the file directly — do not respawn for a comma.
5. **Delta, don't regenerate — inside a bounded loop.** If output fails 1–2
   criteria, send a one-line correction: `codex exec resume <session-id> "<delta>"`
   (the session id is printed at run start; `resume --last` is ambiguous with
   parallel runs). If it fails 3+ criteria or violates a hard ban, respawn with the
   delta appended to the brief. Regenerating from scratch wastes the subscription
   and loses what was right. Bound the loop per worker: set an explicit fix-round
   budget of 2–5 rounds before the first spawn (omission means 5, matching
   `$trial-loop`'s `iteration_budget`; lower it only with evidence the tasks are
   small). One round is one delta or one respawn. A worker that exhausts its budget
   without meeting every criterion stops as blocked: record `blocked` in the fleet
   manifest and surface the unmet criteria to the caller instead of respawning
   again. `blocked` stays reserved for cannot-proceed; an exhausted budget is
   exactly that.
6. **Ship.** Assemble the reviewed survivors into the final deliverable.
   Report what was spawned, what passed, what got fixed.

## Worker failure and resume

A silent, crashed, or hung worker is a handled path, not a mystery:

1. **Bound the wait up front.** Give each spawn a stated timeout before launching
   it. A worker that exits non-zero, writes no deliverable to `out/`, or is still
   running past its timeout counts as failed — never wait on it indefinitely.
2. **Read the evidence before respawning.** Open that worker's `-o` final-message
   file and its task log. The usual causes are a sandbox denial, an auth lapse, or
   a brief pointing at a wrong path — each has a different fix, and respawning
   without reading repeats the failure.
3. **Respawn once.** End what you can observe first: collect a non-zero exit, or
   terminate a timed-out process and confirm it exited — a timeout is not an
   observed end, and two live workers on one workspace corrupt both runs. Then,
   after fixing the cause, rerun the same brief one time.
4. **Surface, don't loop.** A second silence ends that worker's chances: mark its
   manifest row `blocked`, drop its output from the deliverable, and name it in
   the ship report so the caller decides whether to re-brief, split the task, or
   absorb it into the orchestrator session.

For probe budgets and zero-turn waiting mechanics, follow dispatch liveness and
silent-worker recovery in
[references/dispatch-liveness.md](../../references/dispatch-liveness.md).

**Resuming after an orchestrator dies.** Read the fleet manifest instead of
terminal scrollback. Rows marked `done` need no respawn — review their `out/`
files through the normal gate. Rows still `running` may belong to dead processes:
check each one's `-o` file and task log, then take survivors through the failure
path above. Because session ids were persisted at spawn, a live-but-unreported
worker can be continued with `codex exec resume <session-id>` instead of restarted.

## Brief template

```markdown
# Brief <id> — <task name>

Read the workspace instruction file first if preflight found one. This
brief only adds the task (and carries conventions itself when none exists).

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
holds the instruction-file contract, `briefs/`, `out/`, and the fleet manifest.
A brief whose output passed review cleanly is the template for the next run of
the same shape.

When workers edit files inside a git repo, the worktree rules from the global
standards apply: each worker's workspace must be its own external worktree,
never a shared working directory.

## Hard boundaries

- Never ship worker output without the orchestrator review gate.
- Workers never run `git push`, deploys, or credentialed commands.
- Secrets never go into briefs or the workspace instruction file; workers get
  file paths, not tokens.
- If output violates a hard ban, the fix is the orchestrator's edit or a delta run —
  never "close enough".

## Troubleshooting

- `codex exec` refuses to start outside a repo → add `--skip-git-repo-check`.
- Not logged in / usage errors → `codex login status`, then run `codex login`
  interactively.
- Worker wrote nothing to `out/` → follow *Worker failure and resume*: read the
  `-o` final-message file and the task log, fix the cause, respawn once — or
  surface as blocked. Usually a sandbox denial or a brief pointing at a wrong
  path.
- Parallel runs are independent processes; spawn each with its own background
  shell call and collect on completion.
