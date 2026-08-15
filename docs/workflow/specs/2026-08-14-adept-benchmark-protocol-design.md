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
- Invocation family: non-interactive `codex exec --json --ephemeral`.
- User and project configuration: ignored or replaced by a benchmark-owned configuration so each
  arm receives only its declared plugins, skills, tools, rules, and prompt.
- Approval policy: `never`; sandbox: `workspace-write`; network and GitHub credentials are identical
  across arms and scoped only to benchmark-owned repositories.
- Model settings, enabled features, environment variables, tool inventory, Codex version output,
  OS, host architecture, and container runtime are captured before each run.

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

The selected tasks form two groups of three. Every group belongs to one upstream repository and has
one declared common starting revision. #119 must prove that each issue statement remains applicable
and each pinned evaluator (including its gold patch during manifest validation) behaves correctly
from that common revision. A group that cannot satisfy all three tasks without modifying their
substance is ineligible. This constraint makes individual and campaign observations use the same
starting code rather than comparing historical SWE-bench bases with a synthetic campaign base.

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
3. **Adept** — install the pinned Adept revision. Individual prompt: `$quest <n>`. Campaign
   prompt: `$campaign <ordered-list>`.

No arm receives an oracle patch, hidden evaluator tests, another arm's transcript, or results from
an earlier repetition. Prompt bytes and resolved system/tool/plugin inventories are retained.

## Matrix, repetition, and order

The first baseline contains:

- six task cells × three arms × three repetitions = 54 individual runs; and
- two three-task campaign cells × three arms × three repetitions = 18 campaign runs.

The 72 run units execute serially. Before execution, derive one seeded, balanced order that rotates
arms across tasks and repetitions; retain the seed and complete order. The order is frozen before
the first measured run. It must not group all runs of one arm together. A smoke proof uses one
manifest task and one repetition per arm and is excluded from baseline aggregates.

Each individual run starts from its group's common revision and fresh issue/PR state. Each campaign
run starts from the same common revision and the same ordered three-issue topology. Changes may
accumulate within a campaign because that is the workflow behavior under test; no state crosses
arms or repetitions.

## Budgets and terminal outcomes

- Individual hard wall limit: 60 minutes from Codex process start.
- Individual reported-token ceiling: 250,000 total input, cached-input, output, and reasoning tokens
  according to the non-overlapping totals Codex exposes.
- Campaign hard wall limit: 180 minutes.
- Campaign reported-token ceiling: 750,000 on the same basis.
- Environment provisioning is timed separately and excluded from agent wall time.

If Codex exposes cumulative usage during execution, the runner stops at the first event over the
token ceiling. If usage is available only at termination, the run completes and is classified
`agent_budget_exhausted` when the final total exceeds the ceiling; the protocol never estimates an
unavailable live counter. Wall timeout is always enforced externally.

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

Specific evidence may refine these classes in later schemas but cannot silently convert one into
another. Missing artifacts never count as unresolved; they invalidate the run.

## Retry, reset, and cleanup

Agent outcomes are never retried. An `infrastructure_invalid` attempt permits one replacement only
after the original attempt and cause are retained. The replacement keeps the same matrix identity
with an incremented attempt number. A second infrastructure failure remains invalid.

Before every run, verify the immutable revisions, clean workspace, empty run-owned branch/PR set,
expected issue bodies, labels and dependencies, prompt digest, configuration digest, and evaluator
availability. After every run, retain evidence first, then remove or archive run-owned local state
and restore benchmark GitHub state. Cleanup failure makes the next run in that repository
ineligible until reconciliation proves a clean starting state. Never mutate an upstream challenge
repository.

## Measurements

- **Tokens:** raw input, cached-input, output, and reasoning totals exposed by Codex. Preserve null
  for unsupported fields. Dollar cost is a derived report value using a separately pinned price
  table; raw tokens remain authoritative.
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

Functional evaluation is objective and separate. A fresh reviewer context receives a normalized
patch package, repository instructions, public issue and acceptance criteria, and relevant test
results. It does not receive the arm, prompt, transcript, oracle patch, repetition, aggregate
results, or another review. Packages are shuffled under opaque identifiers.

The reviewer records material code-quality findings and a trust-boundary/security inventory using
one fixed rubric. A second human-reviewed calibration sample checks agreement before any numeric
quality or security score is treated as an aggregate. Until calibrated, the baseline publishes raw
findings, reviewer disagreements, and qualitative distributions only. The generating model never
grades its own visible output in the same context.

## AI-SPEC and evaluation plan

The users are Adept maintainers and prospective adopters. The trigger is a baseline-v1 task or
campaign cell. Inputs are a pinned public task/group, common repository revision, frozen arm prompt,
Codex configuration, and allowed tools. Output is a retained agent trajectory, repository change,
workflow terminal state, and functional result for later blinded comparison. Allowed sources are
the public task, repository, repository instructions, live benchmark-owned tracker state, and the
arm's declared workflow material. Oracle patches, hidden evaluator tests, other arms, prior
repetitions, and post-run scores are forbidden. On ambiguity the unattended agent records
`agent_needs_input` or the workflow's parked state; it does not receive an operator answer. Hard
latency and reported-token budgets are 60 minutes/250,000 for individuals and 180
minutes/750,000 for campaigns. Success is the required workflow terminal state plus the pinned
functional evaluator pass, with complete evidence.

The evaluation cases are:

- **EV-1, arm contamination (severity 5, block):** compare resolved plugin, skill, prompt, config,
  and tool inventories. Only declared workflow material may differ. Adept in a control arm or prompt
  drift fails.
- **EV-2, oracle/evaluator leakage (severity 5, block):** inspect the agent-visible filesystem,
  environment, prompt, and tools. Any reachable hidden test or oracle patch fails.
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
- **EV-8, malformed agent output (severity 4, block):** exit without required patch or terminal
  artifacts. Evidence ownership must decide `agent_error` versus `infrastructure_invalid`; a
  missing cell or inferred success fails.
- **EV-9, happy individual path (severity 4, block):** run one smoke task in every arm. Each needs a
  clean start, complete arm proof, retained evidence, and evaluator result.
- **EV-10, happy campaign path (severity 4, block):** run one smoke group in every arm. Each needs
  identical topology, isolated state, retained nested outcomes, and evaluator results.

Measurement is code-based for pins, digests, counts, timing, terminal classes, evaluator results,
and artifact completeness. Quality/security judgment remains review evidence until calibrated
against a human-reviewed sample. The smoke proof must cover EV-1 through EV-4 and EV-6 through
EV-10 before the baseline begins.

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
  before every write. Upstream remotes are read-only.
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
6. Smoke evidence covers every block-gated eval row before baseline collection.
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
