# Forge-review publication preflight and recovery

## Scope and authority

The interactive operator requested: “Repair the Adept publication/recovery workflow outside the
bzr repository, then recover #573,” and approved the recommended preflight plus bounded-recovery
design on 2026-08-30.

The outcome is an Adept Quest workflow that rejects deterministic forge-review publication errors
before its terminal ambiguity state and can recover the already parked bzr PR #588 exactly once
under explicit authority. Completion requires focused regression tests, the Adept guardrail suite,
and successful publication recovery for bzr #573.

Permitted surface is the Quest skill, its publication helper and behavioral fixture, this design
record, ADR 0048, the implementation plan, and the plugin version. Excluded are changes to forge
review generation, GitHub-wide locking, alternate review storage, chunked comments, and unrelated
Adept or bzr work. No ambiguities remain after the operator selected the recommended design.

## Design

[ADR 0048](../../adr/0048-preflight-forge-review-publication.md) governs the ordering and recovery
contract.

`publish-forge-review --preflight` shares the publication path through complete body composition
and public-safety validation, then removes its own temporary body and exits successfully without
calling `gh`, appending the ledger, or disposing source artifacts. Normal publication remains
byte-for-byte compatible. The review-specific 4,096-byte check is removed; the final body check
continues to reject anything over 32,768 bytes before a post.

Quest invokes preflight immediately before its `publication-in-progress` rewrite. A preflight
failure retains the existing non-terminal handoff and all inputs. It never consumes the one-shot
publication attempt.

For a legacy or exceptional `publication-in-progress` state, Quest may recover only with explicit
human authorization. It revalidates the exact handoff identity and PR HEAD, confirms that no
complete annotation for that PR and no publication-verification ledger record exists after the
forge result, confirms all retained inputs through preflight, and appends an exact private recovery
record containing PR number and delivered SHA. A prior recovery record blocks another attempt.
After that record, Quest invokes normal publication once and follows the existing success or park
routes. The check must occur immediately before the attempt; any mismatch parks.

New `publication-in-progress` and `publication-verified` handoffs add one `review-payload:` field:
the exact absolute private payload path or the literal `none`. Recovery parses only that field for
payload identity. A legacy handoff without the field is eligible only when the human explicitly
supplies the exact path or `none` for that PR. Quest validates a supplied path and appends and reads
back `review-publication-payload-reconciled: <path|none>` before preflight. Current PR-body or
filesystem absence never supplies that value. A prior reconciliation record must match exactly;
otherwise recovery parks.

## Failure behavior

- Preflight validation or composition failure: no GitHub comment, no ledger mutation, no terminal
  handoff rewrite, generated body removed, source artifacts retained.
- Recovery evidence missing, mismatched, or ambiguous: park without posting.
- Authorized recovery publication failure: park permanently with the consumed recovery record.
- Publication success followed by verification or disposal failure: preserve the existing helper
  behavior and evidence; do not retry.

## Verification

The helper fixture must prove preflight never calls GitHub or changes the ledger, accepts the
observed 5,548-byte review when the total body fits, rejects an oversized composed body before
posting, removes its generated preflight body, and leaves every source artifact intact. Existing
normal-publication tests must remain green. `just verify` is the repository guardrail.

Because the repository forbids automated assertions on skill prose, the Quest change additionally
requires a recorded behavioral-review matrix. The reviewer must mark each row pass or fail against
the changed instructions and cite the governing lines:

| Scenario | Required result |
|---|---|
| No explicit recovery authorization | Park before preflight, ledger append, or GitHub write |
| Repository, PR, branch, base, or delivered HEAD mismatch | Park before recovery record |
| Handoff, forge-result record, or retained input mismatch | Park before recovery record |
| New handoff records `review-payload: none` | Recover only with an empty helper payload argument |
| New handoff records a payload path | Require that exact private file and publish it |
| Recorded payload is missing or mismatched | Park before recovery record |
| Legacy handoff without explicit payload reconciliation | Park before preflight or ledger mutation |
| Legacy handoff with human-supplied `none` | Append/read back the exact reconciliation record, then use an empty helper payload argument |
| Legacy handoff with a human-supplied path | Validate that exact private file, append/read back the exact reconciliation record, then use the path |
| Legacy reconciliation record disagrees with supplied value | Park without another append or publication attempt |
| PR body was edited after the legacy handoff | Never use current body presence or absence as payload identity evidence |
| Complete matching `WORK:REVIEW` comment exists | Park without another comment |
| Publication-verification record exists after the forge result | Park without another comment |
| Prior recovery-authorization record exists | Park without another attempt |
| Preflight fails | Park without recovery record or GitHub write |
| All evidence matches and authority is explicit | Append and read back recovery record before one publication attempt |
| The authorized attempt fails | Leave the consumed record and park; never attempt again |
| The authorized attempt succeeds | Follow the existing verification, disposal, and `publication-verified` route |

The matrix is a review obligation, not a prose-matching gate: the report must evaluate behavior and
ordering rather than search for prescribed sentences.
