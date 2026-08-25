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

Measured on this workstation (macOS 26.6.1 arm64, zizmor 1.29.0), dropping `--offline`
is not by itself a fix. With no token in the environment, `zizmor .github/workflows/`
exits 0 having audited nothing online, announcing it only as

```
 WARN audit: zizmor: zizmor is running in offline mode by default; some audits and
 auto-fixes will not be available. see https://docs.zizmor.sh/usage/#operating-modes
```

buried in the tool's own log stream. The gate would then report green while the audits
the gate exists to run did not happen, and nothing in the gate's own output would say so.
That is precisely the silent skip [ADR 0025](../../adr/0025-a-skip-reports-the-condition-not-the-cause.md)
decision 2 forbids.

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

**Token discovery.** The script consults, in order:

1. `GH_TOKEN`
2. `GITHUB_TOKEN`
3. `ZIZMOR_GITHUB_TOKEN`
4. `gh auth token`

The first three, in that order, are zizmor's own documented discovery order for
`--gh-token` (`zizmor --help`, Network Options: `[env: GH_TOKEN or GITHUB_TOKEN or
ZIZMOR_GITHUB_TOKEN]`). Reading the same three in the same order means the mode the
script announces is the mode zizmor would have chosen, rather than a second opinion that
can drift from it. An empty value counts as unset; an exported-but-empty `GH_TOKEN` is
not a token.

`gh auth token` is the workstation fallback. Every developer who can push to this
repository already has an authenticated `gh` — `$quest`, `$deliver`, and the record
gates all depend on it — so without the fallback the online audits would never run on a
workstation and the pre-push hook would report offline on every push.

**Online path.** The script prints one line, then runs zizmor with no mode flag:

```
zizmor: online mode; API token from GH_TOKEN
```

and passes the token to the child through `ZIZMOR_GITHUB_TOKEN` in its environment, never
on the command line — argv is readable by every process of the same user through `ps`,
and a token from `gh auth token` has to be handed over somehow. The source *name* is
printed; the token value never is.

No flag is passed on this path because zizmor has no `--online`: a token in the
environment is what selects online mode, verified above.

**Offline path.** The script prints two lines, then runs `zizmor --offline`:

```
zizmor: offline mode (--offline); no API token: <condition>
zizmor: pin provenance was NOT audited — a well-formed 40-character SHA that is
  unreachable in the repository its `uses:` names, or that a known advisory covers,
  passes this run
```

`<condition>` is one of, and reports only what the script observed:

| observation | `<condition>` |
|---|---|
| the three variables are unset or empty and `gh` is not on `PATH` | ``GH_TOKEN, GITHUB_TOKEN and ZIZMOR_GITHUB_TOKEN are unset and gh is not on PATH`` |
| the three are unset or empty and `gh auth token` exited non-zero | ``GH_TOKEN, GITHUB_TOKEN and ZIZMOR_GITHUB_TOKEN are unset and `gh auth token` exited N`` |
| the three are unset or empty and `gh auth token` exited 0 printing nothing | ``GH_TOKEN, GITHUB_TOKEN and ZIZMOR_GITHUB_TOKEN are unset and `gh auth token` exited 0 printing no token`` |

Three conditions rather than one, because ADR 0025 decision 2 requires the line to carry
what discriminates the causes wherever they call for different responses, and these do:
the first is answered by installing `gh` or exporting a token, the second by
`gh auth login` or exporting a token, and the third by a `gh` that answered without
failing — a condition an operator should see stated rather than inferred. The exit status
is reported as the number observed; no cause is named for it, which is the same
discipline `CLAUDE.md` states for a scan's status and ADR 0025 decision 2 states for a
skip.

The second line states the consequence. A gate that says only "offline" leaves a reader
to know which audits that costs; the whole issue is that the cost was invisible.

Both lines print **before** zizmor runs, so a log of a failing run opens with the mode
that produced it.

**Exit status.** zizmor's status is captured into a variable explicitly and re-raised as
the script's own:

