---
name: systematic-debugging
description: "Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes"
---
# Systematic Debugging

**No fix before the investigation has run.**

A fix proposed before you know the cause is a guess. Guesses that happen to
silence the symptom are worse than guesses that fail, because they leave the
cause in place and remove the evidence of it. Reading this as advice for hard
bugs rather than a rule for all of them is how it gets skipped: violating the
letter is violating the spirit.

## When it binds

Any technical issue — a failing test, a production bug, unexpected behaviour, a
performance problem, a broken build, an integration that will not connect.

It binds hardest exactly where it feels least affordable:

- **Under time pressure.** Guessing feels faster and is not; each wrong fix
  costs a full cycle and adds state to reason about.
- **When the fix looks obvious.** An obvious fix for a symptom you have not
  traced is a coincidence you have not tested.
- **After a fix has already failed.** That is the point at which the odds of
  the next guess working have gone *down*, not up.

"It's simple" and "I'm in a hurry" are not exceptions. Simple bugs have causes
too, and finding them takes minutes.

## 1. Investigate

**Read the error and the whole stack trace first.** Not the first line — the
whole thing. File paths, line numbers, and error codes frequently name the cause
outright, and skipping past them to form a theory is the most common way this
process is skipped.

**Check prior art before investigating yourself.** Search `docs/solutions/` for
this root cause: `rg -li '<distinctive error string>' docs/solutions/`, then the
root-cause keywords. The global standards require this check before debugging,
and `$compound` is what fills that directory — skip it and the compounding loop
only ever writes.

Search vestige too where the tools are available (`mcp__vestige__search`). The
solution document is the record; a memory is only a pointer to one, possibly in a
sibling repo.

**A hit is a hypothesis, not a fix.** Carry it into step 3 and test it against
*this* failure — the same symptom from a different root cause is common, and
applying a recorded fix unverified is exactly the symptom-patching this skill
exists to prevent.

No hit is a normal result and costs one command — as is no `docs/solutions/` at
all (`rg` exits 2 on the missing path; that means "nothing recorded here yet",
not a failure). Note it and continue.

**Reproduce it.** Establish the exact steps and whether it happens every time.
An intermittent failure you cannot trigger on demand is not ready to be fixed —
gather more data instead. A fix you cannot watch fail first is unfalsifiable.

**Find what changed.** The diff, the recent commits, a new dependency, a config
edit, a difference between the machine where it works and the one where it does
not.

**In a system with several components, measure before theorising.** When a
failure crosses boundaries — CI to build to signing, request to service to
database — the expensive mistake is guessing which component is at fault and
investigating that one. Instrument every boundary instead: log what enters, log
what leaves, confirm environment and configuration actually propagated, and run
it **once**. That single run tells you which hop breaks, and turns a search over
five components into an investigation of one.

## 2. Trace back to the source

The place an error surfaces is rarely the place it originates. A bad value is
usually passed in from somewhere, and fixing where it lands treats a symptom.

Trace backward: what produced this value, what called that, and up the chain
until you reach the point where a correct input first became a wrong one. Fix
there.

**When manual tracing runs out**, instrument. Immediately *before* the
operation that misbehaves — not in its error path, which may never run — log the
suspect value, the working directory, the environment variables that matter, and
a captured stack. In a test run, write to stderr rather than through the
project's logger, which the harness may suppress.

**To find which test is polluting shared state**, run the test files one at a
time and check for the artifact after each — the file, the directory, the stray
process. The first run that produces it names the culprit. Check before each run
too, so a pre-existing artifact is not blamed on the next test.

## 3. Form one hypothesis and test it

**Find something similar that works.** In the same codebase, ideally. If you are
applying a pattern from a reference implementation, read it completely — a
skimmed pattern applied by analogy is the source of a whole class of bug.

**List every difference between working and broken**, including the ones you are
sure cannot matter. That certainty is where the cause hides.

**Establish what the thing depends on** — configuration, environment, other
components, and the assumptions it makes about them.

Then state one hypothesis, specifically, in writing: *this* is the cause,
because *that*. Test it with the smallest change that would distinguish true
from false, changing one variable.

If it was wrong, form a new hypothesis. Do not leave the failed change in place
and add another on top — two speculative changes interact, and now you cannot
attribute either result.

If you do not understand something, say so. "I don't understand why X happens" is
a usable state that leads to an answer; proceeding as though you do is not.

## 4. Fix

