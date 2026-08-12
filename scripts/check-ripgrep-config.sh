#!/usr/bin/env bash
set -euo pipefail

# Fails when a tracked shell source runs ripgrep while RIPGREP_CONFIG_PATH can
# still reach it. ripgrep applies that file's contents as arguments ahead of the
# ones a caller passes, so every flag a call does not set is chosen by whoever
# set the variable -- and the gates in the verify chain decide their verdict from
# ripgrep's output. `--fixed-strings` in a personal ripgreprc turned the secret
# scanner into a scan that matches nothing and exits 0.
#
# Two forms neutralise it and this gate accepts either, because both leave
# ripgrep unable to read a config file and requiring one form would force an edit
# into files another change owns:
#
#   - `unset RIPGREP_CONFIG_PATH` alone on a line at column 0, above the calls it
#     covers, which then covers every ripgrep below it including one added later;
#     or
#   - `--no-config` on the logical line that invokes ripgrep.
#
# The second form is checked per line, not per invocation: two calls on one line
# where only the first passes --no-config satisfy it. Splitting a logical line
# into its commands needs a shell rather than a scanner, and the residual is
# accepted rather than papered over here.
#
# Sources are discovered, never listed (list-shell-sources.sh), so a new script
# is covered with no edit here. There is no exemption list: a file that never
# runs ripgrep produces no invocation and is never asked for the statement.
#
# Justfile recipe bodies are out of scope for that discovery: list-shell-sources.sh
# finds tracked files named *.sh or opening with a Bash shebang, and Justfile is
# named for `just` and opens with `set shell := [...]`, so it matches neither and
# the `rg --no-config` call in the `hooks` recipe (around line 19) is invisible
# here. Bringing Justfile recipe bodies under this discovery would mean parsing
# `just`'s own recipe syntax -- multiple recipes per file, each an optional
# shebang line, mixed with plain non-shebang recipes this scanner has no reason
# to open -- which is a second file format for a scanner that only claims to read
# shell text (see the strip/runs_ripgrep comment below). scripts/verify-push-test.sh
# instead pins that one call site directly: it runs the `hooks` recipe under a
# hostile RIPGREP_CONFIG_PATH and asserts the foreign-hook refusal still fires,
# so removing `--no-config` from Justfile reddens that test even though this gate
# cannot see the call.
#
# Exit 0 clean, 1 on a finding naming file:line, 2 on a fault.

