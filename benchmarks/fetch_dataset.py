"""Fetch the SWE-bench_Verified dataset from Hugging Face and emit canonical JSONL.

This script lazy-imports ``huggingface_hub`` and ``pyarrow`` — they are not
imported at module level and not needed by tests or other modules.

The ``normalize_row`` function is the pure, testable core: it maps a raw
SWE-bench_Verified dataset row to canonical instance fields. Tests exercise it
with fixture rows; the network call is not tested in CI.

CLI: ``python3 -m benchmarks.fetch_dataset <output.jsonl>``
"""

import json
import sys


def normalize_row(row: dict) -> dict:
    """Map a raw SWE-bench_Verified dataset row to canonical instance fields.

    SWE-bench stores ``FAIL_TO_PASS`` and ``PASS_TO_PASS`` as JSON strings;
    this function parses them to lists. Missing ``issue_url`` is set to ``None``.
    Malformed JSON is handled gracefully (empty list, not a crash).
    """
    if not row:
        raise ValueError("empty row: cannot normalize")

    def _parse_json_list(value):
        if isinstance(value, list):
            return value
        if isinstance(value, str):
            try:
                parsed = json.loads(value)
                if isinstance(parsed, list):
                    return parsed
            except json.JSONDecodeError:
                return []
        return []

    return {
        "instance_id": row.get("instance_id", ""),
        "repo": row.get("repo", ""),
        "base_commit": row.get("base_commit", ""),
        "patch": row.get("patch", ""),
        "test_patch": row.get("test_patch", ""),
        "FAIL_TO_PASS": _parse_json_list(row.get("FAIL_TO_PASS")),
        "PASS_TO_PASS": _parse_json_list(row.get("PASS_TO_PASS")),
        "problem_statement": row.get("problem_statement", ""),
        "issue_url": row.get("issue_url"),
    }


def fetch_dataset(output_path: str) -> None:
    """Download the SWE-bench_Verified test split and write canonical JSONL.

    Lazy-imports huggingface_hub and pyarrow. Network failures are fatal.
    """
    import pyarrow.parquet as pq  # noqa: F401

    # huggingface_hub provides built-in retry for transient HTTP errors.
    from huggingface_hub import hf_hub_download  # noqa: F401

    from benchmarks.manifest import DATASET_NAME, DATASET_REVISION, DATASET_SPLIT

    # Download the parquet file for the test split at the pinned revision.
    parquet_path = hf_hub_download(
        repo_id=DATASET_NAME,
        filename=f"{DATASET_SPLIT}/0000.parquet",
        revision=DATASET_REVISION,
        repo_type="dataset",
    )

    table = pq.read_table(parquet_path)
    rows = table.to_pylist()

    with open(output_path, "w") as f:
        for row in rows:
            normalized = normalize_row(row)
            f.write(json.dumps(normalized) + "\n")

    print(f"wrote {len(rows)} instances to {output_path}")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} <output.jsonl>", file=sys.stderr)
        return 2
    try:
        fetch_dataset(argv[1])
    except Exception as exc:
        print(f"fetch error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
