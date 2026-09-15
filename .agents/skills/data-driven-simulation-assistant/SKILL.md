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
- reviewing official documentation and maintained research repositories as
  candidate knowledge sources;
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

1. Read `references/assistant-contract.md`.
2. If labels or dataset fields matter, read `references/label-taxonomy.md` and
   `references/dataset-schema.md`.
3. For external knowledge, prefer official vendor documentation, standards,
   primary papers, and maintained repositories. Record source revision,
   license, applicable model/fidelity, and tool version before reuse.
4. Treat external material as a candidate until its mathematics and assumptions
   are reviewed and its useful claim is reproduced on a small fixture or
   existing local evidence. Distill accepted rules into an existing
   `references/*.md`; do not copy whole repositories or manuals into skills.
5. Build or refresh the text/JSONL experience dataset; do not ingest `.slx` or
   `.mat` binaries. Use `--include-build-reports` for reviewed run reports; the
   builder still excludes `build/ml` so it cannot train on its own output.
6. Use deterministic filters for model family, fidelity, operating point,
   authority, and review status before lexical or neural ranking.
7. Use the lexical baseline by default. Use the CPU neural classifier only when
   its saved model and evaluation summary were produced from the current
   dataset and the summary has no gate or forbidden-action violations.
8. Produce advisory JSON with candidate labels, candidate parameter classes,
   confidence, evidence paths, required deterministic gates, forbidden actions,
   and next review.
9. Route any acceptance, S6, modal, source-identity, or launch decision to the
   relevant project skill or contract.

## Read When Needed

- `references/assistant-contract.md` for advisory boundaries and JSON schema.
- `references/label-taxonomy.md` for candidate labels and required gates.
- `references/dataset-schema.md` for JSONL record shape and dataset limits.
- `../simulink-modeling-assistant/references/problem-solving-knowledge-base.md`
  for the deterministic symptom-to-diagnostic route that data-driven ranking
  may suggest but never replace.

## External Knowledge Distillation

For user-authorized acquisition, use
[research-paper-review](../research-paper-review/SKILL.md) for source/formula
review and [knowledge-graph-creation](../knowledge-graph-creation/SKILL.md) for
alias-safe, source-linked maintenance. Retrieve the matched card from
[converter fault analysis](../simulink-modeling-assistant/references/converter-fault-analysis.md)
for converter faults; return its source ID, applicability, and local status.
These are reading/routing instructions, not a claim that the current dataset
builder or neural classifier automatically ingests the relationship table.

Use this authority order when external sources inform a modeling task:

1. locally verified model evidence;
2. official documentation, standards, and vendor model definitions;
3. maintained research repositories with tests and a primary publication;
4. community repositories, issues, and informal articles.

Levels 2-4 can propose methods, checks, or candidate parameter classes. They do
not override local operating-point qualification, modal participation,
parameter sensitivity, MIMO coupling, frequency-sweep evidence, or verification
gates. Community material remains hypothesis-only until locally reproduced.

Keep external acquisition separate from the portable library: inspect or clone
sources in a temporary research location, pin a tag or commit, review the
license, and retain only the distilled rule plus provenance. A normal clone of
this library must not require an external repository, vector database, model
binary, or historical run directory to use accepted knowledge.

## Neural Inference

Train the portable NumPy MLP with
`scripts/ml/train_failure_signature_classifier.py`. Run inference through
`scripts/ml/suggest_simulation_diagnosis.py --neural-model <model.json>
--neural-summary <summary.json>`.
Without `--neural-model`, the command deliberately uses the transparent lexical
baseline. Neural output may rank candidate routes such as modal sensitivity,
MIMO coupling, or active frequency sweep. It may also name candidate parameter
classes for tie-breaking after mathematical screening. It may not supply a
direction, step size, controller write, or tuning acceptance.

## Output

Runtime output must be machine-readable JSON shaped by the contract:

```json
{
  "status": "advisory",
  "query_id": "example",
  "candidates": [],
  "candidate_parameter_classes": [],
  "required_gates": [],
  "forbidden_actions": [],
  "next_review": "human_or_codex_review_required"
}
```

Use `status: "advisory_needs_gate"` when the candidate looks strong but the
required deterministic gate has not been run or reviewed.
