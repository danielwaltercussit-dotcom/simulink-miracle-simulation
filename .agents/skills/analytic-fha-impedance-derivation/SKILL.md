---
name: analytic-fha-impedance-derivation
description: Use when deriving analytic or fundamental-frequency-analysis (FHA) equivalent models and closed-form impedance/admittance Z(jw) transfer functions for Simulink power-electronics and converter-dominated systems, then linking that analytic derivation to Bode/resonance evidence and a time-domain validation run. Use this BEFORE trusting a simulated impedance sweep or a time-domain result whose mechanism is not yet understood analytically. Complements (does not replace) impedance-frequency-analysis, which summarizes a response you already have.
---

# Analytic FHA / Impedance Derivation

Use this skill to derive impedance/admittance evidence **analytically** from a
stated topology and operating point, rather than summarizing a sweep you already
have. The point is to close the loop between time-domain simulation and
first-principles frequency-domain reasoning: an FHA-style equivalent model, a
closed-form `Z(jw)` or `Y(jw)`, and the resonances/poles it predicts.

## Core Rule

Analytic and FHA evidence is only as trustworthy as the **stated topology,
operating point, and approximation band**. A closed-form transfer function can
be exact for the model you wrote down and still be wrong about the real
converter, because FHA neglects harmonics, large-signal nonlinearity,
saturation, and dq/sequence coupling. So:

- An analytic resonance (pole) is a prediction, not a proven instability.
  Confirm it against an EMT/RMS time-domain run and, where available, modal
  evidence.
- State the frequency band where the fundamental-frequency / linear small-signal
  approximation is trusted. Above that band (typically near half the switching
  frequency), the analytic curve is out of contract.
- If topology, operating point, units, or the FHA validity bound are
  undocumented, the derivation is **provisional** and must not back a stability
  claim.
- Never claim hardware-level validation from an analytic derivation.

## When To Use vs The Other Frequency-Domain Skills

- Use **this skill** (`analytic-fha-impedance-derivation`) when you are
  *deriving* `Z(jw)` from a topology / transfer function / RLC network and want
  the analytic poles, the FHA validity band, and a derivation contract.
- Use **`impedance-frequency-analysis`** (P3) when you already *have* a
  frequency-indexed response (measured, simulated injection, or a curve from
  this skill) and want resonance/passivity/band screening of that data.
- Use **`small-signal-modal-analysis`** when you have a state matrix and want
  eigenvalue/participation evidence.

These are independent chains. The strongest result is when an analytic pole, a
P3 impedance resonance, and a modal eigenvalue agree at the same frequency.

## Relation To Existing P3/P4 Impedance Work (read-only here)

This skill does **not** rewrite the P3/P4 stack. Treat
`.agents/skills/impedance-frequency-analysis/` and its
`references/impedance-contract.md` as read-only context. This skill reuses the
same canonical frequency-band labels and the same `real(Z)<0` passivity screen
on purpose, so an analytic curve and a P3-summarized sweep are directly
comparable. Integration path: derive `Z(jw)` here, then hand the curve to the P3
helper for cross-checking, or cite this analytic summary as the
frequency-domain artifact in `ibr-model-validation-evidence` (P4).

## Workflow

1. State the topology assumptions and operating point. Undocumented => the
   result is provisional.
2. Pick the model form:
   - `transfer_function`: give `num`/`den` polynomials in `s` so `Z(s)` (or a
     generic response) is exact; analytic poles are reported directly.
   - `rlc_branches`: give parallel series-RLC branches; `Z` is assembled from
     `1/sum(1/Z_branch)`.
3. State the FHA validity bound: either `SwitchingHz` (band defaults to half of
   it) or an explicit `ValidUpToHz`. Without one, the FHA band is undocumented
   and the result is provisional.
4. Derive the curve and read the analytic resonances, the FHA in-band fraction,
   and the passivity screen.
