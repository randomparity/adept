"""Tests for issue materialization (materialize_issues.py)."""

import subprocess
import unittest
from tempfile import TemporaryDirectory

from benchmarks.materialize_issues import (
    EXACT_LABELS,
    materialize_issues,
)


def make_completed(
    returncode: int, stdout: str = "", stderr: str = ""
) -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess(args=[], returncode=returncode, stdout=stdout, stderr=stderr)


def make_manifest() -> dict:
    return {
        "protocol_version": "adept-workflow-v1",
        "groups": [
            {
                "group_id": "A",
                "repository": "aaa/repo",
                "common_revision": "a" * 40,
                "tasks": [
                    {
                        "instance_id": "aaa__repo-001",
                        "issue_url": "https://github.com/aaa/repo/issues/1",
                        "license": "MIT",
                        "materialized_issue_number": None,
                        "test_patch": "diff",
                        "fail_to_pass": ["test_a"],
                        "pass_to_pass": [],
                        "adaptation_evidence": {},
                        "original_base_commit": "a" * 40,
                    },
                    {
                        "instance_id": "aaa__repo-002",
                        "issue_url": "https://github.com/aaa/repo/issues/2",
                        "license": "MIT",
                        "materialized_issue_number": None,
                        "test_patch": "diff",
                        "fail_to_pass": ["test_b"],
                        "pass_to_pass": [],
                        "adaptation_evidence": {},
                        "original_base_commit": "a" * 40,
                    },
                    {
                        "instance_id": "aaa__repo-003",
                        "issue_url": "https://github.com/aaa/repo/issues/3",
                        "license": "MIT",
                        "materialized_issue_number": None,
                        "test_patch": "diff",
                        "fail_to_pass": ["test_c"],
                        "pass_to_pass": [],
                        "adaptation_evidence": {},
                        "original_base_commit": "a" * 40,
                    },
                ],
            },
            {
                "group_id": "B",
                "repository": "bbb/repo",
                "common_revision": "b" * 40,
                "tasks": [
                    {
                        "instance_id": "bbb__repo-001",
                        "issue_url": "https://github.com/bbb/repo/issues/1",
                        "license": "BSD-3-Clause",
                        "materialized_issue_number": None,
                        "test_patch": "diff",
                        "fail_to_pass": ["test_d"],
                        "pass_to_pass": [],
                        "adaptation_evidence": {},
                        "original_base_commit": "b" * 40,
                    },
                    {
                        "instance_id": "bbb__repo-002",
                        "issue_url": "https://github.com/bbb/repo/issues/2",
                        "license": "BSD-3-Clause",
                        "materialized_issue_number": None,
                        "test_patch": "diff",
                        "fail_to_pass": ["test_e"],
                        "pass_to_pass": [],
                        "adaptation_evidence": {},
                        "original_base_commit": "b" * 40,
                    },
                    {
                        "instance_id": "bbb__repo-003",
                        "issue_url": "https://github.com/bbb/repo/issues/3",
                        "license": "BSD-3-Clause",
                        "materialized_issue_number": None,
                        "test_patch": "diff",
                        "fail_to_pass": ["test_f"],
                        "pass_to_pass": [],
                        "adaptation_evidence": {},
                        "original_base_commit": "b" * 40,
                    },
                ],
            },
        ],
        "selection": {"candidate_ledger": "", "manifest_digest": ""},
    }


