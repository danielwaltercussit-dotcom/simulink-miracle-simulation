---
name: ibr-model-validation-evidence
description: Use when preparing or auditing inverter-based resource model validation evidence for Simulink plant models, including EMT/RMS cross-checks, low-SCR behavior, fault ride-through, plant controller response, parameter provenance, and handoff-ready model credibility packages.
---

# IBR Model Validation Evidence

Use this skill when a generated or donor-derived IBR model must be credible
enough for study handoff, not merely runnable inside the current workspace.

## Core Rule

Validation evidence must tie model behavior to a purpose, a fidelity choice,
parameter provenance, and disturbance coverage. A passing smoke simulation is
not a plant-model validation package.

## Workflow

1. Use `model-fidelity-selector` to record the model type and limits.
2. Record model provenance: source model, spec, adapter, parameter script, and
   controller setting source.
3. Require at least one small disturbance and one large disturbance case when
   claiming plant-level dynamic credibility.
4. Require low-SCR or weak-grid evidence when the model is used for IBR-heavy
   or weak-grid studies.
5. Cross-check RMS/phasor/average/switching levels when the claim depends on
   model reduction.
6. Use `snapshot-auditor` before treating copied AI summary packages as
   reusable evidence.

## Evidence Types

- source and parameter provenance
- fidelity decision
- initialization and load-flow consistency
- small disturbance response
- large disturbance / fault recovery
- low-SCR or ESCR stress result
- GFL/GFM comparison when controller choice is a study variable
- modal or damping evidence for oscillation-sensitive cases
- regression against a golden run or higher-fidelity model
- known limitations and non-covered operating ranges

## Helper

Use the project helper to create a fillable evidence checklist:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/verification")
e = write_ibr_validation_evidence_plan( ...
    "CaseName","nebus39_dfig2_weakgrid_v0", ...
    "ModelPath","build/generated_models/nebus39_dfig2_weakgrid_v0.slx", ...
    "FidelityDecision","build/reports/fidelity/nebus39_fidelity_decision.md", ...
    "SnapshotPath",fullfile(getenv("USERPROFILE"),"Desktop", ...
      "AI summary of simulation models","nebus39_dfig2_weakgrid_v0"));
```

## Output

Write evidence packages under:

```text
build/reports/validation/<case>/
  ibr_validation_evidence.md
  ibr_validation_evidence.json
```

Read `references/evidence-contract.md` before changing required evidence,
warning policy, or handoff language.
