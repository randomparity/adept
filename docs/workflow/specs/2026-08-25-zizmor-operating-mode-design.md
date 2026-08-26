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
| 1 | `ZIZMOR_OFFLINE` | offline; reported condition | falls through | warn, then fall through |
| 2 | `ZIZMOR_NO_ONLINE_AUDITS` | offline; reported condition | falls through | warn, then fall through |

| # | variable | non-empty | empty | unset |
|---|---|---|---|---|
| 3 | `GH_TOKEN` | online; reported source | removed from the child env | falls through |
| 4 | `GITHUB_TOKEN` | online; reported source | removed from the child env | falls through |
| 5 | `ZIZMOR_GITHUB_TOKEN` | online; reported source | removed from the child env | falls through |

Falling through all five gives offline with the three token names as the condition.

Rows 3–5 are zizmor's documented discovery order for `--gh-token` (`zizmor --help`,
Network Options: `[env: GH_TOKEN or GITHUB_TOKEN or ZIZMOR_GITHUB_TOKEN]`). Rows 1–2 are
the mode controls under the same heading — `--offline [env: ZIZMOR_OFFLINE=]` and
`--no-online-audits [env: ZIZMOR_NO_ONLINE_AUDITS=]`. `--help` prints no value
enumeration for either; `[possible values: true, false]` comes from clap rejecting an
invalid one.

Three measurements on this host fix these semantics, and getting any of them wrong is a
defect rather than a detail:

- `ZIZMOR_OFFLINE=true` with a valid token completes **offline** at exit 0, printing no
  `WARN`. A script inferring the mode from the token alone would announce "online mode"
  over a run that audited no provenance — worse than the status quo, because the run would
  then be unaudited *and labelled audited*, and the label is this change's whole product.
- `ZIZMOR_OFFLINE=false` with a token goes **online**. A presence test would force
  `--offline` and report the operator's own variable as the cause of a mode they asked
  against — the "cause the observation does not carry" defect ADR 0025 decision 2 forbids.
- An empty or non-boolean value is rejected by zizmor — but only where zizmor still parses
  the variable. `GH_TOKEN=` exits 2 with `GitHub token cannot be empty` *even with
  `--offline` on argv*. `ZIZMOR_OFFLINE=0` exits 2 with `invalid value '0'` when no flag is
  on argv, but exits **0** with `--offline` present, because the explicit flag shadows the
  variable. A malformed `ZIZMOR_NO_ONLINE_AUDITS` is fatal either way — no flag shadows it.
- The exit statuses are distinct: **0** clean, **1** tool failure, **2** usage error, and
  **14** for a completed run reporting findings.

Hence rows 1–2 **warn and fall through** rather than exiting. A malformed value is not a
recognised instruction, so it selects no mode; the gate names it and lets zizmor's own
parser accept or reject it. Exiting instead would refuse in a case where zizmor runs
happily — a second opinion drifting from zizmor's, which is the defect this design exists
to avoid — and it would turn `ZIZMOR_OFFLINE=1`, green on the offline path today, into a
hard failure, regressing R6.

An empty *token* variable is removed from the child's environment, which is what makes "an
empty value is not a token" true by construction instead of asserted. Removing an empty
variable is not the override rejected below: an empty string carries no instruction.

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
run-zizmor: online mode; API token from GH_TOKEN
run-zizmor: online mode; API token from GH_TOKEN; GH_HOST=ghe.example.com
```

The second form is printed when `GH_HOST` is non-empty. That variable is ambient and
zizmor honours it as `--gh-hostname`, so it decides *which* API an online run talks to.
The clause states that destination *before* the scan. A failure does eventually name the
host — measured on this host, `GH_HOST=github.invalid.example` gives a `fatal` whose
headline names the audit (`'artipacked' audit failed`) and whose causal chain names
`https://github.invalid.example/...` — but only inside a stack a reader has to reach.
Naming it up front is what makes the mode line describe the run rather than the intent.
`GH_HOST` is a hostname, not a credential, so it is safe to print.

An exported-but-empty `GH_HOST` is read the same way as the other variables, with
`${VAR+set}`: an empty hostname is a value zizmor uses and fails on, not an absent one, so
the clause prints `GH_HOST=` for it rather than staying silent about the pointing most
likely to confuse.

That `artipacked` was the failing audit is worth recording: it is **not** one of the five
online-only audits, so with a token present zizmor takes audits outside that set onto the
network too. The five are what a token *buys*; they are not the full extent of what a dead
API costs.

No flag is passed on this path because zizmor has no `--online`: a token in the
environment is what selects online mode, verified above.

**Offline path.** The script prints two lines, then runs `zizmor --offline`:

```
run-zizmor: offline mode (--offline); ZIZMOR_OFFLINE=true
run-zizmor: offline mode (--offline); ZIZMOR_NO_ONLINE_AUDITS=true
run-zizmor: offline mode (--offline); no API token: GH_TOKEN, GITHUB_TOKEN and
  ZIZMOR_GITHUB_TOKEN are all unset or empty
run-zizmor: pin provenance was NOT audited: a well-formed 40-character SHA that is
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

**Malformed mode value.** A mode variable holding neither `true` nor `false` is warned
about and then ignored for mode selection; the mode line follows as usual, and zizmor's
own parser has the last word:

```
run-zizmor: ZIZMOR_OFFLINE=0 is not a value zizmor accepts (true or false); it selects no mode
  here, and zizmor may still reject it
