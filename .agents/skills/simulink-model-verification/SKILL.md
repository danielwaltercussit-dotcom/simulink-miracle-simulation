---
name: simulink-model-verification
description: Use when verifying a derived Simulink or Simscape Electrical power-system model in simulink_agent_v1 before declaring it usable, snapshot-ready, or AI-in-loop PASS. Runs compile, smoke simulation, finite logged-output checks, root-overlap checks, self-contained InitFcn checks, report artifact checks, and routes failures back to ai-in-loop diagnosis. Prefer this for model verification when Simulink Test is unavailable or when a fast model-level gate is needed.
---

# Simulink Model Verification

This is the project-local verification gate for derived power-electronics /
converter-interfaced power-system models in
`C:\Users\jonas\Desktop\simulink_agent_v1`.

Use it before saying a model is:

- smoke-ready
- tuning-ready
- `sltest` / regression-ready
- snapshot-ready for `C:\Users\jonas\Desktop\AI summary of simulation models`
- AI-in-loop PASS

## Core Rule

Do not declare PASS from a narrative report alone. PASS requires a reusable
machine check and a written verification artifact.

Primary helper:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
init_simulink_agent_project
addpath("scripts/verification")
r = verify_power_system_model("nebus39_dfig2_weakgrid_v0", ...
    "StopTime", 0.005, ...
    "ReportPath", "build/reports/verification/nebus39_dfig2_weakgrid_v0.md");
assert(r.passed)
```

## Verification Stack

1. `verify_power_system_model` for model-level checks.
2. `testing-simulink-models` for component-level `.feature` / Simulink Test
   harnesses when the model has signal-based Inport/Outport interfaces.
3. `ai-in-loop` when verification should trigger tuning, diagnosis, reporting,
   and AI summary snapshotting.

## What The Helper Checks

- model can be loaded from `build/generated_models/`
- `SimulationCommand update` passes
- short `sim()` completes
- logged outputs exist unless explicitly disabled
- numeric logged outputs contain no NaN/Inf
- root canvas has no overlapping blocks when `ai_in_loop_count_overlap` is on path
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
