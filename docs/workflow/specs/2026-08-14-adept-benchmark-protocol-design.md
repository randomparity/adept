# Freeze the Adept benchmark protocol

Issue: #118

## Goal

Publish the normative protocol that the remaining #117 sub-issues use to build and run the first
comparison of bare-agent, generic-workflow, and Adept issue-to-PR and campaign workflows.

## Scope and authority

The frozen scope is issue #118 annotation token `60eb5d9b-b6a7-460e-99ca-459419f51d0e`.
Issue #118 supplies the outcome and required dimensions. The operator selected Codex CLI with
`gpt-5.6-sol`, then approved the architecture, execution and failure semantics, measurements,
budgets, and review rules on 2026-08-14.

Permitted surface is a benchmark protocol under `docs/benchmarks/`, this specification, ADR 0017,
an implementation plan, and directly necessary structural documentation checks. Model/provider
comparison, private or Adept-authored tasks, the task manifest, runner, run-record schema, scoring
implementation, baseline execution, hosted presentation, and Adept optimization are excluded.

## Governing decision

[ADR 0017](../../adr/0017-freeze-benchmark-protocol-before-implementation.md) freezes controllable
benchmark inputs in one normative document and records provider drift honestly. Machine interfaces
remain owned by #119 through #123.

## Artifact and ownership

Create `docs/benchmarks/adept-workflow-v1.md`. It is the sole normative protocol for baseline v1.
The specification explains why the contract has this shape; the protocol carries the values a run
must obey. A later incompatible change creates a new versioned protocol and baseline rather than
editing the meaning of completed v1 results.

The protocol contains these sections:

- purpose, claims, and non-claims;
- immutable and observed pins;
- dataset and campaign-group eligibility;
- three arm definitions with exact prompt templates;
- execution matrix, repetition, ordering, and isolation;
- budgets and terminal classifications;
- measurement definitions;
- functional and blinded review boundaries;
- evidence, invalidation, retry, reset, and cleanup;
- smoke proof and first-baseline acceptance criteria.

The document cites immutable upstream revisions and official public documentation. It does not add
a parser or schema. #119 and #121 must choose formats that represent the protocol without weakening
it.

## Frozen inputs

### Agent harness

- Codex CLI package: `@openai/codex` version `0.147.0`, the stable npm release observed and locally
  verified on 2026-08-14.
- Model identifier: `gpt-5.6-sol`.
- Reasoning effort: `medium`.
- Adept source revision: `3d74a47dfc7091f9f683c8c2119ba1648dfef821`.
- Invocation family: non-interactive `codex exec --json --ephemeral`.
- Invocation also uses `--ignore-user-config`, `--ignore-rules`, `--strict-config`, and a fresh
  parent-only benchmark-owned `CODEX_HOME`. The only configuration values are
  `model = "gpt-5.6-sol"`,
  `model_reasoning_effort = "medium"`, `approval_policy = "never"`, and
  `sandbox_mode = "workspace-write"`, with `sandbox_workspace_write.network_access = true`.
  The path-scoped egress proxy remains authoritative; this setting grants no undeclared route.
- Enabled Codex features are `multi_agent`, `plugins`, `skill_search`, `shell_tool`,
  `unified_exec`, and `view_image`; every other feature reported by the pinned CLI is disabled.
- Approval policy: `never`; sandbox: `workspace-write`; network and GitHub credentials are identical
  across arms and scoped only to benchmark-owned repositories.
- Built-in capabilities in every arm: local shell execution and stdin, patch editing, local image
  inspection, and Codex agent collaboration. No MCP server, app connector, interactive browser,
  external memory, or undeclared plugin is available.
- Shell-visible commands are the benchmark repository's pinned build tools plus benchmark-pinned
  `git`, `gh`, container runtime, language toolchain, and package manager versions. Preflight
  records their paths and versions and rejects additions or mismatches.
- Agent-spawned process destinations are path-scoped benchmark-owned GitHub repository and API
  routes and a benchmark-owned mirror of dependency artifacts frozen from the common revision's
  manifests before oracle-backed validation. The mirror records immutable paths and
  digests and exposes no index, search, latest-version, task-package, source-distribution, or
  documentation discovery route. An egress proxy rejects task upstreams, public registries,
  external documentation, general GitHub search, later commits, pull requests, issue discussions,
  and all undeclared routes during agent execution. GitHub writes are limited to run-owned
  branches, issues, pull requests, comments, labels, and permitted campaign merges.
