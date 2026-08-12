# Close the upstream attribution

**Goal:** Rewrite the six files still substantially `obra/superpowers` expression
so none exceeds 2% shingled containment or a 16-token shared run, then delete the
attribution — `licenses/`, the README list, `CLAUDE.md`'s Layout entry, and
`$gauntlet`'s stale citation — and record the measurement in ADR 0003.

**Architecture:** Nothing structural changes. Three shell scripts are re-expressed
with every git invocation left byte-identical, and three prompt templates are
re-authored from the dispatch contract that already lives in
`skills/forge/SKILL.md`. Two of the scripts gain their first behaviour suites,
written and proven to fail before the scripts are touched.

**Tech stack:** Bash (3.2 floor), `awk`, ripgrep, `just`, `shellcheck`, `shfmt`.
Measurement is a throwaway Python checker outside the repo.

**Design:** `docs/workflow/specs/2026-08-11-close-the-upstream-attribution.md`.
Decision: `docs/adr/0003-close-the-upstream-attribution.md`.

## Global Constraints

Transcribed from the spec and `CLAUDE.md`, values and all. Every task's
requirements implicitly include this section.

- **Bash 3.2 is the floor.** macOS ships 3.2.57. No `mapfile`, no `readarray`, no
  associative arrays. Regexes used with `[[ =~ ]]` go in a variable first.
- **Shell style:** `#!/usr/bin/env bash`, `set -euo pipefail`, **tab** indentation
  (`shfmt` default; only `.github/scripts/` and `skills/tome-of-lore/assets/` use
  `-i 2`). Lines ≤ 100 characters.
- **`rg` in any committed script passes `--no-config`.**
- **Guardrail:** `just verify` green at every commit, run **bare** — no pipes, no
  `|| true`. `just commit-check` runs on every commit via prek.
- **Never `rm -rf` against the checkout or as an interactive command**; use
  `git rm` for tracked deletions and `trash` for scratch trees. A fixture's own
  `mktemp -d` teardown is the exception and follows
  `tests/fixtures/forge/sdd-workspace-test.sh:29`.
- **Public repo, and that extends to the pull-request body.** Transcripts and
  measurement output pasted there substitute `$SCRATCH` and `$WORK` for the real
  paths, the same convention committed files follow —
  `scripts/check-public-safety.sh` scans the tree only, so nothing catches a leak
  in a PR comment. Applies to Task 1's mutation results and Task 8's three
  transcripts.
- No absolute host paths in committed files; plans and specs name
  the checkout root as `$WORK`. `scripts/check-public-safety.sh` enforces it.
- **Threshold** (ratified into the charter as `WORK:SCOPE` amendment 2 — it is a
  necessary consequence of the outcome sentence, not a design addition): below
  **2% containment** and **no shared run over 16 tokens**,
  measured against `obra/superpowers@d884ae04edebef577e82ff7c4e143debd0bbec99`.
  A run may be exempted only if it is command syntax rather than prose *and* no
  longer than 28 tokens; exemptions are named in ADR 0003's table.
- **Nothing functional changes in the scripts.** Same arguments, same exit codes,
  same files written, same stdout contract. Comments, diagnostic wording, variable
  names and statement structure are what change.
- **Missing the bar is not a task failure.** A rewrite that lands above 2% or
  over 16 tokens still commits its improvement and **records the measured
  figure**; the miss is the §2 fallback input Task 8 collects and Task 9b
  discharges. Read every per-task containment criterion as "below the bar, or the
  figure recorded and carried to Task 8".
- **Anatomy rule 4:** no automated gate asserts on prose. The literal checks below
  are commands a person runs from a checklist, never wired into `just verify`.

### The measurement tool

Not in the repo and never enters it (ADR 0002, anatomy rule 2). Task 0 builds it
in a scratch directory outside the checkout, as **three files with these exact
names and argument orders**, so every later task can name them without ambiguity:

    $SCRATCH/containment.py <upstream-root> <repo-root> <path> [<path>...]
    $SCRATCH/runs.py        <upstream-root> <abs-candidate-path> <label> [min-tokens]
    $SCRATCH/sweep.py       <upstream-root> <repo-root>

`containment.py` prints containment and longest shared run per path; `runs.py`
lists the maximal shared passages above a token floor, so a residual can be judged
command-syntax versus prose; `sweep.py` runs containment over every tracked file
so the candidate set has a denominator.

### The gated literals — they differ per file

This table is the contract. Getting it wrong breaks a dispatch silently, and no
gate catches it.

| File | Literals that must survive verbatim | Consumed at |
|---|---|---|
| `task-reviewer-prompt.md` | `Critical`, `Important`, `Minor`; `Cannot verify from diff`; `⚠️`, `✅`, `❌`; two separate verdicts (spec compliance, task quality) | `skills/forge/SKILL.md:203`, `:226`, `:353-355` |
| `code-reviewer.md` | `Critical`, `Important`, `Minor` | `skills/forge/SKILL.md:203`; `skills/gauntlet/SKILL.md:289-297` |
| `implementer-prompt.md` | `DONE`, `DONE_WITH_CONCERNS`, `BLOCKED`, `NEEDS_CONTEXT` | `skills/forge/SKILL.md:213-223`, `:167`, `:223` |

Check them with word bounds, not fixed strings — `rg -F 'DONE'` matches inside
`DONE_WITH_CONCERNS` and returns 3, so that check cannot fail:

```sh
rg -c --no-config '\bDONE\b'              skills/forge/implementer-prompt.md   # 1
rg -c --no-config -F 'DONE_WITH_CONCERNS' skills/forge/implementer-prompt.md   # ≥1
rg -c --no-config '\bBLOCKED\b'           skills/forge/implementer-prompt.md   # ≥1
rg -c --no-config '\bNEEDS_CONTEXT\b'     skills/forge/implementer-prompt.md   # ≥1
rg -c --no-config -F 'Cannot verify from diff' skills/forge/task-reviewer-prompt.md  # ≥1
rg -c --no-config '\bCritical\b'          skills/forge/task-reviewer-prompt.md # ≥1
```

