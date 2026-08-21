---
name: detect-evil
description: "Run a diff-scoped security pass by inventorying touched trust boundaries and checking validation, authorization, bounding, destination encoding, leaks, secrets, cryptography, deserialization, supply chain, permissions, and security defaults. Use when a branch is security-relevant or the user asks for a threat scan."
---
# Threat Scan

The caller is the `orchestrator` and a dispatched security reviewer is a
`worker`; precise reviewer names remain valid subtypes.

Enumerate the trust boundaries a change touches and check what crosses each one. Read-only
apart from an optional `--out` findings file — do not edit scanned files, comment on PRs, or
change git state.

Input: use the user-supplied target, flags, and focus text.

**This is not `$gauntlet` with a security focus.** `$gauntlet` argues why a change should
not ship, weighing focus text against every other material issue it can defend. This asks a
narrower question systematically: *what crosses a trust boundary here, and is each crossing
validated, authorized, and bounded?* Run it as an inventory, not a critique — the failure
mode of a security review is a confident sweep that never enumerated the surface.

**Caller contract & constraints (front-loaded so they survive truncation).** This skill is
usually one step inside `$quest`. Emitting the verdict is a **checkpoint, not a turn
boundary** — hand it back and let the caller continue; stop only if a human asked for a
one-shot scan with nothing queued after. **Read-only** except for the optional `--out` file.
`approve` only when no defensible finding exists.

A direct `$detect-evil` invocation remains a one-pass, read-only checkpoint. When a standalone
caller wants findings iterated and dispositioned to a settled state, invoke
`$trial-loop --reviewer detect-evil <target and focus>`; `$trial-loop` owns fixes, deferral records,
bounded retries and iterations, and the terminal report. `$detect-evil` never invokes the loop or
mutates the target itself.

## Argument parsing and target resolution

**Read the installed `$gauntlet` skill before parsing** and apply its *Argument
parsing*, *Target resolution*, and *File output* sections **verbatim**: same flags
(`--base <ref>`, `--working-tree`, `--json`, `--out <path>`), same left-to-right token
classification, same three target modes (branch, working-tree, file-list), same
working-tree default, and the same line-anchored `CHARTER` stop rule with its
target-resolution error taxonomy.

Those rules are deliberately not restated here. They are a parsing boundary with one owner,
and a second copy would be a second thing to keep in sync — so read the owner rather than
reconstructing it from memory. If `$gauntlet` is genuinely absent, say so and fall back
to the three flags and three modes named above; do not invent a `CHARTER` interpretation.

One rule from that section is repeated here because it is a safety property and the cost of
getting it wrong is silent: on a target-resolution error, write **nothing** — no artifact, no
`run_id`, no compact object. The `verdict` enum has no error member, so an invented verdict
would read to a caller as a completed scan.

## 1. Inventory the boundaries

Before judging anything, list the trust boundaries the diff touches. A boundary is any
point where data or control crosses a change in trust level:

- **Untrusted input entering** — HTTP handlers and route params, CLI arguments, environment
  variables, config and data files, stdin, deserialized payloads, webhook bodies, IPC and
  socket reads, message-queue consumers, uploaded files, database rows written by another
  actor.
- **Privilege changes** — anything that authenticates, authorizes, assumes a role, drops or
  raises privileges, or decides tenancy.
- **Outbound calls to somewhere else's trust domain** — a URL built from input, a shell
  command, a database query, a template render, a file path, a redirect target.
- **Persistence and transport** — what is written where, at what file mode, over what
  channel, with what retention.

State the inventory explicitly in the summary, even when it is empty. An empty inventory is
a legitimate and common result — say so. The verdict still follows the rule in *Output*:
`approve` requires no defensible finding, including one raised by the claims below or by a
standing category. A scan that reports findings without ever naming a boundary has skipped
the method.

### Reproduce the claims the target rests on

**A claim the target leans on is checked, not accepted.** A diff argues for its own safety
in prose: a comment saying the caller already validated this, a commit message saying the
path is unreachable, a spec saying a guardrail covers the category, a review note saying the
check happens one layer up. Each such claim, if true, keeps a crossing out of the inventory
or answers a step 2 question without a check in the code.
Identify the target's load-bearing factual claims — the ones whose falsity would change its
conclusion — and attempt to reproduce each before you call the inventory complete. The ones
that bite hardest here are the claims that keep a crossing off the list or reopen one, so
take those first — they order the work, they do not bound it: every load-bearing claim
still gets named and a state. This binds the scan rather than informing it: a caller may restate it in
focus text, but focus weights and does not oblige, and a calling loop may key its exits on
whether a pass actually reproduced anything.