- Every agent-spawned process runs in an externally enforced default-deny network namespace whose
  only network path is the benchmark proxy. Direct model transport, DNS, Internet, host-network,
  and alternate-proxy routes are absent; the harness owns model transport outside the namespace.
  Model credentials and model-service proxy routes are absent from child environments. Freeze and
  digest the namespace, firewall, proxy, credential, and DNS configuration before smoke.
- The harness-side Codex process owns credential-bearing `CODEX_HOME` and model transport in a
  parent mount/environment namespace not mounted into the tool sandbox. Every model-directed
  process receives a different empty credential-free `CODEX_HOME`; its environment allowlist
  strips `OPENAI_API_KEY`, model bearer tokens, parent proxy values, parent `CODEX_HOME`, and every
  resolved model-auth source. Only separately scoped benchmark GitHub and route-proxy credentials
  remain.
  Freeze and digest both namespace views and the child allowlist before smoke.
- Model settings, enabled features, environment variables, tool inventory, Codex version output,
  OS, host architecture, and container runtime are captured before each run.

The Adept plugin must be built or installed from that Git commit. Preflight resolves the source
checkout to the full commit, verifies a clean tree, and records a digest of the installed plugin
tree. A revision or digest mismatch invalidates the run before Codex starts.

The Adept arm's only capability delta is the pinned Adept plugin and its skill instructions. The
bare and generic arms load no plugin. The resolved tool names, command versions, destinations,
credentials, configuration, and plugin trees must match this allowlist before every run; capturing
an unexpected capability does not make it valid.

Every task repository receives this exact common instruction overlay, encoded as UTF-8 with LF
line endings:

> You are running a public code challenge in a benchmark-owned fork. Follow repository
> instructions and work only on the stated issue or issues. Do not seek or inspect oracle patches,
> hidden evaluator tests, other runs, or benchmark results. Task upstreams are unavailable. Mutate
> only run-owned state in the benchmark-owned repository. This run is unattended; if a necessary
> product decision cannot be sourced, request input and stop. Stay within the provided wall and
> token budgets.

Preflight compares the overlay bytes and configuration against protocol-owned SHA-256 digests.
Repository-native instructions remain task input and are preserved unchanged in every arm.

OpenAI's model catalog exposes `gpt-5.6-sol` but no dated snapshot. The identifier is a controlled
request value, not proof of fixed server weights. Any response/service fingerprint exposed by
Codex is retained; absence is reported as unavailable. Results claim protocol reproducibility, not
bit-identical model behavior.

### Public task source and evaluator

- Dataset: `SWE-bench/SWE-bench_Verified`, test split, pinned Hugging Face revision
  `03e151cf5560b1af6a4363c6a9d766deaaea6b56`.
- Evaluator: `SWE-bench/SWE-bench` pinned revision
  `128cbd1a5759694874e6bd56624cb2fd6fb079e2`.
- Functional evaluation uses the pinned repository's Docker harness, with image identifiers or
  digests retained by each run.
- #119 selects exactly six public instances and records each upstream license, issue URL,
  repository, original base commit, tests, and adaptation evidence.

#119 enumerates the pinned test split by ascending `instance_id` and retains a candidate ledger.
It excludes non-public repositories; licenses outside `MIT`, `BSD-2-Clause`, `BSD-3-Clause`,
`Apache-2.0`, `ISC`, `Python-2.0`, and `PSF-2.0`; unavailable pinned evaluator images; tasks
without reproducible tests; and tasks whose public issue author or SWE-bench contribution author
has GitHub login `randomparity`. Authorship uses exact GitHub-login equality; unavailable identity
evidence excludes the task. Every exclusion records its rule and source evidence before any arm
is run.

For each repository in lexical order, #119 enumerates every three-element combination of eligible
instances. Sort each combination's IDs lexically, then sort combinations by the tuple
`(first_id, second_id, third_id)`. Candidate common revisions are the combination's distinct full
original-base SHAs in lexical order; timestamps play no role. Install the unchanged issue bodies
in the benchmark tracker. Test every task independently from a clean candidate checkout: require
`git apply --check` and `git apply` for its gold patch without edits, fuzz, or conflict resolution;
require at least one `FAIL_TO_PASS` test to fail before the patch; and require all `FAIL_TO_PASS`
and `PASS_TO_PASS` tests to pass after it under the pinned evaluator. Restore the candidate before
the next task. The first revision satisfying these rules for all three tasks is that combination's
qualifying revision. Select the first two qualifying
repository-disjoint combinations. Freeze and publish the manifest plus the complete accepted and
rejected ledger before smoke or measured arm output is observed. If fewer than two groups qualify,
#119 reports the shortfall and changes this protocol before selecting discretionarily.

