# 0036 — `actions-check` names the zizmor mode it ran and the condition that chose it

## Status

Accepted (2026-08-25)

> **The 1.29.0 measurement is enforced by [ADR 0044](0044-the-zizmor-gate-admits-one-version.md) (2026-08-27).**

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
3. **An empty or non-boolean value is rejected — but only where zizmor still parses the
   variable.** `GH_TOKEN= zizmor --offline` exits 2 with `invalid value '' for
   '--gh-token': GitHub token cannot be empty`, and the explicit `--offline` does not
   rescue it. A malformed `ZIZMOR_NO_ONLINE_AUDITS` is likewise fatal with `--offline` on
   argv. A malformed `ZIZMOR_OFFLINE` is **not**: an explicit `--offline` shadows the
   variable, so `ZIZMOR_OFFLINE=0 zizmor --offline .github/workflows/` exits 0, while the
   same value with no flag exits 2 with `invalid value '0' for '--offline'` and
   `[possible values: true, false]`. That enumeration comes from clap's rejection path,
   not from `--help`.
4. **A findings exit is distinct from a failure exit.** Measured: 0 clean, 1 the run
   failed, 2 usage error, 3 a workflow that would not parse, and **14** for a run that
   completes and reports findings — `zizmor --no-progress --offline` against a throwaway
   workflow with an unpinned `uses:` and a `${{ }}` interpolation in `run:` reported
   `7 findings ... 2 medium, 2 high` at exit 14. The list is "at least these", not an
   enumeration of zizmor's whole status space, and only the 1-versus-14 split is
   load-bearing: a gate that keys on "non-zero" cannot tell a finding from a failure.
   Status 1 itself carries no cause — an unreachable API, a rejected token,
   `invalid input: <path>` for a missing directory, and an unloadable `zizmor.yml` all
   land there.

## Decision

**1. The gate reads every variable that decides the mode, in zizmor's own vocabulary, and
names the mode and the condition before the scan runs.** `actions-check` invokes
`scripts/run-zizmor.sh`, which resolves the mode as follows.

- `ZIZMOR_OFFLINE`, then `ZIZMOR_NO_ONLINE_AUDITS`: a value of `true` selects offline and
  is the reported condition. A value of `false` is not an offline instruction and falls
  through. **Any other value, empty included, selects nothing**: the gate prints a warning
  naming the variable and the values zizmor accepts, and falls through to the token check,
  leaving zizmor's own parser to accept or reject it. The gate does not exit on it,
  because whether the value is fatal depends on which flag ends up on argv (measurement 3)
  — and a gate that refused where zizmor would have run is the second opinion this
  decision exists to avoid. It is also what keeps `ZIZMOR_OFFLINE=1` green on the offline
  path, where it is green today.

  Measurement 3's shadowing applies to `ZIZMOR_OFFLINE` alone. Nothing shadows
  `--no-online-audits`, so a malformed `ZIZMOR_NO_ONLINE_AUDITS` still makes zizmor exit 2
  after the gate has printed its warning and its mode line. The warning therefore says the
  value "selects no mode here, and zizmor may still reject it" rather than claiming the
  gate ignored it — ignoring is not an outcome this gate controls for that variable, and
  one wording true of both beats a per-variable branch for the sake of one word.
- Then `GH_TOKEN`, `GITHUB_TOKEN`, `ZIZMOR_GITHUB_TOKEN` — zizmor's documented order for
  `--gh-token`. The first with a non-empty value selects online and is the reported source.
- A token variable that is set but **empty** is removed from the child's environment. An
  empty string is not a token and carries no instruction, and leaving it in place makes
  zizmor exit 2 on a usage error after the gate has already announced a mode. Removing it
  is what makes "empty is not a token" true rather than merely asserted.
- Otherwise: offline, with the three token names reported as the condition.

The gate then prints one line, or two:

```
run-zizmor: online mode; API token from GH_TOKEN
run-zizmor: offline mode (--offline); ZIZMOR_OFFLINE=true
run-zizmor: offline mode (--offline); no API token: GH_TOKEN, GITHUB_TOKEN and
  ZIZMOR_GITHUB_TOKEN are all unset or empty
run-zizmor: pin provenance was NOT audited: ...
```

Three offline conditions, each with its own response — set `ZIZMOR_OFFLINE=false` or unset
it, likewise `ZIZMOR_NO_ONLINE_AUDITS`, or export a token — which is the discriminator ADR
0025 decision 2 requires where one observation has several causes calling for different
responses. The online line also names `GH_HOST` when set, since that decides which API an
online run talks to.

The online path carries a response too, and it is the path that matters most for one:
online mode is the only mode that can fail, and `actions-check` is in `verify`, which the
managed pre-push hook re-runs — so a developer on hotel wifi is blocked from pushing. When
an online run exits with zizmor's **tool-failure** status the gate prints the remedy after
it:

