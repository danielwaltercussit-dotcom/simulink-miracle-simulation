---
name: gfl-gfm-control-comparison
description: Use when comparing grid-following and grid-forming inverter or DFIG/VSC control strategies in Simulink, including PLL versus VSG/droop/VSM, weak-grid behavior, fault recovery, damping, fair scenario setup, and evidence packages.
---

# GFL GFM Control Comparison

Use this skill when the question is whether GFL, GFM, PLL, VSG, droop, or VSM
control performs better for a given converter-grid study.

## Core Rule

Compare performance, not labels. A fair GFL/GFM comparison uses the same
network, dispatch, disturbance, logging, fidelity decision, tuning budget, and
acceptance metrics unless the report explicitly justifies a difference.

## Workflow

1. Use `model-fidelity-selector` to decide whether RMS, averaged EMT,
   switching EMT, modal, or hybrid evidence is needed.
2. Define baseline/candidate controllers and what parameters may be tuned.
3. Use `weak-grid-scr-scenario` for SCR/ESCR and disturbance axes.
4. Run or request paired simulations under identical scenario definitions.
5. Use `small-signal-modal-analysis` for damping and mode ownership.
6. Use `baseline-regression` and `diagnostic-plotting` for overlays and
   numeric comparisons.
7. Write a comparison report that separates observed behavior from mechanism.

## Required Fairness Checks

- same network and dispatch
- same converter rating and current limit assumptions
- same disturbance timing and clearing
- same observable list and tolerances
- same tuning policy or clearly documented tuned/untuned comparison
- same model fidelity or documented cross-fidelity reason

## Output

Write reports under:

```text
build/reports/control_comparison/<case>/
  gfl_gfm_comparison.md
  gfl_gfm_comparison.json
```

Read `references/comparison-contract.md` before changing fairness checks,
metric names, or conclusion wording.
