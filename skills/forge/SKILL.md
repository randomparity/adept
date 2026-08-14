---
name: forge
description: "Implement an approved plan with test-driven development, direct or worker-driven execution, focused verification, and the repository guardrail suite. Use when asked to build with TDD, execute an implementation plan, or continue the build phase of an issue workflow."
---
# Build With TDD

Implement the design using test-driven development throughout. Set up the
workspace with **pocket dimension**, then pick an execution mode by what
`$spellcraft` produced:

- **A plan exists and its tasks are mostly independent** → **party**: a fresh
  implementer worker per task, each followed by a two-stage review — spec
  compliance, then code quality.
- **No plan, because this is a trivial bugfix or a caller-verified
  `governed-small-change` — or a plan whose tasks are too tightly coupled to
  hand out** → **cast**: implement directly in this session.

**This skill is not the end of the pipeline.** `$trial-loop`,
`$dispel`, `$deliver` and `$return-to-town` follow and own integration,
so neither mode presents an integration menu and neither takes a merge, push, or
discard. That is a property of the run, so the implementer and reviewer
workers dispatched by **party** inherit it; their prompts say so.

**Never start implementation on `main` or `master` without explicit consent.**
This binds both modes and every worker either one dispatches.

When the caller supplies a governed-small-change classification with its revalidated decision reference, decision kind, accepted status, governed behavior, and acceptance criteria, reject any supplied or auto-discovered plan and write and run the focused failing test as the first executable proof.

Otherwise, if no plan path is supplied, look for one under `docs/workflow/plans/`.
No plan is valid only for a trivial bugfix. Any other non-trivial change without a plan
stops and returns to `$spellcraft`.

Build-time scope expansion stops implementation, re-freezes scope, and runs full design without automatically reselecting the abbreviated path.

Return a discovered new decision, ambiguity, or scope expansion to the caller's
`SCOPE CHECKPOINT`; do not infer the decision or continue building. The caller records
the new authority, if supplied, in provenance before re-freezing the charter.

**Caller contract.** If invoked inside `$quest`, completing the build and
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

