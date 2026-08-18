# 0020 — Reviews reproduce claims, and a verified-sound target exits

## Status

Accepted (2026-08-18)

## Context

`$trial-loop` dispatches a reviewer against a target and re-dispatches until the reviewer
returns `approve` or a stop condition fires. Two properties of that loop are missing, and
issue #138 reports one run where both bit at once.

**Nothing asks the reviewer to reproduce anything.** The dispatch step tells the
orchestrator to "Supply the target, charter, and focus — and nothing else"
(`skills/trial-loop/SKILL.md:291` at `dd3f5b0`), and every focus text a caller passes is
evaluative — soundness, completeness, honesty of an argument. At `dd3f5b0`,
`rg --no-config -n 'reproduc' skills/ references/` returns five hits: `$detect-curse`'s
write-a-failing-test rule, the ADR-review clause ADR 0019 added, two occurrences of
"a rerun reproduces the error" in `$trial-loop`'s malformed-return path, and one comment
in a test script. None is a reviewer obligation. Whether a pass checks the target's
factual claims against the world is left to the reviewer's initiative.

**A target whose mechanism is verified sound can still exhaust the cap and report
`blocked`.** The stop conditions cover `approve`, *converged with deferrals*, *converged
on own surface*, cap exhaustion, and rescope. None covers a target whose load-bearing
claims successive passes have confirmed and whose remaining findings are about the
record's wording — each defensible, none changing anything. *Converged with deferrals*
does not catch it (those findings are new, not already-disposed concerns), and *converged
on own surface* does not either (it keys on findings citing lines the run's own fixes
wrote). The loop grinds to the cap and reports `blocked` on a finished target.

The reported instance: a five-iteration ADR review where passes 1 and 2 reproduced the
mechanism and reversed the design twice, passes 3 through 5 argued about wording and
found nothing load-bearing, and the run ended `blocked` on a mechanism three consecutive
passes had confirmed. A branch review on the same repository, which reproduced the build
and the tool behaviour, returned five actionable findings in one pass.

One constraint shapes the exit and is not negotiable. That branch review's top finding
was itself about ADR *prose* — text that would have led a future maintainer to delete a
load-bearing line. So the axis that separates a finding worth another pass from one worth
a note is not prose-versus-fact; it is whether the finding has a consequence.

`$gauntlet`'s finding schema and the loop's compact object are settled ground here: issue
#138 requires reusing both unchanged, and this repository forbids any gate that asserts on
prose, so every rule below is enforced by reading.

## Decision

**The dispatch carries a reproduction instruction, and the loop transmits it.**
`$trial-loop` step 1 sends, on every pass alongside the target, charter, and focus, a
standing instruction: identify the target's load-bearing factual claims, attempt to
reproduce each, and report claim-versus-observation with the command run and the
environment it ran in — before evaluating the argument. The "and nothing else" clause is
amended to name what it actually forbids (prior verdicts, finding history, intended
fixes), so the instruction does not read as a prohibited extra.

It is stated once, in the dispatch, and not copied into any caller's focus text.

**A claim the reviewer cannot reproduce is a finding**, under `$gauntlet`'s existing
schema with no new fields: `file`, `line_start`, and `line_end` point at the claim, `body`
carries the claim, the observation, the command, and the environment, and `recommendation`
is the ordinary remedy. A reviewer that cannot run a command in its environment reports
that as the observation rather than treating the claim as confirmed.

**The claim-versus-observation report rides in `summary`.** The compact object gains no
field. Step 2 already opens the artifact on every iteration to assert `run_id`, so the
orchestrator reads the reproduction block from the artifact it already reads.

**A verified-sound target exits as *sound with record notes*.** The new stop condition
fires when all three hold:

1. a pass in this cycle reported every load-bearing claim reproduced and confirmed, and
   no target edit since has changed what those claims assert;
2. every standing finding is consequence-free under the test below; and
3. the pass's findings can all be disposed of without editing the target — so no fix
   ships unreviewed.

It is reported distinctly, like *converged with deferrals*, and lists the outstanding
notes.

**The consequence test.** For each standing finding, ask what changes if it is never
addressed:

- does the decision the target records change?
- does any behaviour change?
- would a future maintainer, acting on the target as it stands, do something different?

Any yes makes the finding consequential and the exit does not fire. The test is applied
to what the finding *implies*, never to what it is about. The worked negative case is the
branch review above: a finding about ADR prose, whose consequence was a maintainer
deleting a load-bearing line. It answers yes on the third question, so it is
consequential and this exit must not fire on it.

