#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

for case in python-documents python-facade rust-policy cpp-contract bash-extension; do
	bash "$root/architecture-eval-fixtures.sh" "$case" "$scratch/first"
	bash "$root/architecture-eval-fixtures.sh" "$case" "$scratch/second"
	cmp "$scratch/first" "$scratch/second"
	if bash "$root/architecture-eval-fixtures.sh" "$case" "$scratch/first"; then
		printf 'fixture overwrote %s\n' "$case" >&2
		exit 1
	fi
	rm "$scratch/first" "$scratch/second"
done

if bash "$root/architecture-eval-fixtures.sh" unknown "$scratch/unknown"; then
	printf 'fixture accepted unknown case\n' >&2
	exit 1
fi
test ! -e "$scratch/unknown"
ln -s "$scratch/absent" "$scratch/dangling"
if bash "$root/architecture-eval-fixtures.sh" rust-policy "$scratch/dangling"; then
	printf 'fixture followed a pre-existing symlink\n' >&2
	exit 1
fi
test ! -e "$scratch/absent"
printf 'architecture-eval-fixtures-test: all assertions passed\n'
