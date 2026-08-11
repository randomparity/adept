# Behaviour inventory — `systematic-debugging` (rewritten in place)

Extracted at commit `5905760` before any rewriting, per the rewrite spec §5.
Rows are observable behaviours, not wording.

```
SKILL.md                          321
root-cause-tracing.md             169
condition-based-waiting-example.ts 158
defense-in-depth.md               122
condition-based-waiting.md        115
find-polluter.sh                   63
                                  948
```

Spec §1 keeps this one a skill — "invoked directly; nothing wraps it" — so
nothing is absorbed and nothing is deleted wholesale. It is rewritten, and the
question each row answers is whether the behaviour survives that rewrite.

Verdicts:

- **KEEP** — carried into the rewritten `SKILL.md`.
- **FIRST-PARTY** — already this repo's own writing, not upstream. Preserved
  substantially as-is; §2's re-expression requirement does not apply to text
  this project wrote.
- **DROP** — deleted, with a reason.

## The anatomy-rule finding

`CLAUDE.md` rule 1: "The default artifact is one `SKILL.md`. Supporting files are
the exception and must be argued for." This skill ships five supporting files.
Measured against the rules they are meant to satisfy:

- **`condition-based-waiting-example.ts`** imports `~/threads/thread-manager`
  and `~/threads/types` — another project's internal modules. It cannot run in
  this repo, is not tested by anything, and its three helpers are one polling
  loop specialised three ways.
- **`find-polluter.sh`** fails rule 2. It hardcodes `npm test`, so it is
  unusable for the Rust, Python and shell work these skills are consulted from;
  it runs `set -e` without `-uo pipefail` and uses two-space indentation against
  the repo's tabs, which is why `list-shell-sources.sh` carries a named
  exception for it; and it is called a bisection script while performing a
  linear scan. What it does — run each test file in turn, check whether the
  artifact appeared — is four lines of instruction a model executes inline and
  adapts to the project's actual test runner.
- **The three technique documents** total 406 lines, of which the substance is
  roughly 45. The rest is TypeScript, two Graphviz digraphs, and the *same*
  2025-10-03 debugging session narrated three times.

So the rewrite is a single `SKILL.md` with no supporting files. That is rule 1's
default, and here it is also what the content justifies.

## `SKILL.md`

