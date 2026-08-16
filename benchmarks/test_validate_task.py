"""Tests for per-task validation (validate_task.py).

Tests stub git and docker commands via a command-runner parameter and verify
the orchestration logic, evidence recording, error handling, and cleanup.
"""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from benchmarks.validate_task import (
    ValidationError,
    validate_task,
)


def make_completed(
    returncode: int, stdout: str = "", stderr: str = ""
) -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess(args=[], returncode=returncode, stdout=stdout, stderr=stderr)


def _cmd_key(cmd: list[str]) -> str:
    """Return a key identifying which subprocess command this is."""


def _cmd_key(cmd: list[str]) -> str:
    """Return a key identifying which subprocess command this is."""
    if not cmd:
        return ""
    base = os.path.basename(cmd[0])
    if base == "git" and len(cmd) > 1:
        if cmd[1] == "-C" and len(cmd) > 3:
            sub = cmd[3]
            # Include flags to distinguish 'apply --check' from 'apply'
            if sub == "apply" and "--check" in cmd:
                return "git-apply--check"
            return f"git-{sub}"
        if cmd[1] == "clone":
            return "git-clone"
        return f"git-{cmd[1]}"
    if base == "docker":
        if len(cmd) > 1 and cmd[1] == "info":
            return "docker-info"
        return "docker"
    if base == "rm":
        return "rm"
    return base