5. For each analytic resonance, name the time-domain observable that would
   confirm it, and record the related/required time-domain run.
6. Cross-check with P3 (summarize the same curve) and modal evidence before any
   stability statement.
7. When a measured/simulated sweep exists, run `compare_fha_measured_impedance`
   to grade the model against the data (in-band fit vs FHA bound). Treat
   `contract_only` as "not yet data-validated", not as a pass.

## Helper

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")

model.type = "rlc_branches";
model.branches = struct("R", {100, 0, 0}, "L", {0, 0.28, 0}, "C", {0, 0, 100e-6});

summary = summarize_fha_impedance_response( ...
    "Model", model, ...
    "CaseName", "lcl_filter_zsweep", ...
    "FreqMinHz", 1, "FreqMaxHz", 2000, "NPoints", 400, "Spacing", "log", ...
    "TopologyAssumptions", "parallel R||L||C filter, single-phase equivalent", ...
    "OperatingPoint", "rated load, GFL, SCR=3", ...
    "Units", "ohm", "BaseValues", "Sbase=2MVA Vbase=690V", ...
    "SequenceFrame", "positive_sequence", ...
    "FundamentalHz", 50, "SwitchingHz", 4000, ...
    "RelatedTimeDomainRun", "build/reports/emt/lcl_step", ...
    "OutputDir", "build/reports/f1_fha_impedance/lcl_filter_zsweep");
```

Pure base-MATLAB (no toolbox): poles come from `roots`, the curve from
`polyval`/branch algebra. It does not run Simulink; it derives the analytic
response you specify.

## Output

```text
build/reports/f1_fha_impedance/<case>/
  fha_impedance_summary.md
  fha_impedance_summary.json
  fha_frequency_response.csv
```

Read `references/fha-impedance-contract.md` before changing the required
metadata, the FHA-validity logic, the band labels, or the provisional/PASS
wording.

## Comparing The Analytic Model Against Measured / Simulated Data

A derivation alone is contract-consistent, not data-validated. When you have a
measured or simulated-injection frequency sweep, use the comparison helper to
quantify how well the analytic model reproduces it and whether the agreement
lies inside the FHA validity band:

```matlab
% measuredHz, measuredZ are the supplied sweep (e.g. from a P3 injection run)
cmp = compare_fha_measured_impedance(model, measuredHz, measuredZ, ...
    "MeasuredSource", "simulated_injection", ...
    "TopologyAssumptions", "parallel R||L||C filter", ...
    "OperatingPoint", "rated load, GFL, SCR=3", "Units", "ohm", ...
    "ValidUpToHz", 1000, "MagTolPct", 10, "PhaseTolDeg", 10, ...
    "OutputDir", "build/reports/f1_fha_impedance/lcl_compare");
```

It derives the analytic curve on the supplied grid (reusing the derivation
helper's second output, not re-deriving), then reports magnitude rel-error,
wrapped phase error, normalized complex error, and magnitude R^2 — split into
in-band and out-of-band against the FHA bound. The headline is an
`evidence_grade`:

- `contract_only` — provisional, or no points inside the FHA band, so the model
  cannot be data-validated here.
- `data_backed` — in-band fit within tolerance against documented data.
- `data_backed_mismatch` — documented in-band data, but the analytic model does
  NOT meet tolerance (an honest negative; revisit topology/operating point).

The helper NEVER returns a hardware-backed grade: matching a simulated or even a
measured small-signal sweep is not HIL/field validation. Out-of-band errors are
still reported but never upgrade the grade.

Comparison output:

```text
build/reports/f1_fha_impedance/<case>/
  fha_comparison_summary.md
  fha_comparison_summary.json
  fha_comparison_points.csv
```

## Lab References

Treat the desktop lab archive as read-only ground truth for topology values,
base values, and operating points. Use its parameter sets to populate the
derivation contract; never edit, copy, or move archive files. Do not restore or
recreate `NEBUS39V2.slx`.