| # | Observable behaviour | Verdict | Destination / reason |
|---|---|---|---|
| 1 | No fix proposed before root-cause investigation has run | KEEP | The Iron Law and the skill's reason to exist |
| 2 | Applies to any technical issue — test failure, production bug, unexpected behaviour, performance, build, integration | KEEP | Scope |
| 3 | Applies especially under time pressure, when a quick fix looks obvious, and after a fix has already failed | KEEP | The conditions under which the law is actually broken |
| 4 | Do not skip it because the issue looks simple or because you are in a hurry | KEEP | Folded into row 3 — same rule stated from the other side |
| 5 | Read the error and the whole stack trace before anything else: line numbers, paths, codes | KEEP | Cheapest step, most often skipped |
| 6 | Search `docs/solutions/` for the root cause before investigating it yourself | FIRST-PARTY | This repo's compounding loop. Preserved with its `rg -li` recipe |
| 7 | Search vestige where available; the solution document is the record and a memory is only a pointer to one | FIRST-PARTY | Same |
| 8 | A prior-art hit is a hypothesis, not a fix — carry it into hypothesis testing against *this* failure | FIRST-PARTY | Same, and it is the row that keeps prior art from becoming the symptom-patching this skill forbids |
| 9 | No hit, or no `docs/solutions/` at all, is a normal result; `rg` exits 2 on a missing path and that means "nothing recorded yet" | FIRST-PARTY | Same. Matches `CLAUDE.md`'s rule about rg exit statuses |
| 10 | Reproduce consistently before theorising; if it will not reproduce, gather data rather than guess | KEEP | |
| 11 | Check what changed — diff, recent commits, new dependencies, config, environment | KEEP | |
| 12 | In a multi-component system, instrument every component boundary and run once to find *where* it breaks, before proposing any fix | KEEP | The highest-value step in the file. It converts "which of five things is broken" into one measurement |
| 13 | Trace the bad value backward to where it originates, and fix at the source | KEEP | Merges with rows 30–32 from the tracing document |
| 14 | Find similar code in the same codebase that works | KEEP | |
| 15 | Read a reference implementation completely rather than skimming it | KEEP | |
| 16 | List every difference between working and broken, including ones that "can't matter" | KEEP | |
| 17 | Establish what the component depends on — config, environment, assumptions | KEEP | |
| 18 | Form one hypothesis, stated specifically, and write it down | KEEP | |
| 19 | Test it with the smallest possible change, one variable at a time | KEEP | |
| 20 | When it fails, form a new hypothesis — do not stack a second fix on the first | KEEP | The failure mode the whole skill is arranged against |
| 21 | Say "I don't understand X" instead of proceeding as if you do | KEEP | |
| 22 | Write a failing test reproducing the bug before fixing it | KEEP | Points at `references/trial-by-fire.md` for what makes it worth having |
| 23 | Implement one fix addressing the root cause — no "while I'm here" improvements, no bundled refactoring | KEEP | |
| 24 | Verify: the test passes, nothing else broke, the reported issue is actually gone | KEEP | Points at `references/true-seeing.md` |
| 25 | Count failed fixes. At three, stop and question the architecture rather than attempting a fourth | KEEP | The specific, checkable rule that makes this more than advice |
| 26 | Recognise the architectural signature: each fix uncovers coupling somewhere new, or demands a large refactor, or creates fresh symptoms | KEEP | How you tell row 25's case from ordinary difficulty |
| 27 | Raise the architecture with a human before continuing to fix | KEEP | |
| 28 | Where investigation genuinely shows an environmental, timing or external cause: record what was investigated, implement handling, add logging for next time | KEEP | |
| 29 | Treat "no root cause" with suspicion — it is usually incomplete investigation | KEEP | Kept as a claim, not as the invented "95%" statistic |
| 30 | Record a non-obvious root cause with `$compound` into `docs/solutions/`, the write half of row 6's read | FIRST-PARTY | This repo's loop. Preserved, including that `$compound` declines routine bugs so invoking it costs little |
| 31 | Carry a "Red Flags — STOP" list of 11 thoughts | DROP | **Condition:** confirm each is carried before deleting. Verified: quick fix now → 1; try changing X → 1, 19; multiple changes at once → 19, 23; skip the test → 22; "it's probably X" → 1, 18; don't understand but might work → 21; adapt the pattern → 15; listing fixes before investigating → 1; solutions before tracing → 13; "one more attempt" → 25; each fix reveals a new problem → 26 |
| 32 | Carry a "Signals From Your Human Partner That You're Doing It Wrong" list of five quoted redirections | DROP | Another project's operator quoted verbatim ("Ultra-think this", "We're stuck?"). The underlying rules are rows 1, 10, 12 and 25. §2 asks for re-expression, and a list of one specific person's catchphrases cannot be re-expressed — only dropped |
| 33 | Carry a "Common Rationalizations" table of 8 excuses | KEEP, compressed | Same function as the tables in `trial-by-fire` and `true-seeing`, kept for the same reason. Two rows fold: "reference too long" is row 15, "I see the problem" is row 1 |
| 34 | Carry a Quick Reference table mapping the four phases to activities and success criteria | DROP | **Condition:** verified — every cell restates a phase heading and rows 5–28. The phases are already four numbered headings |
| 35 | Carry a "Real-World Impact" section: 15–30 minutes versus 2–3 hours, 95% versus 40% first-time fix rate, near-zero new bugs | DROP | Unsourced numbers from another project's sessions, presented as measurement. The argument that systematic beats thrashing is row 33's, made without inventing a statistic |
| 36 | Announce "Violating the letter of this process is violating the spirit of debugging" | KEEP | One line, and it closes rows 3 and 25 against being read as advisory |

## `root-cause-tracing.md` (169 lines)

| # | Observable behaviour | Verdict | Destination / reason |
|---|---|---|---|
| 37 | Trace backward through the call chain — symptom, immediate cause, its caller, upward — until the original trigger, then fix there | KEEP | Folds into row 13. This is the substance of the whole document |
| 38 | When manual tracing runs out, instrument: log the suspect value, the working directory, relevant environment, and `new Error().stack` immediately before the dangerous operation | KEEP | Genuinely useful and not derivable from row 37 |
| 39 | Log *before* the operation, not after it fails — a failure may not reach the logging | KEEP | One clause, and it is the part people get wrong |
| 40 | In tests, print to stderr rather than through the logger, which may be suppressed | KEEP, generalised | True beyond `console.error()` in Jest, which is how it is currently written |
| 41 | To find which test pollutes shared state, run the test files one at a time and check for the artifact after each | KEEP, as prose | The technique survives; `find-polluter.sh` does not — see row 61 |
| 42 | Carry two Graphviz digraphs (a when-to-use flow and a key-principle flow) | DROP | 30 lines of `dot` source that renders nowhere the agent can see. The when-to-use flow says "trace if you can, otherwise fix at the symptom"; the principle flow restates row 37 and row 45 |
| 43 | Carry a five-step TypeScript worked example (empty `projectDir` → `git init` in the source tree) plus a second retelling under "Real Example" | DROP | The same incident narrated twice in one file and again in `defense-in-depth.md`. Rows 37–41 state the technique it illustrates |
| 44 | Carry a "Real-World Impact" section citing a 2025-10-03 session, 5-level trace, 1847 tests | DROP | Same reason as row 35 |

