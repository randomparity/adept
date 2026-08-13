---
name: bounty
description: "Verify, deduplicate, draft, and file a structured GitHub issue grounded in actual code, with triage labels and native sub-issue support. Use when asked to create or file an issue, turn a reported problem into an issue, or decompose an existing issue or epic into child issues."
---
# Create a Structured GitHub Issue

Draft and file a GitHub issue for the problem described by the user, grounded in the actual code
and de-duplicated against existing issues. Every GitHub write is gated behind confirmation of
the exact draft and target; the open-sweep occurrence path also verifies its not-planned close.

## Steps

1. **Resolve repo.** `gh repo view --json nameWithOwner --jq .nameWithOwner` → `owner/name`.
2. **Read the code before drafting.** Verify the claim described by the user against the source
   with `Grep`/`Glob`/`Read`. The body must carry `file:line` evidence — a claim you could
   not find in the code is a finding *against filing*, not for it; say so and stop.
3. **Dedup and recurrence gate.** Search existing issues across **all states** — a closed
   duplicate (already fixed or closed not planned) is evidence, not noise. First identify the
   proposed defect's evidenced class tuple: (a) failure mechanism or faulty idiom, (b) component
   or file family, and (c) governing accepted decision when one exists. Run one bounded search
   per evidenced dimension:
   `gh search issues --repo <owner/name> <dimension> --json number,title,state,body,url --limit 100`
   (omit `--state`; it accepts only `open`/`closed`, never `all`). A failed query stops filing.
   Exactly 100 results is saturated: it cannot prove a below-threshold result, but may proceed
   when three historical occurrences are already verified.

   Follow issue links directly cited by a matched consolidated-sweep issue, deduplicated and
   capped at 100 distinct links. A failed linked-issue read stops filing. Reaching 100 links has
   the same saturation rule. Title/token overlap selects candidates only; count an issue when
   repository and issue evidence establish every applicable tuple dimension. Present the
   verified history and uncertain candidates. Never count an uncertain candidate, silently
   collapse unrelated defects, or treat a sweep wrapper as an occurrence. An occurrence reached
   directly and through a sweep counts once.

   Before drafting, also reconcile a matching occurrence issue already created for the current
   source, trigger, evidence, and target sweep. This is recovery from a prior create-then-close
   partial failure, not another occurrence. Read its `state,stateReason,url`: if it is already
   closed not planned, return the existing verified outcome tuple. If it is open, show the exact
   recovery action and obtain confirmation to retry only its not-planned close and readback; do
   not create another issue. An unreadable or nonconforming existing occurrence stops recovery.

   The proposed occurrence participates in the count. Below four distinct occurrences, retain
   the existing near-match behavior: rank title/token overlap, present every near-match with its
   state, and offer **"comment on #N instead"** before drafting. At the fourth or later:

   - Search for an open ordinary consolidated-sweep issue for the same tuple. A matching open
     sweep replaces another sweep draft; the current occurrence still needs its own durable
     evidence path in step 4.
   - With only a closed sweep, draft a sequential sweep only when the current occurrence was
     observed after that sweep closed or evidence shows it falls outside what the sweep fixed.
     A covered pre-closure occurrence is historical only and cannot trigger another sweep.
   - With no matching sweep, draft one ordinary consolidated-sweep issue, not an epic. Its
     Evidence preserves the current occurrence's source, trigger, and evidence and cites every
     verified historical occurrence. Its Expected section defines the bounded family-wide fix.

   Never file a duplicate silently. The discovery scan is read-only: do not reopen, close,
   relabel, reparent, comment on, or edit any historical issue.
4. **Draft with mandatory sections.** The body MUST contain: **Problem**, **Evidence**
   (the `file:line` refs from step 2), **Expected**, **Proposed approach**. Refuse to file a
   body missing **Evidence**. When step 3 found an open sweep, draft a distinct occurrence issue
   instead of another sweep. Preserve the current source, trigger, and evidence verbatim, link
   the open sweep in the body, and state that the occurrence will be closed not planned after
   verified creation. When called by campaign, also include a public-safe, whole-line
   `CAMPAIGN-OCCURRENCE: <campaign-slug> source=#N sweep=#N` marker in the new occurrence body.
   Show that marker and lifecycle in the draft the operator confirms. The marker belongs to the
   new issue; discovery still never mutates historical issues.
5. **Triage at creation.** Apply the `$sort-board` taxonomy (`type:`/`priority:`/
   `effort:` + adopted equivalents). Ensure-create the `status:` label you will apply using
   the `quest-log` skill's `ensure_label` recipe. Born triaged:
   `status:ready` when you assigned all of `type:`, `priority:`, and `effort:`;
   `status:needs-triage` when any slot was left unassigned.

   **Also assign a `risk:` value**, against the criteria in the `quest-log` skill,
   after one `gh label list --repo <owner/name> --limit 200 --json name` read — and **only
   when that inventory already holds all three values**. This skill never *creates* a
   `risk:` label: `$sort-board`' bootstrap gate is the sole provisioning point, so a
   decline there stays declined rather than being undone by the next `$bounty` run. Show the
   value's reasoning in the step-6 draft, per the human-read invariant.

   `risk:` is deliberately **not** part of the born-ready conjunction above. Born-ready
   governs eligibility for *daytime* work; `risk:` gates only unattended work, and coupling
   them would park every issue the dimension has not reached.