…and the same for `Important` / `Minor` in both reviewer prompts.

**The `[A-Z_]{2,}` derivation is a floor, not the inventory.** Each template also
carries fill slots that are not uppercase tokens, and the mechanical check cannot
see them — `implementer-prompt.md:42` has `Work from: [directory]`, and both
prompts carry at `:8-9` and `:13-14` the model slot with its warning that *an
omitted model silently inherits the session's most expensive one*.
`code-reviewer.md` carries a dozen descriptive slots such as
`[Yes | No | With fixes]` and `[What's well done? Be specific.]`. Enumerate each
template's non-uppercase slots **by hand, once, before its rewrite**, and carry
that list beside the derived one.

Derive each template's uppercase placeholders mechanically before and after,
never by hand:

```sh
rg -o --no-config '\[[A-Z_]{2,}\]' <template> | sort -u
```

Expected, as of now — the command is the requirement, this list is a convenience:

- `task-reviewer-prompt.md`: `[BASE_SHA] [BRIEF_FILE] [DIFF_FILE] [GLOBAL_CONSTRAINTS] [HEAD_SHA] [MODEL] [REPORT_FILE]`
- `implementer-prompt.md`: `[BRIEF_FILE] [REPORT_FILE]`
- `code-reviewer.md`: `[BASE_SHA] [DESCRIPTION] [HEAD_SHA] [PLAN_OR_REQUIREMENTS] [SHA]`

## Task 0 — build and validate the measurement tool

**Where this fits:** before everything. Every later task's acceptance criteria
are measurements, and an unvalidated instrument makes all of them worthless.

**Creates:** files under `$SCRATCH`, a scratch directory **outside** the
repository. Nothing in the tree.

### Steps

1. Choose `$SCRATCH` outside the checkout and record the path in your working
   notes. It must not be inside the repo — the whole repo ships to the plugin
   cache.
2. `git clone https://github.com/obra/superpowers.git $SCRATCH/upstream-sp` and
   `git -C $SCRATCH/upstream-sp checkout d884ae04edebef577e82ff7c4e143debd0bbec99`.
   Confirm with `git -C $SCRATCH/upstream-sp log -1 --format=%H`.
3. Write `$SCRATCH/containment.py` implementing exactly the method ADR 0002
   records: lowercase the text; keep every run of `[a-z0-9]` and discard
   everything else; cut into overlapping 8-token shingles; for candidate C
   against the union U of every upstream file's shingles,
   `containment(C) = |shingles(C) ∩ U| / |shingles(C)|`. Report alongside it the
   longest run of consecutive candidate tokens occurring contiguously in some one
   upstream file.
4. Add the `runs` capability: for a candidate, print each maximal token span of at
   least N tokens that occurs contiguously upstream. Used to judge whether a
   residual is command syntax or prose.
5. Add the `sweep` capability: run containment over every tracked file
   (`git ls-files`), sorted descending, with longest runs computed for anything
   above 1%.
6. **Materialise the baseline as a tree**, so validation reproduces at any point
   in the branch's life and `containment.py`'s `<repo-root> <path>` signature can
   express it. For each of the seven paths:

       base=$(git merge-base HEAD origin/main)
       mkdir -p "$SCRATCH/baseline/$(dirname <path>)"
       git show "$base:<path>" > "$SCRATCH/baseline/<path>"

7. **Validate before trusting it:**
   `python3 $SCRATCH/containment.py $SCRATCH/upstream-sp $SCRATCH/baseline <path>...`
   It must reproduce ADR 0002 exactly:

   | File | Containment | Longest run |
   |---|---|---|
   | `skills/forge/task-reviewer-prompt.md` | 100.00% | 1139 |
   | `skills/forge/implementer-prompt.md` | 100.00% | 816 |
   | `skills/forge/code-reviewer.md` | 100.00% | 663 |
   | `skills/forge/scripts/review-package` | 95.98% | 152 |
   | `skills/forge/scripts/task-brief` | 95.27% | 127 |
   | `skills/forge/scripts/sdd-workspace` | 11.60% | 45 |
   | `skills/forge/SKILL.md` (excluded from the bar) | 1.82% | 28 |

8. **Stop rule.** If the clone fails, or the pinned SHA does not resolve
   (`git -C $SCRATCH/upstream-sp cat-file -e d884ae04^{commit}`), stop the change
   and go to the operator — nothing is measured against any other ref, and no
   later task proceeds on an unvalidated instrument. Likewise if any figure
   differs, the rebuild is measuring something other
   than what ADR 0002 measured. Do not proceed to Task 1 — the discrepancy is the
   finding, and it goes to the operator. Note that this run's corpus is 171
   upstream files against ADR 0002's reported 140; because containment rises with
   the size of the union, agreement across the larger corpus is the conservative
   direction, but a *disagreement* is disqualifying.

### Acceptance criteria

- The clone is at the pinned SHA and `cat-file -e` resolves it.
- `$SCRATCH/baseline` holds all seven files as of the merge base.
- All seven figures reproduce exactly against that baseline tree.
- `$SCRATCH` is outside the repository and `git status` is clean.

---

## File map

| File | Disposition |
|---|---|
| `tests/fixtures/forge/task-brief-test.sh` | create — first coverage for `task-brief` |
| `tests/fixtures/forge/review-package-test.sh` | create — first coverage for `review-package` |
| `scripts/git-fixture-isolation-test.sh` | modify — register the two new suites in its `suites=()` list |
| `skills/forge/scripts/sdd-workspace` | rewrite (11.60% → target) |
| `skills/forge/scripts/task-brief` | rewrite (95.27% → target) |
| `skills/forge/scripts/review-package` | rewrite (95.98% → target) |
| `skills/forge/implementer-prompt.md` | re-author (100% → target) |
| `skills/forge/task-reviewer-prompt.md` | re-author (100% → target) |
| `skills/forge/code-reviewer.md` | re-author (100% → target) |
| `licenses/superpowers.LICENSE` | delete, and `licenses/` with it |
| `README.md` | modify — Licence section |
| `CLAUDE.md` | modify — Layout entry at line 33 |
| `skills/gauntlet/SKILL.md` | modify — `:289` sentence and `:291` table header |
| `docs/workflow/inventories/subagent-driven-development.md` | modify — one attribution line |
| `docs/workflow/plans/2026-08-11-strip-companion-and-realign-migration.md` | modify — one attribution line |
| `docs/adr/0003-close-the-upstream-attribution.md` | modify — fill the table, flip to `Accepted` |

