#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

ROOT="$(cd "$script_dir/.." && pwd)"
CHECKER="$ROOT/scripts/check-public-safety.sh"

# The cases below hand the gate a hostile RIPGREP_CONFIG_PATH one invocation at
# a time. Unsetting it here keeps the value this suite inherited from steering
# the baseline cases, which assert the gate stays green.
unset RIPGREP_CONFIG_PATH

# Hooks export repository-local selectors that override every fixture's `git -C`.
# Clear Git's reported set before this suite creates or inspects a repository --
# which the very first fixture below already does.
clear_git_env
fixture_init public-safety-test
# The scanner-filename cases below need a checkout-shaped path, so this second
# fixture cannot live under TMPDIR.
fixture_scratch "$ROOT/.public-safety-path-test."
HOME_PATH_FIXTURE=$FIXTURE_SCRATCH

# A real repository, because the gate enumerates the tracked files under every
# directory it is handed and reports a `git ls-files` that could not answer.
# Nothing here is committed: the fixtures below are untracked, the walk reaches
# them, and the empty listing is the legitimate outcome pinned further down.
mkdir -p "$SCRATCH/repo/nested"
git init -q -b main "$SCRATCH/repo"
# A linked worktree's `.git` is a file naming an absolute path, so on a checkout
# under a denied prefix it is a match the gate must not report -- it is Git
# metadata, not content. Nested rather than at the fixture root so the fixture
# stays a repository git can list; `--glob '!.git'` matches the basename at any
# depth, which is the exclusion under test.
printf 'gitdir: /Vol%s/Private Disk/repo/.git/worktrees/example\n' 'umes' \
	>"$SCRATCH/repo/nested/.git"
printf 'public content\n' >"$SCRATCH/repo/README.md"

if ! "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: Git metadata should be excluded\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

printf 'private path: /Us%s/example-user/project\n' 'ers' >"$SCRATCH/repo/private.txt"
if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: repository content leak should fail\n' >&2
	exit 1
fi

if ! grep -qF 'public-safety: denied pattern matched' "$SCRATCH/output"; then
	printf 'public-safety-test: failure should identify the denied pattern\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

rm -f "$SCRATCH/repo/private.txt"

# A Linux home directory is a leak the same way a macOS one is.
printf 'private path: /ho%s/example-user/project\n' 'me' >"$SCRATCH/repo/linux.txt"
if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: Linux home directory leak should fail\n' >&2
	exit 1
fi
rm -f "$SCRATCH/repo/linux.txt"

# /home/runner and /home/linuxbrew are published constants of GitHub's runner
# images, not anyone's home directory. The ubuntu image documents the shellenv
# line below as the way to reach Homebrew, so a workflow that carries it must
# not fail this gate.
{
	# shellcheck disable=SC2016 # fixture text quoted verbatim, not an expansion
	printf 'eval "$(/ho%s/linuxbrew/.linuxbrew/bin/brew shellenv)"\n' 'me'
	printf 'workspace is /ho%s/runner/work/adept/adept\n' 'me'
} >"$SCRATCH/repo/workflow.yml"
if ! "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: published CI home paths should not be denied\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# Ripgrep prefixes a match with its filename when the gate supplies more than
# one target. A checkout beneath a denied home path must not turn that generated
# prefix into content when the matched line itself contains only a published CI
# path. Keep the fixture under ROOT so it exercises the real checkout shape.
printf 'workspace is /ho%s/runner/work/adept/adept\n' 'me' \
	>"$HOME_PATH_FIXTURE/workflow.yml"
