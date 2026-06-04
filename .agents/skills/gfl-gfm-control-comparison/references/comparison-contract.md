# GFL/GFM Comparison Contract

Use this contract when writing a control-strategy comparison.

## Required Metadata

Record:

- compared models or controller variants
- network and dispatch assumptions
- converter rating and limits
- selected model fidelity
- scenario matrix source
- tuning policy
- signals and tolerances
- modal-analysis source if used
- baseline/candidate artifact paths

## Metrics

Use only metrics relevant to the study:

- voltage nadir and recovery time
- frequency nadir, RoCoF, or PLL/VSG frequency error
- active/reactive power settling
- DC-link deviation and recovery
- current limit duration
- damping ratio and mode frequency
- failure rate over the SCR/fault matrix
- solver and non-finite output flags

## Conclusion Policy

- Do not conclude "GFM is better" or "GFL is worse" without naming the tested
  operating range.
- Separate tuning quality from control architecture.
- If the decisive difference appears only at very low SCR, state the SCR range.
- If modal evidence and time-domain evidence disagree, mark the result
  provisional and request an additional scenario.

## Failure Routing

- Missing paired scenario: route to `weak-grid-scr-scenario`.
- Missing damping explanation: route to `small-signal-modal-analysis`.
- Missing plots: route to `diagnostic-plotting`.
- External handoff needed: route to `ibr-model-validation-evidence`.
