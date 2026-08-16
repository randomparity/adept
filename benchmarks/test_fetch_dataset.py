"""Tests for dataset fetch normalization (fetch_dataset.py).

Tests exercise the normalization function with fixture rows; the network
call is not tested in CI.
"""

import unittest

from benchmarks.fetch_dataset import normalize_row


class TestNormalizeRow(unittest.TestCase):
    def _make_raw_row(self, **overrides) -> dict:
        row = {
            "instance_id": "test__repo-001",
            "repo": "test/repo",
            "base_commit": "a" * 40,
            "patch": "diff --git a/file.py b/file.py\n",
            "test_patch": "diff --git a/test.py b/test.py\n",
            "FAIL_TO_PASS": '["test.module::test_a"]',
            "PASS_TO_PASS": '["test.module::test_b"]',
            "problem_statement": "A test issue body.",
            "issue_url": "https://github.com/test/repo/issues/1",
        }
        row.update(overrides)
        return row

    def test_normalize_row_maps_all_fields(self) -> None:
        row = self._make_raw_row()
        result = normalize_row(row)
        self.assertEqual(result["instance_id"], "test__repo-001")
        self.assertEqual(result["repo"], "test/repo")
        self.assertEqual(result["base_commit"], "a" * 40)
        self.assertEqual(result["patch"], "diff --git a/file.py b/file.py\n")
        self.assertEqual(result["test_patch"], "diff --git a/test.py b/test.py\n")
        self.assertEqual(result["problem_statement"], "A test issue body.")
        self.assertEqual(result["issue_url"], "https://github.com/test/repo/issues/1")

    def test_fail_to_pass_parsed_from_json_string(self) -> None:
        row = self._make_raw_row(FAIL_TO_PASS='["test.a", "test.b"]')
        result = normalize_row(row)
        self.assertEqual(result["FAIL_TO_PASS"], ["test.a", "test.b"])

    def test_pass_to_pass_parsed_from_json_string(self) -> None:
        row = self._make_raw_row(PASS_TO_PASS='["test.c"]')
        result = normalize_row(row)
        self.assertEqual(result["PASS_TO_PASS"], ["test.c"])

    def test_missing_issue_url_handled(self) -> None:
        row = self._make_raw_row()
        del row["issue_url"]
        result = normalize_row(row)
        self.assertIsNone(result["issue_url"])

    def test_empty_row_raises(self) -> None:
        with self.assertRaises(ValueError):
            normalize_row({})

    def test_malformed_fail_to_pass_json(self) -> None:
        row = self._make_raw_row(FAIL_TO_PASS="not valid json")
        result = normalize_row(row)
        # Malformed JSON should result in an empty list, not a crash
        self.assertEqual(result["FAIL_TO_PASS"], [])

    def test_pass_to_pass_already_list(self) -> None:
        """If PASS_TO_PASS is already a list, don't try to parse it."""
        row = self._make_raw_row(PASS_TO_PASS=["test.c"])
        result = normalize_row(row)
        self.assertEqual(result["PASS_TO_PASS"], ["test.c"])


if __name__ == "__main__":
    unittest.main()
