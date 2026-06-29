"""Evaluate data-driven simulation assistant fixtures offline."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from simulation_assistant_lib import load_fixture, load_jsonl, suggest_from_records


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", required=True, help="Directory of fixture JSON files.")
    parser.add_argument(
        "--output-dir",
        default="build/reports/ml",
        help="Directory for assistant_eval_summary.md/json.",
    )
    parser.add_argument("--top-k", type=int, default=3)
    return parser.parse_args()


def fixture_files(fixtures_dir: Path) -> list[Path]:
    return sorted(path for path in fixtures_dir.glob("*.json") if path.name != "dataset.json")


def gate_text(result: dict[str, Any]) -> str:
    gates = list(result.get("required_gates", []))
    for candidate in result.get("candidates", []):
        gates.extend(candidate.get("required_gates", []))
    return "\n".join(gates)


def evaluate(fixtures_dir: Path, output_dir: Path, top_k: int = 3) -> dict[str, Any]:
    fixtures_dir = fixtures_dir.resolve()
    output_dir = output_dir.resolve()
    case_results: list[dict[str, Any]] = []
    for fixture_path in fixture_files(fixtures_dir):
        fixture = load_fixture(fixture_path)
        dataset_path = fixtures_dir / fixture.get("dataset", "dataset.jsonl")
        records = load_jsonl(dataset_path)
        result = suggest_from_records(
            fixture["query_text"],
            records,
            query_id=fixture.get("query_id", fixture_path.stem),
            top_k=top_k,
        )
        candidate_labels = [item["label"] for item in result.get("candidates", [])]
        expected_labels = fixture.get("expected_labels", [])
        forbidden_labels = set(fixture.get("forbidden_labels", []))
        forbidden_actions = fixture.get("forbidden_actions", [])
        required_gate_substrings = fixture.get("required_gate_substrings", [])

        top1_hit = bool(candidate_labels[:1] and candidate_labels[0] in expected_labels)
        top3_hit = any(label in candidate_labels[:3] for label in expected_labels)
        forbidden_label_hits = sorted(forbidden_labels.intersection(candidate_labels))
        serialized = json.dumps(result, ensure_ascii=False).lower()
        forbidden_action_hits = [item for item in forbidden_actions if item.lower() in serialized]
        gates = gate_text(result)
        missing_gates = [gate for gate in required_gate_substrings if gate not in gates]
        evidence_ok = all(candidate.get("evidence_paths") for candidate in result.get("candidates", []))

        case_results.append(
            {
                "fixture": fixture_path.name,
                "query_id": result.get("query_id", fixture_path.stem),
                "expected_labels": expected_labels,
                "candidate_labels": candidate_labels,
                "top1_label_hit": top1_hit,
                "top3_label_hit": top3_hit,
                "forbidden_label_hits": forbidden_label_hits,
                "forbidden_action_hits": forbidden_action_hits,
                "missing_gates": missing_gates,
                "evidence_path_coverage": evidence_ok,
                "status": result.get("status", ""),
            }
        )

    total = max(len(case_results), 1)
    summary = {
        "fixture_count": len(case_results),
        "top1_label_hit": sum(1 for item in case_results if item["top1_label_hit"]) / total,
        "top3_label_hit": sum(1 for item in case_results if item["top3_label_hit"]) / total,
        "forbidden_action_violations": sum(len(item["forbidden_action_hits"]) for item in case_results),
        "forbidden_label_violations": sum(len(item["forbidden_label_hits"]) for item in case_results),
        "missing_gate_violations": sum(len(item["missing_gates"]) for item in case_results),
        "evidence_path_coverage": sum(1 for item in case_results if item["evidence_path_coverage"]) / total,
        "cases": case_results,
    }
    write_reports(summary, output_dir)
    return summary


def write_reports(summary: dict[str, Any], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / "assistant_eval_summary.json"
    md_path = output_dir / "assistant_eval_summary.md"
    json_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    lines = [
        "# Data-Driven Simulation Assistant Evaluation",
        "",
        f"- fixture_count: {summary['fixture_count']}",
        f"- top1_label_hit: {summary['top1_label_hit']:.3f}",
        f"- top3_label_hit: {summary['top3_label_hit']:.3f}",
        f"- forbidden_action_violations: {summary['forbidden_action_violations']}",
        f"- forbidden_label_violations: {summary['forbidden_label_violations']}",
        f"- missing_gate_violations: {summary['missing_gate_violations']}",
        f"- evidence_path_coverage: {summary['evidence_path_coverage']:.3f}",
        "",
        "| Fixture | Expected | Candidates | Top1 | Top3 | Missing gates | Forbidden hits |",
        "|---|---|---|---|---|---|---|",
    ]
    for case in summary["cases"]:
        forbidden_hits = case["forbidden_action_hits"] + case["forbidden_label_hits"]
        lines.append(
            "| {fixture} | {expected} | {candidates} | {top1} | {top3} | {gates} | {forbidden} |".format(
                fixture=case["fixture"],
                expected=", ".join(case["expected_labels"]),
                candidates=", ".join(case["candidate_labels"]),
                top1=str(case["top1_label_hit"]).lower(),
                top3=str(case["top3_label_hit"]).lower(),
                gates=", ".join(case["missing_gates"]) or "none",
                forbidden=", ".join(forbidden_hits) or "none",
            )
        )
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    summary = evaluate(Path(args.fixtures), Path(args.output_dir), top_k=args.top_k)
    failed = (
        summary["forbidden_action_violations"]
        or summary["forbidden_label_violations"]
        or summary["missing_gate_violations"]
        or summary["top3_label_hit"] < 1.0
    )
    print(json.dumps(summary, indent=2, ensure_ascii=False, sort_keys=True))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
