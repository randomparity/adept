# 0036 — `actions-check` names the zizmor mode it ran and the condition that chose it

## Status

Accepted (2026-08-25)

## Context

`actions-check` runs `zizmor --offline .github/workflows/`. Offline mode disables every
audit that needs the GitHub API, and those include the audits that check a pin's
provenance: whether the 40-character SHA a `uses:` names is reachable in the repository it
names, and whether the pinned revision is covered by a known advisory. Offline mode
confirms a pin's *shape* and nothing else, so an impostor SHA borrowed from a fork is a
well-formed pin. Five `uses:` pins are in the tree; the next bump — a hand edit, or
Dependabot once #236 lands — would be checked by shape alone.

Issue #239 proposes dropping `--offline` so zizmor uses the API when a token is present.
Measured on this workstation (arm64 macOS 25.6.0, zizmor 1.29.0), that alone is a poor
fix: `env -u GH_TOKEN -u GITHUB_TOKEN -u ZIZMOR_GITHUB_TOKEN zizmor --no-progress
.github/workflows/` exits 0 having audited nothing online, and announces the degrade only
as a `WARN` line inside the tool's own log stream, among its `INFO` lines. The gate itself
adds nothing, so a reader learns the mode only by knowing zizmor's log conventions, and
learns *why* it chose that mode not at all — which is the discrimination
[ADR 0025](0025-a-skip-reports-the-condition-not-the-cause.md) decision 2 requires a
degrade to carry.

The operator settled the one design-changing question before this record was written: a
machine with no token degrades to the offline subset and stays green, because no other
gate here requires network or credentials. Failing without a token was considered and
explicitly rejected.

What the issue does not settle, and what decides the shape of the fix, is that **a token
is not connectivity**. Reproduced on this host: with a token present and the API
unreachable, zizmor does not fall back to the offline subset — it exits 1 with `fatal: no
audit was performed`. Any design that makes online mode the *ambient* local default
therefore turns `just verify` red on a plane, in a tunnel, during a GitHub API incident,
and the morning a token expires.

## Decision

**1. Mode is selected from an explicitly exported token, and the gate names the mode and
the condition before the scan runs.** `actions-check` invokes `scripts/run-zizmor.sh`,
which consults exactly the three variables zizmor itself documents for `--gh-token`, in
zizmor's own order — `GH_TOKEN`, `GITHUB_TOKEN`, `ZIZMOR_GITHUB_TOKEN` (`zizmor --help`,
Network Options). An empty value is not a token. There is no fallback to a credential
store. It then prints one line, or two:

```
zizmor: online mode; API token from GH_TOKEN
zizmor: offline mode (--offline); no API token: GH_TOKEN, GITHUB_TOKEN and
  ZIZMOR_GITHUB_TOKEN are all unset or empty
zizmor: pin provenance was NOT audited — ...
```

Reading the same three names in the same order means the mode the gate announces is the
mode zizmor would have chosen, rather than a second opinion that can drift from it. The
offline condition names one observation with one response — export a token — so ADR 0025
decision 2's requirement to carry a discriminator does not arise: that clause applies
where a condition has several causes calling for different responses, and this one does
not. zizmor's exit status is captured into a variable and re-raised, never piped and never
`|| true`.

Exporting a token is a deliberate act, which is what makes it a sound mode selector: the
person who exports one has asked for online mode and for its network dependency. An
ambient source — reading `gh`'s keyring — would impose that dependency on every developer
who never chose it, which is the failure the Context measures.

**2. The tokenless path passes `--offline`, not `--no-online-audits`.** `--offline`
forbids all online operations; `--no-online-audits` is the documented weaker form that
disables connectivity-dependent audits while still permitting online operations. The
requirement is that the gate be green with no network at all, so the flag that states that
as a property of the run is the right one. The one thing `--no-online-audits` permits that
`--offline` does not — auditing a remote `user/repo` input — this gate never uses; its
only input is the local `.github/workflows/` directory. `--offline` is also the flag in
the recipe today, so the offline invocation is unchanged and every audit that passes now
passes identically.

