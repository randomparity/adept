#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

ROOT="$(cd "$script_dir/.." && pwd)"
CHECKER="$ROOT/scripts/check-public-safety.sh"
# Two cases below shadow git on PATH to make one subcommand answer badly. Each
# stub execs the real binary for every other call, so it has to be resolved here,
# before any of them is on PATH to be found instead.
GIT_REAL=$(command -v git)

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

# The index is a local cache; what ships is HEAD. Removing `.git/index` is the
# documented recovery for a stuck index.lock and the residue of an interrupted
# operation, and it leaves `git ls-files` exiting 0 with no output while HEAD
# still carries the `git add -f`'d ignored path -- git ran and answered
# truthfully, so no status check reaches it. Before the gate enumerated HEAD as
# well, that emptiness degraded the scan to the ignore-respecting walk and this
# fixture exited 0 over a token the same tree reports on with its index in place
# (issue #150).
missing_index="$SCRATCH/missing-index"
mkdir -p "$missing_index/sub"
git init -q -b main "$missing_index"
git -C "$missing_index" config user.name 'Fixture Developer'
git -C "$missing_index" config user.email fixture@example.invalid
printf '%s\n' "$hidden_secret" >"$missing_index/sub/leak.txt"
printf 'sub/leak.txt\n' >"$missing_index/.gitignore"
git -C "$missing_index" add -f sub/leak.txt .gitignore
git -C "$missing_index" commit -qm 'tracked but ignored'
rm "$missing_index/.git/index"

# Both premises. If either stops holding the case proves nothing: the index has
# to answer empty, and HEAD has to still carry the secret.
if [ -n "$(git -C "$missing_index" ls-files)" ]; then
	printf 'public-safety-test: the index still lists files, case is void\n' >&2
	exit 1
fi
if ! git -C "$missing_index" ls-tree -r --name-only HEAD | grep -qF sub/leak.txt; then
	printf 'public-safety-test: HEAD no longer carries the secret, case is void\n' >&2
	exit 1
fi

missing_index_status=0
"$CHECKER" "$missing_index" >"$SCRATCH/output" 2>&1 || missing_index_status=$?
if [ "$missing_index_status" -ne 1 ]; then
	printf 'public-safety-test: a removed index hid a committed secret, got %s\n' \
		"$missing_index_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
if ! grep -qF 'denied pattern matched' "$SCRATCH/output"; then
	printf 'public-safety-test: the secret must still be reported\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The other direction, and why HEAD does not simply replace the index: a path
# staged and not yet committed is in the index and in no tree. This is the
# moment the pre-commit hook runs the gate, so enumerating HEAD alone would
# green on the commit that introduces the secret.
staged_only="$SCRATCH/staged-only"
mkdir -p "$staged_only/sub"
git init -q -b main "$staged_only"
git -C "$staged_only" config user.name 'Fixture Developer'
git -C "$staged_only" config user.email fixture@example.invalid
printf 'public content\n' >"$staged_only/README.md"
printf 'sub/leak.txt\n' >"$staged_only/.gitignore"
git -C "$staged_only" add README.md .gitignore
git -C "$staged_only" commit -qm 'public seed'
printf '%s\n' "$hidden_secret" >"$staged_only/sub/leak.txt"
git -C "$staged_only" add -f sub/leak.txt

# The premise: HEAD does not carry it, only the index does.
if git -C "$staged_only" ls-tree -r --name-only HEAD | grep -qF sub/leak.txt; then
	printf 'public-safety-test: HEAD already carries the secret, case is void\n' >&2
	exit 1
fi

staged_only_status=0
"$CHECKER" "$staged_only" >"$SCRATCH/output" 2>&1 || staged_only_status=$?
if [ "$staged_only_status" -ne 1 ]; then
	printf 'public-safety-test: a staged-only secret must fail the gate, got %s\n' \
		"$staged_only_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The same claim before the first commit, where there is no HEAD to enumerate at
# all: an unborn HEAD is a legitimate answer the gate reads as "nothing is
# committed", never as a fault, and it must not disarm the index half.
unborn="$SCRATCH/unborn-head"
mkdir -p "$unborn/sub"
git init -q -b main "$unborn"
git -C "$unborn" config user.name 'Fixture Developer'
git -C "$unborn" config user.email fixture@example.invalid
printf 'public content\n' >"$unborn/README.md"
printf 'sub/leak.txt\n' >"$unborn/.gitignore"
git -C "$unborn" add README.md .gitignore
if ! "$CHECKER" "$unborn" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: a repository with no commits must not fault\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
printf '%s\n' "$hidden_secret" >"$unborn/sub/leak.txt"
git -C "$unborn" add -f sub/leak.txt
unborn_status=0
"$CHECKER" "$unborn" >"$SCRATCH/output" 2>&1 || unborn_status=$?
if [ "$unborn_status" -ne 1 ]; then
	printf 'public-safety-test: an unborn HEAD must not disarm the index, got %s\n' \
		"$unborn_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# `-C` chooses a directory to run in, not a repository: git reads its
