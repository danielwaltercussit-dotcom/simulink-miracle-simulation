---
name: weak-grid-scr-scenario
description: Use when designing, generating, or reviewing weak-grid, SCR, ESCR, line-strength, low short-circuit capacity, PLL sensitivity, fault recovery, and contingency scenario matrices for Simulink converter-dominated power-system models.
---

# Weak-Grid SCR Scenario

Use this skill when a model must be tested under low system strength, changing
line impedance, contingencies, or SCR/ESCR stress instead of a single nominal
fault.

## Core Rule

Weak-grid evidence is a matrix, not a single run. Record the system-strength
axis, control-setting axis, disturbance axis, and observable axis before
accepting pass/fail conclusions.

## Workflow

1. Identify the converter bus, rated MVA, and network equivalent being stressed.
2. Choose SCR or ESCR values and the method used to realize them.
3. Add control sensitivity axes only when needed: PLL gain scale, VSG inertia,
   damping, virtual impedance, current limit, or GFM share.
4. Add disturbance axes: balanced/unbalanced fault, line opening, load step,
   wind/power step, voltage sag, or recovery time.
5. Declare pass/fail observables before running the matrix.
6. Route low-damping or unstable cases to `small-signal-modal-analysis` and
   plots to `diagnostic-plotting`.

## Helper

Use the matrix generator for planning artifacts:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/scenarios")
m = generate_weak_grid_scr_matrix("CaseName","dfig_w33_scr_scan", ...
    "ScrValues",[1.2 1.5 2 3 5], ...
    "PllGainScales",[0.5 1 1.5], ...
    "FaultTypes",["none","three_phase","single_line_ground"]);
```

## Output

Write scenario plans under:

```text
build/reports/scenarios/<case>_weak_grid_matrix.md
build/reports/scenarios/<case>_weak_grid_matrix.json
```

Read `references/scr-scenario-contract.md` before changing scenario axes,
field names, or acceptance wording.
