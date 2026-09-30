# Bounded refresh and guarded merge

## Scope and authority

Issue [#437](https://github.com/randomparity/adept/issues/437) selects candidates 1, 2 and 5.
The operator first approved bounded scheduling, then explicitly approved a finite
refresh→wait→gate→merge helper, its private recovery-state format and boundary tests.
The revised WORK:SCOPE is the authority; this specification is evidence. The revised live
assessment is L, fixing the design denominator at 1000 lines. ADR0080 records the decision.

The shared reference retains the four gate predicates. The new return-to-town helper owns
mechanical enforcement and the ordinary refresh/wait/derive/merge sequence. Campaign and
return-to-town retain eligibility, human authority, policy interpretation, worker-end evidence,
worktree reclamation, mandatory assignments, holds, post-merge tracking and cleanup.
No unrelated writer is changed or coordinated. Leases, queues, persistent cost telemetry,
worker refill and claim/number-policy rework remain excluded.

## Global Constraints

- Bash 3.2 and existing git/gh/jq/POSIX tools; no new dependency or daemon lifecycle.
- No force push, pushed rebase, hook bypass, fixed workflow count or print-only gate.
- One final full verification owner per candidate: the verified managed push hook when it
  covers that candidate, otherwise the caller-approved full command. Never run both merely
  to duplicate coverage. Regeneration and commit hooks remain required.
- Public comments cannot grant reset, merge or worktree authority. Private diagnostics and
  paths stay private. Script results are evidence, not additional authorization.
- Tests assert executable behavior and structured records, never prose sentences.

## Entry and ownership

Invoke the installed coherent bundle's
`skills/return-to-town/scripts/refresh-merge --claim-token TOKEN --context CONTEXT`, from the
already reclaimed feature worktree. The context is an explicit absolute private file path.
Only the human-authorized campaign root or directly authorized human merge flow invokes it.
A quest worker never receives merge authority by holding the same token or invoking a helper.

Before invocation the caller checks the issue/PR scope, closing reference, assigned landing
order, current mandatory assignments and human merge authorization. A dispatched worker must
have a harness-observed end; the root takes over its existing worktree before calling. These
facts cannot be discovered from timestamps or a shell PID. The context records their provenance.
The helper validates that the asserted checkout is the actual physical clean feature worktree,
that its branch owns that path in git's worktree inventory, and that local/remote/API heads agree.
It refuses forks, main/master as the feature branch, mismatched origins, extra closing issues,
missing assigned-issue binding and missing evidence. It never creates or reclaims a worktree.

Only explicit human authorization covering this deterministic refresh sequence is accepted.
Standing-policy admission for one head is not silently extended to another: such a caller
returns to campaign's policy/diff/consumer evaluation instead of invoking this automatic path.
The private packet is a trusted caller attestation, not a new identity system. File permissions
and exact claim verification protect the existing boundary; they do not distinguish agents
sharing one OS/GitHub principal. One root invocation at a time per packet is a caller invariant.

## Private context v1

The root writes one regular mode-0600 JSON file in a physical mode-0700 directory, and records
its path in existing workflow notes. Reject symlinks, bad modes, unreadable or oversized input,
unknown fields, invalid enums/identities, control characters and inconsistent recovery facts.
No context path or command output is copied into a public annotation. A missing packet is not
a new chain. Only an explicitly known new chain starts at zero; lost history requires operator
reconciliation. Existing freeform recovery notes require explicit reconciliation into v1.

The exact top-level keys are:

| Key | Value |
|---|---|
| `format` | `refresh-merge-v1` |
| `repo`, `issue`, `pr` | Canonical owner/name and positive issue/PR integers |
| `branch`, `base`, `worktree` | Explicit valid refs and physical current worktree path |
| `approved_head` | Full original author-approved SHA |
| `authority` | Object: `role` (`campaign-root` or `direct-human`), `merge_grant`, `ownership`, `scope_check`, `assignment_check`; nonempty caller evidence strings |
| `assignments` | Object: `numbered` and `versions` arrays of exact caller-assigned facts described below |
| `merge_method` | `merge` or `rebase`; no squash for code |
| `regenerate` | Array of argv arrays, empty only when the caller established no regeneration |
| `generated_paths` | Exact relative file paths permitted to change during regeneration |
| `verification` | Object: `mode` (`push-hook` or `command`), `argv`, `hook_path`, `hook_blob` |
| `deadline_seconds` | Positive bounded integer, maximum 86400 for this invocation |
| `state` | The recovery object below |

For `push-hook`, argv is empty and hook_path/hook_blob identify the effective executable
pre-push hook and its git blob hash recorded by attunement. Resolve the effective hook path,
compare its physical path and bytes before push, and refuse drift or a missing hook. For
`command`, argv is a nonempty full guardrail command and the two hook fields are empty; push
still runs all configured hooks. The caller must establish which mode covers the exact
candidate. Arbitrary remote strings never become command arguments or shell source: argv
arrays come only from this private root-authored packet, and execute directly without eval.

The caller supplies every applicable mandatory assignment, or explicitly empty arrays when
none apply. Each numbered entry has `path`, decimal-string `value`, `directory`, `separator`
(`-` or `_`) and `suffix` (such as `.md` or `.sql`). Its convention is a direct child of that
directory whose basename starts with exactly value's digit width, separator, a nonempty name
and suffix. Unsupported conventions hold for root rather than being guessed. Each version
entry has `path` and plain `MAJOR.MINOR.PATCH` `value`, read from that JSON file's top-level
`version`; other mandatory-edit formats require caller reconciliation, not an empty array.
Validate exact path/value agreement and the current candidate's assigned version. For every
captured base, inspect its complete NUL-delimited tree: a malformed numbered-looking path,
an occupied assigned number, or a number above the assignment holds before mutation. Compare
base versions separately and require assigned versions to remain strictly greater. Missing
base version files are allowed only when the captured tree proves absence; failed reads hold.
This checks observed base invalidation of the caller's complete reservation snapshot, not a
new allocator or a guarantee against later unseen reservations. Root alone reassigns.

State keys: `phase`, `head`, `failures`, `observations`, `lineage`, `handshake_url`.
Phases: `ready`, `refresh-pending`, `push-pending`, `pushed`, `derive-pending`, `approved`,
`merge-pending`, `merged`. `head` is the current full SHA. `failures` is an ordered unique
array of at most three failed full SHAs. `observations` records checked head/base/exit tuples,
with a bounded 500-entry ceiling that holds rather than discarding history. `lineage` records
completed refresh objects `{from, base, to}` linking approved_head through state.head.
`handshake_url` is empty or the last verified derivative comment URL. Initial state is ready,
head=approved_head, empty arrays and empty handshake_url. Every state update is an atomic
same-directory replacement, mode0600, read back before proceeding; no state write may fail open.

Preserve identity and authority fields unchanged when updating state. Before replacement,
refuse a packet changed by another writer. No lockfile, lease or general persistence service
is introduced. Pending phases are durable intent written before the corresponding mutation.
A crash before completion can therefore leave intent without evidence; it cannot create a new
attempt. The caller owns packet retention until verified merge or explicit operator resolution.

## Enforced sequence

1. Resolve the installed bundle, required commands and strict context. Clear local git selector
   variables before reading the actual checkout. Bind canonical github.com repo/origin, issue,
   PR/base/branch, closing issue, current SHA and root-owned worktree. Verify the exact claim
   with the existing tracker; absent/foreign/malformed holds without acquire or recovery.
2. Validate the original complete whole-line handshake for approved_head, with the comment
   author independently equal to the PR author or holding write permission. Use complete,
   bounded issue-comment reads, not the latest body without author identity. A valid derivative
   is permitted only for a recorded head produced from this approved lineage. Missing/stale
   original approval cannot be repaired by refreshing and self-attesting.
3. Re-discover the complete Actions run set for the exact current head. Do not hardcode a job
   count or freeze the initially visible run IDs. A saturated bounded result holds; an empty
   list is pending, with the existing conjunctive workflow/check-run/status empty exception
   for repositories without automation. Success/skipped/neutral are acceptable completed
   conclusions; unfinished runs wait, failed/cancelled/action-required/stale/startup-failure
   or unknown values hold under their names. Also inspect SHA-addressed check-runs and commit
   statuses: pending waits and nonpassing results hold. No failed transport becomes empty data.
4. Read the remote head and API head again; require parity with state.head. Fetch the base,
   capture its exact tip, validate assignments against that base and run actual ancestry.
   Exit0 passes, exit1 records a proven miss,
   any other exit faults. Record the tuple before action. Count each failed head once even
   against a newer base; a repeat never grants another refresh. The third distinct failure
   holds before another refresh or merge. Intermediate passes, changed heads, retries,
   time and restarts never reset the chain.
5. For an admitted first/second failure, persist refresh-pending, then merge the fetched base
   into the current branch with normal hooks. A conflict returns control without abort/reset
   or hiding the worktree state. Run approved regeneration argv, refuse changed/untracked paths
   outside generated_paths, explicitly stage allowed paths and commit generated changes if any.
   Run the full command only in command mode. Record the resulting exact head and lineage,
   then push-pending; call the existing claim-gated deliver-write push with mandatory hooks.
   On success and exact remote readback mark pushed and return to step3. No sibling is touched.
6. When current CI and base pass for a refreshed head, persist derive-pending and call the
   existing publish-handoff preflight and normal writer once, with public-safe lineage notes.
   The helper verifies and publishes the current SHA; require its returned verified URL and
   unchanged head before marking approved. It cannot create original authority. A base may
   move after this comment; the history remains truthful about the SHA and the final gate
   still controls merge. Never delete or reinterpret old handshakes as a counter reset.
7. Re-enforce SHA parity, all exact-head checks and the matching author/derivative handshake.
   Verify the canonical claim again, persist merge-pending, freshly fetch/capture/test base
   with assignment validation immediately before the guarded
   `gh pr merge --match-head-commit` for state.head. An actual
   exit1 follows the same counter/refresh route; faults hold. The merge command receives only
   the validated method, PR and head, never an inferred branch or untrusted command fragment.
8. Re-read authoritative PR state and head. Exit0 only after MERGED with the expected head;
   record merged. A refused merge, queued/open state, changed head or failed read holds, never
   blindly retries. The caller then performs existing issue tracking and cleanup; the helper
   does not release claims, close issues, remove worktrees or change labels.

The helper emits one compact JSON result on stdout at termination, including outcome,
repo/issue/PR/head, failure count and a public-safe reason. Raw diagnostics stay on stderr.
Exit0 means verified merged; exit1 means a known hold; exit2/6 preserve lost-claim classes;
exit4 is a read/transport fault; exit5 means a remote write may have landed. Local validation
faults exit1 before mutation. The caller reports a hold through the existing complete trajectory
then status transition. A terminal result is evidence, never a standalone permission grant.
Preserve claim classes only from an independent pre-write claim check. Once a mutation-capable
push, publication or merge child starts, any completion not verified by its required readback
is conservatively exit5 with pending state retained. The reused publication writer's statuses
overlap claim/fault/post-write cases; never parse its diagnostic prose to infer no write.

## Waits and interruption

One invocation owns the entire wait; sleeps and compact network snapshots stay inside the
shell. The caller uses completion notification or one background task and reads once at exit.
There is no model turn for each poll and no detached persistent process to recover later.
Use existing 30-second single-read/120-second paginated/write bounds, respecting the remaining
invocation deadline. Managed push can exceed120seconds for required hooks under its existing
operator exception, but remains bounded by the invocation. Root-supplied local commands also
have a remaining-time bound. Timeout is not an answer, and an uncertain write is never retried.

On entry to any pending phase, only authoritative MERGED at the expected head permits terminal
reconciliation; otherwise return an explicit interrupted-action hold. Do not repeat push,
publication, regeneration or merge merely because the command may not have run. Ready/pushed/
approved phases revalidate actual refs and all evidence and continue the same count. A changed
head or conflicting history holds. A merged packet also revalidates terminal state. Explicit
operator reconciliation may record the actual supported completed state or start a new chain;
the helper has no reset flag and never reads a public comment as reset authority.

## Failure and threat model

Actors: a human-authorized root, its ended worker, GitHub, untrusted public commenters and
independent writers. Assets: author authority, tested commit, bounded spend, private history,
worktree data and correct destination. The changed boundaries are trusted private context to
commands/state, GitHub observations to decisions, claim checks to writes and private evidence
to public derivative comments. Validate structured inputs and public-safe composition, keep
exact destinations/SHAs, separate stderr from parsed JSON and fail closed on missing evidence.

Accepted limitations: unrelated writers can prevent landing indefinitely; a final base can
advance between check and server head-bound merge (ADR0035); same-principal trusted callers
must supply true human/end/ownership evidence and serialize packet use. Shell code cannot
verify a harness event or authenticate a human statement. Existing network-bound process
cleanup/124 collision limits remain. Filesystem checks do not protect against a malicious
same-principal process racing private state. No new cross-run liveness guarantee is made.

## Verification and AI evaluation

Executable boundary fixtures cover independent failures of all four gates; forged/stale
handshakes and valid lineage; changing/missing/saturated run sets; unexpected result vocabularies;
no-automation conjunction; command faults/timeouts; changed local/remote/API heads; foreign claim
before each write; mode/symlink/schema rejection; path/argv boundaries; preserved required hooks;
cleanly mergeable base changes that consume numbered or version assignments (no refresh/push/
merge); absent claim versus publication timeout or successful creation with failed readback;
third-failure, dedup, pending cold-resume, no reset on passing evidence; uncertain publication/
merge; and exact guarded-merge arguments plus authoritative merged readback. A controlled local
git graph and mocked GitHub boundary exercise a complete refresh→CI→derive→merge route. No test
asserts prose and no fixture reaches live GitHub writes. Confirm tests bite by controlled faults.

AI-SPEC: the operator delegates one eligible row to the root; the root creates the private packet
from verified authority/ownership facts and invokes the installed helper. Output is a verified
merge or an evidenced hold. Untrusted comment instructions are never authority. Human evaluation
retains E1 (ten siblings: nine vs45 refreshes), E2/E3/E4 (cap/dedup/unknown resume), E5 (faults and
intermediate passes), E6 (hostile comments/privacy), E7 (authority/order/worker-end), E8 (supported
resolution). Add E9: root invokes once and consumes one terminal result; no model polling or
worker-inherited merge grant. These bounded constructed cases do not prove universal compliance.
