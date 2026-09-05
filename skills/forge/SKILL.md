---
name: forge
description: "Implement an approved plan with contract-based task verification, direct or worker-driven execution, focused tests where applicable, and the repository guardrail suite. Use when asked to build with TDD, execute an implementation plan, or continue the build phase of an issue workflow."
---
# Build With Contract Evidence

Implement each material changed contract with the verification mode its evidence supports. Use
red-green TDD for executable behavior and machine-checkable structure; record a concrete
non-applicability reason only when no task-specific executable or structural observation can fail
meaningfully. Set up the workspace with **pocket dimension**, then pick an execution mode by what
`$spellcraft` produced:

- **A plan exists and its tasks are mostly independent** → **party**: a fresh
  implementer worker per task, each closed on its own verified contract evidence and
  guardrails, and one whole-branch review at the end.
- **No plan, because this is a trivial bugfix or a caller-verified
  `governed-small-change` — or a plan whose tasks are too tightly coupled to
  hand out** → **cast**: implement directly in this session.

**This skill is not the end of the pipeline.** `$trial-loop`,
`$dispel`, `$deliver` and `$return-to-town` follow and own integration,
so neither mode presents an integration menu and neither takes a merge, push, or
discard. That is a property of the run, and each dispatched worker learns it
only from its own prompt: the reviewer template carries it as its read-only
contract — the checkout left exactly as found, with the whole-branch reviewer's
single writable review file as the one exception — and the implementer template
carries it in its Placement section, beside the worktree-and-branch precondition
the worker must pass before its first edit. Never assert that a dispatch carries
an instruction its template does not state.

**Never start implementation on `main` or `master` without explicit consent.**
This binds both modes and every worker either one dispatches; the implementer
template restates it as part of that precondition.

When the caller supplies a governed-small-change classification with its revalidated decision
reference, decision kind, accepted status, governed behavior, and acceptance criteria, reject any
supplied or auto-discovered plan and construct the Cast inventory. A focused entry starts with its
failing test; a non-applicable entry starts with implementation and retains its exact reason.

Otherwise, if no plan path is supplied, look for one under `docs/workflow/plans/`.
No plan is valid only for a trivial bugfix. Any other non-trivial change without a plan
stops and returns to `$spellcraft`.

For every planned task, validate its `Verification` inventory before implementation. It must name
every material changed contract and give each exactly one supported mode:

- `focused-test` names the test file or case, expected red failure, and exact green command.
- `task-test-not-applicable` names the changed surface and explains why no task-specific
  executable or structural observation could fail meaningfully.

Reject an omitted, vague, or contradicted entry at the plan checkpoint. File type, task size,
convenience, and repository guardrails are not reasons. Changed script behavior, parsers, schemas,
record shapes, validation rules, generated artifacts, and other machine-checkable contracts use
`focused-test`. A described human-readable report or ledger shape is not machine-checkable when no
executable consumer validates it. Never search for or snapshot prose wording to manufacture
evidence.

Build-time scope expansion stops implementation, re-freezes scope, and runs full design without automatically reselecting the abbreviated path.

Return a discovered new decision, ambiguity, or scope expansion to the caller's
`SCOPE CHECKPOINT`; do not infer the decision or continue building. The caller records
the new authority, if supplied, in provenance before re-freezing the charter.

**Caller contract.** If invoked inside `$quest`, completing the build and
guardrails means proceed to the next step — do not end your turn. Stop only on
a genuine blocker you have named (e.g. a guardrail that cannot be made green).

## Forge result contract

Both execution modes return one verified result to `$quest`, never an inferred
absence of review. Resolve the workspace and its exact `progress.md` ledger
first; every result appends its ledger record once and reads that exact line
back before returning it.

- **Cast** has no whole-branch reviewer. After its tasks and guardrails pass,
  append and read back `Final review: not-required (reason <reason>, ledger
  <path>)`. Return `not-required`, that exact ledger line, its verified
  public-safe reason, and the ledger path. It must not return a review path.
- **Party** returns `required` only after its final review is closed and
  retained; it returns `required-failed` on every terminal final-review stop.
  Its detailed final-review lifecycle below supplies the exact record.

