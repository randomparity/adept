# Implementation plan — the review summary names the `$trial-loop` exit

Goal: give `$quest`'s durable review summary an `exit:` field, so a run that ended in a named
non-blocking `$trial-loop` exit no longer publishes `verdict: needs-attention` alone.

Architecture: prose only. The contract lives in `skills/quest/SKILL.md`'s *Ship It* section as a
fenced field block; three sites in that one file reference it and must agree. No script, no test,
no schema. The decision is `docs/adr/0021-review-summary-names-the-trial-loop-exit.md`; the
design is `docs/workflow/specs/2026-08-18-review-summary-named-exit-design.md`.

Tech stack: Markdown. No build step.

## Global constraints

- **Repository is public.** No absolute user paths, hostnames, addresses, or session state.
  `scripts/check-public-safety.sh` enforces this; plans and specs name the checkout root `$WORK`.
- **Anatomy rule 1** — a skill is instructions, not a program. This change adds no file to a
  skill directory.
- **Anatomy rule 2** — executable code must do something a model cannot do reliably inline. ADR
  0021 declined a field-list check in `skills/quest/scripts/publish-forge-review` on this ground.
  **That script and `tests/fixtures/quest/publish-forge-review-test.sh` are not to be edited.**
- **Anatomy rule 4** — nothing automated asserts on prose. Add no gate, test, or grep over the
  text this plan writes.
- **Guardrail command** — `just verify`, run bare. No pipes, no `|| true`.
- **Branch** — `feat/review-summary-named-exit-143`; `BASE_BRANCH` is `main`.
- **The contract, verbatim** — six exact, non-empty, single-line fields in order:

  ```text
  verdict: <trial-loop reviewer verdict>
  exit: <trial-loop run outcome, or none>
  findings: <count>
  iterations: <count>
  security: <$detect-evil verdict or not triggered>
  delivered-head-sha: <full exact delivered PR head SHA>
  ```

- **The `exit:` values, verbatim** — `none`, `converged-with-deferrals`,
  `sound-with-record-notes`, `converged-on-own-surface`, `blocked-at-budget`. A named exit
  outranks `none` where a run matches both. `blocked-at-budget` is not writable until issue #151
  documents `$quest`'s resume path.
- **Write discipline is unchanged and must survive this edit** — `mktemp` beside the ledger,
  atomic rename only after the fields are written, reject CR/NUL/outer markers, byte-for-byte
  readback before rename, mode 0600 on both the temporary and installed file.

## Files

| file | responsibility |
|---|---|
| `skills/quest/SKILL.md` | the sole home of the contract; three sites to change |

Nothing else. `skills/quest-log/SKILL.md` describes the annotation's outer structure and names no
summary field, so it stays untouched.

## Task 1 — land the contract and retire its duplicates

One task: the three sites are one logical change, and no reviewer could accept any one of them
while rejecting another — a summary block gaining a field while a paragraph two hundred lines up
still says the summary has no member for the exit is a self-contradicting file.

**Modifies:** `skills/quest/SKILL.md`. **Creates:** nothing. **Tests:** none (anatomy rule 4).

### Interfaces

Consumes: ADR 0021's field list and value set, transcribed in *Global constraints* above.
Relied on by: issue #141, which adds step 6 caller routing for *converged with deferrals* and
*converged on own surface* and reads their `exit:` values from ADR 0021 — **this task writes no
routing prose for either exit.**

### Step 1.1 — replace step 6's workaround paragraph

At `:432-436` (verify the range on the branch first; the merge with `main` may have moved it),
replace the whole paragraph, which currently reads:

> The review summary below is a five-field, single-line contract that has no member
> for either list and asks for a `<trial-loop verdict>` this exit is not, so it is
> not where they go. Write the loop's last reviewer verdict in that field as the
> contract says, and name the exit in `WORK:REVIEW` and the PR body instead;
> widening the summary is tracked in issue #143.

with a paragraph stating the landed behaviour: the review summary carries an `exit:` field, this
exit's value is `sound-with-record-notes`, `verdict:` still takes the loop's last reviewer
verdict, and the two lists still go to `WORK:REVIEW` and the PR body because the summary is a
single-line-field contract that cannot hold them. Do not mention issue #143 as tracking future
work — it is this change.

Keep the preceding paragraph at `:424-430` untouched: it describes the exit itself, which this
change does not alter.

### Step 1.2 — stop `:543-544` enumerating the members

That sentence currently names the members in prose — "(verdict, findings count, iterations,
`$detect-evil` verdict, full delivered HEAD SHA)". Adding `exit:` to it would put the field list
in a second place, which ADR 0021's rejection of the field-list check explicitly forbids.
Replace the parenthetical with a pointer to the field block below rather than a sixth member.

### Step 1.3 — add `exit:` to the contract block

At the fenced block at `:562-568`, insert `exit: <trial-loop run outcome, or none>` as the second
line, after `verdict:`. Change the sentence introducing the block so it says six fields where it
says five, if it states a count. Leave every surrounding sentence about `mktemp`, atomic rename,
CR/NUL/marker rejection, byte-for-byte readback and mode 0600 exactly as it is.

### Step 1.4 — state the values once, below the block

Immediately after the block, add the value list: the five values, what a caller writes for each
`$trial-loop` run ending, the precedence rule that a named exit outranks `none`, and the
restriction that `blocked-at-budget` waits on issue #151. Cite ADR 0021 as the authority. Keep it
to a short paragraph plus a list — the ADR carries the argument, this carries the instruction.

### Step 1.5 — verify

Run, bare, from the worktree root:

```sh
just verify
```

Expect exit 0. Within it: `just records` prints `Records OK.` over 20 ADR records after its own
suite reports `175 passed, 0 failed`; `just plugin-check` passes with exactly one expected
warning, `plugins[0] plugin.json → version: No version specified`; `just shape-check`,
`just lint`, `just format-check`, `just public-safety`, `just ripgrep-config-check`, `just test`
and `just actions-check` all pass. Any other warning is a defect.

Then confirm no duplicate enumeration survives:

```sh
rg -n --no-config 'findings count|five-field|widening the summary' skills/quest/SKILL.md
```

Expect no matches. A match means a site from steps 1.1–1.2 was missed.

### Acceptance criteria

1. `skills/quest/SKILL.md` contains exactly one enumeration of the summary's members: the fenced
   block, now six lines with `exit:` second.
2. Step 6 describes the landed behaviour and no longer points at issue #143 as tracked-separately
   future work.
3. Every sentence governing the write discipline is byte-identical to its state before this
   change.
4. The five `exit:` values, the precedence rule, and the `blocked-at-budget` restriction appear
   once, below the block.
5. No step 6 routing prose is added for *converged with deferrals* or *converged on own surface*.
6. `skills/quest/scripts/publish-forge-review` and
   `tests/fixtures/quest/publish-forge-review-test.sh` are unmodified.
7. `just verify` exits 0.

### Rollback

The change is confined to one file with no generated artifact and no state. `git revert` of the
single commit restores the prior contract; nothing else has to be undone.
