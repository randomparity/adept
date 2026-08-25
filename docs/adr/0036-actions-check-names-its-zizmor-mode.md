# 0036 — `actions-check` names the zizmor mode it ran and the condition that chose it

## Status

Accepted (2026-08-25)

## Context

`actions-check` runs `zizmor --offline .github/workflows/`. Offline mode disables every
audit that needs the GitHub API, and those are the audits that check a pin's provenance:
whether the 40-character SHA a `uses:` names is reachable in the repository it names, and
whether the pinned revision is covered by a known advisory. Offline mode confirms a pin's
*shape* and nothing else, so an impostor SHA borrowed from a fork is a well-formed pin.
Five action pins are in the tree; the next bump — a hand edit, or Dependabot once #236
lands — would be checked by shape alone.

Issue #239 proposes dropping `--offline` so zizmor uses the API when a token is present.
Measured on this workstation (macOS 26.6.1 arm64, zizmor 1.29.0), that alone is not a fix:
`env -u GH_TOKEN -u GITHUB_TOKEN -u ZIZMOR_GITHUB_TOKEN zizmor .github/workflows/` exits 0
having audited nothing online, and says so only as a `WARN` line inside the tool's own log
stream. The gate's own output would then be identical whether provenance was audited or
not — the silent skip [ADR 0025](0025-a-skip-reports-the-condition-not-the-cause.md)
decision 2 forbids, in a gate rather than a test.

The operator settled the one design-changing question before this record was written: a
machine with no token degrades to the offline subset and stays green, because no other
gate in this repository requires network or credentials. Failing there was considered and
explicitly rejected.

Two things then need deciding that the issue leaves open — what the gate says when it
degrades, and whether CI is given a token at all.

## Decision

**1. The gate announces its mode and the condition that chose it, before the scan runs.**
`actions-check` invokes `scripts/run-zizmor.sh`, which consults zizmor's own documented
token sources in zizmor's own order (`GH_TOKEN`, `GITHUB_TOKEN`, `ZIZMOR_GITHUB_TOKEN` —
`zizmor --help`, Network Options) and then `gh auth token`, and prints one line naming the
mode and the source, or two lines naming the mode, the observed condition, and the
consequence:

```
zizmor: online mode; API token from GH_TOKEN
zizmor: offline mode (--offline); no API token: GH_TOKEN, GITHUB_TOKEN and
  ZIZMOR_GITHUB_TOKEN are unset and `gh auth token` exited 1
zizmor: pin provenance was NOT audited — ...
```

The condition reports what the script observed and nothing it did not establish, which is
ADR 0025 decision 2 applied here. Three conditions are distinguished rather than one,
because they call for different responses: `gh` absent from `PATH`, `gh auth token`
exiting non-zero (with the status observed, and no cause named for it), and `gh auth
token` exiting 0 having printed no token. zizmor's exit status is captured into a variable
and re-raised, never piped and never `|| true`.

**2. The tokenless path passes `--offline`, not `--no-online-audits`.** `--offline`
forbids all online operations; `--no-online-audits` is the documented weaker form that
disables connectivity-dependent audits while still permitting online operations. The
requirement is that the gate be green with no network *at all*, so the flag that states
that as a property of the run is the right one. The one thing `--no-online-audits`
permits that `--offline` does not — auditing a remote `user/repo` input — this gate never
uses; its only input is the local `.github/workflows/` directory. `--offline` is also the
flag in the recipe today, so the offline invocation is unchanged and every audit that
passes now passes identically.

**3. CI receives a token, at the permission it already has.** The `Verify` step in
`.github/workflows/verify.yml` gains `GH_TOKEN: ${{ github.token }}` in its existing
`env:` block. The job's `permissions: contents: read` is **not** widened and checkout's
`persist-credentials: false` is **not** relaxed: the online audits read public
repositories' refs and the public advisory database, and `contents: read` on this
repository is the floor a usable `GITHUB_TOKEN` needs for that. The security-posture
change is therefore that the token's *value* becomes visible to the `just ci` step, not
that any permission grows. On a fork pull request GitHub makes `GITHUB_TOKEN` read-only
regardless of the `permissions:` block, so the most a compromised gate script obtains is
authenticated read access to a public repository — content the same actor can already
read unauthenticated, at a lower rate limit.

## Consequences

- Every `actions-check` run states its mode, so a reader of a green gate learns whether
  provenance was audited without knowing zizmor's defaults.
- CI audits provenance on both runners, on every pull request. A workstation with an
  authenticated `gh` audits it too, so the pre-push hook catches a bad pin first.
- A machine with neither says so, twice, and stays green. `just verify` gains no
  dependency on network or credentials.
- A gate now reads a credential. On a workstation the fallback reads the developer's
  personal `gh` token, which is scoped more broadly than a public read needs; it is used
  for one read-only API session and is never persisted or printed. A developer who does
  not want it used exports `GH_TOKEN` to something narrower, or exports it empty, and the
  gate then reports offline mode with the condition.
