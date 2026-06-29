"""Build a text-only JSONL dataset for the data-driven simulation assistant."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from simulation_assistant_lib import build_record, iter_text_files, read_text_lossy, write_jsonl


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".", help="Repository root to scan.")
    parser.add_argument(
        "--output",
        default="build/ml/simulation_experience_dataset.jsonl",
        help="Output JSONL path. Defaults under build/ml/ so large datasets stay untracked.",
    )
    parser.add_argument("--include", action="append", default=[], help="Optional repo-relative glob to include.")
    parser.add_argument("--exclude", action="append", default=[], help="Optional repo-relative glob to exclude.")
    parser.add_argument("--max-files", type=int, default=0, help="Optional cap for smoke runs.")
    parser.add_argument(
        "--labeled-only",
        action="store_true",
        help="Only write records with at least one candidate label.",
    )
    return parser.parse_args()


def build_dataset(
    repo_root: Path,
    output: Path,
    include: list[str] | None = None,
    exclude: list[str] | None = None,
    max_files: int = 0,
    labeled_only: bool = False,
) -> dict[str, int | str]:
    repo_root = repo_root.resolve()
    output = output if output.is_absolute() else repo_root / output
    records = []
    scanned = 0
    for path in iter_text_files(repo_root, include, exclude):
        scanned += 1
        text = read_text_lossy(path)
        rel = path.resolve().relative_to(repo_root).as_posix()
        record = build_record(rel, text)
        if labeled_only and not record["labels"]:
            continue
        records.append(record)
        if max_files and scanned >= max_files:
            break
    count = write_jsonl(output, records)
    return {
        "repo_root": str(repo_root),
        "output": str(output),
        "scanned_files": scanned,
        "written_records": count,
    }


def main() -> int:
    args = parse_args()
    summary = build_dataset(
        repo_root=Path(args.repo_root),
        output=Path(args.output),
        include=args.include,
        exclude=args.exclude,
        max_files=args.max_files,
        labeled_only=args.labeled_only,
    )
    print(json.dumps(summary, indent=2, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
