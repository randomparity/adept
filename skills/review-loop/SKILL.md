---
name: review-loop
description: "Iteratively run an adversarial challenge review, fix or disposition defensible findings, write deferral records when needed, and re-review until approved or bounded stop conditions fire. Use for code, diffs, specs, ADRs, plans, and pre-ship review loops."
---
# Adversarial Review Loop

Run `$challenge` against a target iteratively, fixing findings between passes,
until it returns `approve` or 5 iterations are exhausted. This is both a
standalone skill and a subroutine of `$work-issue` and `$design`.

Input: pass through the user-supplied challenge target and focus text.

The arguments are passed through to `$challenge` verbatim as the challenge
target and optional focus text. This skill adds `--json --out <findings-path>`
automatically: `$challenge` writes the full findings to `<findings-path>` and
returns only `{verdict, findings_count, suppressed_count, path, run_id}`, so the
loop's context carries verdicts, not payloads. Derive `<findings-path>`
deterministically from a hash of the **target and flag tokens** in the supplied challenge arguments plus a
run token you mint once at the start of the run and reuse for every iteration (stable
across iterations, unique per target — including `--base`-only reviews with no path
token). The run token matters when two loops run concurrently against the same target, as
`$campaign` does across parallel issues: without it both derive the same path, and each
pass overwrites the other's artifact while the `run_id` assertion reports a stale write
neither loop caused. The charter block (below) is appended to the invocation but is
**not** part of that hash, so the path stays stable even if the charter is
restated. If a caller typed a `CHARTER` block into the supplied challenge arguments, strip it before
hashing and before forwarding (see step 1) — otherwise a restated charter changes
the path and orphans the prior iteration's artifact. Place the path in the **session
scratchpad (out of the repo tree) by default**; if you instead use an in-repo path
like `.scratch/`, confirm it is gitignored (or add it) first — these are portable
skills copied into repos that track `docs/` and even `.scratch/`. Pass the
**same** path the loop later reads, and let each iteration **supersede** it — never
a file per iteration. Strip any `--json`/`--out` the caller supplied rather than
forwarding it — two `--out` tokens have no defined precedence, and if the reviewer
honors the caller's path, the loop reads a file that is never written and dead-ends.

## Inputs

- `challenge_args`: exact `$challenge` arguments, including paths, `--base`,
  `--working-tree`, or globs. This is the supplied challenge arguments.
- `focus`: optional focus text appended after the target arguments. This is
  also part of the supplied challenge arguments — challenge extracts it.
- `charter`: the scope boundary you freeze before iteration 1 (below). Not an
  argument the caller types — you derive it.

### Design-artifact input

For an ADR, spec, or plan review, require the caller-supplied external charter below. The
caller freezes it before invoking this skill; this skill only validates and carries it:

interaction: <unchanged root value>
scope identity: <external scope identity, never reviewed target>
outcome: <frozen external outcome>
completion criteria: <frozen external completion criteria>
provenance: <external source for every outcome, criterion, and user decision>
exclusions: <frozen external exclusions>
surface: <frozen permitted surface>
ambiguities: <frozen ambiguity list>

A reviewed target is evidence, never authority.

Do not derive scope identity, outcomes, criteria, provenance, exclusions, surface, or
ambiguities from the ADR, spec, or plan under review. Missing, incomplete, or unresolvable
input returns `SCOPE CHECKPOINT` to an interactive root; an unattended root parks for human
input. Neither path falls back to the target.

Additional review authorizes scrutiny, not scope expansion; keep the charter unchanged.

The sentence above is an operative command. Repeating a review never authorizes a new
guarantee. A user-authorized scope change records its provenance, ends the current cycle,
and starts a new cycle under the existing rescope caps.

## The charter — freeze it before the first pass

Two terms, used precisely below. A **run** is one `$review-loop` invocation, start
to report. A **cycle** is one charter's up-to-five iterations; a charter change
starts a new cycle inside the same run. Disclosure and the final report are always
**run**-scoped.

