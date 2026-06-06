---
name: perturbation-stability-boundary-scan
description: Use when identifying stability margins or stability boundaries across swept or randomized parameters for Simulink power-electronics and converter-dominated power-system models - parasitics, filter values, grid strength (SCR/ESCR), controller gains, and operating points. Covers deterministic grid scans and Monte-Carlo boundary scans, pass/fail metric definition, per-axis boundary interpolation, and a scan-evidence reporting contract. Complements small-signal-modal-analysis and impedance-frequency-analysis by mapping where a single-point result stops holding.
---

# Perturbation / Stability Boundary Scan

Use this skill when a converter-grid study needs to know not just whether one
operating point is stable, but **where the stability boundary is** across a
range of parameters: grid strength (SCR/ESCR), controller gains, filter/parasitic
values, or operating points. It turns a sweep or Monte-Carlo cloud of
already-computed stability metrics into a contract-compliant boundary summary.

## Core Rule

A boundary reported here is an **interpolation of the supplied pass/fail
samples**, not a proven physical stability limit. The helper does NOT run a
Simulink sweep, does NOT compute the metric, and does NOT claim hardware-level
validation. A boundary value is only as trustworthy as the metric and the grid
density behind it. Confirm a critical boundary with a refined sweep near the
crossing and with EMT/RMS time-domain validation before quoting it as a margin.

## When To Use vs Modal / Impedance Analysis

- Use `small-signal-modal-analysis` for mode ownership at one operating point
  (eigenvalues, damping, participation factors).
- Use `impedance-frequency-analysis` for frequency-domain resonance / passivity
  evidence at one operating point.
- Use **this skill** when you have many operating points / parameter samples and
  want the boundary between stable and unstable regions, a pass fraction, and a
  margin estimate. The per-sample metric typically comes FROM modal or impedance
  analysis (e.g. min damping ratio, max real eigenvalue, gain margin). This skill
  consumes those scalar metrics; it does not replace them.

## Scan Types

- **Deterministic grid scan** (`ScanType="grid"`): a structured sweep over one or
  more parameter axes (e.g. SCR in 1:0.25:5). Per-axis boundaries are
  well-defined marginal crossings. Prefer for 1-D or 2-D margin studies.
- **Monte-Carlo scan** (`ScanType="montecarlo"`): randomized samples over a
  parameter space, used for robustness / yield under combined uncertainty.
  Requires a recorded `RandomSeed` to be reproducible; per-axis boundaries are
  1-D projections of a cloud and are reported as approximate.

## Pass/Fail Metric

Define exactly one scalar metric per sample and a direction:

- `PassDirection="above"`: sample passes when `metric >= PassThreshold`
  (e.g. damping ratio >= 0.03, gain margin >= 6 dB).
- `PassDirection="below"`: sample passes when `metric <= PassThreshold`
  (e.g. max real eigenvalue <= 0, THD <= limit).

The signed distance to the threshold is the boundary-crossing indicator. An
undocumented metric name, threshold, or direction makes the scan provisional.

## Workflow

1. State the study question and the single pass/fail metric (with units and
   direction) before scanning.
2. Choose grid vs Monte-Carlo. For Monte-Carlo, fix and record a random seed.
3. Compute the metric per sample using modal / impedance / time-domain evidence
   (outside this helper). Assemble an `N x D` sample matrix and `N x 1` metric.
4. Call `summarize_stability_boundary_scan` with parameter names, declared
   ranges, threshold, direction, interpolation method, operating point, units,
   and an output dir.
5. Read the per-axis boundary, pass fraction, warnings, and provisional flag.
6. For a critical boundary, refine the grid near the crossing and confirm with a
   time-domain run; record the run via `RelatedTimeDomainRun`.
7. Route SCR-dependent boundaries to `weak-grid-scr-scenario`; controller-gain
   boundaries to `power-electronics-tuning`; GFL/GFM boundary differences to
   `gfl-gfm-control-comparison`.

## Lab References

Treat the desktop lab archive as read-only ground truth. Use its parameter sets,
SCR ranges, and controller-gain ranges to choose realistic scan bounds; never
edit archive files and never copy private models into the repo. Use
`lab-model-pattern-miner` only when checking the archive.

## Helper

Use the project helper when you already have per-sample stability metrics:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
summary = summarize_stability_boundary_scan(samples, metric, ...
    "CaseName", "dfig_scr_gain_scan", ...
    "ScanType", "grid", ...
    "ParameterNames", ["scr","kp"], ...
    "ParameterRanges", [1 5; 0.1 2], ...
    "MetricName", "damping_ratio", ...
    "PassThreshold", 0.03, ...
    "PassDirection", "above", ...
    "BoundaryInterpMethod", "linear", ...
    "OperatingPoint", "rated load, GFL, SCR x kp sweep", ...
    "Units", "dimensionless", ...
    "OutputDir", "build/reports/f3_boundary_scan/dfig_scr_gain_scan");
```

The helper is pure base-MATLAB (no toolbox dependency): per-axis boundaries use
a linear/nearest zero-crossing of the pass indicator; duplicate grid levels are
collapsed with a worst-case (min pass-indicator) rule so one failing sample at a
level marks that level failing. It does not run a Simulink sweep; supply data.

## Output

Write boundary-scan reports under:

```text
build/reports/f3_boundary_scan/<case>/
  stability_boundary_summary.md
  stability_boundary_summary.json
  scan_samples.csv
```

Keep these artifacts separate from P3/P4 impedance reports under
`build/reports/impedance/`. Read
`references/stability-boundary-contract.md` before changing the metric
classification, boundary interpolation rule, required metadata, or pass/fail
wording.
