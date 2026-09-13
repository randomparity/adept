#!/usr/bin/env bash
# Materialize one frozen planning packet; no instructions or later repairs are included.
set -euo pipefail
set -C

if [ "$#" -ne 2 ] || [ -e "$2" ] || [ -L "$2" ]; then
	printf 'usage: architecture-eval-fixtures.sh CASE NEW-FILE\n' >&2
	exit 2
fi

case "$1" in
python-documents)
	cat >"$2" <<'PACKET'
Case PY-DOC. Historical Python snapshot source-PY1 (the parent before a
document-module change). `src/hmc_mcp/templates.py` starts: "XML builders for
LogicalPartition and ManagedSystem create/modify documents" and defines
`LparResources` and document builders. A separate
`src/hmc_mcp/client_templates.py` owns Template Library query/deploy methods.
These are source facts from that snapshot, not a later repair or required answer.

Requested feature: add a SystemPreferences modify-document builder used by a
client operation. Give the current and intended responsibility owners, changed
files, caller migration and obsolete-path disposition, contract considerations,
and verification. Choose an extension or ownership change based on the facts;
do not silently import later repository state.
PACKET
	;;
python-facade)
	cat >"$2" <<'PACKET'
Case PY-FACADE. Historical Python snapshot source-PY2 (the parent before a
reusable-API facade change). `src/hmc_mcp/client.py` composes domain mixins
into `HMCClient` and owns session and HTTP transport; domain operations live
in `client_*` modules. `src/hmc_mcp/client_contracts.py` defines mixin host
protocols and imports `httpx` at runtime. `tests/unit/test_templates_api.py`
imports `HMCClient` directly from `hmc_mcp.client`. No `src/hmc_mcp/api.py`
exists in this snapshot. These are source facts, not the later implementation.

Requested feature: introduce a supported reusable Python API without importing
presentation modules. Identify a credible owner for exports and transport
contract responsibilities, affected import callers, old-path disposition,
compatibility judgment, and verification. Do not assume every internal import
is a public contract; identify evidence needed before breaking one.
PACKET
	;;
rust-policy)
	cat >"$2" <<'PACKET'
Case RS-POLICY. Synthetic Rust crate: `src/api.rs::can_send(User)` and
`src/jobs.rs::can_send(User)` independently encode the same active/not-banned
rule. `src/worker.rs` calls jobs; `src/http.rs` calls api. The requested feature
adds a paused status that must suppress both paths. `api::can_send` is a public
function with a tested signature; internal module layout has no contract.

Choose a coherent owner or explain why two rules remain justified. Show the
caller migration, disposition of duplicate predicates and any public adapter,
focused tests, and a realistic verification command. A plan that updates only
one predicate leaves a reachable failure.
PACKET
	;;
cpp-contract)
	cat >"$2" <<'PACKET'
Case CPP-CONTRACT. Synthetic C++ library: `include/store/Cache.h` exposes
`Cache::read(Key) -> Result` to external clients and an accepted ABI decision
freezes its symbol and signature. `src/Cache.cpp` and `src/Loader.cpp` each
contain independent stale-entry checks; `src/Refresh.cpp` calls Loader. The
feature adds a stale grace interval. A proposed shortcut removes `Cache::read`
and sends clients to Loader directly. No authorization changes the ABI decision.

Choose ownership and full caller migration, handle the proposed public-contract
break explicitly, name retained paths and tests, and refuse unrelated cleanup
outside this feature. Multiple internal designs may be defensible.
PACKET
	;;
bash-extension)
	cat >"$2" <<'PACKET'
Case SH-EXTENSION. Synthetic Bash repository: `scripts/report.sh` alone owns
report formatting and calls `scripts/collect.sh` for data. `tests/report.sh`
checks current output. The feature adds `--json` output without changing data
collection. A nearby `scripts/deploy.sh` has an unrelated quoting defect.
No external format contract is stated; the existing text output remains used.

Choose the smallest coherent owner, state validation and tests for text/JSON
behavior, and decide whether deploy cleanup belongs in this change. Do not
invent a new shared formatter unless a concrete need requires it.
PACKET
	;;
*)
	printf 'architecture-eval-fixtures: unknown case: %s\n' "$1" >&2
	exit 2
	;;
esac
