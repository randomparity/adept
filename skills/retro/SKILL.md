---
name: retro
description: "Mine GitHub workflow telemetry for cycle time, review iterations, scope accuracy, and status-label history, then write a grounded process- retrospective report with proposed tuning. Use for retrospective analysis of status labels and WORK annotations over a label set or date range."
---
# Process Retrospective

Mine the pipeline's own telemetry — `status:` label transition timelines and
`WORK:SCOPE` / `WORK:REVIEW` / `WORK:TRAJECTORY` annotation comments — for the
**process** metrics the pipeline emits but never reads back, and write a durable
`docs/retro/` report with proposed (not applied) tuning. This is the
process-learning counterpart to `$compound`, which records *solutions* only.

**Read-only against GitHub and git.** Use `gh` for **reads only**. The only durable
side effect is writing one report file; the recipes also create transient `mktemp`
scratch files (deleted when the shell exits). Every `gh` call must be one of the
read-only forms enumerated in *Read-only contract* (bottom) — that section is the
single authoritative allow/forbid list.

The `status:` state machine, the `WORK:*` sentinel / latest-complete-wins
convention, and the colon-label selection gotcha this skill relies on are all
defined by the **`github-tracking` skill**; the recipes below apply them.

The user-supplied text is the selector: a **label-set** or a **date-range**.

## 1. Resolve the repo

```bash
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)   # owner/name
OWNER=${REPO%/*}; NAME=${REPO#*/}
```

Pass `--repo "$REPO"` on every `gh issue` / `gh pr` / `gh search` call, and build
the timeline REST path from the split parts: `repos/$OWNER/$NAME/issues/$N/timeline`
(the `gh api` REST path takes owner and name as separate segments, not the combined
`owner/name`). Never reuse `$REPO` as a bare name. (No `git remote` — stays inside
`Bash(gh:*)`.)

## 2. Select the issues

Disambiguate the selector by shape:

- **Date-range** — the selector contains `..` (e.g. `2026-07-01..2026-07-20`).
  Select issues **closed** in the window:

  ```bash
  gh search issues --repo "$REPO" "closed:<from>..<to>" \
    --json number,state,closedAt --limit 200
  ```

- **Label-set** — anything else (e.g. `status:ready`, or space-separated
  `enhancement priority:high`). Select issues carrying **all** named labels:

  ```bash
  gh search issues --repo "$REPO" "label:<a> label:<b> …" \
    --json number,state,closedAt --limit 200
  ```

**Never use `gh issue list --label` for a colon label** (`status:` / `priority:` /
`type:`) — it silently returns nothing (the `github-tracking` colon-encoding
gotcha), so a real result set looks like "0 issues". `gh search` resolves the colon
and is the selection path for both modes.

- **Exclude `epic`-labeled issues** — they carry no `status:` labels and sit
  outside the state machine.
- **Truncation.** If the result count equals the `--limit` (200), record
  `truncated: yes` in the header and flag the findings as computed over a partial
  population — never present them as the complete backlog.
- **Empty selection.** Write no report; state plainly that the selector matched
  zero issues (distinguishable from the colon trap because `gh search` cannot
  silently mis-encode).

The retrospective is most meaningful over **completed cycles** (closed issues with
a merged PR). A label-set selector may match open, in-flight issues; include them,
but they report **partial** metrics (elapsed-so-far cycle time, `unknown`
scope-actual) — never fabricated completions.

## 3. Gather sources and compute metrics

For each selected issue, gather three sources and compute three metric families.
**Every metric has three possible states — never zero-fill:**

- a **value**, when the source data is present;
- **`unknown`**, when the source annotation is genuinely *absent* (→ Data gaps);
- **`error`**, when a `gh` read *failed* (rate-limit / 5xx / network — → Fetch
  failures). An `error` is never folded into `unknown`.

### 3a. Cycle time — from the label timeline

Capture the timeline **once** to a temp file (re-fetching per field multiplies the
API fan-out). Use `--jq '.[]'` to emit one event object per line so `--paginate`
across pages stays a clean JSONL stream, sourced by `jq -s`.

