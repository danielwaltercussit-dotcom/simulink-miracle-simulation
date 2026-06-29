"""Train a CPU-friendly NumPy failure-signature classifier prototype.

This is an experimental P5 helper. It compares the neural prototype against the
P3 lexical baseline and keeps deterministic gates in every advisory output.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

try:
    import numpy as np
except ImportError as exc:  # pragma: no cover - exercised only on missing runtime deps
    raise SystemExit("NumPy is required for the CPU-friendly neural prototype.") from exc

from simulation_assistant_lib import (
    FORBIDDEN_ACTIONS,
    LABEL_RULES,
    classify_text,
    load_fixture,
    load_jsonl,
    suggest_from_records,
    tokenize,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", default="tests/fixtures/data_driven_simulation_assistant/dataset.jsonl")
    parser.add_argument("--fixtures", default="tests/fixtures/data_driven_simulation_assistant")
    parser.add_argument("--model-dir", default="build/ml/models/failure_signature_classifier")
    parser.add_argument("--feature-dim", type=int, default=256)
    parser.add_argument("--hidden-dim", type=int, default=24)
    parser.add_argument("--epochs", type=int, default=700)
    parser.add_argument("--learning-rate", type=float, default=0.35)
    parser.add_argument("--seed", type=int, default=39)
    parser.add_argument("--top-k", type=int, default=3)
    return parser.parse_args()


def stable_token_bucket(token: str, feature_dim: int) -> int:
    import hashlib

    digest = hashlib.sha1(token.encode("utf-8")).hexdigest()
    return int(digest[:8], 16) % feature_dim


def vectorize_text(text: str, feature_dim: int) -> np.ndarray:
    vector = np.zeros(feature_dim, dtype=np.float64)
    tokens = tokenize(text)
    if not tokens:
        return vector
    for token in tokens:
        vector[stable_token_bucket(token, feature_dim)] += 1.0
    norm = math.sqrt(float(np.dot(vector, vector))) or 1.0
    return vector / norm


def prepare_training(records: list[dict[str, Any]], feature_dim: int) -> tuple[np.ndarray, np.ndarray, list[str]]:
    labels = sorted({label for record in records for label in record.get("labels", [])})
    if not labels:
        raise ValueError("Training dataset has no explicit labels.")
    label_index = {label: idx for idx, label in enumerate(labels)}
    x_rows = []
    y_rows = []
    for record in records:
        text = f"{record.get('source_path', '')} {record.get('text_summary', '')}"
        x_rows.append(vectorize_text(text, feature_dim))
        y = np.zeros(len(labels), dtype=np.float64)
        for label in record.get("labels", []):
            y[label_index[label]] = 1.0
        y_rows.append(y)
    return np.vstack(x_rows), np.vstack(y_rows), labels


def sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-np.clip(x, -40, 40)))


def init_model(input_dim: int, hidden_dim: int, output_dim: int, seed: int) -> dict[str, np.ndarray]:
    rng = np.random.default_rng(seed)
    return {
        "w1": rng.normal(0.0, 0.08, size=(input_dim, hidden_dim)),
        "b1": np.zeros(hidden_dim, dtype=np.float64),
        "w2": rng.normal(0.0, 0.08, size=(hidden_dim, output_dim)),
        "b2": np.zeros(output_dim, dtype=np.float64),
    }


def forward(model: dict[str, np.ndarray], x: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    hidden = np.tanh(x @ model["w1"] + model["b1"])
    probs = sigmoid(hidden @ model["w2"] + model["b2"])
    return hidden, probs


def train_mlp(
    x: np.ndarray,
    y: np.ndarray,
    hidden_dim: int,
    epochs: int,
    learning_rate: float,
    seed: int,
) -> tuple[dict[str, np.ndarray], list[float]]:
    model = init_model(x.shape[1], hidden_dim, y.shape[1], seed)
    history: list[float] = []
    n = float(x.shape[0])
    # Mild positive weighting helps tiny multi-label fixtures learn the sparse labels.
    positive_weight = np.maximum(1.0, (y.shape[0] - y.sum(axis=0)) / np.maximum(y.sum(axis=0), 1.0))
    for _ in range(epochs):
        hidden, probs = forward(model, x)
        eps = 1e-8
        weights = np.where(y > 0, positive_weight, 1.0)
        loss = -np.mean(weights * (y * np.log(probs + eps) + (1.0 - y) * np.log(1.0 - probs + eps)))
        history.append(float(loss))

        grad_logits = weights * (probs - y) / n
        grad_w2 = hidden.T @ grad_logits
        grad_b2 = grad_logits.sum(axis=0)
        grad_hidden = (grad_logits @ model["w2"].T) * (1.0 - hidden * hidden)
        grad_w1 = x.T @ grad_hidden
        grad_b1 = grad_hidden.sum(axis=0)

        model["w2"] -= learning_rate * grad_w2
        model["b2"] -= learning_rate * grad_b2
        model["w1"] -= learning_rate * grad_w1
        model["b1"] -= learning_rate * grad_b1
    return model, history


def gates_for_label(label: str) -> list[str]:
    rule = next((rule for rule in LABEL_RULES if rule.label == label), None)
    return list(rule.required_gates) if rule else []


def why_for_label(label: str) -> str:
    rule = next((rule for rule in LABEL_RULES if rule.label == label), None)
    return rule.why if rule else "candidate label from CPU-friendly neural prototype"


def evidence_for_label(label: str, records: list[dict[str, Any]]) -> list[str]:
    paths: list[str] = []
    for record in records:
        if label not in record.get("labels", []):
            continue
        for path in record.get("evidence_paths", []) or [record.get("source_path", "")]:
            if path and path not in paths:
                paths.append(path)
    return paths or ["training_dataset"]


def predict_advisory(
    query_text: str,
    query_id: str,
    model: dict[str, np.ndarray],
    labels: list[str],
    records: list[dict[str, Any]],
    feature_dim: int,
    top_k: int,
) -> dict[str, Any]:
    _, probs = forward(model, vectorize_text(query_text, feature_dim)[None, :])
    probs = probs[0]
    direct = {item["label"]: item["confidence"] for item in classify_text(query_text)}
    scored: list[tuple[str, float]] = []
    for idx, label in enumerate(labels):
        neural_conf = float(probs[idx])
        if label in direct:
            confidence = min(0.99, 0.15 + 0.6 * neural_conf + 0.35 * direct[label])
        else:
            confidence = min(0.94, neural_conf)
        scored.append((label, confidence))
    scored.sort(key=lambda item: (-item[1], item[0]))

    candidates = []
    required_gates: list[str] = []
    for label, confidence in scored[:top_k]:
        label_gates = gates_for_label(label)
        for gate in label_gates:
            if gate not in required_gates:
                required_gates.append(gate)
        candidates.append(
            {
                "label": label,
                "confidence": round(confidence, 3),
                "evidence_paths": evidence_for_label(label, records),
                "why": why_for_label(label),
            }
        )

    return {
        "status": "advisory_needs_gate",
        "query_id": query_id,
        "candidates": candidates,
        "required_gates": required_gates,
        "forbidden_actions": FORBIDDEN_ACTIONS,
        "next_review": "human_or_codex_review_required",
        "model_type": "hashed_bow_numpy_mlp",
    }


def confidence_for(result: dict[str, Any], label: str) -> float:
    for candidate in result.get("candidates", []):
        if candidate.get("label") == label:
            return float(candidate.get("confidence", 0.0))
    return 0.0


def evaluate_classifier(
    records: list[dict[str, Any]],
    model: dict[str, np.ndarray],
    labels: list[str],
    fixtures_dir: Path,
    feature_dim: int,
    top_k: int,
) -> dict[str, Any]:
    cases = []
    for fixture_path in sorted(path for path in fixtures_dir.glob("*.json") if path.name != "dataset.json"):
        fixture = load_fixture(fixture_path)
        query_id = fixture.get("query_id", fixture_path.stem)
        query_text = fixture["query_text"]
        expected = fixture.get("expected_labels", [])
        baseline = suggest_from_records(query_text, records, query_id=query_id, top_k=top_k)
        classifier = predict_advisory(query_text, query_id, model, labels, records, feature_dim, top_k)
        baseline_labels = [item["label"] for item in baseline.get("candidates", [])]
        classifier_labels = [item["label"] for item in classifier.get("candidates", [])]
        expected_label = expected[0] if expected else ""
        baseline_conf = confidence_for(baseline, expected_label)
        classifier_conf = confidence_for(classifier, expected_label)
        serialized_classifier = json.dumps(classifier, ensure_ascii=False).lower()
        forbidden_hits = [
            item
            for item in fixture.get("forbidden_actions", [])
            if item.lower() in serialized_classifier
        ]
        gate_text = "\n".join(classifier.get("required_gates", []))
        missing_gates = [gate for gate in fixture.get("required_gate_substrings", []) if gate not in gate_text]
        cases.append(
            {
                "fixture": fixture_path.name,
                "expected_label": expected_label,
                "baseline_labels": baseline_labels,
                "classifier_labels": classifier_labels,
                "baseline_top1": bool(baseline_labels[:1] and baseline_labels[0] in expected),
                "baseline_top3": any(label in baseline_labels[:3] for label in expected),
                "classifier_top1": bool(classifier_labels[:1] and classifier_labels[0] in expected),
                "classifier_top3": any(label in classifier_labels[:3] for label in expected),
                "baseline_expected_confidence": round(baseline_conf, 3),
                "classifier_expected_confidence": round(classifier_conf, 3),
                "confidence_gain": round(classifier_conf - baseline_conf, 3),
                "forbidden_action_hits": forbidden_hits,
                "missing_gates": missing_gates,
                "classifier_result": classifier,
            }
        )

    total = max(len(cases), 1)
    forbidden_action_violations = sum(len(case["forbidden_action_hits"]) for case in cases)
    missing_gate_violations = sum(len(case["missing_gates"]) for case in cases)
    confidence_gain_cases = sum(1 for case in cases if case["confidence_gain"] > 0.005)
    summary = {
        "fixture_count": len(cases),
        "baseline": {
            "top1_label_hit": sum(1 for case in cases if case["baseline_top1"]) / total,
            "top3_label_hit": sum(1 for case in cases if case["baseline_top3"]) / total,
        },
        "classifier": {
            "top1_label_hit": sum(1 for case in cases if case["classifier_top1"]) / total,
            "top3_label_hit": sum(1 for case in cases if case["classifier_top3"]) / total,
            "confidence_gain_cases": confidence_gain_cases,
        },
        "forbidden_action_violations": forbidden_action_violations,
        "missing_gate_violations": missing_gate_violations,
        "cases": cases,
    }
    improved = (
        summary["classifier"]["top3_label_hit"] >= summary["baseline"]["top3_label_hit"]
        and confidence_gain_cases >= 1
        and forbidden_action_violations == 0
        and missing_gate_violations == 0
    )
    summary["routing_recommendation"] = (
        "eligible_for_p7_review_not_auto_routed" if improved else "experimental_do_not_route"
    )
    return summary


def serialize_model(
    model: dict[str, np.ndarray],
    labels: list[str],
    feature_dim: int,
    hidden_dim: int,
    history: list[float],
) -> dict[str, Any]:
    return {
        "type": "hashed_bow_numpy_mlp",
        "feature_dim": feature_dim,
        "hidden_dim": hidden_dim,
        "labels": labels,
        "loss_initial": round(history[0], 6) if history else None,
        "loss_final": round(history[-1], 6) if history else None,
        "weights": {name: value.round(8).tolist() for name, value in model.items()},
    }


def write_artifacts(model_doc: dict[str, Any], summary: dict[str, Any], model_dir: Path) -> None:
    model_dir.mkdir(parents=True, exist_ok=True)
    (model_dir / "failure_signature_classifier_model.json").write_text(
        json.dumps(model_doc, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (model_dir / "failure_signature_classifier_summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    lines = [
        "# Failure Signature Classifier Prototype",
        "",
        f"- model_type: {model_doc['type']}",
        f"- feature_dim: {model_doc['feature_dim']}",
        f"- hidden_dim: {model_doc['hidden_dim']}",
        f"- loss_initial: {model_doc['loss_initial']}",
        f"- loss_final: {model_doc['loss_final']}",
        f"- baseline_top3_label_hit: {summary['baseline']['top3_label_hit']:.3f}",
        f"- classifier_top3_label_hit: {summary['classifier']['top3_label_hit']:.3f}",
        f"- confidence_gain_cases: {summary['classifier']['confidence_gain_cases']}",
        f"- forbidden_action_violations: {summary['forbidden_action_violations']}",
        f"- missing_gate_violations: {summary['missing_gate_violations']}",
        f"- routing_recommendation: {summary['routing_recommendation']}",
        "",
        "The prototype remains advisory and is not routed from the skill until a later integration phase.",
    ]
    (model_dir / "failure_signature_classifier_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def run_training(args: argparse.Namespace) -> dict[str, Any]:
    dataset_path = Path(args.dataset)
    fixtures_dir = Path(args.fixtures)
    records = load_jsonl(dataset_path)
    x, y, labels = prepare_training(records, args.feature_dim)
    model, history = train_mlp(x, y, args.hidden_dim, args.epochs, args.learning_rate, args.seed)
    summary = evaluate_classifier(records, model, labels, fixtures_dir, args.feature_dim, args.top_k)
    summary["model"] = {
        "type": "hashed_bow_numpy_mlp",
        "feature_dim": args.feature_dim,
        "hidden_dim": args.hidden_dim,
        "label_count": len(labels),
        "loss_initial": round(history[0], 6) if history else None,
        "loss_final": round(history[-1], 6) if history else None,
        "dataset": str(dataset_path),
    }
    model_doc = serialize_model(model, labels, args.feature_dim, args.hidden_dim, history)
    write_artifacts(model_doc, summary, Path(args.model_dir))
    summary["artifacts"] = {
        "model": str(Path(args.model_dir) / "failure_signature_classifier_model.json"),
        "summary_json": str(Path(args.model_dir) / "failure_signature_classifier_summary.json"),
        "summary_md": str(Path(args.model_dir) / "failure_signature_classifier_summary.md"),
    }
    return summary


def main() -> int:
    args = parse_args()
    summary = run_training(args)
    print(json.dumps(summary, indent=2, ensure_ascii=False, sort_keys=True))
    failed = summary["forbidden_action_violations"] or summary["missing_gate_violations"]
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
