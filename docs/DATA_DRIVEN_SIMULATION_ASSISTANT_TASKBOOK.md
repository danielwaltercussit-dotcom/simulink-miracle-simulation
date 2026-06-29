# Data-Driven Simulation Assistant Taskbook

Branch: `feature/data-driven-simulation-assistant`
Worktree: `C:\Users\PC\Desktop\simulink_agent_workspace\simulink_agent_v1__data_driven_assistant`
Base commit: `2846615 docs(skills): summarize ambient-masked tuning lessons`
Package id: `DATA-DRIVEN-SIMULATION-ASSISTANT`
Status: `P5_NEURAL_PROTOTYPE_READY`

## 0. Purpose

Build a project-local skill and helper pipeline that uses data-driven methods
to assist Simulink power-system modeling work.

The assistant may propose:

- similar historical cases;
- candidate failure signatures;
- candidate missing gates;
- candidate next experiments;
- dataset-quality warnings.

The assistant must not decide:

- model PASS / FAIL;
- S6 tuning authorization;
- modal identity;
- physical source identity;
- accepted tuning direction;
- whether to launch an expensive simulation.

Every output must route back to deterministic project gates such as
`current-simulation-experience.md`, `failure-signatures.md`,
`modal-contract.md`, `verification-contract.md`, or tuning/baseline contracts.

## 1. Multi-Agent Handoff Protocol

This file is the shared task state. Every agent must update it before handing
off. Do not rely on chat history as the only state.

At the start of each turn, the agent must:

1. Run `git status --short --branch`.
2. Read this taskbook.
3. Inspect the latest entry in `## 9. Agent Log`.
4. Review the previous agent's changed files before editing.
5. State which phase it will advance and which files are in scope.

At the end of each turn, the agent must:

1. Update `## 8. Status Board`.
2. Add one entry to `## 9. Agent Log`.
3. Record previous-agent review, this-turn changes, validation, blockers, and
   exact next action.
4. Keep changed files scoped to the active phase.
5. Leave local-only `.claude/` and official submodule dirt untouched.

If an agent finds earlier work wrong, it should fix the taskbook and mark the
affected phase `needs-rework` instead of silently continuing.

## 2. Non-Negotiable Boundaries

- Neural/data-driven outputs are advisory only.
- The first implementation must support a no-training baseline before any
  neural model is added.
- No helper may auto-launch MATLAB, long simulations, or S6 tuning.
- No helper may use `.slx` or `.mat` binary content directly in the dataset.
  It may reference their paths when reports already describe them.
- No generated dataset larger than a small smoke fixture should be committed.
  Commit schemas, scripts, tiny fixtures, and evaluation cases; write larger
  generated data under `build/ml/`.
- Do not edit lab archive or oracle models.
- Do not commit `.claude/settings.local.json` or submodule internal changes.

## 3. Expected Final Shape

```text
.agents/skills/data-driven-simulation-assistant/
  SKILL.md
  references/
    assistant-contract.md
    label-taxonomy.md
    dataset-schema.md
  scripts/ or project scripts under scripts/ml/

scripts/ml/
  build_simulation_experience_dataset.py
  suggest_simulation_diagnosis.py
  train_failure_signature_classifier.py
  evaluate_simulation_assistant.py

tests/
  data_driven_simulation_assistant_test.py
  fixtures/data_driven_simulation_assistant/*.jsonl

docs/
  DATA_DRIVEN_SIMULATION_ASSISTANT_TASKBOOK.md
```

The exact script locations may change if the repo has a stronger convention,
but the taskbook must be updated before changing the structure.

## 4. Output Contract

The assistant's runtime output must be machine-readable JSON:

```json
{
  "status": "advisory",
  "query_id": "example",
  "candidates": [
    {
      "label": "ambient_masked",
      "confidence": 0.82,
      "evidence_paths": ["Claude_demo/.../t1rd45_terminal_decision.md"],
      "why": "persistent line appears in null window"
    }
  ],
  "required_gates": [
    ".agents/skills/small-signal-modal-analysis/references/modal-contract.md"
  ],
  "forbidden_actions": ["S6 tuning", "modal identity confirmed"],
  "next_review": "human_or_codex_review_required"
}
```