`just test` and `scripts/list-shell-sources.sh` discover suites automatically, so
no recipe edit is needed. `scripts/git-fixture-isolation-test.sh` is the one
hand-maintained list.

---

## Task 1 — behaviour suites for `task-brief` and `review-package`

**Where this fits:** first commit. These two scripts have no coverage today, so
rewriting them and asserting nothing changed would be an unbacked claim. Written
against *current* behaviour and green before either script is touched.

**Creates:** `tests/fixtures/forge/task-brief-test.sh`,
`tests/fixtures/forge/review-package-test.sh`
**Modifies:** `scripts/git-fixture-isolation-test.sh`

### Interfaces

Both suites exercise the scripts as executables:

```
skills/forge/scripts/task-brief PLAN_FILE TASK_NUMBER [OUTFILE]
  exit 0 → wrote OUTFILE; stdout one line containing OUTFILE
  exit 2 → wrong arity, or PLAN_FILE does not exist
  exit 3 → no heading matching "Task N" in PLAN_FILE

skills/forge/scripts/review-package BASE HEAD [OUTFILE]
  exit 0 → wrote OUTFILE; stdout one line containing OUTFILE
  exit 2 → wrong arity, or BASE/HEAD unresolvable
```

`tests/fixtures/forge/sdd-workspace-test.sh` is the shape to follow: it clears
the local Git environment (`git rev-parse --local-env-vars`), builds a fresh repo
per case under `mktemp -d`, and cleans up on exit. Read it before writing these.

**Every case in both suites runs with cwd inside its own fixture repository** —
built the way that suite's `new_repo` builds one at lines 43-56: `mktemp -d`,
`git init -q`, explicit `user.email` and `user.name`, a seed commit, and
`pwd -P` because git reports a resolved toplevel and macOS `TMPDIR` sits under a
symlink. No case runs any of the three scripts from the checkout root.
`review-package` resolves `BASE` and `HEAD` from ambient git state, so a case
that forgets this passes or fails on adept's own history rather than the
fixture's.

### What the suites may assert

Never a diagnostic message's text, because the rewrite is licensed to change
wording. Assert:

- exit status on every path;
- all six error paths — `task-brief` arity (2), missing plan file (2),
  task-not-found (3); `review-package` arity (2), unresolvable BASE (2),
  unresolvable HEAD (2);
- that stderr is **non-empty** on each error path;
- that stdout is a single line containing the resolved output path;
- the output file's structural sections;
- `task-brief`'s extraction semantics, which are content assertions on a fixture
  plan and so are in bounds: asking for Task 1 in a plan that also contains
  Task 10 returns only Task 1; a `# Task N` line inside a fenced block is not a
  heading; a body ends at the next Task heading; the final task runs to EOF; any
  heading depth matches;
- **the default-`OUTFILE` case**, one per suite, invoked with two arguments only:
  the resolved path equals `<sdd-workspace stdout>/task-<N>-brief.md` and
  `<sdd-workspace stdout>/review-<from>..<to>.diff`, where each endpoint is what
  `git rev-parse --short` yields **in the fixture repo** — derive it by calling
  that command, never by slicing seven characters, since `core.abbrev` and repo
  size both move it. It is the
  only case that writes `.agent/` state, and Tasks 3 and 4 both carry a
  default-path acceptance criterion that nothing else covers;
- **that `task-brief` exit 3 leaves an empty `OUTFILE`.** The awk redirect at
  `skills/forge/scripts/task-brief:36` runs before the emptiness test at `:38`,
  so a not-found task creates a zero-byte file and then exits 3. Verified
  empirically. That is observable behaviour and R3 freezes "same files written",
  so the suite asserts it and the rewrite preserves it.

Fixtures are **authored**, not copied from an existing plan or upstream example —
they land in the candidate set and are held to the same containment bar.

### Steps

1. Read `tests/fixtures/forge/sdd-workspace-test.sh` end to end. Note how it
   unsets Git's local environment, how it reports `ok` / `fail`, and how its
   `trap` cleans up.
2. Write `tests/fixtures/forge/task-brief-test.sh` covering the assertions above.
   Executable (`chmod +x`), tabs, `set -euo pipefail`, Bash 3.2 constructs only.
3. Run it: `./tests/fixtures/forge/task-brief-test.sh` — expect every case to
   pass against the current script, and a final summary line.
4. Write `tests/fixtures/forge/review-package-test.sh` the same way.
5. Run it — same expectation.
6. **Prove both suites bite.** The existing suite hardcodes its target —
   `SCRIPT="$SCRIPT_DIR/../../../skills/forge/scripts/sdd-workspace"` — so give
   each new suite the same line with an override in front of it:

       SCRIPT="${FORGE_SCRIPT_DIR:-$SCRIPT_DIR/../../../skills/forge/scripts}/task-brief"

   The default is the real path, so the committed suite behaves identically and
   the mechanism costs nothing. **One fresh tree per mutation**, because a single
   reused directory accumulates every prior mutation and stops isolating anything
   after the first round:

       mutant=$(mktemp -d "$SCRATCH/mutant.XXXXXX")
       cp -R skills/forge/scripts/. "$mutant"
       # apply exactly one mutation inside "$mutant"
       FORGE_SCRIPT_DIR=$mutant ./tests/fixtures/forge/<suite>

   The trailing `/.` makes the copy behave the same whether or not the destination
   exists. Record which mutation produced which red.

   Mutations for `task-brief`, one per assertion class so the criterion below is
   actually reachable: swap `exit 2` → `exit 0` on each of the two exit-2 paths;
   swap `exit 3` → `exit 0`; drop the arity guard; write to the wrong path; remove
   the empty-file check so exit 3 never fires; corrupt the awk boundary so `Task 1`
   also matches `Task 10`; drop the `!infence` guard so a fenced `# Task N` counts
   as a heading; change `^#+` to `^##` so heading depth stops matching; stop
   resetting `intask` so a body runs past the next heading; redirect a diagnostic
   to stdout so stderr is empty on an error path; and change the default-path
   construction (`task-<N>-brief.md` → `task<N>-brief.md`).

   Mutations for `review-package`: swap each of the three `exit 2`s; drop one
   `git rev-parse --verify`; write to the wrong path; drop one written-file
   heading; add a second stdout line; redirect a diagnostic to stdout; and build
   the default filename by slicing seven characters instead of calling
   `git rev-parse --short`.

   A test that cannot redden is not a regression check. Record the results for the
   pull-request body.
