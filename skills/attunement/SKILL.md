---
name: attunement
description: "Discover and record a repository's instructions, default branch, working- tree state, guardrail commands, GitHub authentication, decision-record coupling, and parallel-work context before changing code. Use when starting implementation, issue, pull-request, shipping, or campaign work."
---
# Preflight: Discover the Working Environment

Discover and record the repo environment before touching code or switching
branches. Record every finding in the task plan — later steps (`$spellcraft`,
`$forge`, `$deliver`) depend on `BASE_BRANCH` and the guardrail commands
discovered here. When invoked under `$campaign`, report `BASE_BRANCH` and the
guardrail commands back to the orchestrator, which records them in the campaign
manifest — the orchestrator is the manifest's sole writer, and the manifest
outlives the task plan across a fresh-session resume.

If you are running as part of a larger workflow (e.g. `$quest`),
completing preflight means proceed to the next step, not stop. Stop only on a
genuine blocker you have named.

## 1. Read the repo instructions

Read `AGENTS.md`, `CLAUDE.md`, and any nested instruction files that apply to
the files you will touch. If those instructions name an installed language
reference for the files' language (Python, TypeScript, Rust, Bash, or GitHub
Actions), read that reference before writing code — it holds the strictness and
supply-chain rules that are no longer inline in `AGENTS.md`.

## 2. Record architecture context

Run `scripts/detect-host-architecture` from this installed preflight package. Capture its
stdout and exit status even when it returns 2 or 3; do not merge stderr into the payload
and do not evaluate the payload as shell code. Accept only these status/payload pairs:

- exit 0 with `ok<TAB><normalized>`;
- exit 2 with `unsupported<TAB><raw-or-empty>`; or
- exit 3 with `detection-failed<TAB><reason>`.

Unsupported Bash-representable text uses `%q` so it remains observable without adding
fields, records, or terminal control sequences. Never evaluate that representation as
shell code. The detector assumes the resolved `uname` is the operating system tool and its
output is text; shell variables cannot retain binary NUL bytes. Anything else is a
malformed detector result and stops preflight with the observed status
and a request to repair the installed preflight package. Render `HOST_ARCHITECTURE` as the
normalized value, `unsupported (<raw-or-empty>)`, or `detection failed (<reason>)`.

Each agent then applies its native applicable-instruction precedence to the project-local
instruction and policy files read in step 1. Those effective files are authoritative for
target architectures. Record every effective target declaration in
`TARGET_ARCHITECTURES`; record `none declared` when effective policy is silent. Never infer
a target from the host, discard a declared target because it differs from the host, or use
an overridden declaration. Contradictory effective declarations remain unresolved.

Pass the detector status and value, the target state (`conflict`, `none`, or `declared`),
and each preserved declaration as a separate argument to
`scripts/resolve-architecture-context`. Use its `HOST_ARCHITECTURE` and
`TARGET_ARCHITECTURES` records and its final `ARCHITECTURE_RELATIONSHIP` record as one
context result. The resolver implements this first-match table:

| Priority | Condition | Value |
|---:|---|---|
| 1 | Effective target declarations contradict | `unresolved-target-conflict` |
| 2 | Host is unsupported or detection failed | `host-unresolved` |
| 3 | No effective target is declared | `no-target-declared` |
| 4 | Host is in the effective target set | `included` |
| 5 | Host is not in the effective target set | `different` |

For membership only, normalize recognized target aliases with the detector's mapping;
preserve the original declarations in `TARGET_ARCHITECTURES`. The same membership rule
applies to singleton and multi-target sets.

Retain that complete result in the task plan or durable workflow state before any
architecture-sensitive generation, build, or verification, and retain them for later
operations. Architecture-insensitive work may continue when the host is unresolved.
Sensitive work stops with the detector's actionable diagnostic when the host is
unresolved, and target-sensitive work stops for project-owner clarification when targets
conflict or a required target is not declared. A host/target difference is valid context,
not an error. Cross-compilation, emulation, and multi-architecture CI are outside
preflight's scope.

## 3. Discover the default branch

Store it as `BASE_BRANCH`; do not assume `main`. Prefer
`gh repo view --json defaultBranchRef`, falling back to `git remote show origin`
if needed.

## 4. Inspect the working tree

Run `git status --short --untracked-files=all`. If unrelated local changes
exist, stop and ask the user how to proceed. Do not stash, discard, or
overwrite user work without explicit approval.

