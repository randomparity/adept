# Report outranked scan faults — design

Issue: #87. Decision: [ADR 0043](../../adr/0043-report-outranked-scan-faults.md).

## Scope and outcome

The record gate will preserve a positive result when one witness succeeds after another witness
faults, while reporting that incomplete search through a warning owned by the predicate's caller.
The change is limited to `renumbered_elsewhere` and `gate_existed_at`, their callers, mirrored
copies, and regression coverage. Other scan-fault sites remain owned by their existing issues.

## Contract

Both predicates retain their current three outcomes and add status `3` for
`positive-with-fault`:

- `0`: positive result, complete search up to the decisive witness;
- `1`: negative result;
- `2`: fault with no positive result; and
- `3`: positive result after an earlier independent scan fault.

For status `3`, the predicate preserves the same positive-result globals as status `0` plus the
existing fault-location and fault-status globals. The caller emits one `warn_full` diagnostic and
then executes its status-0 action. `renumbered_elsewhere` uses `W-RENUMBER-SCAN` before its
renumber note. `gate_existed_at` uses `W-GATE-WITNESS-SCAN` before the existing
`E-GATE-EMPTY-SET` result. Neither warning changes the process exit status.

## Components and data flow

`renumbered_elsewhere` remembers the first or latest candidate fault as it does today. When a
later canonical-content match is found, it returns `3` rather than `0` if a fault was remembered.
Its caller reports the saved `renumber_fault_path` and `path_exists_status`, then prints the
existing renumber note.

`gate_existed_at` likewise returns `3` when a later filesystem or workflow witness succeeds after
a fault. `check_gate_files` reports the saved `gate_witness_path` and `path_exists_status`, then
emits the same empty-protected-set error used for an ordinary positive witness.

The source and test mirrors under `.github/scripts/` and
`skills/tome-of-lore/assets/` are edited identically. The plugin patch version is bumped so the
change is installable.

## Error handling and compatibility

Status `2` remains the only no-answer fault and keeps its existing error diagnostic. Status `3`
is deliberately a warning because the positive evidence still decides the predicate. All shell
changes remain compatible with Bash 3.2 and use existing globals and emitters; no dependency or
public API is added.

## Testing

The existing `renumber_match_outranks_fault` fixture will assert exit 0, the real renumber note,
and `W-RENUMBER-SCAN` naming the failed candidate read and exit status. A new gate fixture will
make one `ls-tree` witness fault before a later real witness succeeds, assert the existing
`E-GATE-EMPTY-SET` verdict, and assert `W-GATE-WITNESS-SCAN` names the failed witness and status.

Each new assertion must bite: temporarily neutralising the status-3 caller branch must make its
focused suite fail, after which the implementation is restored. `just records` proves fixture
behavior and mirror identity; `just verify` is the final repository guardrail.

## Alternatives

Keeping the fault silent, failing on it, reporting inside the predicate, and using an optional
success side channel are rejected in ADR 0043. The selected fourth outcome is the smallest design
that preserves both caller-owned reporting and the established positive verdict.
