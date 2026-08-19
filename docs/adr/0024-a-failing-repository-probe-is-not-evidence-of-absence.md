# 0024 — A failing repository probe is not evidence of absence

## Status

Accepted (2026-08-19)

## Context

[ADR 0005](0005-scan-faults-are-reported-not-collapsed.md) decided that a scan reading
external bytes has three outcomes — matched, did not match, could not run — and that the
third never falls into the second. Its `Consequences` then listed sites left outside the
rule, and named one of them not merely unfixed but *correct*:

> `resolve_tracker`'s repository and `AGENTS.md` probes fail open to the default tracker:
> both test for *absence* rather than scanning content, and absence is the ordinary case —
> accepted exceptions, not oversights.

That ground does not hold for the repository probe. Issue #165 reports it, and measurement
settles it. On git 2.50.1 (Apple Git-155) under macOS 15.6, `git rev-parse --show-toplevel`
exits **128** for each of: no repository at or above the working directory; a
dubious-ownership refusal (`GIT_TEST_ASSUME_DIFFERENT_OWNER=1`) from inside a working
repository; a `.git` at mode 000; a `.git` directory emptied of its contents; a `.git` file
naming a path that does not exist; `GIT_DIR` set to a path that does not exist; and a
working directory whose parent has been made unreadable. `git rev-parse
--is-inside-work-tree` and `git rev-parse --git-dir` return 128 across the same set.

One of those cases is a platform fact rather than a git fact, and was re-measured on Ubuntu
24.04 with git 2.43.0 after a macOS-only reading of it produced a fix that passed locally
and failed in CI. Under an unreadable parent directory, macOS `getcwd` walks the tree and
fails, so git reports being unable to read the working directory; glibc `getcwd` answers
from the kernel and succeeds, and git gets as far as a `stat` and reports "failed to stat".
Same fault, same 128, two different things to probe for.

So the probe does not test for absence. It returns one status for absence and for refusal
alike, and `resolve_tracker` answered `github` to all of them. A repository whose
`AGENTS.md` declares another tracker, reached by an operator whose git declines it as
dubiously owned, resolved to GitHub at exit 0 and the run then wrote there. That is the
wrong-tracker write the function's own header calls out, arriving through the one door the
header did not watch.

The same reading condemns 0005's own `git cat-file` finding — decision 2 already rules
inadmissible "a command whose exit status cannot separate absent from faulted". The
repository probe is such a command. 0005 reached the opposite verdict for this site because
it classified the probe by what the *caller* wanted to learn rather than by what the
*command* can report.

Nothing here disturbs 0005's three decisions. They are the reason this site is a defect.

## Decision

**1. ADR 0005's exemption for `resolve_tracker`'s repository probe is withdrawn.** Decision 1
of 0005 applies to that site. Decisions 1, 2 and 3 of ADR 0005 are carried forward
unchanged and remain the governing rule; the supersession banner on 0005 is coarse because
the banner grammar has no way to say "in part", and it should be read as reaching that one
`Consequences` bullet only.

The companion `AGENTS.md` probe, `[ -f "$root/AGENTS.md" ]`, keeps its exemption on the
ground 0005 gave it: a `test -f` really does test for absence, and has no third outcome to
lose.

**2. Where a probe cannot separate absence from refusal, the separation is established by a
further probe whose answer is positive, never by reading a diagnostic string.** For the
repository probe that is four probes, none of which parses git's prose:

- git resolves where it is before it looks for a repository, so a working directory it
  cannot establish means nothing was searched. Ask for the name and then whether the name
  can be reached: `cwd=$(pwd -P)` and `[ -d "$cwd" ]`. Both halves are needed, and which one
  fires is a platform fact — on macOS `getcwd` walks the tree and fails outright under an
  unreadable parent; on glibc it answers from the kernel and succeeds, and git's subsequent
  `stat` is what fails ("failed to stat", measured on Ubuntu 24.04 with git 2.43.0). Either
  probe alone leaves the other platform's fault falling through to the default.
- 128 is the status git exits with when it ran and declined, including for an option it does
  not recognise. Any other status is a probe that never ran; 127, for no git on `PATH`, is
  the reachable one.
- `git -c safe.directory='*' rev-parse --show-toplevel` suppresses the ownership check and
  nothing else. A retry that succeeds where the plain probe failed therefore isolates the
  ownership refusal: the repository is there and git declined it.
- `GIT_DIR` or `GIT_WORK_TREE` set means git was told where the repository is. A probe that
  failed anyway says that named repository is unusable, never that none exists.

The retry's root names the remedy and never resolves a tracker. A repository git refuses to
trust is not one to read a declaration out of.

The `GIT_DIR` probe is the one place `resolve_tracker` reads ambient state, and the function
header forbids exactly that. The rule is intact because the read decides a *fault*, never a
resolution: it can only turn a silent default into an error. A `GIT_DIR` naming nothing was
already steering the outcome before this record — to `github`, silently, which is the
header's stated failure mode.

