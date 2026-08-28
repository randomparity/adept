# Zizmor version contract design

Issue: #259. Decision: [ADR 0044](../../adr/0044-the-zizmor-gate-admits-one-version.md).

## Goal

Make the zizmor analyzer version a deterministic guardrail precondition shared by CI and
workstations, with an actionable failure before any audit runs.

## Scope and guarantees

The existing `scripts/run-zizmor.sh` boundary will admit exactly zizmor 1.29.0. This is the
smallest shared point: `just actions-check`, `just verify`, `just ci`, and both CI matrix
legs already invoke it. CI will install that exact version through pinned setup-uv and
`uv tool install`; workstations keep using their existing locally installed binary.

The wrapper must:

1. execute `zizmor --version` before mode selection or auditing;
2. continue only when stdout is exactly `zizmor 1.29.0` and the command succeeds;
3. otherwise exit 1 and name the expected version plus the observed output or command
   failure;
4. never invoke the audit after a failed version check; and
5. retain all existing mode selection, credential handling, diagnostics, and exit-status
   forwarding after admission succeeds.

CI removes zizmor from the Homebrew bundle, installs uv 0.12.7 through
`astral-sh/setup-uv@20cfd1bf945f4377ade1205e4dbc17946fc9a30d` (v10.0.1), and runs
`uv tool install 'zizmor==1.29.0'`. The exact request makes version transitions independent
of staggered runner images. The wrapper remains the enforcement point and catches an
installer or `PATH` mismatch before analysis. On a workstation, `--version` is local and
the later tokenless audit remains explicitly offline.

## Components and data flow

`scripts/run-zizmor.sh` contains the single `EXPECTED_ZIZMOR_VERSION=1.29.0` declaration.
It captures `zizmor --version` without losing the command status, compares the complete
output, and either reports a mismatch or continues into the unchanged mode-selection flow.
The existing fixture stub gains a version-query branch, allowing the focused suite to prove
accepted, mismatched, malformed, and failed version observations without a real binary or
network.

ADR 0036's measured-on-1.29.0 language remains factually useful. ADR 0044 changes its
status from an unenforced caveat to the exact contract the wrapper checks; no historical
measurement or mode decision is rewritten.

## Failure behavior

- Expected output: continue silently so the established mode line remains the first audit
  status message.
- Older, newer, or malformed output: exit 1 with
  `run-zizmor: expected zizmor 1.29.0, observed <output>; install zizmor 1.29.0`.
- Failed `--version`: exit 1 with the expected version, the command status, and an install
  instruction. The audit invocation must remain absent.
- Multi-line output is a mismatch and is rendered as observed data; no value is evaluated
  as shell code.

## Threat model

### Boundary inventory

The existing `PATH` lookup remains a trust boundary: a local operator or CI provisioning
selects the `zizmor` executable. The design adds a pinned third-party setup action and a
PyPI tool download to CI, plus a read of the executable's `--version` output. It widens no
credential, authorization, or file boundary.

### Actors and trust

The pinned setup-uv commit and PyPI are trusted to provision the requested package; the
local operator is trusted to choose `PATH`. A compromised binary was already able to
execute during the audit. Version output is untrusted text used only for exact comparison
and an error message. The GitHub token remains handled by the existing ADR 0036 flow and is
never read or printed by installation or the version check.

### Controls

The setup action is pinned by full commit SHA, uv by exact version, and zizmor by exact
package version. The complete version output is compared as inert shell data inside
`[[ ... ]]`; it is never evaluated, split into a command, or used as a path. A nonzero
version command and every non-exact output fail closed before the audit. Tests cover
metacharacters and multiple lines as mismatch data and prove the audit stub is not invoked.

### Out of scope

An executable can lie about its version, and this change does not add independent signature
verification beyond setup-uv's release checks and the package index transport. Pinning
unrelated CI tools is owned by separate work.

## Verification

The focused fixture suite proves the version gate red before implementation, then green for
all admission and failure paths. `just verify` runs bare and must remain green without a
token or network. CI then proves both hosted runner legs install an admitted version and run
the existing online audit path.

The plugin manifest receives a patch version bump because every repository change must be
installable under ADR 0022.
