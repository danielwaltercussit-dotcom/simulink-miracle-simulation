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

Recommended extra checks:

- `self_contained_init`: derived DFIG / donor-based models should define `Ts`,
  `Tsample`, or other required workspace aliases in model `InitFcn`.
- AI summary snapshots should include `.slx`, spec, build script, report, key
  PNGs, and latest loop status.

## Failure Routing

- Missing output or non-finite output: fix model logging, initialization, or
  controller parameters before claiming PASS.
- Root overlap: return to layout stage; do not hide physical SPS lines behind
  Goto/From.
- Empty InitFcn on donor-based models: patch the build script to set InitFcn
  and rebuild. This prevents FS-018 when copied outside the project.
- Simulink Test unavailable: use `verify_power_system_model` as the hard model
  gate and record the fallback in `sltest_summary.md`.

## Relation To AI-In-Loop

AI-in-loop S7 calls this verification layer as its functional fallback. S9 then
checks that `sltest_summary.md`, `tuning_report.md`, `top.png`, `report.md`, and
`status.json` exist before final PASS.
