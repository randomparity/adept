---
name: build-tdd
description: "Implement an approved plan with test-driven development, direct or subagent- driven execution, focused verification, and the repository guardrail suite. Use when asked to build with TDD, execute an implementation plan, or continue the build phase of an issue workflow."
---
# Build With TDD

Implement the design using test-driven development throughout. Pick the
execution mode by what `$design` produced:

- **A plan exists and tasks are mostly independent:** execute it with
  `subagent-driven-development`: a fresh implementer subagent per
  task, each followed by the skill's two-stage review: spec compliance, then
  code quality.
- **No plan because this is a trivial bugfix or caller-verified
  `governed-small-change`, or tasks are tightly coupled:**
  implement directly in this session.

**You are the dispatched caller of whichever execution skill you invoke** —
`subagent-driven-development`, or `executing-plans` if the plan's header sends
you there. Its *Dispatched mode* section applies, and say so when you invoke it.
The edge that matters: both skills terminate in
`finishing-a-development-branch`, and you are **not** the end of the pipeline —
`$review-loop`, `$simplify-changes`, `$ship-pr` and `$merge-cleanup` follow. The skill
must report back to you instead of presenting an integration menu, and must take
no merge, push, or discard. That mode is a property of the run, so the
implementer and reviewer subagents you dispatch inherit it; their prompts say so.

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

## Subagent execution

Honor repo-level subagent and worktree rules. If repo instructions require
mutating subagents to work in separate worktrees, obey that. Otherwise,
sequential subagent dispatch on the same feature branch is allowed. Never
dispatch mutating subagents in parallel in the same working tree.

**Model selection per dispatch.** Use the skill's model-selection guidance:

- Mechanical task, complete spec, one or two files, no design latitude: cheap
  fast model.
- Multi-file integration or pattern-matching task: standard model.
- Design judgment, broad review, or every reviewer dispatch: most capable
  model.

When an implementer reports `BLOCKED` or returns weak work, change something
before retrying: add missing context, split the task, or escalate the model.
Do not blindly retry the same prompt.

**Subagents inherit nothing.** Each implementer prompt must include:

- full task text from the plan
- issue requirement and acceptance criteria
- where the task fits in the overall design
- applicable `AGENTS.md` conventions
- exact guardrail commands it must run before committing
- TDD requirements below
- the **subagent report contract** (`AGENTS.md`) — the prompt must end with it so
  the implementer returns a condensed report (references, not content), not its
  full working transcript

Every reviewer dispatch (spec-compliance, then code-quality) ends with the same
report contract, so the parent gets a bounded verdict rather than the whole review.

**Severity mapping.** The skill's reviewers grade `Critical / Important / Minor`; the
workflow pipeline's canonical scale is `$challenge`'s `critical | high | medium | low`.
When a task-review finding is carried outward — into `$review-loop` or the `WORK:REVIEW`
summary `$work-issue` posts — convert it with the table in `$challenge`, *Severity
vocabulary*, which owns both the enum and the conversion. Keep the skill's own vocabulary
*inside* the skill: its gates key on those words ("dispatch fix subagents for Critical
and Important findings"), so rewriting them at the dispatch site breaks the gate.

## TDD rules

Whoever writes code — subagent or this session — uses
`test-driven-development`:

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
