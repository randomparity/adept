# Zizmor version contract design

Issue: #259. Decision: [ADR 0044](../../adr/0044-the-zizmor-gate-admits-one-version.md).

## Goal

Make the zizmor analyzer version a deterministic guardrail precondition shared by CI and
workstations, with an actionable failure before any audit runs.

## Scope and guarantees

The existing `scripts/run-zizmor.sh` boundary will admit exactly zizmor 1.29.0. This is the
smallest shared point: `just actions-check`, `just verify`, `just ci`, and both CI matrix
legs already invoke it. No new script, installer, dependency, or network operation is
needed.

The wrapper must:

1. execute `zizmor --version` before mode selection or auditing;
2. continue only when stdout is exactly `zizmor 1.29.0` and the command succeeds;
3. otherwise exit 1 and name the expected version plus the observed output or command
   failure;
4. never invoke the audit after a failed version check; and
5. retain all existing mode selection, credential handling, diagnostics, and exit-status
   forwarding after admission succeeds.

CI keeps the existing Homebrew installation. The wrapper is the enforcement point, so a
different Homebrew resolution produces a red matrix leg before analysis. The same behavior
on a workstation keeps `just verify` offline by default: `--version` is local and the later
tokenless audit remains explicitly offline.

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

The existing `PATH` lookup is the only trust boundary: a local operator or CI provisioning
selects the `zizmor` executable. The design adds a read of that executable's `--version`
output and widens no network, credential, authorization, or file boundary.

### Actors and trust

CI provisioning and the local operator are trusted to choose `PATH`; a compromised binary
was already able to execute during the audit. Version output is untrusted text used only
for exact comparison and an error message. The GitHub token remains handled by the existing
ADR 0036 flow and is never read or printed by the version check.

### Controls

The complete output is compared as inert shell data inside `[[ ... ]]`; it is never
evaluated, split into a command, or used as a path. A nonzero version command and every
non-exact output fail closed before the audit. Tests cover metacharacters and multiple
lines as mismatch data and prove the audit stub is not invoked.

### Out of scope

Binary provenance and installer compromise are unchanged: an executable can lie about its
version, and this change does not add signature verification. Pinning unrelated CI tools is
owned by separate work. These risks are not worsened by reading `--version` before running
the same executable.

## Verification

The focused fixture suite proves the version gate red before implementation, then green for
all admission and failure paths. `just verify` runs bare and must remain green without a
token or network. CI then proves both hosted runner legs install an admitted version and run
the existing online audit path.

The plugin manifest receives a patch version bump because every repository change must be
installable under ADR 0022.