For Party, capture the fork point and reviewed HEAD as full immutable
`<base-sha>..<head-sha>` endpoint SHAs. Ledger records, result identity, and
the quest handoff use those full SHAs; `base7` and `head7` are display-only
abbreviations for filenames and human-facing status.

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

First establish whether the cause is understood. Direct correction is allowed only when the
current failure artifact or an already-recorded investigation identifies a specific cause and the
correction follows from that evidence. Familiarity, a plausible fix, or stale evidence from a
different failure is not enough. Without current causal evidence, run `$detect-curse` before
proposing a correction or asking whether to proceed. If the investigation cannot establish a
cause, apply the response below without guessing past the red baseline.

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

In Cast, construct the same inventory directly when no planned task exists. Run each focused entry
red then green; implement a non-applicable entry without a fabricated task test. Before closure,
inventory the actual diff and reconcile every material contract one-to-one with the inventory. A
missing or reclassified contract returns to the plan checkpoint and records no evidence.

Stop on a genuine blocker — a missing dependency, a test that will not pass, an
instruction you do not understand, a verification that fails repeatedly — and
say so. When a test or verification remains red and its cause is not established by the current
artifact or an already-recorded investigation, run `$detect-curse` before proposing another
correction or declaring the blocker unresolved. If the same artifact recurs after the same
evidence-backed correction with no new evidence, stop instead of repeating the diagnose-fix cycle.
Guessing past a blocker produces work that looks finished and is not.

After all Cast tasks and the guardrails below pass, emit the Cast
`not-required` ledger/result from *Forge result contract* before returning to
the caller. `$quest` consumes that verified result; it must not treat Cast's
lack of a whole-branch reviewer as an implicit no-review mode.

## Party — worker-driven execution

A fresh implementer worker per task, each closed on its own verified contract evidence and
guardrails, and one broad whole-branch review at the end. The isolated context
is the mechanism: a worker that inherits your session's history loses focus, so
construct exactly what each one needs instead of letting it inherit. It also
keeps your own context for coordination.

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

**The party's dispatches are serial, so dispatch them blocking** — set `background: false` on the
implementer, the whole-branch review, and the fix worker that follows it. Nothing here can proceed
until the current worker returns: the next task builds on the previous one's commits, the review
package needs every task's commits, and the fix worker needs the review. A backgrounded dispatch
buys no parallelism there and costs a turn every time this session wonders how it is going. A
dispatcher blocked on a worker cannot poll it, which removes the failure mode instead of governing
it.

The contract below still applies to a blocking dispatch, because a blocking dispatch can still end
without a report.

The implementer, whole-branch reviewer, and fix worker are separate report waits.
Apply [dispatch liveness and silent-worker recovery](../../references/dispatch-liveness.md) to
each. Before any replacement, append the worker, wait site, observations, recovery-chain
identifier, `unused` or `consumed` replacement budget, and artifact dispositions to
`progress.md`. The task brief, implementer report, review package, review file, branch commits, and
worktree state are reconciliation evidence. Do not replace or reclaim a worker on silence alone.

The chain identifier is minted at dispatch on every run, not when a silence
recovery starts. An implementer's is `task-<N>.<attempt>`; the fix worker after
the whole-branch review uses `review-fix.<attempt>`. `task-<N>` is the recovery
chain, and `.<attempt>` is `1` for the original and `2` for the one replacement
this budget permits — so the commits of a worker whose late report raced its
replacement are separable in `git log` rather than by ledger ordering.

`attempt` counts **only** the dispatch-liveness replacement. Re-dispatching a
unit after `NEEDS_CONTEXT` or `CANNOT_COMPLETE` reuses its current attempt
number: that worker was never silently lost, nothing of its work is in doubt,
and incrementing would spend a replacement budget no recovery consumed.

### The per-task loop

1. Generate the task brief: `scripts/task-brief PLAN_FILE N` writes it to a
   uniquely named file and prints the path.
2. Dispatch an implementer with [implementer-prompt.md](implementer-prompt.md),
   carrying the placement contract from *What goes in a dispatch*: the
   assigned worktree as an absolute path, the exact branch name, and the
   dispatch identity `task-<N>.<attempt>`.
3. If it asks questions, answer them fully before it proceeds. A question asked
   before the work is the cheapest one there is; hurrying it produces a defect
   instead of an answer.