class TestValidateTask(unittest.TestCase):
    def _make_instance(self) -> dict:
        return {
            "instance_id": "test__repo-001",
            "repo": "test/repo",
            "base_commit": "a" * 40,
            "patch": "diff --git a/file.py b/file.py\n",
            "test_patch": "diff --git a/test.py b/test.py\n",
            "FAIL_TO_PASS": ["test.module::test_a"],
            "PASS_TO_PASS": ["test.module::test_b"],
        }

    def _make_runner(self, results: dict[str, subprocess.CompletedProcess]):
        """Return a stub runner that maps command keys to canned results."""

        def runner(cmd: list[str]) -> subprocess.CompletedProcess:
            key = _cmd_key(cmd)
            if key in results:
                return results[key]
            return make_completed(0)

        return runner

    def _pre_fail_post_pass_runner(self):
        """A runner where pre-patch fails and post-patch passes."""
        call_count = [0]

        def runner(cmd: list[str]) -> subprocess.CompletedProcess:
            key = _cmd_key(cmd)
            if key in (
                "git-clone",
                "git-checkout",
                "git-apply",
                "git-apply--check",
                "docker-info",
                "rm",
            ):
                return make_completed(0)
            if key == "docker":
                call_count[0] += 1
                # First docker call = pre-patch (FAIL), second = post-patch (PASS)
                if call_count[0] == 1:
                    return make_completed(1, stdout="FAIL")
                return make_completed(0, stdout="PASS")
            return make_completed(0)

        return runner

    def test_gold_patch_apply_check_fails(self) -> None:
        instance = self._make_instance()
        runner = self._make_runner(
            {
                "git-clone": make_completed(0),
                "git-checkout": make_completed(0),
                "git-apply--check": make_completed(1, stderr="error: patch did not apply"),
            }
        )
        with tempfile.TemporaryDirectory() as work_dir:
            with self.assertRaises(ValidationError) as ctx:
                validate_task(instance, "a" * 40, work_dir, runner=runner)
            self.assertIn("apply", str(ctx.exception).lower())

    def test_gold_patch_apply_succeeds(self) -> None:
        instance = self._make_instance()
        with tempfile.TemporaryDirectory() as work_dir:
            evidence = validate_task(
                instance, "a" * 40, work_dir, runner=self._pre_fail_post_pass_runner()
            )
        self.assertTrue(evidence["gold_patch_applied_cleanly"])

    def test_pre_patch_failure_assertion(self) -> None:
        """If all FAIL_TO_PASS tests pass pre-patch, raise."""
        instance = self._make_instance()
        # Docker returns PASS for pre-patch — should raise
        runner = self._make_runner(
            {
                "git-clone": make_completed(0),
                "git-checkout": make_completed(0),
                "git-apply--check": make_completed(0),
                "git-apply": make_completed(0),
                "docker": make_completed(0, stdout="ALL_PASS"),
            }
        )
        with tempfile.TemporaryDirectory() as work_dir:
            with self.assertRaises(ValidationError) as ctx:
                validate_task(instance, "a" * 40, work_dir, runner=runner)
            self.assertIn("pre-patch", str(ctx.exception).lower())

    def test_post_patch_all_pass(self) -> None:
        """When pre-patch fails and post-patch passes, evidence records success."""
        instance = self._make_instance()
        with tempfile.TemporaryDirectory() as work_dir:
            evidence = validate_task(
                instance, "a" * 40, work_dir, runner=self._pre_fail_post_pass_runner()
            )
        self.assertTrue(evidence["post_patch_all_pass"])

    def test_post_patch_failure(self) -> None:
        """When post-patch tests fail, raise."""
        instance = self._make_instance()
        call_count = [0]

        def runner(cmd: list[str]) -> subprocess.CompletedProcess:
            key = _cmd_key(cmd)
            if key == "docker":
                call_count[0] += 1
                if call_count[0] == 1:
                    return make_completed(1, stdout="FAIL")
                return make_completed(1, stdout="FAIL")
            return make_completed(0)

        with tempfile.TemporaryDirectory() as work_dir:
            with self.assertRaises(ValidationError):
                validate_task(instance, "a" * 40, work_dir, runner=runner)

    def test_evidence_fields_complete(self) -> None:
        from benchmarks.manifest import REQUIRED_EVIDENCE_FIELDS

        instance = self._make_instance()
        with tempfile.TemporaryDirectory() as work_dir:
            evidence = validate_task(
                instance, "a" * 40, work_dir, runner=self._pre_fail_post_pass_runner()
            )
        for field in REQUIRED_EVIDENCE_FIELDS:
            self.assertIn(field, evidence)

    def test_docker_invocation_uses_subprocess_args(self) -> None:
        """The Docker command must be passed as a list of args, not a shell string."""
        instance = self._make_instance()
        captured_cmds: list[list[str]] = []

        original_runner = self._pre_fail_post_pass_runner()

        def capturing_runner(cmd: list[str]) -> subprocess.CompletedProcess:
            captured_cmds.append(cmd)
            return original_runner(cmd)

        with tempfile.TemporaryDirectory() as work_dir:
            validate_task(instance, "a" * 40, work_dir, runner=capturing_runner)
        docker_cmds = [c for c in captured_cmds if "docker" in str(c)]
        self.assertTrue(len(docker_cmds) > 0)
        for cmd in docker_cmds:
            self.assertIsInstance(cmd, list)

    def test_docker_unavailable_exits_fault(self) -> None:
        """Docker daemon unavailable should raise with infrastructure fault."""
        instance = self._make_instance()
        runner = self._make_runner(
            {
                "git-clone": make_completed(0),
                "git-checkout": make_completed(0),
                "git-apply--check": make_completed(0),
                "git-apply": make_completed(0),
                "docker-info": make_completed(1, stderr="Cannot connect to the Docker daemon"),
            }
        )
        with tempfile.TemporaryDirectory() as work_dir:
            with self.assertRaises(ValidationError) as ctx:
                validate_task(instance, "a" * 40, work_dir, runner=runner)
            self.assertTrue(ctx.exception.is_infrastructure)

    def test_cleanup_on_failure(self) -> None:
        """Temp dirs should be cleaned up even when validation fails."""
        instance = self._make_instance()
        runner = self._make_runner(
            {
                "git-clone": make_completed(0),
                "git-checkout": make_completed(0),
                "git-apply--check": make_completed(1, stderr="patch failed"),
            }
        )
        with tempfile.TemporaryDirectory() as work_dir:
            with self.assertRaises(ValidationError):
                validate_task(instance, "a" * 40, work_dir, runner=runner)
            self.assertTrue(Path(work_dir).exists())

    def test_infrastructure_fault_vs_finding_exit_codes(self) -> None:
        """Docker failure → infrastructure (exit 2), evaluator failure → finding (exit 1)."""
        instance = self._make_instance()
        # Evaluator failure (post-patch tests fail) = finding
        call_count = [0]

        def finding_runner(cmd: list[str]) -> subprocess.CompletedProcess:
            key = _cmd_key(cmd)
            if key == "docker-info":
                return make_completed(0)
            if key == "docker":
                call_count[0] += 1
                if call_count[0] == 1:
                    return make_completed(1, stdout="FAIL")
                return make_completed(1, stdout="FAIL")  # post-patch fails
            return make_completed(0)

        with tempfile.TemporaryDirectory() as work_dir:
            with self.assertRaises(ValidationError) as ctx:
                validate_task(instance, "a" * 40, work_dir, runner=finding_runner)
            self.assertFalse(ctx.exception.is_infrastructure)


if __name__ == "__main__":
    unittest.main()
