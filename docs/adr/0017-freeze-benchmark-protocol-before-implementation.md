# 0017 — Freeze the benchmark protocol before implementation

## Status

Accepted (2026-08-14)

## Context

Issue #118 must make later benchmark runs comparable before the manifest, runner, telemetry,
scoring, or baseline exists. The protocol has to choose experimental arms, versions, budgets,
repetition, failure semantics, and evidence boundaries without prematurely defining the later
components' machine interfaces. The selected `gpt-5.6-sol` identifier has no dated public model
snapshot, so a claim of bit-for-bit model reproducibility would be false even when every local
input is pinned.

## Decision

Publish one human-readable normative protocol under `docs/benchmarks/`. Freeze every controllable
input: Codex CLI, model identifier and reasoning effort, Adept revision, benchmark dataset and
evaluator revisions, prompts, arm capabilities, topology, budgets, repetitions, environment,
failure taxonomy, reset rules, and evidence requirements. Record uncontrollable service drift as
a limitation and require each run to preserve any model or service identity the harness exposes.

Keep machine-readable task manifests, run-record schemas, execution, scoring, and reports in their
existing follow-up issues. The protocol defines what those artifacts must prove, not their storage
format or implementation.

## Consequences

Later slices receive one contract against which their interfaces and results can be reviewed.
Changing a frozen value creates a new protocol version and a new baseline rather than silently
mixing observations. The first baseline cannot claim exact model-weight reproducibility, and its
report must distinguish controllable pins from service properties OpenAI does not expose.

The protocol is reviewed as prose. Repository gates may verify links and document structure, but
they do not assert normative sentences or duplicate the contract in code.

## Considered & rejected

**Add manifests and run schemas now.** Rejected because #119 and #121 own those interfaces. Adding
them before their consumers exist would couple this decision to speculative formats.

**Publish only a research memo.** Rejected because recommendations leave later runs free to choose
different arms, budgets, or failure handling and therefore do not establish comparability.

**Claim full reproducibility from the model identifier.** Rejected because the public model catalog
does not expose a dated `gpt-5.6-sol` snapshot. The protocol can pin the requested identifier and
record observed service metadata, but it cannot promise an identity the provider does not expose.
