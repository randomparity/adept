# Provider model mapping

Companion to [model selection](model-selection.md). Verified **2026-10-25** against the
primary sources below; read-only version/help inspected with Codex 0.164.0 and Claude Code
2.1.304, plus the active native dispatch schema. No provider task/session was launched.
These are candidate mappings, not an account inventory. Runtime support and effective
instructions take precedence. Maintain identifiers, aliases, supported control values and
provider-specific examples here rather than in consumer skills.

## Codex with OpenAI

| Tier | Candidate |
|---|---|
| Mechanical | `gpt-6-luna` |
| Standard | `gpt-6.1-sol`; `gpt-6-sol` remains available during rollout |
| Deep | `gpt-6-astra`; `gpt-5.6-sol` is another deep candidate |

The [official model guide](https://learn.chatgpt.com/docs/models) identifies these models and
roles; the [API guide](https://developers.openai.com/api/docs/guides/latest-model) separately
describes the current family. Earlier `gpt-5.6-luna` and `gpt-5.6-terra` remain rollout
alternatives when runtime evidence establishes the required capability. Final review selects
the strongest permitted model actually available. CLI `--model` (or `-m`) selects a model;
for example:

```sh
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"'
```

The [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)
defines `model_reasoning_effort` for supported models. Conservative candidates are `low`
(economical), `medium` (balanced), and `high` (deliberative); verify the model's exposed set.
The config reference now describes a model-advertised string, including `xhigh`, `max`, and
`ultra`, rather than a fixed enum. The model guide limits GPT-6 Luna to Max, excluding Ultra;
Ultra includes delegation behavior, not just additional reasoning. API reasoning support is
separate from client selectors. Do not extrapolate values to every model or dispatch surface.
For any unsupported requested value, retain a verified supported default and record the
unavailable control, or name the unmet requirement. Native dispatch tool schemas govern
which model/effort arguments that invocation accepts; CLI flags are not tool arguments.

## Claude Code with Anthropic or hosted Claude

| Tier | Candidate alias; direct Anthropic example |
|---|---|
| Mechanical | `haiku`; `claude-haiku-5-5` |
| Standard | `sonnet`; `claude-sonnet-5-5` |
| Deep | `fable`; `claude-fable-5-1`; `opus` / `claude-opus-5-5` is another deep candidate |

[Model configuration](https://code.claude.com/docs/en/model-config) documents aliases,
provider differences and controls. Select with `--model`; use `--effort` when supported:

```sh
claude --model claude-sonnet-5-5 --effort medium
```

Claude Code lists Fable 5.1/5, Opus 5.5/5/4.8/4.7, Sonnet 5.5/5 and Haiku 5.5 for
`low`, `medium`, `high`, `xhigh`, `max`; Opus/Sonnet 4.6 omit `xhigh`. Models outside its
list have no Claude Code effort control. The
[API effort catalog](https://platform.claude.com/docs/en/build-with-claude/effort) has separate
coverage and defaults. In Claude Code, 5.5 models default to `medium`, Opus 4.7
to `xhigh`, other listed models to `high`, subject to explicit choices and settings. Sonnet
5.5 defaults to `high` on the API. Economical/balanced/deliberative candidates remain
`low`/`medium`/`high`. Claude Code lowers unsupported requests to the highest supported level
at or below the request, subject to caps. Record the effective result. Saved effort in
`modelSettings` or `effortLevel` excludes `max`; `--effort` accepts it. The API catalog does not prove worker-tool support.

The direct 5.5 candidates require Claude Code at least 2.1.280 (Opus), 2.1.284 (Sonnet),
and 2.1.293 (Haiku). Aliases vary by provider and configuration; on the Anthropic API,
`opus`, `sonnet`, and `haiku` currently resolve to 5.5, while hosted aliases can lag.
Bedrock uses inference profiles, Foundry deployment names, and Google's Agent Platform version names; do not transplant direct Anthropic IDs.
`best` can fall back to `opus`; confirm its resolution before using it for required review.
Unknown or unmapped deployments use the policy's verified-default-or-unmet path.

## Refresh procedure

The maintainer changing this mapping owns its refresh. On a routine model release or a runtime
mismatch:

1. Reopen the primary pages, check deprecations and provider/harness distinctions, and inspect
   the relevant current host controls. Record the verification date and inspected harness version.
2. Update only this mapping's candidates, control support, examples, and source links. Keep
   tier meanings and phase defaults stable; a capability-policy change needs its own scope.
3. Walk through both harnesses, an explicit override, an unavailable preferred model,
   unsupported effort and an unknown provider. Require a supported recorded choice or named
   unmet capability. Preserve explicit overrides and recheck strongest-available review; never
   manufacture an alias or control. Root CLI/startup controls do not establish an agent-callable
   root switch or worker dispatch arguments.
4. Check the diff: consumer skills and stable policy need no routine identifier edit. Run
   repository link/plugin/version guardrails; release metadata still receives its required bump.

Inspection and walkthroughs verify this reference, not account access or worker assignment.
Do not install configuration, invoke a provider client, or switch sessions as part of a refresh.
