---
name: resurrection
description: "Reconcile GitHub status labels with actual pull-request and branch state, reset stale orphaned work, and remove residual labels from closed issues. Use between work or campaign runs when issue workflow state may be stale."
---
# Recover Orphaned Issues

Reconcile the `status:` labels (see the `quest-log` skill) against actual GitHub
state. Run this **between** pipeline runs — not while a `$campaign` or `$quest` is
actively working the same repo. Read → plan → one confirmation → apply.

## Steps

1. **Resolve repo.** `gh repo view --json nameWithOwner --jq .nameWithOwner` → `owner/name`.
2. **Sweep in-flight issues.** Resolve `CLAUDE_PLUGIN_ROOT` to the installed plugin
   root, keeping the target repository as cwd. Fetch quest claims once in Bash
   (`bash "$CLAUDE_PLUGIN_ROOT/skills/quest-log/assets/tracker.sh" claim-list --target <owner/name>`) for
   the checks below. Do **not** filter with `gh issue list --label status:...` —
   `gh` mis-encodes the colon and multiple `--label` flags AND (see the skill's colon-label
   gotcha), so either returns nothing. List by state once and filter **client-side**:
   `gh issue list --repo <owner/name> --state open --json number,labels,title --limit 500`,
   Record the returned row count. If it is 500, mark the open-issue population as possibly truncated
   at the limit and carry that named warning into the reconciliation plan; do not describe the open
   sweep as complete.
   then keep issues carrying any in-flight `status:` value (`in-progress`, `in-review`,
   `awaiting-merge`). For each, check reality:
   - **merged PR with `Closes #N`** (`gh pr list --repo <owner/name> --state merged --search
     "N in:body"` — verify the `Closes` link) → plan: close issue, strip `status:` labels.
   - **open PR** → plan: correct the label to match the PR's actual state.
   - **no PR, no matching branch, and stale** (gate below) → plan: reset to `status:ready`.
     If a claim is present, hold it as a claimed in-flight row pending an explicit
     operator abandonment/recovery decision under quest-log; age alone cannot authorize
     its reset or deletion. An approved reset releases the observed token's claim.
   - **claim on a closed issue** → plan: delete the claim (release guarded by the
     observed token; closed-state is authoritative). This cleanup remains separate
     from recovery of an open in-flight claim.
3. **Staleness gate** (prevents clobbering a legitimately-quiet in-flight issue whose branch
   was never pushed). Reset a `status:in-progress` issue only when ALL hold:
   (a) no open/merged PR references it;
   (b) no branch matches its name/number (`git branch -a`, `git ls-remote --heads`);
   (c) no `WORK:SCOPE` annotation posted after the current `status:in-progress` label was
       applied (liveness — read via the skill's latest-complete recipe, applying the
       quest-log token-binding rule: an annotation whose token matches no live claim is
       residue, not liveness);
   (d) the `status:` label's age exceeds the threshold (default 60 min), read via the
       skill's timeline recipe. **Empty timeline result = stale-unknown → do NOT reset;
       surface for a human.** Fail closed, never clobber.
   These gates identify an unclaimed orphan or a candidate for an explicit abandonment
   decision; they do not make a claimed in-flight issue stale. A claimed row requires
   the additional recovery authority below, regardless of how old its label or claim is.
4. **Reconcile blocked dependencies; hold other parked work.** Run the
   `quest-log` recipe in Bash:
   `bash "$CLAUDE_PLUGIN_ROOT/skills/quest-log/assets/cleared-dependencies.sh" plan <owner/name>`. Add every returned issue to the
   reconciliation table as `status:blocked → status:ready (all canonical blockers closed)`.
   This is the repair owner for a primary return-to-town edge that was interrupted or omitted.
   List all other `blocked`/`needs-human` issues as *held* with their parked-phase note (from
   `WORK:TRAJECTORY`; for a birth-blocked issue with no trajectory note, the
   `Blocked by #<n>` body line is the parked-state record). A note missing its closing
   sentinel is not selected at all: latest-complete-wins filters it out and returns the newest
   *earlier* complete block, so an issue can present a stale hand-off as its current parked
   state. Open, missing, malformed, or
   unreadable blockers stay held with the recipe's actionable reason. A human owns every
   other exit edge. Only clean up if a merged PR already closed the underlying work.
5. **Strip stale labels from closed issues.** Same colon-label caveat — list and filter
   client-side: `gh issue list --repo <owner/name> --state closed --json number,labels
   --limit 500`,
   Evaluate this count independently from the open sweep. If it is 500, mark the closed-issue
   population as possibly truncated at the limit and carry that named warning into the
   reconciliation plan; do not describe the closed sweep as complete.
   keep those still carrying any `status:` value → plan: remove the residual `status:` label
   (closed-state is authoritative).
6. **Plan → confirm → apply.** Present the full reconciliation table (`#issue → action`).
   List any branch before touching it. For a claimed in-flight reset, show the observed
   claim and explicitly name the abandonment decision and reset/release action; a generic
   cleanup confirmation cannot stand in for that decision. Retain the exact approval and
   provenance in existing private run notes under quest-log's recovery-authority rule.
   One confirmation may cover the displayed decisions. Before each open-issue reset,
   re-read claim and issue state; a new/changed or unreadable claim, incompatible state,
   or failed staleness gate holds the row. Do not delete a malformed claim through token
   release; hold for its explicitly authorized force-recovery path. After confirmation, apply per issue;
   pass all and only the confirmed cleared-dependency issue numbers to
   `bash "$CLAUDE_PLUGIN_ROOT/skills/quest-log/assets/cleared-dependencies.sh" apply <owner/name> <number>...`, then verify every
   reported transition. Re-evaluation may retain an issue whose state changed after
   planning. A per-issue failure does not abort the sweep.

## Hard constraints

- Between-runs reconciler; do not run concurrently with active `$quest`/`$campaign`.
- Explicit `--json` fields on every `gh` read.
- Fail closed on stale-unknown; move `blocked` only through a confirmed canonical
  cleared-dependency repair, and never auto-move `needs-human`.
- One confirmation before any write; list branches before acting on them.