if ! "$CHECKER" "$HOME_PATH_FIXTURE" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: scanner filename prefix should not be denied\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# Filenames may contain every byte except NUL and slash. Newline and a text
# protocol's field separator must remain path data rather than becoming record
# structure that leaks into the content check.
newline_fixture="$HOME_PATH_FIXTURE/"$'line\nbreak.yml'
separator_fixture="$HOME_PATH_FIXTURE/"$'field\034break.yml'
printf 'workspace is /ho%s/runner/work/adept/adept\n' 'me' >"$newline_fixture"
printf 'workspace is /ho%s/linuxbrew/.linuxbrew\n' 'me' >"$separator_fixture"
if ! "$CHECKER" "$HOME_PATH_FIXTURE" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: filename bytes should not alter matched content\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

leaked_path="/ho$(printf 'me')/example-user/project"
printf 'private path: %s\n' "$leaked_path" >"$separator_fixture"
if "$CHECKER" "$HOME_PATH_FIXTURE" >"$SCRATCH/output" 2>"$SCRATCH/error"; then
	printf 'public-safety-test: hostile filename hid a real home leak\n' >&2
	exit 1
fi
if ! jq -e --arg path "$separator_fixture" --arg content "private path: $leaked_path" \
	'select(.path.text == $path and .line_number == 1 and
		.lines.text == ($content + "\n"))' <"$SCRATCH/output" >/dev/null; then
	printf 'public-safety-test: finding should preserve exact path, line, and content\n' >&2
	cat "$SCRATCH/output" >&2
	cat "$SCRATCH/error" >&2
	exit 1
fi
rm -f "$newline_fixture" "$separator_fixture"

# The allowance is per line, not per file: a real home directory beside a
# published one is still reported, and it is the real one that gets printed.
printf 'also /ho%s/example-user/project\n' 'me' >>"$SCRATCH/repo/workflow.yml"
if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: home leak beside a CI path should fail\n' >&2
	exit 1
fi
if ! grep -qF 'example-user' "$SCRATCH/output"; then
	printf 'public-safety-test: the reported line should name the real leak\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
if grep -qF 'linuxbrew' "$SCRATCH/output"; then
	printf 'public-safety-test: the published CI path should not be reported\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# Prose names the directory without a trailing slash, and at end of line.
{
	printf 'Homebrew lives under /ho%s/linuxbrew on Linux.\n' 'me'
	printf 'The workspace root is /ho%s/runner\n' 'me'
} >"$SCRATCH/repo/workflow.yml"
if ! "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: bare CI home names should not be denied\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The allowance ends where the name does: a person whose account name merely
# starts with one of them is still a finding.
printf 'private path: /ho%s/runnerbee/project\n' 'me' >"$SCRATCH/repo/workflow.yml"
if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: a home name prefixed by a CI name should fail\n' >&2
	exit 1
fi

# Both on one line: the redaction must not swallow the leak beside it.
printf 'PATH=/ho%s/linuxbrew/.linuxbrew/bin:/ho%s/example-user/bin\n' 'me' 'me' \
	>"$SCRATCH/repo/workflow.yml"
if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: home leak sharing a line with a CI path should fail\n' >&2
	exit 1
fi

# A credential on a line that also carries a published CI path is still a
# credential: the allowance covers one pattern's false positive, not the line.
printf '/ho%s/runner/.netrc holds %s%s\n' 'me' 'ghp' '_abcdefghijklmnopqrstuvwxyz01' \
	>"$SCRATCH/repo/workflow.yml"
if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: token beside a CI path should fail\n' >&2
	exit 1
fi
rm -f "$SCRATCH/repo/workflow.yml"

# A tenant hostname is host-specific identity, which CLAUDE.md bars from tracked
# files in this public repo. Assembled at runtime so this test file is not
# itself a match.
printf 'see acme-corp.%s for the board\n' 'atlassian.net' >"$SCRATCH/repo/tenant.md"
if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: tenant hostname leak should fail\n' >&2
	exit 1
fi
rm -f "$SCRATCH/repo/tenant.md"

# Atlassian's own public API domain is not tenant identity and must not match,
# or every design doc citing the REST endpoint fails the gate.
printf 'call api.%s/ex/jira/{cloudId}/rest/api/3\n' 'atlassian.com' \
	>"$SCRATCH/repo/endpoint.md"