fault() {
	printf 'ripgrep-config: %s\n' "$*" >&2
	exit 2
}

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if (($# > 1)); then
	fault 'usage: check-ripgrep-config.sh [repository-root]'
fi
if (($# == 1)); then
	root=$(cd "$1" 2>/dev/null && pwd) || fault "repository root is not a directory: $1"
fi

lister="$root/scripts/list-shell-sources.sh"
[[ -x $lister ]] || fault "source lister is missing or not executable: $lister"

scratch=$(mktemp -d "${TMPDIR:-/tmp}/ripgrep-config.XXXXXX") || fault 'could not create a scratch directory'
cleanup() {
	case $scratch in
	"${TMPDIR:-/tmp}"/ripgrep-config.*) rm -R -- "$scratch" ;;
	*) printf 'ripgrep-config: refusing cleanup outside scratch root: %s\n' "$scratch" >&2 ;;
	esac
}
trap cleanup EXIT

# The list is captured to a file rather than read from a process substitution:
# `while ... done < <(lister)` reports the loop's status, not the lister's, so a
# discovery that failed halfway would yield a short list and a green gate. That
# is the same shape of silent miss this gate exists to prevent.
if ! (cd "$root" && "$lister" --all -z) >"$scratch/sources"; then
	fault 'could not discover shell sources'
fi

# read -d '' keeps the NUL-delimited list intact and works on bash 3.2, which is
# the macOS system shell this repository still supports; mapfile does not.
sources=()
while IFS= read -r -d '' source; do
	sources+=("$source")
done <"$scratch/sources"

((${#sources[@]} > 0)) || fault 'no shell sources discovered'

for source in "${sources[@]}"; do
	[[ -r "$root/$source" ]] || fault "source is unreadable: $source"
done

# The scanner reads shell text, so it strips before it matches: a ripgrep
# *mentioned* in a comment, a quoted string or a here-document body is not one
# the file runs -- a gate that flagged those would be answered by an exemption
# list, which is the thing that rots.
#
# It models quoting, comments, line continuations and here-documents; it is not a
# shell parser and does not claim to be. A construct it misreads produces a
# finding on a compliant file, which is loud, rather than silence on an exposed
# one. It does not check that the flags a call passes are the right ones -- that
# is each gate's own suite.
findings=$(
	cd "$root" && awk '
	function strip(s,   i, c, out, quote, n) {
		out = ""
		quote = ""
		n = length(s)
		for (i = 1; i <= n; i++) {
			c = substr(s, i, 1)
			if (quote == "\047") {
				if (c == "\047") quote = ""
				continue
			}
			if (quote == "\"") {
				if (c == "\\") { i++; continue }
				if (c == "\"") quote = ""
				continue
			}
			if (c == "\\") { i++; out = out "@"; continue }
			if (c == "\047" || c == "\"") { quote = c; out = out "@"; continue }
			# A # opens a comment only where a word could not continue.
			if (c == "#" && (out == "" || substr(out, length(out), 1) ~ /[ \t;|&(){}]/)) break
			out = out c
		}
		return out
	}

	# The separators after which a word is a command name. $( and <( reduce to (
	# and && / || to &, so one character class covers them all.
	#
	# What this recognises: a bare rg, one behind a keyword or a variable
	# assignment, one behind a wrapper that takes flags of its own (xargs -0 rg,
	# timeout 5 rg, sudo -u x rg, env rg, nice, stdbuf, nohup, ionice), one named
	# by absolute path, and one after find -exec/-execdir.
	#
	# What it does not: a quoted command word ("rg"), one reached through a
	# variable (RG=rg; "$RG"), an escaped spelling (r\g), and anything inside eval
	# or bash -c. Those need a shell, not a scanner. They are worth knowing about
	# because this gate is a backstop for the idiomatic shapes above, not a proof
	# that no ripgrep anywhere is exposed.
	function word_is_ripgrep(s,   n, i, words) {
		n = split(s, words, /[ \t]+/)
		for (i = 1; i <= n; i++) {
			if (words[i] ~ /^(\/[^ \t]*\/)?rg$/) return 1
		}
		return 0
	}

	function runs_ripgrep(s,   n, i, parts, seg, wrapper) {
		gsub(/[;|&(){}]/, "\n", s)
		n = split(s, parts, "\n")
		for (i = 1; i <= n; i++) {
			seg = parts[i]
			sub(/^[ \t]+/, "", seg)
			if (seg ~ /(^|[ \t])-exec(dir)?[ \t]+(\/[^ \t]*\/)?rg([ \t]|$)/) return 1
			wrapper = 0
			while (1) {
				if (seg ~ /^(if|then|else|elif|while|until|do|time|command|exec|!)[ \t]+/) {
					sub(/^[^ \t]+[ \t]+/, "", seg)
					continue
				}
				if (seg ~ /^(xargs|env|timeout|sudo|nice|stdbuf|nohup|ionice)[ \t]+/) {
					sub(/^[^ \t]+[ \t]+/, "", seg)
					wrapper = 1
					continue
				}
				if (seg ~ /^[A-Za-z_][A-Za-z0-9_]*=[^ \t]*[ \t]+/) {
					sub(/^[A-Za-z_][A-Za-z0-9_]*=[^ \t]*[ \t]+/, "", seg)
					continue
				}
				break
			}
			# A wrapper execs one of its operands, and which of its own flags take
			# an argument differs per wrapper (sudo -u user, timeout 5, xargs -0).
			# Rather than model each, treat rg appearing as a whole word anywhere
			# in the wrapped command as the invocation it almost certainly is.
			if (wrapper && word_is_ripgrep(seg)) return 1
			if (seg ~ /^(\/[^ \t]*\/)?rg([ \t]|$)/) return 1
		}
		return 0
	}

	# The word a here-document ends on, or "" when the line opens none. <<< is a
	# here-string and reads no body.
	function heredoc_word(s,   rest, word) {
		while (match(s, /<</)) {
			rest = substr(s, RSTART + 2)
			s = rest
			if (substr(rest, 1, 1) == "<") continue
			sub(/^-/, "", rest)
			sub(/^[ \t]+/, "", rest)
			if (match(rest, /^("[^"]+"|\047[^\047]+\047|[A-Za-z_][A-Za-z0-9_]*)/)) {
				word = substr(rest, RSTART, RLENGTH)
				gsub(/["\047]/, "", word)
				return word
			}
		}
		return ""
	}

	FNR == 1 {
		neutralised[FILENAME] = 0
		pending = ""
		start = 0
		terminator = ""
	}

	terminator != "" {
		line = $0
		sub(/^\t+/, "", line)
		if ($0 == terminator || line == terminator) terminator = ""
		next
	}

	{
		# `unset RIPGREP_CONFIG_PATH` counts when it stands alone at column 0 and
		# appears above the invocation it is meant to cover -- an unset below the
		# call neutralises nothing, so only calls seen after it are cleared.
		#
		# Column 0 is a legibility rule, not a scope proof: this scanner does not
		# track blocks, so an unset at column 0 inside a function body or an
		# `if false` branch still counts even though it may never run. Catching
		# that needs a shell. The rule is what makes the statement greppable and
		# reviewable in the file it governs.
		if ($0 ~ /^unset[ \t]+RIPGREP_CONFIG_PATH[ \t]*(#.*)?$/) neutralised[FILENAME] = 1

		if (pending == "") start = FNR
		pending = pending $0
		# An odd number of trailing backslashes continues the logical line.
		if (match(pending, /\\+$/) && RLENGTH % 2 == 1) {
			pending = substr(pending, 1, length(pending) - 1)
			next
		}

		terminator = heredoc_word(pending)
		stripped = strip(pending)
		if (!neutralised[FILENAME] && runs_ripgrep(stripped) &&
			stripped !~ /--no-config/) {
			invocations[FILENAME] = invocations[FILENAME] start "\n"
		}
		pending = ""
	}

	END {
		for (file in invocations) {
			n = split(invocations[file], lines, "\n")
			for (i = 1; i <= n; i++) {
				if (lines[i] != "") printf "%s:%s\n", file, lines[i]
			}
		}
	}
	' "${sources[@]}" | sort -t: -k1,1 -k2,2n
) || fault 'could not scan the shell sources'

if [[ -n $findings ]]; then
	while IFS= read -r finding; do
		printf 'ripgrep-config: %s: runs rg without unset RIPGREP_CONFIG_PATH or --no-config\n' \
			"$finding" >&2
	done <<<"$findings"
	printf 'ripgrep-config: a config file may steer these scans; add "unset RIPGREP_CONFIG_PATH" above the call, or pass --no-config to it\n' >&2
	exit 1
fi

printf 'ripgrep-config: ok (%s shell sources)\n' "${#sources[@]}"