4. It implements, produces the selected contract evidence, self-reviews, and commits.
5. Verify the reported commits landed on the assigned branch before accepting
   the task. In the assigned worktree, every SHA the implementer reported must
   satisfy `git merge-base --is-ancestor <sha> <BRANCH_NAME>`, and
   `git rev-list --count <BASE>..<BRANCH_NAME>` — with the BASE you noted
   **before** the dispatch — must be non-zero. A SHA that fails is a stray
   commit in some other tree, and an empty range is a task that committed
   nowhere. Either one is a stop-and-reconcile, because a worker that got lost
   is exactly the one whose self-report cannot be trusted.

   Then verify the same range identifies its author. Every commit in
   `<BASE>..<BRANCH_NAME>` must carry this task's dispatch chain:

       git log --format='%H %(trailers:key=Forge-Dispatch,valueonly,separator=%x2C)' <BASE>..<BRANCH_NAME>

   Verify the **chain**, not the exact value you issued. Every commit must carry
   `task-<N>` for this task's N, with an attempt of 1 or 2:

   - the value you dispatched — ordinary; the commit is this worker's.
   - the same unit at the other attempt — the late report that raced a
     replacement. Record both values in the ledger line's `chain` field and
     reconcile both result sets per dispatch-liveness. **Not a stop.** Stopping
     here would refuse the one case this identity was added to resolve.
   - the same unit at an attempt above 2 — a stop-and-reconcile. The replacement
     budget is one, so a third attempt means the budget was exceeded somewhere
     this check cannot see.
   - absent, or a different unit — the same stop-and-reconcile as a stray
     commit.

   A replacement dispatch reuses the original task base, so attempt 1's commits
   stay inside this range rather than falling outside it.
6. Read the report and verify one entry per planned contract. A focused entry contains the red
   command and expected failure plus the green command and passing result. A non-applicable entry
   repeats the plan's exact reason and confirms the implemented contract remained non-executable
   and non-structural. Missing or incomplete evidence is `NEEDS_CONTEXT`.

   A focused entry's red half is then re-derived rather than read. Two
   resolutions, and they are separate: resolve `scripts/verify-red` to an
   absolute path against **this skill's own directory** first — the script ships
   beside this skill, not in the target repository, the same as
   `scripts/task-brief` and `scripts/review-package` — then run that absolute
   path with the **assigned worktree** as the working directory. For each
   focused entry:

       scripts/verify-red --base <BASE> --head <HEAD> --test <the entry's test file> -- <the inventory entry's exact command>

   The command comes from the **plan's** Verification inventory, never from the
   implementer's report. A focused entry names a test file, an expected red,
   and a green command — and the red command *is* that green command, run
   against the reverted tree. That is the whole of what makes red and green one
   claim about one commit rather than two unrelated runs. The report also names
   a red command, and the report is written by the party this check exists to
   distrust; letting it supply the command would let a worker choose what
   certifies its own red claim. Where the report's command and the inventory's
   disagree, that disagreement is itself a stop-and-reconcile, not a choice for
   you to make. An inventory command you judge to be weak — one that could not
   observe the contract it names — is a plan defect that returns to the plan
   checkpoint; it is never grounds to substitute a better one here.

   `<BASE>` is the task base you noted before the dispatch; `<HEAD>` is the
   branch tip you verified in step 5 (`git rev-parse <BRANCH_NAME>`), which is
   the SHA the ledger line already records. Pass a command containing shell
   operators as `bash -c '<command>'` — the argument vector runs directly, not
   through a shell.

   `--test` takes **files**, and on every invocation you pass **every** test,
   fixture, and test-support path in the task's diff — whether or not the
   inventory names it, and not just the entry under check. Anything left out is
   classified as implementation and reverted, so the command then fails because
   a helper, a fixture, or a sibling entry's test file vanished rather than
   because the implementation did. That is a vacuous `red-confirmed`: the check
   manufacturing its own evidence. Only the command after `--` changes from
   entry to entry.

   When you cannot classify a changed path, pass it as `--test`. Over-reverting
   fabricates a pass; under-reverting at worst yields `red-not-reproduced`,
   which stops the run. Err toward the stop.

   Where an entry names a case rather than a file, pass the file part —
   everything before the `::` or the runner's selector flag. Where an entry
   names a test file this task did not change, the check does not apply to it:
   that entry returns to the plan checkpoint, because an inventory naming a test
   the task never touched is a plan defect rather than a verdict about red.

   Route on its exit status, which is the interface:

   - **0** (`red-confirmed`) — the entry is closed.
   - **1** (`red-not-reproduced`) — the command passed with the implementation
     reverted, so the report's red claim is unsupported. Stop and reconcile, as
     with a stray commit. Do not re-dispatch and do not accept the entry.
   - **4** (`red-not-separable`) — every path the task changed is a named test
     file, so there was nothing to revert. Record the outcome and continue; the
     entry is not verified and must not be described as though it were.
   - **6** (`red-command-dirtied-tree`) — the verdict on stdout is real, but the
     red command modified tracked paths `verify-red` did not revert and cannot
     restore. Stop and resolve the tree. Do not close the entry on the verdict
     alone: the residue belongs to the command that made it, and carrying it
     forward stops the next entry on a precondition one entry away from its
     cause.
   - **2**, **3**, or **5** — the check could not run, or the tree is not back
     at HEAD. Stop. A 5 leaves the worktree unresolved and nothing may proceed
     past it, exactly as a reviewer's `CLEANUP_FAILED` does.

   After **every** invocation — whatever its status, and including one that
   returned nothing at all — confirm the tree came back:

       git status --porcelain --untracked-files=no

   Non-empty is a stop with the pending paths named. `verify-red` restores under
   an EXIT trap, which covers an ordinary failure and an interrupt but not a
   `SIGKILL` or an abandoned invocation; those leave the implementation reverted
   and nothing inside the script can report it. On the exit-3 dirty-tree
   precondition, disposition the pending modification before re-running — it
   belongs to the worker's report — rather than only stopping.

   Never run the entry's command against the implemented tree and call the
   result red. `verify-red` is what turns that command into a red check: the
   same command that passes at HEAD has to fail once the implementation is
   reverted. Running it at HEAD proves nothing about whether it could ever have
   failed, which is the whole of what this step establishes.