**Cap exhaustion is unchanged.** The final budgeted iteration still stops as `blocked`
whenever any standing finding is consequential. The new exit removes the false `blocked`
on a finished target; it does not soften the real one.

**`$quest` and `$spellcraft` recognise the new exit as non-blocking** and carry its notes
into their own reporting.

`skills/trial-loop/SKILL.md` is the authority for all of this. `$quest` and `$spellcraft`
name the exit only to route on it.

## Consequences

Reproduction now costs commands and time on the reviewer's first act of every pass. On a
target with no load-bearing factual claims it costs one sentence saying so, and the
instruction is written to make that answer legitimate rather than a gap.

The consequence test is a judgment the orchestrator applies to itself, and nothing detects
an orchestrator that calls a consequential finding inconsequential in order to leave the
loop early. Two things bound it: the exit is reported distinctly rather than as `approve`,
and it must list its outstanding notes — which reach the caller's review summary, the
`WORK:REVIEW` annotation, and the pull request, where a human reads them. That is weaker
than a gate and is the price of rule 4 of this repository's anatomy.

Callers now handle a sixth outcome name. A caller that has not been updated treats it as
an unrecognised verdict; the two in this repository are updated in the same change, and a
vendored older copy elsewhere is not.

The reproduction instruction reaches `$detect-evil` too, since the loop transmits it
whichever reviewer is selected. That is intended — a security pass that reproduces its
claims is strictly better — but `$detect-evil` was not designed around it and its scan is
unchanged.

The rule is stated in `$trial-loop` and consumed by name in `$quest` and `$spellcraft`,
with nothing detecting divergence between the three. That is the same residual ADR 0019
records for its own contract, and it is accepted on the same terms.

## Considered & rejected

**Copy the reproduction instruction into each caller's focus text, as #138 proposes.**
judgment: fit — that is four statements of one rule in four files with nothing detecting
divergence, against one statement at the single point every caller passes through. The
dispatch also covers `--reviewer detect-evil` and any future caller for free, where a
focus-text rule covers only the callers someone remembered to edit.

**State the obligation in `$gauntlet`'s Method instead.** judgment: `$gauntlet` runs
standalone against targets that assert nothing to reproduce, and it is the *loop* that
needs the evidence, because the new exit keys on it. Stating it in both files is the
divergence the rejection above avoids.

**Add a `reproduction` array to `$gauntlet`'s JSON output and the compact object.**
verified: the compact object is consumed field by field — at `dd3f5b0`,
`rg --no-config -n 'findings_count' skills/` returns `skills/trial-loop/SKILL.md:38`,
`:305`, and `:319`, which name and read `{verdict, findings_count, suppressed_count, path,
run_id}`, plus `skills/quest/SKILL.md:464`, which routes on `findings_count` and
`suppressed_count` — so a sixth field changes every consumer, and #138's second acceptance
criterion requires the existing schema unchanged.

**Key the exit on prose-versus-fact, exiting once findings stop being factual.**
verified: #138's own evidence refutes it — the branch review's top finding was ADR prose
whose consequence was a maintainer deleting a load-bearing line, and a subject-matter test
waves exactly that finding through.

**Widen *converged with deferrals* to cover this instead of adding an exit.** judgment:
that exit proves stability — no finding that is both new and not self-collision, against a
target you did not touch. A consequence-free finding is new and cites original surface, so
covering it would merge two different convergence proofs into one condition and make
neither readable.

**Let the reviewer judge the target sound and return `approve`.** judgment: `$gauntlet`
approves only when no defensible finding exists, and a consequence-free finding is still
defensible. This would mean lowering the reviewer's bar, which `$trial-loop` forbids in
the same breath as forcing `approve`.

**Raise the iteration cap so a slow-converging target finishes.** judgment: cost — more
passes on a target three passes already confirmed is the reported failure written longer,
and each pass is a fresh full-context reviewer, the loop's dominant cost.

**Let the reviewer, not the orchestrator, decide a finding is consequence-free.**
judgment: the reviewer is deliberately naive of the run's history and cannot see whether a
prior pass confirmed the claims; the orchestrator holds that state, and asking the
reviewer to weigh consequence is asking it to suppress findings.

**Do nothing.** judgment: against #138's reported instance — a five-pass run that reversed
the design twice on reproduced evidence, then spent three fifths of its budget on wording
and reported `blocked` on a mechanism it had confirmed.
