---
name: data-driven-simulation-assistant
description: Use when planning or running advisory data-driven support for Simulink power-system modeling in simulink_agent_v1, including neural-network proposals, retrieval from historical simulation reports, candidate failure signatures, dataset schemas, label taxonomies, missing-gate suggestions, and ML-assisted next-experiment planning. Outputs are candidate-only and must route PASS/FAIL, S6 tuning authorization, modal identity, physical source identity, tuning direction, and expensive-run decisions back to deterministic project gates.
---

# Data-Driven Simulation Assistant

Use this skill when a modeling task needs data-driven assistance from prior
simulation experience, text reports, evaluation fixtures, or future neural
models. The assistant is an advisory layer only. It can suggest candidates; it
cannot decide project gates.

## Core Rule

Every result must be treated as candidate evidence. Deterministic project
contracts remain authoritative for model acceptance, tuning authorization,
modal identity, physical source identity, accepted tuning direction, and
expensive simulation launches.

Read `references/assistant-contract.md` before producing or changing runtime
outputs.

## Use For

- retrieving similar historical reports or experience notes;
- proposing candidate failure labels and evidence paths;
- identifying candidate missing gates for review;
- shaping dataset records and label coverage for data-driven experiments;
- planning a no-training baseline or later neural-network prototype;
- warning when data quality is too weak for an ML-assisted suggestion.

## Do Not Use For

- declaring model PASS or FAIL;
- authorizing S6 tuning;
- confirming modal identity;
- confirming physical source identity;
- accepting a tuning direction;
- launching MATLAB, long simulations, or expensive experiments;
- reading `.slx` or `.mat` binary content into a training dataset.

## Workflow

1. Read `docs/DATA_DRIVEN_SIMULATION_ASSISTANT_TASKBOOK.md` and confirm the
   active phase.
2. Read `references/assistant-contract.md`.
3. If labels or dataset fields matter, read `references/label-taxonomy.md` and
   `references/dataset-schema.md`.
4. Produce advisory JSON with candidate labels, confidence, evidence paths,
   required deterministic gates, forbidden actions, and next review.
5. Route any acceptance, S6, modal, source-identity, or launch decision to the
   relevant project skill or contract.

## Read When Needed

- `references/assistant-contract.md` for advisory boundaries and JSON schema.
- `references/label-taxonomy.md` for candidate labels and required gates.
- `references/dataset-schema.md` for JSONL record shape and dataset limits.
- `docs/DATA_DRIVEN_SIMULATION_ASSISTANT_TASKBOOK.md` for phase state and
  handoff protocol.

## Output

Runtime output must be machine-readable JSON shaped by the contract:

```json
{
  "status": "advisory",
  "query_id": "example",
  "candidates": [],
  "required_gates": [],
  "forbidden_actions": [],
  "next_review": "human_or_codex_review_required"
}
```

Use `status: "advisory_needs_gate"` when the candidate looks strong but the
required deterministic gate has not been run or reviewed.
