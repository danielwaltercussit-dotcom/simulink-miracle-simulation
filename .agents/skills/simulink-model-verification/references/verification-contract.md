# Verification Contract

## PASS Conditions

A derived model can be called verified only when all required checks are true:

- `update`: `set_param(model, "SimulationCommand", "update")` succeeds.
- `sim_completed`: `sim(..., "ReturnWorkspaceOutputs", "on")` succeeds.
- `has_outputs`: at least one logged output exists, unless the caller explicitly
  disables `RequireOutputs`.
- `required_signals_present`: all requested logged signals are present.
- `finite_outputs`: numeric logged outputs contain no NaN or Inf.
- `root_overlap_free`: root-level block overlap count is zero when layout helper
  is available.
- `control_feedback_polarity`: all declared `ControlFeedbackContracts` pass.
  This check defaults to true when no contracts are supplied, preserving the
  generic smoke gate for legacy models.

Recommended extra checks:

- `self_contained_init`: derived DFIG / donor-based models should define `Ts`,
  `Tsample`, or other required workspace aliases in model `InitFcn`.
- `physical_energization`: independent physical P/Q or voltage/current channels
  are finite, non-degenerate, correctly signed, and plausible.
- `observability_contract`: required signals have declared units, base, sign,
  sample count, and native time vectors.
- `operating_point_qualified`: measured pre-event dispatch and voltage match the
  audited target within declared tolerances.
- `scientific_evidence`: record length, frequency resolution, band presence,
  prominence, and damping gates support the exact claim.
- Control-loop tasks should add contract entries for intended negative-feedback
  summing junctions, especially voltage, reactive-power, PLL, current-loop, and
  damping paths whose sign can be inverted by a wiring or port-order mistake.
- AI summary snapshots should include `.slx`, spec, build script, report, key
  PNGs, and latest loop status.

## Feedback Polarity Classification Codes

Each contract in the feedback-polarity result carries a `classification` field
(see `docs/CONTROL_FEEDBACK_POLARITY_GATE.md` for full documentation):

| Code | Meaning | Passed? |
|---|---|---|
| `PASS` | Block exists, is Sum, Inputs match expected | yes |
| `MISMATCH` | Block exists, is Sum, Inputs differ | no |
| `FIXED` | Was MISMATCH, AutoFix corrected successfully | yes |
| `BAD_CONTRACT` | Missing `block_path` or `expected_inputs` | no |
| `MISSING_BLOCK` | Block path does not resolve | no |
| `NOT_SUM_BLOCK` | Block exists but wrong type | no |
| `ERROR` | Unexpected runtime error | no |

The overall `control_feedback_polarity` check is true only when every contract
classifies as `PASS` or `FIXED`.

## JSON Artifact

When `ReportPath` is supplied to `verify_control_feedback_polarity`, a
machine-readable `.json` file is generated alongside the `.md` report (same
directory, same base name). The JSON path can also be set explicitly via
`ReportJsonPath`.

The JSON contains: `name`, `model`, `status`, `passed`, `message`,
`contract_count`, `failed_count`, `mismatch_count`, `fixed_count`,
`classification_counts` (object with all seven codes as keys), and a `contracts`
array with per-contract fields including `classification`.

Consumers (AI-in-loop stages, CI gates, Codex review) should parse
`status` and `contracts[].classification` for machine decisions.

## Top-Level Metrics in verify_power_system_model

When `ControlFeedbackContracts` is supplied, `verify_power_system_model` exposes
the following top-level metrics for AI-in-loop routing without nested-struct
traversal:

| Field | Type | Description |
|---|---|---|
| `control_feedback_contract_count` | int | Number of contracts checked |
| `control_feedback_failed_count` | int | Contracts that did not pass |
| `control_feedback_mismatch_count` | int | MISMATCH-only count |
| `control_feedback_fixed_count` | int | FIXED-only count |
| `control_feedback_classification_counts` | struct | All seven codes with counts |
| `control_feedback_report` | string | Path to Markdown report |
| `control_feedback_json_report` | string | Path to JSON report |

These fields appear in `result.metrics` and in the Markdown verification report.
String-valued metrics (paths) are rendered as backtick-wrapped text in the report
rather than "(omitted)".

## Failure Routing

- Missing output or non-finite output: fix model logging, initialization, or
  controller parameters before claiming PASS.
- Feedback-polarity mismatch: inspect the declared `Sum` block, confirm the
  intended sign from the model/spec, and only then use `AutoFixControlFeedback`
  or an explicit `set_param(block, "Inputs", expected)` repair. Re-run the
  contract and at least one behavior check before accepting the fix.
- Root overlap: return to layout stage; do not hide physical SPS lines behind
  Goto/From.
- Empty InitFcn on donor-based models: patch the build script to set InitFcn
  and rebuild. This prevents FS-018 when copied outside the project.
- Simulink Test unavailable: use `verify_power_system_model` as the hard model
  gate and record the fallback in `sltest_summary.md`.
- Runtime PASS with failed energization, observability, or operating-point
  qualification: keep the earlier PASS fields, fail the later gate, and forbid
  modal/replacement-stage promotion.

## Relation To AI-In-Loop

AI-in-loop S7 calls this verification layer as its functional fallback. S9 then
checks that `sltest_summary.md`, `tuning_report.md`, `top.png`, `report.md`, and
`status.json` exist before final PASS.

Feedback-polarity contracts are currently opt-in. Future AI-in-loop build or
adapter stages may generate contracts from model metadata, but until then the
task owner must pass the relevant contract array into `verify_power_system_model`.