if ! "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: public API domain should not be denied\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
rm -f "$SCRATCH/repo/endpoint.md"

# An Atlassian API token is a credential shape, like the GitHub, OpenAI, AWS and
# Slack shapes beside it. Assembled at runtime so this test file is not itself a
# match for the scan it exercises.
printf 'token = %s%s\n' 'ATATT' '3xFfGF0T00000000000000000000000000000000' \
	>"$SCRATCH/repo/token.md"
if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: Atlassian API token leak should fail\n' >&2
	exit 1
fi
rm -f "$SCRATCH/repo/token.md"

# The token is not always held in plaintext: the documented form here is
# base64(email:token) in an ATLASSIAN_-prefixed variable, which contains no
# literal ATATT at any alignment and does not carry the `Basic ` header word
# either, so neither shape above sees it.
# A credential reaches a file in whatever syntax its container uses, so the
# bare assignment is the least likely of the four rather than the only one.
b64=ZXhhbXBsZUBleGFtcGxlLmNvbTpub3RhcmVhbHRva2Vu
while IFS= read -r form; do
	printf '%s\n' "$form" >"$SCRATCH/repo/env.md"
	if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
		printf 'public-safety-test: Atlassian credential leak should fail: %s\n' \
			"$form" >&2
		exit 1
	fi
done <<FORMS
$(printf '%s_MCP_BASIC_AUTH=%s' 'ATLASSIAN' "$b64")
$(printf 'export %s_MCP_BASIC_AUTH="%s"' 'ATLASSIAN' "$b64")
$(printf "%s_MCP_BASIC_AUTH='%s'" 'ATLASSIAN' "$b64")
$(printf '  "%s_MCP_BASIC_AUTH": "%s",' 'ATLASSIAN' "$b64")
$(printf '  %s_MCP_BASIC_AUTH: %s' 'ATLASSIAN' "$b64")
FORMS
rm -f "$SCRATCH/repo/env.md"

# Naming the variable is not disclosing its value; the setup docs have to.
printf 'set %s_MCP_BASIC_AUTH in your shell profile\n' 'ATLASSIAN' \
	>"$SCRATCH/repo/setup.md"
if ! "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: naming the variable should not be denied\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
rm -f "$SCRATCH/repo/setup.md"

# The prefix alone is not a credential. Prose naming the token format must not
# fail the gate, or the design docs describing it cannot be committed.
printf 'Atlassian API tokens begin %s.\n' 'ATATT' >"$SCRATCH/repo/prose.md"
if ! "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: token prefix in prose should not be denied\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
rm -f "$SCRATCH/repo/prose.md"

# A credential shape the scan is meant to catch, assembled at runtime so this
# suite is not itself a match for the gate that scans it.
planted="token: $(printf '%s%s' 'ghp' '_abcdefghijklmnopqrstuvwxyz01')"

# ripgrep applies the contents of RIPGREP_CONFIG_PATH as arguments ahead of the
# ones the gate passes, so whoever sets that variable chooses what the secret
# scanner matches. Each directive below was reproduced against the unhardened
# gate: the planted token went unreported and the gate exited 0 -- the same
# answer it gives for a clean tree, which is the worst shape a security gate can
# fail in.
printf '%s\n' "$planted" >"$SCRATCH/repo/planted.md"
while IFS= read -r directive; do
	printf -- '%s\n' "$directive" >"$SCRATCH/rgconfig"
	if RIPGREP_CONFIG_PATH="$SCRATCH/rgconfig" "$CHECKER" "$SCRATCH/repo" \
		>"$SCRATCH/output" 2>&1; then
		printf 'public-safety-test: a ripgrep config of %s hid a planted secret\n' \
			"$directive" >&2
		exit 1
	fi