**3. A residual that cannot be closed is named where the fallback is taken, not left
implicit.** What still reaches the default tracker is git's own negative discovery answer —
no repository — and the two cases it reports identically as "not a git repository": a `.git`
it cannot read, and a `.git` whose pointer it cannot follow. Both leave a readable worktree
whose declaration is then missed. Separating them from a true absence means reimplementing
repository discovery. The comment on `resolve_tracker` says so in those terms.

A bare repository also reaches the fallback, and correctly: it has no worktree, so no
`AGENTS.md` and nothing to declare.

## Consequences

An operator whose git declines a repository as dubiously owned now gets an actionable
refusal — the repository's path and the exact `git config --global --add safe.directory`
command — instead of a silent resolution to GitHub. Passing `--profile` still bypasses
resolution entirely, so the operator is never stuck.

The remedy is reconstructed from the retry's root rather than relayed from git's own line.
`scripts/verify-push.sh` and `.github/scripts/check-records.sh` leave git's line standing
because their channel is plain text; `tracker.sh`'s stderr carries one JSON error object a
caller parses, and git's line would corrupt it. The two shapes are now deliberately
different and each says why.

Running outside a git repository still resolves to `github` at exit 0, which
`tests/fixtures/quest-log/tracker-test.sh` pins. That path is now reached only after the
three probes above have ruled out the causes they can rule out.

One fault is reachable that this record does not close, and one caller-visible contract is
not what it looks like:

- A `.git` that git cannot read, or whose pointer it cannot follow, is reported by git as no
  repository and still falls back silently. Decision 3 names it in the code; nothing
  detects it.
- The unreadable-working-directory case cannot produce a single JSON object on stderr
  whatever `tracker.sh` does, because bash writes its own `shell-init` line before the
  script gets control. The suite asserts that case by message rather than by parsing the
  payload, and says why.
- The ownership case cannot be staged everywhere. It skips loudly on a git that ignores
  `GIT_TEST_ASSUME_DIFFERENT_OWNER`, and on a host whose `safe.directory` is already
  permissive the staged refusal never fires — which is what happens on the Ubuntu CI
  runner, where the case skips. It was run and shown to bite on macOS and in an Ubuntu
  24.04 container with git 2.43.0. A skip is announced, never banked as a pass.

`resolve_tracker` grows from 60 to about 90 lines, most of it the comment carrying this
record's reasoning to the site. Nothing enforces this decision; like 0005, it shapes fixes
and does not prevent the next recurrence.

## Considered & rejected

**`git rev-parse --is-inside-work-tree` as the discriminator, as issue #165 suggests.**
verified: measured on git 2.50.1 (Apple Git-155), macOS 15.6, it exits 128 for no
repository, for a dubious-ownership refusal, for a `.git` at mode 000, for an emptied
`.git`, for a `.git` file naming nothing, for `GIT_DIR` set to nothing, and for an
unreadable working directory — the same statuses `--show-toplevel` returns for the same
seven cases. It separates exactly one case the plain probe does not: a bare repository,
where it exits 0 printing `false`. A bare repository has no worktree and therefore no
`AGENTS.md`, so `github` is already the correct answer there and the extra probe would buy
no change in behaviour.

**"Reading the status against a probe that answers outside a repo", the issue's second
suggestion.** verified: the only `git rev-parse` form measured to exit 0 outside a
repository is `--local-env-vars`, which exits 0 inside a dubious-ownership repository too —
it never opens the repository. It distinguishes a working git binary from a broken one, not
absence from refusal.

**Match git's stderr for "dubious ownership".** judgment: it couples the engine to a
diagnostic string that is git's to reword and, on a build with NLS, to translate. This
host's git did not translate it under `LC_ALL=fr_FR.UTF-8` or `de_DE.UTF-8`, which is a fact
about this build and not a property to rely on.

**Die on every non-zero status and drop the outside-a-repository fallback.** verified: the
simplest fix that closes the collapse completely, and the fallback is a pinned contract —
`tests/fixtures/quest-log/tracker-test.sh` asserts `resolve` outside a git repository exits
0 printing `github`, and #165 states that "not in a repository" may legitimately fall back.
Withdrawing it is a caller-contract change and would belong in its own record.

**Reimplement repository discovery to separate "no repository" from an unreadable `.git`.**
judgment: fidelity — it would have to reproduce `GIT_CEILING_DIRECTORIES`, the
filesystem-boundary rule, `.git` files naming another directory, and linked worktrees, and
every divergence from git's own walk is a new wrong-tracker route added to close an old one.

**Resolve the tracker from the `safe.directory` retry's root once it succeeds.** judgment: it
reads a declaration out of a repository git has just refused to trust, which inverts the
purpose of the refusal. The retry is one `rev-parse --show-toplevel`; it reads that
repository's config but runs no hook, alias, pager, editor, or fsmonitor, and its output is
used only to name a path in a diagnostic.

**Leave the site exempt, as 0005 recorded.** verified: the exemption's stated ground is that
the probe "tests for absence". It does not — the measurement in `Context` shows one status
covering absence and six refusals — so the exemption rests on a premise that is false.

**Record nothing and carry the correction in the pull request body.** judgment: 0005's
bullet is the durable artifact and the pull request body is not; a reader who opens 0005
next year finds "accepted exceptions, not oversights" and no reason to doubt it.