```
run-zizmor: the audit run failed rather than reporting findings; zizmor own error is
  above. If it is an API or token fault, a local offline run is ZIZMOR_OFFLINE=true
```

**Keyed on tool failure alone — status 1 — never on "non-zero".** Measurement 4 is why:
findings exit 14, and a hint offered there would tell a developer to switch off the audit
that just caught something, which is a documented route to a green gate over an unaudited
pin. A usage error (2) is not offered it either, because the offline subset does not fix a
malformed variable. If a future zizmor renumbers its statuses the hint stops appearing,
which is the safe direction to fail: a missing hint costs a reader nothing, a misapplied
one costs an audit.

That is a printf on a path already being handled, not a retry or a reachability probe.
zizmor's exit status is captured into a variable and re-raised unchanged, never piped and
never `|| true`; the hint does not alter it.

A `true` `ZIZMOR_NO_ONLINE_AUDITS` is executed as `--offline`, which is the *stronger* of
the two controls the operator asked for. The mode line discloses the substitution — it
names the variable that chose the mode next to the flag that was passed — and the two are
equivalent for this gate, because the sole capability `--no-online-audits` has over
`--offline` is auditing a remote `user/repo` slug and this gate's only input is a local
directory. Worth stating rather than leaving to a reader to notice, since a future change
that let the gate take a remote input would make the difference behavioural.

**2. The offline path passes `--offline`, not `--no-online-audits`.** `--offline` forbids
all online operations; `--no-online-audits` is the documented weaker form that disables
connectivity-dependent audits while still permitting online operations. The requirement is
that the gate be green with no network at all, so the flag that states that as a property
of the run is the right one. The one thing `--no-online-audits` permits that `--offline`
does not — auditing a remote `user/repo` input — this gate never uses. `--offline` is also
the flag in the recipe today, so the offline invocation is unchanged and every audit that
passes now passes identically.

**3. CI receives a token, at the permission it already has, and fails closed without one.**
The `Verify` step in `.github/workflows/verify.yml` gains `GH_TOKEN: ${{ github.token }}`
in its existing `env:` block, plus a guard ahead of `just ci` that exits 1 when that
variable is unset or empty. CI is where connectivity is assured and where the required
check lives, so it is where the online audits belong — and because a workstation is
offline by default, CI is the *only* place they run, which is why the precondition is
asserted rather than assumed. The guard has two arms because an unset variable and an
empty one call for opposite fixes: unset means the `env:` wiring is gone and the repair is
in this file, empty means `github.token` itself resolved empty and the repair is in
repository or organization settings. It re-types no gate command; `just ci` is still the
recipe. The job's `permissions: contents: read` is **not**
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
  `fatal: no audit was performed` and exit 1, in CI as much as locally.
- **CI fails rather than degrading when its token is empty.** The `Verify` step asserts
  `GH_TOKEN` is non-empty before `just ci`. Without it, a `github.token` that resolved
  empty — a repository or organization setting, a platform change, or the `env:` line lost
  in a conflict resolution — would put the runner on the offline path, print the
  no-token condition, and exit 0: the required check green with the five audits running
  nowhere, since a workstation is offline by default. That is this record's own subject one
  level up, and a log line is too weak a mitigation for it. Deliberate removal of the
  wiring stays visible in a reviewed diff; the guard covers the silent case, which is the
  one a diff does not show.
- `GH_HOST` is ambient and zizmor honours it as `--gh-hostname`, so a developer configured
  for a GitHub Enterprise instance gets the same hard `fatal`. The online line names the
  host, so the destination is stated before the scan rather than only inside a failure's
  causal chain — which does name it, contrary to a weaker claim an earlier draft made: the
  headline names the audit, the chain names the URL.
- The online line reports the mode the run was launched in, not that every audit reached
  the API; zizmor reports a per-audit online failure as a `WARN` in its own stream. Stated
  rather than engineered against.
- **A token pulls more than the five online-only audits onto the network.** With
  `GH_HOST` pointed at an unresolvable host, the audit that failed was `artipacked`, which
  runs offline and is not among the five. So the five are what a token buys, not the limit
  of what an unreachable API can break.
- The gate never reads a token's value — it tests each variable for emptiness and lets
  zizmor read the values itself, so no credential passes through the script, its argv, or
  its output.
