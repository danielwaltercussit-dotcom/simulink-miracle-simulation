# Simulation Experience Dataset Schema

The data-driven assistant dataset is a JSONL text corpus built from project
reports and handoff notes. It supports retrieval and advisory classification
only.

## Storage Policy

- Generated datasets belong under `build/ml/`.
- Only tiny smoke fixtures should be committed.
- Dataset builders may read `.md`, `.json`, `.txt`, and `.log` files.
- Modal-sensitivity, frequency-sweep, and MIMO summary JSON are preferred
  structured inputs; retain their source paths and provisional status.
- Dataset builders must not ingest `.slx` or `.mat` binary content directly.
- Prefer repo-relative paths in records when possible.
- Generated retrieval indexes are not authority. Reviewed rules remain in the
  relevant skill reference, while raw reports and external sources remain
  provenance.

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

## Optional Reviewed-Knowledge Metadata

Records distilled from local experience or external sources may add:

```json
{
  "knowledge_status": "candidate",
  "applicability": {
    "model_family": "ieee39_dfig",
    "fidelity": "phasor",
    "operating_point": "declared operating-point id",
    "control_mode": "gfl"
  },
  "external_source": {
    "authority": "vendor_official",
    "url": "https://example.invalid/source",
    "revision": "tag-or-commit",
    "license": "reviewed license identifier",
    "tool_version": "R20xx",
    "reviewed_at": "YYYY-MM-DD",
    "local_reproduction": "not_run"
  },
  "reuse_limits": ["do_not_transfer_parameter_values"],
  "supersedes": []
}
```

- `knowledge_status`: `candidate`, `verified`, `provisional`, `rejected`, or
  `blocked`. Only Codex-reviewed, disk-backed claims may become `verified`.
- `applicability`: deterministic retrieval filters. Unknown values must remain
  explicit rather than inferred from semantic similarity.
- `external_source.authority`: use `vendor_official`, `standard`,
  `primary_publication`, `maintained_research_repo`, or `community`.
- `revision`: immutable tag, release, document version, DOI, or commit when the
  source provides one.
- `local_reproduction`: `not_run`, `partial`, `passed`, or `failed`. A remote
  example running successfully is not local reproduction.
- `reuse_limits`: boundaries such as model-specific assumptions, prohibited
  parameter transfer, missing toolbox coverage, or incompatible fidelity.
- `supersedes`: ids of older records whose conclusions are no longer current.

Before lexical or neural ranking, filter incompatible model families,
fidelities, operating points, control modes, rejected/blocked knowledge, and
unmet deterministic gates. Neural similarity never promotes a candidate or
external source to verified knowledge.

## External Knowledge Admission Loop

1. Periodically inspect official sources and trusted repositories for methods,
   version changes, and known failure modes.
2. Extract a bounded candidate with provenance; do not ingest a whole manual or
   repository into the portable library.
3. Review mathematical assumptions, units, bases, fidelity, version, and
   license.
4. Reproduce the claim on a small fixture or existing local evidence without
   modifying a canonical model merely to test external advice.
5. Distill accepted knowledge into the relevant existing `references/*.md` and
   retain source revision and reuse limits.
6. Rebuild the local lightweight index. Actual modeling decisions still route
   through local mathematical analysis and deterministic verification gates.

## Minimal Fixture Expectations

A committed fixture should include:

- at least one positive candidate label;
- at least one insufficient-evidence or missing-gate case;
- at least one record that references an `.slx` or `.mat` path only as text,
  proving that binary content is not ingested.
