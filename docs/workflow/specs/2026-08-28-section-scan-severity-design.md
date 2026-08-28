# E-SECTION-SCAN severity design

## Scope

Issue #90 requires the record checker to treat a required-section grep fault as a fault of
the scan rather than a defect in the record. The permitted implementation surface is the
checker and test mirrors plus the plugin manifest version. This change adds no dependency,
public interface, schema, persistence, concurrency, authentication, migration, or external
service behavior.

The governing failure-semantics rule originates in ADR 0005 and is carried forward by the
accepted ADRs 0024 and 0025. This design applies that existing decision; it makes no new
architectural decision and therefore adds no ADR.

## Design

Change the `E-SECTION-SCAN` branch in `check_sections` from `err` to `err_full`. Keep the
existing three-way grep status handling and diagnostic unchanged. Add a nearby comment that
explains why the full-severity channel is required: a scan fault describes the scan, so a
base-nonconforming record must not downgrade it to `W-LEGACY-SHAPE`.

The regression fixture will first commit a deliberately legacy debt record, making the base
conformance pass select downgrade mode. It will then shadow `grep` with a fixture-local stub
that exits 2 only for the exact required-section lookup used by `check_sections` and delegates
every other invocation to the real grep. The focused assertion must observe exit 1 and
`E-SECTION-SCAN`; it must also reject `W-LEGACY-SHAPE` for that finding. This isolates the
failure channel without relying on file permissions, which cannot deny reads when tests run
as root.

The production and test edits are made in `.github/scripts/` and copied byte-for-byte to the
corresponding `skills/tome-of-lore/assets/` files. The plugin patch version increases once so
the harness can install the fix.

## Scan-code sweep

Review every remaining `E-*-SCAN` emission in the record checker and its ADR/debt profiles.
Any scan fault that can execute while `emit_mode=downgrade` must use `err_full`; ordinary
record-shape findings may continue to use `err`. The sweep changes only sites with the same
verified root cause. Adjacent codes already using `err_full`, and migrator codes using their
separate `report_failure` channel, remain unchanged.

## Error behavior and compatibility

Matched and missing-section outcomes remain unchanged. Only grep execution faults on a
grandfathered record change from warning/exit 0 to error/exit 1. The implementation remains
Bash 3.2-compatible and must behave on GNU/Linux and macOS/BSD userlands; it introduces no
new shell feature or external command.

## Verification

The new case must be proven to bite by running the focused record-checker suite before the
production channel change and observing its expected failure. After implementation, run the
same focused suite, `just records` to prove mirror identity and record behavior, and bare
`just verify` before shipping. CI must pass `just ci` on both ubuntu-latest and macos-latest.

## Durable workflow context

- Branch: `feat/fix-section-scan-90`
- Base branch: `main`
- Full guardrail: `just verify`
- CI wrapper: `just ci`
- Focused suite: `just test check-records`
- Scope identity: https://github.com/randomparity/adept/issues/90; `q90-d6de4563`
