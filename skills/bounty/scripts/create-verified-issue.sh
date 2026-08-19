#!/usr/bin/env bash
set -euo pipefail

# ripgrep applies the contents of RIPGREP_CONFIG_PATH as arguments ahead of the
# ones passed below, so a personal ripgreprc would otherwise choose what the
# checks here match. Two of them validate a URL and the created issue's body
# before this script reports success; --invert-match inverts both.
unset RIPGREP_CONFIG_PATH

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
tracker="$script_dir/../../quest-log/assets/tracker.sh"

usage() {
	printf 'usage: %s --repo OWNER/NAME --title TITLE --body-file PATH' "${0##*/}" >&2
	printf ' [--label LABEL]... [--parent NUMBER]\n' >&2
	exit 2
}

diagnostic_value() {
	local value=$1
	if ((${#value} > 200)); then
		value=${value:0:200}'…'
	fi
	jq -Rrn --arg value "$value" '$value | @json'
}

repo=
title=
body_file=
parent=
labels=()

while (($#)); do
	case $1 in
	--repo)
		(($# >= 2)) || usage
		repo=$2
		shift 2
		;;
	--title)
		(($# >= 2)) || usage
		title=$2
		shift 2
		;;
	--body-file)
		(($# >= 2)) || usage
		body_file=$2
		shift 2
		;;
	--label)
		(($# >= 2)) || usage
		labels+=("$2")
		shift 2
		;;
	--parent)
		(($# >= 2)) || usage
		parent=$2
		shift 2
		;;
	*) usage ;;
	esac
done

[[ -n $repo && -n $title && -n $body_file ]] || usage
[[ -f $body_file && -s $body_file ]] || {
	printf 'body file must be a populated regular file: %s\n' "$body_file" >&2
	exit 2
}
[[ -z $parent || $parent =~ ^[0-9]+$ ]] || usage

create_args=(--title "$title" --body-file "$body_file")
for label in "${labels[@]+"${labels[@]}"}"; do
	create_args+=(--label "$label")
done
if [[ -n $parent ]]; then
	create_args+=(--parent "$parent")
fi

# The engine reports its taxonomy class; this script's exit surface is 2 for
# usage and 1 for any operational failure, so an unreachable repository must not
# surface as 2 and read as "called with bad arguments".
target_status=0
canonical_url=$("$tracker" target-url --target "$repo" 2>&1) || target_status=$?
if ((target_status != 0)); then
	printf 'canonical repository URL could not be resolved for %s\n' \
		"$(diagnostic_value "$repo")" >&2
	exit 1
fi
canonical_url=${canonical_url%/}
canonical_path=${canonical_url#https://}
canonical_path=${canonical_path#*/}
if ! rg -q '^https://[^/[:space:]]+/[^/[:space:]]+/[^/[:space:]]+$' <<<"$canonical_url" ||
	[[ $canonical_path != "$repo" ]]; then
	printf 'canonical repository URL is malformed or does not match %s\n' \
		"$(diagnostic_value "$repo")" >&2
	exit 1
fi

create_status=0
created_output=$("$tracker" create --target "$repo" "${create_args[@]}" 2>&1) ||
	create_status=$?
# The engine reports a taxonomy class; this script's contract reports 1. The
# distinction between "failed" and "failed but may have landed" is carried by
# the URL check below, exactly as it was before.
create_class=$create_status
((create_status == 0)) || create_status=1
issue_url_pattern='https://[^/[:space:]]+/[^/[:space:]]+/[^/[:space:]]+/issues/[0-9]+'
issue_url=$(printf '%s\n' "$created_output" | rg -o "$issue_url_pattern" | tail -n 1 || true)
# A partial carrying no identity means the write landed and only its URL could
# not be parsed. Reporting that as a failed command invites a re-run and a
# duplicate live issue, which is the outcome this script exists to prevent.
if ((create_class == 5)) && [[ -z $issue_url ]]; then
	printf 'issue was created but its durable issue URL could not be resolved;' >&2
	printf ' creation was not retried\n' >&2
	exit 1
fi
if ((create_status != 0)); then
	if [[ -n $issue_url && $issue_url == "$canonical_url/issues/${issue_url##*/}" ]]; then
		printf '%s: creation command failed with exit %d; creation was not retried\n' \
			"$issue_url" "$create_status" >&2
	else
		printf 'creation command failed with exit %d; durable issue URL could not be resolved;' \
			"$create_status" >&2
		printf ' creation was not retried\n' >&2
	fi
	exit 1
fi
if [[ -z $issue_url ]]; then
	printf 'issue was created but its durable issue URL could not be resolved;' >&2
	printf ' creation was not retried\n' >&2
	exit 1
fi
issue_number=${issue_url##*/}
if [[ $issue_url != "$canonical_url/issues/$issue_number" ]]; then
	printf 'created issue URL does not match canonical repository URL %s: %s;' \
		"$(diagnostic_value "$canonical_url")" "$(diagnostic_value "$issue_url")" >&2
	printf ' creation was not retried\n' >&2
	exit 1
fi

# Past this point the issue exists and its URL has been checked, so every exit
# here has to say so: a bare non-zero from an unguarded `mktemp` or from an
# unguarded removal inside the EXIT trap is the silent failure lines 109-111
# describe, and the caller's remedy for a silent failure is the re-run that
# creates a duplicate live issue.
#
# The two halves therefore end differently. A scratch file that cannot be
# created leaves the read-back unperformed, which is a real failure and reports
# as one -- naming the issue so nobody retries the write. A scratch file that
# cannot be removed after a run that verified everything has broken nothing;
# reporting it as a failure would invite exactly that re-run to reclaim a temp
# file. So cleanup names the retained path and leaves the status alone, which is
# where this diverges from the gate scripts, whose exit 1 means something else.
view_err=$(mktemp) || {
	printf '%s: read-back could not be attempted (no scratch file);' "$issue_url" >&2
	printf ' creation was not retried\n' >&2
	exit 1
}
# shellcheck disable=SC2329 # run by the EXIT trap, not called directly
cleanup() {
	local exit_status=$?
	if ! rm -f -- "$view_err"; then
		printf '%s: retained scratch path: %s\n' "$issue_url" "$view_err" >&2
	fi
	exit "$exit_status"
}
trap cleanup EXIT
view_status=0
issue_json=$("$tracker" view --target "$repo" "$issue_number" 2>"$view_err") ||
	view_status=$?
if ((view_status != 0)); then
	if rg -q 'malformed or incomplete JSON' "$view_err"; then
		printf '%s: read-back returned malformed or incomplete JSON\n' \
			"$issue_url" >&2
	else
		printf '%s: read-back failed; creation was not retried\n' "$issue_url" >&2
	fi
	exit 1
fi
if ! jq -e '
	type == "object"
	and (.id | type == "string")
	and (.title | type == "string")
	and (.body | type == "string")
	and (.labels | type == "array")
	and all(.labels[]; type == "string")
	and (.url | type == "string")
	and ((.parent == null) or (.parent | type == "string"))
' \
	>/dev/null 2>&1 <<<"$issue_json"; then
	printf '%s: read-back returned malformed or incomplete JSON\n' "$issue_url" >&2
	exit 1
fi

observed_title=$(jq -r '.title' <<<"$issue_json")
observed_body=$(jq -r '.body' <<<"$issue_json")
observed_number=$(jq -r '.id' <<<"$issue_json")
observed_url=$(jq -r '.url' <<<"$issue_json")
observed_parent=none
if [[ -n $parent ]]; then
	observed_parent=$(jq -r '.parent // "none"' <<<"$issue_json")
fi
observed_labels=$(jq -r '.labels[]' <<<"$issue_json")
mismatches=()

if [[ $observed_number != "$issue_number" ]]; then
	mismatches+=("number: expected #$issue_number, observed #$observed_number")
fi
if [[ $observed_url != "$issue_url" ]]; then
	expected_display=$(diagnostic_value "$issue_url")
	observed_display=$(diagnostic_value "$observed_url")
	mismatches+=("url: expected $expected_display, observed $observed_display")
fi
if [[ $observed_title != "$title" ]]; then
	expected_display=$(diagnostic_value "$title")
	observed_display=$(diagnostic_value "$observed_title")
	mismatches+=("title: expected $expected_display, observed $observed_display")
fi
if [[ -z $observed_body ]]; then
	mismatches+=("body: expected non-empty, observed empty")
fi
for section in 'Problem' 'Evidence' 'Expected' 'Proposed approach'; do
	if ! rg -q "^## ${section}\r?$" <<<"$observed_body"; then
		mismatches+=("body: missing section '$section'")
	fi
done
for label in "${labels[@]+"${labels[@]}"}"; do
	found=false
	while IFS= read -r observed_label; do
		if [[ $observed_label == "$label" ]]; then
			found=true
			break
		fi
	done <<<"$observed_labels"
	if [[ $found == false ]]; then
		mismatches+=("label: missing $(diagnostic_value "$label")")
	fi
done
if [[ -n $parent && $observed_parent != "$parent" ]]; then
	if [[ $observed_parent == none ]]; then
		mismatches+=("parent: expected #$parent, observed none")
	else
		mismatches+=("parent: expected #$parent, observed #$observed_parent")
	fi
fi

if ((${#mismatches[@]})); then
	printf '%s: verification failed\n' "$issue_url" >&2
	printf '  - %s\n' "${mismatches[@]}" >&2
	exit 1
fi

printf '%s\n' "$issue_url"
