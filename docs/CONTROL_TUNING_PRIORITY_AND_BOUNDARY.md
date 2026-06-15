# Control Tuning Priority And Boundary

Purpose: define the approved closed-loop tuning order and prevent controller
tuning from silently changing the plant, device ratings, or study scenario.

## Current Entry State

The IEEE39 SG5/DFIG5 modeling test has completed structural repair, measurement
contracts, steady P/Q evidence, W36 Qref-path tracing, and rotor-current-limit
diagnosis. It is at the closed-loop tuning entry gate, but no accepted
before/after controller-parameter tuning result exists yet for this model.

W36 reactive authority is structurally blocked at the studied high-P operating
point by the rotor current circle. PLL/current-loop tuning may address
oscillation and damping, but it must not be claimed as a cure for that measured
reactive-capability limit.

## Immutable Plant And Device Boundary

Do not tune or accept changes to:

- network topology, line/cable/transformer physical parameters, or bus ratings;
- device count, device/farm rating, rated voltage/frequency, converter rating,
  or physical current capability;
- machine electrical parameters, physical inertia, shaft, aerodynamic, or
  mechanical plant parameters;
- device replacement, control architecture replacement, or source model;
- load, wind, fault, SCR, or dispatch values as a substitute for a controller
  improvement.

Operating conditions may be varied only as named validation scenarios. Derived
or candidate models may be used; oracle/reference models remain read-only.

## Approved Tunable Boundary

Control parameters may be tuned only after introspection proves their block
path, parameter name, current value, units, bounds, and rollback value.

Use this fixed priority order:

1. PLL parameters and DFIG rotor-side/grid-side current-loop PI gains.
2. Remaining synchronous-machine AVR and governor control parameters.
3. Virtual inertia, POD/PSS-style damping, reactive-power/voltage droop, and
   other supplementary damping or outer-loop control parameters.
4. Controller saturation, anti-windup, protection, and LVRT control thresholds
   or timers.

Priority 4 does not permit increasing device ratings or physical current
capability. DC-link, speed, and other converter control loops may be tuned when
evidence identifies them, but they must not bypass an unresolved higher-priority
root cause.

## Required Closed-Loop Process

### T0: Tuning Readiness

- inventory tunable and immutable parameters by device and block path;
- reject unclassified parameters and any proposed plant/device write;
- define device-owned voltage, current, frequency, P/Q, DC-link, rotor-speed,
  limiter, and protection signals;
- create a rollback snapshot and prove restore on a candidate copy;
- record the baseline scenario set and acceptance metrics.

### T1: Baseline And Root-Cause Classification

- run an unchanged-parameter baseline;
- classify dominant time scale and mode ownership;
- separate converter/PLL oscillation, electromechanical behavior, scenario
  recovery, and structural capability limits;
- select one priority group and one root cause for the next iteration.

### T2: Bounded Parameter Iteration

- change one control family per iteration;
- record `before -> after`, bounds, rationale, scenario, and metrics;
- reject regressions and restore best-so-far;
- do not advance to a lower priority while a higher-priority root cause remains
  untested or unresolved.

### T3: Cross-Scenario Acceptance

- verify steady state, disturbance recovery, weak-grid/SCR, and fault/LVRT
  scenarios as applicable;
- require before/after overlays and machine-readable metrics;
- preserve the unchanged baseline and accepted candidate;
- report structural limits separately from tuning outcomes.

## Current Automatic S6 Restriction

Do not run automatic S6 writes on the IEEE39 SG5/DFIG5 test model until:

- the registry discovers W33-W37 and the remaining synchronous-machine
  controllers needed by the selected priority;
- registry entries explicitly declare priority, parameter class, and
  `control_only=true`;
- the stage rejects immutable/unclassified entries;
- signal ownership and rollback-on-error are proven by tests.

Until then, use T0/T1 inventory and baseline analysis only.