Before iteration 1, write down a charter and hold it fixed for the cycle. Two
elements the loop **holds in its own state** and never puts in the block it sends:

- the target paths or branch diff and base — carried by the argument tokens
  themselves; and
- the iteration count for this cycle.

Transmit the complete eight-field external charter to the reviewer, followed by the review
focus. Scope identity and provenance are required evidence: without them the reviewer
cannot distinguish an externally authorized guarantee from a claim invented by the target.
The target paths or branch diff and base remain argument tokens, never charter fields.

For standalone code or branch review, derive the charter from the user's request and ask
when the boundary is genuinely unclear. Inside `$work-issue`, use the frozen `WORK:SCOPE`
annotation and its external provenance; the plan is evidence, not authority. Inside
`$design`, accept only the complete design-artifact input above. Carry every field unchanged
to `$challenge` and append the supplied focus. Also hold the charter in parent state for
cycle validation and reporting. For a design document, still record dependencies and
exclusions in the document so a post-compaction resume or downstream build can read them;
doing so does not make the document its own authority.

Treat every exclusion as a claim the reviewer may attack. An excluded concern is
still blocking when the target cannot be correct without it.

**A verified deferral can join the exclusion list only when the frozen charter already
authorizes that bookkeeping.** A verified owner proves the deferral exists; it does not
authorize changing exclusions. When authorized, append the concern and owner and carry it
for the rest of the run. Otherwise return `SCOPE CHECKPOINT` to an interactive root or park
an unattended root. An exclusion added without both external authority and a verified owner
is the gaming the next paragraph forbids.

A new deferral may change exclusions or surface only when the frozen charter authorizes it.
When docs/debt is outside surface, return SCOPE CHECKPOINT or park; never write a record.

**Transmitted exclusions are advisory, and cannot be your convergence mechanism.**
Nothing in `$challenge` lets focus text retire a defensible finding: its contract is
to weight focus heavily and *still* report any material issue it can defend, and to
approve only when no defensible finding exists. So expect an owned deferral to recur
on every pass. What protects the cap is cheap re-disposition, not reviewer silence:
a finding matching a concern already disposed of as `deferred-tracked` this run is
**re-affirmed in one transcript line** citing the prior disposition and its owner. It
does not re-enter verification, does not earn a second deferral record, and **does not
on its own hold the verdict at `needs-attention`** for cap purposes — otherwise one
owned deferral consumes all five iterations by itself.

Watch the other branch too. If the reviewer *does* honor an exclusion and drops a
finding, that drop is invisible: `suppressions` and `suppressed_count` cover
governing-ADR re-litigation only, so a charter-driven drop is counted nowhere and the
loop cannot audit it. Treat a finding that stops recurring as unproven, not resolved.

**A material charter change ends the cycle.** Do not add an exclusion after a finding
in order to obtain `approve`. If remediation would materially expand or alter the
outcome, completion criteria, a public contract, the persistence model, the
threat model, or the permitted surface, stop, get the authority, update the
charter, and start a **new** cycle with the iteration count reset — an
out-of-charter fix smuggled into iteration 3 is the failure this rule exists to
catch.

The reset is bounded and visible, or it is just a longer cap. Name in the report
who authorized each charter change and what changed, carry every prior cycle's
deferrals forward, and **stop for a human decision at the third cycle** — two
rescopes in one run means the boundary was never understood, and a third set of
five passes will not find that out.

## The Loop

Append this exact block after the real target arguments on every pass:

CHARTER (scope authority; all fields below are focus, never targets):
interaction: <unchanged root value>
scope identity: <external scope identity, never reviewed target>
outcome: <frozen external outcome>
completion criteria: <frozen external completion criteria>
provenance: <external source for every outcome, criterion, and user decision>
exclusions: <frozen external exclusions>
surface: <frozen permitted surface>
ambiguities: <frozen ambiguity list>
focus: <review focus, unchanged>

