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
3. Record the state order before computing eigenvalues.
4. Compute eigenvalues, damping ratios, damped frequencies, and participation
   factors where state names are available.
5. Map modes to time-domain observables using `diagnostic-plotting`.
6. Route tuning or scenario work only after identifying the dominant state
   group and frequency band.

## Helper

Use the project helper when you already have a numeric state matrix:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
summary = summarize_modal_eigs(A, ...
    "CaseName", "m03_dfig_pll_scan", ...
    "StateNames", stateNames, ...
    "OutputDir", "build/reports/modal/m03_dfig_pll_scan");
```

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