Reproduction is bounded by *Hard constraints* and adds no exception to them. Re-read the
code the claim points at, search for the sibling check the claim says exists, run the
guardrail the claim credits — that last only where running it writes nothing into the
working tree, changes no git state, and executes no code the diff touched. All three, not
any: a guardrail that leaves build output, refreshes a lockfile, or fixes in place lands its
artifacts in the working tree the next pass resolves its target from, and one that runs the
changed code — whether the diff added the guardrail or merely gave it new input — is the
execution *Hard constraints* forbids. A failure of any of those three conditions routes the
claim to not checkable here, naming the rule that stopped you, as does a claim whose only
proof would be an exploit or a probe against a live host; a guardrail that does run under
those three conditions and comes back red refutes the claim.

Every claim you name ends in exactly one of three states, and none may be left unstated:

- **confirmed** — you read the code or ran the guardrail and the claim holds. Name what you
  read or ran; a claim recorded as confirmed on inspection alone says that in those words.
- **refuted** — you checked and it does not hold. This is a finding under the existing
  *Finding bar*, carried in the existing schema with no new field: it names the boundary or
  category the claim was standing in for — or, where it stands for neither, says so and
  stands on the claim itself — cites the claim's own file and lines, and puts the claim, what
  you observed, the command, and the environment in the `body`. A refuted
  load-bearing claim is a defensible finding, so `verdict` is `needs-attention` like any
  other.
- **not checkable here** — the tool, network, platform, or access it needs is absent, the
  command would write into the working tree, change git state, or run the diff's code, or
  *Hard constraints* forbids it outright. This state is a property of the environment, never
  of how much room you had left. Report it as that observation, never as a confirmation. It
  is a finding only where not being able to check it is itself material to the crossing — a
  crossing whose only safety evidence is a gate nobody here could run is often where it is.
  The bar is materiality, not runnability: a scan that filed every un-runnable claim would
  return `needs-attention` on most diffs and teach a reader to skim the ones that matter.

A diff that rests on no such claim gets one sentence saying so, exactly as an empty
inventory does. That is an answer, not a gap.

### Reconcile against the spec's threat model, when the branch wrote one

In branch mode, check whether the diff adds or modifies a spec carrying a threat model —
the boundary inventory, actor model, and control-per-boundary that `$spellcraft` requires of a
security-relevant change. Find it from the diff's own file list (a spec directory such as
`docs/workflow/specs/`); do not go hunting through the repo, and skip this silently when
the diff touches no spec. This is a bounded add-on: form the diff inventory first, so it is
the reconciliation that degrades if budget runs short, never the core scan.

Where a threat model exists, the two inventories are checked against each other, and each
direction is its own finding:

- **In the spec, absent from the diff** — a boundary the design committed to controlling,
  with no control in the code. This is the finding the design-time artifact exists to
  produce, and the reason it is written before the code.
- **In the diff, absent from the spec** — a boundary the implementation introduced that the
  design never considered. Report it against the spec as well as the code; an unrecorded
  boundary means the actor model was never applied to it.
- **Present in both, controlled differently** — the code's control is weaker than, or
  simply not, the one the spec named. Quote both.

The spec is evidence, never an exemption. A boundary the spec lists as out of scope is not
thereby safe: if the diff makes it reachable, the exclusion is stale and that is the
finding.

## 2. Check each crossing

For every boundary in the inventory, check the crossing in this order. Stop at the first
material failure per boundary rather than enumerating every theoretical weakness.

1. **Is it validated?** Type, range, length, encoding, and shape checked before use — and
   checked on the trusted side, not only in a client or a caller.
2. **Is it authorized?** Not just "is the caller logged in" but "may *this* caller act on
   *this* object". A new entry point that skips a check its siblings perform is the finding
   to look hardest for: it is invisible in the new code and only shows up in comparison.
3. **Is it bounded?** Allocation, iteration, recursion depth, request size, timeout, retry
   count. Unbounded work driven by input is a denial-of-service path even when nothing is
   corrupted.
4. **Is it encoded for its destination?** Parameterized query, argv-form exec rather than a
   shell string, escaped template output, path resolved and confined to its intended root,
   URL validated against an allowlist before it is fetched.
5. **What does it leak on failure?** Error text, logs, and telemetry carrying credentials,
   tokens, PII, or internal structure. Check the error path specifically — it is the one the
   happy-path test never covers.

## 3. Standing categories

Independent of the boundary inventory, check the diff for these. They are the ones that
recur across languages and do not announce themselves as boundaries:

- **Secrets** — credentials, tokens, or keys in source, fixtures, logs, URLs, or CI config;
  a token granted broader scope than the step it serves; a secret reaching a place it
  outlives (an env var in an image layer, a query string in an access log).
- **Cryptography** — hand-rolled constructions, an algorithm chosen for speed, a comparison
  that is not constant-time where it guards a secret, a general-purpose RNG used for
  something security-bearing, a verification step that is skipped or made optional.
- **Deserialization and archive handling** — formats that construct objects or evaluate
  content, XML with external entities enabled, archive extraction that trusts member paths.