**Write a failing test that reproduces the bug, before fixing it.** See
[trial-by-fire](../../references/trial-by-fire.md) for what makes such a test
worth having. Without it you cannot demonstrate the fix worked, and nothing stops
the bug returning quietly.

**Make one fix, addressing the cause you identified.** No "while I'm here"
improvements, no refactoring bundled in. Both make the change impossible to
evaluate and impossible to revert cleanly.

**Verify** — the new test passes, nothing else broke, and the originally
reported problem is actually gone. Read
[true-seeing](../../references/true-seeing.md) before saying so.

### Three failed fixes means the architecture, not the bug

Count them. After the third fix that did not work, stop and question the design
rather than attempting a fourth.

The signature is recognisable: each fix uncovers coupling or shared state
somewhere new; each one implies a larger refactor to do properly; each one
produces a fresh symptom elsewhere. That is not a sequence of wrong hypotheses —
it is a right hypothesis about a structure that cannot hold the fix.

Raise it with a human before continuing. A fourth attempt at this point is the
most expensive thing you can do.

## Making the bug impossible

Once you have fixed the cause, add a check at each layer the bad data crossed on
its way to the failure. One check is a fix; checks at every layer make the bug
structurally unreachable.

Map the checkpoints first — every point the value passes through — then add:

- **entry-point validation**, rejecting obviously invalid input at the boundary;
- **operation-level validation**, where the value must make sense for the
  specific thing about to be done with it;
- **an environment guard**, refusing operations that are dangerous in a
  particular context — a destructive command outside a temporary directory
  during tests, for example;
- **instrumentation**, so that if all of the above are somehow bypassed, the
  next occurrence arrives with its context attached.

One check is not enough because each layer catches what the others miss: a
different code path can enter below the entry point, a test double can replace
the operation carrying the second check, and platform differences produce cases
neither anticipated.

Then test the layers by bypassing each in turn and confirming the next one
catches it. Untested validation is code that has never run.

## Waiting on conditions, not on time

A flaky test fixed by lengthening a sleep is not fixed. An arbitrary delay
encodes a guess about how long something takes on the machine you happened to run
it on, and it fails under load, in CI, and in parallel.

Poll for the condition you actually care about — the event arrived, the state
changed, the file exists, the count reached N. Then:

- **Bound it with a timeout**, whose error names what was being waited for.
  Without one, a condition that never becomes true hangs instead of failing.
- **Poll at a modest interval.** Spinning as fast as possible burns CPU and can
  starve the thing you are waiting for.
- **Read the state inside the loop.** Capturing it before entering gives you a
  loop that re-checks a value that can no longer change.

An arbitrary wait is legitimate when the timing itself is what you are testing —
a debounce interval, a throttle window, a tick. Even then: wait for the
triggering condition first, derive the duration from the known interval rather
than guessing, and write the reason in a comment.

## When there is genuinely no root cause

Sometimes investigation concludes the cause is environmental, timing-dependent,
or in something you do not control. That is a real outcome. Record what you
investigated and ruled out, implement the appropriate handling — a retry, a
timeout, an error message that says what actually happened — and add enough
logging that the next occurrence arrives with evidence.

Treat the conclusion with suspicion, though. Far more often it means the
investigation stopped early than that a cause does not exist.

## Closing the loop

Once the fix is verified, a non-obvious root cause is worth recording — run
`$compound` to write it to `docs/solutions/` (plus a vestige recall pointer).
That directory is exactly what step 1's prior-art check reads, so this is the
write half of the same loop: skip it and every future session re-investigates
from scratch. `$compound` has its own bar (non-obvious, likely to recur, saves a
future session 30+ minutes) and will decline a routine bug, so invoking it costs
little when the problem does not qualify.

## The arguments against it

| Excuse | Reality |
|---|---|
| "This one is simple — the process is overkill" | Simple bugs have causes too, and finding them takes minutes. The process is cheap in proportion to the bug |
| "It's an emergency, there's no time" | Guess-and-check is slower than investigating, and it is slowest exactly when you are under pressure and taking shortcuts |
| "Let me try this first, then investigate properly" | The first attempt sets the pattern for the session, and "then investigate" rarely happens once something appears to work |
| "I'll add the test once I've confirmed the fix works" | Confirmed how? Without the test you are checking by hand, which proves nothing repeatable and leaves no regression guard |
| "Changing several things at once saves a cycle" | It costs one: whatever the outcome, you cannot attribute it, so you learn nothing and may have introduced a second bug |
| "One more attempt" (after two or more failures) | Three failures is a signal about the design. A fourth attempt is the most expensive move available |
