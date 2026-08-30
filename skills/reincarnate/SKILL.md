---
name: reincarnate
description: "Validate and rebuild stale AGENTS.md or CLAUDE.md guidance from current repository evidence. Use when project or user AI instructions have drifted, mention commands or layout that may no longer exist, or need an init-style refresh."
---
# Reincarnate AI Guidance

Replace a stale manifestation of `AGENTS.md` or `CLAUDE.md` with guidance grounded in
the repository as it exists now. Preserve valid policy and intent; do not preserve a
claim merely because the old file states it confidently.

## 1. Choose the guidance to rebuild

Identify the repository-level and user-level instruction files that apply to the
current work. Include nested files whose directory scope matters. State which files
you will inspect and which, if any, the operator wants rebuilt.

Treat their scopes differently. Repository files may be rebuilt from evidence in that
repository. A user-level file governs more than the current repository: preserve every
unrelated clause verbatim, and limit the ordinary refresh to repository-specific claims.
A complete user-level rebuild requires an explicit full-scope audit and explicit deletion
decisions in the proposed patch.

Read-only discovery is allowed. Do not edit any guidance yet.

## 2. Reconstruct the current truth

Inspect local evidence before judging the guidance:

- manifests, task runners, and CI workflows for supported commands and tool versions;
- the actual directory tree and representative source files for layout and conventions;
- configured linters, formatters, tests, hooks, and generated-artifact rules;
- durable policy records and current repository documentation for intentional constraints;
- applicable higher-precedence instructions for rules the rebuilt file must retain.

First apply the active harness's native instruction precedence and file scopes, then
identify operator-owned policy. Repository behavior cannot repeal policy: surface a
policy conflict to the operator. For falsifiable repository facts only, prefer executable
configuration and current source over descriptive prose when they conflict. Do not
silently turn an observed convention into policy. Mark a claim `unverifiable` when local
evidence cannot settle it, and ask the operator rather than inventing an answer or
searching externally without permission.

## 3. Diagnose drift

Classify each meaningful existing instruction as:

- **current** — supported by present evidence;
- **stale fact** — a falsifiable repository claim contradicted by present evidence;
- **unverifiable** — neither confirmed nor contradicted;
- **policy** — an operator-owned rule that repository behavior cannot repeal; a conflict
  needs an operator decision.

Check especially for renamed or missing commands, obsolete paths, duplicated rules,
wrong default branches, outdated tool requirements, test instructions that no longer
work, and guidance copied from another scope.

## 4. Draft the new manifestation

Draft a complete replacement for each selected repository file. Keep only guidance that
helps an agent act correctly in that scope. Remove duplication, historical explanation,
and generic advice already supplied by a higher-precedence file or the agent harness.
For a user-level file, retain unrelated and unverifiable clauses verbatim unless the
operator explicitly authorized the full-scope rebuild described above.

The draft must distinguish verified repository facts from operator policy and must not
weaken security, data-safety, accessibility, or explicit operator constraints. Use the
repository's established terminology and commands exactly.

Show the operator:

1. the drift found and the evidence for each correction;
2. any unverifiable or conflicting claims that still need a decision;
3. the proposed patch or replacement text.

## 5. Confirm, write, and verify

Ask for confirmation before replacing any selected guidance file. Confirmation covers
only the displayed patch; revise and ask again if the proposed content changes
materially.

After confirmation, apply the approved edit. Re-read the resulting files, check their
instruction precedence and scope, and run only the repository checks relevant to
documentation or instruction files. Report what changed, what evidence was used, which
checks ran, and any claims left unverifiable.

If confirmation is withheld, leave every file unchanged and return the draft as the
result.