Capture the **fetch outcome first** — a failed read must become `error`, not
`unknown` (§3f). The reliable failure signal is a **non-zero `gh` exit**: a
rate-limit `403`, `5xx`, network drop, or mid-pagination page failure all make
`gh api` exit non-zero (`--jq` is gh-internal, so no pipe masks the status). An
**exit-0 empty capture is *not* a failure** — it is a genuinely empty timeline (rare;
a bare issue with no `labeled`/`closed`/comment events at all), which flows to the `else` and,
having no `in-progress` anchor, becomes `unknown` (a data gap), exactly like a
never-`in-progress` issue. So `error` and the metric branches are mutually exclusive
by control flow — the extraction and guard run only in the `else`:

```bash
TL=$(mktemp)
if ! gh api "repos/$OWNER/$NAME/issues/$N/timeline" --paginate --jq '.[]' > "$TL"; then
  cycle="error"   # non-zero gh exit → Fetch failures (§3f), never Data gaps
else
  # Fetch succeeded: extract anchors, defaulting a missing one to the empty string
  # ("// \"\"") so the never-in-progress guard can catch it.
  FIRST_IP=$(jq -rs '[.[] | select(.event=="labeled" and .label.name=="status:in-progress")] | first | (.created_at // "")' "$TL")
  LAST_CLOSED=$(jq -rs '[.[] | select(.event=="closed")] | last | (.created_at // "")' "$TL")
  # Current state governs (below); an empty $FIRST_IP here → cycle time unknown.
fi
```

**Current state governs (check it first)** — this resolves the open-vs-closed
ambiguity for a reopened issue (which has a `closed` event yet is currently open).
Within the `else` branch above:

- **Guard first — no `in-progress` anchor** (empty `$FIRST_IP`: a never-`in-progress`
  issue, the young-corpus *majority* case, or the rare genuinely-empty timeline) →
  cycle time `unknown` (→ Data gaps). **Stop here; do not run the duration math** —
  `fromdateiso8601` on an empty string raises a `jq` error. This is a data gap, not
  a fetch failure: a failed fetch already exited non-zero and was bucketed `error`
  in the `if` branch.
- Issue **currently closed** (non-empty `$FIRST_IP`) → cycle = first `in-progress`
  → **last** `closed`. Compute the duration in **`jq`** — portable across the `mac`
  (BSD `date`) and Linux hosts, unlike GNU-only `date -d`; `date` is used **only**
  for the report filename's `date +%F`, never for delta math:

  ```bash
  DAYS=$(jq -rn --arg a "$FIRST_IP" --arg b "$LAST_CLOSED" '(($b|fromdateiso8601) - ($a|fromdateiso8601)) / 86400 | floor')
  ```

- Issue **currently open** (non-empty `$FIRST_IP`) → **in-flight**, elapsed from
  `$FIRST_IP` to *now*, reported as `in-flight (Xd elapsed)` — a reopened issue's
  stale earlier `closed` is **not** the cycle end (open state takes precedence over
  the "last closed" anchor). Elapsed is likewise `jq`-computed against `now`:
  `jq -rn --arg a "$FIRST_IP" '((now) - ($a|fromdateiso8601)) / 86400 | floor'`.
- Best-effort **phase durations** when the events exist: `in-progress → in-review`,
  `in-review → awaiting-merge`.

### 3b. Resolve issue → PR (tie-break, never a guess)

Do this **before** the PR-data captures below — the scope-actual and iteration
metrics both need `$PR`. The deterministic resolver is a **body-keyword search**:
the pipeline's PRs link to their issue with `Closes #N` in the body
(`github-tracking`: "PR → issue: `Closes #N` in the PR body"), so a merged PR whose
body carries a standalone closing keyword for `#N` is the closer. Run the search
**once** and filter its output — do not issue a second `gh pr list`:

```bash
CAND=$(mktemp)
gh pr list --repo "$REPO" --search "<N> in:body" --state merged --json number,body > "$CAND"
```

Tie-break rules:

- **The closing PR wins** — one whose body carries a standalone `Closes` / `Fixes`
  / `Resolves #N` (matched by the regex below) — over a PR that only references the
  issue. (A timeline `closed`-by-PR event in `$TL` is a corroborating signal, but
  the body-keyword match is the authoritative resolver here; the pipeline always
  writes `Closes #N`.)
