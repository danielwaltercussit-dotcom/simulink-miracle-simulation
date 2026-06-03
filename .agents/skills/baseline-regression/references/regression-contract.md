# Regression Contract

Use this reference when designing baseline/candidate comparisons.

## Required Metadata

Record:

- baseline model or snapshot path
- candidate model path
- scenario or spec patch
- stop time
- solver assumptions
- signal list
- tolerance policy
- generation or snapshot provenance

## Tolerance Policy

Use explicit tolerances:

- absolute tolerance for near-zero signals
- relative tolerance for scaled quantities
- time-alignment tolerance when simulations use different sample grids
- event-time tolerance for faults or recovery markers

Do not use a single percentage tolerance for all signals unless the report says
why it is physically meaningful.

## Failure Routing

- Same signal missing in candidate only: build/logging regression.
- Non-finite candidate output: verification failure.
- Candidate finite but outside tolerance: tuning, model change review, or
  scenario review depending on the signal.
- Baseline itself fails: stop and revalidate the baseline before judging the
  candidate.

## Plotting

Use `diagnostic-plotting` for overlays. Axes must be identical and tolerance
bands must be visible when pass/fail depends on them.
