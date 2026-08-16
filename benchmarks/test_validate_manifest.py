"""Tests for the manifest validator."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from benchmarks.manifest import (
    DATASET_NAME,
    DATASET_REVISION,
    DATASET_SPLIT,
    EVALUATOR_NAME,
    EVALUATOR_REVISION,
    PROTOCOL_VERSION,
    SCHEMA_VERSION,
    compute_manifest_digest,
)
from benchmarks.validate_manifest import validate_manifest


def make_valid_manifest() -> dict:
    """Return a known-good manifest dict for mutation in tests."""
    manifest = {
        "protocol_version": PROTOCOL_VERSION,
        "schema_version": SCHEMA_VERSION,
        "dataset": {
            "name": DATASET_NAME,
            "split": DATASET_SPLIT,
            "revision": DATASET_REVISION,
        },
        "evaluator": {
            "name": EVALUATOR_NAME,
            "revision": EVALUATOR_REVISION,
        },
        "groups": [
            {
                "group_id": "A",
                "repository": "owner-alpha/repo",
                "common_revision": "a" * 40,
                "tasks": [
                    {
                        "instance_id": "owner_alpha__repo-100",
                        "issue_url": "https://github.com/owner-alpha/repo/issues/100",
                        "license": "MIT",
                        "original_base_commit": "a" * 40,
                        "fail_to_pass": ["test.module::test_a"],
                        "pass_to_pass": ["test.module::test_b"],
                        "test_patch": "diff --git a/test.py b/test.py\n",
                        "adaptation_evidence": {
                            "gold_patch_applied_cleanly": True,
                            "pre_patch_failures": ["test.module::test_a"],
                            "post_patch_all_pass": True,
                            "evaluator_image": "swe-bench:latest",
                        },
                        "materialized_issue_number": None,
                    },
                    {
                        "instance_id": "owner_alpha__repo-200",
                        "issue_url": "https://github.com/owner-alpha/repo/issues/200",
                        "license": "MIT",
                        "original_base_commit": "a" * 40,
                        "fail_to_pass": ["test.module::test_c"],
                        "pass_to_pass": [],
                        "test_patch": "diff --git a/test2.py b/test2.py\n",
                        "adaptation_evidence": {
                            "gold_patch_applied_cleanly": True,
                            "pre_patch_failures": ["test.module::test_c"],
                            "post_patch_all_pass": True,
                            "evaluator_image": "swe-bench:latest",
                        },
                        "materialized_issue_number": None,
                    },
                    {
                        "instance_id": "owner_alpha__repo-300",
                        "issue_url": "https://github.com/owner-alpha/repo/issues/300",
                        "license": "MIT",
                        "original_base_commit": "a" * 40,
                        "fail_to_pass": ["test.module::test_d"],
                        "pass_to_pass": [],
                        "test_patch": "diff --git a/test3.py b/test3.py\n",
                        "adaptation_evidence": {
                            "gold_patch_applied_cleanly": True,
                            "pre_patch_failures": ["test.module::test_d"],
                            "post_patch_all_pass": True,
                            "evaluator_image": "swe-bench:latest",
                        },
                        "materialized_issue_number": None,
                    },
                ],
            },
            {
                "group_id": "B",
                "repository": "owner-beta/repo",
                "common_revision": "b" * 40,
                "tasks": [
                    {
                        "instance_id": "owner_beta__repo-400",
                        "issue_url": "https://github.com/owner-beta/repo/issues/400",
                        "license": "BSD-3-Clause",
                        "original_base_commit": "b" * 40,
                        "fail_to_pass": ["test.module::test_e"],
                        "pass_to_pass": [],
                        "test_patch": "diff --git a/test4.py b/test4.py\n",
                        "adaptation_evidence": {
                            "gold_patch_applied_cleanly": True,
                            "pre_patch_failures": ["test.module::test_e"],
                            "post_patch_all_pass": True,
                            "evaluator_image": "swe-bench:latest",
                        },
                        "materialized_issue_number": None,
                    },
                    {
                        "instance_id": "owner_beta__repo-500",
                        "issue_url": "https://github.com/owner-beta/repo/issues/500",
                        "license": "BSD-3-Clause",
                        "original_base_commit": "b" * 40,
                        "fail_to_pass": ["test.module::test_f"],
                        "pass_to_pass": [],
                        "test_patch": "diff --git a/test5.py b/test5.py\n",
                        "adaptation_evidence": {
                            "gold_patch_applied_cleanly": True,
                            "pre_patch_failures": ["test.module::test_f"],
                            "post_patch_all_pass": True,
                            "evaluator_image": "swe-bench:latest",
                        },
                        "materialized_issue_number": None,
                    },
                    {
                        "instance_id": "owner_beta__repo-600",
                        "issue_url": "https://github.com/owner-beta/repo/issues/600",
                        "license": "BSD-3-Clause",
                        "original_base_commit": "b" * 40,
                        "fail_to_pass": ["test.module::test_g"],
                        "pass_to_pass": [],
                        "test_patch": "diff --git a/test6.py b/test6.py\n",
                        "adaptation_evidence": {
                            "gold_patch_applied_cleanly": True,
                            "pre_patch_failures": ["test.module::test_g"],
                            "post_patch_all_pass": True,
                            "evaluator_image": "swe-bench:latest",
                        },
                        "materialized_issue_number": None,
                    },
                ],
            },
        ],
        "selection": {
            "candidate_ledger": "ledger-test.json",
            "manifest_digest": "",
        },
    }
    manifest["selection"]["manifest_digest"] = compute_manifest_digest(manifest)
    return manifest


class TestValidateManifest(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = make_valid_manifest()

    def test_valid_manifest_no_findings(self) -> None:
        self.assertEqual(validate_manifest(self.manifest), [])

    def test_wrong_protocol_version(self) -> None:
        self.manifest["protocol_version"] = "wrong"
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("protocol_version" in f for f in findings))

    def test_wrong_dataset_revision(self) -> None:
        self.manifest["dataset"]["revision"] = "deadbeef" * 5
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("dataset" in f.lower() and "revision" in f.lower() for f in findings))

    def test_wrong_group_count(self) -> None:
        self.manifest["groups"] = [self.manifest["groups"][0]]
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("group" in f.lower() and "count" in f.lower() for f in findings))

    def test_wrong_task_count_per_group(self) -> None:
        self.manifest["groups"][0]["tasks"] = self.manifest["groups"][0]["tasks"][:2]
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("task" in f.lower() for f in findings))

    def test_duplicate_repository_across_groups(self) -> None:
        self.manifest["groups"][1]["repository"] = self.manifest["groups"][0]["repository"]
        findings = validate_manifest(self.manifest)
        self.assertTrue(
            any("repository" in f.lower() and "different" in f.lower() for f in findings)
        )

    def test_bad_license(self) -> None:
        self.manifest["groups"][0]["tasks"][0]["license"] = "GPL-3.0"
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("license" in f.lower() for f in findings))

    def test_bad_sha(self) -> None:
        self.manifest["groups"][0]["common_revision"] = "not-a-sha"
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("common_revision" in f.lower() or "sha" in f.lower() for f in findings))

    def test_missing_task_field(self) -> None:
        del self.manifest["groups"][0]["tasks"][0]["instance_id"]
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("instance_id" in f for f in findings))

    def test_empty_fail_to_pass(self) -> None:
        self.manifest["groups"][0]["tasks"][0]["fail_to_pass"] = []
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("fail_to_pass" in f for f in findings))

    def test_missing_evidence_field(self) -> None:
        del self.manifest["groups"][0]["tasks"][0]["adaptation_evidence"]["evaluator_image"]
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("adaptation_evidence" in f or "evaluator_image" in f for f in findings))

    def test_digest_mismatch(self) -> None:
        self.manifest["selection"]["manifest_digest"] = "0" * 64
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("digest" in f.lower() for f in findings))

    def test_test_patch_must_be_nonempty_string(self) -> None:
        self.manifest["groups"][0]["tasks"][0]["test_patch"] = ""
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("test_patch" in f for f in findings))

    def test_missing_groups_key(self) -> None:
        del self.manifest["groups"]
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("groups" in f for f in findings))

    def test_bad_issue_url(self) -> None:
        self.manifest["groups"][0]["tasks"][0]["issue_url"] = "http://example.com/123"
        findings = validate_manifest(self.manifest)
        self.assertTrue(any("issue_url" in f for f in findings))


class TestValidateManifestCLI(unittest.TestCase):
    def _write_manifest(self, manifest: dict) -> str:
        f = tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False)
        json.dump(manifest, f)
        f.close()
        return f.name

    def test_cli_valid_exit_zero(self) -> None:
        path = self._write_manifest(make_valid_manifest())
        result = subprocess.run(
            [sys.executable, "-m", "benchmarks.validate_manifest", path],
            capture_output=True,
            text=True,
        )
        Path(path).unlink(missing_ok=True)
        self.assertEqual(result.returncode, 0)

    def test_cli_invalid_exit_one(self) -> None:
        manifest = make_valid_manifest()
        manifest["protocol_version"] = "wrong"
        path = self._write_manifest(manifest)
        result = subprocess.run(
            [sys.executable, "-m", "benchmarks.validate_manifest", path],
            capture_output=True,
            text=True,
        )
        Path(path).unlink(missing_ok=True)
        self.assertEqual(result.returncode, 1)

    def test_cli_missing_file_exit_two(self) -> None:
        result = subprocess.run(
            [sys.executable, "-m", "benchmarks.validate_manifest", "/nonexistent/file.json"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
