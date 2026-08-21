# Budget-stop resume path — implementation plan (issue #151)

**Goal:** make an operator-approved continuation of a `$trial-loop` budget stop a defined,
documented path in `$quest`, unlocking `exit: blocked-at-budget`.

**Architecture:** prose contracts in two skill files, amended by ADR 0029; one sentence of
cross-reference in `$trial-loop`; one corrected paragraph in ADR 0021; a MINOR version
bump. No executable code changes.

**Tech stack:** Markdown skill documents; `just` guardrails; bash test suites (untouched).

## Global Constraints

- BASE_BRANCH: `main`; branch `feat/budget-stop-resume-151`; worktree outside the repo
  tree at `../adept-worktrees/<branch>` per the quest worktree-placement rule.
- Guardrails: `just verify` (full), `just commit-check` (per commit). Zero warnings.
- Version bump required every change (ADR 0022): 1.1.1 → 1.2.0 (MINOR — a skill gains a
  capability).
- No ADR index exists; write only ADR files, never index rows (W-INDEX-TABLE).
- Scope charter: `WORK:SCOPE` token `q151-bc69251f` on issue #151. Exclusions: no changes
  to `skills/quest/scripts/publish-forge-review` or its test fixture; no bards-tale edits;
  no merge.
- Design authority: ADR 0029 (this branch), spec
  `docs/workflow/specs/2026-08-21-budget-stop-resume-design.md`.
- Style: match surrounding prose — ~80-char wrapped lines, em-dash house style, no
  trailing whitespace.

## Files

| File | Responsibility |
|---|---|
| `skills/quest/SKILL.md` | resume path (step 6 subsection), summary unlock (step 8 bullet), payload admission (step 8 trigger + payload definition), park pointer (On a Blocker) |
| `skills/trial-loop/SKILL.md` | one pointer sentence in the caller-contract budget bullet |
| `docs/adr/0021-review-summary-names-the-trial-loop-exit.md` | correct the row-5 hold paragraph |
| `.claude-plugin/plugin.json` | version bump |
| `docs/adr/0029-…`, `docs/workflow/specs/…`, `docs/workflow/plans/…` | already/being committed design record |

## Task 1 — `$quest` step 6: the approved-continuation subsection

**File:** `skills/quest/SKILL.md`

**Interfaces:** consumes the loop's cap bullet semantics (`skills/trial-loop/SKILL.md`
"Final budgeted iteration … without explicit user approval") and the park protocol in
*On a Blocker*. Later tasks rely on the subsection's name ("Approved continuation from a
budget stop") and on it adding the remaining-findings summary to the carry list.

Insert a new `###` subsection immediately after the paragraph ending "…exits *sound with
record notes*, which is not blocked." (the iteration-budget paragraph), before the "When
step 4 ran" paragraph:

```markdown
### Approved continuation from a budget stop

When the loop stops blocked at the iteration budget, the park protocol at the end of this
skill applies: a `WORK:TRAJECTORY` note, then `status:needs-human`. That stop is not
terminal. The operator may approve continuing, and this subsection defines the resume:

- **Approval** is an explicit human decision from the operator who received the park,
  naming the parked run (issue, branch, or PR) and directing continuation past the budget
  stop. It reaches the run as an interactive reply in the resuming turn, a durable record
  on the issue or PR, or an explicit term of the dispatch that resumes the work. Silence,
  absence, or another agent's "keep going" is not approval.
- **On approval**, post a fresh complete `WORK:TRAJECTORY` recording it — who approved,
  where the approval is recorded, and what it authorized — then swap
  `status:needs-human` → `status:in-review` in a single-active edit. Record before label:
  the same exit-edges discipline the park itself followed.
- **Resume at step 7** (Simplify). The approval alone never re-enters the loop —
  `$trial-loop`'s caller contract forbids a budget-stopped run from re-entering — so the
  budget stop stands as the run's ending. One exception, already governed: if a settled
  obligation yields an accepted fix that changes behavior, step 6's round-trip rule runs
  one more loop pass and ADR 0021's replacement rule rewrites the run fields from that
  ending. Before simplification, settle whatever step-6 obligations
  the stop cut short: the security pass above all, judged and dispositioned under step 6's
  Security-pass terms (below in that skill), recording `security: not triggered` where its
  trigger does not fire.
- **Carry the stop's disclosure** into step 8's payload destinations: the three lists this
  step already carries (deferrals with their owning records, outstanding notes, confirmed
  claims) plus the remaining-findings summary the cap bullet makes the stop produce. In
  the ordinary case — no behavior-changing settlement — the summary writes
  `exit: blocked-at-budget`, per step 8 and ADR 0021.
```

**Acceptance:**
- `grep -n "Approved continuation from a budget stop" skills/quest/SKILL.md` finds the
  heading once, inside step 6 (between `## 6.` and `## 7.`).
