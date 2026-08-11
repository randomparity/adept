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
- **Never `rm -rf`.** Use `git rm` for tracked deletions.
- **Public repo.** No absolute host paths in committed files; plans and specs name
  the checkout root as `$WORK`. `scripts/check-public-safety.sh` enforces it.
- **Threshold:** below **2% containment** and **no shared run over 16 tokens**,
  measured against `obra/superpowers@d884ae04edebef577e82ff7c4e143debd0bbec99`.
  A run may be exempted only if it is command syntax rather than prose *and* no
  longer than 28 tokens; exemptions are named in ADR 0003's table.
- **Nothing functional changes in the scripts.** Same arguments, same exit codes,
  same files written, same stdout contract. Comments, diagnostic wording, variable
  names and statement structure are what change.
- **Anatomy rule 4:** no automated gate asserts on prose. The literal checks below
  are commands a person runs from a checklist, never wired into `just verify`.

### The measurement tool

Not in the repo and does not enter it (ADR 0002, anatomy rule 2). It lives at
`$SCRATCH/containment.py` with the pinned upstream clone at `$SCRATCH/upstream-sp`:

```
python3 $SCRATCH/containment.py $SCRATCH/upstream-sp <repo-root> <path> [<path>...]
```

It prints `containment` and `longest run` per path. It reproduces all six of ADR
0002's figures exactly, which is what licenses trusting it.

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

Derive each template's placeholders mechanically before and after, never by hand:

```sh
rg -o --no-config '\[[A-Z_]{2,}\]' <template> | sort -u
```

Expected, as of now — the command is the requirement, this list is a convenience:

- `task-reviewer-prompt.md`: `[BASE_SHA] [BRIEF_FILE] [DIFF_FILE] [GLOBAL_CONSTRAINTS] [HEAD_SHA] [MODEL] [REPORT_FILE]`
- `implementer-prompt.md`: `[BRIEF_FILE] [REPORT_FILE]`
- `code-reviewer.md`: `[BASE_SHA] [DESCRIPTION] [HEAD_SHA] [PLAN_OR_REQUIREMENTS] [SHA]`

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
the local Git environment, builds a scratch repo under `mktemp -d`, and cleans up
on exit. Read it before writing these.

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
  heading depth matches.

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
6. **Prove both suites bite.** For each, copy the script to a scratch path,
   mutate it, point the suite at the copy, and confirm the expected case reddens.
   One mutation per error path: swap each `exit 2` / `exit 3`, drop an arity
   guard, drop a `git rev-parse --verify`, write to the wrong path, drop a
   structural section, add a second stdout line. A test that cannot redden is not
   a regression check. Record the results for the pull-request body.
7. Add both suite paths to the `suites=()` list in
   `scripts/git-fixture-isolation-test.sh`, beside
   `tests/fixtures/forge/sdd-workspace-test.sh`.
8. Run `just verify` bare. Expect it green, with `just test` reporting two more
   suites than before.
9. Commit: `test: cover task-brief and review-package before rewriting them`,
   with the mutation results in the body.

### Acceptance criteria

- Both suites pass against the unmodified scripts.
- Every assertion has been shown to fail against a mutated copy, and the results
  are written down.
- No assertion references a diagnostic message's text.
- Both are registered in `scripts/git-fixture-isolation-test.sh`.
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
- `git diff` shows no change to any command, flag, exit code, or control flow.
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
   unmodified**. If an assertion reds on wording, the suite was asserting a
   diagnostic string and Task 1 was wrong; fix the suite's assertion, not the
   script's message.
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

### Steps

1. Baseline: expect `95.98%`, run `152`.
2. Rewrite following the probe at `$SCRATCH/probe-review-package`, which measured
   0.00% / 6 tokens: rename `base`/`head` to `from`/`to`, introduce a single
   variable for the range, replace `echo` with `printf`, validate both endpoints
   in a loop before writing anything, and rewrite the comments.
3. Re-measure. Target **< 2%, run ≤ 16**.
4. Run `./tests/fixtures/forge/review-package-test.sh` — green, suite unmodified.
5. `just verify` bare.
6. Commit: `refactor: re-express review-package in first-party words`.

### Acceptance criteria

- Below 2% containment, longest run ≤ 16 tokens.
- Suite passes unmodified.
- Every git invocation byte-identical to the current file.
- `just verify` green.

---

## Task 5 — re-author `implementer-prompt.md`

**Where this fits:** first of the three templates. It carries the enum nothing
else does, so it is the highest-risk file in the change.

**Modifies:** `skills/forge/implementer-prompt.md`

### Method

**Author from the contract, do not paraphrase the existing file.** Read
`skills/forge/SKILL.md` — the dispatch flow at :190-208 and the four-status
handling at :213-223 — and write the prompt that contract requires. Read the
current template once to extract *what it must contain*, then write from the
contract, not from its wording.

### What must survive

- The literals `DONE`, `DONE_WITH_CONCERNS`, `BLOCKED`, `NEEDS_CONTEXT`, in a
  `Status:` line the controller can parse.
- The placeholders `[BRIEF_FILE]` and `[REPORT_FILE]`.
- The instruction to write a report file rather than return prose inline.

### Steps

