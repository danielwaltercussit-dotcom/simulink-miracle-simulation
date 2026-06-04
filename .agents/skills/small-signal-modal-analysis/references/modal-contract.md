# Modal Analysis Contract

Use this contract when generating or reviewing small-signal evidence.

## Required Metadata

Record:

- case name and source model/script
- operating point source
- parameter set hash or named script
- matrix source (`jacobian`, `linearize`, exported state-space, or manual)
- state order and state-name source
- eigenvalue units
- damping threshold
- related time-domain run or required follow-up run

## Metrics

For each reported mode include:

- real part
- imaginary part
- damped frequency in Hz
- natural frequency in Hz
- damping ratio
- stability label
- top participating states if available
- likely time-scale bucket

## State Groups

Use physical names when possible:

- PLL angle / PLL integrator
- VSG or droop frequency state
- current controller integrator
- voltage controller integrator
- DC-link or MMC capacitor state
- DFIG rotor speed or mechanical state
- SG rotor angle or speed
- network inductor/capacitor state
- unknown/unlabeled state

## Interpretation Rules

- A negative real part is not enough; low damping can still be unacceptable.
- A mode near the electromechanical band can still involve converter states.
- Do not assign root cause from frequency alone; use participation and
  time-domain validation.
- If the linearization point is not documented, the analysis is provisional.

## Failure Routing

- Missing state names: report reduced confidence and request state mapping.
- Unstable mode: route to `power-electronics-tuning`, `weak-grid-scr-scenario`,
  or build-structure review depending on participating states.
- Low damping under low SCR: route to `weak-grid-scr-scenario`.
- GFL/GFM comparison: route to `gfl-gfm-control-comparison` after computing
  comparable modal summaries.
