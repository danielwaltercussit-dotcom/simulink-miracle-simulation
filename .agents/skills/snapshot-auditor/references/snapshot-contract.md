# Snapshot Audit Contract

Use this reference when checking S10 AI-in-loop snapshot packages in
`simulink_agent_v1`.

## Purpose

The snapshot is a user-facing handoff package. It should prove what model was
generated, which spec and build function produced it, which loop iteration
passed, and which reports support the handoff.

The audit checks package completeness. It does not replace compile, smoke,
tuning, layout, or model verification gates.

## Required Files

In `AI summary of simulation models/<model>/`:

- `<model>.slx`
- `case_<model>.yaml`
- `build_<model>.m`
- `snapshot_manifest.json`
- `README.md`
- `latest_loop_status.json`
- at least one of `<model>_report.md` or `<model>_loop_report.md`

The loop iteration directory should also contain:

- `status.json`
- `report.md`
- `snapshot_audit.md` after the audit runs

## Required Manifest Fields

`snapshot_manifest.json` must include:

- `model`
- `project_root`
- `spec_path`
- `build_fcn`
- `iteration_dir`
- `snapshot_at`
- `files`

The `model`, `spec_path`, and `build_fcn` values must match the arguments used
for the audit.

## Warning Files

Warn, but do not fail, when these are absent:

- `<model>.slxc`
- `latest_model_verification_summary.md`
- `latest_spec_validation.md`
- `latest_adapter_contract.md`
- `latest_layout_quality.md`
- `latest_tuning_report.md`
- `latest_sltest_summary.md`
- `<model>_latest_top.png`
- diagnostic plot index or manifest

Missing optional files can still matter. Route to the related upstream skill
when the user needs that evidence before handoff.

## Report Language

Use concise audit language:

- "Snapshot audit PASS: required files and manifest fields are present."
- "Snapshot audit FAIL: missing `<file>`."
- "Warning only: `<file>` was not found, so the package lacks `<evidence>`."

Do not infer model quality from copied files alone.