# repository-local environment selectors ahead of directory discovery, so with
# them exported the enumeration answers about the ambient repository at exit 0,
# names paths that are not under the scan path, and the gate falls back to the
# ignore-respecting walk that cannot see a `git add -f`'d ignored file. On the
# pre-fix gate that was exit 0, silently, over a token the same tree reports on
# in a clean environment.
selector_target="$SCRATCH/ambient-selectors"
mkdir -p "$selector_target/sub"
git init -q -b main "$selector_target"
git -C "$selector_target" config user.name 'Fixture Developer'
git -C "$selector_target" config user.email fixture@example.invalid
printf '%s\n' "$hidden_secret" >"$selector_target/sub/leak.txt"
printf 'sub/leak.txt\n' >"$selector_target/.gitignore"
git -C "$selector_target" add -f sub/leak.txt .gitignore
git -C "$selector_target" commit -qm 'tracked but ignored'

# The repository the exported selectors point at. It is clean, so a gate that
# answers about it instead of the target reports nothing.
ambient="$SCRATCH/ambient-repository"
mkdir -p "$ambient"
git init -q -b main "$ambient"
git -C "$ambient" config user.name 'Fixture Developer'
git -C "$ambient" config user.email fixture@example.invalid
printf 'public content\n' >"$ambient/README.md"
git -C "$ambient" add README.md
git -C "$ambient" commit -qm 'public seed'

# The premise: pointed at the ambient repository, the listing names that
# repository's file rather than the target's. If this stops holding the cases
# below prove nothing.
if [ "$(GIT_DIR="$ambient/.git" GIT_WORK_TREE="$ambient" \
	git -C "$selector_target" ls-files)" != README.md ]; then
	printf 'public-safety-test: selectors no longer redirect the listing, cases are void\n' >&2
	exit 1
fi

# One selector at a time, each carrying the value its own shape takes. The
# suite cleared this set at the top, so `env` with a single assignment is the
# whole environment difference between these runs and the clean one above.
#
# GIT_INDEX_FILE is exercised on its own deliberately. Clearing it decides which
# index the gate enumerates -- under `git commit --only <paths>` a hook's
# GIT_INDEX_FILE names a temporary index rather than the repository's -- and
# this case pins the answer: the repository's own, never the caller's.
while IFS=' ' read -r selector value; do
	selector_status=0
	env "$selector=$value" "$CHECKER" "$selector_target" \
		>"$SCRATCH/output" 2>&1 || selector_status=$?
	if [ "$selector_status" -ne 1 ]; then
		printf 'public-safety-test: %s redirected the listing and hid a secret, got %s\n' \
			"$selector" "$selector_status" >&2
		cat "$SCRATCH/output" >&2
		exit 1
	fi
done <<SELECTORS
GIT_DIR $ambient/.git
GIT_INDEX_FILE $ambient/.git/index
SELECTORS

# All of them at once, the shape the issue reproduced.
selector_status=0
GIT_DIR="$ambient/.git" GIT_COMMON_DIR="$ambient/.git" GIT_WORK_TREE="$ambient" \
	GIT_INDEX_FILE="$ambient/.git/index" \
	"$CHECKER" "$selector_target" >"$SCRATCH/output" 2>&1 || selector_status=$?
if [ "$selector_status" -ne 1 ]; then
	printf 'public-safety-test: exported git selectors hid a secret, got %s\n' \
		"$selector_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
if ! grep -qF 'denied pattern matched' "$SCRATCH/output"; then
	printf 'public-safety-test: the secret must still be reported\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The other side of the same rule: clearing must not invent a finding or a
# fault. A clean target under the same exported selectors stays green.
if ! GIT_DIR="$ambient/.git" GIT_COMMON_DIR="$ambient/.git" GIT_WORK_TREE="$ambient" \
	GIT_INDEX_FILE="$ambient/.git/index" \
	"$CHECKER" "$ambient" >"$SCRATCH/output" 2>&1; then
	printf 'public-safety-test: a clean tree must stay green under exported selectors\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The clearing has the two failure modes clear_git_env and verify-push.sh name,
# and neither may fall through to an enumeration that still addresses the
# ambient repository: a rev-parse that could not answer, and one that answered
# nothing at exit 0. Both are stubbed, because a real git produces neither --
# `--local-env-vars` is a fixed list git has always begun with GIT_DIR.
ENVSTUB_BIN="$SCRATCH/envstub-bin"
mkdir -p "$ENVSTUB_BIN"
while IFS='|' read -r label action expected_fragment; do
	cat >"$ENVSTUB_BIN/git" <<EOF