7. Add both suite paths to the `suites=()` list in
   `scripts/git-fixture-isolation-test.sh`, beside
   `tests/fixtures/forge/sdd-workspace-test.sh`.
8. **Stage both suites before running any gate:**

       git add tests/fixtures/forge/task-brief-test.sh \
               tests/fixtures/forge/review-package-test.sh

   `just test` iterates `git ls-files -z -- '*-test.sh'` (Justfile:88) and
   `scripts/list-shell-sources.sh` iterates `git ls-files -z` (:69), so an
   untracked suite is invisible to `just test`, `just lint` and
   `just format-check` alike. Skipping this makes step 9 report success over
   files no gate ever opened.
9. Run `just verify` bare. `just test`'s suite count must rise by **exactly 2**
   from whatever it reported before this commit — record both numbers rather
   than trusting a constant, which rots the next time a suite lands. (At the time
   of writing it reports 9, so expect 11.)
10. Commit: `test: cover task-brief and review-package before rewriting them`,
    with the mutation results in the body.

### Acceptance criteria

- Both suites pass against the unmodified scripts.
- Every assertion has been shown to fail against a mutated copy, and the results
  are written down.
- No assertion references a diagnostic message's text.
- Both are registered in `scripts/git-fixture-isolation-test.sh`.
- Both suites still pass when the harness itself is invoked from outside any
  repository (`cd / && $WORK/tests/fixtures/forge/<suite>`) — the cheapest proof
  that no case reads ambient git state.
- `just verify` green.

---

## Task 2 — rewrite `sdd-workspace`

**Where this fits:** first of the six, because its 45-token run is the largest
among the scripts and a miss here is cheapest to discover early.

**Modifies:** `skills/forge/scripts/sdd-workspace`

### Interfaces

Takes no arguments. Prints the absolute workspace path on stdout and nothing
else — **both other scripts consume it through command substitution**, so a
second line or any decoration breaks them. Exits non-zero with a diagnostic when
`.agent/.gitignore` is tracked and does not ignore `.agent/sdd/`, or when
trackedness cannot be determined.

### What must not change

- The three-way tracked / untracked / unanswerable split on
  `git ls-files --error-unmatch`, including that anything other than 0 or 1 is
  fatal rather than folded into "untracked".
- The `git check-ignore -q .agent/sdd/` verification on the tracked path.
- The temp-file-and-rename write with the `trap` cleanup, and `chmod 644`.
- The explicit `cd` guard rather than `cd && pwd`.
- **Two frozen diagnostic substrings**, because the existing suite matches them:
  `refusing to modify it` (test line 177) and `cannot determine whether`
  (test line 227).

### Steps

1. Measure the baseline: `python3 $SCRATCH/containment.py ... skills/forge/scripts/sdd-workspace`
   → expect `11.60%`, run `45`.
2. Inspect what the overlap is:
   `python3 $SCRATCH/runs.py $SCRATCH/upstream-sp <abs path> sdd-workspace 8`
   → three runs, the largest a 45-token header comment. It is comment prose, not
   functional shell.
3. Rewrite the header comment block and the inline comments in first-party words.
   Rename variables where it reads naturally. Leave every command untouched.
4. Re-measure. Target: **< 2% containment, run ≤ 16**.
5. Run the existing suite: `./tests/fixtures/forge/sdd-workspace-test.sh` — expect
   all 8 assertions green, suite file unmodified.
6. Run `just verify` bare.
7. Commit: `refactor: re-express sdd-workspace in first-party words`.

### Acceptance criteria

- Below 2% containment, longest run ≤ 16 tokens.
- `tests/fixtures/forge/sdd-workspace-test.sh` passes, unmodified.
- No command name, flag, exit status or control-flow branch changes. Variable
  renames inside a command are expected and are the point.
- `just verify` green.

---

## Task 3 — rewrite `task-brief`

**Where this fits:** second, because its embedded `awk` program is the case the
probe does not cover — its token density is pattern text rather than variables,
so renaming variables may not be enough.

**Modifies:** `skills/forge/scripts/task-brief`

### Interfaces

```
task-brief PLAN_FILE TASK_NUMBER [OUTFILE]
```

Default `OUTFILE` is `<workspace>/task-<N>-brief.md`, where `<workspace>` comes
from running the sibling `sdd-workspace`. Exit 2 on wrong arity or a missing
plan; exit 3 when no `Task N` heading matches. On success, one stdout line
naming the file.

### What must not change

The extraction semantics Task 1's suite pins: fence tracking, the multi-digit
boundary (`Task 1` must not match `Task 10`), any heading depth, body runs to the
next Task heading or EOF.

### Steps

1. Baseline: expect `95.27%`, run `127`.
2. Rewrite the comments, the usage string, the diagnostics, and the variable
   names. The `awk` program's *patterns* must keep matching the same headings —
   the regex text is functional. Rename its internal variables (`infence`,
   `intask`) and restructure the surrounding shell.
3. Re-measure. Target **< 2%, run ≤ 16**. If the `awk` block alone holds it above,
   inspect with `runs.py` and decide: a run that is command syntax and ≤ 28 tokens
   may be exempted and named in ADR 0003's table; a prose run may not.
