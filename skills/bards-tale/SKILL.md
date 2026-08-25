# $bards-tale — Retrospective Skill

> **Read this file first.** It is the contract. Everything below is binding.

---

## 1. Purpose

Produce a retrospective report that:

- Captures what happened in a campaign or quest.
- Extracts findings with evidence.
- Proposes concrete tunings tied to governing workflows.
- **New:** Reports follow-through on proposals from prior retrospectives.

---

## 2. Inputs

- `docs/retro/<YYYY-MM-DD>-<slug>.md` — the report being written (output path).
- `docs/retro/` — directory of prior reports for follow-through.
- GitHub issues and PRs from the campaign/quest period.

---

## 3. Report Structure

Each report contains:

1. **Campaign context** — quest, dates, participants.
2. **Findings** — observed facts with evidence links.
3. **Proposed tuning (not applied)** — each proposal cites a governing workflow and traces to a finding.
4. **Follow-through** — *new:* status of proposals from prior reports that cite this report via `Retro:` lines.
5. **Learn-to-tune routing** — human action step with citation convention.

---

## 4. Proposed-Tuning Contract

Every proposal in section 3 **must**:

- Name the governing workflow file (e.g., `skills/forge/SKILL.md`, `docs/workflow/inventories/...`).
- Quote the specific rule or step it would change.
- Trace to one or more findings by section anchor.
- State the concrete edit a human would make.
- Carry a unique proposal ID: `PROP-<report-slug>-<n>`.

Example:

```markdown
### PROP-2026-08-11-seek-quest-1
**Workflow:** `skills/forge/SKILL.md` (section 3.2)
**Finding:** [§2.3](#finding-23-scope-drift)
**Change:** Replace "scope audit optional" with "scope audit required before branch".
**Edit:** `skills/forge/SKILL.md:45` — change `MAY` to `MUST`.
```

---

## 5. Learn-to-Tune Routing

After the report is written, a human **must** review each proposal and:

1. Decide: route to `$bounty` (new issue), apply on a branch, or defer with reason.
2. **When filing an issue from a proposal, include a `Retro: docs/retro/<report-file>` line in the issue body.** This links the issue back to the retrospective that proposed it.
3. Record the decision in the report's follow-through section of the *next* retrospective.

The `$bounty` skill is the standard routing path for new issues. Applying on a branch is appropriate for small, contained edits.

---

## 6. Follow-Through Report

**Read-only.** This section appears in every retrospective report and reports on the prior report's proposals.

### 6.1 Method

For the immediately prior report in `docs/retro/` (by date):

1. Extract all proposal IDs (`PROP-<slug>-<n>`) from its section 3.
2. For each proposal ID, search GitHub issues with `gh search issues --json number,title,body --limit 100 --repo <owner>/<repo> "Retro: docs/retro/<prior-report-file>"`.
3. Match issues to proposals by proposal ID mentioned in the issue body.
4. Report each proposal as:
   - **Routed** — issue found with matching proposal ID.
   - **Not routed** — no issue found.
   - **Convention not in use** — prior report predates this convention (no `Retro:` citations exist for it).

### 6.2 Bounded Search & Truncation

- Use explicit `--json number,title,body` fields.
- Limit 100 issues per search (per ADR 0013).
- If results are truncated, report: "Search truncated at 100 issues; some proposals may be unreported."
- Truncation is reported per `docs/adr/0013-report-bounded-list-truncation.md`.

### 6.3 Honest Absence Reporting

If the prior report has no issues citing it via `Retro:` lines:

- **Do not** report "no proposals were adopted".
- Instead report: "Convention not in use for this report (predates citation convention)."

### 6.4 Output Format

```markdown
## Follow-Through: <prior-report-file>

| Proposal | Status | Issue |
|----------|--------|-------|
| PROP-...-1 | Routed | #123 |
| PROP-...-2 | Not routed | — |
| PROP-...-3 | Convention not in use | — |

*Search truncated at 100 issues; some proposals may be unreported.*
```

---

## 7. GitHub Read-Only Contract

**This skill never writes to GitHub.** It only reads via `gh search` and `gh issue view`.

- No auto-filing of issues.
- No auto-creation of branches.
- No mutations of any kind.
- All routing decisions are human actions recorded in the next report's follow-through section.

---

## 8. Output

Write the complete report to `docs/retro/<YYYY-MM-DD>-<slug>.md`.

---

*End of contract.*
