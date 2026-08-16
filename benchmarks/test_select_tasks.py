"""Tests for the deterministic selection algorithm."""

import json
import tempfile
import unittest
from pathlib import Path

from benchmarks.select_tasks import (
    SelectionError,
    select_tasks,
)


def make_instance(
    instance_id: str,
    repo: str,
    base_commit: str,
    license: str = "MIT",
    issue_url: str | None = None,
    fail_to_pass: list[str] | None = None,
    pass_to_pass: list[str] | None = None,
) -> dict:
    """Build a canonical JSONL instance for test fixtures."""
    return {
        "instance_id": instance_id,
        "repo": repo,
        "base_commit": base_commit,
        "patch": "diff --git a/file.py b/file.py\n",
        "test_patch": "diff --git a/test.py b/test.py\n",
        "FAIL_TO_PASS": fail_to_pass or ["test.module::test_a"],
        "PASS_TO_PASS": pass_to_pass or [],
        "problem_statement": "A test issue body.",
        "issue_url": issue_url or f"https://github.com/{repo}/issues/{instance_id.split('-')[-1]}",
        "license": license,
    }


def write_jsonl(instances: list[dict], path: str) -> None:
    with open(path, "w") as f:
        for inst in instances:
            f.write(json.dumps(inst) + "\n")


class TestFiltering(unittest.TestCase):
    def _make_validate_fn(self, valid_pairs: set[tuple[str, str]]):
        """Return a stub validate_fn that succeeds for known pairs."""

        def validate_fn(instance: dict, revision: str) -> dict:
            key = (instance["instance_id"], revision)
            if key in valid_pairs:
                return {
                    "gold_patch_applied_cleanly": True,
                    "pre_patch_failures": instance["FAIL_TO_PASS"],
                    "post_patch_all_pass": True,
                    "evaluator_image": "swe-bench:latest",
                }
            raise SelectionError(f"validation failed for {key}")

        return validate_fn

    def test_filter_excludes_bad_license(self) -> None:
        instances = [
            make_instance("aaa__repo-001", "aaa/repo", "a" * 40, license="GPL-3.0"),
            make_instance("bbb__repo-002", "bbb/repo", "b" * 40, license="MIT"),
            make_instance("bbb__repo-003", "bbb/repo", "b" * 40, license="MIT"),
            make_instance("bbb__repo-004", "bbb/repo", "b" * 40, license="MIT"),
            make_instance("ccc__repo-001", "ccc/repo", "c" * 40, license="MIT"),
            make_instance("ccc__repo-002", "ccc/repo", "c" * 40, license="MIT"),
            make_instance("ccc__repo-003", "ccc/repo", "c" * 40, license="MIT"),
        ]
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            validate_fn = self._make_validate_fn(
                {
                    ("bbb__repo-002", "b" * 40),
                    ("bbb__repo-003", "b" * 40),
                    ("bbb__repo-004", "b" * 40),
                    ("ccc__repo-001", "c" * 40),
                    ("ccc__repo-002", "c" * 40),
                    ("ccc__repo-003", "c" * 40),
                }
            )
            manifest, ledger = select_tasks(jsonl_path, validate_fn=validate_fn)
        excluded = [i for i in ledger["instances"] if i["status"] == "excluded"]
        self.assertTrue(any(i["instance_id"] == "aaa__repo-001" for i in excluded))
        self.assertTrue(any(i.get("exclusion_rule") == "license-not-supported" for i in excluded))

    def test_filter_excludes_missing_license(self) -> None:
        inst = make_instance("aaa__repo-001", "aaa/repo", "a" * 40)
        del inst["license"]
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl([inst], jsonl_path)
            with self.assertRaises(SelectionError):
                select_tasks(jsonl_path, validate_fn=self._make_validate_fn(set()))
        # Verify the ledger would record license-missing by checking eligibility
        from benchmarks.select_tasks import _check_eligibility

        eligible, rule = _check_eligibility(inst)
        self.assertFalse(eligible)
        self.assertEqual(rule, "license-missing")


