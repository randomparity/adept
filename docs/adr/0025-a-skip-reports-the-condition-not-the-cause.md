# 0025 — A skip reports the condition it observed, never a cause

## Status

Accepted (2026-08-19)

## Context

[ADR 0024](0024-a-failing-repository-probe-is-not-evidence-of-absence.md) closed the
collapse in `resolve_tracker`'s repository probe and pinned the dubious-ownership case that
covers the refusal arm. Two things it left standing assert a cause nobody had established:
the guard that decides whether that case runs, and the record's own account of where the
case runs.

**The guard.** Three sites stage the refusal with `GIT_TEST_ASSUME_DIFFERENT_OWNER=1`,
probe `git rev-parse --show-toplevel`, and skip when git does not refuse —
`tests/fixtures/quest-log/tracker-test.sh` and `check-records-test.sh` in both
byte-identical copies. All three printed `this git ignores
GIT_TEST_ASSUME_DIFFERENT_OWNER`. The probe establishes that git did not refuse. It does
not establish why. Measured on macOS 26.6.1 with git 2.50.1 (Apple Git-155), in a fresh
`git init` fixture, every invocation carrying the switch: plain `rev-parse --show-toplevel`
exits 128, `-c safe.directory='*'` exits 0, and `-c safe.directory=<fixture>` exits 0. An
entry covering the path neutralizes the switch, so a git that honours the switch perfectly
still reaches the skip branch whenever protected configuration already trusts the path. One
observation, two causes, and the line named one of them as fact.

Issue #175's fix narrowed the second cause without closing it. With
`GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_SYSTEM=/dev/null` staged, a git that honours
those two variables — they arrive in 2.32 — has no protected configuration left to consult,
so the config route now needs a git that predates them or ignores them. That is the
condition measured here: real git 2.50.1 wrapped by a shim dropping both variables, with a
permissive `*` in the global config, exits 0 from the probe where the unwrapped binary exits
128.

The two causes call for opposite responses, which is why collapsing them is not cosmetic.
A git that ignores the switch offers nothing to stage and nothing to fix. A `safe.directory`
entry is a thing an operator can remove — and on a CI runner it was the difference between
a suite that covers the refusal arm and a suite that announced a skip on every run.

**The record.** 0024's `Consequences` says the staged refusal never fires "on a host whose
`safe.directory` is already permissive — which is what happens on the Ubuntu CI runner,
where the case skips", and that the case "was run and shown to bite on macOS and in an
Ubuntu 24.04 container with git 2.43.0". Run 32294975702, on c68f17d of the branch that
merged 0024, skipped the case on **both** runners:

```
suite (ubuntu-latest)  tracker-test: skip dubious ownership; this git ignores GIT_TEST_ASSUME_DIFFERENT_OWNER
suite (macos-latest)   tracker-test: skip dubious ownership; this git ignores GIT_TEST_ASSUME_DIFFERENT_OWNER
```

No CI arm ran the case. The macOS measurement was a local host's, written into a passage
about the runners, and the Ubuntu cause was a candidate rather than a finding — the only
evidence the record had was the same skip line the guard prints for a git that ignores the
switch.

Issue #175's fix settled the cause afterwards. With `GIT_CONFIG_GLOBAL=/dev/null` and
`GIT_CONFIG_SYSTEM=/dev/null` staged alongside the switch, run 32312386979 on 8522795 runs
the case on both runners:

```
suite (ubuntu-latest)  ok   root probe fails inside a repository   exit=1 E-ROOT-UNRESOLVED
suite (macos-latest)   ok   root probe fails inside a repository   exit=1 E-ROOT-UNRESOLVED
```

Nothing else about the runners changed between the two runs, so the cause was an inherited
permissive `safe.directory` in a global or system config file, honoured in protected
configuration. The runners' git honours the switch; it refuses as soon as that
configuration is out of scope. 0024 named the right mechanism without having established
it, and its "the ownership case cannot be staged everywhere" is wrong about the runners —
it can be staged there, and now is.

## Decision

**1. 0024's account of where the ownership case runs is withdrawn and replaced.** The case
is staged with the global and system config files out of scope, and on that footing it runs
on both CI runners: run 32312386979 is the arm 0024 reported as absent. What remains
unstaged is a git that ignores the switch outright, where the case skips and the skip is
announced, never banked as a pass. The two `Consequences` sentences that name the Ubuntu
runner's permissive configuration as an established cause and offer a local macOS run as
coverage for the macOS runner do not hold. Everything else in 0024 stands, including all
three of its decisions. The supersession banner it now carries is coarse for the reason
0024 gave when it put one on [ADR 0005](0005-scan-faults-are-reported-not-collapsed.md) —
the banner grammar has no way to say "in part" — and should be read as reaching that one
`Consequences` bullet.

