# Zizmor version contract implementation plan

**Goal:** Admit exactly zizmor 1.29.0 at the shared guardrail boundary before any audit.

**Architecture:** Install the exact analyzer in CI with pinned setup-uv, and put the runtime
version contract in the existing `scripts/run-zizmor.sh` entry point used by local and CI
verification. Extend its fixture suite so the test controls both `--version` and audit
invocations.

**Tech stack:** Bash 3.2-compatible shell, shell fixture tests, Just, GitHub Actions.

## Global constraints

- The admitted analyzer version is exactly `1.29.0`; successful version output is exactly
  `zizmor 1.29.0`.
- CI uses `astral-sh/setup-uv@20cfd1bf945f4377ade1205e4dbc17946fc9a30d`
  (v10.0.1), uv `0.12.7`, and `uv tool install 'zizmor==1.29.0'`.
- Bash 3.2 is the floor. Use tabs in shell files, `set -euo pipefail`, and no `mapfile`,
  `readarray`, or associative arrays.
- The workstation path remains offline by default and adds no network prerequisite.
- Preserve all ADR 0036 mode-selection and credential behavior after version admission.
- `just verify` is the full local guardrail and `just ci` is the CI wrapper.

## Task 1: Prove and implement exact version admission

**Files:** modify `scripts/run-zizmor-test.sh` and `scripts/run-zizmor.sh`.

**Interfaces:** The test stub consumes `ZIZMOR_STUB_VERSION_OUTPUT` and
`ZIZMOR_STUB_VERSION_STATUS`. `scripts/run-zizmor.sh` consumes the existing `zizmor` on
`PATH`; later mode logic relies on successful exact output `zizmor 1.29.0`.

1. Extend the stub at the start of its body so `--version` prints
   `${ZIZMOR_STUB_VERSION_OUTPUT:-zizmor 1.29.0}` and exits
   `${ZIZMOR_STUB_VERSION_STATUS:-0}` without writing the audit argv or environment.
2. Extend `run()` to set the two version-stub variables to their successful defaults while
   preserving any case-specific override.
3. Add focused cases for 1.28.0, 1.30.0, output containing a metacharacter and an embedded
   newline followed by nonblank content, and a failed version command. Each case expects
   exit 1, expected and observed diagnostics where available, and an empty audit argv file.
   Keep an existing successful case proving the audit still runs after 1.29.0 is admitted.
4. Run `just test run-zizmor`; expect the new cases to fail because the current wrapper
   invokes the audit without checking the version.
5. Add `EXPECTED_ZIZMOR_VERSION='1.29.0'` near `LABEL` in `scripts/run-zizmor.sh`. Before
   mode selection, use a guarded command substitution to capture `zizmor --version` and
   its status. On nonzero, print the expected version, observed status, and installation
   action, then exit 1. On output other than `zizmor $EXPECTED_ZIZMOR_VERSION`, print the
   expected and observed output plus the same action, then exit 1.
6. Run `just test run-zizmor`; expect every focused fixture case to pass.
7. Run `just lint`, `just format-check`, and `just public-safety`; expect all three commands
   to exit 0 without warnings.
8. Commit with `fix: enforce the zizmor guardrail version`.

**Acceptance:** No audit invocation occurs after failed admission; exact 1.29.0 preserves
all existing behavior; diagnostics name expected and observed facts without executing or
normalizing observed text.

## Task 2: Provision the exact analyzer and ship the contract

**Files:** modify `.github/workflows/verify.yml`,
`docs/adr/0036-actions-check-names-its-zizmor-mode.md` only in its Status section, retain
new ADR 0044 and the linked design specification, and modify `.claude-plugin/plugin.json`.

**Interfaces:** The workflow produces `zizmor 1.29.0` on `PATH` for `just ci`.
`scripts/run-zizmor.sh` consumes it. ADR 0044 owns the exact version decision; ADR 0036
continues to own mode selection. The plugin manifest version is consumed by the harness
and ADR 0022's gate.

1. Remove `zizmor` from the Homebrew install line in `.github/workflows/verify.yml`.
2. After that step, add `astral-sh/setup-uv` pinned to
   `20cfd1bf945f4377ade1205e4dbc17946fc9a30d` with `version: "0.12.7"`, then a shell step
   that runs `uv tool install 'zizmor==1.29.0'` and `zizmor --version`.
3. Add one Status-section line to ADR 0036 stating that ADR 0044 enforces its 1.29.0
   measurement as the gate's admitted version; do not edit its historical body.
4. Change `.claude-plugin/plugin.json` from version `2.12.1` to `2.12.2`.
5. Run `just test run-zizmor`; expect all focused cases to pass.
6. Run `just verify` bare; expect exit 0, no warnings, and the workstation zizmor audit to
   report offline mode when no token is present.
7. Review `git diff main...HEAD` for scope, naming, and accidental host-specific data.
8. Commit with `ci: install the admitted zizmor version`.

**Acceptance:** Both matrix legs request the same exact analyzer, ADR 0036's caveat points
to the enforced decision, the installable plugin version is bumped once, and the complete
repository guardrail is green.

## Rollback and cleanup

Reverting both commits restores the floating-version behavior and manifest version as one
change. Fixture scratch directories remain owned by `fixture_init` cleanup. No persistent
state, generated artifact, external service, or migration requires cleanup.

## Durable handoff

- Branch: `feat/pin-zizmor-version-259`
- Base branch: `main`
- Full guardrail: `just verify`
- CI guardrail: `just ci`
- Focused guardrails: `just test run-zizmor`, `just lint`, `just format-check`,
  `just public-safety`
- Architecture: host `x86_64`; targets `none declared`; relationship
  `no-target-declared`
