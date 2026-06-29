"""Suggest advisory simulation-diagnosis candidates from a text dataset."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from simulation_assistant_lib import load_fixture, load_jsonl, suggest_from_records


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", default="build/ml/simulation_experience_dataset.jsonl")
    parser.add_argument("--query-text", default="", help="Inline query text.")
    parser.add_argument("--query-path", default="", help="Path to a text report to use as query.")
    parser.add_argument("--fixture", default="", help="Fixture JSON with query_text and expected labels.")
    parser.add_argument("--query-id", default="query")
    parser.add_argument("--top-k", type=int, default=3)
    return parser.parse_args()


def load_query(args: argparse.Namespace) -> tuple[str, str, Path]:
    dataset_path = Path(args.dataset)
    query_id = args.query_id
    query_text = args.query_text
    if args.fixture:
        fixture_path = Path(args.fixture)
        fixture = load_fixture(fixture_path)
        query_id = fixture.get("query_id", fixture_path.stem)
        query_text = fixture.get("query_text", "")
        dataset_name = fixture.get("dataset", "")
        if dataset_name:
            dataset_path = fixture_path.parent / dataset_name
    elif args.query_path:
        query_path = Path(args.query_path)
        query_text = query_path.read_text(encoding="utf-8", errors="replace")
        query_id = args.query_id if args.query_id != "query" else query_path.stem
    if not query_text.strip():
        raise ValueError("Provide --query-text, --query-path, or --fixture with query_text.")
    return query_id, query_text, dataset_path


def main() -> int:
    args = parse_args()
    query_id, query_text, dataset_path = load_query(args)
    records = load_jsonl(dataset_path)
    result = suggest_from_records(query_text, records, query_id=query_id, top_k=args.top_k)
    print(json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