done <<'DIRECTIVES'
--fixed-strings
--glob=!*.md
--max-count=0
--encoding=utf-16le
DIRECTIVES
rm -f "$SCRATCH/repo/planted.md" "$SCRATCH/rgconfig"

# ripgrep judges a file binary on a single NUL byte and skips it during
# directory traversal, so a secret in a file carrying one anywhere is not
# scanned at all. --text is what keeps it in view.
printf '%s\n\000trailing\n' "$planted" >"$SCRATCH/repo/nul.md"
if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: a NUL byte hid a planted secret\n' >&2
	exit 1
fi
rm -f "$SCRATCH/repo/nul.md"

# A leading \xFF\xFE makes ripgrep transcode the rest of the file as UTF-16LE,
# so ASCII content is garbled into something the ASCII patterns cannot match --
# a five-byte prefix that bypasses the scanner. --encoding none stops the
# sniffing. The trade is accepted: no tracked file here is UTF-16.
printf '\377\376%s\n' "$planted" >"$SCRATCH/repo/bom.md"
if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: a spoofed UTF-16 mark hid a planted secret\n' >&2
	exit 1
fi
rm -f "$SCRATCH/repo/bom.md"

# A file can be tracked and ignored at once: `git add -f` on a path a .gitignore
# or .ignore names puts it in the index, so it ships to everyone who clones this
# public repo, while ripgrep's walk -- which applies those same rules to tracked
# files -- never opens it. Before the gate named its tracked files explicitly it
# printed nothing and exited 0 here, the same answer it gives for a clean tree.
hidden_secret="token: $(printf '%s%s' 'ghp' '_abcdefghijklmnopqrstuvwxyz01')"

for ignore_file in .gitignore .ignore; do
	fixture="$SCRATCH/hidden-$ignore_file"
	mkdir -p "$fixture/sub"
	git init -q -b main "$fixture"
	git -C "$fixture" config user.name 'Fixture Developer'
	git -C "$fixture" config user.email fixture@example.invalid
	printf '%s\n' "$hidden_secret" >"$fixture/sub/leak.txt"
	printf 'sub/leak.txt\n' >"$fixture/$ignore_file"
	git -C "$fixture" add -f sub/leak.txt "$ignore_file"
	git -C "$fixture" commit -qm 'tracked but ignored'

	# The premise: git ships it. If this stops holding the case proves nothing.
	if ! git -C "$fixture" ls-files | grep -qF sub/leak.txt; then
		printf 'public-safety-test: fixture is not tracked, case is void: %s\n' \
			"$ignore_file" >&2
		exit 1
	fi
	if "$CHECKER" "$fixture" >"$SCRATCH/output" 2>&1; then
		printf 'public-safety-test: %s hid a secret in a tracked file\n' \
			"$ignore_file" >&2
		exit 1
	fi
done

# ripgrep exits 2 when it cannot open a path it was given explicitly, and it does
# so even when it also found matches. `git ls-files` reports the index, so a
# tracked file deleted from the worktree and not staged names a path with nothing
# behind it -- and a bare `if` on ripgrep read that 2 as "no match". `rm` of any
# tracked file turned this gate green while printing the secret to stdout.
deleted="$SCRATCH/deleted-target"
mkdir -p "$deleted/sub"
git init -q -b main "$deleted"
git -C "$deleted" config user.name 'Fixture Developer'
git -C "$deleted" config user.email fixture@example.invalid
printf '%s\n' "$hidden_secret" >"$deleted/sub/leak.txt"
printf 'sub/leak.txt\n' >"$deleted/.gitignore"
printf 'ordinary content\n' >"$deleted/doomed.txt"
git -C "$deleted" add -f sub/leak.txt .gitignore doomed.txt
git -C "$deleted" commit -qm 'tracked but ignored, plus a doomed file'
rm "$deleted/doomed.txt"
if "$CHECKER" "$deleted" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: a deleted tracked file turned the scan green\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
if ! grep -qF 'denied pattern matched' "$SCRATCH/output"; then
	printf 'public-safety-test: the secret must still be reported\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# A scan ripgrep genuinely could not complete is a fault, not a verdict: exit 2,