The selected tasks form two groups of three. Every group belongs to one upstream repository and has
one declared common starting revision. #119 must prove the pre-patch failure, exact gold-patch
application, and post-patch evaluator result for every task from that revision. A group that cannot
satisfy all three tasks mechanically without modifying their issue bodies or patches is ineligible.
This constraint makes individual and campaign observations use the same starting code rather than
comparing historical SWE-bench bases with a synthetic campaign base.

Agent-visible task material is limited to the unchanged public issue body and repository files,
tests, and instructions reachable at the common revision. Freeze and digest that set before any
oracle-backed validation. It must not include or derive names, bodies, criteria, or hints from a
gold patch, SWE-bench test patch, `FAIL_TO_PASS` or `PASS_TO_PASS` metadata, hidden evaluator test,
or validation result.

## Experimental arms

All arms receive the same benchmark-owned repository instructions, issue bodies, acceptance tests,
credentials, tool inventory, starting revision, budgets, and authorization to create branches,
  commits, pull requests, and—for campaign runs only—merge verified work inside the
  benchmark-owned repository. Upstream repositories are read-only. Arm identity changes only the
  workflow input:

1. **Bare agent** — no Adept plugin or workflow prompt. Individual prompt: `Resolve issue #<n> in
   this repository. Drive the change to a tested, committed, CI-green pull request ready to merge.`
   Campaign prompt: `Resolve issues <ordered-list> in this repository. Process the complete batch,
   keep each change tested, and leave every issue closed by a verified merge or clearly classified
   with its blocking reason.`
2. **Generic workflow** — no Adept plugin. Append this fixed checklist to the corresponding bare
   prompt: `Inspect repository instructions and the live issue before changing files. State the
   acceptance criteria, work on a feature branch, test the intended behavior and error paths,
   review the complete diff, run repository guardrails, create a pull request, and verify required
   checks and mergeability. For a batch, track dependencies explicitly and do not let one
   issue-local blocker stop unrelated work.`
3. **Adept** — install Adept revision
   `3d74a47dfc7091f9f683c8c2119ba1648dfef821` and verify it as specified above. Individual prompt:
   `$quest <n>`. Campaign prompt: `$campaign <ordered-list>`.

No arm receives an oracle patch, hidden evaluator tests, another arm's transcript, or results from
an earlier repetition. Prompt bytes and resolved system/tool/plugin inventories are retained.

## Matrix, repetition, and order

The first baseline contains:

- six task cells × three arms × three repetitions = 54 individual runs; and
- two three-task campaign cells × three arms × three repetitions = 18 campaign runs.

The 72 run units execute serially. Define a block as one mode/cell/repetition and its three arm
runs. Canonical block IDs are `<mode>/<cell-id>/<repetition>`, with repetitions numbered 1 through
3. The schedule seed is the lowercase SHA-256 digest of the frozen manifest bytes. Sort blocks by
`SHA-256("adept-v1-order" + NUL + seed + NUL + block-id)`, breaking an impossible digest tie by
block ID. For each block, let `i` be its zero-based rank among sorted blocks of the same mode. Run
arms in the cyclic order beginning at `i mod 3` over `[bare, generic, adept]`. Thus each arm occurs
first, second, and third equally within each mode's six or two cells across three repetitions.
Retain the manifest digest and full schedule before smoke starts; do not regenerate it after any
outcome.

The smoke proof contains six serial units: the lexically first task in the first selected manifest
group in each arm, followed by that group in each arm. Arm order is `[bare, generic, adept]` for
both modes. Smoke uses fresh repetitions of baseline-eligible inputs, is excluded from aggregates,
and does not expose its transcripts or outcomes to later runs.

Each individual run starts from its group's common revision and fresh issue/PR state. Each campaign
run starts from the same common revision and the same ordered three-issue topology. Changes may
accumulate within a campaign because that is the workflow behavior under test; no state crosses
arms or repetitions.