- The token reaches the child through the environment rather than argv, so it is not
  visible in `ps` to other processes of the same user. Beyond that this decision trusts
  zizmor with a credential its `--gh-token` interface exists to receive; a malicious
  zizmor release is not addressed here, and the tool is installed unpinned from Homebrew
  alongside every other gate tool.
- Residual: nothing *fails* when CI degrades to offline. If the `GH_TOKEN` line is removed
  or `github.token` stops resolving, CI prints the offline condition and stays green. The
  mode line is the whole mitigation, and it is a log line — weaker than a red check, and
  accepted as such under decision 3's rejected alternative below.
- Mode selection lives in a script rather than in the recipe body, which brings it under
  `shellcheck`, `shfmt`, and a suite. It is a gate script under `scripts/`, so anatomy
  rules 1 and 2 do not bind it; rule 3 holds, as it runs and exits.

## Considered & rejected

- **Drop `--offline` and change nothing else** — the issue's literal proposal. verified:
  on this workstation (macOS 26.6.1 arm64, zizmor 1.29.0), `env -u GH_TOKEN -u
  GITHUB_TOKEN -u ZIZMOR_GITHUB_TOKEN zizmor --no-progress .github/workflows/` exits 0
  and reports `No findings to report` with the degrade announced only as a `WARN` line in
  zizmor's log stream. The gate's verdict and output would not distinguish an audited run
  from an unaudited one.
- **Fail `actions-check` when no token is reachable.** verified: the operator settled this
  before design. No other gate consults the network or a credential — scanning every gate
  script for one (`rg --no-config -e '\bgh\b|curl|wget|api\.github|GH_TOKEN|GITHUB_TOKEN|https?://' scripts/*.sh .github/scripts/check-records.sh`,
  on this branch) returns exactly one hit, and it is the `gh[pousr]_` *pattern literal*
  inside `check-public-safety.sh`'s secret-detection list, not a call. A gate that reddens
  on a plane is a gate people learn to skip.
- **Use `--no-online-audits` on the tokenless path.** verified: `zizmor --help` (1.29.0)
  describes it as "a weaker version of `--offline`: instead of completely forbidding all
  online operations, it only disables audits that require connectivity." Its one added
  capability is auditing a remote `user/repo` input, which this gate never passes.
- **Let zizmor pick its own mode and say nothing** (drop `--offline`, keep the recipe a
  one-liner). judgment: it is decision 1's problem restated — correct behaviour, invisible
  outcome — and ADR 0025 decision 2 governs exactly that.
- **Report only "offline" without the condition.** judgment: an operator reading it cannot
  tell whether to install `gh`, run `gh auth login`, or export a token, which is the
  discrimination ADR 0025 decision 2 requires a degrade line to carry.
- **Write the mode selection inline in the `actions-check` recipe.** verified:
  `scripts/list-shell-sources.sh` classifies a tracked file as a shell source by a `.sh`
  name or a bash shebang, and `Justfile` is neither — `scripts/check-ripgrep-config.sh`
  documents the same blind spot for its own scan — so an inline branch would be unseen by
  `shellcheck` and `shfmt`. The `test` recipe discovers suites as tracked `*-test.sh`
  paths (`git ls-files -z -- '*-test.sh'`), so an inline branch is also untestable, and
  the reporting behaviour is the whole subject of this record.
- **Omit the `gh auth token` fallback and require an explicitly exported token.**
  judgment: every developer who can push here already has an authenticated `gh`, which
  `$quest`, `$deliver`, and the record gates all rely on; without the fallback the
  pre-push hook would report offline on every push and provenance would be audited only
  in CI, halving the coverage this record is for.
- **Pass the token as `--gh-token <value>` on zizmor's command line.** judgment: argv is
  readable through `ps` by other processes of the same user, and the environment carries
  the same value to the same child without that exposure.
- **Widen the job's `permissions:` beyond `contents: read`.** verified: the online audits
  read other public repositories' refs and the public advisory database; `contents: read`
  on this repository is what makes `GITHUB_TOKEN` usable at all, and no documented zizmor
  audit requires a scope on this repository beyond it. A widened grant would be a real
  posture change bought for nothing.
- **Relax checkout's `persist-credentials: false`.** verified: that setting governs
  whether a credential is written into `.git/config` for later git commands; zizmor reads
  a token from the environment and never through git, so the stricter setting is
  untouched.
- **Make CI fail when the gate runs offline** — a `ZIZMOR_REQUIRE_ONLINE` switch set on
  the runner. judgment: it is a flag nobody asked for, and it converts a network blip on a
  runner into a red required check on an unrelated pull request. The residual it would
  cover — CI degrading silently if the token wiring is removed — is recorded in
  Consequences rather than engineered against, and the removal it guards would be a
  visible edit to `verify.yml` in a reviewed diff.
- **Pin zizmor's version so its mode flags cannot drift.** judgment: the whole gate tool
  set is installed unpinned from Homebrew by one step, and pinning one member of it is a
  different decision about a different problem.
- **Do nothing.** judgment: the audits the threat model credits do not run anywhere today,
  and the next pin bump is the one that would need them.
