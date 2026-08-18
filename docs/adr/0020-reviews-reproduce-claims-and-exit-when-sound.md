# 0020 — Reviews reproduce claims, and a verified-sound target exits

## Status

Accepted (2026-08-18)

## Context

`$trial-loop` dispatches a reviewer against a target and re-dispatches until the reviewer
returns `approve` or a stop condition fires. Issue #138 reports one run where two gaps in
that loop bit at once.

**Nothing asks the reviewer to reproduce anything.** The dispatch step says to supply "the
target, charter, and focus — and nothing else" (`skills/trial-loop/SKILL.md:291` at
`dd3f5b0`), and every focus text a caller passes is evaluative. At `dd3f5b0`,
`rg --no-config -n 'reproduc' skills/ references/` returns five hits — `$detect-curse`'s
write-a-failing-test rule, the ADR-review clause ADR 0019 added, two occurrences of "a
rerun reproduces the error" in `$trial-loop`, and one comment in the shipped record gate.
None is a reviewer obligation.

**A target whose mechanism is verified sound can still exhaust the cap and report
`blocked`.** In #138's instance, two passes reproduced the mechanism and reversed the
design twice, three more argued about wording, and the run reported `blocked` on a
mechanism three consecutive passes had confirmed. No existing exit fits: *converged with
deferrals* keys on findings already disposed of this run (`skills/trial-loop/SKILL.md:512`),
and *converged on own surface* keys on findings citing lines the run's own fixes wrote
(`:547`).

The same evidence constrains the exit: that run's branch review had a top finding about ADR
*prose* — text that would have led a future maintainer to delete a load-bearing line. The
useful axis is consequence, not subject matter.

## Decision

**Reproduction is a reviewer obligation, stated in `$gauntlet`'s Method.** Before
evaluating a target's argument, the reviewer identifies its load-bearing factual claims —
the ones whose falsity would change its conclusion — attempts to reproduce each, and leads
its `summary` by naming those claims with claim versus observation, the command run, and
the environment. It lives in Method because a rule the loop keys an exit on cannot be
advisory, and focus text is (see the rejections below).

That placement binds **every** `$gauntlet` invocation, not only `$trial-loop`'s — `$saga`
dispatches it on a PRD draft (`skills/saga/SKILL.md:42`), `$campaign` on a close-candidate
(`skills/campaign/SKILL.md:179`), and `$quest` names it bare as a fallback. The reach is
intended and unavoidable: Method is the only place the obligation binds, and Method has no
per-caller scope. The cost on those paths is bounded, since a target asserting nothing
reproducible is answered in one sentence.

**`$trial-loop` appends the same instruction to the focus it transmits**, on every pass and
whichever reviewer is selected, naming `$gauntlet`'s Method as its authority. It rides
*inside* `focus`, so `skills/trial-loop/SKILL.md:291`'s "and nothing else" and its
naive-pass guarantee are unchanged; that clause is amended only to say so, since a standing
instruction beside a "nothing else" clause otherwise reads as a prohibited extra. The
transmission delivers the instruction to every reviewer, but it binds only one whose own
Method carries the obligation — for `--reviewer detect-evil` and for a vendored `$gauntlet`
predating this record, delivery is all it is. No caller repeats it.

**Reproduction stays read-only.** `skills/trial-loop/SKILL.md:301` and
`skills/gauntlet/SKILL.md:344` make the reviewer read-only with respect to the target and
git state, with `--out` the sole write exception; this decision creates no second one.
Anything that would write into the target's working tree is reported as the observation —
"could not run here" — never as a confirmation. In working-tree mode `$gauntlet` resolves
its target from `git status` and the self-collision baseline is a `git stash create`
snapshot, so a reviewer's build artifacts would otherwise become the next pass's target.

**A claim the reviewer cannot reproduce is a finding**, under `$gauntlet`'s existing schema
with no new fields: `file`, `line_start`, and `line_end` cite the claim; `body` carries the
claim, the observation, the command, and the environment. The report rides in `summary` and
the failures in `findings`, so the compact object is unchanged and step 2 reads the block
from the artifact it already opens on every iteration.