## `defense-in-depth.md` (122 lines)

| # | Observable behaviour | Verdict | Destination / reason |
|---|---|---|---|
| 45 | After fixing at the source, add validation at each layer the bad data passed through, so the bug becomes structurally impossible rather than merely fixed | KEEP | The document's thesis and a real addition to row 13 |
| 46 | The layers are of four kinds: entry-point validation, business-logic validation, an environment guard for context-specific dangers, and debug instrumentation | KEEP, condensed | The taxonomy is the usable part. The four TypeScript blocks illustrating it are not |
| 47 | Map every checkpoint the data passes through before adding checks, rather than guessing at two | KEEP | |
| 48 | Test each layer by bypassing the one before it and confirming the next catches it | KEEP | Otherwise the extra layers are untested code |
| 49 | Justify the layers: different code paths bypass entry validation, mocks bypass business-logic checks, platform differences need environment guards | KEEP, condensed | Answers "isn't one check enough", which is the objection the rule meets |
| 50 | Carry four TypeScript implementations of the layers | DROP | Row 46 names each layer's job in a clause. The implementations are Node-specific — `existsSync`, `statSync`, `process.env.NODE_ENV`, `tmpdir()` |
| 51 | Carry the empty-`projectDir` incident a third time, with "1847 tests passed" | DROP | Third retelling. Row 44's reason |

## `condition-based-waiting.md` (115 lines) and its example

| # | Observable behaviour | Verdict | Destination / reason |
|---|---|---|---|
| 52 | Replace an arbitrary sleep with polling on the condition you actually care about | KEEP | The rule. A flake fixed by a longer sleep is not fixed |
| 53 | Bound the poll with a timeout whose error names what was being waited for | KEEP | Without it the loop hangs instead of failing |
| 54 | Poll at a modest interval rather than as fast as possible | KEEP | One clause |
| 55 | Read the state inside the loop; do not capture it before entering | KEEP | The bug that makes a correct-looking poll never terminate |
| 56 | An arbitrary wait is legitimate when the timing itself is under test — but wait for the triggering condition first, base the duration on known timing rather than a guess, and say why in a comment | KEEP | The exception, with the three conditions that keep it from swallowing the rule |
| 57 | Carry a "Quick Patterns" table of five `waitFor(...)` one-liners | DROP | **Condition:** verified — each is row 52 with a different predicate substituted |
| 58 | Carry a generic `waitFor` TypeScript implementation | DROP | Rows 52–55 fully specify it: poll the condition, return on truthy, fail on timeout with a named error, sleep briefly between attempts. Writing it in one language for a repo consulted from several is the narrowing |
| 59 | Carry a when-to-use Graphviz digraph | DROP | Row 42's reason. It encodes rows 52 and 56 as two edges |
| 60 | Carry a "Real-World Impact" section: 15 flaky tests, 60% → 100%, 40% faster | DROP | Row 35's reason |
| 61 | Ship `condition-based-waiting-example.ts` — three polling helpers specialised to a thread-event API | DROP | It imports `~/threads/thread-manager` and `~/threads/types`, modules of another project. It cannot run here, nothing tests it, and rows 52–56 carry the technique |

## `find-polluter.sh` (63 lines)

| # | Observable behaviour | Verdict | Destination / reason |
|---|---|---|---|
| 62 | Ship a script that runs each test file in turn and stops at the first one to create a given path | DROP | Fails `CLAUDE.md` rule 2. It hardcodes `npm test`; it uses `set -e` without `-uo pipefail` and two-space indentation, for which `list-shell-sources.sh` carries a named exception; and it scans linearly while calling itself bisection. The behaviour survives as row 41, in a form that adapts to the project's actual test runner |

**Totals:** 62 rows — 33 KEEP (5 folded, condensed or generalised), 5
FIRST-PARTY, 24 DROP.

948 lines carrying 62 behaviours. Twenty-four rows are Graphviz source,
TypeScript against another project's modules, unsourced impact statistics, or
the same 2025-10-03 incident told three times. Five rows are this repo's own
prior-art loop and are the only content here that already satisfies §2.

**The row that decides the shape** is 62 together with 61: once the script and
the TypeScript go, the three technique documents are ~45 lines of substance
between them, and rule 1's default — one `SKILL.md` — stops being a constraint
to argue against and becomes the accurate description of what is left.

**Consequential edit outside the skill.** Deleting `find-polluter.sh` makes its
two-space exception in `scripts/list-shell-sources.sh` dead code. That exception
and the comment documenting it come out in the same change, and the shell-source
count the ripgrep-config gate prints drops by one.
