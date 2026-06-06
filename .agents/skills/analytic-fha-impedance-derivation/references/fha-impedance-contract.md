# Analytic FHA / Impedance Derivation Contract

Use this contract when deriving or reviewing analytic / fundamental-frequency
analysis (FHA) impedance evidence for converter-dominated systems. It is the
analytic counterpart to `impedance-frequency-analysis/references/impedance-contract.md`
(P3); the two intentionally share frequency-band labels and the passivity
screen so an analytic curve and a measured/simulated sweep are comparable.

## Required Metadata

Record, or the derivation is provisional:

- case name
- model form: `transfer_function` (num/den in s) or `rlc_branches`
- response kind: `impedance` (Z), `admittance` (Y, inverted to Z), or generic
  `response` (no Z/Y physics; passivity screen N/A)
- topology assumptions (what network/equivalent was written down, and what was
  neglected: harmonics, saturation, dq/sequence coupling)
- operating point (load level, SCR/ESCR, control mode GFL/GFM) the linearization
  is taken at
- units (ohm, pu) and base values if pu
- sequence/frame: positive-sequence assumed unless stated; flag dq or
  sequence-coupled derivations explicitly
- fundamental frequency (Hz) and, where relevant, switching frequency (Hz)
- FHA validity bound (see below)
- frequency grid range, point count, and spacing (log / linear / nonuniform)
- related time-domain run, or the follow-up run that must confirm the analytic
  prediction

## FHA Validity Band

The fundamental-frequency / linear small-signal approximation is only trusted
over a bounded band. Record the bound and its basis:

- `explicit_valid_up_to` — caller supplied `ValidUpToHz` directly.
- `half_switching_frequency` — bound defaulted to `SwitchingHz/2` (a
  Nyquist-style ceiling for averaged/FHA converter models).
- undocumented — neither supplied. The FHA band is unknown, the in-band
  fraction is `NaN`, and the result is **provisional**.

Features above the bound (e.g. switching harmonics) are NOT covered by the
analytic model and must not be interpreted as physical resonances without a
switching-level EMT confirmation.

## Metrics

For each analytic resonance:

- frequency in Hz
- magnitude at the resonance
- `source`: `analytic_pole` (exact, from the transfer-function denominator) or
  `magnitude_peak` (prominence-ratio screen fallback when no analytic pole lies
  inside the grid)
- estimated -3 dB bandwidth and Q factor (grid-limited; refine the grid near a
  sharp pole before quoting Q)
- frequency band bucket

System-level outputs:

- per-band peak and mean magnitude
- negative-resistance passivity screen: applicable flag, negative-resistance
  flag, point count, negative band edges in Hz
- dominant resonance frequency

## Frequency Bands

Identical labels to the P3 contract:

- `subsync_lt_1Hz`
- `low_1_10Hz`
- `mid_10_100Hz`
- `high_100_1000Hz`
- `vhf_gt_1000Hz`

## Interpretation Rules

- An analytic pole is exact **for the model you wrote down**, not for the real
  converter. Confirm with a time-domain (EMT/RMS) run before any instability
  claim.
- `real(Z) < 0` over a band is the negative-resistance / harmonic-instability
  risk; flag it but route to time-domain and Nyquist/aggregate-impedance checks.
- A positive-sequence scalar derivation can miss dq-frame or sequence-coupled
  instabilities; state this when the derivation is scalar.
- If topology, operating point, units, or the FHA validity bound are
  undocumented, the analysis is provisional and must not back a stability claim.
- Do not claim hardware-level validation from an analytic derivation.

## Measured-Data Comparison (compare_fha_measured_impedance)

When a measured or simulated frequency sweep is supplied, the comparison helper
derives the analytic curve on the SAME grid and grades the agreement. Required
metadata adds `measured_source` (provenance) to the derivation contract;
undocumented provenance makes the comparison provisional.

Reported metrics, computed overall and split in-band vs out-of-band against the
FHA bound:

- magnitude relative error (%) RMSE and max
- wrapped phase error (deg) RMSE and max, wrapped to (-180, 180]
- normalized complex error `|Z_fha - Z_meas| / |Z_meas|` RMSE and max
- magnitude R^2 (overall)

Evidence grade (the headline; never silently inflated):

- `contract_only` — provisional, OR zero points inside the FHA band. The model
  is not data-validated; out-of-band error is reported but does not upgrade it.
- `data_backed` — in-band magnitude RMSE <= `MagTolPct` AND in-band phase RMSE
  <= `PhaseTolDeg`, against documented data.
- `data_backed_mismatch` — documented in-band data present but tolerance not
  met. This is an honest negative result, NOT an error; route back to topology /
  operating-point assumptions.

The helper must never emit a hardware-backed grade. A simulated-injection or
even a bench small-signal sweep is not HIL/field validation; that distinction is
deliberate and the limitations note states it.

## Relation To Other Evidence

- P3 `impedance-frequency-analysis`: derive `Z(jw)` here, then summarize the
  same curve through the P3 helper. Agreement between the analytic poles and the
  P3 resonances is a self-consistency check; disagreement means the grid, the
  topology, or the operating point differ.
- Modal: an analytic pole and a low-damping modal eigenvalue at the same
  frequency are agreeing, non-circular evidence.
- Weak-grid: derive at the low-SCR operating point used by
  `weak-grid-scr-scenario` so analytic and large-disturbance evidence share an
  operating point.
- IBR evidence: `ibr-model-validation-evidence` (P4) may cite this analytic
  summary as the frequency-domain artifact; pass the report path explicitly and
  expect a provisional analytic summary to be downgraded, not treated as PASS.

## Failure Routing

- Missing required metadata: report provisional and request the missing field.
- Negative-resistance band found: route to `power-electronics-tuning` and to
  `weak-grid-scr-scenario` if SCR-dependent.
- Analytic pole near a known switching/control frequency: review controller and
  filter design rather than the grid.
- GFL vs GFM impedance-shape difference: route to `gfl-gfm-control-comparison`
  after deriving comparable analytic curves for both.
- Scalar derivation but suspected dq coupling: derive (or request) a dq-frame /
  sequence-domain model before a stability claim.
