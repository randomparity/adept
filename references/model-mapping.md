# Provider model mapping

Companion to [model selection](model-selection.md). Verified **2026-09-12** against the
primary sources below; CLI controls inspected with Codex 0.154.0 and Claude Code 2.1.268.
These are candidate mappings, not an account inventory. Runtime support and effective
instructions take precedence. Maintain identifiers, aliases, supported control values and
provider-specific examples here rather than in consumer skills.

## Codex with OpenAI

| Tier | Candidate |
|---|---|
| Mechanical | `gpt-5.6-luna` |
| Standard | `gpt-5.6-terra` |
| Deep | `gpt-6-astra`; `gpt-5.6-sol` is another deep candidate |

The [official model guide](https://learn.chatgpt.com/docs/models) identifies these models and
roles. Final review selects the strongest permitted model actually available. CLI `--model`
(or `-m`) selects a model; for example:

```sh
codex -m gpt-5.6-terra -c 'model_reasoning_effort="medium"'
```

The [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)
defines `model_reasoning_effort` for supported models. Conservative candidates are `low`
(economical), `medium` (balanced), and `high` (deliberative); verify the model's exposed set.
The model guide also shows `xhigh`, `max`, and `ultra` in current selectors, while the config
reference lists a narrower enum. Do not extrapolate selector values to every CLI or dispatch
surface. Ultra includes delegation behavior, not just additional reasoning.
For any unsupported requested value, retain a verified supported default and record the
unavailable control, or name the unmet requirement. Native dispatch tool schemas govern
which model/effort arguments that invocation accepts; CLI flags are not tool arguments.

## Claude Code with Anthropic or hosted Claude

| Tier | Candidate alias; direct Anthropic example |
|---|---|
| Mechanical | `haiku` |
| Standard | `sonnet`; `claude-sonnet-5` |
| Deep | `fable`; `claude-fable-5-1`; `opus` is another deep candidate |

[Model configuration](https://code.claude.com/docs/en/model-config) documents aliases,
provider differences and controls. Select with `--model`; use `--effort` when supported:

```sh
claude --model claude-sonnet-5 --effort medium
```

Fable 5.1/5, Opus 5/4.8/4.7 and Sonnet 5 support `low`, `medium`, `high`, `xhigh`, `max`;
Opus/Sonnet 4.6 omit `xhigh`; unlisted models have no effort control. Economical/balanced/
deliberative candidates are `low`/`medium`/`high`. Model and organization limits still apply;
Claude Code can lower an unsupported effort. Record the effective result, not just the request.

Aliases vary by provider and configuration. Bedrock uses inference profiles, Foundry deployment
names, and Google's Agent Platform version names; do not transplant direct Anthropic IDs.
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
   unmet capability. Recheck strongest-available review; never manufacture an alias or control.
4. Check the diff: consumer skills and stable policy need no routine identifier edit. Run
   repository link/plugin/version guardrails; release metadata still receives its required bump.

Inspection and walkthroughs verify this reference, not account access or worker assignment.
Do not install configuration, invoke a provider client, or switch sessions as part of a refresh.
