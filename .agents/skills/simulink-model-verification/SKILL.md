---
name: simulink-model-verification
description: Use when verifying a derived Simulink or Simscape Electrical power-system model in simulink_agent_v1 before declaring it usable, snapshot-ready, or AI-in-loop PASS. Runs compile, smoke simulation, finite logged-output checks, root-overlap checks, self-contained InitFcn checks, report artifact checks, and routes failures back to ai-in-loop diagnosis. Prefer this for model verification when Simulink Test is unavailable or when a fast model-level gate is needed.
---

# Simulink Model Verification

This is the project-local verification gate for derived power-electronics /
converter-interfaced power-system models in
the current repository root.

Use it before saying a model is:

- smoke-ready
- tuning-ready
- `sltest` / regression-ready
- snapshot-ready for the user's configured AI-summary/export folder
- AI-in-loop PASS

## Core Rule

Do not declare PASS from a narrative report alone. PASS requires a reusable
machine check and a written verification artifact.

`verify_power_system_model` PASS means the model is runnable under its current
configuration. It does not prove that replacement-device capacity, transformer
rating/ratio, bus nominal voltage, dispatch, or donor-parameter fidelity are
correct. A device-replacement task also requires the numeric
interface-compatibility artifact defined by `simulink-device-adapters`.

Verification reports for replacement or research models must keep separate
fields for structural, runtime, physical energization, observability,
operating-point qualification, and scientific evidence. A generic helper PASS
may satisfy only the first two. Read
`../simulink-modeling-assistant/references/current-simulation-experience.md`
before promoting a result beyond runnable-model status.

For controller logic, use explicit feedback-polarity contracts. A generic smoke
simulation can pass even when a negative-feedback loop has been wired as
positive feedback, as long as the short run remains finite. Register intended
feedback signs with `ControlFeedbackContracts` so the gate checks the relevant
`Sum` block `Inputs` string before declaring PASS.

Feedback-polarity results carry a per-contract `classification`:
`PASS`, `MISMATCH`, `FIXED`, `BAD_CONTRACT`, `MISSING_BLOCK`, `NOT_SUM_BLOCK`,
or `ERROR`. The helper writes both a Markdown report and a machine-readable
JSON report (same base name, `.json` extension, or set `ReportJsonPath`
/ `ControlFeedbackJsonPath` explicitly). See
`docs/CONTROL_FEEDBACK_POLARITY_GATE.md` and
`references/verification-contract.md` for the schema and routing rules.

Primary helper:

```matlab
projectRoot = pwd;  % run from the repository root
init_simulink_agent_project
addpath("scripts/verification")
r = verify_power_system_model("nebus39_dfig2_weakgrid_v0", ...
    "StopTime", 0.005, ...
    "ReportPath", "build/reports/verification/nebus39_dfig2_weakgrid_v0.md");
assert(r.passed)
```

Feedback-polarity example:

```matlab
contract = struct( ...
    "block_path", "VoltageController/Sum", ...
    "expected_inputs", "+-", ...
    "description", "Vref minus measured terminal voltage");
r = verify_power_system_model("candidate_model", ...
    "ControlFeedbackContracts", contract, ...
    "ReportPath", "build/reports/verification/candidate_model.md");
assert(r.checks.control_feedback_polarity)
```

## Verification Stack

1. `verify_power_system_model` for model-level checks.
2. `testing-simulink-models` for component-level `.feature` / Simulink Test
   harnesses when the model has signal-based Inport/Outport interfaces.
3. Official `model_check`, Model Advisor, or Simulink Check compliance review
   when the task requires structural compliance, custom checks, MAB/JMAAB,
   ISO 26262, DO-178C, AUTOSAR, or other standards evidence. If the required
   toolbox is unavailable, record a soft skip instead of pretending compliance
   passed.
4. `ai-in-loop` when verification should trigger tuning, diagnosis, reporting,
   and AI summary snapshotting.
5. `multitimescale-analysis` when a failed or borderline check needs a
   cross-band explanation before choosing tuning or debugging.
6. `diagnostic-plotting` when a failed or borderline check needs waveform
   evidence before routing the next fix.

## What The Helper Checks

- model can be loaded from `build/generated_models/`
- `SimulationCommand update` passes
- short `sim()` completes
- logged outputs exist unless explicitly disabled
- numeric logged outputs contain no NaN/Inf
- root canvas has no overlapping blocks when `ai_in_loop_count_overlap` is on path
- declared feedback-polarity contracts pass when `ControlFeedbackContracts` is supplied
- SATK `model_check` or available compliance tooling is run when the request or
  project gate requires compliance evidence
- InitFcn is non-empty or contains self-contained aliases such as `Ts` / `Tsample`
- a Markdown report is written when `ReportPath` is supplied

Read `references/verification-contract.md` when you need the exact PASS contract
or when updating AI-in-loop stages.

## Routing

- For quick model-level verification: call `verify_power_system_model`.
- For a closed loop with tuning and snapshot: call `ai_in_loop_run`.
- For subsystem regression tests with signal ports: use `testing-simulink-models`.
- If Simulink Check is unavailable, Model Advisor may soft-skip; do not treat
  that as a project failure, but record it.

## Output

Keep chat short. Point to:

- `build/reports/verification/<model>.md` for standalone verification
- `build/reports/loop/iter_<NN>/sltest_summary.md` for AI-in-loop S7
- `build/reports/loop/iter_<NN>/status.json` for machine state
- `build/reports/loop/iter_<NN>/multitimescale_notes.md` when a failed metric
  was classified across dynamic time scales
- `build/reports/diagnostics/<model>/<run_id>/figure_manifest.json` and
  `index.md` when plots were generated to explain a failure or borderline metric