7. Inventory the actual task diff and reconcile its material contracts one-to-one with the plan
   and report. An unmatched or reclassified contract returns to the plan checkpoint.
8. Mark the task complete in the todo list and append exactly one line, using `mixed` when both
   modes occur: `Task N: complete (commits <base-sha>..<head-sha>, verification
   <focused-test|task-test-not-applicable|mixed>, red <confirmed=<n>,
   not-separable=<n>>, chain <every distinct Forge-Dispatch value observed in
   the range, comma-separated>)`.

**A task's gate is its contract evidence, not a review.** There is no per-task reviewer.
Focused tests end testable contracts at a runnable pass/fail gate; non-applicable contracts end at
an explicit, diff-confirmed reason. A task-scoped
adversarial pass over surface the previous one just wrote spends a dispatch
mostly re-reading the loop's own output. What such a pass could see, the
whole-branch review sees too; what it could not see — the defect spanning
tasks — is why that review exists. ADR 0052 records the decision.

After the last task, run the guardrail suite under *Guardrails* over the
assembled branch and fix anything red before going further. With no per-task
reviewer, this is the first executable check that has seen every task's work
together. Then dispatch the whole-branch review with
[code-reviewer.md](code-reviewer.md), on the most capable model. It is the
branch's only adversarial pass.

Its base is the branch's fork point — `git merge-base HEAD <BASE_BRANCH>`,
recomputed here rather than carried forward, because a rebase moves it. Capture
that full SHA and the full `git rev-parse HEAD` result before dispatching.
Not the commit the build phase started from: a spec and plan committed before Task 1
belong to the branch this review judges. `BASE_BRANCH` is the value
`$attunement` recorded; if you do not have it, ask, and where nobody can be
asked report it as a blocker and return. Never default to `main`.

