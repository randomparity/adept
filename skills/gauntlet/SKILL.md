---
name: gauntlet
description: "Use when asked to challenge, pressure-test, hostile-review, or adversarially review code changes, git diffs, specs, RFCs, plans, design docs, or files before shipping; also use for hidden assumptions, failure modes, edge cases, rollout risk, pre-ship skepticism, or structured JSON findings written to an output path."
---
# Adversarial Challenge Review

Run a hostile review of the target(s) and report the strongest reasons the work should not ship yet. Pressure-test the chosen approach, the assumptions, and the failure modes. Read-only apart from an optional `--out` findings file — do not edit reviewed files, comment on PRs, or change git state.

Input: use the user-supplied target, flags, and focus text.

**Caller contract & constraints (front-loaded so they survive truncation).** This
skill is almost always one step inside a larger workflow (e.g. a review loop).
Emitting the verdict is a **checkpoint, not a turn boundary** — hand it back and
let the caller continue; stop only if a human asked for a one-shot review with
nothing queued after. **Read-only** except for the optional `--out` findings file:
never edit reviewed files, run formatters, post PR comments, or change git state.
`approve` only when no **blocking** finding exists — `medium` and `low` findings are
**notes**, and they ride along with an `approve` rather than withholding it. Full
detail in *Severity vocabulary*, *Caller contract*, and *Hard constraints* below.

## Argument parsing

**Stop rule — the `CHARTER` label.** Before classifying anything, find the first line whose first
**content** token is `CHARTER`, skipping leading whitespace, Markdown list markers (`-`, `*`, `+`)
and emphasis characters, and ignoring trailing punctuation or emphasis. Matching is
case-sensitive; the start of the supplied invocation text counts as a line start. So `CHARTER`, `   CHARTER (…)`,
`CHARTER:`, `- CHARTER:` and `**CHARTER:**` all match. That line and every token after it is
**focus text** — never a target, never a flag. A path named there is prose describing a permitted
change surface, not a file to review. Classify only the tokens *before* that line with the rules
below.

**When a `CHARTER` label was found** and classifying the tokens before it leaves no target token
and no `--base`/`--working-tree` flag, do **not** fall through to the working-tree default. A
flag whose argument would fall at or after the label is not satisfied and does not count here: a
`--base` whose ref token sits on the label line has no ref, so it counts as no `--base` flag —
never consume the label, or anything after it, as a ref. Stop with a target-resolution error,
and **name the cause you can actually distinguish**:

- no token before the label was even a candidate target — the caller supplied nothing but focus
  text and the block → *a `CHARTER` label preceded every target token*;
- a candidate token was present but failed to resolve (a typo, a file deleted since the skill
  was composed, a glob matching nothing) → name **that token**, not the charter. This case takes
  precedence over the rule below about continuing past an unresolvable path: with a label
  present there is nothing left to continue with, so it stops here rather than falling through
  to the working-tree default.

Never assert the charter is at fault when an unresolvable target token explains it. A confident
wrong diagnosis is worse than a generic one, and `$trial-loop` treats this text as a specified
return — it stops immediately and quotes it, so a misnamed cause is terminal and points the
operator at the wrong thing.

Under `--json`/`--out` a target-resolution error suppresses the artifact and the compact object
entirely — see *File output*. (With no label present, nothing changes: a bare `$gauntlet` still
reviews the working tree.)

The anchor is a line boundary, so `CHARTER` appearing mid-line is **not** the label: classify
that token normally. A caller that cannot guarantee the label arrives at the start of its own
line cannot rely on this rule.

Walk the remaining tokens left-to-right and classify each:

1. `--base <ref>` — review the diff `<ref>...HEAD`. Consumes the next token as the ref.
2. `--working-tree` — review uncommitted changes (status + staged + unstaged + untracked).
3. `--json` — emit JSON (schema below) instead of markdown.
4. `--out <path>` — write the full JSON artifact to `<path>` and emit only a compact `{verdict, findings_count, blocking_count, suppressed_count, path, run_id}` inline. Consumes the next token as the path. Implies `--json`. Without `--out`, output is unchanged.
5. Tokens that resolve to a file (`Read`/`ls`) or expand to a non-empty glob (`Glob`) → target list.
6. Anything left → focus text.

If no `--base`, no `--working-tree`, and no resolvable paths are present, default to `--working-tree`. This default does not apply when a `CHARTER` label was found; see the stop rule above.