The campaign issue order is the selected combination's ascending lexical `instance_id` order.
The manifest, materialized tracker, prompt ordered list, and topology digest must preserve that
order before smoke starts.

Each campaign repository starts with exactly three open issues, numbered `#1`, `#2`, and `#3` in
that lexical order, each labelled exactly `type:bug`, `priority:P2`, `status:ready`,
`risk:night-watch`, and `effort:M`. They have no dependency, parent, sub-issue, milestone, project,
assignee, linked branch, linked pull request, comment, or reaction; no other issue is visible. The
prompt list is `1,2,3`. The topology digest and preflight cover the complete presence and absence
contract.

The agent-visible repository is a benchmark-owned sanitized Git repository whose object graph and
refs end at the common starting revision. It has no alternate object store, upstream remote, later
commit object, pull-request ref, reflog entry, or gold-patch object. Provisioning verifies this
boundary before launch.

For a campaign, retain the merge commit for each task and evaluate that task at that commit. This
is its nested functional result. After the last task, replay every task evaluator at final campaign
HEAD and retain those results separately. A campaign is `resolved` only when every issue reached
its required merged state and every evaluator passes at final HEAD. A later regression does not
rewrite the historical nested result, but it makes the campaign `unresolved`.

## Budgets and terminal outcomes

- Individual hard wall limit: 60 minutes from Codex process start.
- Individual reported-token ceiling: 250,000 billable tokens under the formula below.
- Campaign hard wall limit: 180 minutes.
- Campaign reported-token ceiling: 750,000 on the same basis.
- Environment provisioning is timed separately and excluded from agent wall time.

The authoritative usage record is the latest cumulative Codex usage event. Billable tokens equal
`input_tokens + output_tokens`. Cached-input tokens are a subset of input tokens, and reasoning
tokens are a subset of output tokens; retain both as breakdowns but never add them again. Before
baseline execution, the smoke proof must demonstrate that the pinned CLI emits both additive
fields as non-negative integers. A missing, partial, decreasing, or malformed usage record is an
`infrastructure_invalid` telemetry failure, not permission to run without the ceiling.

The runner stops at the first cumulative record over the token ceiling. If cumulative usage is
available only at termination, the run completes and is classified `agent_budget_exhausted` when
the final total exceeds the ceiling. Wall timeout is always enforced externally.

Every launched run reaches exactly one terminal class:

- `resolved` — required workflow terminal state and pinned functional evaluator pass;
- `unresolved` — agent completed but the evaluator did not resolve the task;
- `agent_timeout`;
- `agent_budget_exhausted`;
- `agent_refusal`;
- `agent_needs_input` — the unattended run requested a decision it could not make;
- `agent_parked` — a workflow deliberately recorded a blocker or human handoff short of the
  required terminal state;
- `agent_error` — the agent process failed independently of benchmark infrastructure; or
- `infrastructure_invalid` — setup, pin, credential, harness, evaluator, capture, or cleanup
  failed, so the observation cannot compare agent behavior.

Apply this precedence to independently retained process and harness evidence; the first matching
row wins:

| Order | Evidence | Terminal class |
| --- | --- | --- |
| 1 | Harness-owned or unknown-ownership failure | `infrastructure_invalid` |
| 2 | External wall timer fired before Codex exited | `agent_timeout` |
| 3 | Authoritative usage first exceeded its ceiling | `agent_budget_exhausted` |
| 4 | Healthy capture shows failed process or malformed/missing agent output | `agent_error` |
| 5 | Agent explicitly declines the authorized task | `agent_refusal` |
| 6 | Agent asks for a benchmark-operator decision needed to continue | `agent_needs_input` |
| 7 | Agent records another blocker or deliberate handoff | `agent_parked` |
| 8 | Mode-specific required state and every applicable final evaluator pass | `resolved` |
| 9 | Any other healthy, completed observation | `unresolved` |

Harness-owned failures include setup, evaluator, credential, capture, cleanup, and usage telemetry
failures. Failed Codex processes include nonzero exits and crashes. Unknown ownership means the
evidence cannot distinguish an agent failure from a harness or capture failure.

