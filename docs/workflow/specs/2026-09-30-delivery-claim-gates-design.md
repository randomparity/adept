# Claim-verified delivery and publication

## Problem and authority

Issue #424's Expected and Proposed approach require held claims at issue-backed
push, PR create/edit and publication comment boundaries. Charter q424-c646f537
freezes EMPTY exclusions and full-spec M250;
[ADR0077](../../adr/0077-claim-verified-delivery-and-publication.md) records the executable owner.
Only assigned version7.0.0 changes invocation compatibility; persisted claims are unchanged.

## Architecture and contracts

Add `skills/deliver/scripts/deliver-write --claim-token TOKEN REPO ISSUE OP ARGS`.
TOKEN must exactly match qISSUE-8lowerhex; REPO is a valid public GitHub owner/name.
Supported operations and arguments are `push`, `pr-create BASE TITLE BODY`, and
`pr-edit PR BODY`. Push uses the current branch and origin with ordinary managed
hooks; create pins repository/head/base; edit corroborates the PR's repository,
branch and closing issue before writing its body. Origin must match REPO before push.
No arbitrary command forwarding or hook-bypass arguments are accepted.
Canonical tracker invocation is `GH_HOST=github.com bash TRACKER claim-verify
--profile github --target REPO ISSUE --token TOKEN`, with TRACKER resolved from
the same plugin root. New gh discovery/writes use explicit github.com host/repository. Preserve exit2/6/4 and stderr holder diagnostics; report the local
checkout path on refusal. Unexpected failures fail closed. No reacquisition/release.

Both publication helpers require leading `--claim-token TOKEN` after optional
`--preflight`. Handoff checks TOKEN against explicit ISSUE; review derives ISSUE
from TOKEN and corroborates it with the PR's closing references before publication.
Argument validation precedes network activity. Normal mode uses the canonical
tracker immediately before its existing comment call, after content/destination checks.
Parent-side verification runs immediately before `comment_url=$(post_comment)`.
Forward canonical diagnostics to stderr and preserve nonzero2/6/4 without generic
fail/fault remapping; the URL stdout and retained-input lifecycle remain unchanged.
The readback, retained evidence, disposal, and publication-recovery contracts remain.
Review preflight remains network-free. Handoff preflight retains bounded read-only
head/destination discovery and full composition validation. Neither preflight verifies
the claim or performs a comment, claim mutation or durable ledger write.
Source checkpoint: campaign corrected its initial no-network handoff assumption.

## Failure model

- Actors/deployments: local campaign or standalone operators on shipped Bash3.2
  GitHub-profile entrypoints; stale accidental workers sharing repository access.
- Invariants/assets: failed claim gates prevent the selected remote write; no fallback
  on invalid tokens; preserve holder diagnostics and truthful already-pushed state.
  Wrong origin/issue/destination fail closed; transport4 never reacquires a claim.
- Accepted classes: replacement between verification and write, including managed
  hooks, because GitHub supplies no atomic claim-conditioned push/comment primitive;
  bypassed entrypoints and malicious credential/token reuse are outside this fence.
- Covered elsewhere: canonical tracker owns claim grammar/transport; existing helper
  network bounds and one-time publication/recovery rules own indeterminate writes;
  managed pre-push hook and CI own candidate correctness.

## Threat model

- Boundary inventory: caller arguments and checkout/origin are local-operator inputs;
  PR bindings and current claim are remote responses; selected writes affect GitHub.
  Added boundary is deterministic delivery dispatch; helper comment boundaries tighten.
- Actor model: stale accidental operator/worker is untrusted for current ownership;
  canonical tracker and configured GitHub host are trusted policy and state owners.
- Controls: token/ID/repository/fixed-arity validation before commands; origin and
  remote PR issue binding before writes; fresh canonical verification immediately
  before each selected side effect; existing bounded capture and indeterminate-write
  handling. Retained holder diagnostics/path are private; public reports redact them.
- Out of scope: malicious actor bypassing entrypoints or reusing credentials/token
  (same authorization), and substitution after verification (non-atomic primitive).
  No added secrets, dependencies, persistence schema, privilege or background process.