class TestCombinationOrdering(unittest.TestCase):
    def _make_validate_fn(self, valid_pairs: set[tuple[str, str]]):
        def validate_fn(instance: dict, revision: str) -> dict:
            key = (instance["instance_id"], revision)
            if key in valid_pairs:
                return {
                    "gold_patch_applied_cleanly": True,
                    "pre_patch_failures": instance["FAIL_TO_PASS"],
                    "post_patch_all_pass": True,
                    "evaluator_image": "swe-bench:latest",
                }
            raise SelectionError(f"validation failed for {key}")

        return validate_fn

    def test_combinations_sorted_by_tuple(self) -> None:
        """Combinations should be sorted by (first, second, third) ID."""
        instances = [
            make_instance("ddd__repo-001", "ddd/repo", "d" * 40),
            make_instance("ddd__repo-002", "ddd/repo", "d" * 40),
            make_instance("ddd__repo-003", "ddd/repo", "d" * 40),
            make_instance("ddd__repo-004", "ddd/repo", "d" * 40),
            make_instance("eee__repo-001", "eee/repo", "e" * 40),
            make_instance("eee__repo-002", "eee/repo", "e" * 40),
            make_instance("eee__repo-003", "eee/repo", "e" * 40),
        ]
        valid_pairs = {
            ("ddd__repo-001", "d" * 40),
            ("ddd__repo-002", "d" * 40),
            ("ddd__repo-003", "d" * 40),
            ("eee__repo-001", "e" * 40),
            ("eee__repo-002", "e" * 40),
            ("eee__repo-003", "e" * 40),
        }
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            manifest, ledger = select_tasks(
                jsonl_path, validate_fn=self._make_validate_fn(valid_pairs)
            )
        combos = [c["instance_ids"] for c in ledger["combinations"]]
        # First combo should be the lexically smallest triplet
        self.assertEqual(combos[0], ["ddd__repo-001", "ddd__repo-002", "ddd__repo-003"])

    def test_ids_sorted_within_combination(self) -> None:
        instances = [
            make_instance("ddd__repo-003", "ddd/repo", "d" * 40),
            make_instance("ddd__repo-001", "ddd/repo", "d" * 40),
            make_instance("ddd__repo-002", "ddd/repo", "d" * 40),
            make_instance("ddd__repo-004", "ddd/repo", "d" * 40),
            make_instance("eee__repo-001", "eee/repo", "e" * 40),
            make_instance("eee__repo-002", "eee/repo", "e" * 40),
            make_instance("eee__repo-003", "eee/repo", "e" * 40),
        ]
        valid_pairs = {
            ("ddd__repo-001", "d" * 40),
            ("ddd__repo-002", "d" * 40),
            ("ddd__repo-003", "d" * 40),
            ("eee__repo-001", "e" * 40),
            ("eee__repo-002", "e" * 40),
            ("eee__repo-003", "e" * 40),
        }
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            manifest, ledger = select_tasks(
                jsonl_path, validate_fn=self._make_validate_fn(valid_pairs)
            )
        first_combo = ledger["combinations"][0]["instance_ids"]
        self.assertEqual(first_combo, sorted(first_combo))

    def test_candidate_revisions_lexical_order(self) -> None:
        """When a combination has multiple distinct base commits, test in lexical order."""
        instances = [
            make_instance("ddd__repo-001", "ddd/repo", "f" * 40),
            make_instance("ddd__repo-002", "ddd/repo", "a" * 40),
            make_instance("ddd__repo-003", "ddd/repo", "a" * 40),
        ]
        # Only "a"*40 has 2 of 3 tasks valid — insufficient for a group
        valid_pairs = {
            ("ddd__repo-002", "a" * 40),
            ("ddd__repo-003", "a" * 40),
        }
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            with self.assertRaises(SelectionError):
                select_tasks(jsonl_path, validate_fn=self._make_validate_fn(valid_pairs))

    def test_first_qualifying_revision_selected(self) -> None:
        instances = [
            make_instance("ddd__repo-001", "ddd/repo", "a" * 40),
            make_instance("ddd__repo-002", "ddd/repo", "a" * 40),
            make_instance("ddd__repo-003", "ddd/repo", "a" * 40),
            make_instance("eee__repo-001", "eee/repo", "e" * 40),
            make_instance("eee__repo-002", "eee/repo", "e" * 40),
            make_instance("eee__repo-003", "eee/repo", "e" * 40),
        ]
        valid_pairs = {
            ("ddd__repo-001", "a" * 40),
            ("ddd__repo-002", "a" * 40),
            ("ddd__repo-003", "a" * 40),
            ("eee__repo-001", "e" * 40),
            ("eee__repo-002", "e" * 40),
            ("eee__repo-003", "e" * 40),
        }
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            manifest, ledger = select_tasks(
                jsonl_path, validate_fn=self._make_validate_fn(valid_pairs)
            )
        self.assertEqual(len(manifest["groups"]), 2)
        repos = {g["repository"] for g in manifest["groups"]}
        self.assertEqual(repos, {"ddd/repo", "eee/repo"})

    def test_first_two_disjoint_repos_selected(self) -> None:
        instances = [
            make_instance("aaa__repo-001", "aaa/repo", "a" * 40),
            make_instance("aaa__repo-002", "aaa/repo", "a" * 40),
            make_instance("aaa__repo-003", "aaa/repo", "a" * 40),
            make_instance("bbb__repo-001", "bbb/repo", "b" * 40),
            make_instance("bbb__repo-002", "bbb/repo", "b" * 40),
            make_instance("bbb__repo-003", "bbb/repo", "b" * 40),
            make_instance("ccc__repo-001", "ccc/repo", "c" * 40),
            make_instance("ccc__repo-002", "ccc/repo", "c" * 40),
            make_instance("ccc__repo-003", "ccc/repo", "c" * 40),
        ]
        valid_pairs = {(inst["instance_id"], inst["base_commit"]) for inst in instances}
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            manifest, ledger = select_tasks(
                jsonl_path, validate_fn=self._make_validate_fn(valid_pairs)
            )
        self.assertEqual(len(manifest["groups"]), 2)
        repos = {g["repository"] for g in manifest["groups"]}
        self.assertEqual(len(repos), 2)  # different repos
        # aaa and bbb should be selected (first two repos in lexical order)
        self.assertEqual(repos, {"aaa/repo", "bbb/repo"})

    def test_insufficient_groups_raises(self) -> None:
        instances = [
            make_instance("ddd__repo-001", "ddd/repo", "d" * 40),
            make_instance("ddd__repo-002", "ddd/repo", "d" * 40),
            make_instance("ddd__repo-003", "ddd/repo", "d" * 40),
        ]
        # All pass — only 1 group qualifies, need 2
        valid_pairs = {
            ("ddd__repo-001", "d" * 40),
            ("ddd__repo-002", "d" * 40),
            ("ddd__repo-003", "d" * 40),
        }
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            with self.assertRaises(SelectionError) as ctx:
                select_tasks(jsonl_path, validate_fn=self._make_validate_fn(valid_pairs))
            self.assertIn("fewer than 2", str(ctx.exception).lower())