All labels are candidate labels. A confidence score is not authorization.

## 5. Phase Plan

### P0 - Taskbook and Branch Setup

Goal: create this branch/worktree and taskbook.

Required work:

- Create dedicated branch/worktree.
- Write this taskbook.
- Verify branch status and that unrelated dirty state is excluded.

Acceptance:

- This file exists and names branch, worktree, phase plan, status board, and
  agent-log protocol.
- `git status --short --branch` in this worktree shows only intended files.

### P1 - Skill Skeleton and Contract

Goal: create the project-local skill without scripts yet.

Required work:

- Add `.agents/skills/data-driven-simulation-assistant/SKILL.md`.
- Add `references/assistant-contract.md`.
- Add `references/label-taxonomy.md`.
- Add `references/dataset-schema.md`.
- State trigger contexts clearly in frontmatter.

Required contract rules:

- Candidate-only output.
- Deterministic gates remain authoritative.
- Forbidden decisions listed explicitly.
- Output JSON schema linked.

Acceptance:

- Skill metadata validates with the same frontmatter rules used elsewhere.
- No script or skill claims it can PASS/FAIL models.
- Taskbook status and Agent Log updated.

### P2 - Dataset Schema and Builder v0

Goal: build a small, deterministic dataset extractor from existing reports.

Required work:

- Implement `scripts/ml/build_simulation_experience_dataset.py`.
- Inputs: repo root, output path, optional include/exclude globs.
- Scan text reports only: `.md`, `.json`, `.txt`, `.log`.
- Ignore binary files and generated heavy artifacts.
- Extract records with stable fields:
  `record_id`, `source_path`, `source_kind`, `case_family`, `stage`,
  `text_summary`, `labels`, `metrics`, `evidence_paths`, `required_gates`.
- Write JSONL to `build/ml/simulation_experience_dataset.jsonl` by default.

Seed label hints:

- `ambient_masked`
- `modal_identity_unproven`
- `memory_unbounded`
- `operating_point_unqualified`
- `degenerate_time_axis`
- `physical_injection_observability_split`
- `validator_hardcoded_runid`
- `layout_structure_drift`
- `control_feedback_polarity_mismatch`

Acceptance:

- A tiny committed fixture under `tests/fixtures/...` proves schema shape.
- The real builder can run without MATLAB.
- The generated large dataset stays untracked under `build/ml/`.

### P3 - Retrieval Baseline

Goal: provide useful assistance before any neural model.

Required work:

- Implement `scripts/ml/suggest_simulation_diagnosis.py`.
- Use transparent lexical scoring first: BM25-like token overlap, keyword
  weights, or another deterministic baseline.
- Given a query report/path/text, return top similar records, candidate labels,
  required gates, and forbidden actions.

Acceptance:

- At least five regression fixtures:
  ambient-masked line, frequency coincidence, memory-unbounded run,
  degenerate time axis, control polarity mismatch.
- Each fixture returns the expected candidate label in top candidates.
- Each fixture routes back to deterministic gates.
- No fixture emits S6 authorization or model PASS.

### P4 - Evaluation Harness

Goal: make accuracy and safety measurable before training.

Required work:

- Implement `scripts/ml/evaluate_simulation_assistant.py`.
- Define test cases with expected labels, forbidden labels/actions, and required
  gate mentions.
- Report:
  `top1_label_hit`, `top3_label_hit`, `forbidden_action_violations`,
  `missing_gate_violations`, `evidence_path_coverage`.

Acceptance:

- Evaluation can run offline with committed fixtures.
- Any forbidden-action violation fails the test.
- The report is written to `build/reports/ml/assistant_eval_summary.md/json`.

### P5 - Neural Classifier Prototype

Goal: add a small neural model only after P3/P4 are passing.

Required work:

- Implement `scripts/ml/train_failure_signature_classifier.py`.
- Use a small embedding/classifier pipeline, not a black-box end-to-end
  decision engine.
- Training data comes from JSONL records and explicit labels.
- Save model artifacts under `build/ml/models/` by default; do not commit large
  artifacts.
- The predictor must still emit advisory JSON and deterministic gates.

Acceptance:

