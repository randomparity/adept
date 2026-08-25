# 0036 — `actions-check` names the zizmor mode it ran and the condition that chose it

## Status

Accepted (2026-08-25)

## Context

`actions-check` runs `zizmor --offline .github/workflows/`. Offline mode disables the
audits that check a pin's *provenance* — per <https://docs.zizmor.sh/audits/>, the audits
marked "Works offline: ❌" are `impostor-commit`, `known-vulnerable-actions`,
`ref-confusion`, and `typosquat-uses`. Offline mode confirms a pin's *shape* and nothing
else, so an impostor SHA borrowed from a fork is a well-formed pin. Five `uses:` pins are
in the tree; the next bump — a hand edit, or Dependabot once #236 lands — would be checked
by shape alone.

Issue #239 proposes dropping `--offline` so zizmor uses the API when a token is present.
That leaves the mode unreported: zizmor announces a tokenless degrade only as a `WARN`
inside its own log stream, and the gate adds nothing, so a reader learns the mode by
knowing zizmor's log conventions and learns the condition that chose it not at all — the
discrimination [ADR 0025](0025-a-skip-reports-the-condition-not-the-cause.md) decision 2
requires a degrade to carry.

The operator settled the one design-changing question before this record was written: a
machine with no token degrades to the offline subset and stays green, because no other
gate here requires network or credentials. Failing without a token was considered and
explicitly rejected.

Two measurements on this workstation (arm64 macOS 25.6.0, zizmor 1.29.0) then decide the
shape of the fix.

**A token is not connectivity.** With a token present and the API unreachable, zizmor does
not fall back to the offline subset — `GH_TOKEN=<value> GH_HOST=github.invalid.example
zizmor --no-progress .github/workflows/` gives `fatal: no audit was performed`,
`'artipacked' audit failed`, exit 1. So any design that makes online mode the *ambient*
local default turns `just verify` red on a plane, during an API incident, and the morning
a token expires.

**A token does not decide the mode by itself.** `zizmor --help` documents two further mode
controls under the same Network Options heading: `--offline [env: ZIZMOR_OFFLINE=]` and
`--no-online-audits [env: ZIZMOR_NO_ONLINE_AUDITS=]`. With either exported, a run carrying
a valid token completes offline, exit 0, printing no `WARN` at all — verified with
`GH_TOKEN=<value> ZIZMOR_OFFLINE=true zizmor --no-progress .github/workflows/` and the
same with `ZIZMOR_NO_ONLINE_AUDITS=true`. A gate that inferred its mode from the token
alone would therefore print "online mode" over an unaudited run: worse than today, because
today the run is merely unaudited and afterwards it would be unaudited and labelled
audited.

## Decision

**1. The mode is read from all five variables that decide it, and the gate names the mode
and the condition before the scan runs.** `actions-check` invokes
`scripts/run-zizmor.sh`, which tests, in order: `ZIZMOR_OFFLINE`,
`ZIZMOR_NO_ONLINE_AUDITS`, then `GH_TOKEN`, `GITHUB_TOKEN`, `ZIZMOR_GITHUB_TOKEN` — the
three token names in zizmor's own documented order. An empty value is not a value. The two
mode variables outrank the token because they are an explicit instruction about the mode;
a token merely makes online mode possible. There is no fallback to a credential store.

The gate then prints one line, or two:

```
zizmor: online mode; API token from GH_TOKEN
zizmor: offline mode (--offline); ZIZMOR_OFFLINE is set
zizmor: offline mode (--offline); no API token: GH_TOKEN, GITHUB_TOKEN and
  ZIZMOR_GITHUB_TOKEN are all unset or empty
zizmor: pin provenance was NOT audited — ...
```

Three offline conditions, each with its own response — unset `ZIZMOR_OFFLINE`, unset
`ZIZMOR_NO_ONLINE_AUDITS`, or export a token — which is exactly the discriminator ADR 0025
decision 2 requires where one observation has several causes calling for different
responses. The online line also names `GH_HOST` when it is set, because that variable
decides *which* API an online run talks to. zizmor's exit status is captured into a
variable and re-raised, never piped and never `|| true`.