A repository state produced before a timeout or budget breach does not override the resource
terminal class. A refusal is an explicit rejection, not a request for information. An input request
wins over a workflow's simultaneous parked marker; `agent_parked` covers blockers that do not ask
the benchmark operator to decide. Ties between a wall event and usage event resolve as timeout.

For an individual, required state is a tested committed pull request with all required checks
passing and GitHub reporting it mergeable; merging it is forbidden and unnecessary. Its pinned
evaluator must pass on pull-request HEAD. For a campaign, every issue must be closed by its verified
merge and all three evaluators must pass at final campaign HEAD.

The harness-health record is written outside the agent process and includes process exit, capture
continuity, disk-write result, and artifact-validation result. Later schemas may refine evidence
without changing this precedence. Missing artifacts never count as unresolved or inferred success.

## Retry, reset, and cleanup

Agent outcomes are never retried. An `infrastructure_invalid` attempt permits one replacement only
after the original attempt and cause are retained. The replacement keeps the same matrix identity
with an incremented attempt number. Insert it immediately after the invalid attempt and before the
next nominal smoke or baseline unit; never reorder later nominal units. Retain the expanded attempt
schedule as it grows. A second infrastructure failure remains invalid.

Before every run, verify the immutable revisions, clean workspace, empty run-owned branch/PR set,
expected issue bodies, labels and dependencies, prompt digest, configuration digest, and evaluator
availability. After every run, retain evidence first, then remove or archive run-owned local state
and restore benchmark GitHub state. Cleanup failure makes the next run in that repository
ineligible until reconciliation proves a clean starting state. Never mutate an upstream challenge
repository.

## Measurements

- **Tokens:** raw cumulative input and output totals exposed by Codex, plus cached-input and
  reasoning breakdowns. The additive budget total is input plus output only. Preserve null for an
  unsupported breakdown; the two additive fields are mandatory. Dollar cost is derived using a
  separately pinned price table; raw tokens remain authoritative.
- **Wall time:** monotonic time from agent process start to terminal outcome. Provisioning,
  functional evaluation, and cleanup are separate durations.
- **Generated code and design documentation:** added and deleted lines in the final diff, classified
  by a manifest-owned path/extension map. Renames are separate. Generated dependencies, lockfiles,
  tests, and other text remain visible rather than being folded into code or design docs.
- **User interactions:** agent requests for a benchmark-operator decision after launch. Tool calls,
  worker messages, and approval-policy events are separate counters.
- **Functional result:** the pinned SWE-bench evaluator result, plus issue/PR terminal state
  required by the mode.
- **Task view:** one task/repetition is one observation. Campaign task outcomes remain nested under
  their campaign observation and are not treated as independent campaign samples.
- **Campaign view:** one three-task batch/repetition is one observation.

All aggregates retain denominators and show invalid, missing, and terminal-class counts. The report
does not drop failed cells or pool individual and campaign observations.

## Blinded quality and security/reliability review

Functional evaluation is objective and separate. Every measured attempt with a readable patch and
candidate tree produces exactly one qualitative-review package and gets one fresh reviewer context
with no earlier package or review. An individual package contains its frozen issue body. A campaign
package contains all three frozen issue bodies in campaign order plus nested and final test results.

The label-blinded package contains the patch; a read-only snapshot made by applying that patch to
the pre-validation frozen common-revision tree; the applicable frozen issue body or bodies and
repository instructions; and relevant agent-visible test results. The snapshot contains no Git
metadata or material outside the frozen agent-visible set and candidate patch. No separate
acceptance-criteria artifact is allowed. It does not receive the arm, prompt, transcript, oracle
patch, repetition, aggregate results, or another review. Packages are shuffled under opaque IDs.

A measured agent attempt without a readable patch or candidate tree remains in the qualitative
denominator as `not_reviewable`, with its terminal class and missing-artifact reason. It receives no
score and is never imputed as clean or zero-quality. An `infrastructure_invalid` attempt remains in
the invalid-attempt denominator and is not a qualitative observation; its replacement is classified
independently. Smoke is excluded from qualitative baseline aggregates.

Normalization changes metadata only: it replaces run, arm, branch, commit-author, and pull-request
identifiers with opaque values and normalizes timestamps. It never removes or rewrites substantive
patches, tests, design records, comments, or filenames, even when they reveal workflow style. Each
package retains source and normalized digests plus a machine-readable transformation log. Before
scoring, the reviewer records an arm guess and confidence. The report publishes guess accuracy and
confidence distributions and describes the exercise as label-blinded, not fully arm-blinded.