class TestLedgerCompleteness(unittest.TestCase):
    def _make_validate_fn(self, valid_pairs: set[tuple[str, str]]):
        def validate_fn(instance: dict, revision: str) -> dict:
            key = (instance["instance_id"], revision)
            if key in valid_pairs:
                return {
                    "gold_patch_applied_cleanly": True,
                    "pre_patch_failures": instance["FAIL_TO_PASS"],
                    "post_patch_all_pass": True,
                    "evaluator_image": "swe-bench:latest",
                }
            raise SelectionError(f"validation failed for {key}")

        return validate_fn

    def test_ledger_records_exclusions(self) -> None:
        instances = [
            make_instance("aaa__repo-001", "aaa/repo", "a" * 40, license="GPL-3.0"),
            make_instance("bbb__repo-001", "bbb/repo", "b" * 40),
            make_instance("bbb__repo-002", "bbb/repo", "b" * 40),
            make_instance("bbb__repo-003", "bbb/repo", "b" * 40),
            make_instance("ccc__repo-001", "ccc/repo", "c" * 40),
            make_instance("ccc__repo-002", "ccc/repo", "c" * 40),
            make_instance("ccc__repo-003", "ccc/repo", "c" * 40),
        ]
        valid_pairs = {
            ("bbb__repo-001", "b" * 40),
            ("bbb__repo-002", "b" * 40),
            ("bbb__repo-003", "b" * 40),
            ("ccc__repo-001", "c" * 40),
            ("ccc__repo-002", "c" * 40),
            ("ccc__repo-003", "c" * 40),
        }
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            manifest, ledger = select_tasks(
                jsonl_path, validate_fn=self._make_validate_fn(valid_pairs)
            )
        excluded = [i for i in ledger["instances"] if i["status"] == "excluded"]
        self.assertTrue(any(i["instance_id"] == "aaa__repo-001" for i in excluded))

    def test_ledger_records_combinations(self) -> None:
        instances = [
            make_instance("aaa__repo-001", "aaa/repo", "a" * 40),
            make_instance("aaa__repo-002", "aaa/repo", "a" * 40),
            make_instance("aaa__repo-003", "aaa/repo", "a" * 40),
            make_instance("bbb__repo-001", "bbb/repo", "b" * 40),
            make_instance("bbb__repo-002", "bbb/repo", "b" * 40),
            make_instance("bbb__repo-003", "bbb/repo", "b" * 40),
        ]
        valid_pairs = {(inst["instance_id"], inst["base_commit"]) for inst in instances}
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            manifest, ledger = select_tasks(
                jsonl_path, validate_fn=self._make_validate_fn(valid_pairs)
            )
        self.assertGreater(len(ledger["combinations"]), 0)
        selected = [c for c in ledger["combinations"] if c["status"] == "selected"]
        self.assertEqual(len(selected), 2)


