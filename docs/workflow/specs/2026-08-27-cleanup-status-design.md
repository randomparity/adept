# Cleanup status preservation — design

Issue: #77. Decision:
[ADR 0045](../../adr/0045-cleanup-faults-preserve-earned-status.md).

## Scope and outcome

`check-ripgrep-config.sh` and `verify-push.sh` will account for scratch cleanup without allowing an
EXIT trap to invent a content finding or hide a status the run already earned. The change is
limited to both cleanup functions, their fixture suites, the required plugin patch-version bump,
and the design records. Unrelated cleanup sites and a shared abstraction are excluded.

## Failure contract

Each cleanup function captures `$?` on entry. Successful cleanup exits with that incoming status.
A failed or refused cleanup prints the gate's existing retained-path diagnostic and exits 2 when
the incoming status was 0; when it was non-zero, cleanup preserves it after printing the same
diagnostic. `verify-push.sh` folds the ordinary `rm -R "$TEMP_ROOT"` branch into its existing
`cleanup_failed` accounting and changes that accounting's otherwise-clean status from 1 to 2.

For `check-ripgrep-config.sh`, both a failed removal inside the expected scratch root and refusal
of a path outside that root follow the shared status tail. A successful removal returns directly
with the incoming status. This matches the accepted pattern in `check-skill-shape.sh` without
creating a helper across gates with different cleanup responsibilities.

## Compatibility and error handling

The implementation uses Bash 3.2-compatible `local`, `case`, `if`, and numeric tests. No command,
dependency, public API, or target architecture changes. A retained path remains owned by the
operator after the diagnostic; the suites keep their scratch roots under fixture cleanup so the
intentional test residue leaves with the fixture.

## Testing

Each suite adds a PATH-prepended `rm` shim that exits 1 for the gate's own scratch removal and
delegates other removals to the real command. With `TMPDIR` inside the suite fixture, tests prove:

- an otherwise-clean gate exits 2 and names the retained path;
- a run that already earned its existing failure status preserves it and still names the path;
- the original successful cleanup paths remain green.

The new assertions must bite: temporarily restoring each production cleanup's unguarded removal
must make its focused suite fail. Focused suites run first; `just verify` is the final repository
guardrail. CI runs the same chain through `just ci` on Ubuntu and macOS.

## Durable context

Branch: `feat/fix-cleanup-status-77`. `BASE_BRANCH`: `main`. Host architecture: `x86_64`; target
architectures: none declared; relationship: `no-target-declared`; userland: GNU. Guardrails are
`just test check-ripgrep-config verify-push` while iterating and bare `just verify` before
shipping. ADR index coupling is not coupled because the repository deliberately uses the
directory listing as its index.
