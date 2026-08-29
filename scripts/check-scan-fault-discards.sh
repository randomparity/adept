#!/usr/bin/env bash
set -euo pipefail

# ADR 0047: a status-discard idiom in a gate script must carry an inline
# '# scan-fault: deliberate — <reason>' pragma, or the gate fails. The rule it
# enforces is ADR 0005's: a scan whose result feeds a verdict captures its own
# exit status and never collapses a fault into a verdict.
#
# The match set, per line, after heredoc and comment skipping:
#   - a trailing true- or colon-discard, a continue-discard, or a return-0 /
#     exit-0 discard on a command that is not a test and not a pure builtin;
#   - a command substitution inside a -n / -z test.
# Excluded by construction: [ ... ], [[ ... ]], (( ... )) and test commands;
# pure builtins with no pipeline and no command substitution; comment lines;
# heredoc bodies. The required capture form '|| status=$?' never matches.
#
# Exit 0 clean, 1 findings, 2 this script could not run (a source listing that
# failed, a file that could not be opened, a bad argument). This script is
# itself a scan whose result feeds a verdict, so it follows the rule it
# enforces: it captures its own statuses and reports its own faults.

usage() {
	cat <<'EOF'
usage: check-scan-fault-discards.sh [--files file...]

Scans the repository's gate scripts (the shell-source inventory minus test
scripts) for status-discard idioms without a '# scan-fault: deliberate — <reason>'
pragma. With --files, scans exactly the named files.
EOF
}

# Regexes in variables: bash 3.2 (macOS system bash) mis-parses some quoted regex
# literals inside [[ =~ ]].
heredoc_pat='<<[[:space:]]*(-?)(['"'"'"]?)([A-Za-z0-9_]+)'
comment_pat='^[[:space:]]*#'
pragma_pat='scan-fault:[[:space:]]deliberate[[:space:]]—[[:space:]]*[^[:space:]]'
test_preceding_pat='(\]|\)[[:space:]]*\))[[:space:]]*(\|\||&&)'
test_cmd_pat='^[[:space:]]*test[[:space:]]'
var_assign_pat='^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+'

# Pure builtins: their own status is never a scan verdict, and with no pipeline
# and no command substitution they cannot wrap a scanning stage.
# When a line contains a pipeline (|) or command substitution ($(), the builtin
# is not exempt because it may wrap a scanning command.
builtins='printf echo read : true false unset local export cd shift return exit break continue trap umask set eval source . declare typeset pwd type hash let wait getopts times ulimit alias bg fg jobs kill help compgen complete dirs disown enable history logout popd pushd readonly shopt suspend builtin exec caller bind fc mapfile readarray coproc'

trailing_shapes=(
	'trailing true-discard|\|\|[[:space:]]+true'
	'trailing colon-discard|\|\|[[:space:]]*:'
	'continue-discard|(\|\||&&)[[:space:]]+continue'
	'return-0-discard|(\|\||&&)[[:space:]]+return[[:space:]]+0'
	'exit-0-discard|(\|\||&&)[[:space:]]+exit[[:space:]]+0'
)

# The substitution-in-test shape matches both bracket styles [ ... ] and [[ ... ]]
# and test builtins, with or without double quotes around the substitution.
substitution_shapes=(
	'substitution-in-test|(\[\[?|test)[[:space:]]+-(n|z)[[:space:]]+"?\$\('
)