**A verified-sound target exits as *sound with record notes*.** The condition fires when
all three hold:

1. a pass in this cycle **named** the load-bearing claims it reproduced and reported each
   confirmed, and no target edit since has changed what those claims assert;
2. every standing finding is consequence-free under the test below; and
3. the pass's findings can all be disposed of without editing the target, so no fix ships
   unreviewed.

Condition 1 needs named claims, not a verdict about claims. A pass answering "this target
asserts nothing reproducible" satisfies the instruction but not this condition: a target
with nothing to reproduce leaves the loop through `approve`, *converged with deferrals*, or
the cap, as it does today.

**The consequence test.** For each standing finding, ask what changes if it is never
addressed: does the decision the target records change; does any behaviour change; would a
future maintainer, acting on the target as it stands, do something different? One yes makes
the finding consequential and cancels the exit. The test is applied to what the finding
*implies*, never to what it is about. The worked negative case is the branch review above —
a finding about ADR prose, whose consequence was a maintainer deleting a load-bearing line.
It answers yes on the third question, so this exit must not fire on it.

**The exit is an ordinary run-ending exit**, inheriting *Stop conditions*' on-every-exit
obligations in full: working-tree guardrails and commit, suppression disclosure, deferral
disclosure. `$trial-loop`'s standing "all four exits" counts are corrected to "every exit"
in the same change; the implementation plan names the sites, since a literal search misses
one of them.

**Precedence.** `approve` wins whenever the reviewer returns it, and *converged with
deferrals* wins over this exit where both apply — its no-edit test covers the whole target,
where condition 1 covers only the confirmed claims. The rescope and self-collision exits
outrank it too, carrying obligations it does not: charter authority, and one confirming
pass. Cap exhaustion is unchanged — the final budgeted iteration still stops as `blocked`
whenever a standing finding is consequential.

**`$quest` and `$spellcraft` recognise the new exit as non-blocking** and carry its notes
into their own reporting. `skills/trial-loop/SKILL.md` is the authority for the loop's
exits; they name this one only to route on it.

## Consequences

Reproduction costs commands and time on the reviewer's first act of every pass. Under the
read-only bound, a claim that needs a build to check often yields "could not run here" —
a finding, not a confirmation, and not condition 1 satisfied.

Two of the exit's tests are judgments the orchestrator applies to itself, and nothing
detects either being made self-servingly: whether a standing finding is consequence-free,
and whether an edit since the confirming pass changed what a confirmed claim asserts. What
bounds them is disclosure — the exit is reported distinctly rather than as `approve`, and
its note list names each confirmed claim with the pass that confirmed it, reaching the
review summary, the `WORK:REVIEW` annotation, and the pull request. Weaker than a gate, and
the price of anatomy rule 4.

Two residuals this change does not close. A target with no reproducible claims and only
consequence-free findings still runs to the cap and reports `blocked` — the reported
failure in a narrower form, accepted because condition 1 is what makes "sound" earned
rather than asserted. And `$quest` and `$spellcraft` branch today only on `approve` and
blocked: at `dd3f5b0`, `rg --no-config -n 'converged' skills/quest/SKILL.md
skills/spellcraft/SKILL.md` exits 1 with no matches, so *converged with deferrals* and
*converged on own surface* are already unrouted there. This change adds a third name and
leaves those two as they were; the gap is filed as issue #141 rather than fixed here,
`docs/debt/` being outside this change's surface.

A third residual follows from the transmission being delivery rather than obligation: under
`--reviewer detect-evil`, or a vendored `$gauntlet` predating this record, condition 1 is
not reliable and such a run can still reach the cap on a finished target. `$detect-evil`'s
Method is its own — it borrows `$gauntlet`'s argument parsing, schema, and ADR handling,
not its Method — so the fix is to mirror the obligation there, which `skills/detect-evil/SKILL.md`
being outside this change's surface puts beyond this run. Filed as issue #142; the vendored
case has no fix short of the copy being updated. `$detect-evil`'s scan is unchanged either
way.