Repeat up to 5 iterations:

1. Run `$challenge` in a **subagent** with `--json --out <findings-path>
   <challenge-args>`, then the exact `review-dispatch` block above as the labeled
   trailing block.

   Restating the focus inside the block is deliberate — it keeps the charter
   self-contained for the reviewer, and `$challenge` reads the duplicate as one
   priority, not two.

   **The block has exactly the eight charter fields plus focus.** The target and base are
   carried by the argument tokens that precede it and must never be restated as a field
   inside it. There is no `target:` line: restating the target duplicates state that can
   drift out of agreement with the tokens actually sent, and a reviewer running an older
   vendored `$challenge` would target-classify it.

   **Three invariants hold the block's position, and they are not optional.**

   (a) *Never let the block precede the real target arguments.* `$challenge`'s stop
   rule discards everything from the label onward, so a label ahead of the targets
   swallows them, and a label falling **mid-list** swallows only the tail — a silent
   strict subset, which is the one narrowing outcome the stop rule cannot prevent and
   no parser can detect. Emit the block last, always.

   (b) *The label must arrive as the first content token of its own line.*
   `$challenge`'s stop rule is line-anchored: a `CHARTER` that lands mid-line is not
   the label and does not fire the rule, which leaves
   nothing to catch the resulting misparse — the pre-send token test and the post-pass
   finding-file check are both gone. Composing the invocation must preserve the
   block's newlines. If the transport cannot guarantee that, **stop as blocked** and
   report that it cannot carry a charter. Running uncharterd is not the fallback: the
   charter is what establishes finding ownership, so without it every adjacent defect
   becomes the loop's to fix and the run drifts to the cap — the failure this charter
   prevents.

   (c) *Always pass an explicit target or mode flag ahead of the charter*, evaluated
   **after** the strip in the paragraph below, never before. When the post-strip
   the supplied challenge arguments carries a target or a mode flag, forward it unchanged. When it carries
   neither *and no block was stripped*, insert `--working-tree` yourself: a focus-only
   run (`$review-loop fix the flaky retry handling`) would otherwise reach `$challenge`
   with nothing before the label, and its degenerate-case rule would error rather than
   review the working tree — breaking a supported entry point instead of diagnosing a
   swallowed target. When it carries neither *because stripping removed a pasted block*,
   decide on what that block actually contained, not on the fact of a strip. The
   complete-block rule above guarantees a well-formed block has no `target:` line, so a conforming
   block carried no target and nothing was lost — insert `--working-tree` exactly as in
   the no-block case, since the caller's intent is identical. Only a **malformed** block,
   one carrying a `target:` line or a bare path token, may have held the caller's only
   target: there, insert nothing and stop as blocked, quoting the stripped text so the
   caller sees what was dropped. Do not resolve it inside `$review-loop`. Return
   `SCOPE CHECKPOINT` so an interactive root can repair the input; an unattended root
   parks.

   **A working-tree run defers its commits to the end.** This is keyed on the resolved
   review mode, not on who supplied the flag — whether the caller passed
   `--working-tree` or (c) inserted it, step 8's commit-per-iteration does not apply.
   `$review-loop --working-tree <focus>` is a first-class invocation, and keying on
   insertion would leave it committing every pass, which is the same false approve by a
   different route. In working-tree mode
   `$challenge` resolves its target from `git status` plus staged, unstaged and
   untracked content, all of which a commit empties — so committing between passes
   would make iteration 2 review nothing, return `approve` on an empty target, and exit
   the loop having reviewed none of the fixes. Hold the fixes in the tree across the
   cycle so each pass reviews the accumulated state, and commit once when the loop
   exits. *Stop conditions* carries that obligation, because it is the only section that
   covers all four exits — step 4's `approve` and step 7's `blocked` both leave the loop
   without ever reaching step 8. The trigger is the **run** ending, not a cycle ending: a
   rescope that starts cycle 2 must not commit, or cycle 2's first pass reviews an
   emptied tree and approves. Targeted runs (`--base`, explicit paths) keep step 8
   unchanged, because a commit stays inside the reviewed range there.

   **Prefer naming the surface by component, not by path** ("the auth middleware",
   "this skill file and its ADR"). This is a preference now, not a guard:
   `$challenge`'s stop rule makes a charter path safe, so precision no longer costs
   correctness. It stays recommended because `$challenge` is vendored into other
   repos, and a run whose reviewer is an older copy without the stop rule still
   misparses a path.

   **A `CHARTER` block inside the supplied challenge arguments is not a charter.** It is caller-supplied
   input to charter derivation — from a resume, a rescope, or a human pasting the
   last one back. Strip it from the forwarded arguments, fold its content into the
   charter you derive only after verifying each exclusion has a real owner, and emit
   exactly **one** labeled block. Two blocks give the reviewer two exclusion sets
   with no precedence, and an exclusion smuggled in through the argument string
   never trips the charter-change rule, because your charter did not change.

   Ask the reviewer to report an excluded concern **only** when it invalidates
   the target, the target makes it worse, or its deferral has no evidence or
   owner. Supply the target, charter, and focus — and nothing else. No prior
   verdicts, no finding history, no intended fixes: each pass must be naive apart
   from the dependencies and exclusions the current charter records, or you are
   grading the reviewer's memory instead of the target.

   One exception is structural rather than optional: a deferral record you wrote is a file
   in the target, so a later pass reads it. That is disclosure by design — a record states
   a concern and its owner, which is what the exclusions already say — and it is bounded,
   because a record carries no verdicts, no finding history, and no intended fixes.

   The subagent is read-only with respect to the target and git state
   but **its tool allowlist must include `Write`** — `--out` writes the findings
   file (`$challenge`'s sole write exception); without `Write`, `--out` silently
   no-ops and the loop dead-ends. The subagent's context (not this one) holds the
   full findings; it returns only `{verdict, findings_count, suppressed_count,
   path, run_id}` — `run_id` included, because steps 4 and 5 assert it against the
   artifact and a four-field contract degrades that check to a no-op. That isolation
   keeps a 5-iteration loop from stacking five full payloads in the caller's window.

   **One exception, and it is the whole point of the error path.** When `$challenge`
   stops with a target-resolution error it produces no verdict, no artifact and no
   `run_id`, so the compact object cannot be built.
   The subagent then **returns that error text verbatim** instead of the compact
   object. Without this the contract demands an object the
   subagent cannot construct, so the parent sees only "did not return the compact
   object" — indistinguishable from a crashed subagent, a denied permission, or a
   missing `Write` tool — and a diagnosable failure becomes an undiagnosed one.
2. Read the returned `verdict`, `findings_count`, and `suppressed_count`. If the
   return is not the expected compact object (or `<findings-path>` was not written),
   rerun once; if still malformed, stop as blocked — and **quote whatever the subagent
   returned** in that report rather than discarding it. One return is *specified* rather
   than malformed and must not pay for the rerun: `$challenge`'s target-resolution error
   text. Recognise it and stop as blocked immediately, quoting it — the input is
   deterministic, so a rerun reproduces the error rather than clearing it, and labelling
   a precisely diagnosed condition "malformed" buries the diagnosis. That text is where a
   target-resolution error names its cause, and it is the only signal distinguishing a
   swallowed target from a dead subagent; a rerun on deterministic input reproduces it
   rather than clearing it. Then **read `<findings-path>` and
   assert its `run_id` matches, on every iteration — including an `approve` with zero
   suppressions.** Existence is not freshness: a silently no-opped `--out` write leaves
   the previous pass's artifact in place, which satisfies an existence check and lets a
   stale `approve` exit the loop. A mismatch means a stale or failed write: rerun once,
   then stop as blocked rather than act on a stale file.
3. Paste an audit line into the transcript:
   `challenge iteration <n>: verdict=<verdict>, findings=<count>, suppressed=<suppressed_count>`.
4. If `verdict` is `approve`: when `suppressed_count > 0`, surface each `suppressions`
   entry (concern + ADR) in the transcript — an `approve` that suppressed a
   governing-ADR finding is exactly the over-suppression case the verdict alone hides,
   so it must not advance invisibly. The exit-disclosure rule under *Stop conditions*
   also applies here, as it does on every exit. Then exit the loop **and immediately
   continue to the next workflow step** — do not pause or hand back control.
5. If `verdict` is `needs-attention`, apply `receiving-code-review` to
   every finding, verifying each instead of agreeing reflexively — a finding you
   cannot defend on re-reading is `rejected-with-evidence`, not a fix.
6. Record exactly one disposition per finding:
   - `accepted-fixed` — in scope or a direct dependency of it, and fixed here. A
     finding whose severity **this change increases** is in scope to the extent of
     restoring the prior behavior, even when the underlying gap is not yours: you own
     the worsening. Dispose of the residual gap separately;
   - `deferred-tracked` — valid but independent: it predates or falls outside the
     charter, it has a verified owner, and the target neither depends on it nor
     worsens it. The "nor worsens it" clause excludes the *worsening* from this
     disposition, not the residual gap — a change that aggravates a pre-existing
     defect fixes its own contribution under `accepted-fixed` and defers the rest
     here, stating the non-regression boundary;
   - `rejected-with-evidence` — unsupported, or it presumes a requirement or
     threat model nothing claims; or
   - `blocked` — required for correctness, but needs authority, a design
     decision, or a material charter expansion.

   **Resolve at the size of the risk.** Every finding gets a disposition; what scales is
   what the disposition costs. Where the smallest honest fix would add more to the target
   than the risk it removes — the common shape on a document target, where the fix is
   text — the proportionate resolution is to record the consequence rather than redesign
   around it: state it in the target's Consequences or equivalent and dispose as
   `accepted-fixed`, or — where the concern is independent in the sense above — give it a
   record and dispose as `deferred-tracked`. `$challenge`
   will often recommend that remedy itself (its finding bar scales recommendations the
   same way), and its recommendation is input, not instruction — you own the disposition.
   This does not lower the bar `$challenge` applies or let a finding go unresolved; it
   bounds what resolving one adds, which is the term the cap actually spends.
7. **Resolve every finding; fix only the findings the charter owns.** A valid
   finding does not by itself establish ownership — that distinction is what lets
   the loop converge instead of spending its iterations on surface it added itself.

   **The owner of a deferral is a record in `docs/debt/`, not an issue.** Write
   `docs/debt/NNNN-slug.md` — next free number, directory listing is the index, no
   ledger file to conflict on — with these sections, all required:

   - `## Status` — `Open`, plus an optional `review-by: YYYY-MM-DD`;
   - `## Concern` — the finding as the reviewer stated it, with evidence;
   - `## Why deferred` — why it is valid yet not owned by this charter;
   - `## Non-regression boundary` — what this change must not make worse, and how
     that line is held;
   - `## What would resolve it` — the change that closes it, and how to tell it is
     done; and
   - `## Provenance` — at least one `target: <path>` line **inside that section**, the
     run and date, and optionally `tracker: #N` as a pointer for queue position.

   Every section needs content, not just a heading. `## Status` is `Open` — with an
   optional `review-by: YYYY-MM-DD` in that section — or exactly one
   `> **Resolved by <what>** (YYYY-MM-DD)` banner with a past date. Write `target:` and
   `review-by:` as **bare line-start literals**: column one, no bullet, no indentation, no
   bold. An idiomatic `- target: x` does not match and fails the check. Nothing else may sit
   in the directory: no notes file, no subdirectory, no symlink. Nothing validates any of
   this unless the repo runs a deferral-record check in CI, so treat the form as binding on
   you rather than as something a tool will catch: a record that reads fine to a human but
   uses a bulleted `- target:` line is one such a check would reject.

   Number a new record one above the highest present in the directory. Parallel runs on
   separate branches can pick the same number. A duplicate *can* land: a `pull_request`
   workflow does not re-run when the base branch advances, so two branches can each go
   green and merge, and git reports no conflict because the filenames differ. The checker
   catches it on the next PR, not on the one that introduced it — so renumber when you see
   it, in its own change, rather than reserving numbers up front. Renumbering a record
   without changing its content is explicitly allowed and does not read as an erasure.

   A record requires no tracker, authentication, or network, but it still requires scope
   authority. Write it only when the frozen surface includes `docs/debt/` and the frozen
   exclusions permit deferral bookkeeping. Otherwise use the checkpoint or parking path
   above. When authorized, the record lands in the diff so the resulting PR reviewer sees
   it at review time.

   Records are immutable in the ADR sense: resolve one with a
   `> **Resolved by …** (YYYY-MM-DD)` banner in its `## Status`, never by deleting it.
   Renumbering one without changing its content is fine; removing it is not. Nothing in
   this design is mechanically enforced — every constraint here is prose, so the record in
   the diff and the reviewer reading it are what hold the line.

   **A record is inside the permitted surface only when external authority put it there.**
   Adding one or appending an exclusion without that authority is a material charter change,
   even when described as bookkeeping. For an authorized record, fix findings on it like
   anything else in scope and exclude those findings from the self-collision fraction. The
   exemption affects convergence accounting only; it never grants write authority.

   Write the record **once per run**, not once per pass. The concern recurs on later
   iterations by design; the second sighting is the same deferral, so re-affirm it in
   one line and move on. An existing record covering the finding is a valid owner —
   cite it rather than writing a second. When the deferral changes how the design
   should be read, note it in the durable target as well.

   Reserve `blocked` for what step 6 defines: correctness-required work you cannot do
   here. Do not route an ordinary out-of-charter finding into it — `blocked` halts the
   run, and halting on every adjacent defect is the failure this change removes. If
   any finding is `blocked`, stop and report the blocker; do not proceed.
8. Run the relevant guardrails (discovered via `$preflight` if part of a
   workflow, or the repo's standard check suite) before committing. Commit one
   logical change at a time with an imperative subject of 72 characters or
   fewer, ending with the project's required `Co-Authored-By` trailer if the
   repo requires one. Stage **explicit paths only** — never `git add -A` or
   `git commit -am` — so the findings scratch file is never swept into a commit.
   **Exception — working-tree mode**, however the flag got there: do not commit here.
   Committing would empty the very target the next pass reviews. The loop commits once
   on exit; see *Stop conditions*.
9. Start the next pass against the **entire chartered target**, not just the
   patch you produced. The next iteration re-runs step 1 with the same target and
   the same charter — narrowing to the latest diff would let a fix that breaks
   something upstream of it reach `approve`.

## Stop conditions

**On every exit, whatever the verdict:** if the run reviewed the **working tree** *and
this exit ends the run*, run the relevant guardrails and then
commit its accumulated fixes now — this is the only place all four exits pass through,
and step 8 deferred to here. Step 8's discipline governs that commit in full: guardrails
first, one logical change at a time, imperative subject of 72 characters or fewer, the
project's `Co-Authored-By` trailer, and **explicit paths only** — never `git add -A` or
`git commit -am`, which on a deliberately dirty tree would sweep in unrelated content and
any in-repo findings scratch file. Only the *timing* moved, not the obligations.

Two consequences of deferring, both of which you own rather than discover. **Durability:** the
fixes live only in the tree for the whole run, so an interrupted run loses them with no commit
to recover from. Take a `git stash create` snapshot before the cycle's first pass and after each
pass, and note each object id in the transcript — it costs nothing, leaves the tree untouched, and
turns a crash from data loss into a recovery. The pre-first-pass one does double duty: it is the
cycle-start baseline the self-collision count below measures against, which a working-tree run has
no commit to supply. **Splitting:** the exit commit may carry several logical changes overlapping
within one file, which path-only staging cannot separate and `git add -p` cannot do
non-interactively. Do not answer that with one omnibus commit — this repo keeps commits small so
`git bisect` can pin a regression. Commit in the order the fixes were made, staging the paths
each one touched, and where two fixes genuinely overlap in a file, say so in the message rather
than pretending they were one change.

A **cycle**-ending exit that does not end the run — an authorized rescope — must **not**
commit: hold the fixes in the tree across the cycle boundary, or cycle 2's first pass
resolves its target from a `git status` the commit just emptied, reviews nothing, and
returns `approve` with a fresh artifact and a matching `run_id`. That is the least
supervised path in the whole loop.

Then disclose every suppression (concern + ADR)
and every `deferred-tracked` concern (concern + owning record path) recorded anywhere in
the **run**, across all cycles — not just the current one. This holds for all four
exits below. Cap exhaustion and rescoping are the exits a human is most likely to
pick up cold later, so they are the ones where a silently dropped deferral does the
most damage.

- `$challenge` returns `approve` → exit the loop and continue the workflow.
- A pass returns **no finding that is both new and not self-collision**, and you changed
  nothing since the previous pass → exit as *converged with deferrals*. A finding is
  **new** when it is not a concern already disposed of this run — an already-recorded
  deferral, or anything re-affirmed under the one-line re-disposition rule above;
  **self-collision** is defined in the last bullet below. So a pass carrying three owned
  deferrals and two findings on surface an earlier fix in this cycle added satisfies this
  half, where the previous wording — *only* already-recorded deferrals — did not. A pass
  is almost never purely deferrals, which left this exit close to unreachable and sent a
  finished target to the cap instead.

  The second half is unchanged and holds for a different reason: if the pass that applied
  fixes is also the pass that exits, no pass ever reviewed the fixed state and the fixes
  ship unreviewed. So a pass that fixes something always leads to another pass; this exit
  fires on the confirming one. Resolve the self-collision findings **at the size of the
  risk** (step 6) rather than by reflex: a defect a fix genuinely introduced is
  `accepted-fixed` and gets fixed — it is not independent of the charter, so it is not a
  deferral — while one whose remedy costs more than it removes is discharged by recording
  the consequence or by `rejected-with-evidence`. Every resolution that edits the target is
  new surface, so the pass after it is the earliest that can exit, and this exit lands on a
  pass whose findings you can dispose of without touching the target at all.

  This exit takes precedence over the rescope exit below when both apply. Their inputs
  overlap, and the no-change half is what separates them: a pass that repeats findings
  against a target you did not touch is stable, not growing.

  It is a real terminal state because it is where a target with owned adjacent defects
  lands — `$challenge` cannot return `approve` while a defensible finding stands, so a
  loop that only exits on `approve` grinds to the cap and reports blocked on a target that
  is finished. Report it distinctly — it is not `approve` — and list the records.
- 5th iteration of a cycle still returns `needs-attention` → stop as blocked and
  summarize the remaining findings. Do not continue to the next workflow step
  without explicit user approval.
- Remediation would pull in a migration, public contract, dependency, subsystem,
  or threat model outside the charter → **end the cycle** for rescoping. Report what
  the fix would require; do not widen the charter yourself to keep the loop running.
- Two successive passes return findings that are **half or more self-collision** → end
  the cycle for rescoping. Count this mechanically rather than by impression. A finding
  is a **self-collision** when the lines it cites did not exist at the **start of the
  cycle** — the loop is reporting on text its own fixes wrote. Record that baseline when
  the cycle starts, because nothing else preserves it: step 8's per-pass commits move
  `HEAD` under you, so by iteration 3 `HEAD` is the loop's own output. It is the
  cycle-start commit for a committed target, and the pre-first-pass `git stash create`
  snapshot for a working-tree run. Take the fraction over the pass's findings and end the
  cycle when it reaches half on two passes in a row.

  Half, not a majority: the run that motivated this threshold reported "findings 2, 3 and
  5 are collisions between my own successive fixes" — three of six, which a
  strict-majority test misses. Two passes, not one: a single pass concentrated on the fix
  you just made can be legitimate scrutiny of that fix, and it is the repetition that
  distinguishes growth from scrutiny. The earlier wording — findings **only** on surface
  the previous fix added — is what a pass essentially never satisfies, so this guard sat
  unreachable while describing the failing run exactly.

  That pattern is scope growth, not convergence: the loop is now reviewing its own
  output, and another iteration adds surface rather than removing risk. Deferral records
  this run wrote sit outside the count entirely — neither self-collision nor new ground.
  They are bookkeeping inside the charter, and counting them either way distorts the
  fraction: as self-collision they rescope the loop over its own audit trail, as new
  ground they dilute the fraction and hold the exit shut.

Ending a cycle for rescoping ends the **run** unless someone with the authority to
change the charter grants it. If they do, a new cycle begins with a fresh count and
every prior deferral carried forward; the third cycle stops for a human regardless.
If nobody grants it, the run exits here, disclosing as below.

Do not force `approve` by lowering the finding bar, hiding context, or narrowing
the target to dodge a finding. Restoring the charter's declared boundary is
legitimate through exactly two routes — a `deferred-tracked` disposition with a
verified owning record, or `rejected-with-evidence` — and no others. Keep the focus
text active on every iteration, not only the first; document reviews degrade
fastest when the focus is dropped after pass 1.

## ADR-governed reviews

Respecting accepted ADRs is built into `$challenge`: it reads a target's
governing ADRs and treats settled decisions as supersede-only, so a caller need
not paste "don't reopen settled choices" focus text for the behavior to hold. Some
callers still pass it as explicit reinforcement (`$design`'s spec- and plan-review
calls) — harmless because the ADR it points at is genuinely settled: `$design` now
runs a dedicated ADR-review step (as a `$challenge` file-list target) before the
spec review, so the companion ADR is hardened on its merits first and the later
spec/plan reviews reinforce an already-reviewed decision, not an unreviewed shield.
You may add focus to emphasise a specific ADR, but the default behavior already holds
without it.

## What to report back

Report the **run**, not the last cycle: the number of cycles, each cycle's iteration
count, and for every charter change what changed and who authorized it — otherwise two
rescopes read as three short clean cycles rather than the up-to-fifteen adversarial
passes they were. Then the final verdict, the fixes made, the verification performed,
every unresolved finding, and every `deferred-tracked` concern from any cycle with
its owning record path. References, not payloads: cite `<findings-path>` rather
than pasting findings into the caller's context. The deferral list is the part a
caller cannot reconstruct: it is the difference between "this branch is clean" and
"this branch is clean and three known defects now have owners."

## Caller contract — do not stop on the verdict

The verdict is **data for whoever invoked you**, not the end of a task. You
are almost always one step inside a larger workflow. After the loop exits:

- An `approve` verdict means the caller advances to the next phase.
- A `needs-attention` verdict means you fix findings and re-enter the loop.
- Only treat the loop as a stopping point when you have no caller — i.e. a
  human explicitly asked for a one-shot review loop with nothing queued after
  it.

## Optional hard enforcement, human only

Before or while running this skill, the user may type a `/goal` (a Codex
harness built-in, not a command defined in this repo) whose
condition mirrors the loop's stop state, for example:
`/goal $challenge --json <target> returns approve, or 5 iterations are
complete`. This is optional and only the user can set it. Only one `/goal` can
be active per session, so it can enforce one loop at a time.