1. `rg -o --no-config '\[[A-Z_]{2,}\]' skills/forge/implementer-prompt.md | sort -u`
   → record the set.
2. Read `skills/forge/SKILL.md:190-223`.
3. Re-author the file.
4. Re-run the placeholder command → identical set.
5. Run the four word-bounded literal checks from *Global Constraints* → each ≥ 1,
   and `\bDONE\b` exactly as before.
6. Measure. Target **< 2%, run ≤ 16**.
7. `just verify` bare.
8. Commit: `refactor: re-author the implementer prompt from its dispatch contract`.

### Acceptance criteria

- All four status literals present, word-bound checks pass.
- Placeholder set unchanged.
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

### Steps

1. Record the placeholder set with the `rg -o` command.
2. Read `skills/forge/SKILL.md:196-208`, `:226`, `:353-367`.
3. Re-author from that contract.
4. Re-run the placeholder command → identical set.
5. Literal checks: `Critical`, `Important`, `Minor` word-bound;
   `Cannot verify from diff` with `-F`; the three markers.
6. Measure. Target **< 2%, run ≤ 16**.
7. `just verify` bare.
8. Commit: `refactor: re-author the task reviewer prompt from its contract`.

### Acceptance criteria

- Every literal above present; placeholder set unchanged; both verdicts required
  by the template's output section.
- Below 2% containment, run ≤ 16.
- `just verify` green.

---

## Task 7 — re-author `code-reviewer.md`

**Modifies:** `skills/forge/code-reviewer.md`

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
3. Re-run both commands → heading list and placeholder set unchanged.
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

1. Dispatch one implementer subagent using the rewritten
   `skills/forge/implementer-prompt.md` on a throwaway task in a scratch
   directory. Require: its final message carries exactly one of `DONE` /
   `DONE_WITH_CONCERNS` / `BLOCKED` / `NEEDS_CONTEXT` in the `Status:` position.
2. Dispatch one task reviewer using the rewritten
   `skills/forge/task-reviewer-prompt.md` against a small diff. Require: both
   verdicts present, and at least one finding graded `Critical`, `Important` or
   `Minor`.
3. Record both outcomes verbatim for the PR body. **Commit nothing** — no harness,
   no fixture, no gate.
4. Run the whole-tree scan: `python3 $SCRATCH/sweep.py $SCRATCH/upstream-sp <repo-root>`.
   Record the tracked file count and every file at or above 2%.
5. Confirm each of the six is below 2% with a run ≤ 16, and that the two new test
   fixtures are also below 2%.

### Acceptance criteria

- Both dispatches produced parseable output against the gated vocabulary.
- Whole-tree scan recorded, with the file count and every above-2% file named.
- If any of the six missed, **stop**: the spec's §2 fallback applies, Task 9's
  first two bullets do not happen, and ADR 0003 is revised to say so.

---

## Task 9 — remove the attribution and close the record

**Where this fits:** last, as one commit. Nothing here is licensed until Task 8's
measurement exists.

**Modifies:** `licenses/superpowers.LICENSE` (delete), `README.md`, `CLAUDE.md`,
`skills/gauntlet/SKILL.md`, `docs/adr/0003-close-the-upstream-attribution.md`,
`docs/adr/0002-narrow-the-upstream-attribution.md` (banner already in place)

### Steps

1. `git rm licenses/superpowers.LICENSE` — the directory goes with its last file.
2. `README.md`: remove the six-file list and the
   `licenses/superpowers.LICENSE` link. Keep MIT. Re-aim the measurement pointer
   at **ADR 0003**, not 0002.
3. `CLAUDE.md`: delete the Layout bullet at line 33,
   ``- `licenses/` — attribution for skills still derived from upstream work.``
4. `skills/gauntlet/SKILL.md`: reword `:289` so it identifies the two templates by
   role rather than ancestry, and relabel the table header at `:291` from
   `| superpowers | here |` to `| $forge | here |`.
5. `docs/adr/0003-…`: fill the *After*, *Longest run* and *Exempted constructs*
   columns from Task 8. Drop the exemption column entirely if no exemption was
   needed. Change `## Status` from `Proposed` to `Accepted (2026-08-11)` and
   remove the staging paragraph beneath it.
6. **Close-out sweep:** `rg -n --no-config -i 'superpowers|licenses/'`. A hit in
   `README.md`, `CLAUDE.md`, `skills/`, or `licenses/` means this task is not
   done. Expected survivors: ADR 0002, ADR 0003, this plan, the two specs, and the
   `docs/workflow/` inventories and plans that name the retired paths as history.
7. `just verify` bare — including `just records`, which must accept the
   `Proposed` → `Accepted` transition and the filled table.
8. Commit: `feat: close the upstream attribution`.

### Acceptance criteria

- `licenses/` gone; no reference to it survives in `README.md`, `CLAUDE.md`, or
  `skills/`.
- `rg -i superpowers skills/` returns no matches.
- ADR 0003 is `Accepted` with every table cell filled and no `*pending*` left.
- `just verify` green.
- The close-out sweep returns only the expected historical hits.

---

## Rollback

Every task is one commit on a feature branch and nothing is published mid-way.
`git revert` the offending commit; the only ordering that matters is that Task 9
must not survive a revert of Tasks 2–7, since the notice's removal is licensed by
their measurement.