- Neural classifier is compared against P3 retrieval baseline.
- It improves recall or confidence calibration on at least one useful class
  without introducing forbidden-action violations.
- If it does not beat the baseline, keep it experimental and do not route it
  from the skill.

### P6 - Experiment Point Suggestion

Goal: suggest next evidence-gathering experiments without auto-launching them.

Required work:

- Add an optional suggestion mode.
- Prefer transparent methods first: random forest, Gaussian process, Bayesian
  optimization, or rule-based budget planner.
- Inputs: candidate label, current evidence gaps, max runtime budget, forbidden
  actions.
- Output: proposed experiment contract, expected evidence, resource budget, and
  stop conditions.

Acceptance:

- For ambient-masked damping, it suggests authority-gated source isolation or
  stronger evidence separation, not repeated same-amplitude ringdown.
- For memory-unbounded runs, it suggests bounded probes and PID/slope gates.
- For modal-identity uncertainty, it suggests sensitivity/participation/source
  disable evidence, not tuning.

### P7 - Integration With Existing Skills

Goal: make existing skills know when to call this assistant without handing it
authority.

Required work:

- Add short routing notes to relevant skills:
  `simulink-modeling-assistant`, `ai-in-loop`,
  `small-signal-modal-analysis`, `power-electronics-tuning`,
  `baseline-regression`.
- Each note must say: use for candidate retrieval only; deterministic gate owns
  final decision.

Acceptance:

- Existing PASS/FAIL/S6 wording remains deterministic.
- No existing skill says the assistant can authorize tuning or validation.

### P8 - Review, Commit, and Publish

Goal: prepare a coherent PR-ready branch.

Required work:

- Run all Python tests.
- Run schema/retrieval/evaluation smoke tests.
- Run `git diff --check`.
- Run staged secret scan.
- Commit focused phases.
- Push branch to `origin` when user asks or when a publish checkpoint is needed.

Acceptance:

- Branch contains only main-repo tracked project files.
- `.claude/` and official submodule dirt remain uncommitted unless explicitly
  authorized.

## 6. Review Checklist For Every Phase

Before accepting prior agent work, verify:

- Does it preserve advisory-only semantics?
- Does it name required deterministic gates?
- Does it avoid S6/PASS/modal-identity authority?
- Are generated data and model artifacts kept out of git?
- Are fixture cases small and readable?
- Does the status board match actual files?
- Does Agent Log say what the previous round changed and how it was reviewed?

## 7. Validation Command Index

Use these commands as they become available:

```powershell
git status --short --branch
git diff --check
rg -n "S6 authorized|PASS|modal identity confirmed" .agents/skills/data-driven-simulation-assistant scripts/ml tests/fixtures
```

Future commands to add when scripts exist:

```powershell
python scripts/ml/build_simulation_experience_dataset.py --help
python scripts/ml/suggest_simulation_diagnosis.py --fixture tests/fixtures/data_driven_simulation_assistant/ambient_masked.json
python scripts/ml/evaluate_simulation_assistant.py --fixtures tests/fixtures/data_driven_simulation_assistant
python scripts/ml/train_failure_signature_classifier.py --dataset tests/fixtures/data_driven_simulation_assistant/dataset.jsonl --fixtures tests/fixtures/data_driven_simulation_assistant
python tests/data_driven_simulation_assistant_test.py
```

On this Windows host, system Python may be missing. Use the Codex runtime Python
from `codex_app.load_workspace_dependencies` when needed.

## 8. Status Board

