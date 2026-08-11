# Behaviour inventory — `verification-before-completion` (becomes `references/true-seeing.md`)

Extracted from `skills/verification-before-completion/SKILL.md` (142 lines) at
commit `332a7fb` before any rewriting, per the rewrite spec §5. Rows are
observable behaviours, not wording.

Verdicts are the ones defined in
[`test-driven-development`](test-driven-development.md): **KEEP** into the
reference, **GATE** where a skill already owns the operational form, **DROP**
with a reason.

## The one that has to be got right

Spec §1 records a deliberate weakening: this stops being a skill the global
CLAUDE.md names for invocation and becomes a reference, "and a reference can be
skipped where an invoked skill cannot. Accepted."

That makes the *placement* of these behaviours matter more than their wording. A
rule that only exists in a skippable document is a rule that will be skipped at
exactly the moment it binds — when someone is tired and wants the work over
(row 12). So this inventory checks, for each rule, whether a **gate** holds it
somewhere unskippable, and says so. Where nothing does, the row says that too.

| # | Observable behaviour | Verdict | Destination / reason |
|---|---|---|---|
| 1 | Never claim complete, fixed, or passing without having run the verification in this same message | KEEP | The Iron Law, and the reference's whole subject. Nothing else in the repo states the *freshness* requirement — that a previous run does not license the claim |
| 2 | Identify which command proves the claim before running anything | KEEP | Step 1 of the gate function. The step people skip, because the plausible command is not always the proving one |
| 3 | Run the full command, not a subset or a re-run of the focused case | KEEP | Reinforced operationally by `$ship-pr` §1 — "run the **full** local check suite once (not just the focused tests for the files you touched)" — but the general rule is the reference's |
| 4 | Read the whole output, check the exit code, and count the failures | KEEP | The exit-code half is gated: `CLAUDE.md` says "Run gates bare… A gate's exit status is the verdict." The reading-the-output half is not gated anywhere |
| 5 | For a done, passing or mergeable claim, also run `git status --porcelain`; any untracked file means not green | KEEP | The sharpest rule in the file. A check never saw the file it was not shown, so green plus untracked is a false green |
| 6 | State the actual status with evidence when the output does not confirm the claim | KEEP | The half of the gate that makes it survivable — the alternative to claiming success is reporting truthfully, not staying silent |
| 7 | Do not trust a subagent's success report; check the VCS diff yourself | GATE + KEEP | `$build-tdd` party mode gates this per task — the reviewer reads a review package built from the diff, not the implementer's word. The reference states the general rule, which covers subagents no reviewer follows |
| 8 | A linter passing does not license a build claim; a build passing does not license a test claim | KEEP | The claim/evidence table's real content: each claim needs *its own* command |
| 9 | A regression test is not verified until the red-green cycle has been run — write, pass, revert the fix, watch it fail, restore, pass | KEEP | The most specific procedure in the file and stated nowhere else. `$build-tdd` and `references/trial-by-fire.md` cover red-green for *new* tests; this is the retrofit case, where the fix already exists |
| 10 | Verify requirements line by line against the plan, rather than inferring completion from tests passing | KEEP | Tests passing and requirements met are different claims — row 8's rule applied to the largest claim |
| 11 | Treat hedging words — "should", "probably", "seems to" — as a signal that verification has not run | KEEP | The self-diagnostic. Cheap, and the only rule here that fires before the claim is written |
| 12 | Treat expressions of satisfaction ("Great!", "Perfect!", "Done!") as completion claims subject to the same gate | KEEP | Closes the obvious loophole: the rule is about the assertion, not the sentence form |
| 13 | Apply the rule to paraphrases, synonyms and implications, not only to exact phrases | KEEP | Row 12 generalized, and the reason the reference cannot be a phrase blocklist |
| 14 | Verify before committing, before opening a PR, before moving to the next task, and before delegating | GATE | `$ship-pr` §1 gates the pre-push case; `$build-tdd` Guardrails gates the pre-commit case — "If a guardrail fails, stop and fix it. Do not commit with red guardrails" |
| 15 | Carry a "Common Failures" table of 8 claim/evidence/not-sufficient triples | KEEP, compressed | The table is the file's most usable artifact — it converts an abstract rule into "this claim needs that output". Compressed where rows duplicate: "Tests pass" and "CI green / mergeable" share row 5's point |
| 16 | Carry a "Rationalization Prevention" table of 8 excuses | KEEP, compressed | Same function as `trial-by-fire`'s rationalization table and kept for the same reason. Two rows fold into others: "Linter passed" is row 8, "Agent said success" is row 7 |
| 17 | Carry a "Key Patterns" section of five ✅/❌ pairs | DROP | **Condition:** confirm each pair is carried before deleting. Verified: Tests → 1, 15; Regression → 9; Build → 8; Requirements → 10; Agent delegation → 7. Row 9 survives as procedure, which is what made that pair worth reading |
| 18 | Carry a "Red Flags — STOP" list of 8 items | DROP | **Condition:** verified. Hedging words → 11; satisfaction → 12; about to commit → 14; trusting agents → 7; partial verification → 3; "just this once" → 16; tired → 16; any wording implying success → 13 |
| 19 | Carry a "When To Apply" list of triggers and a "Rule applies to" list of forms | DROP | **Condition:** verified. Triggers → 14; forms → 13. Both are the same two rows in list form |
| 20 | Justify the rule with "From 24 failure memories" and a list of five past incidents | DROP | An appeal to a record this repo does not hold and cannot show. It also mixes in "your human partner said 'I don't believe you'", which is another project's operator speaking — §2 asks for re-expression |
| 21 | Quote an instruction-file line — "Honesty is a core value. If you lie, you'll be replaced" — as the rule's grounding | DROP | Quotes a document this repo does not ship, and threatens rather than explains. Row 1's own argument — an unverified claim is a false statement about work someone will rely on — does the grounding without the borrowed authority |
| 22 | Assert that claiming completion without verification "is dishonesty, not efficiency" | KEEP | One line, and it is the reference's thesis rather than a slogan: it names what the shortcut actually is, which is why rows 11–13 refuse to accept softer wording |
| 23 | Announce "Violating the letter of this rule is violating the spirit of this rule" | KEEP | Same reason as `trial-by-fire` row 34 — it closes rows 12 and 13 against re-reading them as a phrasing exercise |
| 24 | Repeat "This is non-negotiable" / "No shortcuts for verification" as a closing section | DROP | Restates rows 1 and 22 for emphasis. The Iron Law is already stated once at full strength |

**Totals:** 24 rows — 16 KEEP (2 compressed), 2 GATE, 6 DROP.

142 lines is already the leanest of the eleven, and it survives nearly intact.
What comes out is the borrowed authority — another project's operator, its
instruction file, and its 24 unshown failure memories — which is precisely what
spec §2 asks to be re-expressed rather than carried.

**The placement finding.** Only rows 3, 4 (exit code), 7 and 14 have a gate
holding them. Rows 1, 5, 9, 10, 11, 12 and 13 exist in the reference alone,
which spec §1 accepted going in. Row 5 is the one worth naming: a clean
`git status --porcelain` is checkable, cheap, and currently asserted by no gate
in this repo. That is a candidate follow-up issue, not work for this unit.
