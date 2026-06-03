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
