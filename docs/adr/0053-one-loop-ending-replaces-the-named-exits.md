# 0053 — One loop ending replaces `$trial-loop`'s named exits

## Status

Accepted (2026-09-01)

Supersedes the *sound with record notes* exit decided by
[0020](0020-reviews-reproduce-claims-and-exit-when-sound.md), and amends
[0021](0021-review-summary-names-the-trial-loop-exit.md)'s `exit:` value set. Each
amendment is stated here and in one appended note in that record's `## Status` section,
which keeps its accepted status and leaves its decision sections untouched — the shape
[0049](0049-review-verdicts-gate-on-blocking-severity.md) used to amend
[0011](0011-canonical-workflow-review-vocabulary.md). 0020's reproduction obligation is
unaffected and stays exactly as that record wrote it; only the exit keyed on it is
removed. 0021's field set — six exact, non-empty, single-line fields with `exit:` second
— stands; only the enum its `## Decision` fixes for `exit:` narrows.

## Context

ADR 0049 drew the blocking line between `high` and `medium`, made `approve` mean "no
blocking finding" with notes riding along, and defaulted `iteration_budget` to 2 with a
ceiling of 3. Its own Consequences named the follow-on: "Much of `$trial-loop`'s exit
machinery becomes redundant once `approve`-with-notes is the ordinary ending," deferred to
issue #290 so that a verdict change and a simplification of the loop that consumes verdicts
would not land together with no green state between them. 0049 is merged; this record is
that follow-on.

The machinery in question was built against 0011's rule that `approve` required zero
defensible findings. Under that rule a finished target could not be approved, so the loop
grew endings that were not `approve`:

- *converged with deferrals* — a pass whose findings were all owned deferrals or
  self-collisions, against an unchanged target.
- *sound with record notes* — a pass that confirmed every load-bearing claim it named,
  with every standing finding passing a consequence test.
- *converged on own surface* — two passes half-or-more self-collision, all of it in test
  surface the run itself wrote.

Each carried its own precedence rules against the other two, its own reporting branch, its
own caller-routing bullet, and — for *sound with record notes* — a per-pass claims block
the orchestrator had to transcribe out of each artifact because nothing else preserved it.
At `0e12590`, `skills/trial-loop/SKILL.md` is 922 lines, 228 of which this change
removes. Every orchestrator that invokes the loop pays to hold it in context on every
invocation, and `$quest` and `$spellcraft` each carry a routing paragraph that exists only
to enumerate three names.

Two of the three are now reachable only in degenerate cases. `approve` with notes ends a
sound target in two passes, which is what *sound with record notes* was built to
approximate; the consequence test it applied is what `medium` and `low` severity now
encode, applied by the reviewer under a finding bar rather than by the orchestrator against
its own work. *converged on own surface* keys on two consecutive passes at half-or-more
self-collision, which at a budget of 2 cannot fire before the budget does and at the
ceiling of 3 saves exactly one pass.

One case is not degenerate and is the reason this is a re-derivation rather than a
deletion. A blocking-severity finding that is genuinely outside the charter and has a
verified owner recurs at its own severity on every pass, because each pass is naive of the
run's history by design. `blocking_count` never reaches zero, `approve` never comes, and
the run reports blocked on a target that is finished. That is precisely what *converged
with deferrals* existed for, and severity-gating the verdict does not address it.

## Decision

**1. The loop ends when nothing blocking is left for it to act on, and that is one
ending.** The three named exits, their precedence rules, the consequence test, the
self-collision fraction and its cycle-start baseline, and the per-pass claims block are
removed. What remains is `approve`, the ending below, the budget stop, the rescope stop,
and the `blocked` disposition.

**2. The loop reads a residual blocking figure, not `blocking_count` alone.** The residual
is `blocking_count` minus every blocking finding matching a concern this run already
dispositioned as `deferred-tracked` with a verified owner or `rejected-with-evidence`.
Nothing else may be subtracted; a blocking finding fixed on the current pass still counts,
because the fix has not been reviewed yet.

This is the existing one-line re-disposition rule made load-bearing and given a name. That
rule already said an owned deferral "does not on its own hold the verdict at
`needs-attention` for cap purposes"; the change is that it now applies to
`rejected-with-evidence` as well, and that the loop records the figure per pass instead of
deciding it at the cap. `$gauntlet`'s return is unchanged — the subtraction is the
orchestrator's bookkeeping over its own dispositions, and the finding keeps its severity in
the artifact.

**3. A pass with a zero residual whose dispositions edited nothing exits the loop and
advances the workflow**, identically to `approve`. The no-edit half is 0020's rule and is
kept for its reason: if the pass that applies a fix is the pass that exits, no pass ever
reviewed the fixed state.

**4. Callers route on finished-versus-blocked, which the run states outright.** The last
verdict does not carry that fact: a finished run's verdict is `approve` where the reviewer
cleared the target and `needs-attention` where the only blocking findings left were already
dispositioned. `$trial-loop`'s report says which in those words, and `$quest` and
`$spellcraft` read it rather than re-deriving conditions the loop owns.

