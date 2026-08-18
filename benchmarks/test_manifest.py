"""Tests for the manifest schema constants and digest computation."""

import json
import unittest

from benchmarks.manifest import (
    DATASET_NAME,
    DATASET_REVISION,
    DATASET_SPLIT,
    EVALUATOR_NAME,
    EVALUATOR_REVISION,
    PROTOCOL_VERSION,
    SCHEMA_VERSION,
    SUPPORTED_LICENSES,
    canonical_json_bytes,
    compute_manifest_digest,
)


class TestCanonicalJson(unittest.TestCase):
    def test_sorts_keys(self) -> None:
        data = {"b": 1, "a": 2, "c": 3}
        result = canonical_json_bytes(data)
        decoded = json.loads(result)
        keys = list(decoded.keys())
        self.assertEqual(keys, ["a", "b", "c"])

    def test_no_whitespace(self) -> None:
        data = {"a": 1}
        result = canonical_json_bytes(data)
        self.assertEqual(result, b'{"a":1}')

    def test_utf8_encoding(self) -> None:
        data = {"name": "café"}
        result = canonical_json_bytes(data)
        self.assertIsInstance(result, bytes)


class TestManifestDigest(unittest.TestCase):
    def _make_manifest(self) -> dict:
        return {
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
            "groups": [],
            "selection": {
                "candidate_ledger": "ledger-test.json",
                "manifest_digest": "placeholder",
            },
        }

    def test_digest_is_deterministic(self) -> None:
        manifest = self._make_manifest()
        digest1 = compute_manifest_digest(manifest)
        digest2 = compute_manifest_digest(manifest)
        self.assertEqual(digest1, digest2)

    def test_digest_is_sha256_hex(self) -> None:
        manifest = self._make_manifest()
        digest = compute_manifest_digest(manifest)
        self.assertEqual(len(digest), 64)
        self.assertTrue(all(c in "0123456789abcdef" for c in digest))

    def test_digest_ignores_digest_field(self) -> None:
        manifest_a = self._make_manifest()
        manifest_a["selection"]["manifest_digest"] = "aaa"
        manifest_b = self._make_manifest()
        manifest_b["selection"]["manifest_digest"] = "bbb"
        self.assertEqual(
            compute_manifest_digest(manifest_a),
            compute_manifest_digest(manifest_b),
        )

    def test_digest_changes_when_data_changes(self) -> None:
        manifest = self._make_manifest()
        digest_a = compute_manifest_digest(manifest)
        manifest["groups"] = [{"group_id": "X"}]
        digest_b = compute_manifest_digest(manifest)
        self.assertNotEqual(digest_a, digest_b)


class TestConstants(unittest.TestCase):
    def test_protocol_version(self) -> None:
        self.assertEqual(PROTOCOL_VERSION, "adept-workflow-v1")

    def test_schema_version(self) -> None:
        self.assertEqual(SCHEMA_VERSION, "1.0.0")

    def test_dataset_revision_is_40_hex(self) -> None:
        self.assertEqual(len(DATASET_REVISION), 40)
        self.assertTrue(all(c in "0123456789abcdef" for c in DATASET_REVISION))

    def test_evaluator_revision_is_40_hex(self) -> None:
        self.assertEqual(len(EVALUATOR_REVISION), 40)
        self.assertTrue(all(c in "0123456789abcdef" for c in EVALUATOR_REVISION))

    def test_supported_licenses_contains_protocol_set(self) -> None:
        expected = {
            "MIT",
            "BSD-2-Clause",
            "BSD-3-Clause",
            "Apache-2.0",
            "ISC",
            "Python-2.0",
            "PSF-2.0",
        }
        self.assertEqual(SUPPORTED_LICENSES, expected)


if __name__ == "__main__":
    unittest.main()
