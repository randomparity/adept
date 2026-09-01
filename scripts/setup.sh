#!/usr/bin/env bash
set -euo pipefail

# Installs the tools `just verify` needs on macOS and Linux, then leaves the
# clone able to run the guardrail suite. `just setup` runs this and then `just
# hooks`.
#
# The tool set is not invented here. It is what .github/workflows/verify.yml
# installs before it runs `just ci`, because a workstation that cannot run a
# gate CI hard-gates is a workstation that finds its breakage in a pull request
# instead. `just` is deliberately absent from it: running this recipe requires
# just, so a missing just is a prerequisite the README names, not something this
# script could repair from inside a just recipe.
#
# Distro packages first, upstream channels only where no supported manager
# carries the tool. Four fall outside the managers:
#
#   zizmor   scripts/run-zizmor.sh admits exactly one version, so it is pinned
#            here and no package manager's floating version would satisfy it.
#   prek     packaged by Homebrew and nothing else this script supports.
#   claude   published to npm only.
#   actionlint  packaged by Homebrew and pacman; apt and dnf carry no package,
#            so those two use actionlint's own documented download script.
#
# Nothing here is a long-lived process and nothing here is a skill: this is
# repository tooling under scripts/, invoked by a just recipe and gone when it
# exits.
#
# Everything already on PATH is left alone, including a tool installed by some
# other route, so a re-run installs only what is missing. The one exception is
# zizmor at the wrong version, which is reinstalled at the pinned one because
# the gate rejects every other.
#
# Exit 0 when every required tool is present afterwards, 1 when one is not or an
# install failed, 2 on a usage error or an unsupported platform.

LABEL='setup'

# Must equal EXPECTED_ZIZMOR_VERSION in scripts/run-zizmor.sh. setup-test.sh
# asserts the two agree, so a bump there reddens the suite rather than leaving
# this script installing a version the gate refuses.
ZIZMOR_VERSION='1.29.0'

# Required means `just verify` cannot complete without it, so the list is the
# verdict this script reports on. uv and npm are channels rather than gates and
# are installed only when something below needs them.
REQUIRED_TOOLS='git rg shellcheck shfmt jq zsh actionlint zizmor prek claude'

usage() {
	cat <<'EOF'
usage: setup.sh [--dry-run]

Installs the tools `just verify` needs, using this host's package manager
(Homebrew on macOS; apt-get, dnf or pacman on Linux) and the upstream channel
for the tools no supported manager carries.

  --dry-run, -n   print every command that would run, change nothing
  --help, -h      print this message
EOF
}

say() {
	printf '%s: %s\n' "$LABEL" "$*"
}

fail() { # status message...
	local status=$1
	shift
	printf '%s: %s\n' "$LABEL" "$*" >&2
	exit "$status"
}

have() { # binary
	command -v "$1" >/dev/null 2>&1
}

dry_run=0
for argument in "$@"; do
	case $argument in
	--dry-run | -n) dry_run=1 ;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		usage >&2
		fail 2 "unknown argument: $argument"
		;;
	esac
done

# uv installs itself and the tools it manages under ~/.local/bin, and so does
# the npm prefix chosen below, so this shell has to see that directory before
# any of them is invoked -- otherwise `uv tool install` runs in the same
# invocation that just installed uv and cannot find it. Exported, because the
# installers this script runs are separate processes.
local_bin="$HOME/.local/bin"
inherited_path=$PATH
case ":$PATH:" in
*":$local_bin:"*) ;;
*) PATH="$local_bin:$PATH" ;;
esac
export PATH

# The command is printed before it runs, in both modes. A setup script that
# invokes a package manager under sudo owes the operator a record of what it
# asked for, and printing it only in --dry-run would mean the record exists
# exactly where nothing happened.
run() { # command...
	if ((dry_run)); then
		printf '%s: would run:' "$LABEL"
		printf ' %s' "$@"
		printf '\n'
		return 0
	fi
	printf '%s: running:' "$LABEL"
	printf ' %s' "$@"
	printf '\n'
	"$@"
}

# For the two upstream installers, which are pipelines rather than an argv.
# `-o pipefail` so a curl that fails does not reach `sh` as an empty script that
# exits 0 -- the whole failure mode of piping a download into a shell.
run_shell() { # command-string
	if ((dry_run)); then
		printf '%s: would run: %s\n' "$LABEL" "$1"
		return 0
	fi
	printf '%s: running: %s\n' "$LABEL" "$1"
	bash -o pipefail -c "$1"
}