**5. `exit:` takes two values, `none` and `blocked-at-budget`.** 0021's three named-exit
values are removed with the exits they named. `none` is a run that finished; `verdict:`
still carries the reviewer's last verdict and is where the two finished shapes differ. Every
other stop parks the quest before `$deliver` and publishes no summary, as 0021 wrote.
`$bards-tale`'s collector needs no change: it reads the field with a text-or-unknown
projection and its narration already falls back to a verdict-only reading on a value it does
not recognize. Its prose enumerating the five values is corrected to name the two, and to
say that the three retired values appear in annotations published before this record, each
of them a run that was not blocked.

**6. The disclosure obligations are unchanged in force and widen by one list.** Every exit
still discloses every suppression and every `deferred-tracked` concern with its owning
record path or tracker issue, across all cycles. It now also discloses every
`rejected-with-evidence` finding with the pass that raised it — previously required only for
rejections taken on the consequence-free ground. Those two lists are exactly what the
residual subtracts, so disclosing them is what holds a self-applied judgment to account.

**7. The reproduction obligation stays.** 0020 put it in `$gauntlet`'s Method and had
`$trial-loop` transmit it inside focus; both stand. A claim the reviewer could not reproduce
reaches the loop as an ordinary finding on the ordinary severity scale, which is all the
loop needs from it now that no exit reads a claim list back. The one sentence in that Method
saying a calling loop may key its exits on whether a pass reproduced anything is struck,
since no loop does.

## Consequences

`skills/trial-loop/SKILL.md` drops from 922 lines to 794, and the routing
paragraphs in `$quest` and `$spellcraft` shrink to a short paragraph each. `$forge` and `$campaign`
never referenced an exit name and are untouched.

The loop's ending contract changes for every consumer, so this is a major version bump. A
caller that routed on an exit name has nothing to route on and must read the
finished-versus-blocked statement instead; a caller that already routed on "not blocked"
is unaffected.

The residual figure is a judgment the orchestrator applies to its own dispositions, and
nothing detects it being made self-servingly — the same residual 0020 recorded for the
consequence test it replaces. What bounds it is disclosure, and the standing prohibition
on forcing `approve` by lowering the finding bar, hiding context, or narrowing the target.
Weaker than a gate, and the price of anatomy rule 4.

Removing the self-collision fraction removes the loop's only mechanical convergence signal.
The budget is what bounds the loop now, and at a default of 2 and a ceiling of 3 there is
no run long enough for the signal to have changed an outcome. A future change that raises
the ceiling would have to reintroduce something in its place.

Published `WORK:REVIEW` annotations carrying `converged-with-deferrals`,
`sound-with-record-notes`, or `converged-on-own-surface` are historical records of runs
that really ended that way. Nothing rewrites them, and `$bards-tale` reads them as it
always did.

## Considered & rejected

**Keep *converged with deferrals* under a shorter name.** verified against the acceptance
criteria on issue #290: "No named exit remains whose only purpose was ending a loop
`approve` could not end." A renamed exit is the same exit — a second terminal outcome for
every caller to enumerate, with its own precedence against the rescope stop. The residual
figure gets the same behavior out of the loop's existing disposition vocabulary and adds no
name to any caller's contract.

**Drop the deferral subtraction and let `approve` be the only non-blocked ending.**
verified against `skills/gauntlet/SKILL.md`'s finding bar and `$trial-loop`'s own statement
that "expect an owned deferral to recur on every pass": neither reviewer lets focus text or
a charter exclusion retire a defensible finding, so a blocking-severity adjacent defect
recurs indefinitely and the run reports blocked on a finished target. This is the failure
*converged with deferrals* was built for, and it survives severity gating unchanged.

**Have the reviewer downgrade an owned deferral to a note.** verified against 0049 decision
3: moving a finding across the blocking line to obtain a verdict is a hard-constraint
violation in both reviewers, in either direction. Ownership is a fact about the charter,
which the reviewer cannot verify and which does not change how severe the defect is.

**Keep the self-collision fraction as a convergence signal.** judgment: cost against a
budget that already bounds the loop. Its trigger needs two consecutive passes, so at the
default budget of 2 it fires no earlier than the budget and at the ceiling of 3 it saves one
pass — against a cycle-start baseline the loop must record and maintain, an exemption clause
in the deferral-record step, and a field in every audit line.

**Keep the per-pass claims block in the transcript for its own sake.** judgment: nothing
reads it once the exit is gone. The reproduction report is in each pass's artifact
`summary`, which the report already cites by path, and an unreproducible claim arrives as a
finding on the ordinary scale.

**Do the whole simplification inside ADR 0049.** verified: 0049's Consequences rejected it
explicitly — a verdict change and a simplification of the loop that consumes verdicts would
leave no green state between them — and filed #290 to own the removal. This record honors
that split rather than reopening it.
