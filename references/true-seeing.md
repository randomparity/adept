# True Seeing — evidence before claims

Read this before writing any sentence that says work is done, fixed, passing, or
ready. It is the shortest of the references and the one most often skipped at the
exact moment it binds.

## The law

**No completion claim without verification evidence from this same message.**

If you have not run the command in this turn, you cannot say it passes. A run
from earlier does not carry forward: the code has changed since, which is the
whole reason you are making a claim about it now.

Claiming completion you have not checked is not efficiency. It is a false
statement about work someone is going to rely on, and the person relying on it
has no way to tell it from a true one.

## The gate

Before the claim, in this order:

1. **Identify the command that proves it.** Not the one that is convenient or
   the one you ran last — the one whose output would be different if the claim
   were false.
2. **Run it in full.** Not the focused case, not the subset covering the files
   you touched. Architecture checks, doc generation, and boundary tests live
   outside the directory you edited and only fail in a complete run.
3. **Read the output.** Check the exit code, and count the failures rather than
   scanning for the absence of red.
4. **Account for what the check never saw.** For any done, passing, or mergeable
   claim, run `git status --porcelain` as well. An untracked file is one no gate
   read: green plus untracked is a false green, and it is the most common way a
   verified claim turns out to be wrong.
5. **If the output does not confirm the claim, say what is actually true, with
   the evidence.** Reporting the real state is the alternative to claiming
   success — not silence, and not a softer version of the same claim.

Skipping a step is not a faster verification. It is not a verification.

## Every claim needs its own command

Evidence for one claim is not evidence for a different one:

| Claim | What proves it | What does not |
|---|---|---|
| Tests pass | The test command's output, zero failures | An earlier run; "it should pass now" |
| Linter clean | The linter's output, zero findings | A partial run over changed files |
| It builds | The build command, exit 0 | The linter passing — a linter does not compile |
| The bug is fixed | The original symptom, exercised, gone | The code changed in the right place |
| Requirements met | The plan, walked line by line | The test suite being green |
| Green and mergeable | Guardrails exit 0 **and** a clean `git status --porcelain` | Green checks with untracked files |
| The merge published | The base-branch run's conclusion, read | The merge landing; the pull request's own green checks |
| A subagent finished | The diff, read by you | The subagent's report saying it succeeded |
| A red run was a fluke | The nondeterminism found, and fixed or filed | The same test passing on re-run |

The subagent row is the one that costs most. A subagent reporting success is
describing its intent; the diff is what it did. Read the diff.

## Flaky tests

A test that fails and then passes with nothing changed in between has told you
exactly one thing: it is nondeterministic. It has not told you whether the code
works.

**A flake is a determinism defect. Fix it or report it — never spend it as
evidence, in either direction.** The green run does not clear the code and the
red run does not condemn it, because a test whose result turns on timing,
ordering, or environment was not measuring the code on either pass.

So when a run goes red and the next one goes green:

- **Do not re-run to green.** Repeating a command until it returns the answer
  you want is not verification, it is selecting the output. Running it again to
  find out whether the failure repeats is diagnosis, and legitimate; reporting
  the second result *as* the result is not.
- **Say that it flaked.** "Tests pass" after a red run is a false claim about a
  suite you now know to be unreliable. Report both runs and name the test.
- **Give it an owner.** Either fix the nondeterminism — `$detect-curse` finds
  the cause, and waiting on a condition rather than on a clock is the usual
  repair — or file it. An unfixed flake nobody wrote down is rediscovered from
  scratch by the next person, who will also lose an afternoon to it.

A flake carries no verdict for anything else either. It is not a dependency
defect, not a merge conflict, and not an implementer's failure to finish. Each
of those needs its own evidence, and filing nondeterminism under one of them
buries a real defect beneath a wrong diagnosis — the flake stays, and the thing
you blamed gets rejected for nothing.

## Regression tests

A test written to lock in a fix is unverified until you have seen it fail
against the unfixed code. The fix already exists, so the ordinary red-green
sequence is not available — run it backwards:

1. Write the test and confirm it passes.
2. Revert the fix.
3. Run it again. **It must fail.** If it still passes, it is not testing the
   fix.
4. Restore the fix.
5. Run it once more and confirm it passes.

"I've added a regression test" without those five steps is a claim about a file
existing, not about a bug being caught.

## How the rule gets evaded

Rarely by stating something false outright. Usually by one of these:

- **Hedging.** "Should work now", "seems to pass", "probably fine". The hedge is
  an accurate report of your evidence — you have none. Run the command instead of
  qualifying the claim.
- **Satisfaction in place of a claim.** "Great!", "Perfect!", "Done!" assert
  success without appearing to. They are subject to the same gate.
- **Rewording.** The rule binds paraphrase, synonym, and implication. Anything a
  reader would act on as "it works" is a completion claim, whatever grammar it
  arrives in. Reading it as a list of banned phrases and writing around them is
  breaking the rule — violating the letter is violating the spirit.

## The arguments against it

**"I'm confident."** Confidence is not evidence. It is also exactly what you felt
the last time you were wrong.

**"Just this once — it's a one-line change."** One-line changes are where this
fails most often, because they are the ones nobody runs the suite for.

**"A partial check is enough here."** A partial check proves the part it
covered. State that, and it is honest reporting. Extrapolate from it, and it is
a guess wearing a result's clothes.

**"I'm tired and this is the last thing."** The reason the rule is written down
is that judgement is worst precisely then.
