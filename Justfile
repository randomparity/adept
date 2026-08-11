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
    skill_asset="skills/decision-records/assets/$asset"
    if ! cmp -s "$root_asset" "$skill_asset"; then
      echo "record gate mismatch: $skill_asset differs from $root_asset" >&2
      exit 1
    fi
  done

lint:
  #!/usr/bin/env bash
  set -euo pipefail
  files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(./scripts/list-shell-sources.sh --all -z)
  shellcheck "${files[@]}"

format-check:
  #!/usr/bin/env bash
  set -euo pipefail
  tabs=()
  while IFS= read -r -d '' file; do
    tabs+=("$file")
  done < <(./scripts/list-shell-sources.sh --tabs -z)
  two_space=()
  while IFS= read -r -d '' file; do
    two_space+=("$file")
  done < <(./scripts/list-shell-sources.sh --two-space -z)
  shfmt -d "${tabs[@]}"
  shfmt -i 2 -d "${two_space[@]}"

test:
  #!/usr/bin/env bash
  set -euo pipefail
  count=0
  while IFS= read -r -d '' suite; do
    case $suite in
    .github/scripts/check-records-test.sh | \
      skills/decision-records/assets/check-records-test.sh)
      continue
      ;;
    esac
    printf '== %s\n' "$suite"
    "./$suite"
    count=$((count + 1))
  done < <(git ls-files -z -- '*-test.sh')
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
  claude plugin validate ./

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
