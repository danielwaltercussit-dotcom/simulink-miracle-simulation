# Data-Driven Simulation Assistant Contract

This contract defines the safety boundary for the
`data-driven-simulation-assistant` skill. It applies to retrieval baselines,
dataset builders, classifiers, neural-network prototypes, and experiment
suggesters.

## Authority Boundary

The assistant produces candidate-only guidance. A high confidence score is not
authorization, acceptance, or proof. Deterministic gates remain authoritative.

If a candidate needs a deterministic gate that has not been run or reviewed,
the output status must be `advisory_needs_gate`.

## Forbidden Decisions

The assistant must not:

- declare model PASS or FAIL;
- authorize S6 tuning;
- confirm modal identity;
- confirm physical source identity;
- accept a tuning direction;
- decide whether to launch MATLAB, a long simulation, or an expensive
  experiment;
- alter oracle models, lab archives, `.slx` binaries, or `.mat` binaries;
- promote generated data outside `build/ml/` without explicit human review.

## Deterministic Gate Routing

Candidate outputs must route review to the relevant project contract, for
example:

- model acceptance: `.agents/skills/simulink-model-verification/`;
- simulation execution policy: `.agents/skills/simulating-simulink-models/`;
- modal evidence: `.agents/skills/small-signal-modal-analysis/`;
- tuning decisions: `.agents/skills/power-electronics-tuning/`;
- regression evidence: `.agents/skills/baseline-regression/`;
- plot evidence: `.agents/skills/diagnostic-plotting/`;
- current lessons: `.agents/skills/simulink-modeling-assistant/references/current-simulation-experience.md`.

The exact gate path should appear in `required_gates` when the assistant names a
candidate.

## Runtime JSON Schema

Every runtime suggestion must be valid JSON with this shape:

```json
{
  "status": "advisory",
  "query_id": "string",
  "candidates": [
    {
      "label": "ambient_masked",
      "confidence": 0.0,
      "evidence_paths": ["relative/or/absolute/path.md"],
      "why": "short candidate rationale"
    }
  ],
  "required_gates": ["relative/or/absolute/contract.md"],
  "forbidden_actions": ["S6 tuning", "model PASS/FAIL"],
  "next_review": "human_or_codex_review_required"
}
```

Allowed `status` values:

- `advisory`: candidate guidance with named gates.
- `advisory_needs_gate`: candidate guidance that still needs deterministic gate
  execution or review.
- `insufficient_evidence`: no useful candidate can be proposed from the
  available text evidence.

## Confidence Semantics

`confidence` is a ranking signal for review priority, not a decision threshold.
Use values from `0.0` to `1.0`. Do not translate confidence into PASS/FAIL,
S6 authorization, modal identity, source identity, or run-launch decisions.

## Evidence Requirements

Each candidate must include at least one text evidence path when evidence was
available. Prefer repo-relative paths. If evidence is unavailable, return
`status: "insufficient_evidence"` and explain the missing evidence in
`next_review`.

Datasets may read text files such as `.md`, `.json`, `.txt`, and `.log`.
Datasets must not ingest `.slx` or `.mat` binary content directly, though text
reports may reference those paths.

## Validation Expectations

Before claiming this skill changed behavior, validate at least:

- skill frontmatter is well formed;
- advisory output examples parse as JSON;
- no script or skill text claims decision authority;
- taskbook status and Agent Log are updated.
