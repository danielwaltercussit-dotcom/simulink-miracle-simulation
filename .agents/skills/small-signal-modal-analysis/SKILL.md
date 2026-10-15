---
name: small-signal-modal-analysis
description: Use when deriving, reviewing, or validating small-signal, Jacobian, eigenvalue, damping-ratio, participation-factor, or modal analysis for Simulink power-electronics and converter-dominated power-system models, especially DFIG, VSC, MMC, PLL, VSG, weak-grid, and lab reference mathematical models.
---

# Small-Signal Modal Analysis

Use this skill when time-domain results show oscillation, weak damping, or
control interaction and the next decision needs mode ownership rather than only
waveform inspection.

## Core Rule

Small-signal analysis explains local behavior around an operating point. It
does not replace EMT/RMS time-domain validation, fault recovery studies, or
large-signal current-limit checks.

## Lab References

Treat the desktop lab archive as read-only ground truth. Especially useful:

- M03 DFIG math oscillation model: symbolic Jacobian, 50 states, PLL/DC-link
  and DFIG state naming.
- M05 MMC plus four-machine two-area math model: symbolic Jacobian, 99 states,
  MMC PLL/DC capacitor and SG/network state structure.

## Workflow

1. Confirm the operating point and parameter set.
2. Obtain `A` from an existing math script, Symbolic Math Jacobian, or
   Simulink linearization.
   For the latter, use [simulink-linearize](../simulink-linearize/SKILL.md) to
   qualify I/O, state coverage, reduction, operating point, and release options.
3. Record the state order before computing eigenvalues.
4. Compute eigenvalues, damping ratios, damped frequencies, and participation
   factors where state names are available.
5. Map modes to time-domain observables using `diagnostic-plotting`.
6. When tuning direction matters, derive `dA/dp` analytically or by bounded
   central differences over registered control parameters, then compute
   `d(lambda)/dp` and `d(zeta)/dp`.
7. Route tuning or scenario work only after identifying the dominant state
   group and frequency band.

## Data-Driven Assistant Routing

Use `data-driven-simulation-assistant` only for candidate retrieval of similar
text reports, candidate modal-uncertainty labels, or candidate evidence gaps.
The deterministic modal contract owns final modal identity, damping
interpretation, participation claims, and any route toward tuning or scenario
changes.

## Helper

Use the project helper when you already have a numeric state matrix:

```matlab
projectRoot = getenv("SIMULINK_AGENT_ROOT");
if isempty(projectRoot), projectRoot = pwd; end
cd(projectRoot)
addpath("scripts/analysis")
summary = summarize_modal_eigs(A, ...
    "CaseName", "m03_dfig_pll_scan", ...
    "StateNames", stateNames, ...
    "OutputDir", "build/reports/modal/m03_dfig_pll_scan");
```

For parameter ranking, call
`scripts/analysis/summarize_modal_parameter_sensitivity.m` with an accepted
continuous-time `A`, or with a discrete `A` plus `MatrixDomain="discrete"` and
a positive `SampleTime`. Supply one `dA/dp` matrix per registered control
parameter, parameter values/scales, and bounds. The helper maps discrete poles
and derivatives into the continuous pole domain before computing damping
sensitivity. Its constrained least-norm step is a candidate direction only.
Apply at most one bounded candidate through
`power-electronics-tuning`, then re-linearize and confirm the predicted mode
before time-domain validation.

When analytic `dA/dp` is unavailable, use
`scripts/analysis/estimate_state_matrix_parameter_derivatives.m`. Supply a
model-owned callback that applies an in-memory parameter vector, restores it
after linearization, and returns `A` plus the operating-point vector. The helper
runs bounded central differences and flags one-sided steps or operating-point
drift; the user does not need to provide derivative data.

Do not finite-difference immutable plant ratings. If the operating point moves
materially between perturbations, report the sensitivity as provisional and
use `perturbation-stability-boundary-scan` instead of a local linear step.

## Output

Write modal reports under:

```text
build/reports/modal/<case>/
  modal_summary.md
  modal_summary.json
  eigenvalues.csv
```

Read `references/modal-contract.md` before changing metrics, state-group
labels, participation reporting, or pass/fail wording.
