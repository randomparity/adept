# Reproduce before evaluating, and exit a verified-sound target — implementation plan

Goal: `$trial-loop`'s dispatch requires the reviewer to reproduce the target's load-bearing
factual claims before evaluating its argument, and the loop gains a *sound with record
notes* exit so a finished target stops reporting `blocked` at the cap.

Architecture: prose contracts only. `$trial-loop` is the authority; `$quest` and
`$spellcraft` name the new exit to route on it. No executable code, no schema change, no
gate.

Design: `docs/workflow/specs/2026-08-18-trial-loop-reproduce-and-sound-exit-design.md`.
Decision: `docs/adr/0020-reviews-reproduce-claims-and-exit-when-sound.md`. Issue: #138.

## Global Constraints

- Repository anatomy rule 4: **nothing automated asserts on prose**. Do not add a gate,
  test, or grep that checks for any sentence this plan inserts.
- `$gauntlet`'s finding schema, severity scale, verdict enum, and the loop's compact object
  `{verdict, findings_count, suppressed_count, path, run_id}` are unchanged. No new fields.
- The exit is named **sound with record notes**, in italics, everywhere it appears. It must
  not be confused with `rejected-with-evidence`, which is a per-finding disposition.
- The reproduction **obligation** is stated in `$gauntlet`'s Method; `$trial-loop`'s step 1
  transmits the same instruction with the focus and names `$gauntlet` as its authority. Do
  not copy it into `$quest`'s or `$spellcraft`'s focus texts.
- `docs/debt/` is outside the permitted surface. Write no deferral record; do not touch the
  `records` recipe.
- Public repository: no host paths, hostnames, or session state. The checkout root is
  `$WORK`.
- Guardrail: `just verify`, run bare. `git push` runs a pre-push hook that re-runs the whole
  suite in an isolated worktree and takes several minutes — background it.
- Conventional commits, imperative subject ≤ 72 chars, one logical change each, ending with
  the `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>` trailer.

## Task 0 — state the reproduction obligation in `$gauntlet`'s Method