platform=''
manager=''
case "$(uname -s)" in
Darwin)
	platform='macos'
	if ! have brew; then
		fail 2 'Homebrew is required on macOS; install it from https://brew.sh and re-run'
	fi
	manager='brew'
	;;
Linux)
	platform='linux'
	for candidate in apt-get dnf pacman; do
		if have "$candidate"; then
			manager=$candidate
			break
		fi
	done
	if [[ -z $manager ]]; then
		fail 2 'no supported package manager found; this script handles apt-get, dnf and pacman'
	fi
	;;
*)
	fail 2 "unsupported operating system: $(uname -s); this script handles macOS and Linux"
	;;
esac

say "platform $platform; package manager $manager"

# The privilege prefix is empty on macOS, where Homebrew refuses to run as root,
# and on a Linux container already running as root.
privileged=()
if [[ $manager != brew ]] && ((EUID != 0)); then
	if ! have sudo; then
		fail 2 "$manager needs root and sudo is not installed; re-run this script as root"
	fi
	privileged=(sudo)
fi

run_privileged() { # command...
	run ${privileged[@]+"${privileged[@]}"} "$@"
}

# The package name for a binary under a manager, or empty when that manager
# carries no package for it. Empty is the routing decision, not an error: the
# caller falls through to the upstream channel.
package_for() { # binary
	case $1 in
	# Quoted, unlike its neighbours. check-ripgrep-config.sh reads shell text
	# rather than parsing it, and a bare `rg)` label reduces to a command word
	# `rg` under its separator split, so it reports this line as a ripgrep call
	# running with RIPGREP_CONFIG_PATH still readable. Quoting is the shape that
	# scanner already understands as data; the alternative is an `unset
	# RIPGREP_CONFIG_PATH` in a file that never runs ripgrep.
	"rg") printf 'ripgrep\n' ;;
	git | jq | zsh | shfmt) printf '%s\n' "$1" ;;
	shellcheck)
		case $manager in
		dnf) printf 'ShellCheck\n' ;;
		*) printf 'shellcheck\n' ;;
		esac
		;;
	actionlint)
		case $manager in
		brew | pacman) printf 'actionlint\n' ;;
		*) printf '\n' ;;
		esac
		;;
	prek)
		case $manager in
		brew) printf 'prek\n' ;;
		*) printf '\n' ;;
		esac
		;;
	*) printf '\n' ;;
	esac
}

# apt-get's index refresh is slow, and reaching install_packages more than once
# in a run is the ordinary shape rather than the exception: the batch below, then
# again for whichever of uv and npm has to be pulled in behind it. Refreshed once
# per invocation.
apt_updated=0

install_packages() { # package...
	if (($# == 0)); then
		return 0
	fi
	case $manager in
	brew) run brew install "$@" ;;
	apt-get)
		if ((apt_updated == 0)); then
			run_privileged apt-get update
			apt_updated=1
		fi
		run_privileged apt-get install -y "$@"
		;;
	dnf) run_privileged dnf install -y "$@" ;;
	pacman) run_privileged pacman -S --needed --noconfirm "$@" ;;
	esac
}

# uv is the channel for prek and zizmor, so it is installed only when one of
# them is missing. On Linux it comes from Astral's standalone installer rather
# than a package: apt and dnf carry no uv at all, and routing pacman separately
# would add a fourth distro fact this script has to keep true for the sake of
# one host family.
ensure_uv() {
	if have uv; then
		return 0
	fi
	if [[ $manager == brew ]]; then
		install_packages uv
		return 0
	fi
	run_shell "curl -LsSf https://astral.sh/uv/install.sh | sh"
}

ensure_npm() {
	if have npm; then
		return 0
	fi
	case $manager in
	brew) install_packages node ;;
	*) install_packages npm ;;
	esac
}

# First line only. Several of these tools print a banner and a version block,
# and the caller wants one line per tool; the exact string matters only for
# zizmor, which is compared below against its own `zizmor <version>` output.
tool_version() { # binary
	local output=''
	if output=$("$1" --version 2>&1); then
		printf '%s\n' "${output%%$'\n'*}"
	else
		printf 'unknown\n'
	fi
}

zizmor_is_pinned() {
	if ! have zizmor; then
		return 1
	fi
	[[ $(tool_version zizmor) == "zizmor $ZIZMOR_VERSION" ]]
}

missing=()
for tool in $REQUIRED_TOOLS; do
	if have "$tool"; then
		say "present  $tool  $(tool_version "$tool")"
	else
		say "missing  $tool"
		missing+=("$tool")
	fi
