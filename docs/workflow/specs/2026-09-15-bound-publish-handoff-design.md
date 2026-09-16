# Bound publish-handoff's five network calls — design

Issue [#384](https://github.com/randomparity/adept/issues/384), under epic #379. Applies
[ADR 0068](../../adr/0068-a-timeout-is-not-an-answer.md) and
[references/network-bounds.md](../../../references/network-bounds.md). Writes no new record: the
mechanism, the bound, the write rule, and this caller's classification are all already decided.

## Problem

`skills/return-to-town/scripts/publish-handoff` makes five network calls — `gh pr view`,
`gh api /repos/<owner/name>/issues/<n>`, `git ls-remote origin`, `gh issue comment`, and
`gh api /repos/<owner/name>/issues/comments/<id>` — and none carries a bound. Against an
unreachable or black-holing remote any of them blocks forever, which hangs an unattended worker
on the one command a hand-off is supposed to need.

Two of the five sit after the write. A call killed once `gh issue comment` created the comment but
before its URL came back leaves a published block the script cannot see, which is a new and
strictly weaker member of the post-write exit class `skills/return-to-town/SKILL.md` already
reasons about: the script does not know whether the comment exists at all.

## Scope

**In.** `skills/return-to-town/scripts/publish-handoff`, `skills/return-to-town/SKILL.md`,
`tests/fixtures/return-to-town/publish-handoff-test.sh`, `.claude-plugin/plugin.json` (5.10.1),
and this design set — this file and `docs/workflow/plans/2026-09-15-bound-publish-handoff.md`.

**Design.** Add the reference's `bounded_call` verbatim in shape, with its seven non-adaptable
properties intact, plus two thin local wrappers: `bounded_network_call`, which names a capture
slot inside the existing `mktemp -d` workspace and passes an ordinary failure's captured stderr
through to the terminal as it reached it before; and `timed_out`, which turns an exceeded bound
into this script's own `fault` — exit 2, its "could not run" class, the row the reference's
classification table assigns this caller. `124` stays internal.

All five calls issue exactly one request, so all five take the 30-second bound. The bound is a
single script-level constant, documented as approximate.

All five sites capture into a command substitution today, so all five are restructurings rather
than wrapper swaps: each reads its value back out of the stdout capture file. `jq` takes the file
as an operand in place of a here-string; `git ls-remote`'s single line is re-read with `cat`; the
readback response becomes a path (`response_file`) that `assert_stored_body` reads with
`--rawfile` unchanged.

**Classification.** Every timed-out call exits 2 and names itself. A timeout before the write adds
"nothing was posted". A timeout on the write reports that it may or may not have landed. A timeout
on the readback reports that the comment *was* created, names its URL, and reports its stored copy
unverified — more precise than treating the two post-write sites alike, and honest in both
directions. None is retried, and the diagnostic says why re-running is not the remedy.

**No shared helper.** ADR 0068 leaves extraction to whichever applier reaches the third
repetition. Three appliers run in parallel and none can observe that count, so the idiom stays
local; the reference is what they are checked against.

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

- `sleep` is not on `require_commands` and this charter excludes changing that list (owner: #382).
  A host without `sleep` but with `cat`, `rm`, `od` and `awk` is not a deployment this repository
  targets; the cost is a bare non-zero exit rather than a named one.
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

**Boundary inventory.** Widened, not added: the two capture files per call are new filesystem
objects holding a GitHub response. No new entry point, argument, or environment key.

**Actor model.** A local unprivileged user on a shared host is the untrusted party; GitHub is
trusted to the same degree it already is. The operator running the script is trusted.

**Control per boundary.** Captures are created by `>` inside `$workspace`, which `make_workspace`
already allocates with `mktemp -d` at mode 0700 and the existing EXIT trap already removes — so no
`$$`-derived name in a shared directory and no pre-created symlink to follow. This is the
reference's first non-adaptable property, satisfied by an existing control rather than a new one.
A capture from a call that hit its bound is emptied by `bounded_call` before it returns, so no site
can parse a truncated response as a complete short one.

**Explicitly out of scope.** Signal delivery to a PID reused within one poll interval (accepted
above). Anything reachable only by an actor who can already write inside the 0700 workspace.

## Success

1. Each of the five sites is bounded through `bounded_call` with all seven non-adaptable properties
   intact, and none of the five still captures into a command substitution.
2. Each of the five exits 2 on an exceeded bound with a diagnostic naming that call and the bound.
3. The `gh issue comment` site reports the write as indeterminate, and the readback site reports
   the comment as created-but-unverified with its URL. Neither retries.
4. `skills/return-to-town/SKILL.md` states that a timeout is not a re-run condition and what the
   reader does instead.
5. `require_commands`, `scripts/setup.sh`, and every file outside the Scope list are unchanged.
6. `just verify` exits 0.

## Validation

- **`bounded_call` returns 124 on an exceeded bound, and no site uses what the hung call wrote.**
  Mode: `focused-test` — `tests/fixtures/return-to-town/publish-handoff-test.sh`,
  `case_pr_view_times_out`. The fake `gh` emits a partial JSON object and then `exec sleep 300`;
  the case asserts the helper reports the bound rather than a parse error. Red is observed by
  running the case before the constant exists, where the fixture's bound rewrite finds nothing and
  fails the case by name. Green: `just test publish-handoff`.
  The `: >"$out"` discard itself is not separately observable in this caller: every site faults on
  124 before it would parse anything, so the line is structural insurance against a later site
  that does not, which is why the reference requires it be kept rather than reasoned away.
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
- **The re-run rule prose.** Mode: `task-test-not-applicable` — the changed surface is instruction
  prose in `SKILL.md`, and CLAUDE.md anatomy rule 4 forbids a gate asserting on a sentence.
- **`.claude-plugin/plugin.json` declares version 5.10.1 exactly.** Mode: `focused-test` —
  `just version-check`
  (`scripts/check-plugin-version.sh`), which checks shape locally and strict-greater-than-base in
  CI.
