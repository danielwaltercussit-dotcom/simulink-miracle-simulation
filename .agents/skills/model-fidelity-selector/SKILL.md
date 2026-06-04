---
name: model-fidelity-selector
description: Use when choosing the appropriate Simulink, Simscape Electrical, RMS/phasor, EMT, switching, averaged, small-signal, impedance, or hybrid model fidelity for converter-dominated power-system studies in simulink_agent_v1 before building or validating a model.
---

# Model Fidelity Selector

Use this skill before building or judging a complex power-electronics dominated
power-system model when the requested study may need a different fidelity than
the current donor model.

## Core Rule

Pick fidelity from the study question, not from the easiest available block.
A valid answer records what dynamics are included, what dynamics are excluded,
and why that exclusion is acceptable for the decision being made.

## Workflow

1. Classify the study objective: steady-state, electromechanical, converter
   control, fault recovery, protection, harmonic/resonance, or model validation.
2. Identify required time scales and observables.
3. Choose the lowest fidelity that still preserves the decisive dynamics.
4. Declare the forbidden shortcuts for this study.
5. Route the build, simulation, and validation work to the matching skills.
6. Write a fidelity decision note before accepting model results.

## Fidelity Families

- **Positive-sequence / RMS**: electromechanical dynamics, large system scans,
  plant-level response when unbalance, switching, and fast controls are not the
  decision variable.
- **Dynamic phasor / per-phase phasor**: distribution or weak-grid studies that
  need faster-than-RMS behavior, phase detail, or unbalanced fault structure
  without full switching EMT cost.
- **Averaged EMT**: converter controls, PLL/VSG behavior, DC-link recovery, weak
  grid interaction, and fair GFL/GFM comparisons without carrier switching.
- **Switching EMT**: protection, harmonic, detailed current limiting, modulation,
  semiconductor or sub-cycle waveform questions.
- **Small-signal / modal / impedance**: oscillation mechanism, damping, mode
  ownership, participation, gain sensitivity, and controller interaction.
- **Hybrid**: use when one subsystem needs high fidelity and the surrounding
  network can be represented at lower fidelity.

## Routing

- Use `simulink-modeling-assistant` after this skill selects a build path.
- Use `small-signal-modal-analysis` for mode and damping questions.
- Use `weak-grid-scr-scenario` for SCR/ESCR and low-system-strength sweeps.
- Use `gfl-gfm-control-comparison` when comparing control philosophies.
- Use `ibr-model-validation-evidence` before declaring a plant/model package
  ready for external study use.
- Use `baseline-regression` when a lower-fidelity candidate is being checked
  against a higher-fidelity or golden run.

## Helper

Use the project helper when a decision note is needed:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
d = write_model_fidelity_decision( ...
    "CaseName","dfig_w33_weak_grid", ...
    "StudyObjective","PLL damping under low SCR", ...
    "Fidelity","averaged_emt_plus_modal", ...
    "DecisiveDynamics",["PLL","DC-link","current limit"], ...
    "ValidationRoute",["weak-grid-scr-scenario","small-signal-modal-analysis"]);
```

## Output

Write the decision under:

```text
build/reports/fidelity/<case>_fidelity_decision.md
build/reports/fidelity/<case>_fidelity_decision.json
```

Read `references/fidelity-contract.md` before changing the decision schema,
fidelity labels, or pass/fail wording.