The rule now sits in two files: `$gauntlet`'s Method holds the obligation and
`$trial-loop`'s dispatch transmits it, with nothing detecting divergence between them. That
is the price of making it binding, and it is the same residual ADR 0019 records for its own
two-file contract.

## Considered & rejected

**Copy the reproduction instruction into each caller's focus text.** judgment: fit — four
call sites across two files (`skills/spellcraft/SKILL.md:341`, `:369`, `:468` and
`skills/quest/SKILL.md:417`) versus one statement at the point every caller passes through.
(#138 names caller focus text as a second site alongside the dispatch contract; the
dispatch half is what this record adopts.)

**State it in `$trial-loop`'s dispatch alone, leaving `$gauntlet` untouched.** verified:
`skills/gauntlet/SKILL.md:199` tells the reviewer to weight focus heavily "but still report
any other material issue you can defend", and `:226-228` limits focus to reordering attack
surfaces and one summary duty. A contract-compliant reviewer could decline to reproduce
anything, condition 1 would never hold, and the run would land on the cap — the failure
this record removes.

**State it in `$gauntlet`'s Method alone, with no transmission.** judgment: reach — a
single-file rule reaches only reviewers whose installed copy carries it, and
`skills/trial-loop/SKILL.md:204-205` has the loop read and dispatch whichever installed
reviewer is selected, with no step that inspects what that copy says.

**Add a `reproduction` array to `$gauntlet`'s JSON output and the compact object.**
verified: at `dd3f5b0`, `rg --no-config -n 'findings_count' skills/` returns six hits —
`skills/gauntlet/SKILL.md:64` and `:322` define the object, and
`skills/trial-loop/SKILL.md:38`, `:305`, `:319` and `skills/quest/SKILL.md:464` consume it
field by field — so a sixth field changes every one of them.

**Carry the instruction as a ninth field in the `CHARTER` block.** verified:
`skills/trial-loop/SKILL.md:213` states "The block has exactly the eight charter fields plus
focus", so a ninth element breaks the block's own invariant.

**Fire the exit on the consequence test and the no-edit precondition alone, dropping
condition 1.** judgment: it would exit targets nobody checked under a name asserting they
were, and the note list would have nothing to list. The cost is the residual recorded above
— a claim-free target still reaches the cap.

**Have the orchestrator reproduce the claims itself.** judgment: the orchestrator is not
read-only, so its commands are unbounded where the reviewer's are; and it would reproduce
once per run rather than once per pass, which cannot re-confirm a target the loop has since
edited — the very thing condition 1 requires.

**Key the exit on prose-versus-fact.** verified: #138's evidence refutes it — the branch
review's top finding was ADR prose whose consequence was a maintainer deleting a
load-bearing line, and a subject-matter test waves exactly that finding through.

**Widen *converged with deferrals* to cover this.** verified: that exit proves stability —
no finding both new and not self-collision, against an unchanged target
(`skills/trial-loop/SKILL.md:512-514`). A consequence-free finding is new and cites original
surface, so covering it would merge two convergence proofs into one unreadable condition.

**Let the reviewer judge the target sound and return `approve`.** verified:
`skills/gauntlet/SKILL.md:345` approves only when no defensible finding exists, and
`skills/trial-loop/SKILL.md:597` forbids forcing `approve` by lowering the bar.

**Let the reviewer, not the orchestrator, decide a finding is consequence-free.** verified:
`skills/trial-loop/SKILL.md:291-293` keeps each pass naive of the run's history, so the
reviewer cannot see whether a prior pass confirmed the claims.

**Raise the iteration cap.** judgment: cost — more passes on a target three passes already
confirmed is the reported failure written longer.

**Do nothing.** judgment: against #138's instance — two design reversals on reproduced
evidence, then three fifths of the budget on wording and `blocked` on a confirmed
mechanism.
