"""Shared helpers for the data-driven simulation assistant.

The assistant is deliberately transparent: records come from text reports, label
scores come from visible keyword rules, and every candidate routes back to
deterministic project gates.
"""

from __future__ import annotations

import fnmatch
import hashlib
import json
import math
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


ALLOWED_TEXT_SUFFIXES = {".md", ".json", ".txt", ".log"}
BLOCKED_BINARY_SUFFIXES = {".slx", ".mat", ".mlx", ".fig", ".slxc"}
DEFAULT_EXCLUDE_DIRS = {
    ".git",
    ".hg",
    ".svn",
    ".ctx",
    ".claude",
    "__pycache__",
    "build",
    "slprj",
    "external",
}

FORBIDDEN_ACTIONS = [
    "do_not_decide_model_pass_fail",
    "do_not_authorize_s6_tuning",
    "do_not_confirm_modal_identity",
    "do_not_confirm_physical_source_identity",
    "do_not_launch_expensive_simulation",
]


@dataclass(frozen=True)
class LabelRule:
    label: str
    phrases: tuple[str, ...]
    required_gates: tuple[str, ...]
    why: str


LABEL_RULES: tuple[LabelRule, ...] = (
    LabelRule(
        label="ambient_masked",
        phrases=(
            "ambient masked",
            "ambient line",
            "null window",
            "persistent baseline",
            "weak event contrast",
            "forced perturbation is masked",
            "ringdown hidden",
        ),
        required_gates=(
            ".agents/skills/simulink-modeling-assistant/references/current-simulation-experience.md",
            ".agents/skills/diagnostic-plotting/references/plotting-contract.md",
            ".agents/skills/small-signal-modal-analysis/references/modal-contract.md",
        ),
        why="ambient or baseline content may mask the response under review",
    ),
    LabelRule(
        label="modal_identity_unproven",
        phrases=(
            "modal identity unproven",
            "frequency coincidence",
            "peak only",
            "no eigenvalue linkage",
            "missing eigenvalue",
            "mode not verified",
            "participation missing",
        ),
        required_gates=(
            ".agents/skills/small-signal-modal-analysis/references/modal-contract.md",
        ),
        why="frequency evidence needs deterministic modal identity review",
    ),
    LabelRule(
        label="memory_unbounded",
        phrases=(
            "memory unbounded",
            "unbounded memory",
            "growing run folders",
            "appended logs",
            "memory pressure",
            "retention policy missing",
            "pid slope",
        ),
        required_gates=(
            ".agents/skills/simulating-simulink-models/",
            ".agents/skills/diagnostic-plotting/references/plotting-contract.md",
        ),
        why="workflow may be accumulating data or state without a bounded policy",
    ),
    LabelRule(
        label="operating_point_unqualified",
        phrases=(
            "operating point unqualified",
            "missing operating point",
            "load flow missing",
            "initial condition missing",
            "stop time missing",
            "solver mismatch",
            "scenario mismatch",
        ),
        required_gates=(
            ".agents/skills/simulating-simulink-models/",
            ".agents/skills/simulink-model-verification/",
        ),
        why="comparison lacks a qualified scenario or operating point",
    ),
    LabelRule(
        label="degenerate_time_axis",
        phrases=(
            "degenerate time axis",
            "duplicate timestamps",
            "zero duration",
            "single sample",
            "unsorted time",
            "invalid time vector",
            "flat time axis",
        ),
        required_gates=(
            ".agents/skills/diagnostic-plotting/references/plotting-contract.md",
            ".agents/skills/simulating-simulink-models/",
        ),
        why="time-series evidence has an invalid or uninformative time axis",
    ),
    LabelRule(
        label="physical_injection_observability_split",
        phrases=(
            "physical injection observability split",
            "source identity",
            "measurement channel missing",
            "injection visible",
            "observability absent",
            "disturbance not observed",
        ),
        required_gates=(
            ".agents/skills/simulink-model-verification/",
            ".agents/skills/diagnostic-plotting/references/plotting-contract.md",
        ),
        why="disturbance injection and measured observability may not align",
    ),
    LabelRule(
        label="validator_hardcoded_runid",
        phrases=(
            "hardcoded run id",
            "hardcoded runid",
            "stale latest pointer",
            "bundle mismatch",
            "active bundle mismatch",
            "fixed run folder",
        ),
        required_gates=(
            ".agents/skills/baseline-regression/references/long-baseline-causal-gate.md",
            ".agents/skills/simulink-model-verification/",
        ),
        why="validator may be reading stale or fixed evidence instead of the active run",
    ),
    LabelRule(
        label="layout_structure_drift",
        phrases=(
            "layout structure drift",
            "block count changed",
            "line count changed",
            "port topology changed",
            "pre post structure mismatch",
            "layout changed structure",
        ),
        required_gates=(
            ".agents/skills/simulink-model-quality-layout/",
            "scripts/layout/capture_layout_structure.m",
            "scripts/layout/verify_layout_structure.m",
        ),
        why="layout work may have changed topology instead of only moving blocks",
    ),
    LabelRule(
        label="control_feedback_polarity_mismatch",
        phrases=(
            "control feedback polarity mismatch",
            "polarity mismatch",
            "feedback sign mismatch",
            "wrong feedback sign",
            "sign disagreement",
            "negative feedback wired positive",
            "tune gains to mask polarity",
        ),
        required_gates=(
            "tests/control_feedback_polarity_test.m",
            "scripts/verification/verify_control_feedback_polarity.m",
            ".agents/skills/simulink-modeling-assistant/references/derivation-cookbook.md",
        ),
        why="control-loop sign or wiring polarity needs deterministic review",
    ),
)


