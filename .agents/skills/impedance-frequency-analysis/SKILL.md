---
name: impedance-frequency-analysis
description: Use when deriving, reviewing, or validating impedance, admittance, frequency-response, resonance, harmonic-stability, or passivity evidence for Simulink power-electronics and converter-dominated power-system models, especially converter-grid interaction, weak-grid renewable interconnection, sub-synchronous/SSO oscillation, and IBR impedance-based stability studies. Complements small-signal-modal-analysis with frequency-domain evidence.
---

# Impedance / Frequency-Domain Analysis

Use this skill when a converter-grid interaction study needs frequency-domain
evidence: impedance/admittance curves, resonance peaks, a negative-resistance
(passivity) screen, or harmonic-stability margins. It complements modal analysis
by exposing interaction risk in the frequency domain rather than only the
eigenvalue domain.

## Core Rule

Impedance and frequency-response evidence describes the supplied data: a
measured sweep, a simulated injection sweep, or an analytic transfer function.
It does NOT by itself prove a physical instability and does NOT claim
hardware-level validation. A flagged resonance or negative-resistance band is a
risk indicator that must be confirmed with EMT/RMS time-domain validation and,
where available, modal evidence. Do not overclaim from spectral features alone.

## When To Use vs Modal Analysis

- Use `small-signal-modal-analysis` when you have a state matrix and want mode
  ownership (eigenvalues, damping, participation factors).
- Use this skill when you have a frequency-indexed response (impedance Z(f),
  admittance Y(f), or a transfer-function-like response) and want resonance,
  passivity, and harmonic-stability evidence.
- The two are independent evidence chains. Agreement between a modal mode and an
  impedance resonance at the same frequency is strong, non-circular evidence.

## Workflow

1. Confirm the evidence source and operating point: measured, simulated
   injection sweep, or analytic. Record it; an undocumented source makes the
   analysis provisional.
2. Assemble a frequency grid (`frequency_hz`, ascending, positive) and the
   complex positive-sequence response on that grid.
3. Choose the `Kind`: `impedance` (Z in ohms or pu), `admittance` (Y, inverted
   to Z internally), or `response` (generic; passivity screen is N/A).
4. Summarize: resonance peaks, per-band magnitude, and the negative-resistance
   passivity screen.
5. For each flagged resonance, map to a time-domain observable and, if a state
   matrix exists, to a modal mode before assigning a root cause.
6. Route weak-grid low-SCR resonance to `weak-grid-scr-scenario`; route
   GFL/GFM impedance-shape differences to `gfl-gfm-control-comparison`.

## Lab References

Treat the desktop lab archive as read-only ground truth. Impedance-relevant:

- Converter-grid interaction and weak-grid models where a measured or simulated
  impedance sweep is available or reconstructable.
- Use lab parameter sets and frequency bands of interest; never edit archive
  files. Use `lab-model-pattern-miner` only when checking the archive.

## Helper

Use the project helper when you already have a frequency-indexed response:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
summary = summarize_impedance_frequency_response(frequencyHz, Zf, ...
    "CaseName", "dfig_weakgrid_zsweep", ...
    "Kind", "impedance", ...
    "EvidenceSource", "simulated_injection", ...
    "OutputDir", "build/reports/impedance/dfig_weakgrid_zsweep");
```

The helper is pure base-MATLAB (no Signal Processing Toolbox): peak detection
uses a prominence-ratio rule, and the passivity screen flags `real(Z)<0` bands.
It does not run a Simulink sweep itself; supply the data.

## Output

Write impedance reports under:

```text
build/reports/impedance/<case>/
  impedance_summary.md
  impedance_summary.json
  frequency_response.csv
```

Read `references/impedance-contract.md` before changing metrics, peak/passivity
rules, band labels, or pass/fail wording.