class TestManifestOutput(unittest.TestCase):
    def _make_validate_fn(self, valid_pairs: set[tuple[str, str]]):
        def validate_fn(instance: dict, revision: str) -> dict:
            key = (instance["instance_id"], revision)
            if key in valid_pairs:
                return {
                    "gold_patch_applied_cleanly": True,
                    "pre_patch_failures": instance["FAIL_TO_PASS"],
                    "post_patch_all_pass": True,
                    "evaluator_image": "swe-bench:latest",
                }
            raise SelectionError(f"validation failed for {key}")

        return validate_fn

    def test_manifest_has_correct_counts(self) -> None:
        instances = [
            make_instance("aaa__repo-001", "aaa/repo", "a" * 40),
            make_instance("aaa__repo-002", "aaa/repo", "a" * 40),
            make_instance("aaa__repo-003", "aaa/repo", "a" * 40),
            make_instance("bbb__repo-001", "bbb/repo", "b" * 40),
            make_instance("bbb__repo-002", "bbb/repo", "b" * 40),
            make_instance("bbb__repo-003", "bbb/repo", "b" * 40),
        ]
        valid_pairs = {(inst["instance_id"], inst["base_commit"]) for inst in instances}
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            manifest, ledger = select_tasks(
                jsonl_path, validate_fn=self._make_validate_fn(valid_pairs)
            )
        self.assertEqual(len(manifest["groups"]), 2)
        for group in manifest["groups"]:
            self.assertEqual(len(group["tasks"]), 3)

    def test_manifest_digest_matches(self) -> None:
        from benchmarks.manifest import compute_manifest_digest

        instances = [
            make_instance("aaa__repo-001", "aaa/repo", "a" * 40),
            make_instance("aaa__repo-002", "aaa/repo", "a" * 40),
            make_instance("aaa__repo-003", "aaa/repo", "a" * 40),
            make_instance("bbb__repo-001", "bbb/repo", "b" * 40),
            make_instance("bbb__repo-002", "bbb/repo", "b" * 40),
            make_instance("bbb__repo-003", "bbb/repo", "b" * 40),
        ]
        valid_pairs = {(inst["instance_id"], inst["base_commit"]) for inst in instances}
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            manifest, ledger = select_tasks(
                jsonl_path, validate_fn=self._make_validate_fn(valid_pairs)
            )
        self.assertEqual(
            manifest["selection"]["manifest_digest"],
            compute_manifest_digest(manifest),
        )

    def test_single_repo_multiple_combos_selects_first(self) -> None:
        """A repo with 4+ eligible instances should only select the first combo."""
        instances = [
            make_instance("ddd__repo-001", "ddd/repo", "d" * 40),
            make_instance("ddd__repo-002", "ddd/repo", "d" * 40),
            make_instance("ddd__repo-003", "ddd/repo", "d" * 40),
            make_instance("ddd__repo-004", "ddd/repo", "d" * 40),
            make_instance("eee__repo-001", "eee/repo", "e" * 40),
            make_instance("eee__repo-002", "eee/repo", "e" * 40),
            make_instance("eee__repo-003", "eee/repo", "e" * 40),
        ]
        valid_pairs = {(inst["instance_id"], inst["base_commit"]) for inst in instances}
        with tempfile.TemporaryDirectory() as d:
            jsonl_path = str(Path(d) / "dataset.jsonl")
            write_jsonl(instances, jsonl_path)
            manifest, ledger = select_tasks(
                jsonl_path, validate_fn=self._make_validate_fn(valid_pairs)
            )
        # ddd group should have the first 3 instances (001, 002, 003)
        ddd_group = next(g for g in manifest["groups"] if g["repository"] == "ddd/repo")
        ids = [t["instance_id"] for t in ddd_group["tasks"]]
        self.assertEqual(ids, ["ddd__repo-001", "ddd__repo-002", "ddd__repo-003"])


if __name__ == "__main__":
    unittest.main()