- **Never adopt a bare `Part of #N` PR as scope-actual** — it only *partially*
  implements the issue, so its diff under-states true scope and mis-buckets S/M/L.
- **Ambiguity → `unknown`, never a guess** — two or more closing PRs, or none →
  scope-actual and iterations are `unknown`, listed in Data gaps with the reason
  (`ambiguous: N candidate PRs` vs. `no merged PR`). When `$PR` is `unknown`, skip
  the PR capture below and both PR-derived metrics are `unknown`.

The closing keyword is anchored on **both** sides: right by `#<N>(?![0-9])` so `#41`
does not over-match `#410`, and left by `(?<![a-z])` so `hotfix`/`bugfix`/`prefix
#<N>` do not match the `fix #<N>` substring (GitHub only honors a standalone
keyword). The stem class `[eds]*` accepts every closing form
(`Closes`/`Closed`/`Fixes`/`fix`/`Resolves`/`Resolved`), and `:? +` tolerates an
optional colon and any spacing (`Closes: #N`, `Closes  #N`):

```bash
PR=$(jq -r '[.[] | select(.body | test("(?i)(?<![a-z])(clos|fix|resolv)[eds]*:? +#<N>(?![0-9])"))] as $c
       | if ($c|length)==1 then ($c[0].number|tostring)
         elif ($c|length)==0 then "unknown(no-closer)"
         else "unknown(ambiguous)" end' "$CAND")
```

### 3c. Capture the issue and PR blobs

Two captures per issue, each fetched **once**. The `WORK:*` annotations live on
different objects (`github-tracking`): **`WORK:SCOPE` is on the issue**,
**`WORK:REVIEW` is on the PR** — so read each from the right blob. The PR capture
runs only when §3b resolved a numeric `$PR`:

```bash
# issue comments — source of WORK:SCOPE (§3e estimate)
ISSUEJSON=$(mktemp)
gh issue view "$N" --repo "$REPO" --json comments > "$ISSUEJSON"

# PR comments + diff stats in one call — WORK:REVIEW (§3d) and diff LOC (§3e actual)
PRJSON=$(mktemp)
gh pr view "$PR" --repo "$REPO" --json comments,additions,deletions,changedFiles > "$PRJSON"
```

### 3d. Review-loop iterations — from `WORK:REVIEW`

Read the latest **complete** `WORK:REVIEW` block from `$PRJSON`. A block missing its
`<!-- REVIEW:COMPLETE -->` sentinel is treated as **absent** (`github-tracking`
latest-complete-wins):

```bash
jq -r '[.comments[].body | select(test("(?m)^<!-- WORK:REVIEW -->$") and test("(?m)^<!-- REVIEW:COMPLETE -->$"))] | last' "$PRJSON"
```

Extract the **iteration count** (carry the verdict / security status for the
narrative). No complete block → iterations `unknown`.

### 3e. Scope estimate vs. actual — `WORK:SCOPE` vs. PR diff

- **Estimate**: the S/M/L complexity from the latest **complete** `WORK:SCOPE`
  block on the **issue** — read from `$ISSUEJSON`, **not** `$PRJSON` (`WORK:SCOPE`
  is posted on the issue), with the same sentinel / latest-complete rule as §3d
  (`WORK:SCOPE` / `SCOPE:COMPLETE`):

  ```bash
  jq -r '[.comments[].body | select(test("(?m)^<!-- WORK:SCOPE -->$") and test("(?m)^<!-- SCOPE:COMPLETE -->$"))] | last' "$ISSUEJSON"
  ```

- **Actual**: LOC = `additions + deletions` from `$PRJSON`
  (`jq '.additions + .deletions' "$PRJSON"`).
- **Comparison** with **explicitly heuristic** bands: `S < 50`, `M 50–300`,
  `L > 300` LOC. State the bands as heuristic in the report, and treat a
  disagreement as **advisory** — the `WORK:SCOPE` estimate is a qualitative S/M/L
  judgement, not a LOC prediction, so a band mismatch flags an issue *worth a look*,
  not a proven bad estimate (the retro may recommend re-tuning the bands themselves).

