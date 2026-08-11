---
name: build-tdd
description: "Implement an approved plan with test-driven development, direct or subagent- driven execution, focused verification, and the repository guardrail suite. Use when asked to build with TDD, execute an implementation plan, or continue the build phase of an issue workflow."
---
# Build With TDD

Implement the design using test-driven development throughout. Set up the
workspace with **pocket dimension**, then pick an execution mode by what
`$design` produced:

- **A plan exists and its tasks are mostly independent** → **party**: a fresh
  implementer subagent per task, each followed by a two-stage review — spec
  compliance, then code quality.
- **No plan, because this is a trivial bugfix or a caller-verified
  `governed-small-change` — or a plan whose tasks are too tightly coupled to
  hand out** → **cast**: implement directly in this session.

**This skill is not the end of the pipeline.** `$review-loop`,
`$simplify-changes`, `$ship-pr` and `$merge-cleanup` follow and own integration,
so neither mode presents an integration menu and neither takes a merge, push, or
discard. That is a property of the run, so the implementer and reviewer
subagents dispatched by **party** inherit it; their prompts say so.

**Never start implementation on `main` or `master` without explicit consent.**
This binds both modes and every subagent either one dispatches.

When the caller supplies a governed-small-change classification with its revalidated decision reference, decision kind, accepted status, governed behavior, and acceptance criteria, reject any supplied or auto-discovered plan and write and run the focused failing test as the first executable proof.

Otherwise, if no plan path is supplied, look for one under `docs/superpowers/plans/`.
No plan is valid only for a trivial bugfix. Any other non-trivial change without a plan
stops and returns to `$design`.

Build-time scope expansion stops implementation, re-freezes scope, and runs full design without automatically reselecting the abbreviated path.

Return a discovered new decision, ambiguity, or scope expansion to the caller's
`SCOPE CHECKPOINT`; do not infer the decision or continue building. The caller records
the new authority, if supplied, in provenance before re-freezing the charter.

**Caller contract.** If invoked inside `$work-issue`, completing the build and
guardrails means proceed to the next step — do not end your turn. Stop only on
a genuine blocker you have named (e.g. a guardrail that cannot be made green).

## Pocket dimension — the isolated workspace

Set this up before either execution mode runs.

**Detect isolation before creating anything.**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
git rev-parse --show-superproject-working-tree 2>/dev/null   # non-empty ⇒ submodule
```

`GIT_DIR != GIT_COMMON` means a linked worktree — **but it is also true inside a
submodule**, so the third command is not optional. A submodule is a normal
checkout for this purpose.

Already isolated: report the path and whether HEAD is detached (detached means a
branch has to be created at finish time), then skip to project setup. Do not
create a second worktree.

Not isolated: if the instructions do not already declare a worktree preference,
ask before creating one — it changes where the user's work lives. Honour a
declared preference without asking. If the user declines, work in place and
continue to project setup.

**Prefer the harness's native worktree tool** — something named like
`EnterWorktree`, a `/worktree` command, a `--worktree` flag. It handles
placement, branch creation, and cleanup, and running `git worktree add` behind
it creates phantom state it cannot see.

**Unless it would nest.** Check where it puts the worktree first. A worktree
inside the working copy is never acceptable — not `.worktrees/`, not
`worktrees/`, not under `.codex/`, not any subdirectory, and not made acceptable
by a `.gitignore` entry, because whole-tree tooling does not all honour one.
Linters, type checkers, test discovery, and search walk a nested worktree and
fail your commit on another agent's in-flight code. If the native tool nests,
refuse it and run `git worktree add` against an external path yourself.

**Choose the directory** by priority: an explicit external path in your
instructions, then an existing `../<repo>-worktrees/` sibling root, then that
path as the default. Placement outranks priority — if your instructions name a
path inside the repo, say so and use an external one anyway.

```bash
REPO_ROOT=$(cd "$(git rev-parse --show-toplevel)" && pwd -P)
LOCATION="$(dirname "$REPO_ROOT")/$(basename "$REPO_ROOT")-worktrees"
path="$LOCATION/$BRANCH_NAME"
mkdir -p "$(dirname "$path")"
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"