| Phase | Status | Owner | Last changed files | Validation | Next action |
|---|---|---|---|---|---|
| P0 Taskbook/setup | completed | Codex | `docs/DATA_DRIVEN_SIMULATION_ASSISTANT_TASKBOOK.md` | `git diff --check` PASS; structure check PASS | Start P1 skill skeleton |
| P1 Skill skeleton | completed | Codex | `.agents/skills/data-driven-simulation-assistant/SKILL.md`; `.agents/skills/data-driven-simulation-assistant/references/assistant-contract.md`; `.agents/skills/data-driven-simulation-assistant/references/label-taxonomy.md`; `.agents/skills/data-driven-simulation-assistant/references/dataset-schema.md`; `docs/DATA_DRIVEN_SIMULATION_ASSISTANT_TASKBOOK.md` | `git diff --check` PASS; frontmatter validation PASS; JSON examples parse; authority scan reviewed | Start P2 dataset builder |
| P2 Dataset builder | completed | Codex | `scripts/ml/build_simulation_experience_dataset.py`; `scripts/ml/simulation_assistant_lib.py`; `tests/fixtures/data_driven_simulation_assistant/dataset.jsonl`; `tests/data_driven_simulation_assistant_test.py` | builder help PASS; real builder wrote 15 labeled records under ignored `build/ml/`; schema unittest PASS | Start P5 only after reviewing P3/P4 metrics |
| P3 Retrieval baseline | completed | Codex | `scripts/ml/suggest_simulation_diagnosis.py`; `scripts/ml/simulation_assistant_lib.py`; `tests/fixtures/data_driven_simulation_assistant/*.json` | five fixtures top1/top3 PASS; forbidden phrase scan over scripts/fixtures clean | Feed P4 evaluation metrics |
| P4 Evaluation harness | completed | Codex | `scripts/ml/evaluate_simulation_assistant.py`; `tests/data_driven_simulation_assistant_test.py`; `tests/fixtures/data_driven_simulation_assistant/*.json` | offline evaluation PASS: top1=1.0, top3=1.0, forbidden_action_violations=0, missing_gate_violations=0; unittest PASS | Plan P5 CPU-friendly prototype |
| P5 Neural prototype | completed | Codex | `scripts/ml/train_failure_signature_classifier.py`; `tests/data_driven_simulation_assistant_test.py`; `docs/DATA_DRIVEN_SIMULATION_ASSISTANT_TASKBOOK.md` | CPU NumPy MLP PASS: loss 1.155387 -> 0.001763; baseline top3=1.0; classifier top3=1.0; confidence_gain_cases=5; forbidden_action_violations=0; missing_gate_violations=0; artifacts ignored under `build/ml/models/` | Start P6 experiment suggestion planner |
| P6 Experiment suggestion | pending | unassigned | none | none | Add advisory planner |
| P7 Skill integration | pending | unassigned | none | none | Add routing notes |
| P8 Publish | pending | unassigned | none | none | Validate, commit, push when ready |

Status vocabulary:
`pending`, `in-progress`, `needs-review`, `needs-rework`, `blocked`,
`completed`.

## 9. Agent Log

### 2026-06-29 Codex P0

- Previous-agent review: created this branch from clean commit `2846615`; did
  not carry dirty changes from primary worktree.
- This-turn changes: created the initial taskbook for the data-driven
  simulation assistant, including phase plan, handoff protocol, boundaries,
  status board, and validation index.
- Files changed: `docs/DATA_DRIVEN_SIMULATION_ASSISTANT_TASKBOOK.md`.
- Validation: `git diff --check` PASS; structure check confirmed required
  sections for status board, Agent Log, previous-agent review, previous-round
  change tracking, and deterministic-gate boundaries.
- Next action: implement P1 skill skeleton and update this taskbook before
  handoff.

### 2026-06-29 Codex P1

- Previous-agent review: reviewed `ad31603` and the P0 Agent Log; confirmed the
  dedicated branch/worktree excludes primary-worktree dirty skill and `.claude/`
  state.
- This-turn changes: created the project-local data-driven simulation assistant
  skill skeleton and three reference contracts for advisory behavior, label
  taxonomy, and dataset schema.
- Previous round changed: P0 created the branch taskbook and handoff protocol;
  confirmed and kept that structure unchanged except for P1 status updates.
- Files changed: `.agents/skills/data-driven-simulation-assistant/SKILL.md`;
  `.agents/skills/data-driven-simulation-assistant/references/assistant-contract.md`;
  `.agents/skills/data-driven-simulation-assistant/references/label-taxonomy.md`;
  `.agents/skills/data-driven-simulation-assistant/references/dataset-schema.md`;
  `docs/DATA_DRIVEN_SIMULATION_ASSISTANT_TASKBOOK.md`.
- Validation: `git diff --check` PASS; project-local skill frontmatter
  validation PASS; advisory JSON examples parsed with `ConvertFrom-Json`;
  authority scan found only forbidden/routing/candidate-only wording.
