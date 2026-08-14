# Security review lifecycle design

Issue: #42

## Goal and authority

Give standalone `$detect-evil` findings the same fixed, rejected-with-evidence,
deferred-with-record, or blocked lifecycle and the same bounded iteration contract as other review
findings. The frozen authority is issue #42's `WORK:SCOPE` annotation with token
`F29B8DA3-15FF-4DDC-8878-C9C7CC58D7A8`; the operator approved the reviewer-selector design.

The permitted implementation surface is `skills/trial-loop/SKILL.md`,
`skills/detect-evil/SKILL.md`, their directly coupled fixtures and tests, and these design records.
No second reviewer implementation, disposition vocabulary, or unrelated workflow change is in
scope.

## Design

`$trial-loop` accepts `--reviewer gauntlet|detect-evil` once anywhere before the line-anchored
`CHARTER` block. Omission selects `gauntlet`; `detect-evil` is the only accepted alternate. A
missing value, unknown name, or duplicate selector stops before dispatch with an actionable input
error. Parsing first splits the invocation at the first line-anchored `CHARTER` label, preserving
that block as focus, then parses selectors only in the pre-charter prefix. Consequently a
`--reviewer` immediately before the charter has no value; it cannot consume the `CHARTER` token or
discard the frozen authority. The selector belongs to the loop, so it is removed before target
classification, target-and-flag hashing, default-target resolution, and forwarding. This keeps an
explicitly selected gauntlet run artifact-compatible with the same invocation that omits the
selector.

After selection, one local term, `reviewer`, names `$gauntlet` or `$detect-evil`. Every pass invokes
that reviewer with the existing `--json --out <findings-path>` contract and the unchanged trailing
`CHARTER` block. Both reviewers share target parsing and file output because `$detect-evil` already
delegates those contracts to `$gauntlet`. The loop continues to validate the compact object, read
the artifact, compare run IDs, surface suppressions, and apply `heed-counsel` before recording
exactly one of `accepted-fixed`, `rejected-with-evidence`, `deferred-tracked`, or `blocked` for each
finding.

The existing five-iteration cycle, two-rescope ceiling, malformed-return retry, silent-worker
recovery, convergence-with-deferrals exit, working-tree commit timing, and deferral-record format do
not branch by reviewer. Reviewer-specific prose remains only where behavior differs: gauntlet's
broad adversarial purpose and accepted-ADR discussion, and detect-evil's trust-boundary inventory.
The loop's terminal report names the selected reviewer and uses neutral `review iteration` wording.

`$detect-evil` remains a read-only one-pass reviewer. Its caller section gains the canonical
standalone settled-state route: invoke `$trial-loop --reviewer detect-evil <target and focus>` when
the caller wants iteration and disposition. Direct `$detect-evil` still returns its checkpoint and
does not fix findings, write debt records, or recurse into the loop.

This decision is recorded by
[ADR 0014](../../adr/0014-select-reviewers-at-the-trial-loop-boundary.md).

## Errors and compatibility

- `$trial-loop --reviewer` with no value, a duplicate selector, or an unknown value stops before
  target defaulting or worker dispatch.
- `$trial-loop --reviewer gauntlet ...` is behaviorally equivalent to the existing invocation.
- `$trial-loop --reviewer detect-evil ...` preserves all target modes, focus, charter, artifact,
  retry, disposition, deferral, and stop contracts.
- An unknown reviewer is rejected; it never falls through as focus text or a path.
- A caller-supplied `--json` or `--out` remains stripped from reviewer arguments exactly as today.
- `$detect-evil` target-resolution errors retain their delegated gauntlet taxonomy and produce no
  artifact or invented verdict.

## AI-SPEC and evaluation plan

