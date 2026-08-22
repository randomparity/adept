---
name: bards-tale
description: "Mine GitHub workflow telemetry for cycle time, review iterations, scope accuracy, and status-label history, then write a grounded process- retrospective report with proposed tuning. Use for retrospective analysis of status labels and WORK annotations over a label set or date range."
---
# Process Retrospective

Mine the pipeline's own telemetry — `status:` label transition timelines and
`WORK:SCOPE` / `WORK:REVIEW` / `WORK:TRAJECTORY` annotation comments — for the
**process** metrics the pipeline emits but never reads back, and write a durable
`docs/retro/` report with proposed (not applied) tuning. This is the
process-learning counterpart to `$grimoire`, which records *solutions* only.

**Read-only against GitHub and git.** The skill performs no `gh` call and no
arithmetic of its own. Every GitHub read and every computation happens inside
`scripts/collect-telemetry` (this directory), which takes the selector and emits
exactly one JSON telemetry document on stdout conforming to ADR 0030
(`docs/adr/0030-retrospective-telemetry-envelope-and-collector-contract.md`).
The only durable side effects are writing that document beside the report (the
sidecar) and writing the one report file; transient `mktemp` scratch files are
permitted and self-cleaning. The *Read-only contract* (bottom) is the single
authoritative allow/forbid list, and it binds the collector.

The `status:` state machine, the `WORK:*` sentinel / latest-complete-wins
convention, and the colon-label selection gotcha the collector relies on are
all defined by the **`quest-log` skill**; the collector applies them.

The user-supplied text is the selector: a **label-set** or a **date-range**.

## 1. Run the collector

The collector performs the selection, **every** `gh` read, and every
computation; this skill performs none. Pass the selector exactly as the user
supplied it and capture stdout wholesale — the document exists on stdout and
nowhere else:

```bash
DOC=$(mktemp)
skills/bards-tale/scripts/collect-telemetry "<selector>" > "$DOC"
```

If the collector exits non-zero or stdout does not parse as JSON, stop:
write nothing — no sidecar, no report — and surface the collector's stderr.
ADR 0030 makes a non-zero exit or an unparseable capture an aborted
collection that is never parsed as partial output.

