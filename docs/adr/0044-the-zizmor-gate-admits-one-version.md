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
failure or any other output after shell command substitution removes trailing newlines
stops the gate before the audit and reports the expected and observed result.

CI installs uv 0.12.7 through `astral-sh/setup-uv` v10.0.1 pinned to commit
`20cfd1bf945f4377ade1205e4dbc17946fc9a30d`, then runs
`uv tool install 'zizmor==1.29.0'`. Both matrix legs therefore request the same analyzer
package instead of accepting runner-image state. Workstations use the same wrapper
admission check, so the local and CI contracts cannot silently diverge. Updating zizmor
requires one reviewed change to the CI request, wrapper expectation, version-sensitive
tests, and documentation; the existing version remains installable while that change is
reviewed.

ADR 0036 remains authoritative for mode selection. Its caveat that those semantics were
measured on 1.29.0 is now an enforced precondition rather than an unbounded residual.

## Consequences

- Every successful zizmor audit in `just verify` uses 1.29.0 on CI and workstations.
- CI requests the admitted analyzer version directly, so staggered runner-image package
  updates cannot deadlock a version transition.
- A workstation moving forward or backward fails with the expected and observed versions
  instead of producing analyzer-dependent findings.
- `just verify` remains offline by default; the new check executes only the installed
  binary's local `--version` command.
- A new upstream release does not change CI until the repository reviews and updates its
  declared contract.
- The check trusts the `zizmor` executable selected by `PATH`, as the audit invocation
  already does. It makes no new network request and handles no new credential.
- CI adds the pinned setup-uv action and PyPI as provisioning dependencies. A failure to
  download uv or the exact zizmor wheel fails in the install phase before verification.

## Considered & rejected

- **Keep Homebrew as CI's zizmor installer and admit only 1.29.0.** verified: issue #259's
  observed 1.28.0/1.29.0 matrix skew supplies a state where changing the admitted version
  leaves either the updated or stale runner leg red. An exact installer is required for a
  green transition, not only for drift detection.
- **Assert only that matrix legs agree.** judgment: cross-job aggregation adds workflow
  state, permits both legs to agree on an unreviewed version, and does not constrain the
  workstation path.
- **Pin a Homebrew formula version.** verified: issue #259 records that Homebrew provides
  no first-class version pin for the latest-only zizmor formula. Depending on an extracted
  formula would add repository or tap maintenance solely to preserve the installer.
- **Keep the version floating and retain ADR 0036's caveat.** verified: issue #259 records
  one required workflow run where 1.28.0 and 1.29.0 gated the same commit; the caveat did
  not prevent the divergence.
