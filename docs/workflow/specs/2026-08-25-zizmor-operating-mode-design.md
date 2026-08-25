# `actions-check` selects and names zizmor's operating mode

Issue [#239](https://github.com/randomparity/adept/issues/239). Decision record:
[ADR 0036](../../adr/0036-actions-check-names-its-zizmor-mode.md).

## Problem

`Justfile`'s `actions-check` recipe runs

```
actionlint
zizmor --offline .github/workflows/
```

`--offline` disables every audit that needs the GitHub API. The audits it disables are
the ones that check a pin's *provenance* — whether the 40-character SHA a `uses:` names
is reachable in the repository it names, and whether the pinned revision is covered by a
known advisory. Offline mode confirms only that a pin has the right *shape*. An impostor
SHA borrowed from a fork is a well-formed pin offline.

The repository's threat model credits those audits. Five action pins are in the tree
today; the next bump — a hand edit, or Dependabot once issue #236 lands it — would be
checked by shape alone.

Measured on this workstation (arm64 macOS, Darwin 25.6.0, zizmor 1.29.0), dropping
`--offline` is not by itself a fix. With no token in the environment,
`zizmor .github/workflows/` exits 0 having audited nothing online, announcing it only as

```
 WARN audit: zizmor: zizmor is running in offline mode by default; some audits and
 auto-fixes will not be available. see https://docs.zizmor.sh/usage/#operating-modes
```

on stderr among zizmor's `INFO` lines. That `WARN` does appear in exactly the unaudited
case and in no other, so it is a real distinguisher — but it names the mode without the
condition that chose it, and the gate itself adds nothing. A reader learns the mode only
by knowing zizmor's log conventions, and learns why not at all, which is the
discrimination [ADR 0025](../../adr/0025-a-skip-reports-the-condition-not-the-cause.md)
decision 2 requires a degrade to carry.

Two further measurements, neither of which the issue mentions, shape the design.

**A token is not connectivity.** With a token present and the API unreachable, zizmor does
not fall back to the offline subset — it exits 1 with `fatal: no audit was performed`.

**A token does not decide the mode by itself.** `ZIZMOR_OFFLINE=true` and
`ZIZMOR_NO_ONLINE_AUDITS=true` each override a present token: the run completes offline at
exit 0, and — unlike the tokenless default above — prints no `WARN` at all. Anything
reading only the token variables would announce "online mode" over that run. Their value,
not their presence, is what zizmor reads: `ZIZMOR_OFFLINE=false` selects online.

The audits at stake are measured from the binary rather than taken from the published
table. `zizmor --offline -vv --no-progress .github/workflows/` on this host logs
`skipping <audit>: can't run without a GitHub API token` for `impostor-commit`,
`known-vulnerable-actions`, `ref-confusion`, `stale-action-refs`, and
`ref-version-mismatch`. `typosquat-uses` is scheduled offline and is *not* among them, and
<https://docs.zizmor.sh/audits/> does not list `ref-version-mismatch` as online-only — so
where the page and the binary disagree, this spec follows the binary the gate runs.

## Requirements

Sourced from the frozen scope charter on issue #239.

- **R1.** With an API token available, `actions-check` runs zizmor's online audits.
- **R2.** With no API token, `actions-check` runs the offline subset, exits 0, and prints
  a line naming both the mode it ran and the condition that chose it. A bare silent
  fallback is a defect.
- **R3.** `just verify` stays green on a machine with no network and no credentials, as
  every other gate in this repository does. Failing without a token was considered and
  rejected by the operator before this design started.
- **R4.** The design states whether CI receives a token and, if so, the minimum
  permission it needs. A change to the workflow's `permissions:` or to checkout's
  `persist-credentials:` is a security-posture change and is justified in the record and
  the pull-request body, never made silently.
- **R5.** `--offline` and `--no-online-audits` are distinguished deliberately, and the
  choice is stated with its reason.
- **R6.** `actionlint` and every audit that runs today keep running unchanged.
- **R7.** The scan's exit status is captured explicitly. "zizmor found nothing" and
  "zizmor could not run" are never collapsed, per `CLAUDE.md`.

### Out of scope

- `.github/dependabot.yml` (issue #236) and `scripts/check-skill-shape.sh` (issue #238),
  both owned by other work in flight.
- The content of `.github/workflows/pages.yml`. The gate audits it; this change does not
  edit it.
- What zizmor audits beyond its operating mode — configuration file, persona, severity
  and confidence thresholds are all left as they are.

## Design

### Where the logic lives

A new gate script, `scripts/run-zizmor.sh`, owns mode selection, mode reporting, and the
zizmor invocation. `actions-check` becomes

```
actions-check:
  actionlint
  ./scripts/run-zizmor.sh .github/workflows/
```

`actionlint` keeps its own line and its own invocation, unchanged (R6).

A script rather than an inline recipe body, for one reason that decides it: recipe bodies
are invisible to this repository's guardrails. `scripts/list-shell-sources.sh` discovers
tracked files named `*.sh` or opening with a bash shebang; `Justfile` is neither, which
is why `check-ripgrep-config.sh` documents the `Justfile` recipe bodies as out of its
reach. A mode-selection branch written inline would be unlinted by `shellcheck`,
unformatted by `shfmt`, and — decisively — untestable, because `just test` discovers
suites as tracked `*-test.sh` files. The behaviour this change is about *is* the
reporting, so reporting that no suite can exercise is the wrong shape for it.

The script's own suite is `scripts/run-zizmor-test.sh`, beside it, as every gate script
in `scripts/` already has.

### Contract of `scripts/run-zizmor.sh`

```
usage: run-zizmor.sh <input>...
```

Inputs are forwarded to zizmor unchanged. Zero arguments is a usage fault, exit 2 — the
status `list-shell-sources.sh` and `check-ripgrep-config.sh` already reserve for "this
script could not run at all", as against a verdict about what it scanned.

**Mode discovery.** Five environment variables decide zizmor's mode, and the script reads
all five *in zizmor's own vocabulary* — the two mode controls are clap booleans whose
**value** is the instruction, not their presence.

Resolution order:

| # | variable | `true` | `false` | anything else, empty included |
|---|---|---|---|---|
| 1 | `ZIZMOR_OFFLINE` | offline; reported condition | falls through | exit 2, named |
| 2 | `ZIZMOR_NO_ONLINE_AUDITS` | offline; reported condition | falls through | exit 2, named |

| # | variable | non-empty | empty | unset |
|---|---|---|---|---|
| 3 | `GH_TOKEN` | online; reported source | removed from the child env | falls through |
| 4 | `GITHUB_TOKEN` | online; reported source | removed from the child env | falls through |
| 5 | `ZIZMOR_GITHUB_TOKEN` | online; reported source | removed from the child env | falls through |

Falling through all five gives offline with the three token names as the condition.

Rows 3–5 are zizmor's documented discovery order for `--gh-token` (`zizmor --help`,
Network Options: `[env: GH_TOKEN or GITHUB_TOKEN or ZIZMOR_GITHUB_TOKEN]`). Rows 1–2 are
the mode controls under the same heading — `--offline [env: ZIZMOR_OFFLINE=]` and
`--no-online-audits [env: ZIZMOR_NO_ONLINE_AUDITS=]`, both `[possible values: true, false]`.

Three measurements on this host fix these semantics, and getting any of them wrong is a
defect rather than a detail:

- `ZIZMOR_OFFLINE=true` with a valid token completes **offline** at exit 0, printing no
  `WARN`. A script inferring the mode from the token alone would announce "online mode"
  over a run that audited no provenance — worse than the status quo, because the run would
  then be unaudited *and labelled audited*, and the label is this change's whole product.
- `ZIZMOR_OFFLINE=false` with a token goes **online**. A presence test would force
  `--offline` and report the operator's own variable as the cause of a mode they asked
  against — the "cause the observation does not carry" defect ADR 0025 decision 2 forbids.
- An empty or non-boolean value is a usage error, not an ignorable one: `GH_TOKEN=` exits 2
  with `GitHub token cannot be empty` *even with `--offline` on argv*, `ZIZMOR_OFFLINE=`
  exits 2 with `a value is required`, and `ZIZMOR_OFFLINE=0` with `invalid value '0'`.

Hence rows 1–2 exit 2 with the variable and the accepted values named, rather than
announcing a mode the run will never enter; and an empty *token* variable is removed from
the child's environment, which is what makes "an empty value is not a token" true by
construction instead of asserted. Removing an empty variable is not the override rejected
below: an empty string carries no instruction.

A `true` mode variable is reported, never unset. Silently overriding an operator who asked
to stay offline is the same class of defect as the silent degrade this change closes, and
there is no flag to assert online mode over them — `zizmor --offline=false` errors with
`unexpected value 'false' for '--offline'`.

**There is deliberately no fallback to `gh auth token`.** A token is not connectivity:
`gh auth token` is a keyring read that contacts nothing, so it yields a token on a machine
with no network, and zizmor handed a token it cannot use exits 1 with `fatal: no audit was
performed` rather than degrading. Since every developer who can push here has an
authenticated `gh`, such a fallback would redden `just verify` and the pre-push hook for
all of them whenever the API is unreachable — violating R3 for a larger set of machines
than failing-without-a-token would have. Requiring an *export* makes online mode an
opt-in, so the person who takes on the network dependency is the person who asked for it.
[ADR 0036](../../adr/0036-actions-check-names-its-zizmor-mode.md) records this with the
reproduction.

**The script never reads a token's value.** It tests only whether each variable is
non-empty, and lets zizmor read the value itself from the environment it already
inherits. No credential passes through the script, so none can reach its output or its
argv.

**Online path.** The script prints one line, then runs zizmor with no mode flag:

```
zizmor: online mode; API token from GH_TOKEN
zizmor: online mode; API token from GH_TOKEN; GH_HOST=ghe.example.com
```

The second form is printed when `GH_HOST` is non-empty. That variable is ambient and
zizmor honours it as `--gh-hostname`, so it decides *which* API an online run talks to; a
developer configured for a GitHub Enterprise instance otherwise gets a hard failure whose
message names an audit rather than the host. `GH_HOST` is a hostname, not a credential.

No flag is passed on this path because zizmor has no `--online`: a token in the
environment is what selects online mode, verified above.

**Offline path.** The script prints two lines, then runs `zizmor --offline`:

```
zizmor: offline mode (--offline); ZIZMOR_OFFLINE=true
zizmor: offline mode (--offline); ZIZMOR_NO_ONLINE_AUDITS=true
zizmor: offline mode (--offline); no API token: GH_TOKEN, GITHUB_TOKEN and
  ZIZMOR_GITHUB_TOKEN are all unset or empty
zizmor: pin provenance was NOT audited — a well-formed 40-character SHA that is
  unreachable in the repository its `uses:` names, or that a known advisory covers,
  passes this run
```

Three conditions, each with a different response — set `ZIZMOR_OFFLINE=false` or unset it,
likewise `ZIZMOR_NO_ONLINE_AUDITS`, or export a token. That is exactly the case ADR 0025
decision 2 covers: one observation ("the run was offline") with several causes calling for
different responses, so the line carries what discriminates them. The condition reports
the variable and value observed and asserts nothing about why they were set.

"or empty" in the third condition is accurate because the script has already removed any
empty token variable from the child's environment, so empty and unset genuinely reach
zizmor the same way.

**Usage-error path.** A mode variable holding neither `true` nor `false` exits 2 before
any mode is announced:

```
run-zizmor: ZIZMOR_OFFLINE=0 is not a value zizmor accepts (true or false)
```

The second line states the consequence. A gate that says only "offline" leaves a reader
to know which audits that costs; the whole issue is that the cost was invisible.

Both lines print **before** zizmor runs, so a log of a failing run opens with the mode
that produced it.

**Exit status.** zizmor's status is captured into a variable explicitly and re-raised as
the script's own:

```sh
status=0
zizmor --offline "$@" || status=$?
exit "$status"
```

No `|| true`, no pipe. A zizmor that is not installed reaches this as 127 and is
re-raised as 127 (R7).

### `--offline` rather than `--no-online-audits`

`zizmor --help`, Network Options, on zizmor 1.29.0:

- `-o, --offline` — "Perform only offline operations. This disables all online audit
  rules, and prevents zizmor from auditing remote repositories."
- `--no-online-audits` — "Perform only offline audits. This is a weaker version of
  `--offline`: instead of completely forbidding all online operations, it only disables
  audits that require connectivity."

`--offline` is chosen. R3 is the deciding requirement: the tokenless path must be green
with no network at all, and `--offline` is the flag that states "no network" as a
property of the run rather than as a property of the audit set. `--no-online-audits`
leaves online operations permitted, and its one capability over `--offline` — auditing a
remote `user/repo` input — is a capability this gate never uses, because its only input
is the local `.github/workflows/` directory.

`--offline` is also today's flag, so the offline path is byte-for-byte the invocation
that runs now (R6): the audits that pass today pass identically, and the change to that
path is the two lines printed above it.

### CI receives a token

**Decision: yes.** `.github/workflows/verify.yml` gains one line in the `Verify` step's
existing `env:` block:

```yaml
      - name: Verify
        env:
          BASE_SHA: ${{ github.event.pull_request.base.sha || github.event.before }}
          GH_TOKEN: ${{ github.token }}
        run: just ci
```

**Minimum permission: the job's existing `permissions: contents: read`, unchanged.** The
online audits read public repositories' git refs and the public advisory database through
the GitHub API. `contents: read` on *this* repository is the floor a usable
`GITHUB_TOKEN` needs; nothing about reading another public repository's refs requires a
scope beyond it. So:

- `permissions:` is **not** changed. It stays `contents: read`.
- checkout's `persist-credentials: false` is **not** changed. That setting governs whether
  a credential is written into `.git/config` for later git commands; it is unrelated to an
  environment variable on one step, and the workflow keeps the stricter setting.

What does change is that the token's *value* becomes visible to the `just ci` step, which
runs this repository's whole gate chain. That is the security-posture change this design
makes, and the threat model below is where it is judged.

CI sets `GH_TOKEN` and neither mode variable, so the runner takes the online branch by
the same rule every other machine does — no CI-specific path in the script.

Adding the token to the environment rather than interpolating `${{ }}` inside the `run:`
block is the pattern zizmor's own `template-injection` audit exists to enforce; the gate
audits its own workflow, so the change has to satisfy it.

## Threat model

The change widens what a CI step can reach, so the security section applies.

### Boundary inventory

Boundaries this design **adds**:

- **B1 — CI step environment.** A GitHub App installation token reaches the `just ci`
  step's environment on every `pull_request` and every push to `main`. Everything `just
  verify` runs — gate scripts, `prek` hooks, `shellcheck`, `shfmt`, `actionlint`,
  `zizmor`, the npm-installed Claude CLI — inherits it.
- **B2 — token egress to a third-party binary.** With a token in the environment, zizmor
  sends it to `api.github.com` as an API credential.

Boundaries this design **widens**: none.

Boundaries this design does **not** touch: `permissions:`, `persist-credentials:`, the
set of triggers the workflow runs on, and what the gate scans. In particular the gate
reaches no credential store: dropping the `gh auth token` fallback (above) means a
workstation credential is never read, so the design adds no workstation boundary at all.

### Actor model

- **Anonymous internet, via a fork pull request.** Can propose arbitrary content in the
  tree that `just ci` executes, including an edited `Justfile` and edited gate scripts.
  This is the untrusted actor that matters for B1.
- **A repository collaborator.** Can push a branch whose `just ci` runs with a token that
  is not read-only. Trusted with write access already.
- **The developer at a workstation.** Reaches online mode only by exporting a token
  themselves. Trusted with their own credential by construction — the design never goes
  looking for it.
- **zizmor and its transitive dependencies.** Trusted to send the token only to the
  GitHub API. This is a stated trust assumption, not a verified one.

### Control per boundary

- **B1, fork pull request.** The control is GitHub's own: for a `pull_request` event from
  a fork, `GITHUB_TOKEN` is read-only regardless of the `permissions:` block, and secrets
  are not exposed. Combined with `permissions: contents: read` this design leaves in
  place, the most a compromised gate script obtains is authenticated read access to a
  **public** repository — content the same actor can already read unauthenticated. The
  marginal capability gained is a higher API rate limit. This is an existing platform
  control, preferred to a new one.
- **B1, same-repository branch.** `permissions: contents: read` bounds the token to
  reading this public repository. A collaborator who can push a branch can already do
  strictly more than that token permits.
- **B2, egress.** The script never holds the value: it tests the five mode variables for
  emptiness and lets zizmor read the environment it already inherits, so the token appears
  in no argv the script builds and in nothing the script prints. `run-zizmor.sh` prints
  the *name* of the source variable only, and the suite asserts the value is absent from
  the script's output. Beyond that, this design trusts zizmor with a credential it is
  designed to receive — `--gh-token` is its documented interface.

### Explicitly out of scope

- **A malicious zizmor release.** Not addressed. zizmor is installed from Homebrew,
  unpinned, by the same step that installs every other gate tool; pinning the whole tool
  set is a separate decision this change does not make. Noted rather than silently
  omitted.
- **Token theft by a malicious pull request to a *public* repository.** Judged
  uninteresting rather than mitigated, for the reason under B1: a read-only token against
  public content is worth a rate-limit bump.
- **A workstation whose `gh` credential is already compromised.** Out of reach of a gate,
  and out of this design's reach in particular — it never reads that credential.
- **An exported token with an unreachable API.** Verified on this host: zizmor exits 1
  with `fatal: no audit was performed`, and the gate re-raises that status. Deliberately
  not mitigated. A reachability probe or a retry wrapper would grow the design past what
  it governs, and treating a failed online audit as a pass would reinstate exactly the
  silent green this change removes. Requiring an *export* is what bounds the blast
  radius: the machines that can hit this are the ones whose owner opted in.
- **A per-audit online failure inside an otherwise-successful run.** zizmor reports one as
  a `WARN` in its own stream, so a run can announce online mode and still finish green
  having not reached the API for some audit. The mode line reports the token found, not
  that every audit completed. Stated rather than mitigated, for the same
  proportionality reason.

## Testing

`scripts/run-zizmor-test.sh`, discovered by `just test`, using the `fixture_init` /
`fail` scaffold from `scripts/test-fixture-helpers.sh` like every other suite in
`scripts/`. `zizmor` is stubbed on `PATH`; the real binary is never invoked, so the suite
needs no network and no credentials.

The `zizmor` stub records its argv and the token variables it inherited to files in
the scratch directory, and exits with a status the case chooses.

| case | asserts |
|---|---|
| `GH_TOKEN` set | announces online mode naming `GH_TOKEN`; argv carries no `--offline` |
| `GITHUB_TOKEN` set, `GH_TOKEN` unset | announces online naming `GITHUB_TOKEN` |
| `ZIZMOR_GITHUB_TOKEN` set, other two unset | announces online naming `ZIZMOR_GITHUB_TOKEN` |
| all three set to different values | announces `GH_TOKEN` (precedence matches zizmor's) |
| `GH_TOKEN` set to the empty string, `GITHUB_TOKEN` set | empty is not a token; announces `GITHUB_TOKEN` |
| all three set to the empty string | announces offline, exit 0 |
| all three unset | announces offline, `--offline` in argv, condition names all three variables, exit 0 |
| `ZIZMOR_OFFLINE=true` **and** `GH_TOKEN` set | announces **offline**, condition names `ZIZMOR_OFFLINE=true`, `--offline` in argv |
| `ZIZMOR_NO_ONLINE_AUDITS=true` **and** `GH_TOKEN` set | announces offline, condition names `ZIZMOR_NO_ONLINE_AUDITS=true` |
| both mode variables `true` | condition names `ZIZMOR_OFFLINE` (first in order) |
| `ZIZMOR_OFFLINE=false`, `GH_TOKEN` set | falls through; announces **online** naming `GH_TOKEN` |
| `ZIZMOR_OFFLINE=false`, no token | falls through; announces offline with the no-token condition |
| `ZIZMOR_OFFLINE=0` | exit 2, message names the variable and `true or false`; zizmor never runs |
| `ZIZMOR_OFFLINE` set to the empty string | exit 2, same message |
| `ZIZMOR_NO_ONLINE_AUDITS=maybe` | exit 2, same message |
| `GH_TOKEN` empty, others unset | announces offline; the stub sees `GH_TOKEN` **absent** from its environment |
| `GH_TOKEN` empty, `GITHUB_TOKEN` set | announces online naming `GITHUB_TOKEN`; the stub sees `GH_TOKEN` absent |
| offline path | prints the "pin provenance was NOT audited" consequence line |
| online path | the stub inherits the token variable unchanged, so zizmor reads it itself |
| `GH_HOST` set on the online path | the online line names the host |
| `GH_HOST` unset on the online path | the online line omits the host clause entirely |
| no `gh` on `PATH` | irrelevant to the outcome — the script never invokes `gh` |
| zizmor stub exits 1 | the script exits 1 (a real finding still reddens the gate) |
| zizmor stub exits 2 | the script exits 2 (a zizmor fault is not collapsed into a finding) |
| any online case | the token value appears nowhere in the script's stdout or stderr |
| no arguments | usage message, exit 2 |
| inputs forwarded | argv ends with exactly the inputs given, in order |

Each behaviour has a triggering case, including every error path, per `CLAUDE.md`.

### Verification beyond the unit suite

- `just verify` on this workstation with no token exported exercises the **offline** path
  end to end against the real zizmor — which is now the default path everywhere except
  CI. It must exit 0 and print the offline lines (R2, R3, criterion 3).
- The **online** path is exercised against the real zizmor and the real API by running the
  recipe's script with `GH_TOKEN` exported (R1, criterion 1).
- Both real-zizmor runs are reported with the environment each was run in, per ADR 0025
  decision 3.
- CI exercises the online path on both runners once `GH_TOKEN` is wired, on this pull
  request itself.

## Consequences

- Every `actions-check` run — local, pre-push hook, CI — now states its mode. A reader of
  a green gate learns whether provenance was audited without knowing zizmor's defaults.
- CI audits provenance on every pull request, which is the coverage issue #239 asks for.
- A workstation audits provenance only when someone exports a token; by default it runs
  the offline subset and says so, twice, and stays green with no network. Coverage is one
  gate on the merge path rather than two, which is the price of keeping the local gate
  hermetic.
- With a token exported, a failed API call fails the gate hard rather than degrading. That
  applies to CI too: an API outage can redden the required `verify` check for a reason
  unrelated to the pull request. Recorded in ADR 0036 as an accepted residual.
- The required check now depends on state outside this repository. `stale-action-refs`,
  `ref-version-mismatch`, and `known-vulnerable-actions` resolve against upstream
  repositories and the advisory database, so `verify` can newly fail on a re-run of an
  unchanged commit when a tag moves or an advisory is published. That is what the audits
  are for, and it is also a way for an unrelated pull request to go red.
- One new script and one new suite. By the repository's anatomy rules these are gate
  scripts under `scripts/`, not skill files, so rules 1 and 2 do not bind them; rule 3
  holds — the script runs and exits.
