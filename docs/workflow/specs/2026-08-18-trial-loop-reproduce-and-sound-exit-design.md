# Reproduce before evaluating, and exit a verified-sound target — design

Issue: randomparity/adept#138. Decision record: `docs/adr/0020-reviews-reproduce-claims-and-exit-when-sound.md`.
Companion: #137 / ADR 0019, the record-side half of the same problem.

Every `skills/` line citation below is at `dd3f5b0`, this change's merge-base with `main`.

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

Two places, with a clear authority split, and neither of them a caller's focus text.

**The obligation is in `$gauntlet`'s Method.** Focus text cannot oblige: `$gauntlet` weights
focus heavily but "still report[s] any other material issue you can defend"
(`skills/gauntlet/SKILL.md:199`), and focus only reorders attack surfaces and adds one
summary duty (`:226-228`). A reviewer that ignored a focus-only reproduction request would
still be contract-compliant — and then condition 1 of the new exit could never hold and the
run would land on the cap, which is the failure being removed. So the obligation is stated
where it binds.

**`$trial-loop`'s dispatch transmits the same instruction with the focus** on every pass,
naming `$gauntlet`'s Method as its authority. It rides *inside* focus, not as a fourth
thing supplied, so `skills/trial-loop/SKILL.md:291`'s naive-pass guarantee is untouched and
the "and nothing else" clause is amended only to say so. Focus is the only slot available:
the `CHARTER` block is fixed at eight fields plus focus (`:213`), and `$gauntlet` classifies
every non-flag, non-path token as focus (`skills/gauntlet/SKILL.md:59-67`).

The transmission is **delivery, not obligation**. It reaches `--reviewer detect-evil` and a
vendored `$gauntlet` copy predating the Method change, but focus is advisory for them too,
so on those reviewers condition 1 is unreliable and the run can still reach the cap. That
residual is accepted, not fixed — nothing available makes focus bind.

#138 proposes the dispatch plus each caller's focus text. Stating it in the dispatch and
`$gauntlet` instead is a deliberate narrowing, recorded in ADR 0020: four call sites across
two caller files against one transmission point every caller passes through. Consequently
no caller focus text changes for reproduction; the caller edits this change makes are the
ones requirement 7 asks for.

The residual is two statements of one rule with nothing detecting divergence — the price of
making it binding, and the same residual ADR 0019 accepted.

### What the instruction asks for

Four things, in order: identify the target's load-bearing factual claims — the ones whose
falsity would change the conclusion; attempt to reproduce each; report claim, observation,
the command run, and the environment it ran in; and do this before evaluating the argument.

A target with no load-bearing factual claims is answered in one sentence saying so.