- **A non-boolean mode variable is inert offline and fatal online.** `ZIZMOR_OFFLINE=1` is
  green today, because the recipe's explicit `--offline` shadows it. It stays green on the
  offline path here for the same reason. On the *online* path no flag is passed, so
  nothing shadows it and zizmor exits 2 with `invalid value '1' for '--offline'` — after
  the gate has announced online mode, and with no hint, since status 2 is excluded from
  it. Reaching it takes a malformed mode variable and an exported token on the same
  machine; the gate's warning names the variable and zizmor's error names the accepted
  values, so it is diagnosable rather than mysterious. Accepted as a narrow regression
  against "everything running today keeps running unchanged".
- **Every fact above about zizmor's CLI was measured on 1.29.0, and CI installs zizmor
  unpinned** from Homebrew alongside the other gate tools. The variable names, the
  `true`/`false` vocabulary, and the exit statuses are therefore a contract with one
  observed version, not a version-independent one — and the two renames fail in opposite
  directions. Renaming a **token** variable is self-consistent: the gate finds no token,
  reports offline, and runs offline. Renaming a **mode** variable is the dangerous one and
  it is silent: the gate would read the old name, find nothing, see a token, print "online
  mode", and pass no flag, while an operator who set the *new* variable to `true` gets an
  offline run at exit 0 with no `WARN` — unaudited and labelled audited, the state this
  change exists to remove. Pinning the tool set is a separate decision (rejected below);
  this residual is recorded rather than engineered against, and the suite pins the gate's
  own behaviour against a stub, not against zizmor.
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
  provenance without anyone exporting anything. verified: `gh auth token` needs no network
  — behind a dead proxy (`HTTPS_PROXY=http://127.0.0.1:1 HTTP_PROXY=http://127.0.0.1:1
  ALL_PROXY=http://127.0.0.1:1 gh auth token`) it still exits 0 returning a 40-character
  token — so it reports a token on a machine that cannot reach the API, and Context
  measurement 1 shows what zizmor then does with one. Since every developer who can push here has an authenticated
  `gh`, the fallback would redden `just verify` and the pre-push hook for all of them
  whenever the API is unreachable — the outcome the fail-without-a-token alternative was
  rejected for causing, on a strictly larger set of machines. It also inherits `gh`'s
  configured host, which zizmor does not share.
- **Fail `actions-check` when no token is present.** verified: settled by the operator
  before design, and no gate other than the one this change adds consults the network or a
  credential. Scanning the gate scripts that predate this change —
  `rg --no-config -e '\bgh\b|curl|wget|api\.github|GH_TOKEN|GITHUB_TOKEN|https?://' scripts/check-*.sh scripts/list-shell-sources.sh scripts/verify-push.sh scripts/test-fixture-helpers.sh .github/scripts/check-records.sh`
  — returns exactly one line, the `gh[pousr]_` *pattern literal* at
  `check-public-safety.sh:42`, which is a secret-detection pattern rather than a call. The
  same result comes from `scripts/*.sh` on `main`; on this branch that wider glob also
  matches `run-zizmor.sh` and its suite, which are this change's own token-emptiness tests,
  so the narrower path list above is the form that reproduces.
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
  the first, as far as this host settles it: the five audits `zizmor --offline -vv` reports
  as skipped resolve *other* repositories' refs and the advisory database, none of which is
  a resource of this repository, so no permission on this repository is what gates them.
  That is reasoning, not a green run — the pull request cites the CI run that exercises it,
  and if CI shows the audits need more, that is reported as a finding rather than answered
  by widening the grant. judgment for the second: `persist-credentials` governs a
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
- **A `ZIZMOR_REQUIRE_ONLINE` switch honoured by `run-zizmor.sh`**, as a general assertion
  that a CI run really went online. judgment: it would put a new flag in the gate's
  contract for every caller to learn, and make the script responsible for a policy only CI
  holds. Note precisely what is and is not covered without it. Decision 3's guard closes
  the **empty-token** route to a silently-unaudited green check, and that is the route with
  a mechanical trigger. It does **not** assert the run went online, so the
  variable-rename route in the residual above passes straight through it: a renamed token
  variable leaves `GH_TOKEN` non-empty, satisfies the guard, and still yields an offline
  run at exit 0. That half stays recorded rather than engineered against, and this bullet
  is not a claim of full coverage. An earlier draft also rejected the idea on the ground
  that it "would only convert a silent degrade into a red required check on an unrelated
  pull request"; that ground does not survive, because this record already accepts a red on
  an unrelated pull request when a tag moves or an advisory lands.
  Red-because-the-audit-worked and red-because-the-audit-stopped interrupt the same people,
  and only the second means coverage is gone.
- **Probe reachability and retry** so a token plus a dead API degrades instead of failing.
  judgment: it re-introduces the judgement call — how many retries, how long a timeout —
  that a hard failure states plainly, and it grows the design past what this decision
  governs.
- **Do nothing.** judgment: the five audits the threat model credits run nowhere today, and
  the next pin bump is the one that would need them.
