set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  just --list

hooks:
  #!/usr/bin/env bash
  set -euo pipefail
  marker='# adept: managed pre-push hook'
  hook_dir="$(git rev-parse --git-path hooks)"
  destination="$hook_dir/pre-push"
  source='scripts/pre-push-hook'
  prek install
  mkdir -p "$hook_dir"
  if [[ -L $destination || ( -e $destination && ! -f $destination ) ]]; then
    echo "hooks: refusing unsafe pre-push destination: $destination" >&2
    exit 1
  fi
  if [[ -f $destination ]] && ! rg --no-config -qxF "$marker" "$destination"; then
    echo "hooks: refusing foreign pre-push hook: $destination" >&2
    exit 1
  fi
  temporary="$(mktemp "$hook_dir/.pre-push.XXXXXX")"
  trap 'rm -f "$temporary"' EXIT
  cp "$source" "$temporary"
  chmod +x "$temporary"
  mv -f "$temporary" "$destination"
  trap - EXIT

records:
  #!/usr/bin/env bash
  set -euo pipefail
  ./.github/scripts/check-records-test.sh
  # Only the adr profile is enabled. A profile fails when its record directory
  # exists at neither the base ref nor the tree, and this repo has no deferral
  # records yet -- docs/debt/ cannot be created empty either, because the debt
  # profile (unlike adr) exempts no README. Add "debt" here in the same commit
  # as the first deferral record.
  RECORD_PROFILES="adr" ./.github/scripts/check-records.sh
  shared_assets="check-records.sh check-records-test.sh migrate-records.sh"
  shared_assets="$shared_assets profiles/adr.sh profiles/debt.sh records.yml"
  for asset in $shared_assets; do
    root_asset=".github/scripts/$asset"
    skill_asset="skills/tome-of-lore/assets/$asset"
    if ! cmp -s "$root_asset" "$skill_asset"; then
      echo "record gate mismatch: $skill_asset differs from $root_asset" >&2
      exit 1
    fi
  done

lint:
  #!/usr/bin/env bash
  set -euo pipefail
  # The list is captured to a file rather than read from a process substitution:
  # `while ... done < <(lister)` reports the loop's status, not the lister's, so
  # a discovery that stopped on a file it could not classify would lint a short
  # list and pass. check-ripgrep-config.sh captures it for the same reason.
  sources="$(mktemp)"
  trap 'rm -f "$sources"' EXIT
  ./scripts/list-shell-sources.sh --all -z >"$sources"
  files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done <"$sources"
  # -x follows `# shellcheck source=` directives. Without it the suites that
  # source scripts/test-fixture-helpers.sh pass here only because the batch
  # happens to include the helper, while a per-file run reports SC1091.
  shellcheck -x "${files[@]}"

format-check:
  #!/usr/bin/env bash
  set -euo pipefail
  # Captured rather than read from a process substitution, for the reason the
  # lint recipe above gives.
  sources="$(mktemp)"
  trap 'rm -f "$sources"' EXIT
  ./scripts/list-shell-sources.sh --tabs -z >"$sources"
  tabs=()
  while IFS= read -r -d '' file; do
    tabs+=("$file")
  done <"$sources"
  ./scripts/list-shell-sources.sh --two-space -z >"$sources"
  two_space=()
  while IFS= read -r -d '' file; do
    two_space+=("$file")
  done <"$sources"
  shfmt -d "${tabs[@]}"
  shfmt -i 2 -d "${two_space[@]}"

test:
  #!/usr/bin/env bash
  set -euo pipefail
  # Captured rather than read from a process substitution, for the reason the
  # lint recipe above gives. The count floor below catches only a discovery
  # that returned nothing at all; a `git ls-files` that emits some paths and
  # then dies leaves the count non-zero and the run green over a suite set
  # nobody checked was complete.
  suites="$(mktemp)"
  trap 'rm -f "$suites"' EXIT
  git ls-files -z -- '*-test.sh' >"$suites"
  count=0
  while IFS= read -r -d '' suite; do
    case $suite in
    .github/scripts/check-records-test.sh | \
      skills/tome-of-lore/assets/check-records-test.sh)
      continue
      ;;
    esac
    printf '== %s\n' "$suite"
    # The loop's stdin is the suite list, so a suite that read stdin would
    # swallow the suites queued behind it and truncate the run to another
    # green partial pass. test-fixture-helpers-test.sh closes a child's stdin
    # for the same reason.
    "./$suite" </dev/null
    count=$((count + 1))
  done <"$suites"
  if ((count == 0)); then
    printf 'test: no suites discovered\n' >&2
    exit 1
  fi
  printf 'test: %s suites passed\n' "$count"

shape-check:
  ./scripts/check-skill-shape.sh

public-safety:
  ./scripts/check-public-safety.sh

ripgrep-config-check:
  ./scripts/check-ripgrep-config.sh

plugin-check:
  #!/usr/bin/env bash
  set -euo pipefail
  claude plugin validate ./
  # The validator reads the Claude manifests only. It passes green with
  # .mcp.json and .codex-plugin/plugin.json both unparseable, so without these
  # a typo in either ships and surfaces the next time someone runs Codex or
  # starts a server. Parseability plus the one cross-reference that can rot --
  # the skills path Codex is pointed at -- is the whole check; the rest of each
  # manifest's meaning belongs to its own harness.
  jq -e . .mcp.json >/dev/null
  jq -e . .codex-plugin/plugin.json >/dev/null
  skills_path="$(jq -r '.skills' .codex-plugin/plugin.json)"
  if [[ ! -d $skills_path ]]; then
    echo "plugin-check: .codex-plugin/plugin.json names a missing skills path: $skills_path" >&2
    exit 1
  fi

actions-check:
  actionlint
  zizmor --offline .github/workflows/

commit-check: lint format-check public-safety

push-check:
  ./scripts/verify-push.sh

verify: records commit-check shape-check ripgrep-config-check plugin-check test actions-check
  prek run --all-files --stage pre-commit --dry-run

ci:
  #!/usr/bin/env bash
  set -euo pipefail
  just verify