`--base` and explicit paths are mutually exclusive in spirit — if both are present, prefer the explicit paths and warn that `--base` was ignored. A path inside a `CHARTER` block is not an explicit path — the stop rule removes it from classification before this rule is reached.

## Target resolution

- **Branch mode (`--base <ref>`):** file list from `git diff --name-only <ref>...HEAD`; content from `git diff <ref>...HEAD`. Also capture the merge-base (`git merge-base HEAD <ref>`) for context.
- **Working-tree mode (`--working-tree` or default):** combine `git status --short --untracked-files=all`, `git diff --cached`, `git diff`, and the contents of any untracked files.
- **File-list mode (explicit paths or globs):** expand globs with `Glob`, then `Read` each file. Do not pull in git diff.

If a path does not exist or a glob matches nothing, surface that as a target-resolution warning and continue with the remaining targets. If nothing resolves at all, what happens next depends on the `CHARTER` label:

- **A label was found** — stop with the target-resolution error described in *Argument parsing*, naming the token that failed. Do not invent context, and do not fall through to the working-tree default.
- **No label** — keep the warning and fall through to the working-tree default in *Argument parsing*, which treats an unresolved token the same as no target token at all. So `$gauntlet nonexistent.md` reviews the working tree **and** reports which token did not resolve; the warning is what tells the caller its target was wrong.

## Per-target classification

For each target, decide whether it is code or document:

- **Code** — source extensions (`.ts`, `.tsx`, `.js`, `.mjs`, `.py`, `.go`, `.rs`, `.c`, `.cc`, `.cpp`, `.h`, `.hpp`, `.java`, `.kt`, `.rb`, `.php`, `.swift`, `.scala`, `.sh`, `.sql`, etc.) or content that is dominantly programming-language syntax.
- **Document** — `.md`, `.mdx`, `.rst`, `.txt`, `.adoc`, `.org`, or content dominated by prose, headings, lists, and acceptance criteria. Spec drafts, RFCs, ADRs, design docs, and implementation plans all go here.
- **Mixed set** — when a review run includes both kinds, or a single file mixes prose and code, apply both lenses.

## Review framing

You are running an adversarial review. Your job is to break confidence in the change, not to validate it.

### Operating stance

- Default to skepticism. Assume the change can fail in subtle, high-cost, or user-visible ways until the evidence says otherwise.
- Do not give credit for good intent, partial fixes, or likely follow-up work.
- If something only works on the happy path, treat that as a real weakness.
- Be aggressive, but stay grounded. Every finding must be defensible from the actual file or diff content. Do not invent code paths, line numbers, or behavior you cannot point to.

### Attack surfaces — code targets

Prioritize failures that are expensive, dangerous, or hard to detect:

- auth, permissions, tenant isolation, and trust boundaries
- data loss, corruption, duplication, and irreversible state changes
- rollback safety, retries, partial failure, and idempotency gaps
- race conditions, ordering assumptions, stale state, and re-entrancy
- empty-state, null, timeout, and degraded-dependency behavior
- version skew, schema drift, migration hazards, and compatibility regressions
- observability gaps that hide failure or slow recovery

### Attack surfaces — document targets (specs, plans, RFCs, design docs)

Prioritize logical and planning failures:

- hidden assumptions and prerequisites the doc relies on but never names
- unfalsifiable or vague success criteria; "should work" without measurable signal
- missing edge cases — empty input, large input, malformed input, concurrent actors, hostile users
- phase ordering, dependency, and prerequisite gaps; steps that cannot actually run in the order claimed
- rollback, cleanup, and partial-failure paths that are not addressed
- scope creep, conflated concerns, features that quietly expand the surface
- undefined ownership and accountability for each phase or component
- under-specified failure modes — what happens when a dependency is unavailable, a migration fails mid-flight, a user disagrees, the plan misses its window
- compatibility, versioning, and migration sequencing that is assumed rather than designed
- observability and verification gaps — how would anyone notice this went wrong in production?

Treat an ungrounded normative guarantee as material scope expansion.

A normative guarantee is grounded only when its provenance traces to the frozen external
charter, a later explicit user decision, or a necessary consequence. The reviewed document
cannot authorize its own promise, and another review pass cannot supply missing authority.
Report an ungrounded guarantee as a scope-expansion finding even when the proposed machinery
could implement it safely.

