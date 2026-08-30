# Forge-review publication preflight and recovery plan

## Goal

Prevent deterministic publication failures from entering Quest's terminal ambiguity phase and
provide one evidence-bound, human-authorized recovery for an already parked publication.

The Bash helper owns byte-exact validation and composition. Quest owns state sequencing and the
recovery authorization contract. Bash 3.2 remains the runtime floor.

## Global Constraints

- Normal publication remains byte-for-byte compatible.
- Summary, optional payload, and inline not-required reason retain the 4,096-byte cap.
- The complete publication body retains the 32,768-byte cap.
- A recovery attempt requires explicit human authorization and is consumed before its external
  write.
- `just verify` must pass.

## Task 1 — Add validation-only helper preflight

Files:

- Modify `tests/fixtures/quest/publish-forge-review-test.sh`.
- Modify `skills/quest/scripts/publish-forge-review`.

Interfaces:

- Consume the existing six-or-seven publication arguments after a leading `--preflight`.
- Produce no GitHub call or ledger line in preflight mode; print one `preflight-ok` line.
- Preserve the existing normal invocation and output.

Steps:

1. Add fixture cases that invoke `--preflight` with a 5,548-byte private review, assert zero fake
   `gh` events, unchanged ledger and retained sources, no temporary body, and `preflight-ok`; then
   publish a fresh 5,548-byte review through normal mode and assert the verified comment body plus
   ordinary ledger and disposal behavior.
2. Run `just test publish-forge-review`; expect the new case to fail because the option is rejected
   or the review exceeds the local source limit.
3. Parse the optional mode before existing arguments, remove the review-specific source cap, and
   exit after successful composition by deleting only the generated body.
4. Add a composed-body overflow preflight assertion; expect a nonzero exit, no GitHub event, and
   retained inputs.
5. Run `just test publish-forge-review`; expect all fixture cases to pass.
6. Commit the helper and fixture as `fix(quest): preflight review publication`.

Acceptance: preflight and publication exercise one validation/composition implementation, and no
preflight path can reach `post_comment`, ledger append, or source disposal.

## Task 2 — Sequence Quest and define bounded recovery

Files:

- Modify `skills/quest/SKILL.md`.
- Modify `.claude-plugin/plugin.json`.

Interfaces:

- Quest invokes the helper's `--preflight` interface immediately before its terminal handoff write.
- The private ledger recovery line is
  `review-publication-recovery-authorized: pr <number> head <full-sha>`.

Steps:

1. Update Quest's resume routing so `publication-in-progress` remains parked unless explicit human
   recovery authority and every ADR 0048 predicate are present.
2. Persist `review-payload:` as the exact path or `none` in new terminal handoffs; require that
   identity during recovery, and admit a legacy handoff only after an explicit human-supplied
   path-or-`none` value is validated and recorded in the private ledger.
3. Require absence of a prior recovery line, append and read back the exact recovery line before
   the retry, and route that one attempt through the unchanged publication success checks.
4. Add the mandatory preflight call and require its success before writing
   `publication-in-progress`.
5. Review the changed Quest instructions against every scenario in the spec's behavioral-review
   matrix, recording pass/fail and cited lines; fix every failed row and repeat the matrix.
6. Bump the plugin patch version in `.claude-plugin/plugin.json`.
7. Run `just verify`; expect every repository gate to pass.
8. Commit as `fix(quest): recover pre-write publication failures`.

Acceptance: deterministic failures cannot create a terminal handoff, ambiguous failures cannot
retry automatically, and one explicitly authorized recovery cannot be repeated.

## Rollback

Revert both implementation commits together. Do not leave Quest requiring a helper mode absent
from the installed plugin, and do not retain the recovery route without its preflight predicate.