**2. A skip line reports the condition the guard observed, and no cause the observation does
not carry. Where the condition has more than one cause and they call for different
responses, the line carries what discriminates them.** For this guard the condition is "git
did not refuse the fixture under `GIT_TEST_ASSUME_DIFFERENT_OWNER`", and the discriminator
is the `safe.directory` entries in scope under the same staged environment, read with
`git config --show-origin --get-all safe.directory`. None listed leaves a git that ignores
the switch as the only explanation standing; an entry listed names the file that did the
neutralizing. Probe, case, and discriminator share one environment list at each site, for
the reason 0024's fix already gives: a report measured against a condition the case did not
reproduce is how this skipped everywhere while reading as deliberate.

That query's own status is read rather than collapsed. Exit 1 is git's "no such key", the
ordinary answer; anything above it is a query that never ran and must not print as an empty
list, which is [ADR 0005](0005-scan-faults-are-reported-not-collapsed.md) decision 1 applied
to the reporting path rather than to a verdict.

**3. A record's factual claim about an environment names the environment it was measured in.**
A measurement taken on a workstation is written as a workstation's; a claim about a CI
runner is either read out of that runner's log or marked as unestablished. 0024's macOS
sentence was true of the host it was run on and false of the runner it was written about,
and nothing in the sentence said which one it meant.

## Consequences

An operator or maintainer reading a skip now learns which of the two responses applies
instead of being told a cause the run did not establish. Where the entries are listed, the
line names the config file to fix; where none are, the switch is the only explanation left
and there is nothing to fix.

Four sites carry the change, not the three the issue scoped.
`scripts/git-fixture-isolation-test.sh` stages the same probe to decide whether its own
permissive-config assertion can run, and it carried the same wrong line; leaving it would
have left the suite that exists to catch this condition misreporting it.

Each site gains a short helper and the skip line gains a parenthesis. The helper is
duplicated rather than shared because the `check-records-test.sh` twins are compared byte
for byte by `just records` and sit at a different depth from `scripts/`, so neither twin can
source a helper the way `tests/fixtures/` does — the same constraint that already forces
`clear_git_env` to be reimplemented inline there.

0024 now carries a supersession banner. A reader arriving at it from the directory listing
or from a link sees the correction before the corrected sentences.

Nothing enforces decisions 2 and 3. Anatomy rule 4 forbids a gate that greps prose, and the
sentence-level errors these decisions address are exactly prose; like 0005 and 0024 this
record shapes the next fix and does not prevent the next recurrence.

## Considered & rejected

**Drop the skip and let the case fail wherever the refusal cannot be staged.** verified: on
macOS 26.6.1 with git 2.50.1 wrapped by a shim that unsets `GIT_TEST_ASSUME_DIFFERENT_OWNER`
before exec, the fixture is an ordinary working repository and `tracker.sh resolve` exits 0
printing `fixture`; the case would then report a defect in the engine that is not there. A
red for a reason that is not the subject's is the failure mode the guard exists to avoid.

**Match git's stderr for "dubious ownership" to tell the two causes apart.** judgment: 0024
rejected reading git's prose in the engine because the wording is git's to reword and, on an
NLS build, to translate. A suite's skip line is no better a place to couple to it, and
`git config` answers the same question in a form git maintains as an interface.

**Report all of `git config --list --show-origin` in the skip line.** judgment: one key
decides the outcome and the rest is noise on a line an operator reads in a CI log.

**Correct 0024 in place.** verified: `docs/adr/README.md` states that records are
append-only once merged and that a decision is superseded with a new record and a banner on
the old one. The checker enforces the banner grammar and heading and preamble intactness —
`E-BANNER-FORM`, `E-HEADING-REWRITTEN`, `E-PREAMBLE-REWRITTEN` in
`.github/scripts/check-records.sh` — and would pass a sentence rewritten inside a section,
so the convention rather than the gate is what forbids this.

**Append a `## Correction` section to 0024 instead of writing a new record.** judgment:
cheaper, and it leaves the wrong sentences standing above the correction in the same file
for a reader who stops at `Consequences`. It also invents a section the profile's required
list does not know, which `APPEND_ONLY_SECTIONS="*"` would then protect for one record only.

**Fix the guard now and file the record correction as its own issue.** judgment: the issue
scopes both halves as one defect and they are one defect — a cause asserted from an
observation that does not carry it. Splitting them leaves the record wrong for as long as
the second issue waits, and the record is the artifact a reader trusts.