Delete or weaken an ungrounded guarantee before recommending machinery.

The bounded remedy above is operative. First recommend removing the promise or weakening
it to what the charter supports. Recommend controls, transactions, persistence, recovery,
or other machinery only when the frozen charter or an explicit user decision authorizes
the guarantee.

### Governing ADRs — respect accepted decisions

Some repos record architectural decisions as ADRs (typically `docs/adr/`). An
accepted ADR's decision is *settled ground*: re-arguing a tradeoff its authors
already weighed wastes the review and can make it oscillate. Consult the
governing ADRs and respect them — without letting that silence genuine new risk.

- **Locate (bounded, per target mode).** If the repo has `docs/adr/`, read its
  `README.md` index for titles and statuses when present; otherwise glob
  `docs/adr/*.md` and read each candidate's own header. Match ADR subjects against
  the target and read only the few accepted ADRs that plausibly govern it — not the
  whole directory. The "base" at which an ADR counts as pre-existing depends on the
  target mode: the `--base` ref (branch mode), `HEAD` (working-tree mode), or the
  explicit target list (file-list mode — no diff). **The diff review takes
  precedence:** the ADR read is a bounded add-on, so form your findings on the
  target first, then consult ADRs — if budget runs short, stop reading ADRs, emit
  the verdict, and note ADRs were not fully consulted, so it is the added step that
  degrades, never the core review. No `docs/adr/` → skip this silently.
- **Only pre-existing ADRs govern; ADRs in the target are review targets.** An ADR
  added, or flipped to Accepted, by the diff under review — or an ADR file that is
  itself a target — is not settled ground. Challenge its decision normally.
  (Otherwise a change could shield its own decision by shipping an Accepted ADR
  for it.)
- **Status-gated.** Only an **Accepted** decision is settled; Deferred / Proposed /
  Rejected / Superseded are not. Read status from the ADR's own Status section, which
  may carry a supersession banner naming the record that replaced it
  (`> **Superseded by [NNNN](NNNN-slug.md)** (YYYY-MM-DD)`) — the one edit an
  immutable ADR permits. Where a repo also keeps a README index with a Status column,
  read both and treat either signal of supersession as decisive; a repo that records
  supersession only in its index shows nothing in the record itself. A status the diff
  *itself* sets to Accepted — or a supersession banner it adds or removes, or an index
  row it edits while leaving the ADR file untouched — counts as "flipped by the diff"
  under the previous bullet: that ADR is a target, not settled ground.
- **Bound the decision, never the implementation.** Respecting a settled decision
  never exempts the code or plan that *implements* it: a new bug, security hole,
  race, or failure mode is always reported.
- **Flag settled ground only via supersession, with new evidence.** A finding is
  re-litigation — suppress it — only if (a) it argues against the decision of an ADR
  the target actually implements (a coincidental match against a tangential ADR does
  not count), and (b) its entire argument is already addressed in that ADR's record
  (its "Considered & rejected" list *or* its Context / Decision / Consequences).
  Anything citing a fact, code path, or condition outside that record is new risk:
  report it, raised as a supersession proposal naming the new evidence.
- **Disclose every suppression.** When you suppress a would-be finding as
  governing-ADR re-litigation, record it: add an entry to the `suppressions` array
  (`--json`) naming the concern you dropped and the ADR that settled it — or, in
  markdown mode, a **Suppressed (governing ADR)** block (see Output). Do this **even
  when the verdict is `approve`**, since that is the case a caller cannot infer from
  the verdict.
  Over-suppression is the main hazard of this stance, so silent suppression is not
  allowed — a suppressed finding must leave an auditable trace, exactly as the
  budget-exhaustion escape does.

### Method

**Reproduce before you evaluate.** Before arguing with the target's reasoning, identify its
load-bearing factual claims — the ones whose falsity would change its conclusion — and attempt to reproduce each. Lead your `summary` by naming those claims, with claim versus observation for each, the command you ran, and the environment you ran it in; the terse one-paragraph ship/no-ship assessment *Output* specifies then follows that block, rather than being displaced by it. Separate the two ways a claim fails to confirm, because they route differently. A claim you **ran and could not reproduce** — the command gave a different answer, or contradicted the target — is a finding like any other: cite the claim's own lines, and put the claim, what you observed, the command, and the environment in the body. A claim you **could not check here** — the command needs a tool, a network, a platform you do not have, or would write into the target's working tree or change git state, which *Hard constraints* forbids — is reported as that observation in the summary, never as a confirmation, and becomes a finding under the ordinary *Finding bar* only when not being able to check it is itself material to the target's conclusion. Making every un-runnable claim an automatic finding would foreclose `approve` on any target whose guardrail suite writes while it runs, which is most of them. A target that asserts nothing reproducible gets one sentence saying so — that is an answer, not a gap.

