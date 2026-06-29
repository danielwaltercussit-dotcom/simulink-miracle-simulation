# Fidelity Switch Equivalence Contract

Use this contract when recording or reviewing a switch between model fidelities
(detailed switching, averaged EMT, dynamic phasor, RMS/positive-sequence, or
phasor/load-flow). It is the schema enforced by
`scripts/analysis/summarize_fidelity_switch_evidence.m` and exercised by
`tests/fidelity_switching_contract_test.m`.

## Recognized Fidelity Labels

Ranked finer -> coarser (rank in parentheses):

- `switching_emt` (5) - detailed switching, modulation and device detail
- `averaged_emt` (4) - averaged converter, no carrier switching
- `dynamic_phasor` (3) - time-varying phasor, retained sub-RMS bandwidth
- `rms` / `positive_sequence` (2) - electromechanical / RMS
- `phasor` / `load_flow` (1) - steady-state phasor

An unrecognized label is allowed as input but forces `provisional` status, so a
typo or an undefined abstraction cannot be reported as a clean switch.

## Two Equivalence Axes

This contract reports two independent axes and never conflates them:

- **documented_equivalence** - is the equivalence *contract* fully and
  self-consistently documented? This is a metadata/consistency check.
- **measured_equivalence** - is there a *real* baseline-regression comparison:
  an actual numeric error value vs a numeric bound, with compared run ids and
  same-study artifact files that exist on disk?

A documented error-metric *target* is part of documented equivalence only. It
can never, by itself, produce a measured pass. This keeps a text target from
being mistaken for model-backed numerical validation.

## Required Fields (documented_equivalence)

`documented_status` is `pass` only when all are documented:

| Field | Meaning |
|---|---|
| operating_point | bias point the equivalence is asserted at |
| base_values | shared per-unit / SI bases |
| bandwidth_retained_hz | band the target model still represents (numeric) |
| losses | losses retained vs neglected by the target |
| initialization_mapping | source-state to target-initial-state mapping |
| error_metric | comparison metric and its acceptance bound |
| time_step_ratio | target_dt / source_dt (numeric, > 0) |

## Direction and Time-Step Consistency

- `direction` is derived from the fidelity ranks: `refine` (toward finer),
  `coarsen` (toward coarser), `same`, or `unknown`.
- `time_step_ratio = target_dt / source_dt`.
  - `coarsen` expects `ratio >= 1` (coarser models tolerate larger steps).
  - `refine` expects `ratio <= 1` (finer models need smaller steps).
  - `same` / `unknown` impose no ratio constraint.
- A documented ratio that contradicts the direction forces `provisional` and is
  recorded in `warnings`.

## Measured Equivalence Fields (measured_equivalence)

Supply these to ingest a real baseline-regression comparison between the two
fidelities:

| Field | Meaning |
|---|---|
| measured_error_value | actual error number produced by the comparison |
| measured_error_bound | numeric acceptance bound for that error |
| error_metric_definition | how the error was computed (distinct from the documented target text) |
| compared_run_ids | both the from-run and to-run identifiers being compared |
| same_study_artifact_paths | artifact files/dirs that exist on disk and back the comparison |
| same_study_root | root the artifacts must sit under, so cross-study files are rejected |

`measured_status`:

- `not_provided` - no measured inputs supplied (documented target only).
- `provisional` - a measured comparison was attempted but is incomplete or
  unverifiable: a required measured field is missing, an artifact file is
  absent on disk, or an artifact is not under `same_study_root`.
- `pass` - numeric error <= numeric bound AND all measured fields present AND
  every artifact exists on disk under the study root.
- `fail` - all fields present and verifiable, but numeric error > bound.

## Average -> Switching State Mapping

`map_average_to_switching_state` records how averaged states seed a switching
model and whether that mapping is internally consistent.

Inputs: inductor_current_a, duty (0..1), vdc_v, carrier_freq_hz, optional
carrier_phase (default 0).

Outputs: switching initial conditions (inductor_current_a carried over,
carrier_phase declared, reconstructed switch_state_q0), the one-carrier-cycle
reconstructed mean output, and a continuity residual.

- continuity_residual_abs = |Vdc*duty - mean(reconstructed switched output)|
- continuity_residual_rel = residual_abs / |Vdc*duty|
- contract_status = `consistent` when required fields are present, duty is in
  [0,1], and continuity_residual_rel <= residual_tol; otherwise `provisional`.
- model_validation_status is ALWAYS `not_run` for this helper. A small residual
  proves the mapping is self-consistent, NOT that a simulation stays continuous.

## Runnable Prototype (model-backed)

`run_fidelity_switch_prototype` builds a minimal averaged-vs-switching RL model
in memory and actually simulates it.

- ran = true only if Simulink built and simulated the model in this session.
- rel_error = |mean(i_sw) - i_avg| / |i_avg| over the steady-state window.
- model_validation_status: `ran` on success, `failed` on a sim error,
  `not_run` if never attempted. On failure rel_error stays NaN; it can never
  become a measured pass.

Feed proto.rel_error + proto.json_path into the measured-equivalence fields to
obtain overall_status=`measured_pass` ONLY when the simulation actually ran and
the error is within bound.

## Three Separated Verdicts

- contract consistency: documented_status / mapping contract_status. Metadata is
  complete and self-consistent. NOT a model result.
- model-backed: measured_status=`pass` / overall_status=`measured_pass`,
  reached only from an actual simulation within bound plus same-study artifacts.
- hardware-backed: NOT provided by this package. Never assert it from software.

## Status (combined)

- `documented_status`: `pass` | `provisional` (see required fields above and the
  direction/time-step rule).
- `measured_status`: `not_provided` | `provisional` | `pass` | `fail`.
- `overall_status` combines the two without overclaiming:
  - `measured_pass` - measured pass AND documented pass (the only state that
    asserts model-backed equivalence).
  - `measured_fail` - measured comparison ran and the error exceeded the bound.
  - `documented_pass` - documentation complete, no measured comparison supplied.
  - `provisional` - anything else.

`provisional` is the safe default. A fidelity switch must never be presented as
"equivalent" or "interchangeable" unless documented, and must never be presented
as numerically validated unless `overall_status` is `measured_pass`.

The legacy fields `status`/`provisional` are retained as aliases of
`documented_status`/`documented_provisional` for backward compatibility.

## Failure Routing

- Missing observable for the error metric -> `diagnostic-plotting` or model
  logging before comparing fidelities.
- Damping / mode-ownership must survive the switch -> `small-signal-modal-analysis`.
- Cross-fidelity result comparison -> `baseline-regression` against a golden run.
- Model-package credibility before external use -> `ibr-model-validation-evidence`.