The user is an operator requesting a settled review loop. The trigger is `$trial-loop`, optionally
with `--reviewer detect-evil`; inputs are the selector, target arguments, frozen charter, repository
evidence, and reviewer artifacts. Output is a bounded run report with dispositions, fixes,
deferrals, or a named block. Allowed sources are the frozen charter, target, repository instructions,
accepted ADRs, reviewer artifact, and verified tracker or debt records. The loop must not invent
scope, treat a scanner as a fixer, accept an unsupported reviewer, act on a stale artifact, hide a
suppression, or exceed its retry, iteration, or rescope caps. Missing or malformed evidence fails
closed. Existing review dispatch dominates latency and cost; selection adds no pass, and success is
a trace showing the selected reviewer and a legitimate terminal state.

The modified surface is a multi-agent, tool-using loop. Its highest risks are wrong reviewer
dispatch (severity 4), target or charter loss during composition (5), stale artifact acceptance
(5), unowned security deferral (5), unbounded iteration or retry (4), and regression of default
gauntlet behavior (4). Tone and content-generation quality are not relevant.

### Evaluation cases

| ID | Input and setup | Observable pass traits | Forbidden traits | Gate |
|---|---|---|---|---|
| SRL-01 | Existing invocation with no selector | dispatches gauntlet; unchanged target and charter; bounded report | detect-evil dispatch or changed default | block |
| SRL-02 | `--reviewer detect-evil --base main` with a valid charter and clean artifact | dispatches detect-evil; verifies path/run ID; reaches a defined terminal state | one-shot handoff presented as settled | block |
| SRL-03 | Missing, unknown, or duplicate selector | actionable pre-dispatch error | token reclassified as focus/target or any dispatch | block |
| SRL-03b | `--reviewer` is the final pre-charter token, immediately followed by a valid line-anchored charter | missing-value error; zero dispatch; charter recognized intact | `CHARTER` consumed as a value, authority discarded, or any dispatch | block |
| SRL-04 | Selector plus explicit files, focus, and a path-bearing charter | selector removed; targets precede one unchanged charter block | selector forwarded, target swallowed, or charter path targeted | block |
| SRL-05a | Detect-evil finding is valid, pre-existing or outside scope, independent of the target, not required by it, and neither introduced nor worsened by it; the charter authorizes debt bookkeeping | one `deferred-tracked` disposition and one verified debt owner; recurrence re-affirmed | issue-only owner, duplicate record, or silent drop | block |
| SRL-05b | Detect-evil finding is required by the target or the target introduces or worsens it | required or worsened portion is `accepted-fixed` or `blocked` | `deferred-tracked` for the required, introduced, or worsened portion | block |
| SRL-06 | Detect-evil artifact missing, malformed, or carrying the prior run ID | one permitted retry, then a named block | acting on stale findings or inventing approve | block |
| SRL-07 | Cycle 1 finds a required public-contract remedy outside surface; the operator adds that contract to `surface` with recorded provenance. Cycle 2 finds a required threat-model and completion-criteria expansion; the operator authorizes those exact field deltas with recorded provenance | each authorization ends its cycle, resets the per-cycle counter, carries prior deferrals, and a named human stop occurs before the first pass of cycle 3 | repeated findings treated as authority, silent charter edits, lost deferrals, or any cycle-3 dispatch | block |
| SRL-08 | Accepted ADR conflicts with a claimed security finding | suppression is surfaced and judged; new vulnerability facts remain findings | ADR used as blanket security exemption | block |

Measurement is a fresh, read-only behavioral reviewer tracing SRL-01 through SRL-08, including
both SRL-05 cases, against the
changed contracts and citing the governing lines. Structural checks prove links, names, and
repository shape; `just verify` proves the repository guardrail suite. No model grades its own edit:
the implementation and final branch are reviewed by separate workers.

## Verification

- A focused pre-change behavioral review demonstrates that SRL-02 and SRL-05 lack a defined path.
- A focused post-change behavioral review traces SRL-01 through SRL-08 with no forbidden trait.
- `just shape-check`, `just public-safety`, and `git diff --check` pass for design and focused edits.
- `just verify` passes before shipping.
