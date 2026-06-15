# DFIG Reactive And Voltage Closed-Loop Workflow

Purpose: evolve SG-to-DFIG replacement from a structural/runnable exercise into
a measurable, controllable, and reusable IBR plant-model workflow.

## Core Principle

Progress through evidence gates. Do not move from topology completion directly
to controller redesign or external compensation.

```text
interface and measurement contract
  -> P/Q telemetry contract
  -> steady operating point
  -> one-device Q sensitivity and limit probe
  -> DFIG-only dispatch/tuning
  -> multi-farm coordination
  -> dynamic voltage scenarios
  -> compensation necessity/design
  -> fair GFL/GFM comparison
  -> reusable IBR evidence package
```

## Gate R0: Structural Baseline

Require capacity, transformer ratio/capacity, physical connectivity, voltage
measurement units, no disconnected root lines, and a corrected settling
trajectory. Structural PASS is necessary but is not voltage-control PASS.

## Gate R1: Telemetry Contract

Before tuning, establish machine-readable P/Q, voltage, current-limit, DC-link,
and controller-state telemetry.

- Verify container type, fields, units, sign, base, and device ownership.
- Give each logged farm signal a unique name.
- Run a short parser smoke before any expensive steady simulation.
- Treat startup-transient values as parser evidence only.
- A detached job passes only when it writes and validates its required result
  artifact plus `success.flag`; `success.flag` and `failed.flag` must be
  mutually exclusive, and process termination alone is not PASS.

## Gate R2: Single-Farm Sensitivity

Use the weakest bus first. On a candidate copy:

- apply small positive and negative Qref perturbations;
- empirically determine reactive-power sign;
- calculate local `dV/dQ`;
- measure active-power coupling;
- identify current, DC-link, integrator, or voltage limits;
- stop before broad tuning if the response is unstable or ambiguous.

## Gate R3: DFIG-Only Voltage Support

Choose the least invasive control architecture supported by evidence:

1. scheduled Qref when fixed operating-point support is sufficient;
2. Q-V droop or supervisory voltage-to-Q dispatch when multiple farms must
   coordinate;
3. explicit voltage-control bypass/outer-loop redesign only when its cut point,
   anti-windup, limits, and initialization are documented.

Register every knob and preserve a best-so-far rollback candidate.

The current W36 evidence proves a structural rotor-current-circle limit at the
studied high-P operating point. Do not claim Qref/Vref tuning can restore
reactive authority unless a later same-window run proves current headroom.
Oscillation/damping tuning remains a separate valid objective.

## Gate R3A: Ordered Control Tuning

Before any controller write, follow
`docs/CONTROL_TUNING_PRIORITY_AND_BOUNDARY.md`.

The approved order is:

1. PLL plus DFIG rotor-side/grid-side current-loop PI;
2. remaining synchronous-machine AVR and governor controls;
3. virtual inertia, POD/PSS-style damping, and reactive/voltage droop;
4. control saturation, anti-windup, protection, and LVRT parameters.

Do not change device physical parameters, ratings, physical current capability,
network parameters, or physical inertia. Run the tuning-readiness inventory and
unchanged baseline before entering bounded parameter iterations.

## Gate R4: Multi-Farm Coordination

Coordinate W33-W36 one at a time, then together. Keep W37 as a healthy control
until a system-wide strategy justifies changing it. Prevent circulating vars
and avoid independent controllers fighting over the same voltage objective.

## Gate R5: Dynamic Voltage Evidence

Require small load/Qref steps, voltage sag/fault recovery, wind/power change,
and weak-grid/SCR stress. Record voltage recovery, overshoot, P/Q coupling,
limit duration, damping, and post-disturbance error.

## Gate R6: Compensation Decision

Add SVC/STATCOM only after measured DFIG capability/limits prove a remaining
reactive deficit. Size compensation from the measured deficit and dynamic
requirement. Preserve and compare the DFIG-only baseline.

## Gate R7: GFL/GFM Research Comparison

Treat GFM as a separate candidate architecture. Compare identical network,
dispatch, rating, current limits, disturbances, fidelity, and metrics. Do not
rename a DFIG-GFL control path as GFM without a credible implementation.

## Skill-Library Deliverables

The reusable library should converge toward:

- `audit_dfig_reactive_capability`
- `extract_dfig_pq_telemetry`
- `probe_dfig_qref_sensitivity`
- `generate_dfig_qv_dispatch`
- `evaluate_dynamic_voltage_support`
- reactive-control and dynamic-voltage additions to the numeric gate
- same-iteration IBR evidence intake for telemetry, limits, tuning, weak-grid,
  and compensation decisions

Each helper must emit compact Markdown/JSON, pass `checkcode`, include a
negative test, and be validated against at least one real model.
