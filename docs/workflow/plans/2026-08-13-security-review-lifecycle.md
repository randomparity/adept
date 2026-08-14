# Security review lifecycle implementation plan

**Goal.** Let `$trial-loop` select `$detect-evil` as its reviewer so standalone security
findings receive the existing four dispositions and bounded settled-state lifecycle.

**Architecture.** `$trial-loop` remains the sole coordinator and parses one optional reviewer
selector before forwarding the remaining invocation. Both supported reviewers continue to own
one-pass, read-only analysis and the shared artifact schema. `$detect-evil` gains only a pointer to
the composed lifecycle; it does not recurse or mutate reviewed state.

**Tech stack.** Markdown skill contracts, fresh read-only behavioral reviewers, repository shell
guardrails through `just`.

## Global constraints

- Branch: `feat/security-review-lifecycle-42`; `BASE_BRANCH=main`.
- Guardrail: `just verify` locally; CI invokes the same chain through `just ci`.
- Host architecture: `arm64`; target architectures: none declared; relationship:
  `no-target-declared`.
- The repository is public: no absolute host paths or private runtime state in committed files.
- Skill contracts remain instructions, not new executable programs or long-lived processes.
- Nothing automated asserts on prose. Behavioral semantics use a fresh independent reviewer;
  `just shape-check` proves only structural skill validity.
- Shell remains Bash 3.2-compatible, though this change adds no shell source.
- The frozen scope is issue #42's `WORK:SCOPE` token
  `F29B8DA3-15FF-4DDC-8878-C9C7CC58D7A8`; the operator approved ADR 0014's reviewer-selector
  design.
- Selector grammar is exactly `--reviewer gauntlet|detect-evil`, at most once before the first
  line-anchored `CHARTER`; omission means `gauntlet`.
- Parsing splits off and preserves the charter before consuming a selector value. Missing,
  unknown, and duplicate selectors stop before dispatch.
- Disposition, deferral, retry, iteration, convergence, rescope, artifact, working-tree commit,
  and caller-continuation behavior remains one shared contract.

## Files

- Modify `skills/trial-loop/SKILL.md`: own selector parsing and make the shared lifecycle reviewer-
  neutral without weakening gauntlet-specific guarantees.
- Modify `skills/detect-evil/SKILL.md`: document the canonical standalone settled-state invocation.
- No fixture script is added: a script asserting Markdown phrases would violate repository anatomy
  rule 4, while a model-driven executable test would be nondeterministic.

## Task 1 — Compose security review through trial-loop

**Files:** modify `skills/trial-loop/SKILL.md` and `skills/detect-evil/SKILL.md`.

**Interfaces:** consumes both reviewers' existing `--json --out` compact object and full artifact:
`{verdict, findings_count, suppressed_count, path, run_id}` plus `findings` and `suppressions` arrays.
Produces `$trial-loop [--reviewer gauntlet|detect-evil] <challenge-args>`; later quest, spellcraft,
forge, and direct callers continue to consume the default gauntlet behavior unchanged.

This is one task because the selector is not usable until the coordinator and scanner contracts
name each other, and no reviewer could accept one half as a working security lifecycle.

### 1. Prove the current contract fails the new behavior

Give a fresh read-only behavioral reviewer the unchanged `skills/trial-loop/SKILL.md`,
`skills/detect-evil/SKILL.md`, ADR 0014, and specification cases SRL-01 through SRL-08. Ask it to
trace each case and cite governing lines without calling either skill or editing files.

Expected: SRL-01 passes because gauntlet is hard-coded; SRL-02, SRL-03, SRL-03b, SRL-04,
SRL-05a/b, SRL-06/06b, and the detect-evil-specific parts of SRL-07/08 fail because trial-loop has
no selector or scanner dispatch and detect-evil names no settled lifecycle. Record this red result;
an immediate all-pass means the test did not bite and stops implementation.

### 2. Add reviewer selection to the trial-loop input contract

Replace the gauntlet-only opening and input definitions with text carrying these exact normative
rules:

```markdown
Run the selected reviewer against a target iteratively, fixing or dispositioning findings between
passes, until it returns `approve` or a bounded stop fires. The reviewer defaults to `$gauntlet`;
`--reviewer detect-evil` selects `$detect-evil`.

Before classifying challenge arguments, split at the first line-anchored `CHARTER` label and
preserve that block unchanged. In the pre-charter prefix, accept at most one
`--reviewer gauntlet|detect-evil`; omission means `gauntlet`. The flag consumes its next
pre-charter token. A missing value, unknown reviewer, or duplicate selector is an input error:
stop before target defaulting, hashing, artifact allocation, or worker dispatch. Remove a valid
selector before every one of those operations and before forwarding challenge arguments.
```