6. **Confirm → recheck → create → verify.** Show the full draft (title, body, labels) and get one
   explicit confirmation. Write the confirmed body to a populated temporary file and
   immediately before any write, repeat the matching-open-sweep read from step 3. Confirmation
   applies only to the exact draft and target shown. If the recheck changes the draft kind or
   target sweep, discard the stale confirmation, show the complete replacement draft, and get
   a new explicit confirmation before any create, comment, close, label, or other write. If a
   confirmed target sweep closed and no replacement is open, write nothing and restart the
   closed-sweep recurrence decision; do not infer post-closure persistence from an occurrence
   that predates and was covered by that sweep.

   Then invoke the bundled `scripts/create-verified-issue.sh` with `--repo <owner/name>`,
   `--title <t>`, `--body-file <tmp>`, and one `--label <label>` per intended label.
   Retain the populated temporary body file through read-back verification; never replace
   it with standard input or inline `--body`, and never `eval` argument tokens. The script
   creates exactly one issue, reads it back with explicit JSON fields, and checks the
   confirmed title, non-empty body, mandatory sections, and every intended label. Its
   verified URL is the only success result.

   On verification failure, report the durable issue URL and every exact mismatch emitted
   by the script. Do not retry, replace, or create a duplicate. If creation returned no
   resolvable URL, report that the durable artifact could not be identified and stop.

   For the confirmed open-sweep occurrence path only, close the newly verified occurrence with
   `gh issue close <N> --reason "not planned"`, then read it with
   `gh issue view <N> --json state,stateReason,url`. Success requires `state: CLOSED` and
   `stateReason: NOT_PLANNED`. A failed close, failed readback, or other state is not success:
   return the occurrence number, sweep number, rationale, and actual state (`unknown/unverified`
   when unreadable), and stop. When verified, return that same tuple with
   `closed-not-planned`, so a calling campaign can record it in its outcomes log and final
   report.
7. **Decompose mode** (arguments name a parent issue, e.g. "decompose #N"): read the parent
   (and its `$divination` split if present), draft each sub-issue through steps 2–6, and file each
   as a **native sub-issue** by passing `--parent <N>` to
   `scripts/create-verified-issue.sh` (the direct native path requires `gh` ≥ 2.94.0; on
   older `gh`, or to link a *pre-existing* issue instead, use
   `gh api repos/<owner>/<name>/issues/<N>/sub_issues` or the `sub_issue_write` MCP tool).
   Add a `Part of #N` courtesy line to each sub-issue body. The script also verifies the
   created issue's authoritative native `parent` field. After each child, wait for its
   verified URL before creating the next. If verification fails, stop the decomposition,
   report prior verified URLs plus the failed child's durable URL and every mismatch, and
   do not create later children or a replacement.

   **Carried confirmation.** A calling command that has already shown these drafts and
   obtained one explicit confirmation (e.g. `$saga`'s step-6 gate) carries that
   confirmation into filing: do not re-confirm and do not re-run dedup (it already ran
   per sub-issue; sibling sub-issues of the same parent are never dedup candidates). An
   Evidence refusal aborts that one sub-issue and reports it via the caller's
   partial-filing path — it never prompts mid-set. **Leave the `risk:` slot unassigned on
   this path**, and skip its inventory read: `$saga`'s go/no-go displays only `status:`
   birth labels, so a value assigned here would reach GitHub unread, which the
   `quest-log` human-read invariant forbids. The carve-out keys on the *carried
   confirmation*, not on decompose mode — a human-run `$bounty decompose #N` still assigns,
   because step 6 shows it each draft. `$sort-board` reaches these issues later via its
   report line. Birth labels come from the caller's
   per-entry state, overriding step 5: `status:blocked` + a `Blocked by #<n>` body line
   for dependents, `status:needs-triage` for open-question entries (blocked wins when
   both apply), else `status:ready` — the same rule recovery applies below.

   **Epic-parent recovery.** When the parent carries the `epic` label, its Decomposition
   section is the authoritative sub-issue list. Enumerate existing native sub-issues
   (`gh api repos/<owner>/<name>/issues/<N>/sub_issues`), diff by the entries' `#<n>`
   annotations first (an annotated entry is satisfied iff its number is in the list),
   falling back to exact title match only for unannotated entries. File only absent
   entries, in topological order, resolving `Blocked by` refs via the annotations —
   except `(adopted)`-annotated entries, which are **re-linked, never created**
   (re-check the adoption preconditions — still open, unparented, without sub-issues
   of its own, not `epic`-labeled; create with a fresh annotation and a
   dependents' `Blocked by` renumber only when the annotated issue no longer exists or
   is permanently disqualified, surfacing that to the operator). If a re-filed entry
   replaces a deleted blocker, update its dependents' `Blocked by #<old>` lines to the
   new number. An entry whose Evidence refusal is deterministic — genuinely greenfield,
   no existing code to cite — is surfaced as **unfileable, operator action required**,
   not looped back through the same refusal on every recovery pass.
   Re-filed entries take their birth labels from the entry's own state —
   `status:blocked` + `Blocked by #<n>` for dependents, `status:needs-triage` for
   open-question entries (blocked wins when both apply), else `status:ready`.
   After every recovery create — including a deleted-blocker replacement —
   write the annotation back to the epic's Decomposition entry (`#<old>` → `#<new>`;
   annotate previously-unannotated entries `#<n> — <title>`), so the next recovery run
   converges and files nothing.

## Hard constraints

- Read + `gh` only; no branches, no file writes outside the populated temporary body file.
- Recurrence discovery never mutates historical issues. The only extra write it can authorize
  is closing the newly confirmed open-sweep occurrence not planned.
- Explicit `--json` fields on every `gh` read.
- One current confirmation before any `gh issue create` / sub-issue write — a caller's carried
  confirmation (step 7) counts only while the draft kind and target remain unchanged.
- Refuse to file without an Evidence section.