Exporting a token is a deliberate act, which is what makes it a sound mode selector: the
person who exports one has asked for online mode and its network dependency. An ambient
source — reading `gh`'s keyring — would impose that dependency on every developer who
never chose it.

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
widened and checkout's `persist-credentials: false` is **not** relaxed. The
security-posture change is therefore that the token's *value* becomes visible to the
`just ci` step, not that any permission grows. On a fork pull request GitHub makes
`GITHUB_TOKEN` read-only, so the most a compromised gate script obtains is authenticated
read access to a public repository — content the same actor can already read
unauthenticated, at a lower rate limit.

## Consequences

- Every `actions-check` run states its mode and the condition that chose it, so a reader
  of a green gate learns whether provenance was audited without knowing zizmor's defaults,
  and an operator who wanted online mode and got offline learns which variable to change.
- CI audits provenance on both runners, on every pull request. That is where a bad pin is
  caught before merge.
- A workstation audits provenance only when someone exports a token. By default it runs
  the offline subset and says so, and stays green with no network, exactly as today.
  Coverage is one gate on the merge path rather than two — the price of keeping the local
  gate hermetic.
- With a token exported the dependency is hard, not graceful: a failed API call gives
  `fatal: no audit was performed` and exit 1. That applies to CI too, so an API outage or
  a revoked token can redden the required `verify` check for a reason unrelated to the
  pull request, reporting a `fatal:` that names an audit rather than the network. Accepted
  in both directions: nothing *fails* if the `GH_TOKEN` line is later removed either — CI
  would print the offline condition and stay green, and the mode line is the whole
  mitigation.
- `GH_HOST` is ambient and zizmor honours it as `--gh-hostname`. A developer with `GH_HOST`
  exported for a GitHub Enterprise instance and a token for it gets the same hard `fatal`
  from `just verify`. The online line names the host when it is set, so the message that
  failed at least says where the run was pointed.
- The online line reports the mode the run was launched in, not that every online audit
  reached the API. zizmor reports a per-audit online failure as a `WARN` in its own
  stream, so a run can announce online mode, warn in the middle, and finish green. Stated
  rather than engineered against; a post-scan verification step would cost more than the
  residual is worth.
- The gate never reads a token's value. The five variables are ones zizmor already
  consults, so the script tests each for emptiness and lets zizmor read the values itself
  — no credential passes through the script, its argv, or its output.
- Mode selection lives in a script rather than the recipe body, which brings it under
  `shellcheck`, `shfmt`, and a suite. It is a gate script under `scripts/`, so anatomy
  rules 1 and 2 do not bind it; rule 3 holds, as it runs and exits.

## Considered & rejected

- **Drop `--offline` and change nothing else** — the issue's literal proposal. verified: on
  this host, `env -u GH_TOKEN -u GITHUB_TOKEN -u ZIZMOR_GITHUB_TOKEN zizmor --no-progress
  .github/workflows/` exits 0 reporting `No findings to report`, preceded by ` WARN audit:
  zizmor: zizmor is running in offline mode by default`; the same command with a token, and
  `zizmor --offline`, print no such line. So the `WARN` does distinguish an unaudited run —
  what it does not carry is the condition that chose the mode, and it appears only in the
  tokenless default case, never when `ZIZMOR_OFFLINE` or `ZIZMOR_NO_ONLINE_AUDITS` sets the
  mode explicitly (both verified above). A gate leaning on it would be silent in exactly
  the case it most needs to speak.
- **Select the mode from the token variables alone.** verified: the two mode variables
  above override a present token, silently and with exit 0, so the gate would print "online
  mode" over a run that audited no provenance. Reading three of the five variables that
  decide the mode is a second opinion that drifts from zizmor's.
- **Unset `ZIZMOR_OFFLINE` and `ZIZMOR_NO_ONLINE_AUDITS` on the online path** (`env -u`)
  rather than reporting them. judgment: it silently overrides an operator who asked to stay
  offline, which is the same class of defect as the silent degrade this record closes.
  There is also no flag to assert online mode over them — `zizmor --offline=false` errors
  with `unexpected value 'false' for '--offline'` — so reporting is the honest option.
