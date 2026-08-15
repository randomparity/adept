# Adept workflow benchmark protocol v1

Status: frozen for the first baseline after issue
[#118](https://github.com/randomparity/adept/issues/118)

This document is the normative protocol for the first baseline in epic
[#117](https://github.com/randomparity/adept/issues/117). It compares a bare Codex agent, a fixed
generic workflow, and pinned Adept on public issue-to-pull-request tasks and three-task campaigns.
The words **must**, **must not**, **required**, and **forbidden** are normative.

Issues #119 through #123 may encode this contract in manifests, runners, run records, scoring, and
reports. They must not weaken or reinterpret it. If a baseline cites v1, any semantic correction
requires a new reviewed protocol version; published v1 evidence does not change retroactively.

## Scope

The benchmark measures the end-to-end workflow under three control conditions, both as individual
tasks and as campaigns. It records functional resolution, workflow terminal state, reported token
usage, wall time, output size, operator interactions, and label-blinded quality and security review.

This version does not compare models, providers, or agent harnesses. It does not define a hosted
service, dashboard, leaderboard, task manifest format, run-record schema, runner implementation,
scoring implementation, task IDs, or baseline result. It excludes private tasks, tasks made for
Adept, real Adept tasks, and optimization of Adept from benchmark outcomes.

## Frozen inputs

### Agent, model, and Adept

Every run must use:

- Codex CLI package `@openai/codex` version `0.147.0`;
- model identifier `gpt-5.6-sol`;
- reasoning effort `medium`;
- non-interactive invocation family `codex exec --json --ephemeral`; and
- Adept source revision `3d74a47dfc7091f9f683c8c2119ba1648dfef821` in the Adept arm.

The invocation must also use `--ignore-user-config`, `--ignore-rules`, `--strict-config`, and a
fresh benchmark-owned `CODEX_HOME`. The only configuration values are:

```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "medium"
approval_policy = "never"
sandbox_mode = "workspace-write"
```

Enabled Codex features are `multi_agent`, `plugins`, `skill_search`, `shell_tool`, `unified_exec`,
and `view_image`. Every other feature reported by Codex CLI `0.147.0` must be disabled.

The Adept plugin must be built or installed from the pinned Git commit. Before Codex starts,
preflight must resolve the source checkout to the full commit, verify a clean tree, and compare a
digest of the installed plugin tree with the expected digest. A revision or digest mismatch makes
the attempt `infrastructure_invalid`.

OpenAI exposes `gpt-5.6-sol` as an identifier, not a dated immutable snapshot. The requested model
value is frozen; server weights are not proven fixed. Retain any response or service fingerprint
Codex exposes and report its absence as unavailable. Results may claim protocol reproducibility,
not bit-identical model behavior.

### Public tasks and evaluator

Every task must come from the test split of `SWE-bench/SWE-bench_Verified` at Hugging Face revision
`03e151cf5560b1af6a4363c6a9d766deaaea6b56`.

Functional evaluation must use `SWE-bench/SWE-bench` revision
`128cbd1a5759694874e6bd56624cb2fd6fb079e2` and its Docker harness. Each run record must retain the
evaluator revision and every evaluator image identifier or digest.

The manifest must contain exactly six public tasks in two groups of three. Every group must belong
to one upstream repository and declare one common starting revision. The two selected groups must
belong to different repositories. Each task must record its upstream license, issue URL,
repository, original base commit, tests, and common-revision adaptation evidence.

### Deterministic task selection

At the pinned dataset revision, enumerate the test split by ascending `instance_id` and retain a
complete candidate ledger. Exclude a task only for one of these objective reasons:

- its repository is not public;
- its SPDX license is not `MIT`, `BSD-2-Clause`, `BSD-3-Clause`, `Apache-2.0`, `ISC`,
  `Python-2.0`, or `PSF-2.0`;
- its pinned evaluator image is unavailable;
- its tests cannot be reproduced with the pinned evaluator; or
- the public issue author or SWE-bench contribution author has GitHub login `randomparity`; or
- public evidence does not expose the author identity needed for that exact-login check.

Every exclusion must record the applicable rule and public source evidence before any arm runs.

For each repository in lexical order, enumerate every three-element combination of eligible
instances. Sort the IDs inside each combination lexically, then sort combinations by the tuple
`(first_id, second_id, third_id)`. The candidate common revisions are the combination's distinct
full original-base commit SHAs in lexical order; timestamps do not participate.

Test candidate revisions in that order. Install the unchanged public issue bodies in the benchmark
tracker. Test every task independently from a clean candidate checkout. Require `git apply --check`
and `git apply` for its gold patch without edits, fuzz, or conflict resolution. Under the pinned
evaluator, at least one `FAIL_TO_PASS` test must fail before the patch, and every `FAIL_TO_PASS` and
`PASS_TO_PASS` test must pass after it. Restore the candidate before the next task. The first
revision satisfying those rules for all three tasks is the combination's common revision. Select
the first two qualifying combinations from different repositories.

Freeze and publish the manifest and the complete accepted and rejected candidate ledger before any
smoke or measured arm output is observed. If two groups do not qualify, stop and revise this
protocol; discretionary replacement is forbidden.

Gold patches are available only during manifest validation. They, SWE-bench test patches,
`FAIL_TO_PASS` and `PASS_TO_PASS` metadata, hidden evaluator tests, and validation workspaces must
not be reachable from an agent run.

Agent-visible task material is limited to the unchanged public issue body and repository files,
tests, and instructions reachable at the common revision. Freeze and digest that set before any
oracle-backed validation. It must not include or derive test names, bodies, acceptance criteria,
or hints from a gold patch, SWE-bench test patch, `FAIL_TO_PASS` or `PASS_TO_PASS` metadata, hidden
evaluator test, or validation result.

## Common execution environment

All arms must receive the same task repository, repository-native instructions, unchanged issue
bodies, common-revision public tests, common starting revision, credentials, tool inventory,
budgets, and authorization. Repository-native instructions must remain unchanged across arms.

For every quoted prompt or instruction below, remove the Markdown `> ` prefixes, join consecutive
quoted lines with one ASCII space, decode Markdown character references, and append one LF byte.
The resulting UTF-8 bytes are the input; Markdown wrapping is not an embedded newline.

Every task repository must receive this exact common instruction overlay:

> You are running a public code challenge in a benchmark-owned fork. Follow repository
> instructions and work only on the stated issue or issues. Do not seek or inspect oracle patches,
> hidden evaluator tests, other runs, or benchmark results. Task upstreams are unavailable. Mutate
> only run-owned state in the benchmark-owned repository. This run is unattended; if a necessary
> product decision cannot be sourced, request input and stop. Stay within the provided wall and
> token budgets.

Preflight must compare the configuration and overlay bytes with protocol-owned SHA-256 digests.

### Allowed capabilities

Every arm has these Codex built-in capabilities:

- local shell execution and stdin;
- patch editing;
- local image inspection; and
- Codex agent collaboration.

No arm may access an MCP server, app connector, interactive browser, external memory, or undeclared
plugin. The Adept arm's only capability delta is the pinned Adept plugin and its skill instructions.
The bare and generic arms load no plugin.

Shell-visible commands are the task repository's pinned build tools plus benchmark-pinned `git`,
`gh`, container runtime, language toolchain, and package manager versions. Before every run,
preflight must compare tool names, paths, and versions with the allowlist. An observed unexpected
capability is invalid, even if all arms happen to expose it.

Network destinations are limited through a path-scoped egress proxy to:

- the model service;
- benchmark-owned GitHub repository and API routes; and
- a benchmark-owned dependency-artifact mirror frozen from the common revision's manifests before
  oracle-backed validation.

The dependency mirror must record immutable paths and digests and expose no index, search,
latest-version, task-package, source-distribution, or documentation discovery route. During agent
execution, the proxy must reject task upstreams, public registries, external documentation, general
GitHub search, later commits, pull requests, issue discussions, and every undeclared route.
Domain-level GitHub permission alone is insufficient.

Credentials must be identical across arms and scoped to benchmark-owned repositories. GitHub
writes are limited to run-owned branches, issues, pull requests, comments, labels, and, for
campaigns, permitted merges in benchmark-owned repositories. Upstream repositories are read-only.

Before every run, retain model settings, enabled features, environment variables after secret
redaction, resolved tools, command versions, plugin and skill inventories, Codex version output,
operating system, host architecture, container runtime, prompt bytes, and relevant digests.

## Experimental arms

Only the workflow input differs between arms.

### Bare agent

No Adept plugin or workflow checklist is present.

Individual prompt:

> Resolve issue #&lt;n&gt; in this repository. Drive the change to a tested, committed, CI-green
> pull request ready to merge.

Campaign prompt:

> Resolve issues &lt;ordered-list&gt; in this repository. Process the complete batch, keep each
> change tested, and leave every issue closed by a verified merge or clearly classified with its
> blocking reason.

### Generic workflow

No Adept plugin is present. Append this exact checklist to the corresponding bare prompt:

> Inspect repository instructions and the live issue before changing files. State the acceptance
> criteria, work on a feature branch, test the intended behavior and error paths, review the
> complete diff, run repository guardrails, create a pull request, and verify required checks and
> mergeability. For a batch, track dependencies explicitly and do not let one issue-local blocker
> stop unrelated work.

### Adept

Install and verify Adept revision `3d74a47dfc7091f9f683c8c2119ba1648dfef821`.

Individual prompt:

> $quest &lt;n&gt;

Campaign prompt:

> $campaign &lt;ordered-list&gt;

No arm may receive an oracle patch, hidden evaluator test, another arm's transcript, an earlier
repetition's output, or any post-run score.

## Matrix and schedule

The first measured baseline contains:

- six task cells × three arms × three repetitions = 54 individual run units; and
- two campaign cells × three arms × three repetitions = 18 campaign run units.

All 72 nominal units execute serially. A task/repetition is one individual observation. A complete
three-task campaign/repetition is one campaign observation; its nested task outcomes are not
independent campaign samples.

### Deterministic measured order

A block is one mode, cell, and repetition with its three arm runs. Its canonical ID is
`<mode>/<cell-id>/<repetition>`, with repetitions numbered 1 through 3. The schedule seed is the
lowercase SHA-256 digest of the frozen manifest bytes.

Sort all blocks by:

```text
SHA-256("adept-v1-order" + NUL + seed + NUL + block-id)
```

Break a digest tie by block ID. For each block, let `i` be its zero-based rank among sorted blocks
of the same mode. Run its arms in the cyclic order beginning at `i mod 3` over
`[bare, generic, adept]`. Each arm therefore occurs first, second, and third equally within each
mode across three repetitions.

Retain the manifest digest and full nominal schedule before smoke starts. Do not regenerate or
reorder it after any outcome.

### Smoke order

Before the baseline, run six serial smoke units. Use the lexically first task in the first selected
manifest group in `[bare, generic, adept]` order, followed by that complete group in
`[bare, generic, adept]` order. Smoke uses fresh repetitions of baseline-eligible inputs, is
excluded from aggregates, and must not expose its transcripts or outcomes to later runs.

### Isolation and campaign evaluation

Every individual run starts from its group's common revision and fresh tracker state. Every
campaign starts from that revision and the same ordered three-issue topology. Changes may
accumulate inside a campaign; no state may cross arms or repetitions.

The campaign issue order is the selected combination's ascending lexical `instance_id` order. The
manifest, materialized tracker, prompt ordered list, and topology digest must preserve that order
before smoke starts.

The agent-visible repository must be a benchmark-owned sanitized Git repository whose object graph
and refs end at the common starting revision. It must have no alternate object store, upstream
remote, later commit object, pull-request ref, reflog entry, or gold-patch object. Provisioning must
verify this boundary before launch.

For each campaign task, retain its merge commit and run its evaluator at that commit. This is the
nested historical functional result. At final campaign HEAD, replay all three task evaluators and
retain those results separately. A campaign is resolved only when all issues reach the required
merged state and every evaluator passes at final HEAD. A later regression does not rewrite a
nested result, but it makes the campaign unresolved.

## Budgets and terminal outcomes

| Mode | Hard wall limit | Reported-token ceiling |
| --- | ---: | ---: |
| Individual | 60 minutes | 250,000 |
| Campaign | 180 minutes | 750,000 |

Wall time begins when the Codex process starts. Provisioning, functional evaluation, and cleanup
are timed separately and do not consume agent wall time.

The latest cumulative Codex usage event is authoritative. Budget usage is:

```text
input_tokens + output_tokens
```

Cached-input tokens are a subset of input tokens, and reasoning tokens are a subset of output
tokens. Retain both breakdowns but never add them again. Before baseline execution, smoke must show
that the pinned CLI emits non-negative integer input and output totals. Missing, partial,
decreasing, or malformed usage is an `infrastructure_invalid` telemetry failure.

Stop at the first cumulative usage record above the ceiling. If usage is available only at
termination, preserve the completed trajectory but classify it `agent_budget_exhausted` when the
final total exceeds the ceiling. Enforce the wall timer externally. A tie between a wall event and
a usage event resolves as timeout.

### Exhaustive terminal classification

Every launched attempt receives exactly one class. Apply this precedence; the first matching row
wins:

| Order | Evidence | Terminal class |
| ---: | --- | --- |
| 1 | Harness-owned or unknown-ownership failure | `infrastructure_invalid` |
| 2 | External wall timer fired before Codex exited | `agent_timeout` |
| 3 | Authoritative usage first exceeded its ceiling | `agent_budget_exhausted` |
| 4 | Healthy capture shows failed process or malformed or missing agent output | `agent_error` |
| 5 | Agent explicitly declines the authorized task | `agent_refusal` |
| 6 | Agent asks for a benchmark-operator decision needed to continue | `agent_needs_input` |
| 7 | Agent records another blocker or deliberate handoff | `agent_parked` |
| 8 | Mode-specific required state and every applicable final evaluator pass | `resolved` |
| 9 | Any other healthy, completed observation | `unresolved` |

A repository state produced before a resource breach does not override the resource class. A
refusal is an explicit rejection, not a request for information. An operator-input request wins
over a simultaneous workflow parked marker. `agent_parked` covers blockers that do not ask the
benchmark operator to decide.

For an individual, the required state is a tested committed pull request with all required checks
passing and GitHub reporting it mergeable. Merging an individual pull request is forbidden and
unnecessary. Its pinned evaluator must pass on pull-request HEAD. For a campaign, every issue must
be closed by its verified merge and all three evaluators must pass at final campaign HEAD.

Harness-owned failures include setup, evaluator, credential, capture, cleanup, and usage telemetry
failures. Unknown ownership means retained evidence cannot distinguish agent failure from harness
or capture failure. The harness-health record must be outside the agent process and contain process
exit, capture continuity, disk-write result, and artifact-validation result.

Missing artifacts never count as unresolved or inferred success. With healthy capture, a nonzero
exit, crash, malformed output, successful exit without a required patch, or missing agent terminal
artifact is `agent_error`.

## Retry, reset, and cleanup

Agent outcomes are never retried. One `infrastructure_invalid` attempt permits one replacement
after the original attempt and cause are retained. The replacement keeps the matrix identity and
increments the attempt number. Insert it immediately after the invalid attempt and before the next
nominal smoke or measured unit. Do not reorder later nominal units. Retain the expanded schedule as
it grows. A second infrastructure failure remains invalid without another replacement.

Before every run, verify:

- all immutable revisions and expected digests;
- a clean workspace and empty run-owned branch and pull-request set;
- expected issue bodies, labels, and dependencies;
- prompt, instruction, configuration, tool, and plugin inventories;
- evaluator availability; and
- the absence of prior-run state.

Retain all evidence before cleanup. Then remove or archive run-owned local state and restore the
benchmark-owned GitHub state. A cleanup failure prevents another run in that repository until
reconciliation proves the required clean start. Never mutate an upstream challenge repository.

## Measurements and aggregation

Each attempt must retain:

- raw cumulative input and output tokens;
- cached-input and reasoning token breakdowns, or null when an optional breakdown is unsupported;
- monotonic agent wall time, plus separate provisioning, evaluation, and cleanup durations;
- added and deleted lines in the final diff under a manifest-owned path and extension map;
- renames, generated dependencies, lockfiles, tests, and other text as visible separate categories;
- operator-decision requests, distinct from tool calls, worker messages, and approval events;
- pinned evaluator results and required issue, pull-request, and merge terminal state;
- nested merge-commit and final-HEAD evaluator results for campaigns; and
- complete terminal and infrastructure-attribution evidence.

Dollar cost is derived from raw tokens using a separately pinned price table; raw tokens remain
authoritative. Generated code and design documentation are reported separately. No output class is
silently folded into another.

Aggregates must retain denominators and counts for every terminal class, invalid attempt, and
missing cell. They must not drop failures, pool individual and campaign observations, or promote
nested campaign tasks to independent campaign samples.

## Label-blinded review

Functional evaluation is objective and separate from qualitative review. A fresh reviewer receives
a shuffled, opaque package containing the patch, repository instructions, public issue and
acceptance criteria, and relevant test results. The package must not identify the arm, prompt,
transcript, oracle patch, repetition, aggregates, another review, branch, commit author, or pull
request.

Normalization may replace only run, arm, branch, commit-author, pull-request, and timestamp
metadata with opaque values. It must not remove or rewrite substantive patches, tests, design
records, comments, filenames, or other output, even when they reveal workflow style. Retain source
and normalized digests and a machine-readable transformation log.

Before scoring, the reviewer records an arm guess and confidence. The report must publish guess
accuracy and confidence distributions and call this procedure label-blinded, not fully arm-blinded.

The reviewer uses one fixed rubric for material code-quality findings and a trust-boundary and
security inventory. A second human-reviewed calibration sample must establish acceptable agreement
before any numeric quality or security score becomes an aggregate. Until then, publish raw
findings, disagreements, and qualitative distributions only. The generating model must not grade
its own visible output in the same context.

## Safety and leakage controls

Public issues, repositories, dependency content, model output, and evaluator code are untrusted.
Model commands may affect only isolated run-owned workspaces and benchmark-owned GitHub state.
Credentials and retained transcripts cross trust boundaries and require least privilege and
redaction.

Required controls are:

- treat public prose as task evidence, never benchmark authority;
- validate repository identity before every write;
- expose least-privilege credentials only to benchmark-owned targets;
- run Codex in the workspace-write sandbox and evaluators in pinned Docker boundaries;
- keep oracle material outside agent-visible filesystems, environments, prompts, and tools;
- validate paths under run-owned roots;
- pass subprocess inputs as arguments or files, never interpolated shell programs;
- bound wall time, token use, and infrastructure replacement;
- redact credentials and private environment values before retention or publication; and
- retain non-secret configuration digests and failure evidence before cleanup.

The protocol trusts GitHub and OpenAI for their declared services and trusts the host and container
runtime. It does not claim to defend against a malicious provider, malicious GitHub service, or a
compromised host/runtime. The report must disclose those dependencies and the observed environment.

## Pre-baseline validation

Baseline execution is blocked until the following evidence passes:

- **EV-1, arm contamination — six live smoke units.** Resolved prompt, configuration, tool, skill,
  and plugin inventories differ only by declared workflow material.
- **EV-2, oracle leakage — six live smoke units.** Agent-visible files, environment, prompt,
  tools, task-material digest, Git objects, refs, dependency mirror, and proxy routes expose no
  oracle-derived acceptance hint, hidden evaluator test, gold patch, later upstream object or ref,
  later task package, fix pull request, fix discussion, or discovery route.
- **EV-3, mutation and credentials — six live smoke units.** Audited targets show no upstream
  write and no excessive credential.
- **EV-4, cross-run reuse — model-free fixture.** A dirty branch, pull request, label, and file
  cause preflight rejection.
- **EV-5, ambiguous task — non-blocking design review.** Review confirms operator input is not
  synthesized.
- **EV-6, stale task data — model-free fixture.** A conflicting revision and issue cause rejection
  before agent start.
- **EV-7, budget escape — model-free fixture.** Synthetic wall and usage events preserve evidence
  and classify correctly.
- **EV-8, malformed output — model-free fixture.** Agent-owned malformed output, capture
  interruption, and an unknown missing artifact classify as `agent_error`,
  `infrastructure_invalid`, and `infrastructure_invalid`, respectively.
- **EV-9, individual path — three live individual smoke units.** Every arm starts clean and
  retains a complete trajectory and evaluator result.
- **EV-10, campaign path — three live campaign smoke units.** Every arm has identical topology,
  isolation, nested results, and final evaluator results.

The protocol-validation fixture suite does not invoke the model. Its cases are not run units or
replacement attempts. EV-5 warns but does not block. EV-1 through EV-4 and EV-6 through EV-10 must
pass before the first measured unit.

Pins, digests, counts, timing, terminal classes, evaluator results, and artifact completeness are
code-measured. Quality and security judgment remains review evidence until human calibration.

## Required publication evidence

A baseline report conforming to v1 must publish or link:

- the frozen protocol, manifest, selection ledger, common-revision evidence, and schedule;
- resolved model, Codex, Adept, evaluator, environment, capability, and configuration evidence;
- all nominal cells and retained infrastructure-invalid attempts with denominators;
- raw measurement fields and derivation inputs;
- functional results at required individual, merge-commit, and final campaign boundaries;
- label-blinded packages, transformation logs, rubric, arm guesses, confidence, and calibration
  status;
- smoke and protocol-validation evidence for EV-1 through EV-10; and
- disclosed provider, GitHub, host, container, telemetry, and model-snapshot limitations.

This evidence makes the comparison auditable. It does not turn unavailable provider identity into
an immutable model snapshot or allow downstream tooling to silently choose a different experiment.