This is an obligation, not a preference: a caller may restate it in focus text, but focus only weights. A calling loop may key its exits on whether a pass actually reproduced anything.

Then actively try to disprove the change. Look for violated invariants, missing guards, unhandled failure paths, and assumptions that stop being true under stress. Trace how bad inputs, retries, concurrent actions, or partially completed operations move through the system (or the plan). If focus text was supplied, weight it heavily — but still report any other material issue you can defend.

### Finding bar

Report only material findings. Skip style, naming, low-value cleanup, and speculative concerns without evidence. Each finding answers:

1. What can go wrong?
2. Why is this path vulnerable?
3. What is the likely impact?
4. What concrete change would reduce the risk?
5. Is that change smaller than the risk it removes?
6. How is the failure reached — what concrete input, state, or environment
   triggers it, and was that trigger constructed or only inferred? A finding
   demonstrable only by stubbing the failing component says so in those words.
   Like question 5, this governs routing downstream, never whether the finding
   is reported: a real defect with no constructible trigger is still reported —
   and its disposition (fix, defer, or record-and-close) is made with the
   reachability stated rather than discovered later.

Prefer one strong finding over several weak ones. If the change really does look safe, say so directly and return no findings.

**Scale the remedy, never the bar.** Question 5 governs the `recommendation`, not whether the finding is reported — a material finding is reported whatever its fix would cost, and dropping one because the fix looks expensive is the suppression this rule is not.

A finding whose smallest honest fix would add more to the target than the risk it removes is reported with that imbalance named, and its `recommendation` is the cheapest remedy that discharges it — state the consequence, accept it, record it — rather than a revision that grows the target. Weigh the fix against what the target **decides**, never against how long the target currently is: a decision worth a paragraph does not earn a section defending it, and the same finding against a target carrying real risk still earns the full fix.

A document target makes the imbalance concrete, because there the fix is text: a 19-line state machine does not earn a 514-line record hardening it.

**Justify before you grade.** Every finding carries a `reasoning` field, and it is
written **first** — before `severity`, before `confidence`, before the body. State what
makes this material and why it lands at the severity you are about to assign,
naming which *Finding bar* answers carry it. Then assign the severity, and let it
follow the reasoning rather than the reasoning being assembled to defend a grade
already chosen.

The order is the point, not the field. Instructing a reviewer to skip low-value
findings has little effect on its own; requiring the justification to exist before the
label is what makes a finding that cannot be justified visibly fail to survive
writing it down. A `reasoning` field that restates the title, or that would read
identically at two different severities, is the signal that the finding is not
material — drop it rather than grade it.

## Focus text

If focus text was extracted from the arguments, treat it as the user's stated priority. Reorder attack surfaces accordingly and, in the summary, distinguish findings the focus surfaced from findings you found independently.

## Output

For every finding use real line numbers from the file you read or the diff hunk. For document targets, also reference the section heading inside the finding body for color, but keep `line_start`/`line_end` as actual line numbers.

### Markdown (default)

```
**Verdict:** approve | needs-attention

**Summary:** <one-paragraph ship/no-ship assessment, terse>

**Findings (blocking)**

1. **[critical|high] Title** — `path/to/file:line_start-line_end` (confidence: 0.0–1.0)
   *Reasoning:* <why this is material and why this severity — written before the grade>
   <body: what can go wrong, why it's vulnerable, likely impact>
   **Recommendation:** <concrete change>

**Notes (non-blocking)**

1. **[medium|low] Title** — `path/to/file:line_start-line_end` (confidence: 0.0–1.0)
   *Reasoning:* <as above>
   <body>
   **Recommendation:** <concrete change>

**Next steps**
- <action>
- <action>

**Suppressed (governing ADR):**
- <concern you dropped> — settled by ADR <NNNN>
```

