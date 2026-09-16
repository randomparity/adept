# Bound publish-handoff's five network calls — design

Issue [#384](https://github.com/randomparity/adept/issues/384), under epic #379. Applies
[ADR 0068](../../adr/0068-a-timeout-is-not-an-answer.md) and
[references/network-bounds.md](../../../references/network-bounds.md). Writes no new record: the
mechanism, the bound, the write rule, and this caller's classification are all already decided.

## Problem

`skills/return-to-town/scripts/publish-handoff` makes five network calls — `gh pr view`,
`gh api /repos/<owner/name>/issues/<n>`, `git ls-remote origin`, `gh issue comment`, and
`gh api /repos/<owner/name>/issues/comments/<id>` — and none carries a bound, so an unreachable
or black-holing remote hangs an unattended worker on the one command a hand-off is meant to need.

Two of the five sit after the write. A call killed once `gh issue comment` created the comment but
before its URL came back leaves a published block the script cannot see: a new and strictly weaker
member of the post-write exit class `skills/return-to-town/SKILL.md` already reasons about, where
the script does not know whether the comment exists at all.

## Scope

**In.** `skills/return-to-town/scripts/publish-handoff`, `skills/return-to-town/SKILL.md`,
`tests/fixtures/return-to-town/publish-handoff-test.sh`, `.claude-plugin/plugin.json` (5.10.1),
and this design set — this file and `docs/workflow/plans/2026-09-15-bound-publish-handoff.md`.

**Design.** Transcribe the reference's `bounded_call` unchanged, with its seven non-adaptable
properties intact, plus two thin local wrappers: `bounded_network_call`, which names a capture
slot inside the existing `mktemp -d` workspace; and `timed_out`, which turns an exceeded bound
into this script's own `fault` — exit 2, its "could not run" class, the row the reference's
classification table assigns this caller. `124` stays internal.

Capturing stderr to a file would otherwise stop it reaching the terminal, on the success path as
much as the failure path, so `bounded_network_call` passes it through on every status but 124 —
where the writer was killed mid-stream and a partial diagnostic reads as an answer.

All five calls issue exactly one request, so all five take the 30-second bound. The bound is a
single script-level constant, documented as approximate.

All five sites capture into a command substitution today, so all five are restructurings rather
than wrapper swaps: each reads its value back out of the stdout capture file. `jq` takes the file
as an operand in place of a here-string; `git ls-remote`'s single line is re-read with `cat`; the
readback response becomes a path (`response_file`) that `assert_stored_body` reads with
`--rawfile` unchanged.

**Test mechanism.** #384 names two ways to reach the bound without waiting 30 seconds — a FIFO
the test blocks on, or an injectable bound — and asks for the choice to be stated. This takes a
third: `sed` rewrites the one bound constant in a *copy* of the script, run through the fixture's
existing `HELPER_PATH`. A FIFO is a file each case must create, open and tear down, and leaves a
blocked writer to reason about when a case aborts. An injectable bound puts a permanent
environment key in a shipped executable for a test's benefit, which an operator could set and
collect false timeouts from. The copy adds no shipped surface and fails the case by name if the
constant is renamed; its cost is that five cases exercise a copy whose only difference is the
bound.

**Classification.** Every timed-out call exits 2 and names itself. A timeout before the write adds
"nothing was posted". A timeout on the write reports that it may or may not have landed. A timeout
on the readback reports that the comment *was* created, names its URL, and reports its stored copy
unverified — more precise than treating the two post-write sites alike, and honest in both
directions. None is retried, and the diagnostic says why re-running is not the remedy.

Two new causes join exit 2 beyond the bound itself, both from moving a captured value into a file:
`awk` failing to scan the create response for a URL, and `cat` failing to read back the refs
`git ls-remote` reported. Each is a scan that could not run, so each faults rather than collapsing
into the emptiness check below it, which would report a scan that could not run as one that found
nothing — the defect this script's header already names.

**No shared helper.** ADR 0068 leaves extraction to whichever applier reaches the third
repetition; three run in parallel and none can observe that count, so the idiom stays local and
the reference is what they are checked against.

**Out.** No retry or backoff. No bound on `git rev-parse --local-env-vars` at `:260`, which reaches
no network. No change to `require_commands` or `scripts/setup.sh`. No other applier's executable.
No `WORK:TRAJECTORY` composer restructuring (#380).

## Failure model

**Actors and deployments.** A `$return-to-town` run at an operator's terminal; the same run
dispatched from an unattended campaign queue, which is the deployment this change exists for; the
behaviour suite under `just verify` and CI.

**Invariants and assets at stake.**

- A published hand-off comment is public and permanent; a spurious re-run appends another.
- The merge gate reads exactly one line, so a run must never report success it did not verify.
- `publish-handoff`'s exit taxonomy is what `$return-to-town` acts on: 2 must stay "could not run".
- Capture files hold GitHub response bodies and are written inside a private 0700 workspace.

**Accepted failure classes.**

- `sleep` is not on `require_commands`, and this charter excludes changing that list (owner:
  #382). The cost is worse than a missing-binary exit, so it is stated: every site calls the
  wrapper in a `|| rc=$?` list, which suppresses `set -e` inside it, so a failing `sleep 0.1`
  spins the poll loop instead of aborting and reports a **false 124** on a call that was answering
  — the defect this convention exists to prevent. Reachable only on a host carrying `iconv`, `od`,
  `awk` and `mktemp` but not `sleep`, which this repository does not target. Reported to the campaign
  orchestrator as a mechanism/exclusion interaction — #382 is closed, so it has no live owner —
  rather than patched around here.
- The bound is not a deadline. Poll overhead accumulates and a 30-second bound fires at roughly 32.
- PID reuse inside one poll interval, same-uid: the reference records it and no idiom on a Bash 3.2
  floor closes it.
- An interactive `ssh` passphrase or host-key prompt reads from `/dev/tty` and is contained by the
  bound rather than named by it. `GIT_TERMINAL_PROMPT=0` is not set here: the one `git` site
  already runs after `clear_local_git_env`, and adding a knob for a sharper message is scope the
  charter does not carry.
- A caller killed mid-call still orphans what was running — today's exposure, unchanged.

**Covered elsewhere.**

- An aggregate per-run budget — ADR 0068 Consequences; no owner for this script.
- `skills/quest-log/assets/profiles/github.sh` — no applier issue; ADR 0068 records the gap.
- The other three appliers — #386 and #387.

## Threat model

**Boundary inventory.** Widened, not added: two capture files per call, holding a GitHub
response. No new entry point, argument, or environment key.

**Actor model.** A local unprivileged user on a shared host is the untrusted party. GitHub and the
operator running the script are trusted exactly as much as they already are.

**Control per boundary.** Captures are created by `>` inside `$workspace`, which `make_workspace`
already allocates with `mktemp -d` at 0700 and the EXIT trap already removes — so no `$$`-derived
name in a shared directory and no pre-created symlink to follow. That is the reference's first
non-adaptable property, met by an existing control rather than a new one.

**Explicitly out of scope.** Signal delivery to a PID reused within one poll interval (accepted
above), and anything reachable only by an actor who can already write inside the 0700 workspace.

## Success

1. Each of the five sites is bounded through `bounded_call` with all seven non-adaptable properties
   intact, and none of the five still captures into a command substitution.
2. Each of the five exits 2 on an exceeded bound with a diagnostic naming that call and the bound.
3. The `gh issue comment` site reports the write as indeterminate, and the readback site reports
   the comment as created-but-unverified with its URL. Neither retries.
4. `skills/return-to-town/SKILL.md` states that a timeout is not a re-run condition and what the
   reader does instead — including at the "Re-run it once" sentence itself, which is the line the
   completion criterion names and the one a reader reaches first.
5. `require_commands`, `scripts/setup.sh`, and every file outside the Scope list are unchanged.
6. `just verify` exits 0. The manifest bump is PATCH because no invocation's contract changes:
   #384 offers only PATCH or MAJOR, and exit 2 gains a cause rather than a class.

## Validation

- **`bounded_call` returns 124 on an exceeded bound.** Mode: `focused-test` —
  `tests/fixtures/return-to-town/publish-handoff-test.sh`, `case_pr_view_times_out`. The fake `gh`
  emits a partial JSON object and then `exec sleep 30`; the case asserts the helper reports the
  bound rather than a parse error. Red is observed by adding the case before the bound exists,
  where the fixture's bound rewrite finds nothing and fails the case by name. Green:
  `just test publish-handoff`.
  The `: >"$out"` discard itself is not separately observable in this caller: every site faults on
  124 before it would parse anything, so the line is structural insurance against a later site
  that does not, which is why the reference requires it be kept rather than reasoned away. The
  partial object is in the fake for that later site's benefit, not as evidence here.

- **The timeout cases are margin-bounded rather than timing-dependent.** Mode: `focused-test` —
  the five cases below, with both margins stated because a margin nobody wrote down is a flake
  nobody predicted. Each runs a copy of the helper whose single bound constant is rewritten to 2
  seconds against a call that sleeps 30 — **15x** on the bound firing — and that same rewritten
  constant governs the calls which must *succeed* in the case, four of them in the readback case
  at roughly 30 ms each — **60x** on the other side. A later case is counted against both.
- **Each of the five sites classifies a timeout as exit 2 naming the call.** Mode: `focused-test` —
  `case_pr_view_times_out`, `case_issue_read_times_out`, `case_ls_remote_times_out`,
  `case_comment_write_times_out`, `case_readback_times_out`, each asserting exit 2 and the
  call-naming substring. Green: `just test publish-handoff`.
- **A timed-out write is reported as indeterminate, not as "nothing was posted".** Mode:
  `focused-test` — `case_comment_write_times_out`: the fake records the posted body and emits a
  URL before hanging, and the case asserts the body was recorded, that stdout carries no URL, and
  that stderr says the write may or may not have landed.
- **A timed-out readback names the created comment.** Mode: `focused-test` —
  `case_readback_times_out` asserts exit 2 and that stderr carries the comment URL.
- **The re-run rule prose, at both the "Re-run it once" sentence and the paragraph below it.**
  Mode: `task-test-not-applicable` — the changed surface is instruction prose in `SKILL.md`, and
  CLAUDE.md anatomy rule 4 forbids a gate asserting on a sentence.
- **`.claude-plugin/plugin.json` declares version 5.10.1 exactly.** Mode: `focused-test` —
  `just version-check`
  (`scripts/check-plugin-version.sh`), which checks shape locally and strict-greater-than-base in
  CI.