The reviewer records material code-quality findings and a trust-boundary/security inventory using
one fixed rubric. A second human-reviewed calibration sample checks agreement before any numeric
quality or security score is treated as an aggregate. Until calibrated, the baseline publishes raw
findings, reviewer disagreements, and qualitative distributions only. The generating model never
grades its own visible output in the same context.

Before smoke output, #122 freezes and publishes the rubric bytes/digest, Codex and model versions,
reviewer prompt/config/tools/network, package builder, normalization rules, and human instructions.
The primary reviewer is Codex CLI `0.147.0`, `gpt-5.6-sol`, reasoning `medium`, one fresh read-only
context per package, and no network. Calibration selects one package in every arm, mode, and
repetition stratum. Choose the smallest lexical digest of
`SHA-256("adept-v1-calibration" + NUL + manifest-digest + NUL + canonical-matrix-id)`, where the
matrix ID is `<mode>/<cell-id>/<arm>/<repetition>`; neither package digest participates. One
arm-blinded human independently applies the same four-item ordinal 0-3 rubric: correctness risk,
maintainability, test quality, and security/reliability. For each dimension, compute linearly
weighted Cohen's kappa over its 18 pairs with weight `1 - abs(primary - human) / 3`. A dimension
permits a numeric aggregate only at `kappa >= 0.60`; otherwise it publishes raw findings and
disagreements. Publish matrix IDs, selection digests, both score sets, all four statistics, and the
threshold. Fewer than 18 reviewable packages permits no numeric qualitative aggregate.

## AI-SPEC and evaluation plan

The users are Adept maintainers and prospective adopters. The trigger is a baseline-v1 task or
campaign cell. Inputs are a pinned public task/group, common repository revision, frozen arm prompt,
Codex configuration, and allowed tools. Output is a retained agent trajectory, repository change,
workflow terminal state, and functional result for later blinded comparison. Allowed sources are
the public task, repository, repository instructions, live benchmark-owned tracker state, and the
arm's declared workflow material. Oracle patches, hidden evaluator tests, other arms, prior
repetitions, and post-run scores are forbidden. On ambiguity the unattended agent requests input
and is classified `agent_needs_input`; a blocker that requires no operator decision is
`agent_parked`. It does not receive an operator answer. Hard
latency and reported-token budgets are 60 minutes/250,000 for individuals and 180
minutes/750,000 for campaigns. Success is the required workflow terminal state plus the pinned
functional evaluator pass, with complete evidence.

The evaluation cases are:

- **EV-1, arm contamination (severity 5, block):** compare resolved plugin, skill, prompt, config,
  and tool inventories. Only declared workflow material may differ. Adept in a control arm or prompt
  drift fails.
- **EV-2, oracle/evaluator leakage (severity 5, block):** inspect the agent-visible filesystem,
  environment, prompt, tools, task-material digest, Git object graph, refs, dependency mirror, and
  egress proxy. Any oracle-derived acceptance hint, hidden test, gold patch, later upstream object
  or ref, later task package, fix pull request, fix discussion, or discovery route fails. Live
  direct-IP, DNS, host-network, alternate-proxy, model-service, model-credential, upstream,
  registry, and general-GitHub probes must fail while declared child-process proxy routes succeed.
  A representative model-directed process must fail to read the resolved parent auth source,
  parent `CODEX_HOME`, `auth.json`, or common model-credential variables; its empty child
  `CODEX_HOME` must contain no credential.
- **EV-3, upstream mutation or excessive credentials (severity 5, block):** run smoke with audited
  repository and token targets. Writes outside benchmark-owned state or broader credentials fail.
- **EV-4, cross-run state reuse (severity 4, block):** seed one dirty branch, PR, issue label, and
  workspace artifact. Preflight must reject the run; proceeding or hiding residue fails.
- **EV-5, ambiguous task (severity 4, warn):** supply a task requiring an unsourced product
  decision. The unattended run requests input or parks. A harness-provided answer fails.
- **EV-6, stale or conflicting task data (severity 4, block):** make the manifest revision disagree
  with the issue or repository. The run must invalidate before agent start.
- **EV-7, cost or loop escape (severity 4, block):** exceed wall or reported-token budget. The run
  must preserve partial evidence and use the correct terminal class.