### 3f. Fetch failures ≠ data gaps

On any `gh` read error for an issue/PR (a non-zero `gh` exit — rate-limit `403`,
`5xx`, network drop), mark the affected metric `error` (not `unknown`) and record
it in a distinct **Fetch failures** section. **Continue — never fail-fast
silently** (a read-only run has nothing to roll back). Annotate the aggregate as
computed over an incomplete fetch (`over M of N issues; K fetch errors`). If fetch
errors exceed successes, lead the report with a prominent unreliability warning
suggesting a smaller selector or a retry.

## 4. Write the report

Path: `docs/retro/<date>-<slug>.md`, where `<date>` = `date +%F` and `<slug>` is a
filesystem-safe rendering of the selector (`status:ready` → `status-ready`;
`2026-07-01..2026-07-20` → `2026-07-01-2026-07-20`). If a same-`<date>-<slug>` file
exists, **overwrite it** (a point-in-time snapshot; newest supersedes) and note the
replacement in the in-session summary — never a silent clobber.

Sections:

1. **Header** — selector, mode (label-set / date-range), generated date, issue
   count, `truncated: yes|no`, and per-metric **coverage** (how many of N issues
   had each source annotation). State coverage up front so a thin sample is never
   mistaken for a complete one.
2. **Metrics** — per-issue rows plus an aggregate. Aggregates are **median +
   range** (not a fabricated p90 over a handful of points). Emit an **instability
   note whenever a metric's coverage `N < 5`**, warning against over-trusting a
   2–4-point median.
3. **Findings** — process observations, each **grounded in a named metric**. Every
   finding must reference an issue number or aggregate present in the Metrics table,
   and any number it states must match the table. No finding citing an entity absent
   from the table, or a number the table contradicts. Causal phrasing is allowed
   only to the extent the cited metric supports it.
4. **Proposed tuning (NOT applied)** — concrete suggestions, each satisfying **both**
   halves of the grounding rule: it **cites a real** `shared/commands/*.md` or
   `AGENTS.md` file (verified with `Read` / `Grep`) **and traces to a finding or
   metric** in this report. No proposal invented independent of the data. Each is
   explicitly a proposal a human applies on a branch — the skill never edits those
   files.
5. **Data gaps** — issues/PRs whose source annotation is genuinely *absent*.
6. **Fetch failures** — issues/PRs whose `gh` read *errored* (kept distinct from
   Data gaps). Omit when there were none.

## 5. Surface the result

After writing the file, **print an in-session summary** to the conversation — the
metrics headline, the top findings, and the proposed-tuning count — so the report
is never a write-only artifact for its primary reader. On an overwrite, state that
an existing file was replaced.

Then state the **learn→tune** step: a human routes any worthwhile proposal into the
pipeline via `$issue` (born triaged) or applies it on a branch. `$retro` never files
the issue or edits the files itself.

Given the young telemetry corpus, an early run over a historical selector may be
dominated by `unknown` results. That is fine — surface it honestly via the coverage
and data-gaps sections; a degenerate report is clearly labeled, not silently empty.

## Read-only contract (hard constraints)

- **Zero mutating `gh` calls.** Every `gh` invocation must be one of: `gh repo
  view`, `gh search …`, `gh issue view|list`, `gh pr view|list`, or `gh api`
  **path-scoped to the timeline read endpoint** (`gh api repos/*/issues/*/timeline
  …`). Forbidden: `gh issue edit|close|reopen|comment|lock`, `gh pr
  edit|close|merge|comment|ready`, `gh label create|delete`, `gh api` with
  `-X`/`--method POST|PATCH|PUT|DELETE`, and **`gh api graphql`** (it POSTs by
  default and can carry a mutation with no write flag).
- **Explicit `--json` fields** on every read.
- **No zero-fill** — missing → `unknown`; failed read → `error`; never `0`.
- **No git, no commits, no file edits** other than writing the one report doc
  (plus transient `mktemp` scratch files, which are permitted and self-cleaning).
- **Proposals are proposed, not applied.**
