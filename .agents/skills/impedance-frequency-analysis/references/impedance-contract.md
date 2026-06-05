# Impedance / Frequency-Domain Analysis Contract

Use this contract when generating or reviewing impedance and frequency-domain
evidence for converter-dominated systems.

## Required Metadata

Record:

- case name and source model/script
- evidence source: `measured`, `simulated_injection`, `analytic`, or `synthetic`
- operating point (load level, SCR/ESCR, control mode GFL/GFM) the sweep was
  taken at
- response kind: `impedance` (Z), `admittance` (Y), or generic `response`
- sequence/frame: positive-sequence assumed by the helper; note dq or
  sequence-coupled data explicitly because the scalar screen under-reports it
- frequency grid range, point count, and spacing (log vs linear)
- units (ohms, pu) and base values if pu
- related time-domain run or required follow-up run

## Metrics

For each reported resonance include:

- frequency in Hz
- magnitude at the peak
- prominence ratio (peak / reference valley)
- estimated -3 dB bandwidth and Q factor
- frequency band bucket

System-level outputs:

- per-band peak and mean magnitude
- negative-resistance passivity screen: applicable flag, negative-resistance
  flag, point count, and the negative band edges in Hz
- dominant resonance frequency

## Frequency Bands

Use consistent band names:

- `subsync_lt_1Hz` sub-synchronous / inter-area band
- `low_1_10Hz` electromechanical / slow control band
- `mid_10_100Hz` sub-synchronous-to-synchronous converter-grid band
- `high_100_1000Hz` switching-harmonic / fast-control band
- `vhf_gt_1000Hz` very-high-frequency band

## Interpretation Rules

- A resonance peak is a spectral feature of the supplied data, not a proven
  instability. Confirm with time-domain (EMT/RMS).
- `real(Z) < 0` over a band is the classic harmonic-instability / negative-
  resistance risk for grid-following converters; flag it but do not declare
  instability without a time-domain or Nyquist/aggregate-impedance check.
- A single positive-sequence scalar impedance can miss dq-frame or sequence-
  coupled instabilities; state this limitation when the data is scalar.
- Q factor from a 3-point grid is approximate; refine the grid near a peak
  before quoting a sharp Q.
- If the evidence source or operating point is undocumented, the analysis is
  provisional.
- Do not claim hardware-level validation from simulated or analytic sweeps.

## Relation To Other Evidence

- Modal: an impedance resonance and a low-damping modal eigenvalue at the same
  frequency are agreeing, non-circular evidence. Disagreement means at least one
  chain is missing a mechanism; investigate before concluding.
- Weak-grid: re-run the impedance summary at the low-SCR operating point used by
  `weak-grid-scr-scenario` so resonance and large-disturbance evidence share an
  operating point.
- IBR evidence: `ibr-model-validation-evidence` may cite an impedance summary as
  the frequency-domain artifact; pass the report path explicitly.

## Failure Routing

- No documented operating point: report provisional and request the point.
- Negative-resistance band found: route to `power-electronics-tuning`
  (controller bandwidth / damping) and to `weak-grid-scr-scenario` if it is
  SCR-dependent.
- Resonance near a known switching or control frequency: review the controller
  and filter design rather than the grid.
- GFL vs GFM impedance-shape difference: route to `gfl-gfm-control-comparison`
  after computing comparable impedance summaries for both.
- Scalar data but suspected dq coupling: request dq-frame or sequence-domain
  impedance before a stability claim.