- **EV-8, malformed agent output (severity 4, block):** exercise agent-owned malformed output,
  capture interruption, and an unknown-cause missing artifact. The attribution table must yield
  `agent_error`, `infrastructure_invalid`, and `infrastructure_invalid`, respectively; a missing
  cell or inferred success fails.
- **EV-9, happy individual path (severity 4, block):** run one smoke task in every arm. Each needs a
  clean start, complete arm proof, retained evidence, and evaluator result.
- **EV-10, happy campaign path (severity 4, block):** run one smoke group in every arm. Each needs
  identical topology, isolated state, retained nested outcomes, and evaluator results.

Measurement is code-based for pins, digests, counts, timing, terminal classes, evaluator results,
and artifact completeness. Quality/security judgment remains review evidence until calibrated
against a human-reviewed sample.

The six smoke run units cover the live path for EV-1 through EV-3, EV-9, and EV-10. A separate
bounded protocol-validation suite uses harness fixtures and does not invoke the model: dirty state
for EV-4, conflicting pins for EV-6, synthetic wall and usage events for EV-7, and three synthetic
process/capture records for EV-8. These fixtures are validation cases, not run units or replacement
attempts. EV-5 remains a non-blocking design review case. Evidence for every applicable EV row and
all six smoke units must pass before the baseline begins.

## Threat model

### Boundaries and actors

- Public issue, repository, and dataset content crosses from upstream authors into a tool-using
  Codex process.
- Model-directed commands cross into local workspaces and benchmark-owned GitHub repositories.
- GitHub and model credentials cross from the benchmark operator into the harness.
- Agent patches cross into the pinned Docker evaluator.
- Retained transcripts and diffs cross into blinded reviewers and the public report.

Actors are upstream repository contributors, public issue commenters, the model, benchmark
operators, GitHub, OpenAI's model service, and the pinned evaluator containers. Upstream content and
model output are untrusted. The operator controls the manifest and credentials. GitHub and OpenAI
are external trusted dependencies for their declared services, not sources of benchmark scope.

### Controls

- Treat public prose as task evidence, never benchmark instructions; frozen prompts and repository
  policy retain authority.
- Use benchmark-owned forks/issues with least-privilege credentials and validate repository identity
  before every write. Task-upstream routes are blocked during agent execution.
- Run Codex in an isolated workspace-write sandbox and the evaluator in its pinned Docker boundary;
  preserve resource/time limits and never expose oracle material to the agent container.
- Pass subprocess inputs as arguments or files, never interpolated shell programs; validate paths
  under run-owned roots.
- Redact credentials and private environment values from retained/public artifacts while preserving
  non-secret configuration digests and failure classifications.
- Bound retries to one infrastructure replacement and require evidence retention before cleanup.

Out of scope are a malicious GitHub or OpenAI service, compromise of the host/container runtime,
and security of upstream project code unrelated to its execution inside the benchmark sandbox.
Those are platform risks rather than claims this protocol can discharge; the report must disclose
the trusted services and environment.

## Acceptance criteria

1. `docs/benchmarks/adept-workflow-v1.md` contains every frozen value and rule in this specification
   without a placeholder or conflicting interpretation.
2. The protocol distinguishes immutable pins, observed metadata, and unavailable provider identity.
3. Matrix arithmetic is 54 individual plus 18 campaign run units, and every unit has one of the
   declared terminal classes or a retained infrastructure-invalid attempt.
4. Dataset eligibility requires two three-task common-revision groups and gold/evaluator validation
   before baseline execution.
5. Exact arm prompts and resolved inventories make contamination reviewable.
6. Six smoke units and the separate protocol-validation suite cover every block-gated eval row
   before baseline collection.
7. Existing structural and public-safety guardrails pass. No automated check asserts prose wording.

## Verification and rollback

Self-review maps each approved design statement to the protocol. Adversarial review challenges the
ADR, specification, plan, and final diff. `just shape-check`, `just public-safety`, `just records`,
and `just verify` provide structural, privacy, record, and repository-wide checks. A fresh reviewer
performs the block-row protocol simulation because repository anatomy rule 4 forbids a test that
asserts Markdown wording.

Rollback reverts the protocol, specification, plan, and ADR commits together before any baseline-v1
run. Once a baseline cites v1, corrections create a new protocol version so published evidence does
not change meaning retroactively.
