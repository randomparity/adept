#!/usr/bin/env bash
set -euo pipefail

# Behaviour suite for scripts/setup.sh.
#
# Every case runs the script in --dry-run against a hermetic PATH holding only
# stub executables, so the suite decides what this host appears to be and what
# is already installed, and installs nothing. A dry run leaves the shell's
# builtins for everything except `uname` and the `cat` in usage(), which is why
# a stub directory alone is a complete PATH.
#
# What is under test is the routing: which package manager is chosen, which
# package name each tool gets under it, which tools fall through to an upstream
# channel, and which are skipped because they are already present. The installs
# themselves are the package managers' business and are not re-tested here.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

fixture_init setup-test

setup=$script_dir/setup.sh
home=$SCRATCH/home
mkdir -p "$home"

write_stub() { # dir name body
	local path=$1/$2
	printf '#!/usr/bin/env bash\n%s\n' "$3" >"$path"
	chmod +x "$path"
}

# `uname` is the only external the platform branch runs, and `cat` the only one
# usage() runs. Both are stubbed into every fixture so no case depends on the
# host's own PATH.
new_stubs() { # name kernel
	local dir=$SCRATCH/$1
	mkdir -p "$dir"
	# The one entry that is not a stub. setup.sh and the stubs alike start
	# `#!/usr/bin/env bash`, and env resolves bash through PATH -- which is this
	# directory and nothing else -- so without it every case exits 127 before
	# the script's first line.
	ln -s "$BASH" "$dir/bash"
	write_stub "$dir" cat 'exec /bin/cat "$@"'
	write_stub "$dir" uname "printf '%s\\n' '$2'"
	printf '%s\n' "$dir"
}

# A tool that answers --version, which is how setup.sh decides a tool is present
# and how it reads zizmor's version.
stub_tool() { # dir name [version-line]
	local version=${3:-"$2 9.9.9"}
	write_stub "$1" "$2" "printf '%s\\n' '$version'"
}

stub_all_required() { # dir [zizmor-version-line]
	local dir=$1 tool
	for tool in git rg shellcheck shfmt jq zsh actionlint prek claude; do
		stub_tool "$dir" "$tool"
	done
	stub_tool "$dir" zizmor "${2:-zizmor 1.29.0}"
}

RUN_OUTPUT=''
RUN_STATUS=0
run_setup() { # stub-dir argument...
	local dir=$1
	shift
	RUN_STATUS=0
	RUN_OUTPUT=$(PATH="$dir" HOME="$home" "$setup" "$@" 2>&1) || RUN_STATUS=$?
}

assert_status() { # name expected
	[[ $RUN_STATUS -eq $2 ]] ||
		fail "$1: expected exit $2, got $RUN_STATUS: $RUN_OUTPUT"
}

assert_contains() { # name fragment
	[[ $RUN_OUTPUT == *"$2"* ]] ||
		fail "$1: expected '$2' in: $RUN_OUTPUT"
}

assert_lacks() { # name fragment
	[[ $RUN_OUTPUT != *"$2"* ]] ||
		fail "$1: expected no '$2' in: $RUN_OUTPUT"
}

# --- usage ------------------------------------------------------------------

help_stubs=$(new_stubs help Darwin)
stub_tool "$help_stubs" brew
run_setup "$help_stubs" --help
assert_status 'help' 0
assert_contains 'help' 'usage: setup.sh'
assert_lacks 'help' 'would run:'

run_setup "$help_stubs" --nope
assert_status 'unknown argument' 2
assert_contains 'unknown argument' 'unknown argument: --nope'

# --- platform detection -----------------------------------------------------

alien_stubs=$(new_stubs alien Plan9)
run_setup "$alien_stubs" --dry-run
assert_status 'unsupported kernel' 2
assert_contains 'unsupported kernel' 'unsupported operating system: Plan9'

# Homebrew is the only manager this script drives on macOS, so its absence is a
# stop with an instruction rather than a fall-through to a Linux branch.
nobrew_stubs=$(new_stubs nobrew Darwin)
run_setup "$nobrew_stubs" --dry-run
assert_status 'macOS without Homebrew' 2
assert_contains 'macOS without Homebrew' 'Homebrew is required on macOS'

bare_linux_stubs=$(new_stubs bare-linux Linux)
run_setup "$bare_linux_stubs" --dry-run
assert_status 'Linux without a manager' 2
assert_contains 'Linux without a manager' 'no supported package manager found'

# --- macOS routing ----------------------------------------------------------

# Homebrew carries every tool but the three with no bottle here, so the macOS
# plan is one `brew install` plus the pinned zizmor and the npm-only CLI.
brew_stubs=$(new_stubs brew Darwin)
stub_tool "$brew_stubs" brew
run_setup "$brew_stubs" --dry-run
assert_status 'macOS plan' 0
assert_contains 'macOS plan' 'platform macos; package manager brew'
assert_contains 'macOS plan' 'would run: brew install'
for package in git ripgrep shellcheck shfmt jq zsh actionlint prek; do
	assert_contains 'macOS plan' " $package"
done
assert_contains 'macOS plan' 'would run: uv tool install --force zizmor==1.29.0'
assert_contains 'macOS plan' 'would run: npm install -g @anthropic-ai/claude-code'
# Homebrew has an actionlint bottle and a prek bottle, so neither takes an
# upstream channel here.
assert_lacks 'macOS plan' 'download-actionlint.bash'
assert_lacks 'macOS plan' 'uv tool install prek'
# Homebrew's node prefix is writable, so the npm install takes no --prefix.
assert_lacks 'macOS plan' '--prefix'
# brew never runs under sudo.
assert_lacks 'macOS plan' 'sudo'

# --- Linux routing ----------------------------------------------------------