`BRANCH_NAME` is whatever your instructions assigned (`$quest` names it
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

## Party — worker-driven execution

A fresh implementer worker per task, a two-stage task review after each, and
one broad whole-branch review at the end. The isolated context is the mechanism:
a worker that inherits your session's history loses focus, so construct
exactly what each one needs instead of letting it inherit. It also keeps your
own context for coordination.

Honor repo-level worker and worktree rules. If repo instructions require
mutating workers to use separate worktrees, obey that. Otherwise,
sequential worker dispatch on the same feature branch is allowed. **Never
dispatch mutating workers in parallel in the same working tree** — they
conflict.

Execute all tasks without pausing to check in. The only reasons to stop are a
`CANNOT_COMPLETE` you cannot resolve, ambiguity that genuinely prevents progress, or
completion; "should I continue?" asks the human to re-decide something they
already decided. Keep commentary between tool calls to a single line at most:
what is durable is the ledger and the tool output, not the running account.

### Before the first dispatch

Read the plan, note its Global Constraints, and create a todo per task.

Then read it through once looking for contradictions — between two tasks, or
between a task and the Global Constraints — and for anything the plan *requires*
that a reviewer would write up as a defect: an assertion-free test, a logic block
duplicated word for word. Left undetected, that costs a fix cycle on every task
it touches, where catching it costs one question. Collect them and ask once,
quoting the plan text beside each and asking which of the two holds. If the scan
is clean, proceed without comment.

Where nobody can be asked, the Global Constraints and the repo's conventions
govern, and the deviation goes in your report. Escalate before Task 1 only where
either choice could be wrong.

### Silent party workers

The implementer, task reviewer, fix worker, and whole-branch reviewer are separate report waits.
Apply [dispatch liveness and silent-worker recovery](../../references/dispatch-liveness.md) to
each. Before any replacement, append the worker, wait site, observations, recovery-chain
identifier, `unused` or `consumed` replacement budget, and artifact dispositions to
`progress.md`. The task brief, implementer report, review package, review file, branch commits, and
worktree state are reconciliation evidence. Do not replace or reclaim a worker on silence alone.

### The per-task loop

1. Generate the task brief: `scripts/task-brief PLAN_FILE N` writes it to a
   uniquely named file and prints the path.
2. Dispatch an implementer with [implementer-prompt.md](implementer-prompt.md).
3. If it asks questions, answer them fully before it proceeds. A question asked
   before the work is the cheapest one there is; hurrying it produces a defect
   instead of an answer.
4. It implements, tests, self-reviews, and commits.
5. Generate the review package: `scripts/review-package BASE HEAD`, using the
   BASE you noted **before** the dispatch. `HEAD~1` is wrong and fails quietly:
   where a task produced several commits it shows the reviewer only the final
   one, and the diff still looks plausible.
6. Dispatch the task reviewer with
   [task-reviewer-prompt.md](task-reviewer-prompt.md) and that path.
   A `CLEANUP_FAILED` return must match the exact three-line reviewer contract;
   reject any mixed verdict/count return and stop with the residual worktree.
7. On critical, high, or medium findings, dispatch a fix worker, then re-review.
   Do not move on with any still open. Record low findings in the ledger; they
   may be dispositioned and advanced, but the review remains `needs-attention`.
8. Mark the task complete in the todo list and the progress ledger.

After the last task, dispatch the whole-branch review with
[code-reviewer.md](code-reviewer.md), on the most capable model. The per-task
reviews are task-scoped by design and cannot see a defect that spans tasks.

Its base is the branch's fork point — `git merge-base HEAD <BASE_BRANCH>`,
recomputed here rather than carried forward, because a rebase moves it. Not the
commit the build phase started from: a spec and plan committed before Task 1
belong to the branch this review judges. `BASE_BRANCH` is the value
`$attunement` recorded; if you do not have it, ask, and where nobody can be
asked report it as a blocker and return. Never default to `main`.

1. **Read the ledger first.** No `Final review` line for this range: dispatch.
   A verdict line and no `closed` line: the review ran and its file is on disk,
   so resume at the fix wave — do not regenerate, do not clear, do not
   re-dispatch. Verdict and `closed` lines without either `retained for PR
   publication` or `review-publication-disposed`: resume at step 6's retention
   marking. A retained line exposes the exact review and ledger paths to the
   caller and completes forge; a later publication-disposed line confirms that
   `$quest` closed the scratch lifecycle. Do not infer completion from a
   missing review file or from the historical review line alone.
2. `scripts/review-package <fork-point> HEAD` for `[DIFF_FILE]`. It must exit 0
   and print a non-zero commit count and a non-zero byte count. Report and stop
   rather than dispatching: this file is the reviewer's whole input.
3. `[REVIEW_FILE]` is `<workspace>/final-review-<base7>..<head7>.md`, in the
   directory `scripts/sdd-workspace` prints. Remove anything already at that
   path before dispatching, so a file there afterwards is this dispatch's.
   `[LOW_LEDGER]` is the low findings you have been accumulating; pass the
   literal `none` when there were none.
4. When the reviewer returns, `[REVIEW_FILE]` must exist and be non-empty. If
   you passed a non-empty `[LOW_LEDGER]`, read that file's `#### Low triage`
   heading whatever the verdict — that heading, not the whole file. On `approve`
   nothing else reads the answer you asked for.
5. **Append the ledger line once that check passes**, before the fix wave —
   `Final review <base7>..<head7>: <verdict> (review <path>)` — and a second,
   `Final review <base7>..<head7>: closed`, when the wave finishes. Two appends,
   not an edit, as everywhere else in that ledger. Before the wave and not
   after, because a run that dies mid-wave leaving no line sends the next one
   through step 1 to clear a finished review. A dispatch ending in a stop gets
   no line.
6. Once the range has its `closed` ledger line and every in-run consumer has
   finished, retain the review for `$quest` rather than disposing it. Append
   `Final review <base7>..<head7>: retained for PR publication (review <path>,
   ledger <path>)`, using the exact regular, non-empty review path and the
   exact forge-ledger path. Read that line back before reporting success. The
   retained review stays in ignored scratch storage until `$quest`'s
   `publish-forge-review` helper verifies the PR comment and recoverably
   disposes it. Never move it to trash in forge, and never append retention for
   an unconsumed artifact or one still needed by a live worker.

**Forge-to-quest result.** A closed retained whole-branch review returns
`required` with its exact review path and ledger path. A selected execution
mode that did not require a whole-branch review returns `not-required` with a
verified, public-safe reason and its ledger path; it does not invent a review
path. A failed, missing, malformed, or unresolved required review is terminal:
return `required-failed` with the ledger path and actionable local reason, and
do not return a retained artifact. `$quest` must park before delivery on that
result. These modes are workflow state, not interchangeable verdict labels.

A missing or empty file means the return is not evidence. If the reviewer produced no report,
apply the silent-party-worker contract above; only a reconciled, harness-observed end may consume
the chain's one replacement. If a report arrived but the file is missing or empty, keep the
existing malformed-return behavior: discard it, re-dispatch once, then stop and report. A reviewer
that returned `WRITE_FAILED` or `PACKAGE_MISSING` has named
the problem — stop on the first one. Do not retry at a second path; the
template's read-only rule rests on the reviewer having exactly one writable
path. Every such terminal stop, including an exhausted malformed return or
silent-worker recovery, is `required-failed`: append and read back
`Final review <base7>..<head7>: required-failed (reason <reason>, ledger
<path>)`, return that mode with the ledger path and local reason, and stop.
Do not let the branch continue to `$trial-loop`, `$dispel`, `$deliver`, or any
other shipping phase with no whole-branch review. `$quest` parks this result
before delivery rather than reclassifying it as `not-required`.

A `CLEANUP_FAILED` return is also a stop. Accept only the exact three-line shape
defined by the reviewer template, with an absolute worktree path and one-line
reason. Reject a return that mixes `CLEANUP_FAILED` with a verdict or counts;
the review cannot be consumed while reviewer-created state remains unresolved.
Return `required-failed` by the same ledgered terminal path; it cannot resume
as a shipping-without-review path.

### Handling what an implementer reports

Four statuses, four responses:

- **DONE** — generate the review package and dispatch the task reviewer.
- **DONE_WITH_CONCERNS** — read the concerns first. Correctness or scope
  concerns get addressed before review; observations get noted.
- **NEEDS_CONTEXT** — supply what was missing and re-dispatch.
- **CANNOT_COMPLETE** — assess it. A context problem gets more context; a reasoning
  problem gets a more capable model; an oversized task gets split; a wrong plan
  gets escalated.

**Never retry an unchanged prompt after `CANNOT_COMPLETE`, and never ignore an
escalation.** If the implementer says it is stuck, something has to change.

**A reported flake is dispositioned here, before the review package is
generated** — fix the determinism, or file it and record the reference. Filing
is yours to do, not the implementer's, and doing it now is what stops the task
reviewer raising a finding nothing downstream can close.

A task reviewer may also report "⚠️ Cannot verify from diff" — requirements
living in unchanged code or spanning tasks. The rest of the review proceeds
around them, but none may be left open when you close the task. Settle each one: the
plan and everything the neighbouring tasks established are yours to see and the
reviewer's to guess at. If it turns out to be a genuine gap, the spec review
failed.

### Choosing a model

Use the least powerful model that can do the job, and **always name it
explicitly** — an omitted model inherits your session's, usually the most
capable and most expensive.

- Mechanical task, complete spec, one or two files, no design latitude → cheap.
- Multi-file integration or pattern matching → standard.
- Design judgment, broad codebase understanding, or the final whole-branch
  review → most capable.

**Turn count beats token price.** Give a weak model something multi-step and it
will often need two or three times as many turns to finish, which is more
expensive than the stronger model would have been. Use a mid-tier floor for
reviewers and for implementers working from prose; reserve the cheapest tier for
transcription — where the plan text already contains the code to write — and for
single-file mechanical fixes.

### What goes in a dispatch

**Subagents inherit nothing.** Each implementer prompt must include:

- the task brief path, introduced as its requirements, with the exact values to
  use verbatim
- where this task fits in the wider change
- the issue requirement and acceptance criteria
- anything settled by an earlier task — an interface, a chosen approach — that
  the brief itself has no way of carrying
- your resolution of any ambiguity you noticed in the brief
- applicable `AGENTS.md` conventions
- exact guardrail commands to run before committing
- the TDD requirements below
- the report-file path, named after the brief (`…/task-N-brief.md` →
  `…/task-N-report.md`)
- the **worker report contract** (`AGENTS.md`), last, so the implementer
  returns a condensed report — references, not content — rather than its whole
  transcript

Exact values — numbers, magic strings, signatures, test cases — live in the
brief and nowhere else. What you send describes one task, not where the session
has been — resist pasting in the running summary of everything finished so far.
A dispatch observed in practice ran to 42k characters, essentially all of it
that accumulated history.

Hand artifacts over as **files**, not pasted text. Anything you paste into a
prompt, and anything a worker prints back, stays resident in your context and
is re-read on every later turn. The reviewer gets three paths — the brief, the
report, and the review package — plus the constraints that bind the task. Fix
dispatches append to the same report file.

**Constructing a reviewer prompt**, the rules that matter most:

- **Never rule on a finding before the reviewer has made it.** Watch for the
  shape: you are about to tell the reviewer that something is out of bounds, is
  settled, is at worst cosmetic, or was chosen deliberately. Every one of those
  is a verdict, written by the party a review exists to check, and the motive is
  almost always to avoid another round. Let it be raised; decide it after.
- Copy the plan's binding requirements **verbatim** into the global-constraints
  block: exact values, formats, and stated relationships ("same layout as X").
  That block is the reviewer's attention lens, and a paraphrase changes what it
  looks at. The template already carries the process rules.
- Give no instruction whose scope you cannot state. "Look at everything that
  touches this" and "try the concurrency suite if it seems worthwhile" are
  invitations to wander; name the reason and the target, or leave them out.
- The implementer already ran the tests and reported the results. Asking for
  that again buys nothing and costs a full run.

The whole-branch reviewer returns a bounded verdict and a path rather than the
review itself.

Every fix dispatch carries the implementer contract: re-run the tests covering
the change and report the command and its output. Name the covering test files —
a one-line fix does not need the whole suite. Confirm the report has all three
before re-dispatching the reviewer. One finding cannot take that contract: a
flaked test, where re-running it is the evidence the flake policy under
*Guardrails* rejects. Dispose of it where reported flakes are dispositioned,
above, rather than by dispatching a fix that re-runs it.

If the **final** review returns findings, send **one** fix worker and give it
the review file's path rather than a list — a list is the resident context cost
the review file exists to remove. Per-finding fixers each rebuild context and
re-run suites, and one real session's final-review wave cost more than all its
tasks combined.

Say in that dispatch what binds it, because a path carries none of the filtering
a hand-picked list did: critical, high, and medium findings are to be fixed;
Recommendations are not; and low findings are not *unless you name them in the
dispatch*, which is what you have just read the triage section to decide. A
finding labelled `plan-mandated` is likewise returned to you rather than fixed,
unless you name it as one the human has already upheld.

Order the two triggers: a non-zero `plan-mandated` count goes to the human
**before** the fix wave. Read those labelled findings out of `[REVIEW_FILE]`
first — that subset, not the whole file — and put each in front of the human
beside the plan text it disputes; a count alone asks them to rule on work they
have not seen. Then carry their answer into the dispatch by naming the upheld
findings. Nothing further is prescribed.

Put low findings in the ledger as they arrive, and hand the final review that
list to triage against the merge bar. A summary nobody is directed to read is
indistinguishable from having thrown the findings away. Where a finding and the
plan disagree, neither one wins by default and neither is yours to overrule: put
both in front of the human and ask which holds. That means not waving the
finding away on the plan's authority, and equally not sending a fix that
contradicts the plan without having asked.

### Durable progress

Conversation memory does not survive compaction. An orchestrator that no longer
knows which tasks finished will hand out work already done, sometimes a whole
run of it — the costliest failure this process has produced. Keep the record in
a ledger; todos alone are not enough.

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
compaction the ledger and `git log` outrank whatever you seem to remember: the
commits they name are on disk whether or not you recall making them.

### Never

- Let a task through unreviewed, or settle for a report carrying only one of the
  a spec-compliance check and canonical verdict. Both are required.
- Accept "close enough" on spec compliance, or let an implementer's self-review
  stand in for the task review.
- Make a worker read the whole plan file instead of its brief.
- Dispatch any reviewer without a review-package file.

**Review vocabulary.** Task and whole-branch reviewers use `$gauntlet`'s canonical
`critical | high | medium | low` severity and `approve | needs-attention` verdict
directly. `approve` requires zero findings. GitHub priority, unattended-execution
`risk:*` labels, restock coverage exposure, and a reviewer's named concern are
separate classifications and never map to severity.

## TDD rules

Whoever writes code — a worker or this session — works to the standard in
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

Run the project's local check suite discovered in `$attunement`. At minimum,
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

A guardrail that fails once and passes on re-run has not gone green — see
[true-seeing](../../references/true-seeing.md), *Flaky tests*. The rule above
holds unchanged: fix the determinism and say in the commit that it flaked. If
you file it instead of fixing it, that is a stop — report it to the orchestrator
with the issue reference. Filing does not turn a red guardrail into a green one.
That is stricter than a flake inside a task's own suite, and deliberately: a red
guardrail blocks the commit, where a flaked task test does not.

## Context checkpoint

The **durable artifacts** of this phase are the committed code and tests and the
plan's completed tasks — not the TDD red/green output or implementer transcripts.
Before handing off to review, confirm the branch name and the exact guardrail
commands are recorded somewhere durable (the plan, the campaign manifest, or a
note), so a post-compaction resume can recover them. Do **not** run `context compaction`
proactively; just keep the artifacts complete.
