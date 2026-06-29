# Simulation Experience Dataset Schema

The data-driven assistant dataset is a JSONL text corpus built from project
reports and handoff notes. It supports retrieval and advisory classification
only.

## Storage Policy

- Generated datasets belong under `build/ml/`.
- Only tiny smoke fixtures should be committed.
- Dataset builders may read `.md`, `.json`, `.txt`, and `.log` files.
- Dataset builders must not ingest `.slx` or `.mat` binary content directly.
- Prefer repo-relative paths in records when possible.

## JSONL Record

Each line is one JSON object with these fields:

```json
{
  "record_id": "stable-string",
  "source_path": "relative/path/to/report.md",
  "source_kind": "markdown_report",
  "case_family": "ieee39_dfig",
  "stage": "S5",
  "text_summary": "short evidence summary",
  "labels": ["ambient_masked"],
  "metrics": {
    "confidence_hint": 0.0
  },
  "evidence_paths": ["relative/path/to/report.md"],
  "required_gates": [
    ".agents/skills/small-signal-modal-analysis/references/modal-contract.md"
  ]
}
```

## Field Rules

- `record_id`: stable id derived from source path and normalized content or a
  deterministic fixture id.
- `source_path`: text source that produced the record.
- `source_kind`: short source type such as `markdown_report`, `json_report`,
  `terminal_log`, or `handoff_note`.
- `case_family`: scenario family when known, otherwise `unknown`.
- `stage`: workflow stage such as `R1`, `S5`, `S6`, `P1`, or `unknown`.
- `text_summary`: concise normalized evidence summary; do not store large raw
  file bodies in committed fixtures.
- `labels`: candidate labels from `label-taxonomy.md`.
- `metrics`: numeric or string hints extracted from the text source; keep empty
  when not available.
- `evidence_paths`: one or more text evidence paths for review.
- `required_gates`: deterministic contracts that must review the candidate.

## Minimal Fixture Expectations

A committed fixture should include:

- at least one positive candidate label;
- at least one insufficient-evidence or missing-gate case;
- at least one record that references an `.slx` or `.mat` path only as text,
  proving that binary content is not ingested.
