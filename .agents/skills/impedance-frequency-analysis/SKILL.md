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
- Frequency coincidence alone does not establish modal ownership. A response
  derived from the same A matrix is a consistency check, not independent
  evidence. Match states, I/O, and operating point, then seek an independent
  injection or time-domain observation before claiming corroboration.

## Workflow

1. Confirm the operating point and evidence source. When external frequency
   data is absent, create a temporary non-persistent injection hook or a copied
   probe model and run `scripts/analysis/run_frequency_injection_sweep.m`.
   Never wait for the user to manufacture `Z(f)` when the model exposes a safe
   injection and measurement boundary.
2. Assemble a frequency grid (`frequency_hz`, ascending, positive). A scalar
   positive-sequence response is an initial screen only; use independent
   dq/sequence injections and the MIMO route when coupling is relevant.
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
projectRoot = getenv("SIMULINK_AGENT_ROOT");
if isempty(projectRoot), projectRoot = pwd; end
cd(projectRoot)
addpath("scripts/analysis")
summary = summarize_impedance_frequency_response(frequencyHz, Zf, ...
    "CaseName", "dfig_weakgrid_zsweep", ...
    "Kind", "impedance", ...
    "EvidenceSource", "simulated_injection", ...
    "OutputDir", "build/reports/impedance/dfig_weakgrid_zsweep");
```

The helper is pure base-MATLAB (no Signal Processing Toolbox): peak detection
uses a prominence-ratio rule, and the passivity screen flags `real(Z)<0` bands.
For existing data, supply it directly. For model-backed data, use
`run_frequency_injection_sweep` with a trial callback that sets the injection,
runs the bounded model trial, and returns `time`, `input`, and `output`; feed its
`response_complex` into this helper. Use enough settling and measurement cycles,
check the reported sinusoidal-fit quality, refine near peaks, and restore every
temporary model change.

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

For MMC periodic dynamics or multi-converter network interaction, read the
matched PE-02/04 card in
[converter fault analysis](../simulink-modeling-assistant/references/converter-fault-analysis.md).
HSS guidance does not mean the scalar helper implements harmonic lifting.
