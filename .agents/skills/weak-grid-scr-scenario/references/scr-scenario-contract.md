# Weak-Grid Scenario Contract

Use this contract for SCR/ESCR and low-system-strength scenario design.

## Required Fields

Record:

- case name
- stressed bus or converter point of interconnection
- rated MVA and voltage base
- SCR or ESCR definition used
- network modification method
- scenario axes and values
- disturbance timing
- pass/fail observables
- required logs and figures
- modal or regression follow-up route

## Recommended Axes

- SCR or ESCR: `[1.0 1.2 1.5 2 3 5]` or project-specific subset.
- X/R ratio or line distance scale.
- PLL gain scale for GFL controls.
- VSG inertia/damping or virtual impedance scale for GFM controls.
- GFM share when multiple IBRs exist.
- Fault type and clearing time.
- Pre-fault dispatch and reactive-power mode.

## Observables

At minimum consider:

- terminal voltage RMS and recovery time
- active and reactive power recovery
- PLL frequency or VSG frequency
- DC-link voltage
- current limit activation
- rotor speed for DFIG/SG hybrid cases
- NaN/Inf and solver failure flags
- dominant modal damping for borderline cases

## Failure Routing

- Oscillation without immediate numerical failure: route to
  `small-signal-modal-analysis`.
- Good waveform but missing baseline evidence: route to `baseline-regression`.
- Inconsistent GFL/GFM comparison: route to `gfl-gfm-control-comparison`.
- Plant-level evidence package: route to `ibr-model-validation-evidence`.