# First token after leading VAR=value assignments. Naive by design: a value
# containing spaces is mis-stripped, but such lines carry a pipeline or a
# substitution and are not builtin-exempt anyway.
command_word() {
	local rest=$1
	rest=${rest#"${rest%%[![:space:]]*}"}
	while [[ $rest =~ $var_assign_pat ]]; do
		rest=${rest#*"${BASH_REMATCH[0]}"}
		rest=${rest#"${rest%%[![:space:]]*}"}
	done
	printf '%s\n' "${rest%%[[:space:]]*}"
}

findings=0

scan_file() {
	local file=$1 line lineno=0 pending="" tabs="" first rest m word is_builtin line_before shape pat
	if ! { exec 3<"$file"; } 2>/dev/null; then
		printf 'scan-fault-guard: could not open %s\n' "$file" >&2
		exit 2
	fi
	while IFS= read -r line <&3; do
		lineno=$((lineno + 1))
		if [ -n "$pending" ]; then
			first=${pending%% *}
			if [ "$line" = "$first" ] ||
				{ [ "${tabs%% *}" = 1 ] && [ "${line#"${line%%[!$'\t']*}"}" = "$first" ]; }; then
				case "$pending" in
				*' '*) pending=${pending#* } ;;
				*) pending="" ;;
				esac
				case "$tabs" in
				*' '*) tabs=${tabs#* } ;;
				*) tabs="" ;;
				esac
			fi
			continue
		fi
		[[ $line =~ $comment_pat ]] && continue
		rest=$line
		while [[ $rest =~ $heredoc_pat ]]; do
			m=${BASH_REMATCH[0]}
			pending="$pending ${BASH_REMATCH[3]}"
			if [ -n "${BASH_REMATCH[1]}" ]; then
				tabs="$tabs 1"
			else
				tabs="$tabs 0"
			fi
			rest=${rest#*"$m"}
		done
		pending=${pending# }
		tabs=${tabs# }
		[[ $line =~ $pragma_pat ]] && continue
		if [[ $line =~ $test_preceding_pat ]] || [[ $line =~ $test_cmd_pat ]]; then
			continue
		fi
		for shape in "${trailing_shapes[@]}"; do
			pat=${shape#*|}
			if [[ $line =~ $pat ]]; then
				word=$(command_word "$line")
				is_builtin=no
				case " $builtins " in
				*" $word "*) is_builtin=yes ;;
				esac
				line_before=${line%"${BASH_REMATCH[0]}"*}
				# shellcheck disable=SC2016 # literal matching of '$(' in line
				if [ "$is_builtin" = yes ] && [[ $line_before != *'|'* ]] && [[ $line != *'$('* ]]; then
					break
				fi
				printf 'scan-fault-guard: %s:%s: %s without a '\''# scan-fault: deliberate — <reason>'\'' pragma\n' \
					"$file" "$lineno" "${shape%%|*}" >&2
				findings=$((findings + 1))
				break
			fi
		done
		for shape in "${substitution_shapes[@]}"; do
			pat=${shape#*|}
			if [[ $line =~ $pat ]]; then
				printf 'scan-fault-guard: %s:%s: %s without a '\''# scan-fault: deliberate — <reason>'\'' pragma\n' \
					"$file" "$lineno" "${shape%%|*}" >&2
				findings=$((findings + 1))
				break
			fi
		done
	done
	exec 3<&-
}

if [ $# -gt 0 ] && [ "$1" = --files ]; then
	shift
	if [ $# -eq 0 ]; then
		printf 'scan-fault-guard: --files needs at least one file\n' >&2
		exit 2
	fi
	for file in "$@"; do
		scan_file "$file"
	done
	exit "$([ "$findings" -gt 0 ] && echo 1 || echo 0)"
fi

if [ $# -gt 0 ]; then
	usage >&2
	exit 2
fi

listing=$(mktemp) || {
	printf 'scan-fault-guard: could not create a scratch file\n' >&2
	exit 2
}
# shellcheck disable=SC2329 # run by the EXIT trap, not called directly
cleanup() {
	local status=$?
	if ! rm -f -- "$listing"; then
		printf 'scan-fault-guard: retained scratch path: %s\n' "$listing" >&2
		if ((status == 0)); then
			exit 2
		fi
	fi
	exit "$status"
}
trap cleanup EXIT
if ! ./scripts/list-shell-sources.sh --all -z >"$listing"; then
	printf 'scan-fault-guard: could not discover shell sources\n' >&2
	exit 2
fi
while IFS= read -r -d '' file; do
	case "$file" in
	tests/fixtures/* | */tests/fixtures/* | *-test.sh) continue ;;
	esac
	scan_file "$file"
done <"$listing"
exit "$([ "$findings" -gt 0 ] && echo 1 || echo 0)"
