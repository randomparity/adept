# Reproduce before evaluating, and exit a verified-sound target — design

Issue: randomparity/adept#138. Decision record: `docs/adr/0020-reviews-reproduce-claims-and-exit-when-sound.md`.
Companion: #137 / ADR 0019, the record-side half of the same problem.

## Problem

`$trial-loop` runs an adversarial reviewer against a target until it returns `approve` or a
stop condition fires. Two gaps, both observed in one run (#138).

**The dispatch never asks the reviewer to reproduce anything.** Step 1 says to supply "the
target, charter, and focus — and nothing else" (`skills/trial-loop/SKILL.md:291` at
`dd3f5b0`), and every focus text callers pass is evaluative. At `dd3f5b0`,
`rg --no-config -n 'reproduc' skills/ references/` returns five hits and none is a reviewer
obligation. Whether a pass checks the target's factual claims against the world is left to
the reviewer's initiative.

**A verified-sound target can still exhaust the cap and report `blocked`.** The existing
exits are `approve`, *converged with deferrals*, *converged on own surface*, cap exhaustion,
and rescope. None fits a target whose load-bearing claims successive passes have confirmed
and whose remaining findings concern the record's wording — each defensible, none changing
anything. *Converged with deferrals* keys on findings already disposed of this run;
*converged on own surface* keys on findings citing lines the run's own fixes wrote. Neither
describes new findings on original surface that simply do not matter.

In the reported run, passes 1 and 2 reproduced the mechanism and reversed the design twice,
passes 3 to 5 argued about wording, and the loop reported `blocked` on a mechanism three
consecutive passes had confirmed.

The constraint that shapes the exit: in the same evidence, a branch review's top finding was
about ADR *prose* whose consequence was a maintainer deleting a load-bearing line. The
useful axis is consequence, not subject matter.

## Requirements

Sourced from #138's acceptance criteria and the frozen `WORK:SCOPE` on that issue.

1. The dispatch requires the reviewer to identify the target's load-bearing factual claims,
   attempt to reproduce each, and report claim-versus-observation with the command and
   environment used, before evaluating the argument.
2. The "and nothing else" clause is amended so the instruction does not read as a
   prohibited extra.
3. A claim the reviewer cannot reproduce is a finding in its own right, under `$gauntlet`'s
   existing finding schema, with no new fields.
4. A stop condition exists for a target whose load-bearing claims are reproduced and
   confirmed and whose remaining findings carry no consequence, exiting as *sound with
   record notes*, reported distinctly from `approve` and from cap exhaustion, listing the
   outstanding notes.
5. That condition keys on consequence, not subject matter, and the text carries the branch
   review counterexample as a worked negative case.
6. Cap exhaustion still reports `blocked` whenever a standing finding is consequential.
7. `$quest` and `$spellcraft` recognise the new exit as a non-blocking outcome.
8. `just verify` passes.

## Non-requirements

- No gate, script, or test checks any of this. Repository anatomy rule 4 forbids automated
  assertions on prose; enforcement is reading.
- `$gauntlet`'s finding schema, severity scale, verdict enum, and the loop's compact object
  are unchanged.
- Merged records and completed reviews are not retrofitted.
- No deferral bookkeeping: `docs/debt/` is outside the frozen surface for this change.

## Design

### Where the reproduction instruction lives

In `$trial-loop`'s step 1, as a standing instruction the loop transmits on every pass
alongside the target, charter, and focus — **not** in caller focus texts.

#138 proposes both ("the dispatch contract … and the focus text `$spellcraft` and `$quest`
pass"). Stating it in the dispatch alone is a deliberate narrowing, recorded in ADR 0020:
four copies of one rule in four files, with nothing detecting divergence, is the drift the
frozen scope flags as a risk, and the dispatch is the one point every caller passes
through. It also covers `--reviewer detect-evil` and any future caller without further
edits. The tradeoff, recorded in ADR 0020's consequences, is that the instruction reaches
`$detect-evil` whether or not that reviewer was designed around it.

Consequently no caller focus text changes for reproduction. The caller edits this change
makes are the ones requirement 7 asks for: recognising the new exit.

### What the instruction asks for

Four things, in order:

- identify the target's load-bearing factual claims — the claims the target's argument
  rests on, whose falsity would change the conclusion;
- attempt to reproduce each;
- report claim, observation, the command run, and the environment it ran in;
- do this before evaluating the argument.