# distinct from both the clean 0 and the finding 1. Root can read a 000 file, so
# the case proves nothing there and is skipped rather than asserted falsely.
if [ "$(id -u)" -ne 0 ]; then
	unreadable="$SCRATCH/unreadable-target"
	mkdir -p "$unreadable"
	git init -q -b main "$unreadable"
	git -C "$unreadable" config user.name 'Fixture Developer'
	git -C "$unreadable" config user.email fixture@example.invalid
	printf 'ordinary content\n' >"$unreadable/secret-free.txt"
	git -C "$unreadable" add secret-free.txt
	git -C "$unreadable" commit -qm 'a file that becomes unreadable'
	chmod 000 "$unreadable/secret-free.txt"
	fault_status=0
	"$CHECKER" "$unreadable" >"$SCRATCH/output" 2>&1 || fault_status=$?
	chmod 644 "$unreadable/secret-free.txt"
	if [ "$fault_status" -ne 2 ]; then
		printf 'public-safety-test: an incomplete scan must fault, got %s\n' \
			"$fault_status" >&2
		cat "$SCRATCH/output" >&2
		exit 1
	fi
else
	printf 'public-safety-test: SKIP unreadable-scan fixture: running as root, which\n'
	printf 'public-safety-test: reads a mode-000 file, so the scan completes and the\n'
	printf 'public-safety-test: fault path is never reached. This run did not check it.\n'
fi

# The walk only ever opened regular files; naming a path explicitly makes ripgrep
# open whatever is there. A tracked path replaced by a FIFO blocks forever with no
# writer -- a burned CI timeout rather than a wrong answer, and one the walk-only
# shape did not have. The scan target test is -f for that reason.
#
# The gate is run in the background and polled rather than wrapped in timeout(1),
# which macOS does not ship (a timeout-based leg would fail on it). A regression here
# reddens this case instead of hanging the suite.
fifo="$SCRATCH/fifo-target"
mkdir -p "$fifo"
git init -q -b main "$fifo"
git -C "$fifo" config user.name 'Fixture Developer'
git -C "$fifo" config user.email fixture@example.invalid
printf 'ordinary content\n' >"$fifo/pipe.txt"
printf '%s\n' "$hidden_secret" >"$fifo/leak.txt"
git -C "$fifo" add pipe.txt leak.txt
git -C "$fifo" commit -qm 'a file that becomes a FIFO'
rm "$fifo/pipe.txt"
mkfifo "$fifo/pipe.txt"

"$CHECKER" "$fifo" >"$SCRATCH/output" 2>&1 &
fifo_pid=$!
waited=0
while kill -0 "$fifo_pid" 2>/dev/null && [ "$waited" -lt 30 ]; do
	sleep 1
	waited=$((waited + 1))
done
if kill -0 "$fifo_pid" 2>/dev/null; then
	kill -9 "$fifo_pid" 2>/dev/null || :
	wait "$fifo_pid" 2>/dev/null || :
	printf 'public-safety-test: a FIFO scan target blocked the gate\n' >&2
	exit 1
fi
fifo_status=0
wait "$fifo_pid" || fifo_status=$?
if [ "$fifo_status" -ne 1 ]; then
	printf 'public-safety-test: the FIFO tree should still report its secret, got %s\n' \
		"$fifo_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# A tracked file no ignore rule hides is reached by the walk and by its explicit