File: `skills/gauntlet/SKILL.md`, section *Method* (the paragraph beginning "Actively try to
disprove the change").

### Step 0.1 — add the obligation

Add a short paragraph to *Method*, before or after the existing one, requiring the reviewer
to identify the target's load-bearing factual claims — the ones whose falsity would change
its conclusion — attempt to reproduce each, and lead `summary` by naming those claims with
claim versus observation, the command run, and the environment. State that a claim it
cannot reproduce is a finding under the ordinary bar; that a command it cannot run is
reported as that observation, never as a confirmation; that reproduction is read-only under
*Hard constraints* (`:344`), so anything that would write into the target's working tree is
reported rather than run; and that a target asserting nothing reproducible is answered in
one sentence.

This is the binding statement. It must not be phrased as a focus-text preference — the
whole reason it lives here is that `:199` and `:226-228` make focus advisory.

### Step 0.2 — verify and commit

`just verify` bare, exit 0. Commit as
`feat(gauntlet): reproduce load-bearing claims before evaluating`.

## Task 1 — transmit the instruction from `$trial-loop`'s dispatch

File: `skills/trial-loop/SKILL.md`. Anchor: the paragraph in step 1 beginning "Ask the
reviewer to report an excluded concern".

### Step 1.1 — amend the "nothing else" clause and add the instruction

Replace this paragraph:

> Ask the reviewer to report an excluded concern **only** when it invalidates
> the target, the target makes it worse, or its deferral has no evidence or
> owner. Supply the target, charter, and focus — and nothing else. No prior
> verdicts, no finding history, no intended fixes: each pass must be naive apart
> from the dependencies and exclusions the current charter records, or you are
> grading the reviewer's memory instead of the target.

with the same paragraph amended to name the reproduction instruction as supplied rather
than prohibited, and to say that what "nothing else" forbids is the run's own history —
followed by the standing instruction as an indented block quote, then short paragraphs
covering (a) that the loop **appends the instruction to the focus it transmits**, so it
lands in the `focus:` field of the `CHARTER` block and in the focus position of the
arguments, leaving the block's eight-fields-plus-focus invariant intact; (b) that the
report rides in `summary` and the failures ride in `findings`, so no schema changes; and
(c) that reproduction is what the *sound with record notes* exit keys on, so a run with no
reproducing pass behaves exactly as before.

The block quote asks for, in order: identify the load-bearing factual claims (the ones
whose falsity would change the conclusion); attempt to reproduce each; lead `summary` with
the claims **named**, claim versus observation, and the command and environment; file an
unreproducible claim as an ordinary finding citing the claim's lines with claim,
observation, command, and environment in the body; report a command that cannot be run here
as that observation and never as a confirmation; answer a target that asserts nothing
reproducible in one sentence.

The instruction must also state the **read-only bound**: reproduction is inspection plus
commands that write nothing into the target's working tree. `skills/trial-loop/SKILL.md:301`
and `skills/gauntlet/SKILL.md:344` make the reviewer read-only with respect to the target
and git state with `--out` the sole write exception, and this change creates no second one.
Say why in one clause: in working-tree mode the target is resolved from `git status` and
the self-collision baseline is a `git stash create` snapshot, so reviewer-written files
would become the next pass's target and inflate the loop's convergence signal.

Leave the following paragraph ("One exception is structural rather than optional…")
untouched — the deferral-record disclosure exception still stands.

### Step 1.2 — verify

Run `just verify` bare. Expect exit 0.

### Step 1.3 — commit

`feat(trial-loop): require reproducing claims before evaluation`

## Task 2 — add the *sound with record notes* exit

File: `skills/trial-loop/SKILL.md`, section *Stop conditions*.

### Step 2.1 — insert the new bullet

Insert a new bullet immediately after the *converged with deferrals* bullet (the one ending
"Report it distinctly — it is not `approve` — and list the records.") and before the
final-budgeted-iteration bullet. The new bullet states:

- the trigger: a pass **named** the load-bearing claims it reproduced and reported each
  confirmed, nothing changed since has altered what those claims assert, and every standing
  finding is consequence-free;
- that named claims are required, not a verdict about claims — a pass answering "this
  target asserts nothing reproducible" satisfies the instruction but not this condition,
  and such a target leaves through `approve`, *converged with deferrals*, or the cap as it
  does today;
- the consequence test as three questions — does the decision the target records change,
  does any behaviour change, would a future maintainer acting on the target as it stands do
  something different — with one yes cancelling the exit;
- **the worked negative case**, in its own paragraph: the test is on consequence and never
  on subject matter; "it is only about wording" is not the trigger; the branch review whose
  top finding was about ADR prose that would have led a maintainer to delete a load-bearing
  line answers yes on the third question and is consequential;
- the no-edit precondition, with the same reason *converged with deferrals* gives: a pass
  that applies a fix is never the pass that exits;
- that it is an ordinary run-ending exit inheriting the section's on-every-exit obligations
  in full — working-tree guardrails and commit, suppression disclosure, deferral disclosure;
- distinct reporting, the note list, and precedence: the rescope and self-collision exits
  outrank it (they carry obligations it does not), and it outranks *converged with
  deferrals* where both apply.

### Step 2.1a — correct the stale exit counts

"all four exits" appears **three** times, at `skills/trial-loop/SKILL.md:268`, `:477`, and
`:505` — the third wrapping a line break, so a line-anchored grep finds only two. Find them
with `rg --no-config -n --multiline --multiline-dotall 'all four\s+exits'
skills/trial-loop/SKILL.md`, or by reading the section. Replace all three with "every
exit". The `:505` site is the one scoping suppression and deferral disclosure, which the
new exit inherits, so missing it is the failure this step exists to prevent.

### Step 2.2 — amend the cap bullet

Append to the final-budgeted-iteration bullet a sentence saying it fires when a standing
finding is still consequential, that the two conditions are a pair, and that `blocked` at
the cap stays the honest outcome whenever consequence-bearing work is outstanding — however
many passes confirmed the mechanism.

### Step 2.3 — extend *What to report back* and the caller contract

In *What to report back*, require naming the exit when the run took it, listing the notes,
and naming the claims a pass reproduced and confirmed.

In *Caller contract — do not stop on the verdict*, add that a *sound with record notes*
exit means the caller advances, carrying the notes into its own report.

### Step 2.4 — verify and commit

`just verify` bare, exit 0. Commit as
`feat(trial-loop): exit a verified-sound target with record notes`.

## Task 3 — teach the callers the new exit

### Step 3.1 — `$spellcraft`

File: `skills/spellcraft/SKILL.md`, step 2, the sentence beginning "If the loop blocks
(5 iterations without `approve`)". Restate the blocked condition as five iterations with a
consequential finding standing, then add that a *sound with record notes* exit is not that
case: continue to the spec review and carry the notes into the design record.

### Step 3.2 — `$quest`

File: `skills/quest/SKILL.md`. Two edits:

- the preamble sentence "As a background subagent, an `approve` from the review loop means
  proceed now, not wait" — add the new exit alongside `approve`;
- step 6, after "Address every defensible finding and commit after each accepted fix" —
  add that *sound with record notes* is a non-blocking outcome whose notes go into the
  review summary, and therefore into `WORK:REVIEW` and the pull request.

### Step 3.3 — verify and commit

`just verify` bare, exit 0. Commit as
`feat(quest,spellcraft): route on the sound-with-record-notes exit`.

## Task 4 — records

The ADR and the design doc are written before the build (they are this change's design
phase) and committed first. No index row: `docs/adr/README.md` deliberately carries no
index table and the records gate warns if one appears.

## Rollback

Every change is additive prose in four Markdown files plus two new records. Reverting the
three feature commits restores the prior contract exactly; the ADR, being merged, would be
superseded rather than deleted.
