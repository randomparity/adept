# 0036 — `actions-check` names the zizmor mode it ran and the condition that chose it

## Status

Accepted (2026-08-25)

## Context

`actions-check` runs `zizmor --offline .github/workflows/`, so the audits that need the
GitHub API never run. Measured rather than taken from the published table:
`zizmor --offline -vv --no-progress .github/workflows/` on this workstation (arm64 macOS,
Darwin 25.6.0, zizmor 1.29.0) logs `skipping <audit>: can't run without a GitHub API
token` for `impostor-commit`, `known-vulnerable-actions`, `ref-confusion`,
`stale-action-refs`, and `ref-version-mismatch`, and schedules everything else. Those five
are what a token buys. `typosquat-uses` runs offline and is not among them, and
<https://docs.zizmor.sh/audits/> does not list `ref-version-mismatch` as online-only, so
the binary is cited here in preference to the page.

Offline mode confirms a pin's *shape*; the five above are what confirm its *provenance*.
An impostor SHA borrowed from a fork is a well-formed pin. Five `uses:` pins are in the
tree; the next bump — a hand edit, or Dependabot once #236 lands — would be checked by
shape alone.

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

Three measurements then decide the shape of the fix. All are from this workstation, with
`--cache-dir` outside the worktree.

1. **A token is not connectivity.** `GH_TOKEN=<value> GH_HOST=github.invalid.example
   zizmor --no-progress .github/workflows/` gives `fatal: no audit was performed`, exit 1.
   Online mode does not degrade when the API is unreachable; it fails.
2. **A token does not decide the mode.** `zizmor --help` documents `--offline
   [env: ZIZMOR_OFFLINE=]` and `--no-online-audits [env: ZIZMOR_NO_ONLINE_AUDITS=]`; it
   prints no value enumeration for either. With `ZIZMOR_OFFLINE=true` a run carrying a
   valid token completes offline at exit 0 printing no `WARN`; with `ZIZMOR_OFFLINE=false`
   the same run goes online. The *value* is the instruction, not the variable's presence.
3. **An empty or non-boolean value is fatal, not ignorable.** `GH_TOKEN= zizmor --offline`
   exits 2 with `invalid value '' for '--gh-token': GitHub token cannot be empty` — the
   explicit `--offline` does not rescue it. `ZIZMOR_OFFLINE=` exits 2 with `a value is
   required`, and `ZIZMOR_OFFLINE=0` with `invalid value '0' for '--offline'` followed by
   `[possible values: true, false]`. That enumeration comes from clap's rejection path,
   which is where the accepted vocabulary is stated.

## Decision

**1. The gate reads every variable that decides the mode, in zizmor's own vocabulary, and
names the mode and the condition before the scan runs.** `actions-check` invokes
`scripts/run-zizmor.sh`, which resolves the mode as follows.

- `ZIZMOR_OFFLINE`, then `ZIZMOR_NO_ONLINE_AUDITS`: a value of `true` selects offline and
  is the reported condition. A value of `false` is not an offline instruction and falls
  through. Any other value, empty included, is one zizmor will reject, so the gate exits 2
  naming the variable and the values zizmor accepts rather than announcing a mode the run
  will never enter.
- Then `GH_TOKEN`, `GITHUB_TOKEN`, `ZIZMOR_GITHUB_TOKEN` — zizmor's documented order for
  `--gh-token`. The first with a non-empty value selects online and is the reported source.
- A token variable that is set but **empty** is removed from the child's environment. An
  empty string is not a token and carries no instruction, and leaving it in place makes
  zizmor exit 2 on a usage error after the gate has already announced a mode. Removing it
  is what makes "empty is not a token" true rather than merely asserted.
- Otherwise: offline, with the three token names reported as the condition.

The gate then prints one line, or two:

```
zizmor: online mode; API token from GH_TOKEN
zizmor: offline mode (--offline); ZIZMOR_OFFLINE=true
zizmor: offline mode (--offline); no API token: GH_TOKEN, GITHUB_TOKEN and
  ZIZMOR_GITHUB_TOKEN are all unset or empty
zizmor: pin provenance was NOT audited — ...
```

Three offline conditions, each with its own response — set `ZIZMOR_OFFLINE=false` or unset
it, likewise `ZIZMOR_NO_ONLINE_AUDITS`, or export a token — which is the discriminator ADR
0025 decision 2 requires where one observation has several causes calling for different
responses. The online line also names `GH_HOST` when set, since that decides which API an
online run talks to.

