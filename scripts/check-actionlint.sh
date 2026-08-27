#!/usr/bin/env bash
set -euo pipefail

label='check-actionlint'

fail() {
	printf '%s: %s\n' "$label" "$1" >&2
	exit 2
}

if (($# != 1)); then
	fail 'usage: check-actionlint.sh <workflow-directory>'
fi

workflow_dir=$1
[[ -d $workflow_dir ]] || fail "workflow directory does not exist: $workflow_dir"

scratch=$(mktemp -d) || fail 'could not create scratch directory'
cleanup() {
	local status=$?
	if ! rm -rf -- "$scratch"; then
		printf '%s: retained scratch directory: %s\n' "$label" "$scratch" >&2
		if ((status == 0)); then
			exit 2
		fi
	fi
	exit "$status"
}
trap cleanup EXIT

# actionlint 1.7.12 can deadlock after its integrated ShellCheck runner exits
# (upstream #704). Its workflow syntax, expression, action, and injection checks
# remain enabled; only the concurrent ShellCheck integration is disabled here.

workflows=$scratch/workflows
if ! find "$workflow_dir" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 >"$workflows"; then
	fail "could not list workflow files in $workflow_dir"
fi
[[ -s $workflows ]] || fail "no workflow files found in $workflow_dir"

workflow_files=()
while IFS= read -r -d '' workflow; do
	workflow_files+=("$workflow")
done <"$workflows"
actionlint -shellcheck= "${workflow_files[@]}"

workflow_number=0
for workflow in "${workflow_files[@]}"; do
	workflow_number=$((workflow_number + 1))
	output_dir=$scratch/$workflow_number
	mkdir "$output_dir"

	awk -v label="$label" -v source="$workflow" '
	function die(message) {
		printf "%s: %s: %s\\n", label, source, message > "/dev/stderr"
		exit 2
	}

	function indentation(line, prefix) {
		prefix = line
		sub(/[^ ].*$/, "", prefix)
		return length(prefix)
	}

	function trim(value) {
		sub(/^[ ]+/, "", value)
		sub(/[ ]+$/, "", value)
		return value
	}

	function add_matrix_os(value) {
		value = trim(value)
		sub(/[ ]*(#.*)?$/, "", value)
		if (!matrix_os_seen) {
			matrix_os_all_unix = 1
			matrix_os_seen = 1
		}
		matrix_os_values++
		if (value !~ /^(ubuntu|macos)(-[[:alnum:]_.-]+)?$/) {
			matrix_os_all_unix = 0
		}
	}

	{
		line = $0
		if (index(line, "\t")) {
			die("tabs are unsupported in workflow indentation")
		}
		indent = indentation(line)
		key = line
		sub(/^ */, "", key)
		field = key
		sub(/^- +/, "", field)

		if (field ~ /^shell:/) {
			die("shell overrides are unsupported; add extractor support before using one")
		}

		if (os_list_indent >= 0 && indent <= os_list_indent) {
			os_list_indent = -1
		}
		if (os_list_indent >= 0 && indent > os_list_indent && key ~ /^-[ ]+/) {
			value = key
			sub(/^-[ ]+/, "", value)
			add_matrix_os(value)
			next
		}
		if (field ~ /^os:/) {
			value = field
			sub(/^os:[ ]*/, "", value)
			if (value ~ /^[[]/) {
				sub(/^[[]/, "", value)
				sub(/[]][ ]*(#.*)?$/, "", value)
				count = split(value, values, /,/)
				for (entry = 1; entry <= count; entry++) {
					add_matrix_os(values[entry])
				}
			} else if (value == "") {
				os_list_indent = indent
			}
		}

		if (field ~ /^runs-on:/) {
			value = field
			sub(/^runs-on:[ ]*/, "", value)
			value = trim(value)
			sub(/[ ]*(#.*)?$/, "", value)
			if (value == "${{ matrix.os }}") {
				matrix_runner = 1
			} else if (value !~ /^(ubuntu|macos)(-[[:alnum:]_.-]+)?$/) {
				die("cannot independently ShellCheck runner: " value)
			}
		}
	}

	END {
		if (matrix_runner && (matrix_os_values == 0 || !matrix_os_all_unix)) {
			die("cannot independently ShellCheck matrix.os: every static value must be ubuntu-* or macos-*")
		}
	}
	' "$workflow"

	awk -v label="$label" -v source="$workflow" -v output_dir="$output_dir" '
	function die(message) {
		printf "%s: %s: %s\\n", label, source, message > "/dev/stderr"
		exit 2
	}

	function indentation(line, prefix) {
		prefix = line
		sub(/[^ ].*$/, "", prefix)
		return length(prefix)
	}

	function begin_run() {
		block_count++
		path = sprintf("%s/%03d.sh", output_dir, block_count)
		active = 1
		content_indent = -1
	}

	function end_run() {
		if (active) {
			close(path)
			active = 0
		}
	}

	function check_key(line, value) {
		value = line
		sub(/^ */, "", value)
		sub(/^- +/, "", value)
		if (value ~ /^run:/) {
			sub(/^run:[ ]*/, "", value)
			if (value !~ /^[|][+-]?[ ]*(#.*)?$/) {
				die("run blocks must use a literal block scalar")
			}
			begin_run()
		}
	}

	{
		line = $0
		if (index(line, "\t")) {
			die("tabs are unsupported in workflow indentation")
		}
		indent = indentation(line)

		if (active) {
			if (line ~ /^ *$/) {
				print "" >>path
				next
			}
			if ((content_indent < 0 && indent <= run_indent) ||
				(content_indent >= 0 && indent < content_indent)) {
				end_run()
			} else {
				if (content_indent < 0) {
					content_indent = indent
				}
				print substr(line, content_indent + 1) >>path
				next
			}
		}

		run_indent = indent
		check_key(line)
	}

	END {
		end_run()
	}
	' "$workflow"

	for script in "$output_dir"/*.sh; do
		[[ -e $script ]] || continue
		shellcheck -s bash "$script"
	done
done