## 5. Discover the local guardrail commands

Before the first commit, discover the repo's check suite. Use repo docs, build
manifests, workflow files, and common targets such as `just ci`, `make`,
package scripts, `pyproject.toml`, `Cargo.toml`, or `.github/workflows/`.
Record the exact commands in the task plan. Note which checks CI hard-gates
**individually** vs. only via an aggregate recipe — a guard added to an
umbrella `ci` target may not gate PRs if CI calls the sub-recipes directly.

Where the repo keeps an ADR index, also determine whether a gated check couples
the two — an ADR file requiring a matching index row, or the reverse. Read the
recipe rather than trusting its name; the guard is often a script the recipe
calls. Record a `coupled` / `not coupled` verdict beside the commands, and report
it to the orchestrator under `$campaign`. Step 7, `$spellcraft`, and `$campaign`
step 7 all branch on that coupling verdict.

Beside each command, record three facts the command line alone does not carry:

**Cost.** Record the approximate wall-clock time as an **observed duration**
— measured from an actual run of the command during this preflight or its
caller's work — or an explicit `unknown` when the command has never run. Do
not record a recommended timeout instead: a timeout budget is caller policy
layered on top of a measurement, and an unrun command supports neither claim.
`unknown` tells the reader to bound the first run generously; a duration tells
them what every later run costs. Update the entry when a later run replaces
an `unknown`.

**Prerequisites.** Everything the command needs that a default checkout does
not supply: installed tools with version floors, one-time setup targets such
as a hooks installer, credentials or services CI provides but a workstation
does not. Unrecorded, each of these is re-diagnosed per session.

**Known landmines.** Behaviors that look like failures but are not. A managed
pre-push hook that re-runs the whole check suite in an isolated worktree can
outlast a two-minute default tool timeout — that is slowness, not a hang, and
re-invoking after an apparent timeout restarts the suite instead of ending
it. Repo instruction files often name such hazards; carry them into the
record so a reader of the task plan does not have to find them there.

Before the first build, check prior art for exactly these facts. Search
`docs/solutions/` for tooling-involved records (`rg -li '<tooling keyword>'
docs/solutions/`, then scan the hits' frontmatter tags) — `$grimoire` fills
that directory, and its record format carries a tooling slot in `tags` for
precisely this read. This is the compounding loop `$detect-curse` runs before
investigating a failure, applied before anything goes red. No hit is a normal
result and costs one command — as is no `docs/solutions/` at all.

## 6. Confirm gh authentication

Confirm `gh` is authenticated enough to read the issue and later create a PR.
If authentication is missing, stop with the exact command the user should run.

## 7. Detect parallel-run context

If you were dispatched as one of several agents working sibling issues
concurrently, honor what the orchestrator handed you:

- Use the **ADR / migration numbers it assigned**. Do not pick "next free" —
  parallel agents all read the same "next free" and collide on ADR and
  migration filenames. If no number was assigned and you need one, ask the
  orchestrator rather than guessing.
- Stay strictly within the **file scope** you were given; do not edit files
  another agent owns, even to fix an adjacent nit — flag it instead.
- **Leave an ADR index alone** (e.g. target-repository: `docs/adr/README.md`). Write only
  your own ADR file and report `index row pending`; the orchestrator owns the row.
  Rows appended by parallel agents conflict even when their numbers are disjoint,
  because git conflicts on adjacent insertions.
  **Unless CI gates the index** — the gate outranks the run type because the row is a
  merge precondition and this rule is a convention. Take the coupling verdict
  from your dispatch prompt if the orchestrator supplied one, and otherwise run step 5's
  coupling check yourself; only a check CI hard-gates individually counts, not one
  reachable solely through an umbrella recipe. Where such a check enforces "one index row per ADR
  file", withholding the row puts your own stop condition out of reach: the
  check stays red until the row exists, and the orchestrator appends rows only
  after the wave's last PR merges — the merge that check is blocking. Add your own
  single row in your own PR then, matching the length and tone of the rows around
  it, and give its `Status` cell the same value as your record's own `## Status` —
  such a guard usually compares the two. Touch no other row and do not reflow the
  table; the orchestrator's serial-merge branch refresh (`$campaign` step 6)
  reconciles the adjacent-insertion conflicts between siblings.
- Expect generated-doc and snapshot files to be cross-agent conflict zones; keep
  your edits to them minimal and additive.