The online path carries a response too, and it is the path that matters most for one:
online mode is the only mode that can fail, and `actions-check` is in `verify`, which the
managed pre-push hook re-runs — so a developer on hotel wifi is blocked from pushing. When
zizmor exits non-zero in online mode the gate prints the remedy after it:

```
zizmor: the online audits failed; set ZIZMOR_OFFLINE=true to run the offline subset
```

That is a printf on a path already being handled, not a retry or a reachability probe.
zizmor's exit status is captured into a variable and re-raised, never piped and never
`|| true`.

**2. The offline path passes `--offline`, not `--no-online-audits`.** `--offline` forbids
all online operations; `--no-online-audits` is the documented weaker form that disables
connectivity-dependent audits while still permitting online operations. The requirement is
that the gate be green with no network at all, so the flag that states that as a property
of the run is the right one. The one thing `--no-online-audits` permits that `--offline`
does not — auditing a remote `user/repo` input — this gate never uses. `--offline` is also
the flag in the recipe today, so the offline invocation is unchanged and every audit that
passes now passes identically.

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

- Every run states its mode and the condition that chose it, so a reader of a green gate
  learns whether provenance was audited, and an operator who expected online mode learns
  which variable to change.
- CI audits provenance on both runners, on every pull request. A workstation does so only
  when someone exports a token; by default it runs the offline subset, says so, and stays
  green with no network. Coverage is one gate on the merge path rather than two — the
  price of keeping the local gate hermetic.
- **The required check now depends on state outside this repository.**
  `stale-action-refs`, `ref-version-mismatch`, and `known-vulnerable-actions` resolve
  against upstream repositories and the advisory database, so `verify` can newly fail on a
  re-run of an unchanged commit — a tag moved, an advisory published. That is the point of
  the audits, and it is also a way for an unrelated pull request to go red. Accepted.
- With a token exported the dependency is hard, not graceful: a failed API call gives
  `fatal: no audit was performed` and exit 1, in CI as much as locally. Accepted in both
  directions — nothing *fails* if the `GH_TOKEN` line is later removed either, since CI
  would print the offline condition and stay green, and the mode line is the whole
  mitigation.
- `GH_HOST` is ambient and zizmor honours it as `--gh-hostname`, so a developer configured
  for a GitHub Enterprise instance gets the same hard `fatal`. The online line names the
  host when set, so the message at least says where the run was pointed.
- The online line reports the mode the run was launched in, not that every audit reached
  the API; zizmor reports a per-audit online failure as a `WARN` in its own stream. Stated
  rather than engineered against.
- The gate never reads a token's value — it tests each variable for emptiness and lets
  zizmor read the values itself, so no credential passes through the script, its argv, or
  its output.
- Mode selection lives in a script rather than the recipe body, which brings it under
  `shellcheck`, `shfmt`, and a suite. It is a gate script under `scripts/`, so anatomy
  rules 1 and 2 do not bind it; rule 3 holds, as it runs and exits.

## Considered & rejected

- **Drop `--offline` and change nothing else** — the issue's literal proposal. verified: on
  this host, `env -u GH_TOKEN -u GITHUB_TOKEN -u ZIZMOR_GITHUB_TOKEN zizmor --no-progress
  .github/workflows/` exits 0 reporting `No findings to report`, preceded by ` WARN audit:
  zizmor: zizmor is running in offline mode by default`; the same command with a token, and
  `zizmor --offline`, print no such line. The `WARN` does distinguish an unaudited run, but
  it carries no condition, and it appears only in the tokenless default — never when
  `ZIZMOR_OFFLINE=true` sets the mode. A gate leaning on it would be silent in the case it
  most needs to speak.
- **Infer the mode from the token variables alone**, or from their presence rather than
  their value. verified: measurements 2 and 3 in Context. `ZIZMOR_OFFLINE=true` overrides a
  present token silently at exit 0, so the gate would print "online mode" over an unaudited
  run; `ZIZMOR_OFFLINE=false` is an *online* request that a presence test would report as
  the operator's own offline instruction. Both are the second-opinion drift this decision
  exists to avoid, and the second is the cause-not-carried-by-the-observation defect ADR
  0025 decision 2 forbids.