4. Run `./tests/fixtures/forge/task-brief-test.sh` — expect green, **suite
   unmodified**.

   If an assertion reds on wording, that is a **Task 1 defect, not a Task 3 one**,
   and it has a defined return path: stash or revert the rewrite, fix the
   assertion against the *unmodified* script, re-prove that assertion bites
   against a mutated copy, commit that as its own `test:` commit, then redo the
   rewrite. Never edit the suite in the same commit as the rewrite — that is
   exactly the "description of whatever the rewrite produced" the pre-written
   suites exist to prevent.
5. `just verify` bare.
6. Commit: `refactor: re-express task-brief in first-party words`.

### Acceptance criteria

- Below 2% containment, longest run ≤ 16 tokens, or a named exemption that is
  command syntax and ≤ 28 tokens.
- `tests/fixtures/forge/task-brief-test.sh` passes unmodified.
- Same arguments, same three exit statuses, same default output path.
- `just verify` green.

---

## Task 4 — rewrite `review-package`

**Where this fits:** third. The probe already demonstrated this one reaches 0.00%.

**Modifies:** `skills/forge/scripts/review-package`

### Interfaces

```
review-package BASE HEAD [OUTFILE]
```

Default `OUTFILE` is `<workspace>/review-<base7>..<head7>.diff`. Exit 2 on wrong
arity or an unresolvable revision. Writes a file containing the commit list, the
`--stat` summary, and the `-U10` diff. One stdout line naming the file and
reporting the commit count and byte size.

### What must not change

`git rev-parse --verify --quiet`, `git log --oneline`, `git diff --stat`,
`git diff -U10`, `git rev-list --count`, and `git rev-parse --short` — every one
byte-identical, flags included.

The four headings written **into the output file** are content rather than
diagnostics, and R3 freezes the files written: `# Review package:`, `## Commits`,
`## Files changed`, `## Diff`. Task 1's suite asserts them, so they are not
available to the rewrite.

### Steps

1. Baseline: expect `95.98%`, run `152`.
2. Rewrite using the five moves a probe of this file measured at 0.00% / 6
   tokens: rename `base`/`head` to `from`/`to`; introduce a single variable for
   the range and use it everywhere `${base}..${head}` appeared; replace `echo`
   with `printf`; validate both endpoints in a loop before writing anything; and
   rewrite every comment. No git *command, subcommand, flag or argument order*
   changes — only the variable names the commands read.
3. Re-measure. Target **< 2%, run ≤ 16**.
4. Run `./tests/fixtures/forge/review-package-test.sh` — green, suite unmodified.
5. `just verify` bare.
6. Commit: `refactor: re-express review-package in first-party words`.

### Acceptance criteria

- Below 2% containment, longest run ≤ 16 tokens.
- Suite passes unmodified.
- Every git invocation keeps the same command, subcommand, flags and argument
  order; only the variable names inside them change. Reading the diff, no
  invocation gains or loses a flag and none changes what it resolves to.
- `just verify` green.

---

## Task 5 — re-author `implementer-prompt.md`

**Where this fits:** first of the three templates. It carries the enum nothing
else does, so it is the highest-risk file in the change.

**Modifies:** `skills/forge/implementer-prompt.md`

### Method

**Author from the contract, do not paraphrase the existing file.** Read
`skills/forge/SKILL.md` — the dispatch flow at :190-208 and the four-status
handling at :213-223 — and write the prompt that contract requires.

**But the contract is thin, and an instruction inventory comes first.** Whole
blocks of this template have no in-repo consumer: the self-review block at
`:80-106` (Completeness / Quality / Discipline / Testing) is represented by five
words at `skills/forge/SKILL.md:196`, and `## Code Organization` (`:50-62`) and
the escalation triggers (`:63-79`) by nothing at all. Authoring from the contract
alone would silently drop them, which is exactly the redesign exclusion (c)
forbids — on an AI surface, in the change whose point is that the wording must
not be reused.

So: read the current template **once**, write down an inventory of every
instruction it gives (not its wording — what it tells the implementer to do),
then write the replacement from the contract *and* that inventory.

### What must survive

- The literals `DONE`, `DONE_WITH_CONCERNS`, `BLOCKED`, `NEEDS_CONTEXT`, in a
  `Status:` line the controller can parse.
- The placeholders `[BRIEF_FILE]` and `[REPORT_FILE]`.
- The `Work from: [directory]` directive (`:42`) — an implementer dispatched
  without a working directory mutates whatever tree it happens to be in.
- The model slot at `:8-9`, **including its warning** that an omitted model
  silently inherits the session's most expensive one. Dropping the warning is a
  cost regression nothing else catches.
- The instruction to write a report file rather than return prose inline.

### Steps

1. `rg -o --no-config '\[[A-Z_]{2,}\]' skills/forge/implementer-prompt.md | sort -u`
   → record the set.
2. Read `skills/forge/SKILL.md:190-223`.
3. Re-author the file.
4. Re-run the placeholder command → identical set.
5. Run the four word-bounded literal checks from *Global Constraints* → each ≥ 1,
   and `\bDONE\b` exactly as before. Then the two non-uppercase slots:
   `rg -c --no-config -F 'Work from:'` and
   `rg -c --no-config -F "session's most expensive one"` → both ≥ 1.
6. Measure. Target **< 2%, run ≤ 16**.
7. `just verify` bare.
8. Commit: `refactor: re-author the implementer prompt from its dispatch contract`.

### Acceptance criteria

- All four status literals present, word-bound checks pass.
- Placeholder set unchanged; `Work from:` and the model-cost warning present.
- **Every instruction in the inventory is present in the replacement, or its
  removal is named and justified in the commit body.** Containment and literal
  checks cannot see a dropped instruction; this criterion is the only thing that
  can.
- Below 2% containment, run ≤ 16.
- `just verify` green.

---

## Task 6 — re-author `task-reviewer-prompt.md`

**Modifies:** `skills/forge/task-reviewer-prompt.md`

### What must survive

- `Critical`, `Important`, `Minor` as grades.
- `Cannot verify from diff`, and the `⚠️` / `✅` / `❌` markers.
- **Two verdicts returned separately** — does it meet the spec, and is it good
  code. `skills/forge/SKILL.md:353-355` names a report carrying only one as a
  failure.
