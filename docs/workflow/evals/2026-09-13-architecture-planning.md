# Architecture planning evaluation — issue #364

The case matrix was frozen before collection: five packets in
`tests/fixtures/forge/architecture-eval-fixtures.sh`, each run once with a
baseline and revised instruction excerpt in a fresh read-only context. The
attempt cap was ten, with no retries. These are design-only probes, not
implementation or guardrail executions.

Baseline instruction revision: `283926bf8e68459ac7246c2f2cc585ece21fd158`.
Revised instruction revision: `9e8909510edd409373506296605189e7c4a055ad`.
Each variant supplied the same packet and `quest` lines 60–80, 180–215;
`spellcraft` lines 128–170, 470–500; and `oathbind` lines 25–47 from its
own revision. Line ranges select different text when those files changed;
that is the treatment. Each evaluator received only the assembled prompt,
had no prior run context, and was instructed to use no tools. The nine event
streams show only agent-message items, with no tool calls. The historical
Python packets cite pre-fix source snapshots at the parents of the document
and facade changes; no later implementation was supplied. Public source-PY1
and source-PY2 are anonymous tokens for privately verified revisions. The
private frozen prompts retain exact source identity. This privacy substitution
does not alter source facts or the paired evaluator inputs, but replaying the
public fixture is not a byte-identical reconstruction of the original prompts.

## Frozen rubric and calibration

For each response, cite the actual decision and rate five dimensions
`supported`, `missed`, or `unclear`: (1) an evidence-backed owner choice,
allowing coherent consolidation or justified retention; (2) affected-caller
migration and obsolete-path disposition; (3) public or accepted contract
preservation, or an explicit decision checkpoint; (4) focused behavioral and
structural verification; (5) no gratuitous move or unrelated cleanup. A
silent contract break or reachable missed migration fails the case. Unclear
evidence is inconclusive. No module name, prescribed sentence, or unique
layout is required.

Calibration examples shown to the operator before scoring: PY-DOC can keep
builders in `templates.py` when its scope and client caller are justified, or
rename the module when all imports migrate. CPP-CONTRACT cannot remove the
accepted `Cache::read` ABI merely to unify stale checks. SH-EXTENSION cannot
add an unneeded shared formatter or fix the unrelated deploy defect. The
operator approved this exact rubric and examples on 2026-09-13 before scoring;
the campaign's private approval record retains the decision provenance.

## Collection and cost

Codex CLI 0.154.0, `gpt-5.6-sol`, medium reasoning, ephemeral read-only
context. Nine runs completed and one yielded no decision; all ten attempts
are counted. For the nine completions, the CLI reported 215,995 input tokens
(99,712 cached) and 6,924 output tokens (3,454 reasoning). The interrupted
attempt has no usage report, so aggregate token cost is a lower bound.
Elapsed times are wall-clock seconds; no pricing claim is made.

| Case | Baseline | Revised | Collection result |
|---|---:|---:|---|
| PY-DOC, historical document owner | interrupted after >30 min, no output | 27.74 s | baseline inconclusive |
| PY-FACADE, historical reusable API | 30.63 s | 23.02 s | both completed |
| RS-POLICY, duplicated status rule | 22.32 s | 42.59 s | both completed |
| CPP-CONTRACT, stale rule and protected ABI | 25.38 s | 34.57 s | both completed |
| SH-EXTENSION, clean extension and unrelated cleanup | 24.84 s | 29.89 s | both completed |

The unscored response facts are:

| Case | Baseline response | Revised response |
|---|---|---|
| PY-DOC | No response. | Kept document building in `templates.py`; named the client operation as a caller but its file was absent from the packet; requested schema and public-path checkpoints. |
| PY-FACADE | Added `api.py` as facade; kept `client.py` as implementation/transport owner; migrated the known test; checkpointed the old import path. | Made the same facade choice and proposed a conditional type-only `httpx` change in `client_contracts.py`; checkpointed old-path compatibility. |
| RS-POLICY | Proposed one internal policy function, a public API adapter, jobs predicate removal, and HTTP/worker coverage; checkpointed the status representation. | Proposed the same ownership and caller migration, plus a private module declaration; checkpointed public or persisted status representation. |
| CPP-CONTRACT | Proposed Loader as sole stale-rule owner, retained the Cache ABI, accounted for Refresh, and checkpointed grace semantics. | Made the same owner and ABI decision, with explicit boundary/zero-grace and Refresh tests; checkpointed grace semantics. |
| SH-EXTENSION | Extended `report.sh`, retained collection/text paths, excluded deploy cleanup, and checkpointed the JSON schema; also listed a design document. | Extended `report.sh`, retained collection/text paths, excluded deploy cleanup, and checkpointed the JSON schema. |