1. **Read the ledger first, scoped to this full `<base-sha>..<head-sha>`
   range.** A
   matching `required-failed` line returns `required-failed` unchanged with its
   ledger path and reason; do not regenerate the package, redispatch the
   reviewer, or continue the pipeline. `$quest` must park that result. No
   `Final review` line for this range: dispatch. A verdict line and no `closed`
   line: the review ran and its file is on disk, so resume at the fix wave — do
   not regenerate, do not clear, do not re-dispatch. Verdict and `closed` lines
   without a matching retained record: resume at step 6's retention marking.
   A retained line exposes the exact review and ledger paths to the caller and
   completes forge.

   A `review-publication-disposed` line suppresses retention only when it is
   paired with this range's retained record: that record names the current
   forge-ledger identity and exact review path, and the later disposal record
   names that same review path. Do not match a generic marker, prefix,
   substring, or an older range's disposal record. Do not infer completion from
   a missing review file or from the historical review line alone.
2. `scripts/review-package <fork-point> HEAD` for `[DIFF_FILE]`. It must exit 0
   and print a non-zero commit count and a non-zero byte count. Report and stop
   rather than dispatching: this file is the reviewer's whole input.
3. `[REVIEW_FILE]` is `<workspace>/final-review-<base7>..<head7>.md`, in the
   directory `scripts/sdd-workspace` prints. Remove anything already at that
   path before dispatching, so a file there afterwards is this dispatch's.
4. When the reviewer returns, `[REVIEW_FILE]` must exist and be non-empty.
5. **Append the ledger line once that check passes**, before the fix wave —
   `Final review <base-sha>..<head-sha>: <verdict> (review <path>)` — and a
   second, `Final review <base-sha>..<head-sha>: closed`, when the wave finishes.
   Two appends,
   not an edit, as everywhere else in that ledger. Before the wave and not
   after, because a run that dies mid-wave leaving no line sends the next one
   through step 1 to clear a finished review. A dispatch ending in a stop gets
   neither a verdict line nor a `closed` line. Every terminal final-review stop
   instead appends and reads back its `required-failed` line before returning;
   it is never an unrecorded no-review path.
6. Once the range has its `closed` ledger line and every in-run consumer has
   finished, retain the review for `$quest` rather than disposing it. Append
   `Final review <base-sha>..<head-sha>: retained for PR publication (review
   <path>, ledger <path>)`, using the exact regular, non-empty, mode-0600 review
   path and exact mode-0600 forge-ledger path. Read that line back before reporting
   success. The
   retained review stays in ignored scratch storage until `$quest`'s
   `publish-forge-review` helper verifies the PR comment and recoverably
   disposes it. Never move it to trash in forge, and never append retention for
   an unconsumed artifact or one still needed by a live worker.

**Party result.** A closed retained whole-branch review returns `required` with
its exact full `<base-sha>..<head-sha>` range, retained ledger line, review
path, and ledger path. A failed, missing, malformed, or unresolved required
review is terminal: return `required-failed` with its exact ledger line, ledger
path, and actionable local reason, and do not return a retained artifact.
`$quest` must park before delivery on that result. These modes are workflow
state, not interchangeable verdict labels.