done

if have zizmor && ! zizmor_is_pinned; then
	say "pinned   zizmor $ZIZMOR_VERSION required by scripts/run-zizmor.sh; reinstalling over $(tool_version zizmor)"
	missing+=(zizmor)
fi

# Each missing tool is routed once, here, and the upstream blocks below read
# that routing rather than re-deriving it. Deriving it twice is how a tool the
# manager had just installed also got installed from upstream on top of it.
#
# One manager invocation for everything it carries, rather than one per tool:
# apt-get and dnf resolve a batch far faster than a sequence, and a single
# `sudo` prompt is the difference between a setup that runs unattended and one
# that does not.
packages=()
upstream=()
for tool in ${missing[@]+"${missing[@]}"}; do
	package=$(package_for "$tool")
	if [[ -n $package ]]; then
		packages+=("$package")
	else
		upstream+=("$tool")
	fi
done
install_packages ${packages[@]+"${packages[@]}"}

from_upstream() { # binary
	local candidate
	for candidate in ${upstream[@]+"${upstream[@]}"}; do
		if [[ $candidate == "$1" ]]; then
			return 0
		fi
	done
	return 1
}

if from_upstream prek || from_upstream zizmor; then
	ensure_uv
fi
if from_upstream prek; then
	run uv tool install prek
fi
if from_upstream zizmor; then
	# --force so a wrong version already installed by uv is replaced rather than
	# reported as already satisfied, which is the case that brought us here.
	run uv tool install --force "zizmor==$ZIZMOR_VERSION"
fi

if from_upstream actionlint; then
	# actionlint's own documented installer, asked for the latest release.
	# Latest rather than a pin because CI installs it from Homebrew unpinned, so
	# a pin here would gate this workstation against a version no runner has.
	#
	# The destination reaches the installer through the environment rather than
	# spliced into the command string: this is the one place a path derived from
	# $HOME would be interpolated into shell source, and a home directory
	# carrying a quote would turn it into something other than a path. Named on
	# its own line so the operator still sees where it lands.
	say "installing actionlint into $local_bin"
	export SETUP_LOCAL_BIN=$local_bin
	# shellcheck disable=SC2016 # expanded by run_shell's shell, which is the point
	run_shell 'mkdir -p "$SETUP_LOCAL_BIN" && curl -sSfL https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash | bash -s -- latest "$SETUP_LOCAL_BIN"'
fi

if from_upstream claude; then
	ensure_npm
	case $manager in
	# Homebrew's node prefix is user-writable, so a global install needs no
	# privilege. A distro npm's is /usr, and rather than run npm under sudo this
	# takes the same ~/.local prefix uv already uses.
	brew) run npm install -g @anthropic-ai/claude-code ;;
	*) run npm install -g --prefix "$HOME/.local" @anthropic-ai/claude-code ;;
	esac
fi

if ((dry_run)); then
	say 'dry run: nothing was installed'
	exit 0
fi

# The verdict comes from a fresh lookup rather than from the installs reporting
# success. A package manager that exits 0 having put a binary somewhere this
# shell cannot see is the failure this script exists to make visible, and
# ~/.local/bin not being on the operator's own PATH is the common form of it.
hash -r
still_missing=()
for tool in $REQUIRED_TOOLS; do
	if have "$tool"; then
		say "ok       $tool  $(tool_version "$tool")  $(command -v "$tool")"
	else
		still_missing+=("$tool")
	fi
done

if ((${#still_missing[@]})); then
	printf '%s: still missing after install: %s\n' "$LABEL" "${still_missing[*]}" >&2
	case ":$PATH:" in
	*":$local_bin:"*)
		printf '%s: install the remaining tools by hand, then re-run\n' "$LABEL" >&2
		;;
	*)
		printf '%s: ~/.local/bin is not on your PATH; add it to your shell profile and re-run\n' "$LABEL" >&2
		;;
	esac
	exit 1
fi

if ! zizmor_is_pinned; then
	fail 1 "zizmor is $(tool_version zizmor) but scripts/run-zizmor.sh requires zizmor $ZIZMOR_VERSION"
fi

# Said rather than left to be discovered. This process put ~/.local/bin on its
# own PATH so the tools it installed there could be verified; the operator's
# next shell reads their profile instead, and every one of those tools would be
# missing from it.
case ":$inherited_path:" in
*":$local_bin:"*) ;;
*) say 'add ~/.local/bin to your PATH in your shell profile; this run put it on PATH only for itself' ;;
esac
say 'every required tool is present'
