# 0044 — The zizmor gate admits one version

## Status

Accepted (2026-08-27)

## Context

The two `Verify` matrix legs installed different Homebrew versions while gating the same
commit: zizmor 1.28.0 on macOS and 1.29.0 on Ubuntu. The shared workstation and CI entry
point, `scripts/run-zizmor.sh`, depends on CLI details measured on 1.29.0, but it currently
runs any `zizmor` found on `PATH`.

The upstream GitHub releases page named v1.29.0 as the latest stable release on 2026-08-27.
The local `zizmor --version` output was `zizmor 1.29.0` at design time.

## Decision

`scripts/run-zizmor.sh` owns an exact expected version, 1.29.0. Before selecting an audit
mode, it runs `zizmor --version` and requires the exact output `zizmor 1.29.0`. A command
failure or any other output stops the gate before the audit and reports the expected and
observed result.

CI continues installing zizmor with Homebrew. Homebrew may resolve a different package,
but the guardrail suite will not use it: both matrix legs enter through the same wrapper
and must pass the same admission check. Workstations use that same path, so the local and
CI contracts cannot silently diverge. Updating zizmor requires one reviewed change to the
expected version and its version-sensitive tests and documentation.

ADR 0036 remains authoritative for mode selection. Its caveat that those semantics were
measured on 1.29.0 is now an enforced precondition rather than an unbounded residual.

## Consequences

- Every successful zizmor audit in `just verify` uses 1.29.0 on CI and workstations.
- A runner image moving forward or backward fails with the expected and observed versions
  instead of producing analyzer-dependent findings.
- `just verify` remains offline by default; the new check executes only the installed
  binary's local `--version` command.
- A new upstream release intentionally turns CI red only after Homebrew installs it. The
  repository must then review and update its declared contract before adopting the release.
- The check trusts the `zizmor` executable selected by `PATH`, as the audit invocation
  already does. It makes no new network request and handles no new credential.

## Considered & rejected

- **Install `zizmor==1.29.0` through `uv tool install` in CI.** judgment: this adds a
  second CI installer and still needs a shared workstation admission check; it is more
  mechanism without strengthening the contract.
- **Assert only that matrix legs agree.** judgment: cross-job aggregation adds workflow
  state, permits both legs to agree on an unreviewed version, and does not constrain the
  workstation path.
- **Pin a Homebrew formula version.** verified: issue #259 records that Homebrew provides
  no first-class version pin for the latest-only zizmor formula. Depending on an extracted
  formula would add repository or tap maintenance solely to preserve the installer.
- **Keep the version floating and retain ADR 0036's caveat.** verified: issue #259 records
  one required workflow run where 1.28.0 and 1.29.0 gated the same commit; the caveat did
  not prevent the divergence.

