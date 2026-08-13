# Decoupled Interface Contract

The contract for a cross-scale equivalent-source decoupling interface between
two Simulink simulation domains (e.g. switching EMT <-> averaged EMT, or
averaged EMT <-> electromechanical). Checked statically by
`summarize_decoupled_interface_plan`. A `pass` is a plan verdict only and never
implies the interface was executed.

## Three-axis semantics

- `contract_status`: `pass | provisional | fail` - static plan consistency.
- `model_validation_status`: `not_attempted | pass | fail` - evidence from an
  attached ModelProbe only.
- `handoff_ready`: `true` only when contract `pass`, model `pass`, and zero
  warnings.

A bare `verified_against_model = true` without a ModelProbe is a warning and the
derived value is forced `false`.

## Required plan metadata

- `case_name` - identifier for the interface case.
- `interface_kind` - one of:
  `thevenin | norton | controlled_source | measurement_only | s_function_wrapper`.
- `source_domain` - one of:
  `switching_emt | averaged_emt | phasor_rms | electromech`.
- `target_domain` - one of:
  `switching_emt | averaged_emt | phasor_rms | electromech`.
- `exchange_variables` - struct or list declaring at least one exchanged
  quantity drawn from `voltage | current | power | angle | frequency`. Must be
  non-empty.
- `sample_time_s` - interface sample time in seconds (> 0).
- `hold_policy` - one of:
  `explicit_zoh | rate_transition | implicit_discrete | none | undocumented`.
- `delay_s` - interface transport/compute delay in seconds (>= 0).
- `algebraic_loop_breaker` - one of:
  `unit_delay | memory | transport_delay | solver_iteration | none | undocumented`.
- `energy_consistency_check` - one of: `pass | fail | not_attempted`.
- `verified_against_model` - a CLAIM only; never trusted without a ModelProbe.

## Recommended fields

- `equivalent_impedance_ohm` - Thevenin/Norton equivalent impedance.
- `base_voltage_v` - per-unit voltage base.
- `base_power_va` - per-unit power base.
- `phase_reference` - phase/angle reference for phasor or dq exchange.
- `dq_abc_transform` - declared transform when exchanging dq vs abc.
- `initialization_policy` - how the interface state is initialized.
- `boundary_measurement_filter` - filter at the measurement boundary.
- `sign_convention` - load/generator sign convention for power/current.
- `saturation_limits` - limits on exchanged source values.

## Failure conditions (`contract_status = fail`)

- `source_domain == target_domain` while `interface_kind` claims a cross-scale
  decoupling kind (`thevenin | norton | controlled_source | s_function_wrapper`)
  without justification - no real scale boundary is being decoupled.
- `hold_policy == none` while `sample_time_s > 0` and source/target domains
  differ - an unheld sample-and-cross-domain hand-off.
- `algebraic_loop_breaker == none` at a bidirectional `controlled_source`
  interface - guaranteed algebraic loop.
- `delay_s < 0` or `sample_time_s <= 0`.
- `energy_consistency_check == fail`.
- `exchange_variables` missing or empty.
- Unsupported `interface_kind`, `source_domain`, or `target_domain` label.

## Provisional conditions (`contract_status = provisional`)

- `hold_policy` undocumented.
- `algebraic_loop_breaker` undocumented.
- `energy_consistency_check == not_attempted`.
- Missing `sign_convention` or `phase_reference` when exchanging phasor
  (`phasor_rms`) or dq variables.
- `equivalent_impedance_ohm` missing for a `thevenin` or `norton` interface.

## Warning conditions (do not fail, but block handoff_ready)

- `delay_s > sample_time_s` - interface delay exceeds its own sample period.
- Non-integer ratio when both `source_sample_time_s` and `target_sample_time_s`
  are supplied.
- Bare `verified_against_model = true` without a ModelProbe.
- `interface_kind == measurement_only` while bidirectional power exchange is
  claimed (e.g. `exchange_variables` includes `power` with a bidirectional flag).

## ModelProbe semantics

`summarize_decoupled_interface_plan(plan, 'ModelProbe', probe)`:

- no probe -> `model_validation_status = not_attempted`.
- `probe.ran == true && probe.sim_success == true` ->
  `model_validation_status = pass`, derived `verified_against_model = true`.
- `probe.ran == true && probe.sim_success == false` ->
  `model_validation_status = fail` (a failure issue is recorded).

When serialized, the `model_probe` JSON object exposes the core fields
`ran`, `sim_success`, `model`, `notes`, `mdl_path` (plus numeric
`stop_time_s` / `max_abs_state` when present). All string fields are
JSON-escaped so Windows paths (`C:\...`), quotes, and control whitespace remain
machine-readable (`jsondecode`-safe).
