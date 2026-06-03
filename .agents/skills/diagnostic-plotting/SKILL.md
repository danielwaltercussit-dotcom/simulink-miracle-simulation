---
name: diagnostic-plotting
description: Use when exporting, reviewing, or standardizing diagnostic plots for Simulink simulations in simulink_agent_v1, including logsout time-series figures, smoke-simulation evidence, tuning-round visual summaries, failure-signature investigation, AI-in-loop report figures, and figure_manifest.json artifacts.
---

# Diagnostic Plotting

Use this skill after a Simulink run has produced a `SimulationOutput`, saved
`.mat` output, tuning history, or AI-in-loop iteration directory that needs
human-readable diagnostic figures.

Primary helper:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
init_simulink_agent_project
addpath(".agents/skills/diagnostic-plotting/scripts")

in = Simulink.SimulationInput("nebus39_dfig2_weakgrid_v0");
in = in.setModelParameter("StopTime", "0.05");
out = sim(in);

manifest = export_simulink_diagnostic_plots("nebus39_dfig2_weakgrid_v0", ...
    "SimulationOutput", out, ...
    "OutputDir", "build/reports/diagnostics/nebus39_dfig2_weakgrid_v0/latest");
```

## Workflow

1. Use `simulating-simulink-models` to run or locate the simulation output.
2. Export figures with `scripts/export_simulink_diagnostic_plots.m`.
3. Re-read `figure_manifest.json` before referencing results in chat or reports.
4. Treat plots as evidence, not as PASS criteria. Use
   `simulink-model-verification`, `multitimescale-analysis`, or `ai-in-loop`
   for PASS/FAIL gates and cross-band decisions.

Read `references/plotting-contract.md` before changing figure naming, manifest
fields, or AI-in-loop report integration.

## Figure Policy

- Write figures under `build/reports/diagnostics/<model>/<run_id>/` unless the
  caller supplies an iteration-local `OutputDir`.
- Always emit `figure_manifest.json` and `index.md`.
- Prefer `logsout` signal names. If the caller supplies `Signals`, plot only
  those names.
- Plot scalar or low-channel time series directly; for wider arrays, plot the
  first three channels and record the total channel count.
- Flag NaN/Inf counts in the manifest instead of hiding them with smoothing.
- Do not edit oracle models or source `.slx` files to add logging just for a
  plot. If logging is missing, report that as the diagnostic finding.

## Routing

- For smoke or custom simulation data: pair with `simulating-simulink-models`.
- For cross-time-scale explanations: pair with `multitimescale-analysis`.
- For S6 tuning interpretation: pair with `power-electronics-tuning`.
- For final model acceptance: pair with `simulink-model-verification`.
- For closed-loop runs: attach the manifest path to the AI-in-loop iteration
  report and keep the generated images inside that iteration directory when
  possible.