A missing or empty file means the return is not evidence. If the reviewer produced no report,
apply the silent-party-worker contract above; only a reconciled, harness-observed end may consume
the chain's one replacement. If a report arrived but the file is missing or empty, keep the
existing malformed-return behavior: discard it, re-dispatch once, then stop and report. A reviewer
that returned `WRITE_FAILED` or `PACKAGE_MISSING` has named
the problem — stop on the first one. Do not retry at a second path; the
template's read-only rule rests on the reviewer having exactly one writable
path. Every such terminal stop, including an exhausted malformed return or
silent-worker recovery, is `required-failed`: append and read back
`Final review <base-sha>..<head-sha>: required-failed (reason <reason>, ledger
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

- **DONE** — verify its commits and close the task.
- **DONE_WITH_CONCERNS** — read the concerns first. Correctness or scope
  concerns get addressed before the task is closed; observations get noted.
- **NEEDS_CONTEXT** — supply what was missing and re-dispatch.
- **CANNOT_COMPLETE** — assess it. A context problem gets more context; a reasoning
  problem gets a more capable model; an oversized task gets split; a wrong plan
  gets escalated.

**Never retry an unchanged prompt after `CANNOT_COMPLETE`, and never ignore an
escalation.** If the implementer says it is stuck, something has to change.

**A reported flake is dispositioned here, before the task is closed** — fix the
determinism, or file it and record the reference. Filing is yours to do, not the
implementer's, and doing it now is what stops a nondeterministic run standing as
the whole of a task's evidence, where nothing between here and the whole-branch
review would look at it again.

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
implementers working from prose; reserve the cheapest tier for transcription —
where the plan text already contains the code to write — and for single-file
mechanical fixes.

**This governs your own model too.** A coordinating session runs on the most
capable model by default and then pays that rate for every turn it spends
dispatching, waiting, checking and reporting — which across a long build
outnumbers the turns it spends deciding anything. Capability is what the
dispatches above need; coordination is not where it earns its price. Where the
harness allows it, run a coordinating session no higher than the most capable
worker it dispatches, and keep the waiting off the model entirely — see Silent
party workers.

### What goes in a dispatch

**Subagents inherit nothing.** Each implementer prompt must include:

- the task brief path, introduced as its requirements, with the exact values to
  use verbatim
- the **placement contract** — the assigned worktree as an absolute path, the
  exact branch name the worker commits to, and the dispatch identity
  `task-<N>.<attempt>` it stamps on every commit. A dispatch missing any of the
  three values is invalid: do not send it, and stop with `NEEDS_CONTEXT` if you
  receive one. The implementer template turns them into a precondition the
  worker verifies before its first edit, failing closed on a mismatch
- where this task fits in the wider change
- the issue requirement and acceptance criteria
- anything settled by an earlier task — an interface, a chosen approach — that
  the brief itself has no way of carrying
- your resolution of any ambiguity you noticed in the brief
- applicable `AGENTS.md` conventions
- exact guardrail commands to run before committing
- the task's complete Verification inventory and the contract-evidence rules below
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
is re-read on every later turn. The whole-branch reviewer gets two paths — the
review package and the review file it writes — plus the plan and the constraints
that bind the branch. Fix dispatches append to the same report file.

**Constructing the reviewer prompt**, the rules that matter most:

- **Never rule on a finding before the reviewer has made it.** Watch for the
  shape: you are about to tell the reviewer that something is out of bounds, is
  settled, is at worst cosmetic, or was chosen deliberately. Every one of those
  is a verdict, written by the party a review exists to check, and the motive is
  almost always to avoid another round. Let it be raised; decide it after.
- Copy the plan's binding requirements **verbatim** into
  `[PLAN_OR_REQUIREMENTS]`: exact values, formats, and stated relationships
  ("same layout as X"). That slot is the reviewer's attention lens, and a
  paraphrase changes what it looks at. The template already carries the process
  rules.
- Give no instruction whose scope you cannot state. "Look at everything that
  touches this" and "try the concurrency suite if it seems worthwhile" are
  invitations to wander; name the reason and the target, or leave them out.
- The implementer already ran the tests and reported the results. Asking for
  that again buys nothing and costs a full run.

The whole-branch reviewer returns a bounded verdict and a path rather than the
review itself.

Every fix dispatch carries the implementer contract, placement included: the
assigned worktree path, branch name, and the `review-fix.<attempt>` dispatch
identity, verified before the first edit. Re-run the tests covering the change
and report the command and its output. Name the covering test files — a
one-line fix does not need the whole suite. Confirm the report carries the
command, its output, and the covering test files before closing the fix wave.

Verify the fix wave's commits the way step 5 verifies a task's: every commit
from the reviewed HEAD to the branch tip must carry `review-fix.<attempt>`.
Absent or a different unit is a stop-and-reconcile. A stamp nobody checks is
attribution the next reconciliation cannot rely on.

One finding cannot take that contract: a
flaked test, where re-running it is the evidence the flake policy under
*Guardrails* rejects. Dispose of it where reported flakes are dispositioned,
above, rather than by dispatching a fix that re-runs it.

If the **final** review returns findings, send **one** fix worker and give it
the review file's path rather than a list — a list is the resident context cost
the review file exists to remove. Per-finding fixers each rebuild context and
re-run suites, and one real session's final-review wave cost more than all its
tasks combined. It carries the same placement contract as any implementer: the
branch's worktree path, branch name, and the `review-fix.<attempt>` dispatch
identity, verified before the first edit.

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

Put the review's low findings in the ledger with the disposition you gave each
one — named into the fix wave, or left. A summary nobody is directed to read is
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
out of a PR diff. It makes `<workspace>` mode 0700. Every controller-owned
ledger, review, summary, handoff, and publication body in that directory must
be a regular mode-0600 file before it is handed to another workflow phase.
Fail closed if that check fails; do not retain or publish the artifact. Writing
`progress.md` at a hardcoded path with an editor tool skips these protections,
and in a repo that tracks everything the next `git add -A` sweeps the ledger
into someone's commit. Run the script — or `task-brief` / `review-package`,
which call it — before the first write, then confirm:

```bash
git check-ignore -q "$(git rev-parse --show-toplevel)/.agent/sdd/progress.md"
```

A failure there means that write was refused or reverted, not that a further
ignore step is owed. Do not reach for `.git/info/exclude`: a sandboxed agent may
be denied writes to `.git/` entirely.

When a task's commits are verified on the branch, its report contains every selected evidence
entry, its actual diff reconciles to the inventory, and its guardrails passed, append one line:
`Task N: complete (commits <base-sha>..<head-sha>, verification
<focused-test|task-test-not-applicable|mixed>, red <confirmed=<n>,
not-separable=<n>>, chain <every distinct Forge-Dispatch value observed in
the range, comma-separated>)`. After any
compaction the ledger and `git log` outrank whatever you seem to remember: the
commits they name are on disk whether or not you recall making them.

### Never

- Close a task on a report missing any selected contract evidence or guardrail result, or on
  commits you have not verified onto the assigned branch.
- Let the branch reach handoff without the whole-branch review, or accept
  "close enough" on what the plan asked a task for.
- Make a worker read the whole plan file instead of its brief.
- Dispatch the reviewer without a review-package file.

**Review vocabulary.** The whole-branch reviewer uses `$gauntlet`'s canonical
`critical | high | medium | low` severity and `approve | needs-attention` verdict
directly. `approve` requires zero **blocking** (`critical` or `high`) findings;
`medium` and `low` are notes and do not withhold it.

Forge's *routing* is unchanged by that gate and is deliberately stricter than it:
the fix wave takes `medium` as well, and `low` findings go to the
ledger. A verdict states what the reviewer found; routing states what this
orchestrator does with it, and forge choosing to fix a note is not the reviewer
withholding a verdict over one. GitHub priority, unattended-execution
`risk:*` labels, restock coverage exposure, and a reviewer's named concern are
separate classifications and never map to severity.

## Contract-evidence rules

For every `focused-test` entry, whoever writes code — a worker or this session — works to the
standard in [trial-by-fire](../../references/trial-by-fire.md):

1. Write the failing test first.
2. Run it and confirm it fails for the expected reason.
3. Write the minimal implementation.
4. Run the focused test and relevant guardrails.
5. Refactor only while staying green.

Test behavior and edge/error paths, not implementation details: empty input,
null or missing values, malformed input, boundaries, timeouts, partial
failure, permission failures, and degraded dependencies where relevant.

For `task-test-not-applicable`, preserve the exact reason and do not create a prose search,
snapshot, or unrelated assertion. This removes only the focused task test; repository guardrails
and the whole-branch review required by Party or the caller remain mandatory.

When a plan defines bounded agent-behavior evaluation cases, run them against the changed
instructions with a fresh evaluator and compare observable routes and forbidden traits directly to
the plan. Keep private inputs and reports private. One pass is expected; after an evidence-backed
correction, allow one confirming pass. A second failure parks instead of starting a third pass.

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

The **durable artifacts** of this phase are the committed implementation, selected verification
evidence, and completed plan tasks — not raw red/green output or implementer transcripts.
Before handing off to review, confirm the branch name and the exact guardrail
commands are recorded somewhere durable (the plan, the campaign manifest, or a
note), so a post-compaction resume can recover them. Do **not** run `context compaction`
proactively; just keep the artifacts complete.

Before returning a Cast result, append and read back one private ledger line per reconciled
contract. Every substituted value must be non-empty and contain no semicolon, CR, LF, or NUL:

`Cast verification: <contract> = focused-test (red command <command>; red exit <status>; red
observation <summary>; green command <command>; green exit <status>; green observation <summary>)`

`Cast verification: <contract> = task-test-not-applicable (reason <reason>)`

Commands are exact, statuses are decimal, observations are concise single-line summaries, and raw
output remains transient. Refuse an unrepresentable value; do not add escaping or a parser.