apt_stubs=$(new_stubs apt Linux)
stub_tool "$apt_stubs" apt-get
stub_tool "$apt_stubs" sudo
run_setup "$apt_stubs" --dry-run
assert_status 'apt plan' 0
assert_contains 'apt plan' 'platform linux; package manager apt-get'
assert_contains 'apt plan' 'would run: sudo apt-get update'
assert_contains 'apt plan' 'would run: sudo apt-get install -y'
assert_contains 'apt plan' ' shellcheck'
# Debian's package is lowercase; only Fedora's is not.
assert_lacks 'apt plan' 'ShellCheck'
# The four tools apt carries no package for, each on its documented channel.
assert_contains 'apt plan' 'https://astral.sh/uv/install.sh'
assert_contains 'apt plan' 'would run: uv tool install prek'
assert_contains 'apt plan' 'would run: uv tool install --force zizmor==1.29.0'
assert_contains 'apt plan' 'download-actionlint.bash'
assert_contains 'apt plan' 'would run: npm install -g --prefix'

# The index refresh happens once, not once per install_packages call. uv and npm
# both reach that function after the batch, and on a slow mirror three refreshes
# is the difference between a setup that finishes and one an operator kills.
apt_updates=0
while IFS= read -r line; do
	case $line in
	*'apt-get update'*) apt_updates=$((apt_updates + 1)) ;;
	esac
done <<<"$RUN_OUTPUT"
[[ $apt_updates -eq 1 ]] ||
	fail "apt plan: expected one apt-get update, got $apt_updates: $RUN_OUTPUT"

dnf_stubs=$(new_stubs dnf Linux)
stub_tool "$dnf_stubs" dnf
stub_tool "$dnf_stubs" sudo
run_setup "$dnf_stubs" --dry-run
assert_status 'dnf plan' 0
assert_contains 'dnf plan' 'would run: sudo dnf install -y'
# Fedora's package is capitalised, and installing 'shellcheck' there fails.
assert_contains 'dnf plan' ' ShellCheck'
assert_contains 'dnf plan' 'download-actionlint.bash'

pacman_stubs=$(new_stubs pacman Linux)
stub_tool "$pacman_stubs" pacman
stub_tool "$pacman_stubs" sudo
run_setup "$pacman_stubs" --dry-run
assert_status 'pacman plan' 0
assert_contains 'pacman plan' 'would run: sudo pacman -S --needed --noconfirm'
# Arch is the one Linux family with an actionlint package, so it does not take
# the download script.
assert_contains 'pacman plan' ' actionlint'
assert_lacks 'pacman plan' 'download-actionlint.bash'

# A manager needing root with no way to get it stops before the first install
# rather than failing partway through one. Meaningless when the suite is already
# root, which is the ordinary shape in a container.
if ((EUID != 0)); then
	nosudo_stubs=$(new_stubs nosudo Linux)
	stub_tool "$nosudo_stubs" apt-get
	run_setup "$nosudo_stubs" --dry-run
	assert_status 'Linux without sudo' 2
	assert_contains 'Linux without sudo' 'sudo is not installed'
fi

# --- what is already installed ----------------------------------------------

# The idempotence case: a clone whose tools are all present installs nothing.
present_stubs=$(new_stubs present Darwin)
stub_tool "$present_stubs" brew
stub_all_required "$present_stubs"
run_setup "$present_stubs" --dry-run
assert_status 'nothing to do' 0
assert_contains 'nothing to do' 'dry run: nothing was installed'
assert_contains 'nothing to do' 'present  jq'
assert_lacks 'nothing to do' 'would run:'

# zizmor is the one tool whose mere presence is not enough: scripts/run-zizmor.sh
# admits exactly one version and exits 1 on every other, so a wrong one is
# reinstalled rather than left alone.
stale_stubs=$(new_stubs stale Darwin)
stub_tool "$stale_stubs" brew
stub_all_required "$stale_stubs" 'zizmor 1.30.0'
run_setup "$stale_stubs" --dry-run
assert_status 'stale zizmor' 0
assert_contains 'stale zizmor' 'reinstalling over zizmor 1.30.0'
assert_contains 'stale zizmor' 'would run: uv tool install --force zizmor==1.29.0'
# uv is pulled in because it is the channel that reinstalls zizmor, and nothing
# else is: the tools that are present stay untouched.
assert_contains 'stale zizmor' 'would run: brew install uv'
assert_lacks 'stale zizmor' ' ripgrep'
assert_lacks 'stale zizmor' 'npm install'

# --- the pin agrees with the gate that enforces it --------------------------

# setup.sh installs zizmor and scripts/run-zizmor.sh refuses every version but
# one. Two constants, and a bump to either alone leaves `just setup` installing
# a version `just actions-check` rejects -- on a fresh clone, where the operator
# has no reason to suspect the setup step.
constant_of() { # file name
	local file=$1 name=$2 line value
	while IFS= read -r line; do
		case $line in
		"$name="*)
			value=${line#*=}
			value=${value#\'}
			value=${value%\'}
			printf '%s\n' "$value"
			return 0
			;;
		esac
	done <"$file"
	return 1
}

setup_pin=$(constant_of "$setup" ZIZMOR_VERSION) ||
	fail 'pin agreement: setup.sh declares no ZIZMOR_VERSION'
gate_pin=$(constant_of "$script_dir/run-zizmor.sh" EXPECTED_ZIZMOR_VERSION) ||
	fail 'pin agreement: run-zizmor.sh declares no EXPECTED_ZIZMOR_VERSION'
[[ $setup_pin == "$gate_pin" ]] ||
	fail "pin agreement: setup.sh installs zizmor $setup_pin, run-zizmor.sh requires $gate_pin"

printf 'setup-test: all cases passed\n'
