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
arithmetic of its own beyond §4's bounded follow-through search. Every collection
read and every collection computation happens inside
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

The collector performs the selection, **every** collection `gh` read, and every
collection computation; within §1 this skill performs none. Pass the selector
exactly as the user supplied it and capture stdout wholesale — the document
exists on stdout and nowhere else:

```bash
DOC=$(mktemp)
skills/bards-tale/scripts/collect-telemetry "<selector>" > "$DOC"
```

**Prior sidecar.** Before invoking, check `docs/retro/` for the most recent
prior sidecar of the same selector: files named `<date>-<slug>.json` whose
`<slug>` renders the same selector and whose date is strictly earlier than
today — the newest of them is the prior run. Pass its path as the optional
second argument; the collector computes the comparison (below) and the report
renders it. When no earlier sidecar exists — including one a human never
committed, which this git-free skill simply cannot see — pass no second
argument and the movement section is omitted entirely. Locating the file is a
filesystem read and a name sort; the comparison itself is never done here.

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
- **Cohort and throughput fields** — per-issue `scope_complete` (a complete
  `WORK:SCOPE` block exists under latest-complete-wins — the boundary the
  report's cohort split follows, independent of whether its complexity line
  parses) and `closed_at` (the raw close instant; an open issue reports
  `unknown(not-closed)`); `metrics.cohorts` (per-cohort aggregates over
  `instrumented` / `legacy`, the pre-existing flat `metrics.aggregate`
  becoming the labelled combined context); `metrics.quartiles`, combined-population
  p25/p75 gated at N >= 20; `metrics.throughput.weeks`, weekly closed counts
  with instability-gated per-week median cycle. The renderer contract for all
  of these is §3.

- **Movement** — `metrics.movement`, always present: the comparison of this
  run's combined aggregates against a prior run's, per span family, behind
  the issue's comparability rules (exact selector match, a known prior
  schema major, neither run truncated). With no prior path passed — and for
  every refusal — it carries an explicit `omitted`/`incomparable` status
  with its reason, never a guessed delta. The renderer contract is §3's
  movement section.

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
   `rate_limited` when present, per-metric **coverage** from
   `metrics.coverage` (how many of N issues carried each metric as a value),
   and the **cohort split**: how many issues are instrumented (a complete
   `WORK:SCOPE` block exists, `scope_complete` true) and how many are legacy.
   State coverage up front so a thin sample is never mistaken for a complete
   one. The label-anchored metrics are thin by nature; the GitHub-native
   spans cover the whole selected population minus fetch errors and cannot
   be skewed by a labeling bug — say so when contrasting the two families.

   **The cohort boundary.** Presence of a complete `WORK:SCOPE` is the line
   between the legacy cohort and the instrumented cohort. Everything below
   keeps the cohorts apart; combined figures appear only where this contract
   says so, explicitly labelled as context — a median over "all issues"
   mixes a measured cohort with one that was never measured, and publishing
   it as one number is the dishonesty this structure exists to prevent.
2. **Metrics** — two tables, one aggregate block per cohort:
   - **Instrumented cohort table** — full rows for every issue with
     `scope_complete` true: cycle, phases, closing PR, review iterations,
     verdict/exit/security, scope estimate vs actual LOC, the GitHub-native
     spans, the queue/rework spans, drift, trajectory and divination fields.
   - **Legacy cohort table** — compact rows for every other issue: issue,
     cycle, closing PR, LOC. The remaining columns are structurally
     `unknown` for these issues, and printing that word seventy times
     communicates nothing; the compact shape is the honesty, not a loss.
   - **Aggregates** — `metrics.cohorts.instrumented` and
     `metrics.cohorts.legacy`: **median + range** per span family within
     each cohort (not a fabricated p90 over a handful of points). The
     combined figure (`metrics.aggregate`, all issues) may appear once
     beneath both, explicitly labelled *context — all issues*, never as
     either cohort's headline. Durations are hours to one decimal — a
     sub-hour cycle reports `0.4`, never `0`. Emit an **instability note
     whenever a metric's coverage `N < 5`**, warning against over-trusting
     a 2–4-point median. Risk-band cycle segments are gated structurally —
     a band under five measured cycles reports its count only. Flag any
     issue whose `review_drift_hours` exceeds
     `max(1, 0.1 × pr_lifespan_hours)`: the label timestamps lag reality.
   - **Combined quartiles** — `metrics.quartiles`, labelled *combined
     population*: p25/p75 for a span family only when at least 20 issues
     carry it as a value (families below the threshold report their count
     alone). Per-cohort quartiles are **excluded deliberately**: the
     instrumented cohort is often a dozen points, and p25/p75 over that few
     repeats the mixed-aggregate mistake in finer grain. If no family
     reaches the threshold, omit the section rather than lower it.
