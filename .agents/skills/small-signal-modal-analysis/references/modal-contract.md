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

## Ambient-Masked Ringdown (reviewed 2026-06-23, T1RD45)

- A spectral line already present in a pre-injection/null window is AMBIENT; a
  ringdown dominated by it carries no damping info. Require the free-decay
  envelope to fall (late/early RMS << 1) AND start above the ambient floor before
  fitting zeta. Near-zero zeta from a flat envelope is an artifact, not low
  damping; estimator disagreement is UNRESOLVED, never "stable".
- Keep Prony/Hilbert/AR separate with reject reasons; AR is for frequency, not
  damping magnitude in short/heavy windows. Report identifiability explicitly
  (cycles, e-folds at threshold, log-envelope separation vs noise) or return
  unidentifiable. Local evidence: Claude_demo/.../reports/control/t1rd45_terminal_decision.md.

## Modal Identity Requires More Than Frequency (reviewed 2026-06-24, T1AMBSRC Tier-1)

- Near-frequency coincidence is NOT physical modal identity. A torsional hand-
  estimate at 1.566 Hz coinciding with a dlinmod mode at 1.561 Hz did NOT make them
  the same mode.
- A shaft/torsional claim requires PARAMETER SENSITIVITY (e.g. f ~ sqrt(Ksh)) or
  named-state participation — not frequency proximity. The 1.561 Hz mode was shaft-
  INSENSITIVE (Ksh ±10% left it within ±0.3%, non-monotonic), so the mechanical
  classification was rejected.
- Local evidence: Claude_demo/.../reports/control/t1ambsrc_tier1/tier1_shaft_sensitivity.md
  and .../t1s6_closure/s6_closure_decision.md.