- **`schema_version`** — reject a major version this skill does not know
  rather than guessing at its shape (ADR 0030's bump rule).
- **`selector`, `mode`** — the selector as passed, and `"label-set"` or
  `"date-range"`.
- **`truncated`** — true whenever the selected population equalled the search
  limit. The signal is conservative: treat the population as possibly
  incomplete while it is true and flag the findings as computed over a partial
  population — never present them as the complete backlog (ADR 0013).
- **`population`** — `count` and the ordered selected issue numbers. Epic-labelled
  issues are excluded by the collector; they sit outside the state machine.
- **`rate_limited`** — present only on a partial document: fetch errors stacked
  up past the collector's cutoff, processing stopped early, and
  `metrics.issues` covers fewer issues than `population`. Surface this
  prominently rather than presenting the metrics as complete.
- **`metrics.issues`** — one entry per processed issue. Every metric position
  is in exactly one tri-state: a value, `"unknown(<reason>)"` (a genuine data
  gap), or `"error"` (a failed read). Never zero-fill; never read an `error`
  as an `unknown`; never fold either into a default.
- **GitHub-native spans** — seven per-issue fields sourced from GitHub's own
  timestamps rather than pipeline labels, so they cannot be skewed by a
  labeling bug: `lead_time_hours` (issue filed→closed; an open issue reports
  `unknown(not-closed)` — the span is incomplete, never elapsed-so-far),
  `pr_lifespan_hours` (PR opened→merged), `full_delivery_hours` (issue
  filed→PR merged), `merge_lag_hours` (last commit→merged),
  `build_private_hours` (first commit→PR opened), `ci_wall_hours`
  (`statusCheckRollup`: earliest check start→latest completion over checks
  carrying both timestamps — `CheckRun` entries; `StatusContext` entries carry
  none, and a rollup with no timed checks is `unknown(no-checks)` /
  `unknown(no-check-timings)`, never a zero fill), and `reopen_count` (counted
  from `reopened` events in the captured timeline; a successful read with zero
  reopens genuinely reports `0`). All ride the same reads as the label-anchored
  metrics — widened `--json` lists, no additional round trips — and their
  coverage equals the selected population minus fetch errors and genuinely
  absent anchors (open issues, issues with no closing PR, PRs without
  timestamps or commits) — far wider than the label-anchored samples.
- **Queue and rework spans** — five label-anchored per-issue fields computed
  from the already-fetched timeline stream in the issue-side group:
  `triage_latency_hours` (filed → first `status:ready`),
  `queue_wait_hours` (first `status:ready` → first `status:in-progress`;
  together the two decompose the filed-to-started interval and localize
  where the delay sits), `blocked_dwell_hours` (summed time inside
  `status:blocked` / `status:needs-human`; each entry pairs with its exit —
  any other `status:` label, the matching `unlabeled` event, or the close
  event — and an interval with no exit is `unknown(still-blocked)`),
  `human_response_hours` (last `status:awaiting-merge` label → PR merge
  instant), and `rework_bounces` (counted re-entries into `in-progress`
  after `in-review`; a measured zero reports `0`, like `reopen_count`).
  These degrade when the pipeline mislabels — which is exactly what the
  drift cross-check reports — and that difference in failure mode is why
  they sit in the issue-side group apart from the GitHub-native family. A
  span that runs backwards (label history out of order) is `"error"` at its
  position, never a clamped value.
- **Drift cross-check** — `review_drift_hours`: where both sides exist, the
  absolute disagreement between the label-derived review phase
  (`phase_review_hours`) and its GitHub-timestamp analogue
  (`pr_lifespan_hours`); otherwise it carries the same tri-state as its
  missing or errored side. A disagreement exceeding **10% of
  `pr_lifespan_hours` or 1 hour, whichever is larger**, means labels were
  written late or not at all — the drift `$resurrection` exists to repair —
  not that review was fast.
- **Trajectory mining** — five per-issue fields read line-anchored from the
  latest complete `WORK:TRAJECTORY` block in the already-fetched issue
  comments (latest-complete-wins): `trajectory_phase` (the `phase:` or
  `outcome:` slot — the parked phase or terminal outcome),
  `trajectory_branch` (`branch:` / `branch/pr:`), `trajectory_pr` (the
  first integer of an explicit `pr:` field), `trajectory_guardrails`
  (`guardrails:` / `guardrail status:`), and `trajectory_surprises`
  (`surprises worth remembering:` / `surprises:`). An absent block is
  `unknown`; prose that defeats the line-anchored read is the data gap it
  honestly is — a multi-line surprises section surfaces only its first
  line.
- **Divination calibration** — `divination_complexity` from the latest
  complete `WORK:DIVINATION` block, plus `scope_miss_location`: the
  skill's heuristic LOC bands (S < 50, M 50–300, L > 300) turn each link
  of the divination → `WORK:SCOPE` estimate → `loc_actual` chain into a
  band, and the agreement pattern locates a miss — `aligned` (all three
  bands agree), `assessment` (the estimate repeats the divination against
  a differing actual, or the estimate matches the actual the divination
  misread — the divergence begins at the pre-work assessment), `freeze`
  (divination and actual agree against a differing estimate — the freeze
  diverged from a correct assessment), `divergent` (no two links agree),
  or `unknown(no-divination)` / `unknown(no-scope)` / `unknown(no-loc)`
  for a link that did not resolve. A failed comment or diff read is
  `error` at every position it feeds.
- **Risk-band cycle segmentation** — a per-issue `risk_band` (most
  restrictive of the `risk:` labels present, quest-log's multi-match rule;
  `unjudged` when none — absence is the third state it is everywhere
  else, never `night-safe`) and `metrics.risk_band_cycle_hours`, the
  cycle-time distribution (count, median, min, max) per band. The
  instability rule is structural here: a band with fewer than five
  measured cycles reports only its count, with
  `unknown(instability-rule)` at each distribution position.

**Empty selection.** When `population.count == 0`, write nothing — no report,
no sidecar — and state plainly that the selector matched zero issues (`gh
search` percent-encodes colon labels correctly, so an empty result is genuinely
empty).

A label-set selector may match open, in-flight issues; include them, but their
metrics are partial (`cycle_in_flight` true, elapsed-so-far cycle) — never
fabricated completions.

## 2. Write the sidecar

Write the captured document byte-for-byte to `docs/retro/<date>-<slug>.json`,
where `<date>` = `date +%F` and `<slug>` is a filesystem-safe rendering of the
selector (`status:ready` → `status-ready`; `2026-07-01..2026-07-20` →
`2026-07-01-2026-07-20`). If a same-`<date>-<slug>` file exists, **overwrite
it** (a point-in-time snapshot; newest supersedes) and note the replacement in
the in-session summary — never a silent clobber. A human commits both
artifacts; this skill runs no git.

## 3. Render the report from the document

Path: `docs/retro/<date>-<slug>.md`, same `<slug>` and overwrite semantics.

Sections:

1. **Header** — selector, mode (label-set / date-range), generated date (from
   `generated_at`), issue count (`population.count`), `truncated: yes|no`,
   `rate_limited` when present, and per-metric **coverage** from
   `metrics.coverage` (how many of N issues carried each metric as a value).
   State coverage up front so a thin sample is never mistaken for a complete
   one. The label-anchored metrics are thin by nature; the GitHub-native
   spans cover the whole selected population minus fetch errors and cannot
   be skewed by a labeling bug — say so when contrasting the two families.
2. **Metrics** — per-issue rows from `metrics.issues` plus the aggregate from
   `metrics.aggregate`: **median + range** per span family (not a fabricated
   p90 over a handful of points). Durations are hours to one decimal — a
   sub-hour cycle reports `0.4`, never `0`. Emit an **instability note
   whenever a metric's coverage `N < 5`**, warning against over-trusting a
   2–4-point median. Risk-band cycle segments are gated structurally — a
   band under five measured cycles reports its count only. Flag any issue
   whose `review_drift_hours` exceeds
   `max(1, 0.1 × pr_lifespan_hours)`: the label timestamps lag reality.
3. **Findings** — process observations, each **grounded in a named metric**.
   Every finding must reference an issue number or aggregate present in the
   Metrics table, and any number it states must match the table. No finding
   citing an entity absent from the table, or a number the table contradicts.
   Causal phrasing is allowed only to the extent the cited metric supports it.
   When narrating a review loop from `exit`, remember: the field takes one of
   five enumerated values (ADR 0021); absence is not `none`, so keep today's
   verdict-only reading when `exit` is missing or unrecognized.
   Lead time carries a standing caveat: where issues are batch-filed by
   `$saga` or `$bounty` and worked later, `lead_time_hours` is dominated by
   queue position rather than effort — findings must not read it as slowness.
4. **Proposed tuning (NOT applied)** — concrete suggestions, each satisfying
   **both** halves of the grounding rule: it **cites a real governing workflow
   or applicable repository instruction source** (verified with `Read` /
   `Grep`) **and traces to a finding or metric** in this report. No proposal
   invented independent of the data. Each is explicitly a proposal a human
   applies on a branch — the skill never edits those files. The scope check
   compares `scope_estimate` against `loc_actual` with **explicitly heuristic**
   bands — `S < 50`, `M 50–300`, `L > 300` LOC — and treats a disagreement as
   **advisory**: the estimate is a qualitative judgement, so a mismatch flags
   an issue *worth a look*, and the retro may recommend re-tuning the bands
   themselves.
5. **Data gaps** — entries whose source annotation is genuinely *absent*
   (`unknown`).
6. **Fetch failures** — entries whose `gh` read *errored* (`error`; kept
   distinct from Data gaps). Omit when there were none. If errors exceed
   successes, lead the report with a prominent unreliability warning
   suggesting a smaller selector or a retry.

## 4. Surface the result

After writing the file, **print an in-session summary** to the conversation — the
metrics headline, the top findings, and the proposed-tuning count — so the report
is never a write-only artifact for its primary reader. On an overwrite, state that
an existing file was replaced.

Then state the **learn→tune** step: a human routes any worthwhile proposal into the
pipeline via `$bounty` (born triaged) or applies it on a branch. `$bards-tale` never files
the issue or edits the files itself.

Given the young telemetry corpus, an early run over a historical selector may be
dominated by `unknown` results. That is fine — surface it honestly via the coverage
and data-gaps sections; a degenerate report is clearly labeled, not silently empty.

## Read-only contract (hard constraints)

- **Zero mutating `gh` calls.** Every `gh` invocation — all of them live inside
  `scripts/collect-telemetry` — must be one of: `gh repo view`, `gh search …`,
  `gh issue view|list`, `gh pr view|list`, or `gh api` **path-scoped to the
  timeline read endpoint** (`gh api repos/*/issues/*/timeline …`). Forbidden:
  `gh issue edit|close|reopen|comment|lock`, `gh pr
  edit|close|merge|comment|ready`, `gh label create|delete`, `gh api` with
  `-X`/`--method POST|PATCH|PUT|DELETE`, and **`gh api graphql`** (it POSTs by
  default and can carry a mutation with no write flag).
- **Explicit `--json` fields** on every read.
- **No zero-fill** — missing → `unknown`; failed read → `error`; never `0`.
- **No git, no commits, no file edits** other than writing the two artifacts
  this skill owns — the one report doc **and** its telemetry sidecar (plus
  transient `mktemp` scratch files, which are permitted and self-cleaning).
- **Proposals are proposed, not applied.**
