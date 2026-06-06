---
name: hybrid-solver-multirate-simulation
description: Use when choosing or reviewing solver and multirate settings for cross-time-scale Simulink power-electronics simulations where microsecond converter switching and slow electromechanical/grid dynamics must coexist. Covers stiffness detection, fixed vs variable step, local solver boundaries, discrete step sizing, rate-transition policy, algebraic-loop handling, and numerical-stability warnings. Produces a contract-checked solver plan, not a model conversion.
---

# Hybrid Solver / Multirate Simulation

Use this skill when a converter-dominated power-system model spans more than one
time scale and the solver/step configuration has to be justified before a run is
trusted: detailed switching (microseconds) feeding average/RMS converter control
(sub-millisecond to milliseconds) feeding electromechanical and grid dynamics
(tens of milliseconds to seconds).

The deliverable is a **solver plan with an evidence contract**, not an automatic
model rewrite. The plan states which solver runs which partition, at which step,
and why those steps are admissible given the fastest event and the slowest mode.

## Core Rule

A multirate solver plan is admissible evidence only when every step size is
justified against two anchors that the caller must supply:

- the **fastest event** that must be resolved (e.g. PWM carrier period, switching
  edge, fault inception, the highest control-loop bandwidth), and
- the **slowest mode** that must be captured over the run horizon (e.g. an
  electromechanical swing or inter-area oscillation period).

If either anchor is undocumented, the plan is `provisional` and must not be used
to claim a validated cross-time-scale result. A step size that cannot resolve its
partition's fastest event (too coarse) or that is larger than the simulation stop
time / smaller than solver precision (impossible) is a contract failure, not a
warning. See `references/multirate-solver-contract.md`.

## When To Use vs Other Skills

- Use `model-fidelity-selector` first to decide *which fidelity* each subsystem
  needs (switching vs average vs phasor). This skill assumes that decision is
  made and answers *how to time-step and solve* the resulting mixed model.
- Use `simulink-solver-profiler-analyzer` / `simulink-profiler-analyzer` when you
  already have a running model and want measured step/solver cost. This skill is
  the up-front plan and admissibility check before or between those runs.
- Use `small-signal-modal-analysis` to obtain the slowest-mode frequency that
  anchors the macro step, and `impedance-frequency-analysis` for fast resonance
  bands that constrain the micro step. Both feed anchors into this plan.

## Workflow

1. Identify partitions and their time scales: switching/EMT, control/average,
   electromechanical/grid. Record the fastest event and slowest mode in Hz or
   seconds. Undocumented anchors -> `provisional`.
2. Choose a solver strategy per partition: variable-step stiff (e.g. ode23tb /
   ode15s) for continuous EMT with stiffness, fixed-step discrete for control
   and code-gen-bound partitions, or a single global fixed step when the model
   targets real-time / HIL (hand off to `hil-readiness-real-time-prep`).
3. Size each discrete step: the micro step must resolve the fastest event with
   enough samples (default >= 10 samples per fastest period / carrier); the
   macro step must over-sample the slowest mode (default >= 20 samples per slow
   period) while staying integer-ratio-compatible with the micro step at rate
   transitions.
4. Set the rate-transition policy explicitly: deterministic vs nondeterministic,
   data-integrity-only vs data-integrity-and-determinism, and whether transitions
   are auto-inserted or manual. Mixed continuous/discrete boundaries need a
   stated sample-time and a zero-order-hold or rate-transition block.
5. Declare algebraic-loop handling: none, solved analytically, broken with a
   unit delay / Memory block (and the sample-time cost), or left to the solver
   (record the iteration tolerance). An unbroken algebraic loop across a rate
   transition is a contract failure.
6. Emit numerical-stability warnings: stiffness ratio, step-ratio between
   partitions, sample-rate non-integer ratios, and any step that violates the
   fastest-event or slowest-mode anchor.
7. Confirm with a run only when a small runnable example exists. Do not convert a
   large or private model to multirate form to satisfy this plan.

## Stiffness And Step Heuristics

These are screening defaults, not solver guarantees:

- Stiffness ratio = slowest time constant / fastest time constant. A ratio above
  ~1e4 across a single continuous partition argues for a stiff variable-step
  solver or for splitting the partition.
- Samples per fastest period: >= 10 to resolve a switching carrier or fast
  control loop; >= 20 preferred near a flagged resonance.
- Step ratio between adjacent rates should be a small integer (2, 5, 10, 20).
  Non-integer ratios force interpolation at rate transitions and are flagged.
- Fixed step must divide the simulation stop time and any sample time it feeds.

The helper applies these as warnings/failures; a domain expert may override with
a documented rationale, which the contract records rather than silently accepts.

## Lab References

Treat the desktop lab archive as read-only ground truth. Multirate-relevant:

- Models that already mix detailed switching converters with electromechanical
  or grid dynamics: read their solver type, fixed step, and rate-transition
  choices as reference values, never as files to edit.
- Use lab step sizes and switching/control frequencies as realistic anchors for
  a synthetic plan. Use `lab-model-pattern-miner` only when checking the archive.

Do not restore or copy any private model (including NEBUS39V2.slx) into the repo.

## Helper

Use the project helper when you have a candidate solver plan to check:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
plan = struct( ...
    "case_name", "vsc_weakgrid_hybrid", ...
    "stop_time_s", 2.0, ...
    "fastest_event_hz", 10e3, ...   % 10 kHz PWM carrier
    "slowest_mode_hz", 1.2, ...     % ~1.2 Hz electromechanical swing
    "partitions", struct( ...
        "name", {"switching_emt","control_avg","electromech"}, ...
        "solver", {"ode23tb","discrete","discrete"}, ...
        "step_kind", {"variable","fixed","fixed"}, ...
        "step_s", {NaN, 5e-5, 1e-3}, ...
        "max_step_s", {2e-6, NaN, NaN}, ...
        "algebraic_loop", {"none","unit_delay","none"}));
summary = summarize_multirate_solver_plan(plan, ...
    "OutputDir", "build/reports/m1_multirate_solver/vsc_weakgrid_hybrid");
```

The helper is pure base-MATLAB (no toolbox dependency). It does not open or run a
Simulink model; it checks the supplied plan against the contract and writes
evidence. Marking `verified_against_model=true` requires an actual load/update/
simulate result supplied by the caller.

## Output

Write solver-plan reports under:

```text
build/reports/m1_multirate_solver/<case>/
  multirate_solver_plan.md
  multirate_solver_plan.json
  partition_step_table.csv
```

Read `references/multirate-solver-contract.md` before changing required
metadata, step heuristics, failure vs warning wording, or status labels.