```sh
status=0
ZIZMOR_GITHUB_TOKEN=$token zizmor "$@" || status=$?
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

The `gh auth token` fallback never fires in CI, because `GH_TOKEN` is set — one fewer
moving part on the runner.

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
- **B2 — token egress to a third-party binary.** `run-zizmor.sh` hands a token to zizmor,
  which sends it to `api.github.com` as an API credential.

Boundaries this design **widens**:

- **B3 — workstation credential reach.** A gate that previously read no credential now
  reads `gh auth token`, which on a workstation is a developer's personal OAuth token,
  scoped far more broadly than a public read needs.

Boundaries this design does **not** touch: `permissions:`, `persist-credentials:`, the
set of triggers the workflow runs on, and what the gate scans.

### Actor model

- **Anonymous internet, via a fork pull request.** Can propose arbitrary content in the
  tree that `just ci` executes, including an edited `Justfile` and edited gate scripts.
  This is the untrusted actor that matters for B1.
- **A repository collaborator.** Can push a branch whose `just ci` runs with a token that
  is not read-only. Trusted with write access already.
- **The developer at a workstation.** Owns the `gh` credential the fallback reads. Trusted
  with it by construction — it is theirs.
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
- **B2, egress.** The token is passed in the child's environment, not in argv, so it does
  not appear in `ps` output for other processes of the same user. `run-zizmor.sh` prints
  the *name* of the source variable and never the value; the suite asserts the value is
  absent from the script's own output. Beyond that, this design trusts zizmor with a
  credential it is designed to receive — `--gh-token` is its documented interface.
- **B3, workstation.** The control is scope: the fallback runs only when all three token
  variables are unset, and the token it obtains is used for one read-only API session and
  never persisted, logged, or written anywhere. A developer who does not want their
  personal token used exports `GH_TOKEN` to a fine-grained token, or exports an empty
  `GH_TOKEN` and `PATH`s around `gh`, and the gate then reports offline mode with the
  condition — which is exactly the reporting this change adds.

### Explicitly out of scope

- **A malicious zizmor release.** Not addressed. zizmor is installed from Homebrew,
  unpinned, by the same step that installs every other gate tool; pinning the whole tool
  set is a separate decision this change does not make. Noted rather than silently
  omitted.
- **Token theft by a malicious pull request to a *public* repository.** Judged
  uninteresting rather than mitigated, for the reason under B1: a read-only token against
  public content is worth a rate-limit bump.
- **A workstation whose `gh` credential is already compromised.** Out of reach of a gate;
  the credential is compromised for `$quest`, `$deliver`, and `git push` first.
- **Network-present-but-failing with a token available.** R3 covers "no network and no
  credentials"; a host that has a token *and* a broken network gets whatever zizmor does
  with a failed API call, and the gate re-raises that status. Not mitigated, because a
  gate that treated a failed online audit as a pass would reinstate the silent green this
  change removes.

## Testing

`scripts/run-zizmor-test.sh`, discovered by `just test`, using the `fixture_init` /
`fail` scaffold from `scripts/test-fixture-helpers.sh` like every other suite in
`scripts/`. Both `zizmor` and `gh` are stubbed on `PATH`; the real binaries are never
invoked, so the suite needs no network and no credentials.

The `zizmor` stub records its argv and its `ZIZMOR_GITHUB_TOKEN` to files in the scratch
directory and exits with a status the case chooses.

| case | asserts |
|---|---|
| `GH_TOKEN` set | announces online mode naming `GH_TOKEN`; argv carries no `--offline`; the stub sees the token |
| `GITHUB_TOKEN` set, `GH_TOKEN` unset | announces online naming `GITHUB_TOKEN` |
| `ZIZMOR_GITHUB_TOKEN` set, other two unset | announces online naming `ZIZMOR_GITHUB_TOKEN` |
| all three set to different values | announces `GH_TOKEN`; the stub sees `GH_TOKEN`'s value (precedence) |
| `GH_TOKEN` set to the empty string, `gh` stub yields a token | empty is not a token; falls through to the `gh` fallback |
| all unset, `gh` stub prints a token | announces online naming `gh auth token`; the stub sees that token |
| all unset, `gh` absent from `PATH` | announces offline, `--offline` in argv, condition names `gh is not on PATH`, exit 0 |
| all unset, `gh` stub exits 1 | announces offline, condition names `exited 1`, exit 0 |
| all unset, `gh` stub exits 0 printing nothing | announces offline, condition distinguishes this from a failure, exit 0 |
| offline path | prints the "pin provenance was NOT audited" consequence line |
| zizmor stub exits 1 | the script exits 1 (a real finding still reddens the gate) |
| zizmor stub exits 2 | the script exits 2 (a zizmor fault is not collapsed into a finding) |
| any online case | the token value appears nowhere in the script's stdout or stderr |
| no arguments | usage message, exit 2 |
| inputs forwarded | argv ends with exactly the inputs given, in order |

Each behaviour has a triggering case, including every error path, per `CLAUDE.md`.

### Verification beyond the unit suite

- `just verify` on this workstation, which has an authenticated `gh`, exercises the
  online path end to end against the real zizmor and the real API (R1, criterion 3).
- The tokenless path is exercised against the real zizmor by running the recipe's script
  with the three variables unset and `PATH` pointing at a directory without `gh`. This
  is the reporter's tokenless environment reconstructed on this host — a real zizmor, no
  token reachable — and the run must exit 0 with the offline lines (R2, R3).
- CI exercises the online path on both runners once `GH_TOKEN` is wired, on this pull
  request itself.

## Consequences

- Every `actions-check` run — local, pre-push hook, CI — now states its mode. A reader of
  a green gate learns whether provenance was audited without knowing zizmor's defaults.
- CI audits provenance on every pull request, which is the coverage issue #239 asks for.
- A workstation with `gh` authenticated audits provenance too, so the pre-push hook
  catches a bad pin before it reaches CI.
- A machine with neither says so, twice, and stays green.
- One new script and one new suite. By the repository's anatomy rules these are gate
  scripts under `scripts/`, not skill files, so rules 1 and 2 do not bind them; rule 3
  holds — the script runs and exits.