**3. CI receives a token, at the permission it already has.** The `Verify` step in
`.github/workflows/verify.yml` gains `GH_TOKEN: ${{ github.token }}` in its existing
`env:` block. CI is where connectivity is assured and where the required check lives, so
it is where the online audits belong. The job's `permissions: contents: read` is **not**
widened and checkout's `persist-credentials: false` is **not** relaxed: the online audits
read public repositories' refs and the public advisory database, and `contents: read` on
this repository is the floor a usable `GITHUB_TOKEN` needs for that. The security-posture
change is therefore that the token's *value* becomes visible to the `just ci` step, not
that any permission grows. On a fork pull request GitHub makes `GITHUB_TOKEN` read-only
regardless of the `permissions:` block, so the most a compromised gate script obtains is
authenticated read access to a public repository — content the same actor can already read
unauthenticated, at a lower rate limit.

## Consequences

- Every `actions-check` run states its mode, so a reader of a green gate learns whether
  provenance was audited without knowing zizmor's defaults.
- CI audits provenance on both runners, on every pull request. That is where a bad pin is
  caught before merge.
- A workstation audits provenance only when someone exports a token. By default it runs
  the offline subset and says so, twice. Provenance coverage is therefore CI's, and the
  pre-push hook does not duplicate it — the coverage this record buys is one gate on the
  merge path, not two.
- `just verify` gains no ambient dependency on network or credentials: with no token
  exported it is green with no network, exactly as today. The dependency arrives only with
  an exported token, and then it is hard rather than graceful — verified on this host, a
  token plus an unreachable API gives `fatal: no audit was performed` and exit 1, not a
  degrade to offline. A developer who exports `GH_TOKEN` in a shell profile has opted into
  a gate that reddens offline; the remedy is to unset it, and the offline line then says
  so.
- Residual, both directions. Nothing *fails* when CI degrades to offline: if the
  `GH_TOKEN` line is removed or `github.token` stops resolving, CI prints the offline
  condition and stays green, and the mode line is the whole mitigation — a log line,
  weaker than a red check. In the other direction, with the token wired an API outage or a
  revoked token fails `actions-check` hard, so the required `verify` check can redden for
  a reason unrelated to the pull request, reporting a `fatal:` that names an audit rather
  than the network.
- The online line reports the token the script found, not that every online audit reached
  the API. zizmor reports a per-audit online failure as a `WARN` in its own stream, so a
  run can announce online mode, warn in the middle, and still finish green — the record's
  own subject one level up. Stated here rather than engineered against; a post-scan
  verification step would cost more than the residual is worth.
- The gate never reads the token's value. Because the three sources are exactly the
  variables zizmor already consults, the script tests only whether each is non-empty and
  lets zizmor read the value itself — so no credential passes through the script, appears
  in its argv, or can reach its output. Beyond that this decision trusts zizmor with a
  credential its `--gh-token` interface exists to receive; a malicious zizmor release is
  not addressed here, and the tool is installed unpinned from Homebrew alongside every
  other gate tool.
- Mode selection lives in a script rather than in the recipe body, which brings it under
  `shellcheck`, `shfmt`, and a suite. It is a gate script under `scripts/`, so anatomy
  rules 1 and 2 do not bind it; rule 3 holds, as it runs and exits.

## Considered & rejected

- **Drop `--offline` and change nothing else** — the issue's literal proposal. verified:
  on this host, `env -u GH_TOKEN -u GITHUB_TOKEN -u ZIZMOR_GITHUB_TOKEN zizmor
  --no-progress .github/workflows/` exits 0 reporting `No findings to report`, preceded by
  ` WARN audit: zizmor: zizmor is running in offline mode by default`; the same command
  with a token, and `zizmor --offline`, both print no such line. So the WARN does
  distinguish an unaudited run — what it does not carry is the condition that chose the
  mode, and it sits on stderr among `INFO` lines with nothing from the gate itself. A
  reader learns the mode only by knowing zizmor's log conventions and learns the condition
  not at all, which is what ADR 0025 decision 2 asks a degrade line to supply.
