# Stability Boundary Scan Contract

Use this contract when generating or reviewing perturbation / stability boundary
scan evidence for converter-dominated systems. It is the durable specification
behind `summarize_stability_boundary_scan.m`; read it before changing metrics,
the boundary rule, band/label wording, or pass/fail semantics.

## Required Metadata

Record:

- case name and source model/script
- scan type: `grid` (deterministic sweep) or `montecarlo` (randomized)
- evidence source: `measured`, `simulated`, `analytic`, or `synthetic`
- varied parameter names and declared ranges (one range per parameter)
- pass/fail metric name, units, threshold, and direction
  (`above` = pass when metric >= threshold; `below` = pass when metric <=
  threshold)
- random seed (REQUIRED for `montecarlo`; reproducibility depends on it)
- operating point the scan was taken at (load level, control mode, fixed
  parameters not being swept)
- declared sample count (cross-checked against supplied samples)
- related time-domain run or required follow-up run

If operating point, units, metric name, parameter ranges, or (for Monte-Carlo)
the random seed are undocumented, the scan is **provisional** and must be
reported as such. Provisional scan evidence must never be promoted to a
hardware-level or proven-margin claim.

## Metric And Classification

- Exactly one scalar metric per sample. Typical metrics: minimum damping ratio,
  maximum real part of eigenvalues, gain/phase margin, peak overshoot, THD.
- The signed pass indicator `g` is `metric - threshold` (direction `above`) or
  `threshold - metric` (direction `below`). `g >= 0` passes.
- System-level outputs: sample count, pass count, fail count, and pass fraction.

## Boundary Estimation

For each parameter axis report:

- whether a boundary (a sign change of the pass indicator) exists in range
- the boundary value (first / lowest-parameter crossing if several)
- the crossing count on that axis
- a per-axis note

Rules:

- Boundary interpolation method is `linear`, `nearest`, or `none`.
- Per-axis boundaries are MARGINAL estimates: other parameters are not held
  fixed, so a 2-D+ boundary is a projection. State this; do not present a
  per-axis crossing as a full multi-D stability surface.
- Duplicate parameter levels are collapsed with a worst-case (minimum pass
  indicator) rule, so a single failing sample at a level marks the whole level
  as failing. This is conservative by design.
- A `linear` crossing interpolates the zero of `g` between bracketing levels; a
  `nearest` crossing snaps to the bracketing level with the smaller `|g|`.

## Joint Boundary Curve

An opt-in joint boundary reports the critical value of a primary axis as a
function of a conditioning axis (e.g. critical `Kp` vs `Ts`). Required:

- `JointPrimaryAxis` and `JointConditioningAxis` must name two distinct scanned
  parameters.
- It requires a deterministic `grid` scan; on a Monte-Carlo scan the joint
  boundary is marked requested-but-unavailable and never fabricated.
- Each conditioning slice reports: conditioning value, critical primary value
  (or none), a has-boundary flag, the level count, and a note.
- A monotone trend (`increasing` / `decreasing` / `non-monotone` /
  `insufficient`) is classified only from slices that produced a finite
  boundary.
- All-pass / all-fail slices are reported as such, not coerced to a number.
- The curve is interpolated from the grid; it is not a proven margin. Couple
  physically dependent parameters inside the metric (e.g. delay samples that
  scale with `Ts`) so the curve reflects the real dependency.

## Evidence Tiers

Every reported boundary must declare its tier; never promote a lower tier to a
higher one in prose or status:

1. `contract-consistency` - metadata + pass/fail bookkeeping complete; no physics
   asserted.
2. `analytic` / illustrative - a transparent closed-form metric produced the
   samples (e.g. `dt_loop_stability_metric`, a discrete current loop). Real
   coupling, teaching model, NOT a validated converter.
3. `model-backed` - per-sample metric came from an actual Simulink/Simscape
   `load`/`update`/`sim` of the studied model.
4. `hardware-backed` - HIL / bench measurement. Not produced by this skill.

`dt_loop_stability_metric` is tier 2 and does NOT model PLL weak-grid (low-SCR)
instability; its SCR axis only rescales series inductance and is illustrative.

## Interpretation Rules

- A boundary is an interpolation of the supplied pass/fail samples, not a proven
  physical stability limit. Confirm with a refined sweep near the crossing and
  with EMT/RMS time-domain validation.
- Grid density caps boundary accuracy: a coarse grid gives a coarse boundary.
  Refine near a crossing before quoting a sharp margin.
- A Monte-Carlo pass fraction is a robustness/yield statistic for the sampled
  distribution, not a guarantee outside the sampled space and not a probability
  of physical instability.
- `no passing samples` or `no failing samples` means the boundary lies outside
  the scanned region; the scan brackets nothing and must say so.
- Do not claim hardware-level validation from simulated or analytic scans.

## Relation To Other Evidence

- Modal: the per-sample metric is often a modal output (min damping, max real
  eigenvalue). A boundary in damping ratio and a boundary in a modal mode at the
  same parameter value are agreeing, non-circular evidence.
- Impedance: a passivity / resonance margin from `impedance-frequency-analysis`
  can be the per-sample metric for a frequency-domain boundary scan.
- Weak-grid: re-run the scan across the SCR/ESCR range used by
  `weak-grid-scr-scenario` so the boundary and large-disturbance evidence share
  parameter definitions.
- IBR evidence: `ibr-model-validation-evidence` may cite a boundary-scan summary
  as the margin artifact; pass the report path explicitly.

## Artifact Manifest

The helper writes, and the summary lists in `artifact_manifest`:

```text
build/reports/f3_boundary_scan/<case>/
  stability_boundary_summary.json
  stability_boundary_summary.md
  scan_samples.csv
```

Keep these separate from P3/P4 impedance reports under
`build/reports/impedance/`. Namespace scratch/test cases so a stale artifact
cannot produce a false PASS in a later review.

## Failure Routing

- No documented operating point / units / seed: report provisional and request
  the metadata before quoting a margin.
- SCR-dependent boundary: route to `weak-grid-scr-scenario`.
- Controller-gain boundary: route to `power-electronics-tuning` (bandwidth /
  damping retune).
- GFL vs GFM boundary difference: route to `gfl-gfm-control-comparison` after
  computing comparable scans for both.
- Boundary outside the scanned region: widen the parameter ranges and rescan.
- Coarse / ambiguous crossing (multiple sign changes on one axis): refine the
  grid near the crossings before reporting a single boundary.
