---
name: saga
description: "Interview a rough feature idea into a GitHub epic containing a PRD and dependency-ordered, born-triaged native sub-issues. Use when a feature spans multiple pull requests and the user wants an epic, PRD, decomposition, or campaign-ready issue set."
---
# Plan an Epic

Turn the rough idea supplied by the user into a filed **epic**: a PRD living in the epic
issue's body, plus native sub-issues born triaged, ready for `$campaign`.

**Read-only until the step-6 confirmation gate.** No GitHub writes of any kind before
it; that one confirmation covers **every** write this skill performs, including the
delegated sub-issue filing.

## 1. Resolve repo

`gh repo view --json nameWithOwner --jq .nameWithOwner` → `owner/name`; pass
`--repo <owner/name>` on every `gh` call. A failure here *is* the auth check — same
preamble as `$bounty`; stop with the `gh` error rather than starting the interview.

## 2. Interview

Ask 3–6 questions, **one at a time**, multiple-choice where possible: problem, affected
users/flows, constraints, success criteria, explicit non-goals. Stop asking when the
answers stop changing the decomposition.

## 3. Escape hatch

If the interview reveals single-issue scope (one PR can carry it), say so and hand off
to `$bounty`. No epic for work one PR can carry.

## 4. Draft the PRD

Draft the epic issue body with mandatory sections: **Problem, Goals, Non-goals,
Requirements, Success criteria, Decomposition, Open questions**. Each Decomposition
entry: proposed title, seam rationale grounded in code you actually read
(`file:line` refs into *existing* modules — never files that don't exist yet), and any
ordering dependencies on sibling entries. Validate the dependency graph while drafting:
a cycle never reaches confirmation — surface it as an open question and re-cut the seams.

## 5. Adversarial pass

Write the draft to a scratchpad temp file. Dispatch `$gauntlet` on it as a read-only
subagent per `$trial-loop`'s dispatch recipe (`--json --out` to a scratchpad path —
one pass, not the loop). Focus: missing requirements, wrong seams, hidden coupling between
sub-issues, scope creep. Apply findings by default; carry the challenge summary to the
step-6 confirmation. A fundamental objection (wrong problem, wrong seams throughout)
loops back to the interview **at most once**, and the re-draft gets exactly one more
pass — two total. If the second pass still objects fundamentally, surface the
disagreement and stop.

## 6. Dedup + the one confirmation

Run `$bounty`'s step-3 dedup gate — search across **all states**, with its `gh search`
recipe and gotchas, adding `labels` to the `--json` fields (the branches below key on
the candidate's `epic` label) — for the epic *and* each proposed sub-issue.

- **Epic near-match found** (the candidate must itself be `epic`-labeled — a non-epic
  near-match gets the stock sub-issue treatment below instead): present it with state;
  offer **extend #N** — append the new
  entries (seam rationale and dependency lines included) to its Decomposition under this
  run's confirmation, then delegate filing. Annotation and recovery semantics stay
  identical to the fresh-epic path: adopted entries carry their `#<n> — <title>
  (adopted)` annotations **in the same edit as the append**, which **replaces step 7.1**
  (the epic already exists — never `gh issue create` here); step 7.2's topological pass
  and step 8 then apply unchanged, with `Blocked by #<n>` refs to pre-existing entries
  resolved from their annotations. Re-run the step-4 cycle check over the **union** of
  pre-existing and appended entries before the confirmation — a cycle re-cuts, never
  files. Never file a rival epic silently.
- **Sub-issue near-match found:** offer **adopt #N as a sub-issue** only if the candidate
  is open, has no parent, has no native sub-issues of its own, and is not `epic`-labeled
  (check parent/children via `gh api repos/<owner>/<name>/issues/<N>/sub_issues` and the
  issue's own parent field). Disqualified candidates fall back to `$bounty`'s stock
  near-match offer.

Then show, for a single explicit go/no-go: the full epic body; the sub-issue list with
each birth label; adopted issues marked distinctly with their current `status:` label —
and an in-flight adoptee headed for a dependent slot gets its **own explicit warning
line** (this confirmation will demote live work to `status:blocked`); dependencies as
`Blocked by <entry title>` placeholders with a note that numbers resolve at filing; and
the challenge summary.

## 7. File

1. **Epic:** `gh issue create` with the PRD as body via `--body-file`, label `epic`
   (ensure-create per the `quest-log` recipe), **no `status:` label**. Adopted
   entries are annotated `#<n> — <title> (adopted)` in the Decomposition **at
   body-creation time** — their
   numbers are already known — so no crash window exists before their links land.
2. **One topological pass over all entries** — adopted and created alike, blockers
   before dependents, so every `Blocked by #<n>` resolves to an already-numbered
   sibling. Per entry, in graph order:
   - **Adopted entry:** link via the `sub_issues` API. If it sits in a dependent
     position, apply `status:blocked` + append a `Blocked by #<n>` line (the stated,
     confirmed exception to leave-untouched) — its blocker was handled earlier in the
     pass or is already annotated (extend path), and so has a number. If the adoptee
     carried an in-flight `status:` label at adoption, first post/update a
     `WORK:TRAJECTORY` note recording its parked phase and live branch/PR, per the
     `quest-log` blocked-edge rule.
   - **Created entry:** delegate to `$bounty` decompose mode under its
     carried-confirmation contract (the waivers and refusal handling live there). The
     sub-issue's Evidence section is the entry's seam rationale (step 4). Birth
     labels: `status:ready` default;
     `status:needs-triage` for open-question entries; `status:blocked` +
     `Blocked by #<n>` for dependents — **blocked wins** when both apply (the open
     question survives in the body and the epic's Open Questions). After each create,
     annotate the epic's Decomposition entry to `#<n> — <title>` (one `gh issue edit`
     per entry).

## 8. Report and stop

Epic URL; sub-issue list in three buckets — `ready` (dependency-free), `blocked` /
`needs-triage` (with what unblocks each), adopted (with pre-existing state) — and a
paste-ready `$campaign <n…>` line containing **only the dependency-free `status:ready`
subset**. Launching it is the operator's move. Stop.

## Failure modes

- **Partial filing** (epic filed, sub-issue *k* of *n* fails): report exactly which
  sub-issues exist, stop. Recovery = re-run `$bounty decompose #<epic>` — its epic-parent
  recovery contract (annotation-first diff, re-link for `(adopted)` entries) does the
  rest.
- **`gh` < 2.94.0** (no `--parent`): decompose mode's documented `sub_issues` API
  fallback applies; this skill delegates rather than handling it.
- **Interview stalls on load-bearing unknowns:** file with an Open Questions section;
  affected sub-issues are born `status:needs-triage`, flowing into the triage path.

## Hard constraints

- No GitHub writes before the step-6 confirmation; exactly one confirmation per run.
- Explicit `--json` fields on every `gh` read; bodies via `--body-file`; never `eval`.
- The epic never carries a `status:` label.
- Single-level decomposition; epic closure and unblocking stay manual.
