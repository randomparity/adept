"""Manifest schema constants and digest computation for the v1 benchmark protocol.

This module holds the pinned protocol values and the canonical-JSON digest
function used by the manifest validator and the selection algorithm. It is
stdlib-only and imported by every other benchmarks/ module.
"""

import hashlib
import json

PROTOCOL_VERSION = "adept-workflow-v1"
SCHEMA_VERSION = "1.0.0"

DATASET_NAME = "SWE-bench/SWE-bench_Verified"
DATASET_SPLIT = "test"
DATASET_REVISION = "03e151cf5560b1af6a4363c6a9d766deaaea6b56"

EVALUATOR_NAME = "SWE-bench/SWE-bench"
EVALUATOR_REVISION = "128cbd1a5759694874e6bd56624cb2fd6fb079e2"

SUPPORTED_LICENSES = frozenset(
    {
        "MIT",
        "BSD-2-Clause",
        "BSD-3-Clause",
        "Apache-2.0",
        "ISC",
        "Python-2.0",
        "PSF-2.0",
    }
)

REQUIRED_TASK_FIELDS = (
    "instance_id",
    "issue_url",
    "license",
    "original_base_commit",
    "fail_to_pass",
    "pass_to_pass",
    "test_patch",
    "adaptation_evidence",
)

REQUIRED_EVIDENCE_FIELDS = (
    "gold_patch_applied_cleanly",
    "pre_patch_failures",
    "post_patch_all_pass",
    "evaluator_image",
)


def canonical_json_bytes(data: dict) -> bytes:
    """Serialize to RFC 8785 canonical JSON (sorted keys, no whitespace)."""
    return json.dumps(data, sort_keys=True, separators=(",", ":")).encode("utf-8")


def compute_manifest_digest(manifest: dict) -> str:
    """Compute the SHA-256 digest of the manifest's canonical JSON.

    The digest is computed with ``selection.manifest_digest`` set to an empty
    string so the digest field itself does not affect the digest value.
    """
    temp = dict(manifest)
    selection = dict(temp.get("selection", {}))
    selection["manifest_digest"] = ""
    temp["selection"] = selection
    return hashlib.sha256(canonical_json_bytes(temp)).hexdigest()