# path, so the same match arrives twice. A real leak is the worst moment to
# double the output.
duplicate="$SCRATCH/duplicate-report"
mkdir -p "$duplicate"
git init -q -b main "$duplicate"
git -C "$duplicate" config user.name 'Fixture Developer'
git -C "$duplicate" config user.email fixture@example.invalid
printf '%s\n' "$hidden_secret" >"$duplicate/plain.txt"
git -C "$duplicate" add plain.txt
git -C "$duplicate" commit -qm 'a plainly tracked secret'
if "$CHECKER" "$duplicate" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: a plainly tracked secret must fail the gate\n' >&2
	exit 1
fi
if [ "$(grep -cF 'plain.txt' "$SCRATCH/output")" -ne 1 ]; then
	printf 'public-safety-test: the match should be reported once\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The other half of the same rule: an ignored file that is *untracked* never
# ships, so scanning it would fail the gate on host-specific content that is
# ignored precisely to keep it out of the tracked tree -- CLAUDE.local.md here.
# This is what a bare --no-ignore would break, and it must stay green.
untracked="$SCRATCH/untracked-ignored"
mkdir -p "$untracked"
git init -q -b main "$untracked"
git -C "$untracked" config user.name 'Fixture Developer'
git -C "$untracked" config user.email fixture@example.invalid
printf 'public content\n' >"$untracked/README.md"
printf 'CLAUDE.local.md\n' >"$untracked/.gitignore"
git -C "$untracked" add README.md .gitignore
git -C "$untracked" commit -qm 'public seed'
printf '%s\n' "$hidden_secret" >"$untracked/CLAUDE.local.md"
if ! "$CHECKER" "$untracked" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: an untracked ignored file must not fail the gate\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# A `git ls-files` read through a process substitution reports the loop's
# status, never git's, so a listing that emitted some paths and then died left
# the gate scanning a short set and exiting 0 -- and the `2>/dev/null` on that
# call removed the one thing that would have said why. The stub reproduces
# exactly that shape: one path on stdout, a diagnostic on stderr, a non-zero
# exit. The fixture is a real repository so the fault is the stub's and not the
# directory's.
#
# The path the stub names is the clean one, deliberately. The secret lives in
# the tracked-but-ignored partial.txt the listing died before reaching, so the
# truncated set the pre-fix gate scanned never contained it and that gate
# exited 0 over content it had not listed -- the ADR 0005 defect itself, rather
# than the exit 1 it would have returned had the stub named the secret.
GIT_REAL=$(command -v git)
STUB_BIN="$SCRATCH/stub-bin"
mkdir -p "$STUB_BIN"
cat >"$STUB_BIN/git" <<EOF
#!/usr/bin/env bash
for argument in "\$@"; do
	if [ "\$argument" = ls-files ]; then
		printf '.gitignore\0'
		printf 'stub git: the listing stopped partway\n' >&2
		exit 128
	fi
done
exec "$GIT_REAL" "\$@"
EOF
chmod +x "$STUB_BIN/git"

partial="$SCRATCH/partial-listing"
mkdir -p "$partial"
git init -q -b main "$partial"
git -C "$partial" config user.name 'Fixture Developer'
git -C "$partial" config user.email fixture@example.invalid
printf '%s\n' "$hidden_secret" >"$partial/partial.txt"
printf 'partial.txt\n' >"$partial/.gitignore"
git -C "$partial" add -f partial.txt .gitignore
git -C "$partial" commit -qm 'a listing that stops partway'

partial_status=0
PATH="$STUB_BIN:$PATH" "$CHECKER" "$partial" >"$SCRATCH/output" 2>&1 || partial_status=$?
if [ "$partial_status" -ne 2 ]; then
	printf 'public-safety-test: a listing that stopped partway must fault, got %s\n' \
		"$partial_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
if ! grep -qF 'could not list the tracked files' "$SCRATCH/output"; then
	printf 'public-safety-test: the fault should name what could not be listed\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