- Placeholders `[BASE_SHA] [BRIEF_FILE] [DIFF_FILE] [GLOBAL_CONSTRAINTS]
  [HEAD_SHA] [MODEL] [REPORT_FILE]` — `[DIFF_FILE]` is the review-package path
  and the reviewer cannot run without it.

### Method

As Task 5: this contract is thin too, so read the current template **once** and
write down an instruction inventory before authoring. Write the replacement from
the contract and that inventory together.

### Steps

1. Record the placeholder set with the `rg -o` command, and the instruction
   inventory.
2. Read `skills/forge/SKILL.md:196-208`, `:226`, `:353-367`.
3. Re-author from that contract and the inventory.
4. Re-run the placeholder command → identical set.
5. Literal checks: `Critical`, `Important`, `Minor` word-bound;
   `Cannot verify from diff` with `-F`; the three markers.
6. Measure. Target **< 2%, run ≤ 16**.
7. `just verify` bare.
8. Commit: `refactor: re-author the task reviewer prompt from its contract`.

### Acceptance criteria

- Every literal above present; placeholder set unchanged; both verdicts required
  by the template's output section.
- Every instruction in the inventory present in the replacement, or its removal
  named and justified in the commit body.
- Below 2% containment, run ≤ 16.
- `just verify` green.

---

## Task 7 — re-author `code-reviewer.md`

**Modifies:** `skills/forge/code-reviewer.md`

### Method

This file's in-repo contract is deliberately thin — one dispatch line at
`skills/forge/SKILL.md:208` and the severity table at
`skills/gauntlet/SKILL.md:289-297` — so unlike Tasks 5 and 6 it cannot be
authored from the contract alone. Read `code-reviewer.md` **once** to extract an
inventory: placeholders, the verdict line, the heading sequence, and the fact
that the headings appear at two sites (`## Output Format` and `## Example
Output`). Write that inventory down. Then write the replacement from the
inventory rather than from the file.

**The section sequence is inherited, not derived, and that is intentional.** Do
not "improve" it. ADR 0003 claims arrangement independence for the two templates
that have consumption sites; it does not claim it for this one, because a
whole-branch report is read by a person rather than dispatched on.

### What must survive

- `Critical`, `Important`, `Minor`.
- Placeholders `[BASE_SHA] [DESCRIPTION] [HEAD_SHA] [PLAN_OR_REQUIREMENTS] [SHA]`.
- The verdict line `**Ready to merge?** [Yes | No | With fixes]` — the template's
  form at :107, not the narrative `Ready to merge: With fixes` the example uses at
  :169.
- The section sequence **Strengths → Issues (Critical / Important / Minor) →
  Recommendations → Assessment**. This has no in-repo consumer; it is retained
  deliberately because a whole-branch report is read by a person. The file carries
  the headings twice, in `## Output Format` and `## Example Output`.

### Steps

1. `rg -n --no-config '^\s*#{2,4} ' skills/forge/code-reviewer.md` → record the
   heading list. Same for placeholders.
2. Re-author from `skills/forge/SKILL.md:208` and `skills/gauntlet/SKILL.md:289-297`.
3. Re-run both commands → heading list and placeholder set unchanged. Check the
   instruction inventory the same way Tasks 5 and 6 do.
4. Literal checks for the three grades.
5. Measure. Target **< 2%, run ≤ 16**.
6. `just verify` bare.
7. Commit: `refactor: re-author the whole-branch code reviewer prompt`.

### Acceptance criteria

- Grades, placeholders, verdict line and section sequence all present.
- Below 2% containment, run ≤ 16.
- `just verify` green.

---

## Task 8 — dispatch smoke, then the whole-tree measurement

**Where this fits:** after all six rewrites, before anything is deleted. This is
the only step that exercises the dispatch contract rather than inspecting it.

**Modifies:** nothing. Produces two records for the pull-request body.

### Steps

1. **Build the smoke fixtures.** `git init $SCRATCH/smoke-repo`, set
   `user.email` and `user.name` on it, and make two commits — the second adding a
   `plan.md` containing two tasks **and an obvious defect for the reviewers to
   find**: a shell snippet with an unquoted `$1` inside a `rm` argument, say.
   Without a planted defect, "at least one graded finding" tests whether the
   fixture happens to contain a bug, and its failure branch sends the hardest
   template in the change back for a re-author on that basis. Then, **with cwd `$SCRATCH/smoke-repo`**, run
   the *rewritten* scripts by absolute path, which doubles as an end-to-end check
   of Tasks 3 and 4:

       cd $SCRATCH/smoke-repo
       $WORK/skills/forge/scripts/task-brief     plan.md 1 $SCRATCH/brief.md
       $WORK/skills/forge/scripts/review-package HEAD~1 HEAD $SCRATCH/review.diff

   Then **derive the placeholder set rather than working from a list** — run
   `rg -o --no-config '\[[A-Z_]{2,}\]' <template> | sort -u` against each of the
   *three* rewritten templates and fill every token each prints. As of now that is
   seven: `[BRIEF_FILE]` → `$SCRATCH/brief.md`; `[DIFF_FILE]` →
   `$SCRATCH/review.diff`; `[REPORT_FILE]` → a path under `$SCRATCH`;
   `[GLOBAL_CONSTRAINTS]` → this plan's *Global Constraints* section; `[MODEL]` →
   the dispatching model; and `[BASE_SHA]` / `[HEAD_SHA]` → the smoke repo's two
   commit SHAs.
2. Dispatch one implementer subagent with the rewritten
   `skills/forge/implementer-prompt.md` on the throwaway task. **Fill
   `Work from:` with `$SCRATCH/smoke-repo` and dispatch with that as cwd** — this
   is the one dispatch that writes files, and an unpinned working directory means
   it edits the adept checkout. Require: its final message carries exactly one of
   `DONE` / `DONE_WITH_CONCERNS` / `BLOCKED` / `NEEDS_CONTEXT` in the `Status:`
   position.
3. Dispatch one task reviewer with the rewritten
   `skills/forge/task-reviewer-prompt.md` against `$SCRATCH/review.diff`.
   Require: both verdicts present, and at least one finding graded `Critical`,
   `Important` or `Minor`.