Update `## Inputs` to define `reviewer`, rename `challenge_args` as the selected reviewer's exact
arguments, and state that the selector and charter block are excluded from the target-and-flag
hash. Keep caller-supplied `--json`/`--out` stripping unchanged.

### 3. Make the loop reviewer-neutral without weakening shared safety

Throughout dispatch, artifact validation, audit lines, stop conditions, and reporting, replace a
hard-coded reviewer name only where the statement applies identically to both supported reviewers.
Use these forms consistently:

```markdown
run the selected reviewer in a **subagent** with
`--json --out <findings-path> <challenge-args>`
```

```text
review iteration <n>: reviewer=<gauntlet|detect-evil>, verdict=<verdict>,
findings=<count>, suppressed=<suppressed_count>
```

```markdown
- The selected reviewer returns `approve` → exit the loop and continue the workflow.
```

State that each pass reads the installed selected reviewer in full before invocation. Keep the
trailing charter's eight fields plus focus unchanged, and keep explicit target/mode insertion,
working-tree deferred commits, run-unique output, run-ID matching, suppression disclosure,
`heed-counsel`, all four dispositions, debt ownership, convergence, five-pass cycle cap, two-
rescope cap, silent-worker recovery, and whole-target reruns unchanged.

Keep the target-resolution rule precise: both reviewers share gauntlet's taxonomy through
detect-evil's delegation. A returned target-resolution error has no artifact or compact object,
stops immediately without spending the malformed-return retry, and cannot consume a stale file.

Retain gauntlet-specific text where it is true rather than mechanically renaming it: its broad
adversarial purpose, accepted-ADR implementation, and optional hard-enforcement example. Add the
detect-evil-specific guarantee that every pass performs its trust-boundary inventory and uses the
same finding bar; focus text cannot suppress a defensible finding from either reviewer.

### 4. Publish the canonical detect-evil composition

In `skills/detect-evil/SKILL.md`'s front-loaded caller contract, add this exact distinction:

```markdown
A direct `$detect-evil` invocation remains a one-pass, read-only checkpoint. When a standalone
caller wants findings iterated and dispositioned to a settled state, invoke
`$trial-loop --reviewer detect-evil <target and focus>`; `$trial-loop` owns fixes, deferral records,
bounded retries and iterations, and the terminal report. `$detect-evil` never invokes the loop or
mutates the target itself.
```

Add one example using `--base main` through trial-loop. Do not copy the four dispositions or stop
contract into detect-evil.

### 5. Run the focused green behavioral evaluation

Give a new context-isolated, read-only reviewer the changed skill files, ADR 0014, and the complete
specification. Require a line-cited trace of SRL-01, SRL-02, SRL-03, SRL-03b, SRL-04, SRL-05a,
SRL-05b, SRL-06, SRL-06b, SRL-07, and SRL-08.

Expected: every case has all observable pass traits and no forbidden trait. The reviewer must not
invoke skills, write artifacts, edit git state, or treat the plan/spec as implementation authority.
Any failed or untraceable case is red and must be fixed before the commit.

### 6. Verify and commit

Run, bare:

```sh
just shape-check
just public-safety
git diff --check
just verify
```

Expected: every command exits 0; `just verify` reports 14 suites passed, actionlint and zizmor no
findings, and only the repository's accepted missing-version manifest warning.

Review the diff for accidental gauntlet semantic loss, selector leakage into reviewer arguments,
duplicated lifecycle prose in detect-evil, and wording that claims behavior not implemented by the
skill contract. Stage only the two skill files and commit:

```sh
git add skills/trial-loop/SKILL.md skills/detect-evil/SKILL.md
git commit -m "feat: compose security scans through trial-loop"
```

**Acceptance:** the fresh green trace covers every SRL case; direct detect-evil remains read-only;
default trial-loop remains gauntlet-compatible; scanner selection reaches the same dispositions,
deferral records, caps, artifact checks, and caller continuation; all guardrails pass.

**Rollback and cleanup:** reverting the implementation commit restores gauntlet-only trial-loop
behavior without data migration. Remove every run-unique review artifact after its final consumer;
leave no findings file in the repository tree.

## Design-to-build checkpoint

Branch `feat/security-review-lifecycle-42`; base `main`; guardrail `just verify`. ADR 0014 and the
security-review-lifecycle specification are approved. Open design findings: none. The scope audit
must approve the candidate surface before `$forge` begins.