# Confirm it really landed outside the repo before working in it.
case "$(pwd -P)/" in
  "$REPO_ROOT"/*) echo "NESTED — relocate outside $REPO_ROOT" ;;
esac
```

`BRANCH_NAME` is whatever your instructions assigned (`$work-issue` names it
explicitly); derive it from the work and report your choice if nothing did. If
the containment check prints, remove the worktree and recreate it externally —
never paper over it with a `.gitignore` entry.

If `git worktree add` fails on a sandbox permission denial, say the sandbox
blocked it, work in the current directory, and run setup and baseline there.

**Then set up and verify a clean baseline.** Install dependencies for whatever
manifests are present — `package.json`, `Cargo.toml`, `requirements.txt`,
`pyproject.toml`, `go.mod` — and run the project's test command. A baseline you
did not check is a baseline that gets blamed on your change.

On a failing baseline the response depends on who is reachable:

- **Interactive:** report the failures, ask whether to proceed or investigate, wait.
- **Dispatched, with an instruction or repo rule that explicitly addresses the
  failed baseline:** report, then follow it.
- **Dispatched, without one:** report the failures as a blocker and return.

Generic dispatch, autonomy, or task-completion language is not authority to
proceed past a red baseline. Do not infer permission and do not start
implementing.

Report when ready: the path, the passing test count, and what is about to be
built.

## Cast — direct execution

Chosen when there is no plan because the change is a trivial bugfix or a
caller-verified `governed-small-change`, or when a plan exists but its tasks are
too tightly coupled to hand out separately.

Read the plan and review it critically **before** starting — questions and
concerns raised now cost one answer; discovered mid-task they cost one per task.
Raise them rather than noting them. If the plan changes in response, review the
amended plan rather than executing against your reading of the old one.

Create a todo per plan task. Conversation memory does not survive compaction,
and the todo list is what survives it.

Then, per task: mark it in progress, follow its steps exactly, run the
verifications the plan specifies — not a substitute for them — and mark it
complete only once those pass. The plan phase spent its effort making the steps
bite-sized; improvising past them discards that work, and a task marked complete
before its verification ran is the false green everything else here exists to
prevent.

Stop on a genuine blocker — a missing dependency, a test that will not pass, an
instruction you do not understand, a verification that fails repeatedly — and
say so. Guessing past a blocker produces work that looks finished and is not.

## Party — subagent-driven execution

A fresh implementer subagent per task, a two-stage task review after each, and
one broad whole-branch review at the end. The isolated context is the mechanism:
a subagent that inherits your session's history loses focus, so construct
exactly what each one needs instead of letting it inherit. It also keeps your
own context for coordination.

Honor repo-level subagent and worktree rules. If repo instructions require
mutating subagents to work in separate worktrees, obey that. Otherwise,
sequential subagent dispatch on the same feature branch is allowed. **Never
dispatch mutating subagents in parallel in the same working tree** — they
conflict.

Execute all tasks without pausing to check in. The only reasons to stop are a
`BLOCKED` you cannot resolve, ambiguity that genuinely prevents progress, or
completion; "should I continue?" asks the human to re-decide something they
already decided. Between tool calls narrate at most one short line — the ledger
and the tool results are the record.

### Before the first dispatch

Read the plan, note its Global Constraints, and create a todo per task.

Then scan the plan once for conflicts: tasks that contradict each other or the
Global Constraints, and anything the plan *mandates* that the review rubric
treats as a defect — a test that asserts nothing, a verbatim-duplicated logic
block. Without this scan such a plan burns one fix cycle per task instead of one
question up front. Batch everything you find into a single question, each
finding beside the plan text that mandates it, asking which governs. If the scan
is clean, proceed without comment.

Where nobody can be asked, the Global Constraints and the repo's conventions
govern, and the deviation goes in your report. Escalate before Task 1 only where
either choice could be wrong.

### The per-task loop

1. Generate the task brief: `scripts/task-brief PLAN_FILE N` writes it to a
   uniquely named file and prints the path.
2. Dispatch an implementer with [implementer-prompt.md](implementer-prompt.md).
3. If it asks questions, answer them fully before it proceeds. A question asked
   before the work is the cheapest one there is; hurrying it produces a defect
   instead of an answer.
4. It implements, tests, self-reviews, and commits.
5. Generate the review package: `scripts/review-package BASE HEAD`, using the
   BASE you recorded **before** dispatching — never `HEAD~1`, which silently
   drops all but the last commit of a multi-commit task.
6. Dispatch the task reviewer with
   [task-reviewer-prompt.md](task-reviewer-prompt.md) and that path.
7. On Critical or Important findings, dispatch a fix subagent, then re-review.
   Do not move on with either still open.
8. Mark the task complete in the todo list and the progress ledger.

After the last task, dispatch the whole-branch review with
[code-reviewer.md](code-reviewer.md), on the most capable model. The per-task
reviews are task-scoped by design and cannot see a defect that spans tasks.

### Handling what an implementer reports

Four statuses, four responses:

- **DONE** — generate the review package and dispatch the task reviewer.
- **DONE_WITH_CONCERNS** — read the concerns first. Correctness or scope
  concerns get addressed before review; observations get noted.
- **NEEDS_CONTEXT** — supply what was missing and re-dispatch.
- **BLOCKED** — assess it. A context problem gets more context; a reasoning
  problem gets a more capable model; an oversized task gets split; a wrong plan
  gets escalated.

**Never retry an unchanged prompt after `BLOCKED`, and never ignore an
escalation.** If the implementer says it is stuck, something has to change.

A task reviewer may also report "⚠️ Cannot verify from diff" — requirements
living in unchanged code or spanning tasks. These do not block the rest of the
review, but resolve each one yourself before marking the task complete: you hold
the plan and cross-task context the reviewer does not. A confirmed gap is a
failed spec review.

### Choosing a model

Use the least powerful model that can do the job, and **always name it
explicitly** — an omitted model inherits your session's, usually the most
capable and most expensive.

- Mechanical task, complete spec, one or two files, no design latitude → cheap.
- Multi-file integration or pattern matching → standard.
- Design judgment, broad codebase understanding, or the final whole-branch
  review → most capable.

**Turn count beats token price.** The cheapest models routinely take 2–3× the
turns on multi-step work and cost more overall. Use a mid-tier floor for
reviewers and for implementers working from prose; reserve the cheapest tier for
transcription — where the plan text already contains the code to write — and for
single-file mechanical fixes.

### What goes in a dispatch

**Subagents inherit nothing.** Each implementer prompt must include:

- the task brief path, introduced as its requirements, with the exact values to
  use verbatim
- where this task fits in the wider change
- the issue requirement and acceptance criteria
- interfaces and decisions from earlier tasks that the brief cannot know
- your resolution of any ambiguity you noticed in the brief
- applicable `AGENTS.md` conventions
- exact guardrail commands to run before committing
- the TDD requirements below
- the report-file path, named after the brief (`…/task-N-brief.md` →
  `…/task-N-report.md`)
- the **subagent report contract** (`AGENTS.md`), last, so the implementer
  returns a condensed report — references, not content — rather than its whole
  transcript

Exact values — numbers, magic strings, signatures, test cases — live in the
brief and nowhere else. A dispatch describes one task, never the session's
history: do not paste accumulated prior-task summaries. One real session's
dispatch reached 42k characters of which 99% was pasted history.

Hand artifacts over as **files**, not pasted text. Anything you paste into a
prompt, and anything a subagent prints back, stays resident in your context and
is re-read on every later turn. The reviewer gets three paths — the brief, the
report, and the review package — plus the constraints that bind the task. Fix
dispatches append to the same report file.

**Constructing a reviewer prompt**, the rules that matter most:

- **Never pre-judge a finding.** If what you are writing contains "do not flag",
  "don't treat X as a defect", "at most Minor", or "the plan chose" — stop. You
  are pre-judging, usually to spare yourself a review loop. Let the reviewer
  raise it and adjudicate it afterwards.
- Copy the plan's binding requirements **verbatim** into the global-constraints
  block: exact values, formats, and stated relationships ("same layout as X").
  That block is the reviewer's attention lens, and a paraphrase changes what it
  looks at. The template already carries the process rules.
- No open-ended directives ("check all uses", "run race tests if useful")
  without a concrete task-specific reason.
- Do not ask a reviewer to re-run tests the implementer already ran on the same
  code — the implementer's report carries that evidence.

Every reviewer dispatch ends with the same report contract, so you get a bounded
verdict rather than the whole review.

Every fix dispatch carries the implementer contract: re-run the tests covering
the change and report the command and its output. Name the covering test files —
a one-line fix does not need the whole suite. Confirm the report has all three
before re-dispatching the reviewer. If the **final** review returns findings,
send **one** fix subagent with the complete list; per-finding fixers each rebuild
context and re-run suites, and one real session's final-review wave cost more
than all its tasks combined.

Record Minor findings in the ledger as you go and point the final review at that
list, so it can triage what must be fixed before merge — a roll-up nobody reads
is a silent discard. A finding that conflicts with what the plan mandates is the
human's decision: present the finding and the plan text and ask which governs.
Do not dismiss it because the plan mandates it, and do not dispatch a fix that
contradicts the plan without asking.

### Durable progress

Conversation memory does not survive compaction. Controllers that lost their
place have re-dispatched entire completed task sequences — the most expensive
failure observed in practice. Track progress in a ledger, not only in todos.

Resolve the workspace with `scripts/sdd-workspace`, which prints its absolute
path, and check for `<workspace>/progress.md`. Tasks marked complete there are
done: resume at the first that is not, and never re-dispatch one the ledger has
already closed.

**Only that script creates the workspace**, and that matters: it writes a
self-ignoring `.gitignore` (`*`) into `.agent/`, which is the whole mechanism
keeping the ledger, briefs, reports, and review packages out of `git status` and
out of a PR diff. Writing `progress.md` at a hardcoded path with an editor tool
skips it, and in a repo that tracks everything the next `git add -A` sweeps the
ledger into someone's commit. Run the script — or `task-brief` / `review-package`,
which call it — before the first write, then confirm:

```bash
git check-ignore -q "$(git rev-parse --show-toplevel)/.agent/sdd/progress.md"
```

A failure there means that write was refused or reverted, not that a further
ignore step is owed. Do not reach for `.git/info/exclude`: a sandboxed agent may
be denied writes to `.git/` entirely.

When a review comes back clean, append one line:
`Task N: complete (commits <base7>..<head7>, review clean)`. After any
compaction, trust the ledger and `git log` over your own recollection — the
commits it names exist in git even when you no longer remember creating them.

### Never

- Skip a task review, or accept a report missing either verdict — spec
  compliance and code quality are both required.
- Accept "close enough" on spec compliance, or let an implementer's self-review
  stand in for the task review.
- Make a subagent read the whole plan file instead of its brief.
- Dispatch a task reviewer without a review-package file.

**Severity mapping.** The task and final reviewers above grade `Critical / Important / Minor`; the
workflow pipeline's canonical scale is `$challenge`'s `critical | high | medium | low`.
When a task-review finding is carried outward — into `$review-loop` or the `WORK:REVIEW`
summary `$work-issue` posts — convert it with the table in `$challenge`, *Severity
vocabulary*, which owns both the enum and the conversion. Keep this vocabulary *inside*
this skill: the party mode's gates key on those words ("dispatch a fix subagent on
Critical or Important findings"), so rewriting them at the dispatch site breaks the gate.

## TDD rules

Whoever writes code — subagent or this session — works to the standard in
[trial-by-fire](../../references/trial-by-fire.md):

1. Write the failing test first.
2. Run it and confirm it fails for the expected reason.
3. Write the minimal implementation.
4. Run the focused test and relevant guardrails.
5. Refactor only while staying green.

Test behavior and edge/error paths, not implementation details: empty input,
null or missing values, malformed input, boundaries, timeouts, partial
failure, permission failures, and degraded dependencies where relevant.

### Language-agnostic implementation rules

- **Do not weaken test gating.** Integration/e2e tests gated behind an env
  flag, feature, or external tool stay gated. Do not un-gate them to make a
  run pass, and do not widen what an existing gate admits.
- **Test at the boundary the project prescribes.** Drive the unit directly
  with injected dependencies unless repo convention says to test through
  transport, IPC, CLI, or another boundary.
- **Return the project's structured result/error type** with the most specific
  error category. Populate next-action or affordance fields with literal valid
  identifiers, not prose.
- **Redact secrets and untrusted or external output** before returning it and
  before persisting or snapshotting it.
- **Regenerate committed snapshots you invalidate.** If you change a type,
  model, schema, OpenAPI output, approval file, or `insta` snapshot,
  regenerate and review it in the same change.

## Guardrails

Run the project's local check suite discovered in `$preflight`. At minimum,
for the languages involved, it must cover:

- format check
- lint
- type check, when the language has one
- tests

Zero warnings. Fix every warning or add a narrow inline ignore with a
justification. Whatever is hard-gating in CI must be green locally before
every commit unless it requires hardware, credentials, or external services
unavailable locally; in that case, run the closest local equivalent and state
the limitation in the PR body.

If a guardrail fails, stop and fix it. Do not commit with red guardrails.

## Context checkpoint

The **durable artifacts** of this phase are the committed code and tests and the
plan's completed tasks — not the TDD red/green output or implementer transcripts.
Before handing off to review, confirm the branch name and the exact guardrail
commands are recorded somewhere durable (the plan, the campaign manifest, or a
note), so a post-compaction resume can recover them. Do **not** run `context compaction`
proactively; just keep the artifacts complete.