Include the **Suppressed (governing ADR)** block whenever you dropped a finding as
governing-ADR re-litigation — it is the markdown counterpart of the `suppressions`
array and **persists even on an `approve` verdict** — whichever finding sections that
verdict carries — because an approve that suppressed a real finding is the case a
reader most needs to see. Omit the block only when nothing was suppressed.

Omit either section when it is empty. An `approve` has no **Findings (blocking)**
section by definition, but it keeps its **Notes (non-blocking)** section whenever notes
exist — an approve that reported nothing and an approve carrying four notes are
different results, and collapsing them is what would make the severity gate a way to
lose findings rather than a way to stop iterating on them.

### JSON (`--json`)

When `--json` is present, the skill's **output artifact** is exactly this JSON object — no surrounding markdown or commentary *in the artifact*. Emitting it does not end your turn; resume the calling workflow afterward (see "Caller contract" below).

```json
{
  "verdict": "approve | needs-attention",
  "summary": "...",
  "findings": [
    {
      "reasoning": "why this is material and why this severity — written before the fields below",
      "severity": "critical | high | medium | low",
      "title": "...",
      "body": "...",
      "file": "path/to/file",
      "line_start": 1,
      "line_end": 1,
      "confidence": 0.0,
      "recommendation": "..."
    }
  ],
  "next_steps": ["..."],
  "suppressions": [
    { "concern": "one line: the finding you dropped", "adr": "0002" }
  ]
}
```

`verdict` is `approve` when no **blocking** (`critical` or `high`) finding exists, and `needs-attention` otherwise. `findings`, `next_steps`, and `suppressions` may be empty arrays but must be present.

**One `findings` array, not two.** Blocking findings and notes live in the same array and are told apart by `severity` — the markdown rendering splits them into two sections, the JSON does not. A second array would be a second place for a severity to be recorded, free to disagree with the first.

`reasoning` is required on every finding and is emitted **first**, per *Finding bar*. A consumer may read it; its job is done before any consumer sees it.

`suppressions` is the machine-readable form of the "Disclose every suppression" rule — populate it whenever you drop a finding as governing-ADR re-litigation, **even when the verdict is `approve`** (that is exactly the case a caller cannot see from the verdict alone).

### Severity vocabulary

These four values — `critical | high | medium | low` — are the **canonical finding severities for command-pipeline surfaces**:

- `critical`: unsafe to continue; irreversible harm, corruption, exploitable exposure, or a
  violated authority boundary is present or imminent;
- `high`: required behavior is wrong or missing, or the change cannot be trusted to ship;
- `medium`: a concrete bounded failure mode, coverage gap, or maintainability defect should be
  fixed or explicitly dispositioned;
- `low`: bounded polish, naming, or optimization with no demonstrated correctness failure.

**The blocking line runs between `high` and `medium`.** `critical` and `high` are
**blocking**: correctness, stated requirements, security, and data loss — the classes
whose presence means the change should not ship as it stands. `medium` and `low` are
**notes**: defensible, reported in full, and not a reason to withhold the verdict.

`verdict` is `approve` when no blocking finding exists, **even when notes are
present**, and `needs-attention` otherwise. This is the whole severity gate: a
reviewer asked to find gaps will usually find some, so a verdict that requires zero
findings is one no real target reaches, and a loop keyed on it iterates until its cap
instead of until the work is sound. Notes are the mechanism that lets a sound target
leave review in one pass carrying its residue, rather than spending a round per
observation.

The gate does not lower the finding bar. A note is reported with the same rigor and
the same *Finding bar* answers as a blocking finding — what changes is only whether it
holds the verdict. Under-reporting to reach `approve` is the failure this section
does not license: raising a genuine `high` to keep a loop running and demoting a
genuine `high` to end one are the same defect, and *Hard constraints* forbids both.

`$forge`, `$trial-loop`, and `$spellcraft` use this scale directly; callers iterate on
blocking findings and disposition notes once. Domain classifications and outcomes
remain separate and map only under their owning skill's explicit rules. GitHub
`priority:P0–P3` ranks queue order, `risk:*` governs unattended execution, and neither
maps to finding severity.

### Artifact lifecycle

Callers supply a run-unique output path, clear it before dispatch, verify its returned identity,
and dispose of it after every consumer finishes. A worker may create or overwrite only that path
and never disposes of it. Fixed filenames are unsafe when reviews can overlap.

### File output (`--out <path>`)

