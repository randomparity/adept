---
name: warding
description: "Run a proactive repository maintenance sweep for stale issues, dependency freshness outside Dependabot, supply-chain advisories, and deferral records past review-by. Use when asked to groom, sweep, or surface maintenance work without doing the work."
---
# Groom the Repository

Sweep the four maintenance signals nothing else in this skill set watches, and turn each into
filed work. `$warding` **produces work; it never does the work.** Its whole write surface is: it
files issues, it ages issues that have gone quiet (comment → `stale` label → a recoverable
close), and it opens one draft PR against deferral records. It never bumps
a dependency, edits code, or merges anything.

Run it manually, or on a schedule (see *Trigger* below). Read → report → one confirmation →
write.

Codex skills do not carry slash-command tool allowlists. Keep this workflow read-first and
require one explicit user confirmation before any GitHub write, branch push, or draft PR.

## Steps

1. **Resolve repo and scope.** `gh repo view --json nameWithOwner --jq .nameWithOwner` →
   `owner/name`. With an argument naming one sweep (`A`–`D`), run only that sweep; with no
   argument, run all four. Note whether `.github/dependabot.yml` exists and which ecosystems it
   covers — sweep B skips those.

2. **Sweep A — issue staleness.**

   Open issues that are correctly triaged and have simply aged. This is the gap between
   `$sort-board` (which labels at intake) and `$resurrection` (which reconciles `status:`
   against PR reality): neither notices an issue nobody ever picked up.

   List once and filter client-side — `gh issue list --repo <owner/name> --state open --json
   number,title,labels,updatedAt --limit 500` — because `gh` mis-encodes the colon in a
   `--label status:...` filter and silently returns nothing (the `quest-log` skill's
   colon-label gotcha).

   If the returned array contains 500 issues, report that Sweep A is possibly truncated at the
   limit and that staleness coverage may be partial. Do not infer or act on issues outside the
   returned population.

   **Never touch** an issue carrying an in-flight `status:` value (`in-progress`, `in-review`,
   `awaiting-merge`), `status:blocked`, or `status:needs-human` — a human owns those exit edges
   (`$resurrection` step 4) — nor an `epic` parent, whose quiet means its children are
   working, nor any issue referenced by an open PR.

   Everything else runs a three-state machine. Ensure-create the `stale` label first (the
   `quest-log` skill's `ensure_label` recipe); stop with its message if that fails.

   - **Warn** — no `stale` label, and `updatedAt` older than `STALE_AFTER` (default 90 days):
     post a `GROOM:STALE` annotation naming the grace period and the reopen path, **then** add
     `stale`. Never close on this pass.
   - **Close** — carries `stale`, applied longer ago than `GRACE` (default 30 days), with no
     activity since: close as **not planned**, keeping the `stale` label.
   - **Revive** — carries `stale`, with activity after the label was applied: remove `stale`
     and report it. Aging restarts from scratch.

   **Read the label's age from the timeline, never from `updatedAt`.** Applying `stale` bumps
   `updatedAt` itself, so an `updatedAt`-driven close re-arms on every run and never fires:

   ```bash
   gh api "repos/$OWNER/$REPO/issues/$N/timeline" --paginate \
     --jq '[.[] | select(.event=="labeled" and .label.name=="stale")] | last | .created_at'
   ```

   An empty result is **stale-unknown**: do not close, surface for a human — the same
   fail-closed rule `$resurrection`' staleness gate applies.

   **Activity since the warning is `updatedAt` strictly after that timestamp**, which is why the
   annotation is posted *before* the label and the label is the pass's last write. Reverse the
   order and the comment's own timestamp lands after the label, so every warned issue reads as
   revived on the next run and nothing is ever closed.

   **The close is recoverable by construction.** `stale` is a plain label, so it survives the
   close; only `status:` values are stripped from closed issues, and only by policy
   (`$resurrection` step 5). Closing as *not planned* also sets `stateReason: NOT_PLANNED`,
   a field rather than a label, which nothing in this pipeline can strip. Either marker alone
   finds a swept issue; together they separate "the sweep closed this" from "a human closed it
   unfinished":

   ```bash
   gh issue list --repo <owner/name> --state closed --limit 500 \
     --json number,title,stateReason,labels \
     --jq '.[] | select(.stateReason=="NOT_PLANNED" and (.labels | any(.name=="stale")))'
   ```

3. **Sweep B — dependency freshness beyond Dependabot.** Enumerate version pins Dependabot does
   not cover, and file one issue per coherent upgrade:

   - Action refs in `.github/workflows/*.yml`, unless a `dependabot.yml` covers
     `github-actions`.
   - Tool versions pinned in the target repository's provisioning and workflow files.
   - Container bases in any `Dockerfile` / `compose.yml`.

   **Look every current version up at sweep time**; never assert one from memory. Title each
   issue with the dependency name so `$bounty`'s dedup gate matches it on the next run.

4. **Sweep C — supply-chain audit.** When a manifest exists, run `osv-scanner scan source -r .`
   and file one issue per advisory cluster sharing a fix, `priority:` from severity, advisory ID
   in the title so dedup matches next run.

   If `osv-scanner` is absent, consult the current official OSV-Scanner installation guidance
   and report the sweep as **skipped — `osv-scanner` not installed** with an applicable install
   command. If that guidance is unavailable or has no applicable command, name the missing
   guidance in the skipped result; never invent a command or let an absent tool read as a clean
   sweep.

5. **Sweep D — deferral-record staleness.** This sweep emits a **draft PR that edits records
   in place**, not issues: the record is the durable owner, and a tracker issue never appears
   in a diff.

   Read `RECORD_DIR` for each profile the repo enables (`RECORD_PROFILES` in its records
   workflow; `docs/debt` for the `debt` profile). Select records that are **open** — `## Status`
   reads `Open`, with no `> **Resolved by ...**` banner — **and** whose `review-by:` date has
   passed. Open-only is load-bearing — a resolved record's `review-by:`
   is not a staleness signal, whatever the gate emits — so do not weaken it to "whatever CI
   warned about". `check_review_by` skips resolved records as of #124, so the two agree today;
   the rule stands independently of that agreement and outlives it.

   If no record qualifies, say so and emit nothing.

   Otherwise, before branching, check for an open sweep PR on the sweep's fixed branch
   `chore/groom-review-by` (`gh pr list --repo <owner/name> --state open --head
   chore/groom-review-by --json number,headRefName` — `--head` is the exact-match flag; a
   `--search "head:..."` query is the wrong idiom here) and **update that branch rather than
   opening a second PR.** For each stale record, in `## Status` only:

   - bump `review-by:` forward (default +90 days from today; the field is not append-only —
     `APPEND_ONLY_SECTIONS` omits `## Status` by design, so this edit is conforming);
   - append a dated re-evaluation line stating why the concern still stands.

   **Never write a `> **Resolved by ...**` banner.** Judging a concern discharged is the call
   this sweep cannot make unattended; the PR body tables each record's concern and what would
   resolve it, and the reviewer converts a bump to a banner where warranted. The PR is created
   as a **draft** for the same reason.

6. **Report → confirm → write.** Present one table covering all four sweeps — sweep, finding,
   proposed artifact — including every sweep that found nothing or was skipped. After one
   explicit confirmation, apply: issues through `$bounty` (which re-runs its own dedup and
   Evidence gates per issue), then the sweep-D branch, commit, push, and draft PR. A per-item
   failure does not abort the rest of the sweep; report it in the summary.

## Trigger

Manual invocation is the primary path. The harness's `CronCreate` does not fit this cadence:
its jobs fire only while the REPL is idle, and recurring jobs auto-expire after 7 days — far
shorter than the quarterly `review-by:` horizons sweep D exists to catch.

For a real schedule, drive it from an external scheduler (`launchd`, `systemd` timer, `cron`)
invoking Codex non-interactively with a `$warding` request, and understand what that run can and cannot do first.

**A headless scheduled run is report-only.** Step 6's confirmation gate has nobody to answer it,
so the sweep reports and writes nothing. That is the intended default, not a limitation to route
around: capture the report where the scheduler can put it in front of you, and run `$warding`
attended to act on it. Making a scheduled run write requires the operator to grant an
auto-approving permission mode for that invocation — a deliberate act, which is exactly what
the read-first confirmation gate above is designed to force.

One further caveat: interactively-authenticated MCP servers may be absent in a headless run, so
a scheduled `$warding` can see less than an attended one.

## Hard constraints

- Files work; never does it. No dependency bumps, no code edits, no merges.
- Sweep D is the sole exception to issues-only output, and it edits `## Status` only.
- Never write a resolution banner; never touch a resolved record.
- One explicit confirmation before any GitHub write or any push.
- Explicit `--json` fields on every `gh` read; list by state and filter `status:` client-side.
- An absent tool is a reported skip, never a silent pass.
- Idempotent across runs: stable issue titles for dedup, and update the open sweep PR rather
  than opening another.
