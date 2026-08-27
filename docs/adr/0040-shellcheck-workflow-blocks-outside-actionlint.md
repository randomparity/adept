# 0040 ShellCheck workflow blocks outside actionlint

## Status

Accepted (2026-08-27)

## Context

The `actions-check` gate lets actionlint invoke ShellCheck for workflow `run:` blocks. With
actionlint 1.7.12, that integration can deadlock after ShellCheck exits: actionlint remains
asleep with a self-held pipe, no ShellCheck child, and no progress. The failure reproduced on
`.github/workflows/pages.yml` and matches upstream `rhysd/actionlint#704`. Actionlint succeeds
with the integration disabled, and ShellCheck succeeds on the extracted Pages block.

ADR 0034 deliberately keeps the Pages build inline. Moving it to a script would overturn that
accepted decision and would not cover future inline workflow shell.

## Decision

Run actionlint with its integrated ShellCheck command disabled. In the same fail-closed gate,
extract every supported workflow `run: |` literal block and invoke ShellCheck on each block
independently with the explicit Bash dialect (`shellcheck -s bash`). The extractor deliberately
supports the repository's bounded workflow subset: no `shell:` overrides, and only static
Ubuntu/macOS runners or the exact `matrix.os` expression when every literal matrix value is an
Ubuntu/macOS runner. Reject an entire workflow containing another shell or runner form, and reject
unsupported `run:` scalar forms, instead of trying to infer a dialect or silently omitting a
block. Propagate actionlint, extraction, and ShellCheck failures.

Keep the orchestration in a Bash 3.2-compatible script with a focused fixture suite. The
`actions-check` recipe calls that script before zizmor.

## Consequences

Actionlint retains workflow validation and ShellCheck retains embedded-Bash validation, without
the deadlocking child-process integration. The Pages build stays inline. The policy is stricter
than GitHub Actions: a future Windows job or explicit Bash declaration requires extractor support
before it can land, even if that job has no run block. A workflow form the extractor does not
understand stops the gate rather than reducing coverage.

## Considered & rejected

- **Move the Pages build into a shell script.** Rejected: ADR 0034 chose the inline build, and
  moving one block would not preserve coverage for other blocks.
- **Disable integrated ShellCheck without replacing it.** Rejected: embedded shell defects would
  go unchecked.
- **Retry or time out actionlint.** Rejected: retries retain a known race and a timeout only
  delays its report.
- **Add a YAML-parser dependency.** Rejected: the repository's constrained forms can be extracted
  and rejected fail-closed without new provisioning or supply-chain surface.