def repo_relative(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def normalize_text(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def tokenize(text: str) -> list[str]:
    return re.findall(r"[a-z0-9_]+", text.lower())


def phrase_hits(text: str, phrases: Iterable[str]) -> list[str]:
    lower = text.lower()
    return [phrase for phrase in phrases if phrase in lower]


def classify_text(text: str) -> list[dict[str, Any]]:
    direct = text.lower()
    results: list[dict[str, Any]] = []
    for rule in LABEL_RULES:
        hits = phrase_hits(direct, rule.phrases)
        if rule.label in direct and rule.label not in hits:
            hits.append(rule.label)
        if not hits:
            continue
        confidence = min(0.95, 0.45 + 0.12 * len(hits))
        results.append(
            {
                "label": rule.label,
                "confidence": round(confidence, 3),
                "matched_phrases": sorted(set(hits)),
                "required_gates": list(rule.required_gates),
                "why": rule.why,
            }
        )
    results.sort(key=lambda item: (-item["confidence"], item["label"]))
    return results


def source_kind_for(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix == ".md":
        return "markdown_report"
    if suffix == ".json":
        return "json_report"
    if suffix == ".log":
        return "terminal_log"
    if suffix == ".txt":
        return "handoff_note"
    return "text_report"


def infer_case_family(text: str, source_path: str) -> str:
    haystack = f"{source_path} {text}".lower()
    if "ieee39" in haystack or "39bus" in haystack or "nebus39" in haystack:
        if "dfig" in haystack:
            return "ieee39_dfig"
        return "ieee39"
    if "kundur" in haystack or "twoarea" in haystack or "two area" in haystack:
        return "kundur_two_area"
    if "dfig" in haystack:
        return "dfig"
    return "unknown"


def infer_stage(text: str, source_path: str) -> str:
    haystack = f"{source_path} {text}"
    match = re.search(r"\b(?:P\d+|R\d+|S\d+|DIF-\d+)\b", haystack, re.IGNORECASE)
    return match.group(0).upper() if match else "unknown"


def summarize_text(text: str, max_chars: int = 360) -> str:
    normalized = normalize_text(text)
    if len(normalized) <= max_chars:
        return normalized
    return normalized[: max_chars - 3].rstrip() + "..."


def stable_record_id(source_path: str, text: str) -> str:
    digest = hashlib.sha1(f"{source_path}\n{normalize_text(text)}".encode("utf-8")).hexdigest()
    stem = re.sub(r"[^a-z0-9]+", "-", Path(source_path).stem.lower()).strip("-") or "record"
    return f"{stem}-{digest[:12]}"


def build_record(source_path: str, text: str) -> dict[str, Any]:
    labels = classify_text(text)
    required_gates: list[str] = []
    for label in labels:
        for gate in label["required_gates"]:
            if gate not in required_gates:
                required_gates.append(gate)
    return {
        "record_id": stable_record_id(source_path, text),
        "source_path": source_path,
        "source_kind": source_kind_for(Path(source_path)),
        "case_family": infer_case_family(text, source_path),
        "stage": infer_stage(text, source_path),
        "text_summary": summarize_text(text),
        "labels": [item["label"] for item in labels],
        "metrics": {
            "label_hint_count": len(labels),
            "text_char_count": len(text),
        },
        "evidence_paths": [source_path],
        "required_gates": required_gates,
    }


def validate_record(record: dict[str, Any]) -> list[str]:
    required = (
        "record_id",
        "source_path",
        "source_kind",
        "case_family",
        "stage",
        "text_summary",
        "labels",
        "metrics",
        "evidence_paths",
        "required_gates",
    )
    errors: list[str] = []
    for field in required:
        if field not in record:
            errors.append(f"missing field: {field}")
    for list_field in ("labels", "evidence_paths", "required_gates"):
        if list_field in record and not isinstance(record[list_field], list):
            errors.append(f"{list_field} must be a list")
    if "metrics" in record and not isinstance(record["metrics"], dict):
        errors.append("metrics must be an object")
    return errors


def should_skip_path(
    path: Path,
    repo_root: Path,
    include_globs: Iterable[str] | None = None,
    exclude_globs: Iterable[str] | None = None,
) -> bool:
    rel = repo_relative(path, repo_root)
    parts = set(Path(rel).parts)
    if parts & DEFAULT_EXCLUDE_DIRS:
        return True
    suffix = path.suffix.lower()
    if suffix in BLOCKED_BINARY_SUFFIXES:
        return True
    if suffix not in ALLOWED_TEXT_SUFFIXES:
        return True
    include = list(include_globs or [])
    exclude = list(exclude_globs or [])
    if include and not any(fnmatch.fnmatch(rel, pattern) for pattern in include):
        return True
    if exclude and any(fnmatch.fnmatch(rel, pattern) for pattern in exclude):
        return True
    return False


def iter_text_files(
    repo_root: Path,
    include_globs: Iterable[str] | None = None,
    exclude_globs: Iterable[str] | None = None,
) -> Iterable[Path]:
    for path in sorted(repo_root.rglob("*")):
        if path.is_file() and not should_skip_path(path, repo_root, include_globs, exclude_globs):
            yield path


def read_text_lossy(path: Path, max_bytes: int = 512_000) -> str:
    data = path.read_bytes()[:max_bytes]
    return data.decode("utf-8", errors="replace")


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    if not path.exists():
        return records
    with path.open("r", encoding="utf-8") as handle:
        for line_no, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            record = json.loads(stripped)
            errors = validate_record(record)
            if errors:
                joined = "; ".join(errors)
                raise ValueError(f"{path}:{line_no}: invalid record: {joined}")
            records.append(record)
    return records


def write_jsonl(path: Path, records: Iterable[dict[str, Any]]) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for record in records:
            handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
            count += 1
    return count


def lexical_score(query_tokens: Counter[str], record_tokens: Counter[str], idf: dict[str, float]) -> float:
    score = 0.0
    for token, q_count in query_tokens.items():
        if token not in record_tokens:
            continue
        score += min(q_count, record_tokens[token]) * idf.get(token, 1.0)
    q_norm = math.sqrt(sum(value * value for value in query_tokens.values())) or 1.0
    r_norm = math.sqrt(sum(value * value for value in record_tokens.values())) or 1.0
    return score / (q_norm * r_norm)


def compute_idf(records: list[dict[str, Any]]) -> dict[str, float]:
    doc_count = max(len(records), 1)
    df: Counter[str] = Counter()
    for record in records:
        tokens = set(tokenize(record.get("text_summary", "")))
        for token in tokens:
            df[token] += 1
    return {token: math.log((1 + doc_count) / (1 + count)) + 1.0 for token, count in df.items()}


def suggest_from_records(
    query_text: str,
    records: list[dict[str, Any]],
    query_id: str = "query",
    top_k: int = 3,
) -> dict[str, Any]:
    query_tokens = Counter(tokenize(query_text))
    query_labels = classify_text(query_text)
    query_label_names = {item["label"] for item in query_labels}
    idf = compute_idf(records)
    scored_records: list[dict[str, Any]] = []
    for record in records:
        record_tokens = Counter(tokenize(record.get("text_summary", "")))
        score = lexical_score(query_tokens, record_tokens, idf)
        overlap = query_label_names.intersection(record.get("labels", []))
        score += 0.8 * len(overlap)
        if score <= 0:
            continue
        copy = dict(record)
        copy["score"] = round(score, 6)
        scored_records.append(copy)
    scored_records.sort(key=lambda item: (-item["score"], item.get("record_id", "")))
    label_scores: dict[str, float] = defaultdict(float)
    label_evidence: dict[str, list[str]] = defaultdict(list)
    label_gates: dict[str, list[str]] = defaultdict(list)
    label_why: dict[str, str] = {}

    for item in query_labels:
        label_scores[item["label"]] += item["confidence"] + 0.4
        label_why[item["label"]] = item["why"]
        for gate in item["required_gates"]:
            if gate not in label_gates[item["label"]]:
                label_gates[item["label"]].append(gate)

    for record in scored_records[: max(top_k * 2, 5)]:
        for label in record.get("labels", []):
            label_scores[label] += float(record["score"])
            for evidence_path in record.get("evidence_paths", []):
                if evidence_path not in label_evidence[label]:
                    label_evidence[label].append(evidence_path)
            for gate in record.get("required_gates", []):
                if gate not in label_gates[label]:
                    label_gates[label].append(gate)
            if label not in label_why:
                rule = next((rule for rule in LABEL_RULES if rule.label == label), None)
                label_why[label] = rule.why if rule else "candidate label from similar records"

    candidates = []
    max_score = max(label_scores.values(), default=0.0)
    for label, score in sorted(label_scores.items(), key=lambda item: (-item[1], item[0]))[:top_k]:
        confidence = 0.0 if max_score <= 0 else min(0.99, 0.25 + 0.7 * (score / max_score))
        candidates.append(
            {
                "label": label,
                "confidence": round(confidence, 3),
                "evidence_paths": label_evidence.get(label) or [record.get("source_path", "query") for record in scored_records[:1]],
                "why": label_why.get(label, "candidate label from lexical retrieval"),
            }
        )

    required_gates: list[str] = []
    for candidate in candidates:
        for gate in label_gates.get(candidate["label"], []):
            if gate not in required_gates:
                required_gates.append(gate)

    if not candidates:
        return {
            "status": "insufficient_evidence",
            "query_id": query_id,
            "candidates": [],
            "required_gates": [],
            "forbidden_actions": FORBIDDEN_ACTIONS,
            "next_review": "add_text_evidence_or_review_deterministic_contracts",
        }

    return {
        "status": "advisory_needs_gate",
        "query_id": query_id,
        "candidates": candidates,
        "required_gates": required_gates,
        "forbidden_actions": FORBIDDEN_ACTIONS,
        "next_review": "human_or_codex_review_required",
        "similar_records": [
            {
                "record_id": item.get("record_id", ""),
                "source_path": item.get("source_path", ""),
                "score": item["score"],
                "labels": item.get("labels", []),
            }
            for item in scored_records[:top_k]
        ],
    }


def load_fixture(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)