#!/usr/bin/env bash
for argument in "\$@"; do
	if [ "\$argument" = --local-env-vars ]; then
		$action
	fi
done
exec "$GIT_REAL" "\$@"
EOF
	chmod +x "$ENVSTUB_BIN/git"
	envstub_status=0
	PATH="$ENVSTUB_BIN:$PATH" "$CHECKER" "$selector_target" \
		>"$SCRATCH/output" 2>&1 || envstub_status=$?
	if [ "$envstub_status" -ne 2 ]; then
		printf 'public-safety-test: %s must fault, got %s\n' \
			"$label" "$envstub_status" >&2
		cat "$SCRATCH/output" >&2
		exit 1
	fi
	if ! grep -qF "$expected_fragment" "$SCRATCH/output"; then
		printf 'public-safety-test: the fault should name what could not be cleared: %s\n' \
			"$label" >&2
		cat "$SCRATCH/output" >&2
		exit 1
	fi
done <<'ENVSTUBS'
a local-env-vars read that died|exit 128|cannot read git local env vars
a local-env-vars read that named nothing|exit 0|git reported no local env vars
ENVSTUBS

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

# A committed file no ignore rule hides is reached three ways -- by the walk, by
# the index listing and by the commit listing -- so the same match arrives three
# times. A real leak is the worst moment to multiply the output.
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

# The HEAD half has the same two fault shapes, and neither may fall through to a
# walk that cannot see an ignored path. Both are stubbed, because the fixture is
# a real repository whose HEAD resolves and whose tree reads fine. The keys are
# `--verify` and `ls-tree` rather than `rev-parse`: the gate issues a second
# rev-parse for `--local-env-vars`, and a stub keyed on the subcommand alone
# would fault at that call instead and prove something else.
HEADSTUB_BIN="$SCRATCH/headstub-bin"
mkdir -p "$HEADSTUB_BIN"
cat >"$HEADSTUB_BIN/git" <<EOF
#!/usr/bin/env bash
for argument in "\$@"; do
	if [ "\$argument" = --verify ]; then
		printf 'stub git: HEAD could not be resolved\n' >&2
		exit 128
	fi
done
exec "$GIT_REAL" "\$@"
EOF
chmod +x "$HEADSTUB_BIN/git"
headprobe_status=0
PATH="$HEADSTUB_BIN:$PATH" "$CHECKER" "$selector_target" \
	>"$SCRATCH/output" 2>&1 || headprobe_status=$?
if [ "$headprobe_status" -ne 2 ]; then
	printf 'public-safety-test: a HEAD probe that could not answer must fault, got %s\n' \
		"$headprobe_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
if ! grep -qF 'could not resolve HEAD' "$SCRATCH/output"; then
	printf 'public-safety-test: the fault should name what could not be resolved\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The commit listing itself, in the shape the ls-files stub above uses: a path on
# stdout, a diagnostic on stderr, a non-zero exit. The path it names is the clean
# one, so a gate that read the truncated set as complete would exit 0 over the
# tracked-and-ignored secret it never listed -- the ADR 0005 defect rather than
# the exit 1 a stub naming the secret would have produced.
cat >"$HEADSTUB_BIN/git" <<EOF
#!/usr/bin/env bash
for argument in "\$@"; do
	if [ "\$argument" = ls-tree ]; then
		printf '.gitignore\0'
		printf 'stub git: the commit listing stopped partway\n' >&2
		exit 128
	fi
done
exec "$GIT_REAL" "\$@"
EOF
chmod +x "$HEADSTUB_BIN/git"
lstree_status=0
PATH="$HEADSTUB_BIN:$PATH" "$CHECKER" "$selector_target" \
	>"$SCRATCH/output" 2>&1 || lstree_status=$?
if [ "$lstree_status" -ne 2 ]; then
	printf 'public-safety-test: a commit listing that stopped partway must fault, got %s\n' \
		"$lstree_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
if ! grep -qF 'could not list the committed files' "$SCRATCH/output"; then
	printf 'public-safety-test: the fault should name what could not be listed\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
if ! grep -qF 'stub git: the commit listing stopped partway' "$SCRATCH/output"; then
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

# A failed scratch removal must not read as a finding. The EXIT trap runs under
# `set -e`, where its return becomes the exit status, and 1 is this gate's
# finding status -- so an unguarded trap reports a public-safety violation
# naming no file, no line and no pattern.
RMFAIL_BIN="$SCRATCH/rmfail-bin"
mkdir -p "$RMFAIL_BIN"
cat >"$RMFAIL_BIN/rm" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$RMFAIL_BIN/rm"

