---
name: grimoire
description: "Capture a non-obvious, verified problem solved in the current session as a durable solution document and, when available, a short memory-system recall pointer. Use when asked to compound learning, record a solution, or preserve a recurring debugging discovery."
---
# Compound a Solved Problem

Capture a problem solved in this session as durable, searchable knowledge with two
artifacts in two roles:

- **`docs/solutions/` in the project repo** — the full record. Portable, greppable,
  readable by any agent or human without special tooling. Source of truth.
- **vestige memory** — a short cross-project recall pointer to that record. Never a
  copy of it.

## 1. Identify the problem

From the current session (and the user-supplied hint, if given), identify the problem
that was just solved: symptom, investigation path, root cause, and fix. If the session
contains no solved problem — or the fix is unverified — say so and stop. Do not invent
a writeup from a half-finished debugging session.

## 2. Qualify it

Only compound problems that clear this bar:

- The root cause was **non-obvious**: it required real investigation, not the first
  hypothesis or an error message that named the fix.
- It is **likely to recur** — in this repo, in a sibling project, or as a class of
  mistake (API misuse, environment quirk, tooling trap).
- A future session that found this doc would **save 30+ minutes**.

Routine bugs, typos, and anything fully explained by an existing lint rule or test do
not qualify. If the problem does not clear the bar, say why in one sentence and stop.

## 3. Check for prior art

Search `docs/solutions/` (`rg -li` on root-cause keywords) and vestige
(`mcp__vestige__search`) for an existing record of the same root cause.

- Same root cause, new wrinkle → **update the existing doc** (append to Evidence,
  extend Prevention). Do not create a near-duplicate.
- Genuinely new → continue.

## 4. Write the solution doc

Record `git status --short` now — step 6 branches on whether the tree was clean
before this step. Then create `docs/solutions/<YYYY-MM-DD>-<short-slug>.md` (make
the directory if needed):

```markdown
---
title: <one-line problem statement>
date: <YYYY-MM-DD>
tags: [<root-cause class>, <subsystem>, <tooling involved>]
components: [<files or modules involved>]
---

## Problem

<symptom as observed: error text, failing command, wrong behavior>

## Root cause

<the actual mechanism, not the symptom — why it happened>

## Solution

<what fixed it, with file:line references and the verifying command + output>

## Prevention

<lint rule, test, hook, or convention that catches this class earlier; "none
practical" is an acceptable answer>
```

Write for a reader with zero session context. Concrete identifiers and exact error
strings beat prose — they are what future `rg` searches will hit.

## 5. Ingest the vestige pointer

Store one memory via `mcp__vestige__smart_ingest`: repo name, doc path, one-sentence
root cause, and the tags — nothing more. The doc is the record; vestige only needs
enough for recall to surface "this happened before, look at `<repo>/docs/solutions/<file>`"
from another project.

If the vestige tools are not available on this host, skip this step and tell the
user the recall pointer was not stored — the solution doc remains the source of
truth either way. Do not fail the skill over a missing pointer.

## 6. Commit

If the working tree was clean before step 4, commit the doc on the current branch as
`docs(solutions): <short problem statement>`. Never commit on the default branch; if
on it, leave the file uncommitted and tell the user. If the tree was already dirty,
leave the doc uncommitted so it rides with the in-flight work, and say so.
