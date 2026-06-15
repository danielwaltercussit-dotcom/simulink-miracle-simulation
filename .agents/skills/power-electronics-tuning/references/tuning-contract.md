# Tuning Contract

## Registry Entry Requirements

Each tunable knob must define:

- `id`
- `block_path`
- `mask_param`
- `current`
- `min`
- `max`
- `units`
- `fs_targets`
- `scale_fcn`
- `priority`
- `parameter_class`
- `control_only`
- `rollback_value`

`control_only` must be true before a tuning stage may write the parameter.
Reject plant/device physical parameters, ratings, topology, and unclassified
parameters. Use `docs/CONTROL_TUNING_PRIORITY_AND_BOUNDARY.md` as the
authoritative priority and immutability contract.

## Approved Priority

1. PLL and DFIG rotor/grid current-loop PI.
2. Remaining synchronous-machine AVR and governor controls.
3. Virtual inertia, POD/PSS-style damping, and reactive/voltage droop.
4. Control saturation, anti-windup, protection, and LVRT thresholds/timers.

Do not advance to a lower priority while the selected higher-priority root
cause remains untested or unresolved.

## Current Failure Signature Mapping

- `FS-006`: voltage band or reactive support issue
- `FS-009`: PLL/frequency recovery issue
- `FS-013`: 5-30 Hz oscillation
- `FS-014`: low-frequency oscillation below 5 Hz

## Default Direction Policy

- if `I_osc_growth > 1.05`, try increasing the selected loop bandwidth
- otherwise try lowering it
- allow at least two same-direction probes before flipping direction because
  weak-grid DFIG gradients can be non-monotonic

## Add A New Knob

1. Confirm the mask parameter name by introspection.
2. Add bounded registry entry.
3. Add FS targets.
4. Run `inspect_tuning_registry`.
5. Run at least `ai_in_loop_run(..., "goal", "tune")`.

Before step 5, prove rollback-on-error and verify that the selected model-owned
signals support the intended metric and failure-signature decision.