- **Fall back to `gh auth token` when no variable is set**, so a workstation audits
  provenance without anyone exporting anything. verified: `gh auth token` is a keyring read
  that contacts nothing, so it reports a token on a machine with no network; zizmor handed
  a token it cannot use then exits 1 — `GH_TOKEN="$(gh auth token)" GH_HOST=github.invalid.example zizmor --no-progress .github/workflows/`
  gives `fatal: no audit was performed`, `'artipacked' audit failed`, exit 1 (arm64 macOS,
  zizmor 1.29.0). Since every developer who can push here has an authenticated `gh`, the
  fallback would redden `just verify` and the pre-push hook for all of them whenever the
  API is unreachable — the outcome the fail-without-a-token alternative was rejected for
  causing, on a strictly larger set of machines. It also inherits `gh`'s configured host:
  `gh auth token` without `--hostname` selects the default host, while zizmor defaults to
  `--gh-hostname github.com`, so a developer configured for a GitHub Enterprise instance
  would hand over a token that 401s into the same hard `fatal`.
- **Fail `actions-check` when no token is present.** verified: the operator settled this
  before design. No other gate consults the network or a credential — scanning every gate
  script for one (`rg --no-config -e '\bgh\b|curl|wget|api\.github|GH_TOKEN|GITHUB_TOKEN|https?://' scripts/*.sh .github/scripts/check-records.sh`,
  on this branch) returns exactly one hit, and it is the `gh[pousr]_` *pattern literal*
  inside `check-public-safety.sh`'s secret-detection list, not a call. A gate that reddens
  on a plane is a gate people learn to skip.
- **Use `--no-online-audits` on the tokenless path.** verified: `zizmor --help` (1.29.0)
  describes it as "a weaker version of `--offline`: instead of completely forbidding all
  online operations, it only disables audits that require connectivity." Its one added
  capability is auditing a remote `user/repo` input, which this gate never passes.
- **Report only "offline" without the condition.** judgment: an operator reading it cannot
  tell whether the gate found no token or was told to stay offline, which is the
  discrimination ADR 0025 decision 2 requires a degrade line to carry.
- **Write the mode selection inline in the `actions-check` recipe.** verified:
  `scripts/list-shell-sources.sh` classifies a tracked file as a shell source by a `.sh`
  name or a bash shebang (`is_shell_source`, line 92), and `Justfile` is neither —
  `scripts/check-ripgrep-config.sh` documents the same blind spot for its own scan — so an
  inline branch would be unseen by `shellcheck` and `shfmt`. The `test` recipe discovers
  suites as tracked `*-test.sh` paths (`git ls-files -z -- '*-test.sh'`, `Justfile:188`),
  so an inline branch is also untestable, and the reporting behaviour is the whole subject
  of this record.
- **Restrict online mode to CI by detecting the runner** (a `$CI` or `$GITHUB_ACTIONS`
  test) rather than by token presence. judgment: an exported token is a clearer and more
  honest opt-in signal than sniffing the environment for a runner, it keeps one code path
  instead of two, and it lets a developer reproduce CI's mode locally by exporting the
  same variable CI sets.
- **Read the token's value and pass it as `--gh-token <value>`, or re-export it.**
  judgment: unnecessary once the sources are exactly the three variables zizmor reads
  itself, and strictly worse — argv is readable through `ps` by other processes of the
  same user, and any handling at all puts a credential somewhere it can be printed by
  mistake. Testing the variables for emptiness needs no value.
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
  the runner. judgment: a flag nobody asked for, guarding a removal that would be a visible
  edit to `verify.yml` in a reviewed diff. The residual it would cover is recorded in
  Consequences instead.
- **Add a reachability probe or a retry around the online run** so a token plus a dead API
  degrades to offline instead of failing. judgment: it grows the design well past what this
  decision governs, and it re-introduces the judgement call — how many retries, how long a
  timeout — that a hard failure states plainly.
- **Pin zizmor's version so its mode flags cannot drift.** judgment: the whole gate tool
  set is installed unpinned from Homebrew by one step, and pinning one member of it is a
  different decision about a different problem.
- **Do nothing.** judgment: the audits the threat model credits do not run anywhere today,
  and the next pin bump is the one that would need them.