4. Dispatch one whole-branch reviewer with the rewritten
   `skills/forge/code-reviewer.md` against the smoke repo's two-commit range.
   Require the `**Ready to merge?**` verdict line, the four output sections, and
   that the planted defect is graded under a `Critical` / `Important` / `Minor`
   heading. This one is the hardest to
   re-author — its contract is thinnest and its arrangement is inherited — so
   leaving it unexercised would exempt the riskiest file. A failure here returns
   to **Task 7**.
5. Record all three outcomes verbatim for the PR body. **Commit nothing** — no
   harness, no fixture, no gate.
6. Run the whole-tree sweep from Task 0. Record the tracked file count and every
   file at or above 2%.
7. Confirm each of the six is below 2% with a run ≤ 16, and that the two new test
   fixtures are also below 2%.

### Acceptance criteria

- All **three** dispatches produced parseable output against the gated
  vocabulary — including the whole-branch reviewer's `**Ready to merge?**` verdict
  line and at least one finding under a `Critical` / `Important` / `Minor`
  heading.
- No dispatched prompt text contains an unfilled bracket token. Check with
  `\[[^]\n]{2,}\]`, not the uppercase pattern, and allow only the output-format
  exemplars meant to survive into the prompt: `[Yes | No | With fixes]`,
  `[Approved | Needs fixes]`, `[1-2 sentence technical assessment]`,
  `[What's well done? Be specific.]`, and `code-reviewer.md`'s four issue-bucket
  descriptions. Every other bracket token must be filled.
- Whole-tree scan recorded, with the file count and every above-2% file named.
- If any of the six missed, **Task 9 does not run at all** — go to Task 9b, which
  holds the whole fallback in one place.
- A fixture from Task 1 measuring at or above 2%, or carrying a run over 16
  tokens, is **rewritten and re-measured** before Task 9 begins. It is not a §2
  fallback case and does not keep the notice standing — it is a file this change
  authored, held to the same bar as the six.

### When the smoke does not pass

- **It runs and the output is off-contract** — a missing status literal, one
  verdict instead of two, an ungraded finding. Send the work back to Task 5,
  Task 6 or Task 7 as the failing template dictates, with the transcript
  attached. Task 9 is blocked until a re-run passes,
  and the re-run is recorded alongside the first.
- **It cannot be run at all** — reserved for a genuine absence of dispatch
  capability in the session, never for a missing fixture, which step 1 creates.
  Record it in the pull-request body as **not exercised**, name it as an accepted
  gap in ADR 0003's consequences, and tell the operator. Do not count it as a
  pass: the fallback control is reading the checklist, which the spec already says
  is insufficient on its own for this failure mode.

---

## Task 9 — remove the attribution and close the record

**Where this fits:** last, as one commit. Nothing here is licensed until Task 8's
measurement exists.

**Prerequisite:** the design commits — the spec, ADR 0003, and ADR 0002's
supersession banner — reach `main` in the *same* pull request as this task. Step 7
explains why.

**Modifies:** `licenses/superpowers.LICENSE` (delete), `README.md`, `CLAUDE.md`,
`skills/gauntlet/SKILL.md`, `docs/adr/0003-close-the-upstream-attribution.md`,
`docs/adr/0002-narrow-the-upstream-attribution.md` (banner already in place)

### Steps

1. `git rm licenses/superpowers.LICENSE` — the directory goes with its last file.
2. `README.md`: replace the whole *Licence* passage at **lines 58-72** — the
   framing sentence about six files, the six-file list, the
   `licenses/superpowers.LICENSE` link, and the closing "that list is a
   measurement" sentence — with MIT plus one sentence pointing at **ADR 0003**.
   No occurrence of `superpowers` or `licenses/` may survive in the file; step 6
   checks it.
3. `CLAUDE.md`: delete the Layout bullet at line 33,
   ``- `licenses/` — attribution for skills still derived from upstream work.``
4. **Attribution for the two quoting records.** Add one line to
   `docs/workflow/inventories/subagent-driven-development.md` and one to
   `docs/workflow/plans/2026-08-11-strip-companion-and-realign-migration.md`,
   naming `obra/superpowers` at `d884ae04` and its MIT licence beside the quoted
   material. These are the only shipped files that keep upstream runs after the
   close-out, and this change removes the notice that covered them — so the line
   goes in here rather than being deferred.
5. `skills/gauntlet/SKILL.md`: reword `:289` so it identifies the two templates by
   role rather than ancestry, and relabel the table header at `:291` from
   `| superpowers | here |` to `| $forge | here |`.
6. `docs/adr/0003-…`: fill the *After*, *Longest run* and *Exempted constructs*
   columns from Task 8. **Also update the candidate-set count** — the record says
   "every tracked file — 129 of them", and this change adds two fixtures, so that
   number is stale. Set it to what Task 8 step 6 recorded, and re-check the "Five
   files sit above the line" sentence against the same sweep. Then append one sentence to that paragraph **naming the deltas that
   land after the scan** — the deleted `licenses/superpowers.LICENSE`, the README,
   `CLAUDE.md` and `skills/gauntlet/SKILL.md` edits, and the table fill itself —
   and say whether the recorded count is the as-scanned (pre-deletion) figure or
   the post-deletion one. The spec requires this; the prose edits are first-party
   *removal* and the deletion is a deletion, so none can raise a figure, but a
   reader cannot verify that without knowing which tree was counted. Drop the exemption column entirely if no exemption was
   needed. Change `## Status` from `Proposed` to `Accepted (2026-08-11)` and
   remove the staging paragraph beneath it.
7. **Close-out sweep:** `rg -n --no-config -i 'superpowers|licenses/'`. A hit in
   `README.md`, `CLAUDE.md`, `skills/`, or `licenses/` means this task is not
   done. Expected survivors: ADR 0002, ADR 0003, this plan, the two specs, and the
   `docs/workflow/` inventories and plans that name the retired paths as history.
