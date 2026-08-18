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

The constraint that shapes the exit comes from the same evidence. A branch review's top
finding was about ADR *prose* — text that would have led a future maintainer to delete a
load-bearing line. The useful axis is consequence, not subject matter.

## Decision

**The loop appends a standing reproduction instruction to the focus it transmits.** It is
written once, in `$trial-loop`'s dispatch step, and no caller repeats it. Transport-wise it
arrives at the reviewer as focus text and is weighted as the user's stated priority: the
`CHARTER` block is fixed at eight fields plus focus (`skills/trial-loop/SKILL.md:213`), and
`$gauntlet` classifies every non-flag, non-path token as focus (`skills/gauntlet/SKILL.md:59-67`),
so focus is the only slot that exists. Its own wording — reproduce *before* evaluating —
is what orders it against the caller's evaluative focus.

The instruction asks the reviewer to identify the target's load-bearing factual claims,
attempt to reproduce each, and lead its `summary` with claim versus observation, naming the
command run and the environment it ran in.

**Reproduction stays read-only.** `skills/trial-loop/SKILL.md:301` and
`skills/gauntlet/SKILL.md:344` both make the reviewer read-only with respect to the target
and git state, with `--out` the sole write exception, and this decision creates no second
one. Reproduction is inspection plus commands that write nothing into the target's working
tree; anything that would write is reported as the observation — "could not run here" —
never as a confirmation. That bound is not decoration: in working-tree mode `$gauntlet`
resolves its target from `git status`, and the cycle-start `git stash create` baseline is
what the self-collision fraction measures against, so a reviewer's build artifacts would
become the next pass's target and inflate the loop's own convergence signal.

**A claim the reviewer cannot reproduce is a finding**, under `$gauntlet`'s existing schema
with no new fields: `file`, `line_start`, and `line_end` cite the claim; `body` carries the
claim, the observation, the command, and the environment; `recommendation` is the ordinary
remedy. The report rides in `summary` and the failures ride in `findings`, so the compact
object is unchanged and step 2 reads the block from the artifact it already opens on every
iteration (`skills/trial-loop/SKILL.md:329-333`).

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
the cap, exactly as it does today.

**The consequence test.** For each standing finding, ask what changes if it is never
addressed: does the decision the target records change; does any behaviour change; would a
future maintainer, acting on the target as it stands, do something different? One yes makes
the finding consequential and cancels the exit. The test is applied to what the finding
*implies*, never to what it is about. The worked negative case is the branch review above —
a finding about ADR prose, whose consequence was a maintainer deleting a load-bearing line.
It answers yes on the third question, so this exit must not fire on it.

**The exit is an ordinary run-ending exit.** It inherits *Stop conditions*' on-every-exit
obligations in full — working-tree guardrails and commit, suppression disclosure, deferral
disclosure. The stale "all four exits" counts at `skills/trial-loop/SKILL.md:268` and
`:477` become "every exit" in the same change, so no enumeration needs maintaining again.

**Precedence.** `approve` wins whenever the reviewer returns it. The rescope and
self-collision exits outrank this one, because they carry obligations it does not — charter
authority, and one confirming pass. Where this and *converged with deferrals* both apply,
report this one: it says everything that exit says and adds which claims were confirmed.

**Cap exhaustion is unchanged.** The final budgeted iteration still stops as `blocked`
whenever a standing finding is consequential.

**`$quest` and `$spellcraft` recognise the new exit as non-blocking** and carry its notes
into their own reporting. `skills/trial-loop/SKILL.md` is the authority; they name the exit
only to route on it.

## Consequences

Reproduction costs commands and time on the reviewer's first act of every pass. Under the
read-only bound, a claim that needs a build to check often yields "could not run here" —
which is a finding, not a confirmation, and not condition 1 satisfied.

The consequence test is a judgment the orchestrator applies to itself, and nothing detects
an orchestrator that calls a consequential finding inconsequential to leave early. Two
things bound it: the exit is reported distinctly rather than as `approve`, and it must list
its outstanding notes, which reach the review summary, the `WORK:REVIEW` annotation, and
the pull request. Weaker than a gate, and the price of anatomy rule 4.

Callers now handle a sixth outcome name; the two here are updated in the same change, a
vendored older copy elsewhere is not. The instruction also reaches `$detect-evil`, since
the loop transmits it whichever reviewer is selected — intended, though `$detect-evil` was
not designed around it and its scan is unchanged. And the rule is stated in `$trial-loop`
and consumed by name in two callers with nothing detecting divergence: the same residual
ADR 0019 records, accepted on the same terms.

## Considered & rejected

**Copy the reproduction instruction into each caller's focus text, as #138 proposes.**
judgment: fit — four call sites across two files (`skills/spellcraft/SKILL.md:341`, `:369`,
`:468` and `skills/quest/SKILL.md:417`) versus one statement at the point every caller
passes through, which also covers `--reviewer detect-evil` and any future caller for free.

**State the obligation in `$gauntlet`'s Method instead.** judgment: it is the loop, not the
reviewer, that needs the evidence, because the new exit keys on it; and stating it in both
files is the divergence the rejection above avoids.

**Add a `reproduction` array to `$gauntlet`'s JSON output and the compact object.**
verified: at `dd3f5b0`, `rg --no-config -n 'findings_count' skills/` returns six hits —
`skills/gauntlet/SKILL.md:64` and `:322` define the object, and
`skills/trial-loop/SKILL.md:38`, `:305`, `:319` and `skills/quest/SKILL.md:464` consume it
field by field — so a sixth field changes every one of them, and #138's second acceptance
criterion requires the existing schema unchanged.

**Carry the instruction as a ninth field in the `CHARTER` block.** verified:
`skills/trial-loop/SKILL.md:213` states "The block has exactly the eight charter fields plus
focus", and a ninth element breaks the block's own invariant and the reviewer's parse.

**Key the exit on prose-versus-fact.** verified: #138's evidence refutes it — the branch
review's top finding was ADR prose whose consequence was a maintainer deleting a
load-bearing line, and a subject-matter test waves exactly that finding through.

**Widen *converged with deferrals* to cover this.** verified: that exit proves stability —
no finding both new and not self-collision, against an unchanged target
(`skills/trial-loop/SKILL.md:512-514`). A consequence-free finding is new and cites
original surface, so covering it would merge two different convergence proofs into one
unreadable condition.

**Let the reviewer judge the target sound and return `approve`.** verified:
`skills/gauntlet/SKILL.md:345` approves only when no defensible finding exists, and
`skills/trial-loop/SKILL.md:597` forbids forcing `approve` by lowering the bar. A
consequence-free finding is still defensible.

**Let the reviewer, not the orchestrator, decide a finding is consequence-free.** verified:
`skills/trial-loop/SKILL.md:291-293` keeps each pass naive of the run's history, so the
reviewer cannot see whether a prior pass confirmed the claims.

**Raise the iteration cap.** judgment: cost — more passes on a target three passes already
confirmed is the reported failure written longer.

**Do nothing.** judgment: against #138's instance — two design reversals on reproduced
evidence, then three fifths of the budget on wording and `blocked` on a confirmed
mechanism.
