# Diagnostic Plotting Contract

This contract standardizes diagnostic figures for `simulink_agent_v1`.

## Inputs

Use one of:

- a live `Simulink.SimulationOutput` object passed as `SimulationOutput`
- a `.mat` file passed as `MatFile` containing `out`, `simOut`, or
  `simulationOutput`
- a `Simulink.SimulationData.Dataset` object passed as `SimulationOutput`

Optional selectors:

- `Signals`: string array or cellstr of logsout names to export
- `MaxSignals`: maximum number of signals to export when `Signals` is empty
- `OutputDir`: explicit destination, usually an AI-in-loop iteration folder
- `StatusJson`: status file to reference from the manifest

## Output Layout

Default:

```text
build/reports/diagnostics/<model>/<yyyymmddTHHMMSS>/
  overview.png
  signal_<safe_name>.png
  figure_manifest.json
  index.md
```

For AI-in-loop iterations, prefer:

```text
build/reports/loop/iter_<NN>/diagnostics/
  figure_manifest.json
  index.md
  *.png
```

## Manifest Fields

`figure_manifest.json` must include:

- `model`
- `created_at`
- `output_dir`
- `source`
- `status_json`
- `signals_requested`
- `figures`

Each figure entry must include:

- `kind`: `overview` or `signal`
- `signal`
- `path`
- `samples`
- `channels_total`
- `channels_plotted`
- `nan_count`
- `inf_count`
- `finite`
- `min`
- `max`
- `rms`
- `peak_abs`

## Figure Checklist

Each figure must have:

- a descriptive filename with a stable role, such as `overview.png` or
  `signal_<safe_name>.png`
- model name in the title or index
- source artifact recorded in `figure_manifest.json`
- time axis in seconds unless the source uses samples
- units in the plot, index, or linked metric source when units are known
- identical axes for baseline/candidate or before/after overlays when those are
  compared
- thresholds or tolerance bands when pass/fail is discussed
- scenario fault windows shaded when applicable
- no screenshots of MATLAB desktop chrome

## Recommended Signals

Smoke overview:

- bus voltage magnitude or phase voltage
- machine speed, frequency, or PLL frequency estimate
- current magnitude or RMS
- DC-link voltage for converter models
- active/reactive power when available

DFIG and weak-grid tuning:

- PLL frequency or angle error
- rotor-side current or current magnitude
- stator/grid current magnitude
- terminal voltage
- active/reactive power
- any metric used by `extract_tuning_metrics.m`

Fault or scenario recovery:

- disturbed bus voltage
- device current limit signal
- power recovery
- frequency or speed deviation
- recovery-time threshold and settling band

## Failure Marking

For NaN/Inf or divergence:

1. Find the first non-finite sample per signal.
2. Plot a short window ending at that sample when the source data supports it.
3. Mark or name the first bad sample in the index or manifest.
4. Route the finding to `multitimescale-analysis`, `ai-in-loop` S8, or
   `simulink-debug-commandline`.

For oscillation growth:

1. Use the same analysis window as the tuning metrics.
2. Show envelope or peak markers only if they are computed from the plotted
   signal.
3. Report dominant frequency and growth metric in the caption, index, or linked
   tuning report.

## Interpretation Rules

- A clean figure set does not prove model correctness.
- A missing figure for a requested signal is a diagnostic result and should be
  recorded in chat or report text.
- NaN/Inf in plotted data should route back to `ai-in-loop` S8 diagnosis or
  `simulink-debug-commandline`.
- Tuning conclusions should cite both the figure path and the numerical metric
  source from `extract_tuning_metrics` or `tuning_report.md`.
- Keep figures reproducible: record the model name, source `.mat` path when
  used, selected signals, and output directory in the manifest.
- Avoid broad theory unless it directly explains the plotted behavior.