cleanup_clean_status=0
PATH="$RMFAIL_BIN:$PATH" "$CHECKER" "$untracked" >"$SCRATCH/output" 2>&1 ||
	cleanup_clean_status=$?
if [ "$cleanup_clean_status" -ne 2 ]; then
	printf 'public-safety-test: a failed cleanup on a clean run must fault, got %s\n' \
		"$cleanup_clean_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
if ! grep -qF 'retained scratch path' "$SCRATCH/output"; then
	printf 'public-safety-test: a failed cleanup should name the retained path\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The other half: a run that already found a secret keeps its finding status, so
# the fault cannot mask a real report.
cleanup_finding_status=0
PATH="$RMFAIL_BIN:$PATH" "$CHECKER" "$duplicate" >"$SCRATCH/output" 2>&1 ||
	cleanup_finding_status=$?
if [ "$cleanup_finding_status" -ne 1 ]; then
	printf 'public-safety-test: a finding must survive a failed cleanup, got %s\n' \
		"$cleanup_finding_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The scratch file is a directory-scan cost, so a mktemp that cannot answer is a
# fault for a directory and must not fall through to a walk.
MKTEMPFAIL_BIN="$SCRATCH/mktempfail-bin"
mkdir -p "$MKTEMPFAIL_BIN"
cat >"$MKTEMPFAIL_BIN/mktemp" <<'EOF'
#!/usr/bin/env bash
printf 'stub mktemp: no usable temp directory\n' >&2
exit 1
EOF
chmod +x "$MKTEMPFAIL_BIN/mktemp"
scratch_fault_status=0
PATH="$MKTEMPFAIL_BIN:$PATH" "$CHECKER" "$empty_listing" >"$SCRATCH/output" 2>&1 ||
	scratch_fault_status=$?
if [ "$scratch_fault_status" -ne 2 ]; then
	printf 'public-safety-test: an unusable scratch file must fault, got %s\n' \
		"$scratch_fault_status" >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi
if ! grep -qF 'could not create a scratch file' "$SCRATCH/output"; then
	printf 'public-safety-test: the fault should name the scratch file\n' >&2
	cat "$SCRATCH/output" >&2
	exit 1
fi

# The claim the git preflight's placement rests on: a host without git can still
# scan a regular file, and only a directory faults. The PATH is rebuilt from
# scratch with everything the gate needs except git, because shadowing git would
# leave `command -v git` succeeding.
NOGIT_BIN="$SCRATCH/nogit-bin"
mkdir -p "$NOGIT_BIN"
nogit_ready=1
for required in bash dirname rg jq mktemp rm awk; do
	if required_path=$(command -v "$required"); then
		ln -sf "$required_path" "$NOGIT_BIN/$required"
	else
		nogit_ready=0
		break
	fi
done
if [ "$nogit_ready" -eq 1 ]; then
	nogit_dir_status=0
	PATH="$NOGIT_BIN" "$CHECKER" "$empty_listing" >"$SCRATCH/output" 2>&1 ||
		nogit_dir_status=$?
	if [ "$nogit_dir_status" -ne 2 ]; then
		printf 'public-safety-test: a directory scan without git must fault, got %s\n' \
			"$nogit_dir_status" >&2
		cat "$SCRATCH/output" >&2
		exit 1
	fi
	if ! grep -qF 'git is required to scan a directory' "$SCRATCH/output"; then
		printf 'public-safety-test: the fault should name the missing tool\n' >&2
		cat "$SCRATCH/output" >&2
		exit 1
	fi

	printf 'public content\n' >"$file_target"
	if ! PATH="$NOGIT_BIN" "$CHECKER" "$file_target" >"$SCRATCH/output" 2>&1; then
		printf 'public-safety-test: a file scan without git must stay green\n' >&2
		cat "$SCRATCH/output" >&2
		exit 1
	fi
	printf '%s\n' "$hidden_secret" >"$file_target"
	nogit_file_status=0
	PATH="$NOGIT_BIN" "$CHECKER" "$file_target" >"$SCRATCH/output" 2>&1 ||
		nogit_file_status=$?
	if [ "$nogit_file_status" -ne 1 ]; then
		printf 'public-safety-test: a file scan without git must still report, got %s\n' \
			"$nogit_file_status" >&2
		cat "$SCRATCH/output" >&2
		exit 1
	fi
else
	printf 'public-safety-test: SKIP git-absent cases: could not assemble a git-free PATH.\n'
	printf 'public-safety-test: This run did not check them.\n'
fi

printf 'public-safety-test: ok\n'