8. `just verify` bare, **and** `BASE_SHA=$(git rev-parse origin/main) just records`
   once. A bare `just records` prints "BASE_SHA unset — validating records only"
   and skips the append-only pass entirely, so it would not exercise this edit at
   all.

   The edit is legal for exactly one reason, and it is a prerequisite rather than
   a property: **ADR 0003 must not already be in `main`.** `APPEND_ONLY_SECTIONS="*"`
   exempts only `## Status`, and the table lives in `## Decision`, so filling it
   is an `E-REWRITE` the moment the record exists at the base ref. If the design
   commits somehow merged ahead of the implementation, do not fill the table —
   write a superseding ADR 0004 carrying the measurement instead.
9. Commit: `feat: close the upstream attribution`.

### Acceptance criteria

- `licenses/` gone; no reference to it survives in `README.md`, `CLAUDE.md`, or
  `skills/`.
- `rg -i superpowers skills/` returns no matches.
- ADR 0003 is `Accepted` with every table cell filled and no `*pending*` left.
- `just verify` green.
- The close-out sweep returns only the expected historical hits.

---

## Task 9b — partial closure, if any of the six missed

**Only if Task 8 found a file that cannot reach the bar.** Task 9 does not run;
this does instead. It transcribes the spec's per-bullet keying (R1) into steps,
because "R4 does not happen" is not an instruction anyone can follow.

1. `licenses/superpowers.LICENSE` **stays**, and so does `CLAUDE.md`'s Layout
   entry. Neither is keyed to a partial result.
2. `README.md`: keep the Licence section's structure but shorten the list to the
   files that actually missed, and re-aim the pointer at **ADR 0003** — the
   pointer move is not keyed to full closure, only the list is.
3. `skills/gauntlet/SKILL.md`: the `:289` sentence and the `:291` table header are
   keyed to the **two reviewer prompts alone**. If those two cleared the bar, make
   both edits regardless of what the scripts did.
4. `docs/adr/0003-…`: fill the table with the measured figures exactly as Task 9
   step 5 describes, update the candidate-set count, and flip `## Status` to
   `Accepted (2026-08-11)`. Then **resolve the conditional**: the Decision's "If
   any of the six keeps its citation" paragraph is replaced by what happened —
   which files kept their citation and why — so the merged record states an
   outcome rather than a branch.
5. **Do not rename the file.** "Close the upstream attribution" reads wrong for a
   partial close, but ADR 0002's supersession banner names
   `0003-close-the-upstream-attribution.md` by path, and the `adr` profile's
   `check_supersede_link` resolves it — a `git mv` dangles that banner and fails
   `E-SUPERSEDE-DANGLING` in the very `just records` run step 6 performs. Say what
   happened in the H1's wording and the record's own prose instead; the filename
   is a path, not a claim.
6. Close-out sweep, `just verify` bare, and
   `BASE_SHA=$(git rev-parse origin/main) just records`.
7. **Leave the residual owned.** `gh issue create` naming each file that kept its
   citation, with its measured containment and longest run, why it could not
   clear the bar, and what would close it — labelled from the repo's existing set
   (`type:chore`, a `priority:`, `status:needs-triage`). Then state issue #32's
   disposition explicitly: either closed as partially delivered with the successor
   linked, or held open with its unmet criteria restated. Do not leave the
   remaining rewrite living only in a merged record's prose — that is the failure
   mode ADR 0002's tracked follow-up existed to avoid, and the reason #32 exists.
8. Commit: `feat: narrow the upstream attribution to the files that kept it`.

### Acceptance criteria

- Every file that missed is still cited in both the README and ADR 0003, and the
  notice is still present.
- ADR 0003 carries no conditional and no `*pending*` cell.
- A successor issue exists naming every file that kept its citation, and #32's
  disposition is recorded.
- `BASE_SHA=... just records` reports no `E-SUPERSEDE-DANGLING`: ADR 0002's
  banner still resolves.
- `just verify` green.

---

## Cleanup

`$SCRATCH` holds the upstream clone, the checker, the mutant copies and the smoke
repository.

**Keep it until the pull request merges.** Branch review, `$detect-evil`, CI and
the merge itself can all force a change to one of the six, and any such change
re-measures that file — against the surviving instrument if it is still there, or
by re-running Task 0 in full, seven-figure validation included, if it is not.
`$SCRATCH/baseline` is what makes that re-validation possible after the rewrites
land — keep it alongside the checker.
Deleting the checker at Task 9 makes the cheap path unavailable exactly when it is
most likely to be needed.

After the merge, remove it with `trash` (never `rm -rf` as an interactive
command), and confirm nothing from it reached the checkout: `git status` clean,
and `git ls-files --others --exclude-standard` empty under the repository root.

## Rollback

The hazard is one-directional: Task 9's deletion of the notice is licensed by
Tasks 2–7's measurement, so the notice must never outlive the rewrite that
justified removing it.

**Pre-merge.** `git revert` in reverse task order, Task 9 first — whether or not
the branch has been pushed. There is no unpushed carve-out: `git reset --hard`
and every force-push form, `--force-with-lease` included, are denied
unconditionally by settings policy. Revert forward, always.

**Post-merge.** Under a `--merge` merge, `git revert -m 1 <merge>` restores the
rewrites and the notice together. Under `--rebase` there is no merge commit:
revert the range in reverse task order instead. The repository forbids squash for
code, so those are the only two shapes.

**Either way the revert must leave `docs/adr/` intact.** State the requirement as
an outcome, because two different errors fire: `E-GONE` if the record is deleted,
and `E-REWRITE` — which trips first and is easier to cause — if the revert merely
rolls the *After* table back to `*pending*`. So after any revert, `docs/adr/` must
be byte-identical to the base ref **plus** appended `## Consequences` text.
Restore it from the commit before the revert, which exists under both merge
shapes: `git restore --source=<sha-before-revert> -- docs/adr/`. Naming `<merge>`
does not work under `--rebase`.

Reverting a single rewrite commit is the dangerous case: it puts back upstream
expression while `licenses/superpowers.LICENSE` stays deleted. If one genuinely
must come out alone, the *same* commit restores the licence file and that file's
README entry — and appends to ADR 0003's `## Consequences`, because its *After*
column now describes a file that no longer exists in that form.