# The diagnostic git itself printed has to survive: discarding it is what left
# a short scan with nothing on stderr to explain it.
if ! grep -qF 'stub git: the listing stopped partway' "$SCRATCH/output"; then
	printf "public-safety-test: git's own diagnostic should reach the caller\n" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The contract that fault creates, pinned at the shape a user actually meets
# rather than only at the stub's: a directory outside any worktree exits 2. The
# stub above and this case fail differently -- the stub emits a path and a
# diagnostic before dying, a real non-repository emits nothing -- so softening
# the contract by special-casing an empty-output non-zero as benign would keep
# the stub case red and reopen the walk-only path for every such directory.
#
# GIT_CEILING_DIRECTORIES stops git's upward discovery at the scratch root, so
# the case does not rest on where TMPDIR points. It is the only fixture here
# whose premise is a *negative* property of its ancestry -- every other one
# creates the repository it needs -- and `TMPDIR=$PWD/tmp` inside a checkout is
# a real habit, under which git finds that checkout and the gate exits 0.
# clear_git_env cannot interfere: the name is not one
# `git rev-parse --local-env-vars` reports.
outside_worktree="$SCRATCH/outside-worktree"
mkdir -p "$outside_worktree"
printf 'public content\n' >"$outside_worktree/README.md"
outside_status=0
GIT_CEILING_DIRECTORIES="$SCRATCH" "$CHECKER" "$outside_worktree" \
	>"$SCRATCH/output" 2>&1 || outside_status=$?
if [ "$outside_status" -ne 2 ]; then
	printf 'public-safety-test: a directory outside a worktree must fault, got %s\n' \
		"$outside_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
if ! grep -qF 'could not list the tracked files' "$SCRATCH/output"; then
	printf 'public-safety-test: the fault should name what could not be listed\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The other side of that rule, pinned deliberately: an empty listing under a
# zero status is a legitimate answer, not a fault. Unlike
# `git rev-parse --local-env-vars`, which always names at least GIT_DIR, this
# listing has a genuine empty case -- a checkout subdirectory with nothing
# tracked under it, and a repository before its first `git add`. The walk still
# covers the tree, so an empty listing must not disarm the scan either.
empty_listing="$SCRATCH/empty-listing"
mkdir -p "$empty_listing"
git init -q -b main "$empty_listing"
git -C "$empty_listing" config user.name 'Fixture Developer'
git -C "$empty_listing" config user.email fixture@example.invalid
printf 'public content\n' >"$empty_listing/README.md"
git -C "$empty_listing" add README.md
git -C "$empty_listing" commit -qm 'public seed'
mkdir -p "$empty_listing/nothing-tracked"
if ! "$CHECKER" "$empty_listing/nothing-tracked" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: a subtree with nothing tracked must not fault\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
printf '%s\n' "$hidden_secret" >"$empty_listing/nothing-tracked/leak.txt"
empty_status=0
"$CHECKER" "$empty_listing/nothing-tracked" >"$SCRATCH/output" 2>&1 || empty_status=$?
if [ "$empty_status" -ne 1 ]; then
	printf 'public-safety-test: an empty listing must not disarm the walk, got %s\n' \
		"$empty_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# skills/quest/scripts/publish-forge-review hands this gate a single regular
# file. There are no tracked files to enumerate under one -- ripgrep opens a
# path named on the command line whatever the ignore rules say -- so the
# enumeration must not be asked about it, and `git -C <file>` failing must not
# turn a file scan into a fault.
file_target="$SCRATCH/file-target.md"
printf 'public content\n' >"$file_target"
if ! "$CHECKER" "$file_target" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: a regular file scan target must not fault\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
printf '%s\n' "$hidden_secret" >"$file_target"
file_status=0
"$CHECKER" "$file_target" >"$SCRATCH/output" 2>&1 || file_status=$?
if [ "$file_status" -ne 1 ]; then
	printf 'public-safety-test: a secret in a file scan target must fail the gate, got %s\n' \
		"$file_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

printf 'public-safety-test: ok\n'