No evaluator performed a caller search or an implementation, and each
proposed migration is therefore unverified. The PY-DOC baseline absence
remains a failed collection arm.
The Python packets deliberately hide the full source snapshot and omit actual
caller maps. The cited pre-fix repositories have additional direct callers
beyond those named in the packets. Their answers can be assessed for a
discovery-and-migration plan, but actual migration completeness must be
`unclear`; absence of a named missed caller is not proof of completeness.
Adding caller maps now would change a frozen input and belongs to a separate
evaluation, not a silent repair of these ten runs.

## Calibrated assessment

Ratings follow the five frozen dimensions in order: ownership, caller/path
migration, protected contracts, verification, and avoiding gratuitous or
unrelated changes. `S` means supported by the response, `U` unclear; the
interrupted arm has no ratings. These are plan assessments, not implemented
behavior. No response disclosed a silent contract break or a missed named
synthetic caller.

| Case | Variant | Ratings | Assessment and observable limit |
|---|---|---|---|
| PY-DOC | baseline | — | Inconclusive: no response after interruption. |
| PY-DOC | revised | S/U/S/S/S | It kept document builders together, named the client caller, and checkpointed unknown XML/public contracts; the packet hides the actual caller map. |
| PY-FACADE | baseline | S/U/S/S/S | It proposed an API facade while retaining client implementation and checkpointing the old import path; complete migration cannot be checked. |
| PY-FACADE | revised | S/U/S/S/U | Same core choice; a conditional `httpx` change could be necessary for import isolation but lacks evidence here, so extra-scope risk remains unclear. |
| RS-POLICY | baseline | S/S/S/S/S | One internal rule, public adapter, jobs predicate removal, and HTTP/worker coverage; it checkpointed status representation. |
| RS-POLICY | revised | S/S/S/S/S | Same owner and migration; also named the private module declaration and status-contract checkpoint. |
| CPP-CONTRACT | baseline | S/S/S/S/S | One Loader rule, Cache ABI retained, Refresh accounted for; grace semantics checkpointed. |
| CPP-CONTRACT | revised | S/S/S/S/S | Same owner and ABI choice, with explicit boundary and Refresh checks; grace semantics checkpointed. |
| SH-EXTENSION | baseline | S/S/S/S/S | Extended the existing formatter, kept text/collection paths, excluded deploy cleanup, and checkpointed JSON shape. |
| SH-EXTENSION | revised | S/S/S/S/S | Made the same owner and exclusion choices, without a shared formatter; JSON shape checkpointed. |

The four complete baseline/revised pairs support the same principal ownership
choices. This bounded run shows no measured planning improvement from the
revised excerpts. Python migration completeness and the unmatched PY-DOC
baseline prevent a stronger conclusion; neither missing evidence nor a
checkpoint is scored as a successful implementation.

The first PY-DOC baseline invocation emitted its prompt but no model response,
kept an HTTPS connection open, and was interrupted. The cause is unverified.
No output file, event stream, timestamped run record, or token accounting
exists for it. Its duration and the no-retry claim rest on contemporaneous
operator observation and cannot be independently reconstructed. Later
attempts kept the
model, prompt construction, and settings unchanged, with a 180-second timeout
to bound a recurrence; none timed out. This does not restore a matched PY-DOC
outcome. Raw prompts, event streams, and outputs were retained in private
scratch during the run; they are not part of the plugin.

## Limits and future cases

The packets are compact excerpts, not whole repositories. Historical source
facts were checked against the private pre-fix commits; the evaluator saw only
those facts, not complete files or later repairs. Plans cannot demonstrate
working migrations, so implementation guardrails were not exercised in the
ten model contexts. Repository `just verify` checks shell/structural rules,
public-safety patterns, and fixture repeatability; it does not validate model
decisions or historical claims. One model, one harness, and one attempt per cell do not
support a population-level quality estimate.

A future Mending repair may enter this matrix only after its defect, triggering
pre-repair source commit, affected callers, protected contracts, and verified
post-repair outcome are recorded. Build the evaluator packet from the
pre-repair snapshot, keep the repair and later history outside both contexts,
freeze the budget and rubric, and score multiple defensible plans against the
observable contracts. That intake is documentation, not an automatic feed.
