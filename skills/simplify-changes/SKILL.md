---
name: simplify-changes
description: "Apply a behavior-preserving simplification pass over recent changes: remove speculative abstraction, dead code, cleverness, redundancy, and noise, then verify with repository guardrails. Use when asked to simplify a diff, branch, PR, or recent work."
---
# Simplify

Refine code for clarity and maintainability **without changing what it does**. This is a
polish pass, not a refactor: every edit must be defensible as "same behavior, easier to
read." If a change might alter behavior, it belongs in a fix or feature commit, not here.

## Scope

Default scope is *recent changes*: the working tree plus the current branch's diff against
the base branch (`git diff origin/<base>...HEAD` — resolve the base, don't assume `main`).
User-supplied scope overrides: explicit paths, a PR number, or a branch ref. Never widen scope
beyond what was asked — an unrelated file with ugly code gets flagged in the report, not
edited.

## What to remove or tighten

Apply the applicable repository and agent instructions, in this priority order:

1. **Speculative abstraction** — utilities with one caller, parameters nothing passes,
   config nothing reads, branches nothing reaches. Inline or delete. (No premature
   abstraction; the third duplication earns the helper, not the first.)
2. **Dead and shadow code** — commented-out blocks, unused imports/vars, superseded
   implementations left "just in case." Delete entirely; replace-don't-deprecate.
3. **Cleverness** — nested ternaries, dense one-liners, implicit fallthrough, magic
   values. Rewrite explicit: if/else chains, named intermediates, named constants.
4. **Redundancy** — repeated expressions computed twice, conditions that re-check what
   the type or an earlier guard already proves, wrapper functions that only forward.
5. **Noise comments** — comments that restate the code. Keep only constraint comments
   (the "why" the code can't express). If a WHAT-comment is needed, refactor until it
   isn't.
6. **Limit violations introduced by the diff** — functions over 100 lines or complexity
   8, >5 positional params, lines over 100 chars.

## What NOT to do

- Do not change behavior, public interfaces, error messages, or log/output text.
- Do not remove an abstraction that has ≥2 real callers or encodes a genuine boundary.
- Do not chase "fewer lines" — explicit beats compact; a clear 10-line version wins over
  a clever 3-line one.
- Do not reformat untouched code or churn style that matches the file's existing idiom.

## Process

1. Enumerate the in-scope hunks; read each changed function in full, with enough of the
   surrounding file to know its idiom.
2. Make the edits, smallest first. Each edit stands alone — if one is questioned, the
   rest still hold.
3. Re-run the repo's guardrails on the touched files (linter, type checker, relevant
   tests — discover them; don't assume). A simplification that breaks a check is reverted,
   not argued with.
4. Report: what was simplified and why (one line each), what was deliberately left
   alone, and anything flagged-but-out-of-scope. If nothing needed simplifying, say so
   plainly — a no-op result is a valid result.
