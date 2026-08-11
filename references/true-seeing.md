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
| A subagent finished | The diff, read by you | The subagent's report saying it succeeded |

The last row is the one that costs most. A subagent reporting success is
describing its intent; the diff is what it did. Read the diff.

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