```

**Online-failure hint.** Online mode is the only mode that can fail, and `actions-check`
is in `verify`, which the managed pre-push hook re-runs — so a failed online audit blocks
`git push`. When an online run exits with zizmor's **tool-failure** status the script
prints the response after it, so the red path carries a remedy as the offline conditions
do:

```
run-zizmor: the audit run failed rather than reporting findings; zizmor own error is
  above. If it is an API or token fault, a local offline run is ZIZMOR_OFFLINE=true
```

**The condition is `status == 1`, never "non-zero".** Findings exit 14, and offering this
hint there would advise switching off the audit that just caught something — a documented
route to a green gate over an unaudited pin. A usage error (2) is not offered it either,
since the offline subset does not fix a malformed variable. A future zizmor that
renumbers its statuses simply stops printing the hint, which is the safe direction to
fail.

It prints only in online mode, only on status 1, and does not alter that status. It is a
`printf` on a branch already being handled — not a retry, a timeout, or a reachability
probe, all of which the ADR rejects.

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

One consequence to state rather than leave implicit: when `ZIZMOR_NO_ONLINE_AUDITS=true`
selects the mode, the gate still passes `--offline`, so the operator's request for the
weaker control is executed as the stronger one. The mode line discloses it by naming the
variable beside the flag, and the two are equivalent here because
`--no-online-audits`'s only extra capability is auditing a remote `user/repo` slug, which
this gate never passes. A future change that let the gate take a remote input would make
the difference behavioural.

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
  sends it as an API credential to **the host `GH_HOST` names, defaulting to
  `github.com`** — the GitHub Server Hostname zizmor derives its API and git endpoints
  from (`zizmor --help` 1.29.0: `--gh-hostname ... [env: GH_HOST=] [default: github.com]`),
  not an API host given directly — zizmor honours that variable as `--gh-hostname`. This is the first
  path on which this repository's gate sends a credential off the machine at all: the
  recipe previously ran `zizmor --offline`, which forbids all online operations. The
  destination is therefore chosen by ambient input, which is why it is named here rather
  than left implicit.

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
- **B2, egress.** Two controls, for the two halves of the boundary.

  *The credential itself:* the script never holds the value. It tests the five mode
  variables for emptiness and lets zizmor read the environment it already inherits, so the
  token appears in no argv the script builds and in nothing the script prints.
  `run-zizmor.sh` prints the *name* of the source variable only, and the suite asserts the
  value is absent from the script's output. Beyond that, this design trusts zizmor with a
  credential it is designed to receive — `--gh-token` is its documented interface.

  *The destination:* the only control is visibility. `run-zizmor.sh` names `GH_HOST` on the
  online mode line whenever it is set, so a run pointed somewhere unexpected says so in the
  log it fails in. There is deliberately no allowlist or validation: that would be a second
  opinion on zizmor's own configuration — the drift this design exists to avoid — and it
  would cost more than the risk it removes. Reachability is narrow. In CI `GH_HOST` is
  unset and nothing in the diff sets it, and an actor who could set it there already
  controls the tree `just ci` executes, which is B1's problem and judged there. On a
  workstation it is the developer's own configuration, and online mode requires them to
  export a token themselves, so the worst case is misdelivering one's own credential to
  one's own configured host — with the symptom the design already predicts, a hard `fatal`
  naming an audit. No untrusted actor gains a capability.

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
- **An exported token sent to a `GH_HOST` the developer configured.** Accepted. The gate
  names the host on the online line and does not validate it, per B2's control list above;
  the residual is a developer misdelivering their own credential to their own configured
  host, which fails hard rather than silently.
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
| `ZIZMOR_OFFLINE=0`, no token | warns naming the variable and `true or false`, then announces offline; zizmor still runs |
| `ZIZMOR_OFFLINE=0`, `GH_TOKEN` set | warns, then announces **online** — the malformed value selects nothing |
| `ZIZMOR_OFFLINE` set to the empty string | warns, then falls through |
| `ZIZMOR_NO_ONLINE_AUDITS=maybe` | warns, then falls through |
| any valid mode value | no warning is printed |
| `GH_TOKEN` empty, others unset | announces offline; the stub sees `GH_TOKEN` **absent** from its environment |
| `GH_TOKEN` empty, `GITHUB_TOKEN` set | announces online naming `GITHUB_TOKEN`; the stub sees `GH_TOKEN` absent |
| offline path | prints the "pin provenance was NOT audited" consequence line |
| online path | the stub inherits the token variable unchanged, so zizmor reads it itself |
| `GH_HOST` set on the online path | the online line names the host |
| `GH_HOST` unset on the online path | the online line omits the host clause entirely |
| no `gh` on `PATH` | irrelevant to the outcome — the script never invokes `gh` |
| zizmor stub exits 1 | the script exits 1 (a real finding still reddens the gate) |
| zizmor stub exits 2 | the script exits 2 (a zizmor fault is not collapsed into a finding) |
| zizmor stub exits 1, online mode | the online-failure hint is printed; status is still 1 |
| zizmor stub exits 1, offline mode | the online-failure hint is **not** printed |
| zizmor stub exits 0, online mode | the online-failure hint is **not** printed |
| zizmor stub exits **14**, online mode | the hint is **not** printed — findings must never draw "switch the audit off"; status is still 14 |
| zizmor stub exits 2, online mode | the hint is **not** printed; status is still 2 |
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