**Could-not-reproduce and could-not-check are different outcomes.** A claim the reviewer
ran and could not reproduce is a finding, always. A claim it could not check — no tool, no
network, wrong platform, or a command the read-only bound forbids — is reported as that
observation and becomes a finding only where the inability to check is itself material.
Without the split, the most common load-bearing claim in a portable-skill target ("the
guardrails pass", whose suite writes while it runs) is un-runnable, therefore an automatic
finding, therefore `approve` is foreclosed and every such run goes to the cap — this
change's own failure mode, reintroduced by its own rule.

### Recording the claim list

Condition 1 reads back which claims a pass named and how each was accounted for, and
nothing in the loop preserves that: the compact object does not carry it and the artifact
is superseded next pass. So step 3's audit line gains the claims block, taken from the
`summary` in the artifact step 2 already opens. A pass that named none records
`claims: none named`, which keeps the exit shut explicitly rather than by omission.

### Reproduction stays read-only

`skills/trial-loop/SKILL.md:301` and `skills/gauntlet/SKILL.md:344` make the reviewer
read-only with respect to the target and git state, with `--out` the sole write exception.
This change creates no second one: reproduction is inspection plus commands that write
nothing into the target's working tree, and anything that would write is reported as the
observation.

The bound is load-bearing, not decoration. In working-tree mode `$gauntlet` resolves its
target from `git status`, and the cycle-start `git stash create` snapshot is the baseline
the self-collision fraction measures against — so a reviewer's build artifacts would become
the next pass's target *and* count as lines that did not exist at cycle start, inflating
the loop's own convergence signal and pushing the run toward the own-surface or rescope
exit on evidence the reviewer manufactured.

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

1. a pass in this cycle **named** the target's load-bearing factual claims and accounted
   for every one it named, and no target edit since has changed what those claims assert;
2. every standing finding is consequence-free under the test below;
3. the pass's findings can all be disposed of without editing the target.

Condition 1 requires named claims, not a verdict about claims. Otherwise the exit is
vacuously reachable: the reviewer chooses which claims count as load-bearing, and the
instruction deliberately legitimates "this target asserts nothing reproducible" as an
answer — so a lazy or mistaken pass would hand the orchestrator condition 1 and the exit
would turn entirely on a consequence test nothing checks. A target with nothing to
reproduce leaves the loop through `approve`, *converged with deferrals*, or the cap, as it
does today.

**Accounted for**, not merely *reproduced*. Each named claim is confirmed, or explicitly
reported as not checkable in the reviewer's environment. Without that, "the claims it
reproduced" reads as a restrictive clause over whatever subset the pass happened to check,
and one confirmed claim out of four names satisfies the condition — which collapses the
earned-soundness argument the condition exists for. A not-checkable claim is a standing
finding and clears the consequence test on its own; usually it will not, because a
load-bearing claim nobody can check is what a future maintainer acts on differently.

**Scoped per cycle**, matching the self-collision baseline. A rescope need not edit the
target, so without the scoping a confirmation from cycle 1 would satisfy condition 1 on
cycle 2's first pass under a charter that had since widened.

**Disposition of an outstanding note**: `rejected-with-evidence`, with the consequence test
as the evidence. `accepted-fixed` and `deferred-tracked` both edit the target — the latter
because a deferral record is a file in it — and the exit's third precondition forbids that.
`$trial-loop` step 6's `rejected-with-evidence` line gains the same clause so the two
agree. Because step 6 runs on every pass, the on-every-exit disclosure gains the same
findings: without that, the consequence judgment could be taken on iteration 2 and the run
could leave through *converged with deferrals* with nothing disclosing it.

The third precondition is the same guarantee *converged with deferrals* gets from its
"you changed nothing since the previous pass" half: a pass that applies a fix is never the
pass that exits, so no fix ships unreviewed.

The exit is an ordinary run-ending exit and inherits *Stop conditions*' on-every-exit
obligations in full — working-tree guardrails and commit, suppression disclosure, deferral
disclosure. `skills/trial-loop/SKILL.md` says "all four exits" in **three** places, and not
all in one section: `:268` in *The Loop*, `:477` and `:505` in *Stop conditions* — the last
wrapping a line break so a line-anchored grep finds only two, and it is the one scoping
suppression and deferral disclosure, the obligation the new exit most needs. All three
become "every exit", which is correct now and stays correct.

Precedence: `approve` wins if the reviewer returns it. *Converged with deferrals* outranks
this exit where both apply, because its no-edit test covers the whole target while
condition 1 covers only what the confirmed claims assert — an orchestrator that rewrote a
section after the confirming pass satisfies condition 1 and does not satisfy that one. The
rescope and self-collision exits outrank it too, carrying obligations it does not — charter
authority, and one confirming pass — and an exit whose conditions the orchestrator itself
judges must not be the cheap way past them. A finding the consequence test calls
consequential cancels the exit and the loop continues ordinarily.

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

Both callers branch today only on `approve` and blocked: at `dd3f5b0`,
`rg --no-config -n 'converged' skills/quest/SKILL.md skills/spellcraft/SKILL.md` exits 1
with no matches, so *converged with deferrals* and *converged on own surface* are already
unrouted there. This change adds a third name and leaves those two as they are — routing
them is outside the frozen surface and is filed as issue #141 instead.

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

- **Two self-applied tests.** An orchestrator wanting out of the loop can call a
  consequential finding inconsequential, and can call an edit since the confirming pass
  claim-preserving. Bounded only by distinct reporting and by the note list — which names
  each confirmed claim with the pass that confirmed it — reaching `WORK:REVIEW` and the
  pull request. Recorded in ADR 0020.
- **Cross-file drift.** The obligation sits in `$gauntlet`'s Method, the transmission in
  `$trial-loop`, and the exit name is consumed in `$quest` and `$spellcraft`, with nothing
  detecting divergence — the same residual ADR 0019 accepted for its contract.
- **A claim-free target still reaches the cap.** Condition 1 requires a reproducing pass,
  so a target that asserts nothing reproducible and accumulates only consequence-free
  findings still reports `blocked`. Accepted in ADR 0020: without condition 1 the exit
  would call targets sound that nobody checked.
- **Reproduction cost on every pass.** Mitigated by the one-sentence answer for targets
  with no factual claims, and by the reported evidence that reproducing passes are the
  ones that find defects.
- **The transmission does not bind a reviewer whose Method lacks the obligation.** Under
  `--reviewer detect-evil`, or a vendored `$gauntlet` predating this change, focus is
  advisory, so condition 1 is unreliable and such runs can still reach the cap. Accepted in
  ADR 0020; `$detect-evil`'s scan is unchanged either way.