- Blockers/risks: no scripts or neural model implemented yet; P2 must add a
  deterministic no-training dataset builder before any neural prototype.
- Next action: implement P2 dataset schema enforcement and text-only builder.

### 2026-06-29 Codex P2-P4

- Previous-agent review: reviewed P1 commit `87b6549`, the skill skeleton, and
  all three reference contracts; accepted the advisory-only boundary and kept
  deterministic gate ownership intact.
- This-turn changes: implemented the text-only dataset builder, transparent
  lexical retrieval baseline, offline evaluation harness, shared helper library,
  five regression fixtures, one schema fixture dataset, and a direct unittest
  smoke suite.
- Previous round changed: P1 created the project-local skill contract and
  marked P2 as the next action; confirmed and advanced only P2-P4 files.
- Files changed: `scripts/ml/simulation_assistant_lib.py`;
  `scripts/ml/build_simulation_experience_dataset.py`;
  `scripts/ml/suggest_simulation_diagnosis.py`;
  `scripts/ml/evaluate_simulation_assistant.py`;
  `tests/data_driven_simulation_assistant_test.py`;
  `tests/fixtures/data_driven_simulation_assistant/dataset.jsonl`;
  `tests/fixtures/data_driven_simulation_assistant/*.json`;
  `docs/DATA_DRIVEN_SIMULATION_ASSISTANT_TASKBOOK.md`.
- Validation: Codex runtime Python ran builder help; real builder wrote 15
  labeled records to ignored `build/ml/simulation_experience_dataset.jsonl`;
  fixture evaluation passed with top1=1.0, top3=1.0,
  forbidden_action_violations=0, missing_gate_violations=0,
  evidence_path_coverage=1.0; direct unittest passed 4 tests; forbidden phrase
  scan over `scripts/ml` and committed fixtures had no matches.
- Blockers/risks: retrieval is intentionally lexical and small-fixture backed;
  P5 must compare any neural prototype against this baseline and keep it
  experimental if it does not improve useful recall or calibration.
- Next action: implement P5 as a CPU-friendly small embedding/classifier
  prototype under `scripts/ml/train_failure_signature_classifier.py`.

### 2026-06-29 Codex P5

- Previous-agent review: reviewed P2-P4 commit `f0efdc3`, the dataset schema,
  retrieval baseline, evaluation harness, and fixture metrics; accepted that
  P3/P4 were passing before training.
- This-turn changes: added a CPU-friendly NumPy hashed bag-of-words plus
  one-hidden-layer MLP classifier prototype; it trains from JSONL explicit
  labels, emits advisory JSON with deterministic gates, saves ignored artifacts
  under `build/ml/models/`, and compares itself against the P3 retrieval
  baseline.
- Previous round changed: P2-P4 established the no-training baseline and
  offline safety metrics; confirmed and used those fixtures unchanged.
- Files changed: `scripts/ml/train_failure_signature_classifier.py`;
  `tests/data_driven_simulation_assistant_test.py`;
  `docs/DATA_DRIVEN_SIMULATION_ASSISTANT_TASKBOOK.md`.
- Validation: Codex runtime Python trained the prototype with loss 1.155387 ->
  0.001763; baseline top1/top3=1.0/1.0; classifier top1/top3=1.0/1.0;
  confidence_gain_cases=5; forbidden_action_violations=0;
  missing_gate_violations=0; direct unittest passed 5 tests.
- Blockers/risks: fixture set is intentionally tiny, so the classifier is
  eligible for P7 review but is not auto-routed from the skill; any production
  route still needs broader fixtures and human/Codex review.
- Next action: implement P6 experiment-point suggestion without auto-launching
  simulations.

### Template For Future Agent Entries

```text
### YYYY-MM-DD <agent/name> <phase>

- Previous-agent review: <what files/status/logs were reviewed and verdict>.
- This-turn changes: <short exact summary>.
- Previous round changed: <what the prior entry claimed changed, confirmed or corrected>.
- Files changed: <paths>.
- Validation: <commands and results, or why skipped>.
- Blockers/risks: <none or exact issue>.
- Next action: <one concrete task for next agent>.
```