- **Fall back to `gh auth token` when no variable is set**, so a workstation audits
  provenance without anyone exporting anything. verified: `gh auth token` returns from the
  keyring, so it reports a token on a machine with no network; zizmor handed a token it
  cannot use exits 1 (the `fatal: no audit was performed` measurement in Context). Since
  every developer who can push here has an authenticated `gh`, the fallback would redden
  `just verify` and the pre-push hook for all of them whenever the API is unreachable — the
  outcome the fail-without-a-token alternative was rejected for causing, on a strictly
  larger set of machines. It also inherits `gh`'s configured host, which zizmor does not
  share: `gh auth token` without `--hostname` selects `gh`'s default host while zizmor
  defaults to `--gh-hostname github.com`.
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
- **Report only "offline" without the condition.** judgment: with three causes calling for
  three different responses, a bare "offline" leaves an operator unable to tell which one
  applies — the discrimination ADR 0025 decision 2 exists to require.
- **Write the mode selection inline in the `actions-check` recipe.** verified:
  `scripts/list-shell-sources.sh` classifies a tracked file as a shell source by a `.sh`
  name or a bash shebang (`is_shell_source`, line 89, with the `*.sh` case at line 92), and
  `Justfile` is neither — `scripts/check-ripgrep-config.sh` documents the same blind spot
  for its own scan — so an inline branch would be unseen by `shellcheck` and `shfmt`. The
  `test` recipe discovers suites as tracked `*-test.sh` paths (`git ls-files -z --
  '*-test.sh'`, `Justfile:188`), so an inline branch is also untestable, and the reporting
  behaviour is the whole subject of this record.
- **Restrict online mode to CI by detecting the runner** (a `$CI` or `$GITHUB_ACTIONS`
  test). judgment: an exported token is a clearer opt-in than sniffing for a runner, it
  keeps one code path, and it lets a developer reproduce CI's mode by exporting the same
  variable CI sets.
- **Read the token's value and pass `--gh-token <value>`, or re-export it.** judgment:
  unnecessary once the sources are variables zizmor reads itself, and strictly worse — argv
  is readable through `ps` by other processes of the same user, and any handling at all
  puts a credential somewhere it can be printed by mistake.
- **Scope `GH_TOKEN` to a dedicated `actions-check` step** instead of the `Verify` step
  that runs the whole suite. judgment: the narrower blast radius is real, but buying it
  means either running `actions-check` twice or splitting the guardrail recipe so CI
  invokes it in pieces — and `CLAUDE.md` requires CI to invoke the project's recipe rather
  than re-typed command strings, which a per-gate step would reintroduce. The exposure is a
  read-only token on a public repository, to first-party reviewed code.
- **Widen the job's `permissions:` beyond `contents: read`.** verified: the four online
  audits named in Context read *other* repositories' refs and the GitHub Advisories
  database (<https://docs.zizmor.sh/audits/>), none of which is a resource of this
  repository, so no permission on this repository could enable them. `permissions:` is
  therefore left exactly as it is.
- **Relax checkout's `persist-credentials: false`.** judgment: that setting governs whether
  a credential for *this* repository's remote is written into `.git/config`; zizmor
  authenticates to the GitHub API from the environment, so nothing it does reads that
  credential. Nothing to gain, a stricter setting to lose.
- **Make CI fail when the gate runs offline** — a `ZIZMOR_REQUIRE_ONLINE` switch set on the
  runner. judgment: a flag nobody asked for, guarding a removal that would be a visible edit
  to `verify.yml` in a reviewed diff. The residual it would cover is recorded in
  Consequences instead.
- **Add a reachability probe or a retry around the online run** so a token plus a dead API
  degrades instead of failing. judgment: it grows the design past what this decision
  governs, and re-introduces the judgement call — how many retries, how long a timeout —
  that a hard failure states plainly.
- **Pin zizmor's version so its mode flags cannot drift.** judgment: the whole gate tool set
  is installed unpinned from Homebrew by one step, and pinning one member is a different
  decision about a different problem.
- **Do nothing.** judgment: the audits the threat model credits do not run anywhere today,
  and the next pin bump is the one that would need them.