- **Supply chain** — a new dependency, a version floated rather than pinned, a lockfile
  bypass, an install-time script, a CI action referenced by a mutable tag rather than a SHA.
- **Permissions and defaults** — file modes, umask, world-readable state, a permissive CORS
  or cookie attribute, disabled certificate verification, a debug or verbose path that
  survives into production config.

**Prefer the guardrail that already covers it.** Where the repo runs a tool that catches a
category mechanically — `zizmor` for GitHub Actions, `shellcheck` for shell quoting and
word-splitting, a dependency auditor, a secrets scanner — a clean run of that tool is
stronger evidence than this scan's inspection. Do not re-report what a green guardrail
already covers. If the guardrail exists but does not run in CI, *that* is the finding, and
it is worth more than the individual instance that prompted it.

## Finding bar

Every finding names a boundary from step 1 or a category from step 3, and answers:

1. What crosses, from where, under whose control?
2. What check is missing or insufficient?
3. What can an actor who controls that input actually cause?

4. What concrete change closes it?

The one exception is the **refuted-claim finding** from *Reproduce the claims the target
rests on*: it need not name a boundary or a category — where the claim stands in for
neither, it says so and stands on the claim itself — and its four questions are answered by
the claim, what you observed, the command you ran, and the environment you ran it in,
which that bullet already requires in `body`. Every other finding names a boundary or a
category as above.

**Reachability is part of the claim, not a caveat on it.** A missing check on a path no
untrusted actor can reach is a lower severity than the same omission on a public route, and
the finding says which it is. Do not report a category as a finding because the category
exists in the codebase — report it because this diff created, widened, or failed to close a
path. Do not invent a threat actor a system's deployment does not have.

Prefer one traced finding over several pattern-matched ones. If the change genuinely touches
no boundary and trips no category, say so plainly and return no findings — an empty result
is the honest outcome for most diffs.

## Output

Exactly `$gauntlet`'s schema, severity vocabulary (`critical | high | medium | low`), and
markdown/JSON forms, so a caller can consume either command's artifact without branching.
Three differences in how the fields are filled:

- **`summary` opens with the boundary inventory from step 1** — the surface you enumerated,
  before any verdict. That is what a reader needs to judge whether the scan looked in the
  right places, and it is the field a later reviewer checks the scan against.
- **The claims block follows the inventory immediately**, still ahead of any verdict-bearing
  prose: each load-bearing claim you named, claim versus observation, the command you ran,
  and the environment you ran it in. Open it by naming what it covers: the target's
  load-bearing claims, with the ones the inventory rests on first. That is the set a calling
  loop reads back when it keys an exit on the list, so name it as the rule it is rather than
  as a note on this scan's reach. The order is fixed: the inventory leads because a claim
  qualifies a boundary and cannot be read before the surface it qualifies, and the claims
  block stays labelled as its own so a loop can lift it back out. A caller may tell you the
  claims lead the `summary` — `$trial-loop` appends exactly that to the focus it transmits on
  every pass, quoting `$gauntlet`'s Method. Here the inventory leads and the claims block
  follows it, and this rule wins over focus.
- **`suppressions` carries governing-ADR re-litigation only**, on the same terms as
  `$gauntlet`: a decision an accepted ADR settled is not re-argued here either.
  A security finding that cites a fact outside that record is new risk, not re-litigation —
  report it. An accepted ADR never settles a vulnerability in the code implementing it.

`verdict` is `approve` only when no defensible finding exists; otherwise `needs-attention`.

## Hard constraints

- Never run an exploit, probe a live host, or execute code from the diff to prove a finding.
  This static-inspection bound governs proving a vulnerability: a finding stands on the code
  path you can point to. Running a repository guardrail to reproduce a claim is not proving
  a finding — it is bounded by the three conditions in *Reproduce the claims the target
  rests on*, not by this bullet.
- Do not invent files, lines, routes, or callers. If a finding depends on inference about an
  unseen caller, say so in the body and lower the confidence honestly.
- This is a diff-scoped pass, not a codebase audit. Pre-existing weaknesses the change
  neither introduces nor touches are out of scope — note them once in `next_steps` if they
  bear on the change, and do not let them hold the verdict.

## Examples

```
$detect-evil --base main                      # branch diff vs main
$detect-evil --working-tree                   # uncommitted changes
$detect-evil src/auth/*.ts                    # explicit files
$detect-evil --base main focus on the new webhook handler
$detect-evil --json --out "$TMPDIR/detect-evil-43-feat-authz.json" --base main
                                              # name the artifact per run — a fixed
                                              # filename collides when several runs
                                              # scan in parallel
$trial-loop --reviewer detect-evil --base main # settled standalone security-review lifecycle
```

> Reminder: the verdict is a checkpoint, not a finish line. Hand it back to your workflow.
