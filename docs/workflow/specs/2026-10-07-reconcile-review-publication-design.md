# Reconcile a verified review publication

Issue #312; scope `q312-dde59a09`. Decision: [ADR0083](../../adr/0083-reconcile-verified-review-publication.md).

## Problem

The helper can verify a remote comment and fail while appending or reading back its
local verification line. PFR-6 reproduces the present-line failure. Quest parks, and
ADR0048 recovery rejects the very existing comment needed to finish.

## Scope and success

Under explicit human authorization for this exact PR, reconcile the original
retained inputs with one exact existing comment. Both absent verification and one
complete matching but unverified line must complete without another comment.
Keep quest responsible for authority, exact handoff/forge-result binding, original
input identity, complete comment-list ambiguity checks and unchanged delivered HEAD.
Extend the existing helper, which already owns composition, remote readback,
verification ledger and disposal; no ownership transition or new executable.
Automatic retry, ambiguous/mismatched comments, changed HEAD and substituted inputs
remain excluded with their owners frozen in WORK:SCOPE.

## Behavior

Add `--reconcile COMMENT-URL RETAINED-BODY` before the required claim flag. Quest
first validates its publication-in-progress handoff and original private inputs,
including legacy payload reconciliation. After its forge-result record, permit no
publication closing record and zero or one exact verified line for the selected URL;
reject other verification text, duplicates or a consumed recovery authorization.
Select exactly one complete matching comment and independently read its exact URL.
Require that comment's repository/PR identity and full body match the original
helper-generated body and composition of the original inputs. Require the original
body to be a private regular direct child named `.publish-forge-review.` plus six
characters; do not substitute a fresh body or select by filesystem recency.

Immediately before invoking reconciliation, repeat PR identity/HEAD and comment
checks, append/read back the existing recovery-authorization line once, then call
the helper in reconciliation mode. The helper composes through the normal validation
path, compares the retained body byte-for-byte, removes only its comparison temporary,
and adopts the original body. It verifies the claim/destination and reads the existing
comment; this mode has no comment-create call. It appends verification if absent,
or reads back the one existing exact line without duplicating it, then runs existing
disposal and closing-record logic. Quest applies the normal exact closing partition,
unchanged-HEAD and atomic publication-verified handoff checks. A failed attempt parks
with evidence and cannot consume a second allowance.

## Failure model

Actors are a human-authorized quest and its installed Bash3.2 helper on macOS/Linux,
with exclusive ownership of its private workspace and publication attempt. Assets
are the already-published review, original private evidence and nonduplicate ledger.
Ledger append/readback failure and failed disposal are exercised. Wrong URL, wrong
body, nonprivate or substituted body, and remote read failures must stop before ledger
repair or disposal. Concurrent workspace mutation is excluded by existing exclusive
ownership, not made atomic across GitHub and disk. Later changed PR HEAD or comment
is operator reconciliation; repeated failed recovery remains terminal by ADR0048.

## Validation

Extend the installed-copy helper fixture: reproduce absent and present verification
failures, then reconcile each and assert exactly one lifetime comment invocation,
one verified line and complete closing ownership. Include both forge modes, payload,
wrong comment body/identity, invalid retained body and failed recovery readback.
Red: existing helper rejects the new mode. Green: `just test publish-forge-review`.
Read quest recovery/handoff instructions and ADR manually; prose assertions are
forbidden by repository anatomy rule4. Run `just commit-check`, shape/plugin/version
checks, then final full local `just ci` through the mandatory pre-push hook and CI.