A target with no load-bearing factual claims is answered in one sentence saying so. A
command the reviewer cannot run in its environment is reported as that observation, not as
a confirmation.

### Where the report goes

In `$gauntlet`'s existing `summary` field, which is free text. The compact object gains no
field, and step 2 already opens the artifact on every iteration to assert `run_id`, so the
orchestrator reads the block from a file it already reads. An unreproducible claim is an
ordinary finding: `file`/`line_start`/`line_end` point at the claim, `body` carries claim,
observation, command, and environment, `recommendation` is the ordinary remedy.

### The amended "nothing else" clause

The clause's purpose is to keep each pass naive of the run's history. It is rewritten to
say what it forbids — prior verdicts, finding history, intended fixes — and to name the
reproduction instruction as part of what is supplied. The existing exception (a deferral
record the run wrote is a file in the target) is unchanged.

### The new exit

*Sound with record notes*, added to *Stop conditions* as its own bullet. Three
preconditions:

1. a pass in this cycle reported every load-bearing claim reproduced and confirmed, and no
   target edit since has changed what those claims assert;
2. every standing finding is consequence-free under the test below;
3. the pass's findings can all be disposed of without editing the target.

The third precondition is the same guarantee *converged with deferrals* gets from its
"you changed nothing since the previous pass" half: a pass that applies a fix is never the
pass that exits, so no fix ships unreviewed.

Precedence: `approve` wins if the reviewer returns it. Where this exit and *converged with
deferrals* both apply, report this one — it carries strictly more information (the
confirmed claims) and lists the deferral owners anyway under the run's disclosure rule.
A finding the consequence test calls consequential cancels the exit and the loop continues
ordinarily.

### The consequence test

For each standing finding, ask what changes if it is never addressed:

- does the decision the target records change?
- does any behaviour change?
- would a future maintainer, acting on the target as it stands, do something different?

Any yes makes the finding consequential. The test is applied to what the finding implies,
never to what it is about.

The worked negative case is stated inline in the skill: the branch-review finding about ADR
prose whose consequence was a maintainer deleting a load-bearing line answers yes on the
third question. It is consequential, and this exit must not fire on it. Without that case
in the text, the first orchestrator to read "remaining findings are about wording" as the
trigger reproduces the failure the exit exists to prevent.

### Cap exhaustion

Unchanged in effect, amended in wording to say explicitly that it is `blocked` because a
standing finding is consequential — so the two conditions read as the pair they are.

### Callers

- `$spellcraft` step 2 currently says "If the loop blocks (5 iterations without `approve`),
  stop as blocked … do not run the spec review against an unhardened ADR." That sentence
  gets the distinction: *sound with record notes* is not blocked, the spec review proceeds,
  and the notes travel with the design record.
- `$quest` names `approve` in its preamble as the signal to proceed and consumes the loop's
  verdict in its step 6 review summary. Both gain the new exit as a non-blocking outcome
  whose notes go into the summary and therefore into `WORK:REVIEW` and the pull request.

### Naming

*sound with record notes* — the phrase #138 uses. It does not collide with
`rejected-with-evidence`, which `references/heed-counsel.md` and `$trial-loop` step 6 use
for a per-finding disposition; this names a run outcome.

## Testing

There is nothing executable to test, and rule 4 forbids a prose gate. Verification is:

- `just verify` — the structural gates (skill shape, name/directory agreement, reference
  link resolution, public-safety scan, record format for the new ADR).
- Reading: the amended dispatch text and the new exit are read against the eight
  requirements above, and against #138's counterexample specifically.

The first real exercise is this change's own branch review, which runs under the amended
dispatch.

## Risks

- **The consequence test is self-applied.** An orchestrator wanting out of the loop can
  call a consequential finding inconsequential. Bounded only by distinct reporting and by
  the notes reaching `WORK:REVIEW` and the pull request. Recorded in ADR 0020.
- **Cross-file drift.** The exit name is stated in `$trial-loop` and consumed by name in
  `$quest` and `$spellcraft`, with nothing detecting divergence — the same residual ADR
  0019 accepted for its contract.
- **Reproduction cost on every pass.** Mitigated by the one-sentence answer for targets
  with no factual claims, and by the reported evidence that reproducing passes are the
  ones that find defects.
- **`$detect-evil` receives an instruction it was not designed around.** Accepted in ADR
  0020: a security pass that reproduces its claims is strictly better, and its scan is
  unchanged.