class TestMaterialization(unittest.TestCase):
    def _make_capturing_runner(self, issue_number: int = 1):
        """Return a runner that captures commands and returns incrementing issue numbers."""
        counter = [issue_number]
        captured: list[list[str]] = []

        def runner(cmd: list[str]) -> subprocess.CompletedProcess:
            captured.append(cmd)
            # gh issue create returns the issue number
            if "issue" in str(cmd) and "create" in str(cmd):
                num = counter[0]
                counter[0] += 1
                return make_completed(0, stdout=str(num))
            return make_completed(0)

        runner.captured = captured
        return runner

    def test_dry_run_prints_gh_commands(self) -> None:
        manifest = make_manifest()
        runner = self._make_capturing_runner()
        with TemporaryDirectory():
            materialize_issues(manifest, "test/repo", dry_run=True, runner=runner)
        # In dry-run, no runner calls should be made
        self.assertEqual(len(runner.captured), 0)

    def test_issue_order_matches_lexical_instance_id(self) -> None:
        manifest = make_manifest()
        runner = self._make_capturing_runner()
        with TemporaryDirectory():
            result = materialize_issues(manifest, "test/repo", dry_run=False, runner=runner)
        group_a = result["groups"][0]
        numbers = [t["materialized_issue_number"] for t in group_a["tasks"]]
        self.assertEqual(numbers, [1, 2, 3])

    def test_exact_label_set(self) -> None:
        manifest = make_manifest()
        runner = self._make_capturing_runner()
        with TemporaryDirectory():
            materialize_issues(manifest, "test/repo", dry_run=False, runner=runner)
        # Check that gh issue create commands include the exact labels
        create_cmds = [c for c in runner.captured if "create" in c]
        self.assertTrue(len(create_cmds) > 0)
        for cmd in create_cmds:
            [
                a
                for a in cmd
                if a.startswith("type:bug")
                or a.startswith("priority:")
                or a.startswith("status:")
                or a.startswith("risk:")
                or a.startswith("effort:")
            ]
            # Labels are passed as --label args, check at least some are present
        # Verify all 5 labels appear across the commands
        all_labels = set()
        for cmd in create_cmds:
            for i, arg in enumerate(cmd):
                if arg == "--label" and i + 1 < len(cmd):
                    all_labels.add(cmd[i + 1])
        self.assertEqual(all_labels, set(EXACT_LABELS))

    def test_manifest_updated_with_issue_numbers(self) -> None:
        manifest = make_manifest()
        runner = self._make_capturing_runner()
        with TemporaryDirectory():
            result = materialize_issues(manifest, "test/repo", dry_run=False, runner=runner)
        for group in result["groups"]:
            for task in group["tasks"]:
                self.assertIsNotNone(task["materialized_issue_number"])

    def test_gh_invocation_uses_args_not_shell(self) -> None:
        manifest = make_manifest()
        runner = self._make_capturing_runner()
        with TemporaryDirectory():
            materialize_issues(manifest, "test/repo", dry_run=False, runner=runner)
        for cmd in runner.captured:
            self.assertIsInstance(cmd, list)

    def test_two_groups_create_six_issues(self) -> None:
        manifest = make_manifest()
        runner = self._make_capturing_runner()
        with TemporaryDirectory():
            materialize_issues(manifest, "test/repo", dry_run=False, runner=runner)
        create_cmds = [c for c in runner.captured if "create" in c]
        self.assertEqual(len(create_cmds), 6)

    def test_partial_failure_exits_fault(self) -> None:
        manifest = make_manifest()
        call_count = [0]

        def failing_runner(cmd: list[str]) -> subprocess.CompletedProcess:
            if "create" in cmd:
                call_count[0] += 1
                if call_count[0] == 2:
                    return make_completed(1, stderr="API error")
            return make_completed(0, stdout="1")

        with TemporaryDirectory():
            with self.assertRaises(Exception) as ctx:
                materialize_issues(manifest, "test/repo", dry_run=False, runner=failing_runner)
        self.assertTrue(ctx.exception.is_fault)

    def test_topology_digest_computed(self) -> None:
        manifest = make_manifest()
        runner = self._make_capturing_runner()
        with TemporaryDirectory():
            result = materialize_issues(manifest, "test/repo", dry_run=False, runner=runner)
        # Topology digest should be present in the result
        self.assertIn("topology_digest", result.get("selection", {}))


if __name__ == "__main__":
    unittest.main()