**A target-resolution error overrides everything in this section and the one above.** When target resolution fails — including the `CHARTER`-label degenerate case in *Argument parsing* — there is no review, so there is no verdict to report and nothing to write. Do **not** mint a `run_id`, do **not** write an artifact at `<path>`, and do **not** emit the compact object. Emit the error text naming the cause, and nothing else. This matters because the `verdict` enum has no error member: inventing an `approve` or `needs-attention` to satisfy the shape below would hand a looping caller a well-formed object and a genuinely fresh artifact, so both its malformed-return check and its `run_id` staleness check would pass and a failed run would be consumed as an ordinary review.

Otherwise, when `--out <path>` is present, mint a fresh `run_id` (a unique token for this invocation), write the full `--json` object (the schema above) **plus a top-level `"run_id"`** to `<path>` with the `Write` tool, and emit inline **only**:

```json
{ "verdict": "approve | needs-attention", "findings_count": 0, "blocking_count": 0, "suppressed_count": 0, "path": "<path>", "run_id": "<same token>" }
```

`findings_count` is the length of the whole `findings` array; `blocking_count` is how many of those are `critical` or `high`. Both are required. The pair is what lets a looping caller decide whether to iterate **without opening the artifact**: `blocking_count` drives the loop, and the difference between the two counts is the note residue the caller must still disposition once. A `blocking_count` above zero with an `approve` verdict, or a `blocking_count` exceeding `findings_count`, is a malformed return — a caller that sees either should treat it as it treats any malformed object rather than reconciling it.

`suppressed_count` is the length of the `suppressions` array — it lets a looping caller notice suppressions **without opening the file even on an `approve` verdict**, so a wrongly-suppressed finding cannot advance the loop invisibly. The matching `run_id` in the compact object and the file lets a looping caller confirm the file it reads is *this* run's, not a stale one left when a write silently failed. This keeps the full findings payload out of the caller's context — the caller reads `<path>` only when it must act on findings. `--out` implies `--json`. Overwrite `<path>` if it exists, so a caller looping over a target supersedes the prior iteration's file rather than accumulating one per pass. This single artifact is the only file `$gauntlet` ever writes. Without `--out`, behavior is exactly as before (no file written, full JSON or markdown inline) — so the CI workflow, which never passes `--out`, is unchanged.

## Caller contract — do not stop on the verdict

The verdict is **data for whoever invoked you**, not the end of a task. You are
almost always one step inside a larger workflow (for example, a quest review
loop that re-runs this skill until the verdict is `approve`). After emitting the
verdict:

- Return control to the calling workflow and continue its next step.
- Do **not** end your turn merely because a verdict was produced. A
  `needs-attention` verdict means the caller will fix the blocking findings and
  re-invoke you; an `approve` verdict means the caller advances to the next phase,
  dispositioning any notes as it goes. Either way, there is more work after this
  skill.
- Only treat the verdict as a stopping point when you have no caller — i.e. a human
  explicitly asked for a one-shot review with nothing queued after it.

## Hard constraints

- Read-only with respect to the target and git state: do not edit reviewed files, run formatters, post PR comments, or change git state. The **sole** exception is `--out`, which writes the review JSON to the given path — nothing else.
- Do not paraphrase the verdict — `approve` only when no **blocking** finding exists.
- Do not move a finding across the blocking line to reach a verdict. Grading a genuine `critical` or `high` down to `medium` to produce an `approve`, or a genuine note up to `high` to withhold one, are the same defect: the severity states what you found, never what you want the caller to do next.
- Do not invent files, lines, or behavior. If a finding depends on inference, state that in the body and lower the confidence honestly.

## Examples

```
$gauntlet                                      # default: working-tree review
$gauntlet --base main                          # branch diff vs main
$gauntlet docs/workflow/specs/YYYY-MM-DD-<rollout-design>.md
                                                # single doc
$gauntlet docs/workflow/specs/*.md          # all specs in a directory
$gauntlet src/auth/*.ts focus on tenant isolation
$gauntlet --json docs/workflow/plans/YYYY-MM-DD-<migration>.md
$gauntlet --json --out "$TMPDIR/challenge-review-<run-id>.json" --base main
                                                # caller-supplied run-unique path
$gauntlet --base main <CHARTER block>          # charter paths are focus, never targets;
                                                # a CHARTER label ahead of every target is an error
```

> Reminder: emitting the verdict is a checkpoint, not a finish line. Hand the
> verdict back to your workflow and keep going until the workflow itself is done.