- **Unset `ZIZMOR_OFFLINE` and `ZIZMOR_NO_ONLINE_AUDITS` on the online path** (`env -u`)
  rather than reporting them. judgment: it silently overrides an operator who asked to stay
  offline — the same class of defect as the silent degrade this record closes. Removing an
  *empty* token variable is not this: an empty string carries no instruction to override.
  There is also no flag to assert online mode over them, since `zizmor --offline=false`
  errors with `unexpected value 'false' for '--offline'`.
- **Fall back to `gh auth token` when no variable is set**, so a workstation audits
  provenance without anyone exporting anything. verified: `gh auth token` returns from the
  keyring, so it reports a token on a machine with no network, and Context measurement 1
  shows what zizmor then does. Since every developer who can push here has an authenticated
  `gh`, the fallback would redden `just verify` and the pre-push hook for all of them
  whenever the API is unreachable — the outcome the fail-without-a-token alternative was
  rejected for causing, on a strictly larger set of machines. It also inherits `gh`'s
  configured host, which zizmor does not share.
- **Fail `actions-check` when no token is present.** verified: settled by the operator
  before design, and no other gate consults the network or a credential — scanning every
  gate script for one (`rg --no-config -e '\bgh\b|curl|wget|api\.github|GH_TOKEN|GITHUB_TOKEN|https?://' scripts/*.sh .github/scripts/check-records.sh`,
  on this branch) returns exactly one hit, the `gh[pousr]_` *pattern literal* inside
  `check-public-safety.sh`'s secret-detection list.
- **Use `--no-online-audits` on the offline path.** judgment: see Decision 2, which states
  the grounds and quotes `zizmor --help` for them.
- **Write the mode selection inline in the `actions-check` recipe.** verified:
  `scripts/list-shell-sources.sh` classifies a shell source by a `.sh` name or a bash
  shebang (`is_shell_source`, line 89), and `Justfile` is neither —
  `scripts/check-ripgrep-config.sh` documents the same blind spot for its own scan — so an
  inline branch would be unseen by `shellcheck` and `shfmt`. The `test` recipe discovers
  suites as tracked `*-test.sh` paths (`Justfile:188`), so it would also be untestable, and
  the reporting behaviour is the whole subject of this record.
- **Leave the CI posture knobs alone but reach for them if the audits complain** — widen
  `permissions:` past `contents: read`, or relax `persist-credentials: false`. verified for
  the first: the five online audits read *other* repositories' refs and the advisory
  database, none of which is a resource of this repository, so no permission on this
  repository could enable them. judgment for the second: `persist-credentials` governs a
  credential written into `.git/config` for this repository's remote, and zizmor
  authenticates to the API from the environment — nothing to gain, a stricter setting to
  lose.
- **Scope `GH_TOKEN` to a dedicated `actions-check` step** instead of the `Verify` step
  that runs the whole suite. judgment: the narrower blast radius is real, but buying it
  means running `actions-check` twice or splitting the guardrail recipe so CI invokes it in
  pieces — and `CLAUDE.md` requires CI to invoke the project's recipe rather than re-typed
  command strings, which a per-gate step would reintroduce. The exposure is not narrow: the
  token reaches every binary `just verify` runs, the unpinned npm-installed Claude CLI that
  `plugin-check` invokes included. What bounds it is `permissions: contents: read` and the
  token being read-only on a public repository, not the callees being first-party.
- **Run the online audits outside the required check** — a scheduled workflow, or a
  separate non-required job — so the merge gate stays offline and deterministic and the
  upstream-state residual above disappears. judgment: a provenance finding that arrives
  after the merge is a bad pin already on `main`, which is the thing the audit exists to
  prevent; catching it at the bump is the whole point of putting it on the gate. A
  non-required job is also one people learn to ignore. The residual is preferred to that
  latency, deliberately.
- **Make CI fail when the gate runs offline**, or **probe reachability and retry** so a
  token plus a dead API degrades instead of failing. judgment: the first is a flag nobody
  asked for, guarding a removal that would be a visible edit to `verify.yml` in a reviewed
  diff; the second re-introduces the judgement call — how many retries, how long a timeout
  — that a hard failure states plainly. Both residuals are recorded in Consequences
  instead.
- **Do nothing.** judgment: the five audits the threat model credits run nowhere today, and
  the next pin bump is the one that would need them.
