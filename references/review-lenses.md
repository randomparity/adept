# Review lenses

A lens is named focus text for an existing reviewer, not a reviewer, skill, target, or flag. It
changes the reading technique a reviewer weights; it never narrows the finding bar or permits the
reviewer to ignore another material issue.

## Selection

Choose the reviewer through the caller's existing route before choosing a lens. Broad adversarial
review uses `gauntlet`; a security review selected by the caller's security triggers or explicit
`--reviewer detect-evil` uses `detect-evil`. The `security` lens is valid only on that security
route. A lens name in focus text never changes reviewer selection, so it cannot turn `gauntlet`
into a substitute security reviewer.

For the first review, take the first matching shape in the table that is compatible with the
selected reviewer. Append any caller-specific target context after the preset instead of replacing
either one. If no more specific row matches, use `failure-injection`.

| Lens | Use when the target primarily contains | Focus text |
|---|---|---|
| `security` | A review already routed to `detect-evil` | Inventory trust boundaries; test validation, authorization, secrets, permissions, and security defaults. |
| `consumer-installation` | Packaged skills, invocations, paths, or assets | Read as a consumer outside the source checkout. Verify every path, invocation, and asset resolves from `<plugin-root>`, independent of cwd. |
| `downstream-reader` | Structured fields, records, annotations, manifests, or generated formats | Identify every reader of each changed field or format and verify each still parses and interprets it correctly. |
| `operator-cold-resume` | Workflow state, labels, handoffs, recovery, or durable progress | Resume as a human or fresh session using durable tracker and branch state only; find any fact that exists only in the transcript. |
| `host-portability` | Shell, CI, commands, or platform-sensitive operations | Check declared target hosts: shell floors, BSD/GNU differences, tool-call shell behavior, paths, and architecture assumptions. |
| `anatomy-rules` | Plugin layout, skills, references, executables, fixtures, or gates | Apply the repository's artifact and layout rules: instruction versus program, executable bar, process lifetime, prose assertions, and fixture placement. |
| `public-safety` | Public docs, issue/PR content, logs, or shared configuration | Trace every emitted or committed value for host identity, credentials, private context, and unsafe provenance. |
| `cost` | Dispatch, review, CI, gate, or retry behavior | Count model dispatches, review rounds, and full-suite runs on the ordinary and failure paths. |
| `simplification-first` | New helpers, abstractions, refactors, or disproportionate designs | Apply `$dispel`'s perspective: find what can be deleted and whether the change is smaller than the problem it removes. |
| `failure-injection` | Runtime behavior, algorithms, parsers, or no more specific shape | Construct bad inputs, partial failures, retries, races, and degraded dependencies; trace recovery and cleanup. |

## Independent reviews and loop iterations

A second independent review over unchanged target bytes uses a different lens. Select the next
matching row; if there is none, use `failure-injection`, then `simplification-first`, choosing the
first one different from the prior lens. This applies when a single pass escalates into a new
review run and whenever a caller repeats a single pass without changing the target.

Iterations within one `$trial-loop` run are not independent lens selections. Resolve the lens and
composed focus before iteration 1, then keep both unchanged for every fixing and confirming pass.
The confirming pass reviews the fixes using the same technique; it does not spend a new angle.

Changing lenses never changes reviewer selection. In particular, every pass on a security route
remains `detect-evil`, even when an independent second pass uses a non-`security` lens.