- The subsection names approval, transitions, re-entry step, carry, and the exit value.

**Verify:** `just shape-check public-safety` exit 0. Commit:
`docs(quest): document the approved-continuation resume path in step 6`.

## Task 2 — `$quest` step 8: unlock the exit value and admit the fourth list

1. Replace the `blocked-at-budget` bullet (currently "…Not writable until issue #151
   documents that resume path; until then such a run parks and publishes no summary.")
   with:

```markdown
- `blocked-at-budget` — a run stopped as blocked at the iteration budget, then continued
  through step 6's approved-continuation resume path. `verdict:`, `findings:`, and
  `iterations:` describe that stopped run; the approval is its aftermath, not a second
  ending.
```

2. In the paragraph beginning "ADR 0021 is the authority for the field set…", the payload
   sentence enumerates "deferrals with their owning paths or tracker issues, outstanding
   notes, the confirmed claim list". Replace that enumeration with "the lists step 6
   carries — deferrals with their owning paths or tracker issues, outstanding notes, the
   confirmed claim list, and a budget stop's remaining-findings summary —" so the payload
   definition and the trigger cannot drift apart.

3. Widen the composition trigger: "If step 6 carried a deferral list, outstanding notes,
   or a confirmed claim list, compose the run's payload file once…" becomes "If step 6
   carried any of the lists it specifies — a deferral list, outstanding notes, a confirmed
   claim list, or a budget stop's remaining-findings summary — compose the run's payload
   file once…".

**Acceptance:** `grep -n "Not writable until issue #151" skills/quest/SKILL.md` finds
nothing; the trigger names the fourth list; the payload definition references step 6's
specification.

**Verify:** `just shape-check public-safety` exit 0. Commit:
`docs(quest): make blocked-at-budget writable, admit findings summary`.

## Task 3 — `$quest` On a Blocker: the resume pointer

**File:** `skills/quest/SKILL.md`. **Consumes:** Task 1's subsection.

Append to the `status:needs-human` bullet: "A `$trial-loop` budget stop parks here too,
and it is the one park with a defined resume: step 6's approved-continuation path."

**Acceptance:** the bullet names the resume; no other blocker type claims one.

**Verify:** `just shape-check public-safety` exit 0. Commit:
`docs(quest): point the needs-human park at the resume path`.

## Task 4 — `$trial-loop` caller contract + ADR 0021 amendment

**Files:** `skills/trial-loop/SKILL.md`, `docs/adr/0021-review-summary-names-the-trial-loop-exit.md`.

1. In the caller-contract bullet "A run stopped as blocked at the iteration budget does
   not re-enter the loop, and the caller does not advance without explicit human
   approval.", append: "An approval that advances the caller belongs to the caller's own
   contract — `$quest` documents the approved-continuation resume path in its step 6."

2. In ADR 0021's row-5 paragraph, replace "`$quest` documents no such resume today — issue
   #151 — so **`blocked-at-budget` may not be written until it does**, and until then a
   run stopped at the budget parks and publishes no summary at all." with: "ADR 0029 now
   documents that resume path — the approved continuation this row already describes — so
   **`blocked-at-budget` is writable for exactly such a run**, published once at step 8
   like every other value; before it landed, a run stopped at the budget parked and
   published no summary at all." Leave the rest of the paragraph, including the
   "value is fixed here so the change that adds the path has one to use" sentence,
   verbatim. No Superseded-by banner: 0021 keeps its accepted status (ADR 0028's pattern).

**Acceptance:** `grep -n "may not be written until" docs/adr/0021-….md` finds nothing;
`grep -n "ADR 0029" docs/adr/0021-….md` finds the corrected sentence; the trial-loop
bullet names quest's step 6 without restating its semantics.

**Verify:** `just records shape-check` exit 0. Commit:
`docs(trial-loop): point approved continuations at quest's resume path`.

## Task 5 — version bump and full guardrails

**File:** `.claude-plugin/plugin.json`: `"version": "1.1.1"` → `"1.2.0"`.

**Acceptance:** `jq -r .version .claude-plugin/plugin.json` prints 1.2.0.

**Verify:** `just verify` exit 0 (records gate now covers ADR 0029; plugin-check
`--strict` passes with the new version). Commit:
`chore: bump version to 1.2.0 over main's 1.1.1`.

**Cross-reference read-through (spec Verification).** After the last edit lands, read each
location the new text points at and confirm it matches what the prose claims: quest step 6
subsection → step 8's exit list and payload trigger; quest *On a Blocker* → step 6's
subsection; trial-loop caller bullet → quest step 6; ADR 0021's corrected sentence →
ADR 0029. Any mismatch is fixed before `just verify` runs, not deferred.

## Rollback

Each task is an independent commit; `git revert` per commit restores the prior contract.
No generated artifacts, migrations, or external state exist.
