# Hybrid Solver / Multirate Simulation Contract

Use this contract when generating or reviewing a solver and multirate step plan
for cross-time-scale, converter-dominated Simulink models. The plan is a
justification artifact, not a model rewrite.

## Required Plan Metadata

Record at the plan level:

- case name and source model/script
- simulation stop time (`stop_time_s`)
- fastest event to resolve, in Hz (`fastest_event_hz`): PWM carrier, switching
  edge rate, fault inception sampling need, or highest control-loop bandwidth
- slowest mode to capture, in Hz (`slowest_mode_hz`): electromechanical swing,
  inter-area oscillation, or slowest control/outer-loop dynamic
- global strategy: `multi_solver` (per-partition), `single_fixed_step`
  (real-time / HIL bound), or `single_variable_step`
- whether the plan was `verified_against_model` (an actual load/update/simulate
  result was supplied) or is plan-only

If `fastest_event_hz` or `slowest_mode_hz` is missing or non-positive, the plan
is `provisional` and must not back a validated cross-time-scale claim.

## Required Per-Partition Metadata

For each partition record:

- `name` and physical time scale (switching/EMT, control/average,
  electromechanical/grid)
- `solver`: a Simulink solver name (e.g. `ode23tb`, `ode15s`, `ode45`,
  `discrete`) or `FixedStepDiscrete`
- `step_kind`: `fixed` or `variable`
- `step_s`: the fundamental/fixed sample time for a fixed-step partition
- `max_step_s`: the max step for a variable-step partition
- `algebraic_loop`: `none`, `solved`, `unit_delay`, `memory`, or
  `solver_iterated`

## Step Heuristics (screening defaults)

The anchor checks are enforced **globally** across partitions, because the point
of a multirate plan is that slow partitions legitimately take coarse steps:

- Fastest event vs the **finest** step across all partitions:
  `1 / (fastest_event_hz * finest_step) >= 10`. Only the finest partition has to
  resolve the fastest event. Below 10 -> **failure**.
- Slowest mode vs the **coarsest** step across all partitions:
  `1 / (slowest_mode_hz * coarsest_step) >= 20`. If even the coarsest step
  over-samples the slow mode this passes. Below 20 -> **warning** (the slow mode
  is poorly captured; fast phenomena may still be valid).
- Step ratio between adjacent fixed rates should be a small integer (2, 5, 10,
  20). A non-integer ratio forces rate-transition interpolation -> **warning**.
- Every fixed `step_s` must be `> 0`, `< stop_time_s`, and large enough to be
  representable; a step `>= stop_time_s` or `<= 0` -> **failure**.
- Stiffness ratio = slowest time constant / fastest time constant
  = `fastest_event_hz / slowest_mode_hz`. A ratio above ~1e4 inside one
  continuous partition argues for a stiff solver or a partition split ->
  **warning** when a non-stiff continuous solver is used across that ratio.

Each partition also reports its own `samples_per_fastest` and
`samples_per_slowest` for inspection, but those per-partition numbers are
**diagnostic only** and do not by themselves fail the plan.

## Failure vs Warning vs Provisional

- `failure`: an impossible or unresolvable choice — step out of `(0, stop_time)`,
  micro step too coarse for the fastest event, or an unbroken algebraic loop on a
  discrete/rate-transition partition. A plan with any failure has
  `status = "fail"`.
- `warning`: an admissible-but-risky choice — under-sampled slow mode,
  non-integer rate ratio, high stiffness ratio under a non-stiff solver. Warnings
  do not by themselves fail the plan.
- `provisional`: a required anchor (fastest event or slowest mode) or a partition
  solver/step field is undocumented. A provisional plan cannot be `pass`; it is
  reported as `provisional` until the anchor is supplied.
- `pass`: all required metadata documented and no failures.

## Algebraic Loops And Rate Transitions

- An algebraic loop crossing a rate transition or sitting on a discrete partition
  must be broken (`unit_delay` / `memory`) or `solved` analytically. Leaving it
  `solver_iterated` across a rate boundary is a **failure** because the iteration
  is not well defined across sample times.
- Continuous-to-discrete boundaries require an explicit sample time and a
  zero-order-hold or rate-transition block. Record the transition determinism:
  data-integrity-only vs data-integrity-and-determinism.

## Interpretation Rules

- A passing plan means the step/solver choices are *self-consistent and
  admissible against the supplied anchors*. It does not prove the model is
  numerically converged; only a real run with error/step diagnostics does that.
- Heuristic thresholds (10 / 20 samples, 1e4 stiffness, integer ratios) are
  screening values. A documented expert override is recorded in the plan, not
  silently accepted; the override still surfaces the original warning.
- `verified_against_model` may be set true only when an actual load/update/
  simulate result is attached. Plan-only evidence must never claim model
  verification.
- Do not convert a large or private model to multirate form to satisfy this
  plan. Use a small runnable example or synthetic anchors.

## Relation To Other Evidence

- Fidelity: `model-fidelity-selector` decides per-subsystem fidelity; this plan
  consumes that decision and assigns solvers/steps to the chosen fidelities.
- Modal: `small-signal-modal-analysis` supplies `slowest_mode_hz`; an impedance
  resonance from `impedance-frequency-analysis` can tighten `fastest_event_hz`.
- HIL: a `single_fixed_step` strategy routes to `hil-readiness-real-time-prep`
  for code-gen and latency feasibility; this plan only checks step admissibility.
- Profiling: after a run, `simulink-solver-profiler-analyzer` supplies measured
  step counts that can confirm or revise the planned steps.

## Failure Routing

- Undocumented anchors: report `provisional` and request fastest event / slowest
  mode before any cross-time-scale claim.
- Micro step too coarse: tighten the micro step or raise partition fidelity; do
  not relax the 10-samples rule without a recorded rationale.
- High stiffness under a non-stiff solver: switch to a stiff variable-step solver
  or split the continuous partition.
- Non-integer rate ratio: re-grid the discrete rates to an integer ratio or
  document the interpolation cost explicitly.
- Algebraic loop across a rate transition: break it with a unit delay / Memory
  block and record the added sample-time delay.