3. **Throughput over time** — `metrics.throughput.weeks` as a table: week
   (Monday-start UTC), closed count, and per-week median cycle. A
   date-range retrospective answers *whether the pipeline is changing*, not
   only how fast it was; the trend of weekly medians is the signal, so
   present weeks in order even when counts are small. A week with fewer
   than five measured cycles reports its count with
   `unknown(instability-rule)` at the median position — read the sequence
   of counts before reading any median.
4. **Movement against the previous run** — rendered only when a prior sidecar
   was passed to the collector. `metrics.movement.status` decides the shape,
   and the issue's comparability rules are the whole contract:
   - `compared` — a table of the compared span families: family, previous
     median, current median, Δ median (signed, one decimal), labelled with the
     prior run's `generated_at` so the reader knows what moved against what.
     Only families present in `movement.families` appear — a family either
     side could not resolve is absent, and the table never zero-fills it.
   - `incomparable` — one line naming the reason (`truncated-prior` /
     `truncated-current`): the section exists to say why there is no movement,
     because movement between partial populations is not movement.
   - `omitted` — the section is omitted entirely: a different selector is not
     a predecessor, and a prior that was never committed simply does not exist
     for this git-free skill. Never an empty section, never a section
     reporting movement against nothing.
5. **Findings** — process observations, each **grounded in a named metric**.
   Every finding must reference an entity present in this report — an issue
   row in either cohort's table (compact rows ground legacy-cohort findings
   on cycle, PR, or LOC), an aggregate or quartile figure, a movement row, a
   throughput week, or a coverage count — and any number it states must match
   the entry it cites. No finding citing an entity absent from the report, or
   a number the cited entry contradicts; a finding about the instrumented
   cohort must not quietly lean on the combined context figures. Causal
   phrasing is allowed only to the extent the cited metric supports it.
   When narrating a review loop from `exit`, remember: the field takes one
   of five enumerated values (ADR 0021); absence is not `none`, so keep
   today's verdict-only reading when `exit` is missing or unrecognized.
   Lead time carries a standing caveat: where issues are batch-filed by
   `$saga` or `$bounty` and worked later, `lead_time_hours` is dominated by
   queue position rather than effort — findings must not read it as
   slowness.
6. **Proposed tuning (NOT applied)** — concrete suggestions, each satisfying
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
7. **Data gaps** — entries whose source annotation is genuinely *absent*
   (`unknown`). When a gap set is the majority for a category, list the
   **complement with a count** for the remainder — "complete `WORK:SCOPE`:
   14 issues (#26, #140, …); the remaining 56 have none" — instead of
   enumerating the majority. Enumerate a gap set directly only when it is
   the minority.
8. **Fetch failures** — entries whose `gh` read *errored* (`error`; kept
   distinct from Data gaps). Omit when there were none. If errors exceed
   successes, lead the report with a prominent unreliability warning
   suggesting a smaller selector or a retry.

## 4. Surface the result

After writing the file, **print an in-session summary** to the conversation — the
metrics headline, the top findings, and the proposed-tuning count — so the report
is never a write-only artifact for its primary reader. On an overwrite, state that
an existing file was replaced.

Then state the **learn→tune** step: a human routes any worthwhile proposal into the
pipeline via `$bounty` (born triaged) or applies it on a branch. An issue filed from a
retrospective proposal carries a whole-line citation in its body naming the proposing
report —

    Retro: docs/retro/<date>-<slug>.md

— written by whoever files the issue, exactly like the existing `Part of #N` courtesy
line; nothing in `$bounty` changes. `$bards-tale` never files the issue or edits the
files itself.

**Follow-through check.** The citation makes routing measurable, so close the loop:
when §1 located a prior sidecar for this selector, run one bounded read-only search
for issues citing that prior report —

    gh search issues --repo <owner>/<name> --limit 50 --json number,title,state,body \
      '"Retro" "docs/retro/<prior-date>-<slug>.md"'

GitHub search rejects a colon inside a quoted phrase, so the query pairs the
`Retro` term with an exact-phrase match on the report path rather than quoting
the whole citation line.

— and compare its results against the prior report's **Proposed tuning** section
(a local read of the prior report file). Report, in the in-session summary above,
which of that report's proposals were routed (an issue cites the report) and which
were unrouted. Honesty rules: a prior report carrying proposals but returning zero
citations reports **convention not in use for this report** — never "no proposals
were adopted", because a report filed before the convention existed cannot be
measured by it. When the returned count equals the limit, report possible
truncation per ADR 0013 rather than presenting the result as complete. The check
never files, comments on, or otherwise routes anything itself.

Given the young telemetry corpus, an early run over a historical selector may be
dominated by `unknown` results. That is fine — surface it honestly via the coverage
and data-gaps sections; a degenerate report is clearly labeled, not silently empty.

## Read-only contract (hard constraints)

- **Zero mutating `gh` calls.** Every `gh` invocation — the collection reads live
  inside `scripts/collect-telemetry`, and the sole other sanctioned call is §4's
  bounded follow-through search — must be one of: `gh repo view`, `gh search …`,
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
