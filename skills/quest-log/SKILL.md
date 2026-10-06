# Quest log skill

Processes repair actions end-to-end: evaluates intent, enforces policy, and manages standing-repair state.

## Intent

Identify the action being taken, determine which skills and policies apply, and check for standing authority.

## Standing repair authority

Standing repair authority binds maintainer approval to the exact Git blob of the instruction file that holds the policy section. Editing that file invalidates old packets.

A repair whose diff adds, edits, removes, or renames any accepted instruction location (`AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`) is barred from standing-policy admission and from policy-only merge, regardless of the policy's permitted surfaces. Such repairs fall back to the ordinary per-repair human gate. This bar is enforced at both the policy-admission check and the pre-merge recheck points.

All other guarantees in ADR 0064 and ADR 0081 remain unchanged.

## Steps

### 1. Identify action

Read the repair description and any attached context. Determine what kind of change the author wants to make and which skills it may touch.

### 2. Evaluate skills

Check each skill the repair may affect:

- **Permissions**: Can the skill handle the requested change safely? Does it require human review?
- **Policies**: Which policies apply? What restrictions do they impose?
- **Context**: Are there constraints the skill should respect?

Summarize your findings before proceeding.

### 3. Check standing authority

If the repair is authorized by an existing policy or standing authority, note that. If not, flag it for human review.

### 4. Apply or escalate

- If standing authority covers the repair, apply the change.
- Otherwise, prepare a summary for human approval and wait for confirmation.

## Output format

Return a structured summary:

```
Action: <what is being done>
Skills affected: <list>
Policy checks: <results>
Standing authority: <yes/no + source>
Next step: <apply / escalate>
