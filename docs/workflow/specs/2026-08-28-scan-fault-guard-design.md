# Scan-fault discard guard — design

Issue: #66
Decision: [ADR 0047](../../adr/0047-scan-fault-discards-require-a-pragma.md)

## Goal and scope

Add a structural gate that enforces ADR 0005's scan-fault rule: a status-discard idiom in
the gate scripts must carry an inline `# scan-fault: deliberate — <reason>` pragma, and an
undocumented one fails the gate. The decision — guard yes, inline-pragma shape, match set,
exclusions, scan scope, placement — is ADR 0047's; this document specifies the guard's
behavior for implementation and testing.

Permitted surface: `docs/adr/0047-*.md`, this design record, the implementation plan, a new
guard script `scripts/check-scan-fault-discards.sh` and its suite
`scripts/check-scan-fault-discards-test.sh`, `Justfile` wiring, pragma annotations in the
gate scripts (and their byte-identical twins), and the plugin manifest version. The
central-allowlist shape, the diff-scoped shape, `if !` matching, and test-script scanning
are excluded (ADR 0047 Considered & rejected).

## Behavior

The guard scans the repository's shell sources — `scripts/list-shell-sources.sh --all -z`
output — minus test scripts (paths matching `tests/fixtures/*` or `*/tests/fixtures/*`, and
names ending `-test.sh`). For each file, line by line, it applies, in order:
1. **Comment skip.** A line whose first non-whitespace character is `#` is skipped.
2. **Heredoc tracking.** A line containing `<<` (not `<<<`) followed by optional `-`,
   optional quote, and a word character opens a heredoc; its delimiter word is queued. While
   a delimiter is pending, lines are skipped until a line equal to the delimiter (leading
   tabs tolerated only for `<<-`), which dequeues it. Heredoc bodies are content, not code.
3. **Pragma check.** A line containing `scan-fault: deliberate —` followed by at least one
   non-whitespace character is exempt.
4. **Match.** A line is a finding when it contains one of:
   - `|| true` or `|| :` on a command that is not a test and not a pure builtin;
   - `|| continue`, `&& continue`, `|| return 0`, `&& return 0`, `|| exit 0`, `&& exit 0`
     on such a command;
   - `[ -n "$(cmd)" ]`, `[ -z "$(cmd)" ]`, `[[ -n $(cmd) ]]`, `[[ -z $(cmd) ]]`,
     `[[ -n "$(cmd)" ]]`, `[[ -z "$(cmd)" ]]`, or `test -n/-z` with a command substitution.
5. **Exclusions.** The trailing discard patterns do not fire when the discarded command is a
   test — the text before the operator ends with `]`, `]]`, or `))`, or the line's command
   word is `test` — or a pure builtin when the line contains no pipeline (`|`) and no
   command substitution (`$(`). The pure builtins are: `printf`, `echo`, `read`, `:`,
   `true`, `false`, `unset`, `local`, `export`, `cd`, `shift`, `return`, `exit`, `break`,
   `continue`, `trap`, `umask`, `set`, `eval`, `source`, `.`, `declare`, `typeset`, `pwd`,
   `type`, `hash`, `let`, `wait`, `getopts`, `times`, `ulimit`, `alias`, `bg`, `fg`,
   `jobs`, `kill`, `help`, `compgen`, `complete`, `dirs`, `disown`, `enable`, `history`,
   `logout`, `popd`, `pushd`, `readonly`, `shopt`, `suspend`, `builtin`, `exec`, `caller`,
   `bind`, `fc`, `mapfile`, `readarray`, `coproc`. The command word is the first token
   after leading `VAR=value` assignments. If the line contains a pipeline or a command
   substitution, it is not builtin-exempt.
6. **Report.** A finding prints `scan-fault-guard: <file>:<line>: <shape> without a
   '# scan-fault: deliberate — <reason>' pragma` where `<shape>` names the operator
   (`trailing true-discard`, `trailing colon-discard`, `continue-discard`, `return-0-discard`,
   `exit-0-discard`, `substitution-in-test`) — never the literal operator, so the guard's
   own messages cannot match its own patterns.

Exit status: 0 clean; 1 findings; 2 the guard could not run — a non-zero source-listing
status, an unopenable file, or a bad argument. The guard captures the lister's status
explicitly (the lister exits 1 when discovery broke) and reports it rather than passing.

The guard accepts `--files file…` to scan explicit paths (its suite's entry point); with no
argument it scans the inventory.

Wiring: a `scan-fault-check` recipe runs `./scripts/check-scan-fault-discards.sh`; the
`commit-check` recipe gains it, so `just verify`, the pre-push hook, and CI run it.

The sweep: every deliberate discard in the gate scripts gains the pragma with a reason
citing its class (in-memory input per ADR 0032 decision 4, the sanctioned `|| :` form per
decision 2, cleanup, probe, documented residual). The `just records` mirror twins receive
identical annotations.

## AI-SPEC and evaluation plan

No AI surface: the guard is a deterministic shell scan with no model, prompt, retrieval, or
generation. No eval plan applies.

## Threat model

- **Boundary inventory.** The guard reads tracked repository files (shell sources) and the
  source-lister's output. It adds no network or external boundary. It never executes the
  content it scans; matching is line-based regex over text.
- **Actor model.** The only untrusted party is a future contributor whose commit introduces
  a discard idiom into a gate script. The guard's purpose is to make that commit red.
- **Control per boundary.** A file the guard cannot open is a fault (exit 2), never a pass —
  the guard follows the rule it enforces. A line the guard misreads is a correctness
  question, not a security one: a false red blocks a commit (loud, bounded); a false pass
  (heredoc false-open, `<<` inside a string) is the recorded residual.
- **Out of scope.** Maliciously crafted shell content cannot redirect the guard (no eval,
  no source); the guard's own execution is under `set -euo pipefail` with the repo's
  guarded-cleanup pattern.

## Traceability

- Guard exists and runs on every commit: wiring task (commit-check) + guard suite.
- Match set, exclusions, pragma grammar, heredoc tracking, exit statuses: guard suite cases
  (one per shape, per exclusion, per fault path).
- Sweep annotates every deliberate discard: `just records` passes on the twins; `just
  verify` green.
- The guard follows the rule: its own source carries no unannotated discard (it is in the
  inventory it scans).
- Verification: `just verify` (full suite) plus the guard suite's own cases.