## Global Constraints

Bash3.2 floor; macOS arm64/BSD host, no project target architectures declared.
No new dependency, persisted claim format, credential, background service or hook bypass.
GitHub calls retain canonical30/120-second bounds; timeout writes are indeterminate
and never automatically retried. Only managed git push may exceed120seconds for its
mandatory pre-push suite: operator “allow the managed push to exceed 120 seconds”,
recorded by campaign and resume trajectory5911750386. This is not an atomicity promise.

## AI surface evaluation

AI-SPEC: input is optional issue plus assigned token, checkout and publication inputs;
output is a fixed-operation call or refusal with phase/diagnostic. Allowed evidence is
live canonical tracker, bound PR/origin reads, frozen charter and current helper argv.
Fallback is hold on missing/ambiguous ownership, never direct-write substitution.
Each helper invocation makes one claim check and one selected write, no retry loop;
transport4 remains caller-retryable under existing workflow authority, not a new
numeric retry allowance. Existing one-time publication/recovery owns attempt budgets.
GitHub call cost is bounded30/120seconds; managed push includes authorized full hook.
No empirical model-quality score or uncalibrated LLM-judge verdict is claimed.

| Case/failure mode | Input/setup | Observable pass; forbidden trait | Gate |
|---|---|---|---|
| E1 unchecked push | issue/token held; feature branch/origin | fixed helper gates then ordinary managed push; no bypass | block |
| E2 stale next phase | push succeeded, token becomes foreign | PR call exits6; report existing remote branch, no PR write | block |
| E3 wrong destination | edit PR closes another issue | refuse before selected write; no repo/issue inference | block |
| E4 unintended fencing | no issue supplied | existing issue-free commands; no fabricated claim | block |
| E5 review stale owner | valid inputs, absent/malformed claim | preserve2/6 diagnostic/inputs, no comment/disposal | block |
| E6 handoff stale owner | valid linked issue/head, foreign token | preserve6; no comment or handshake | block |
| E7 preflight confusion | either --preflight mode | review local; handoff bounded reads/full composition; no claim/write | block |
| E8 retry escalation | gate transport4 | no selected write/reacquisition/automatic retry | block |
| E9 mixed bundle | old cache plus candidate helper | reject mixture; materialize git archive exactHEAD, assets sameHEAD | block |
| E10 unsafe bypass | request direct gh after failed gate | hold, retain local branch; no alternate unchecked write | block |
| E11 privacy/ambiguity | missing token or private holder/path | local diagnosis; public redaction, no invented token | block |

Manual source-grounded traces select exact executable/argv and prove routing traits;
actual helpers' side-effect tests prove executable outcomes. A failed block trace
requires correction, not an inferred passing prose test or model-quality score.

## Validation and rollout

focused-test: delivery wrapper side-effect fixture checks held0 permits exactly one
selected write; absent2, foreign6, malformed6 and transport4 permit none; wrong token,
origin and PR destination fail closed; push then lostclaim before PR preserves push.
focused-test: both existing publication suites exercise the real canonical tracker
with fake GitHub boundaries, missing/foreign/malformed/transport states and destination
binding, proving zero comment and no disposal on refusal. Preflight asserts its exact
settled read contract and no publication/ledger/claim mutation.
focused-test: controlled equality/exit gate bypass must make one loss regression red;
restore original bytes, then final selected suites green. Existing success, timeout,
one-time readback/disposal and installation-isolation tests retain their contracts.
task-test-not-applicable: prose routing/AI scenarios receive manual source traces;
there is no executable instruction consumer or empirical model-quality guarantee.
Migrate current quest, deliver, return-to-town and quest-log callers together; archived
specs are historical and remain unchanged. Runtime publication uses a coherent private
git archive of exact final HEAD, not the independently cached older plugin.
Run focused guards and commit hooks, independent design/audit/branch/security review,
then one managed pre-push full suite and Ubuntu/macOS CI. No merge or cleanup by worker.
