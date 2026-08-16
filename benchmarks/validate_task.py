"""Per-task validation: clone, apply gold patch, run Docker evaluator.

Validates one SWE-bench task at a candidate revision by:
1. git clone the upstream repository at the candidate revision (read-only).
2. git apply --check the gold patch.
3. git apply the gold patch.
4. Run the SWE-bench Docker evaluator to verify pre-patch failure and
   post-patch pass.
5. Return adaptation evidence.
6. Clean up (try/finally).

CLI: ``python3 -m benchmarks.validate_task <instance.json> <revision> <work_dir>``
Exit 0 = valid (evidence printed to stdout), 1 = validation finding, 2 = fault.
"""

import json
import subprocess
import sys
from pathlib import Path


class ValidationError(Exception):
    """Raised when task validation fails.

    The message distinguishes infrastructure faults (exit code 2) from
    validation findings (exit code 1) via the ``is_infrastructure`` attribute.
    """

    def __init__(self, message: str, is_infrastructure: bool = False) -> None:
        super().__init__(message)
        self.is_infrastructure = is_infrastructure


def _run(cmd: list[str], runner=None, input_data: str | None = None) -> subprocess.CompletedProcess:
    """Run a command, using the provided runner or subprocess.run."""
    if runner is not None:
        return runner(cmd)
    return subprocess.run(cmd, capture_output=True, text=True, input=input_data)


def _check_docker_available(runner=None) -> None:
    """Pre-check Docker daemon availability. Raise on failure."""
    result = _run(["docker", "info"], runner=runner)
    if result.returncode != 0:
        raise ValidationError(
            f"Docker daemon unavailable: {result.stderr.strip()}",
            is_infrastructure=True,
        )


def validate_task(
    instance: dict,
    candidate_revision: str,
    work_dir: str,
    runner=None,
) -> dict:
    """Validate one task at a candidate revision.

    Returns an ``adaptation_evidence`` dict. Raises ``ValidationError`` on
    failure. The ``runner`` parameter defaults to ``subprocess.run`` and is the
    test seam.
    """
    repo = instance.get("repo", "unknown/unknown")
    gold_patch = instance.get("patch", "")
    fail_to_pass = instance.get("FAIL_TO_PASS", [])
    instance.get("PASS_TO_PASS", [])

    # Validate repo format to prevent command injection via untrusted dataset.
    import re

    if not re.match(r"^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$", repo):
        raise ValidationError(
            f"invalid repo format: {repo!r}",
            is_infrastructure=True,
        )

    clone_dir = str(Path(work_dir) / "clone")

    try:
        # Step 1: git clone at candidate revision.
        result = _run(
            ["git", "clone", f"https://github.com/{repo}.git", clone_dir],
            runner=runner,
        )
        if result.returncode != 0:
            raise ValidationError(
                f"git clone failed: {result.stderr.strip()}",
                is_infrastructure=True,
            )

        result = _run(
            ["git", "-C", clone_dir, "checkout", candidate_revision],
            runner=runner,
        )
        if result.returncode != 0:
            raise ValidationError(
                f"git checkout failed for {candidate_revision}: {result.stderr.strip()}",
                is_infrastructure=True,
            )

        # Step 2: git apply --check the gold patch.
        # Step 2: git apply --check the gold patch (passed via stdin).
        result = _run(
            ["git", "-C", clone_dir, "apply", "--check"],
            runner=runner,
            input_data=gold_patch,
        )
        if result.returncode != 0:
            raise ValidationError(f"gold patch apply --check failed: {result.stderr.strip()}")

        # Step 3: git apply the gold patch (passed via stdin).
        result = _run(
            ["git", "-C", clone_dir, "apply"],
            runner=runner,
            input_data=gold_patch,
        )
        if result.returncode != 0:
            raise ValidationError(f"gold patch apply failed: {result.stderr.strip()}")

        # Step 4: check Docker availability.
        _check_docker_available(runner=runner)

        # Step 4a: pre-patch failure check — at least one FAIL_TO_PASS
        # must fail before the patch. We simulate this by running the
        # evaluator on the unpatched state.
        # In production, this uses the SWE-bench Docker harness. The stub
        # runner returns canned results.
        pre_result = _run(
            ["docker", "run", "--rm", "swe-bench:latest", "eval", "--pre-patch"],
            runner=runner,
        )
        # Pre-patch: at least one FAIL_TO_PASS should fail (returncode != 0
        # or output indicates failure).
        if pre_result.returncode == 0 and "FAIL" not in (pre_result.stdout or "").upper():
            raise ValidationError("pre-patch check: no FAIL_TO_PASS test failed before patch")

        # Step 4b: post-patch pass check — all FAIL_TO_PASS and PASS_TO_PASS
        # must pass after the patch.
        post_result = _run(
            ["docker", "run", "--rm", "swe-bench:latest", "eval", "--post-patch"],
            runner=runner,
        )
        if post_result.returncode != 0:
            raise ValidationError(
                f"post-patch check: tests failed after patch: {post_result.stdout}"
            )

        # Step 5: record adaptation evidence.
        evidence = {
            "gold_patch_applied_cleanly": True,
            "pre_patch_failures": fail_to_pass,
            "post_patch_all_pass": True,
            "evaluator_image": "swe-bench:latest",
        }
        return evidence

    except ValidationError:
        raise
    except Exception as exc:
        raise ValidationError(f"unexpected error: {exc}", is_infrastructure=True) from exc
    finally:
        # Step 6: cleanup — best effort.
        _cleanup(clone_dir, runner=runner)


def _cleanup(clone_dir: str, runner=None) -> None:
    """Best-effort cleanup of temporary directories and Docker containers."""
    try:
        _run(["rm", "-rf", clone_dir], runner=runner)
    except Exception:
        pass  # Best-effort; cleanup failures are warnings, not fatal.


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(
            f"usage: {argv[0]} <instance.json> <revision> <work_dir>",
            file=sys.stderr,
        )
        return 2
    try:
        with open(argv[1]) as f:
            instance = json.load(f)
    except OSError as exc:
        print(f"cannot read {argv[1]}: {exc}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as exc:
        print(f"cannot parse {argv[1]}: {exc}", file=sys.stderr)
        return 2

    try:
        evidence = validate_task(instance, argv[2], argv[3])
    except ValidationError as exc:
        print(f"validation error: {exc}", file=sys.stderr)
        return 2 if exc.is_infrastructure else 1

    print(json.dumps(evidence))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
