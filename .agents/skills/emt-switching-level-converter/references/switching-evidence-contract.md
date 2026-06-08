# EMT / Switching-Level Converter Evidence Contract

Use this contract when generating or reviewing switching-level (detailed) EMT
waveform evidence for converter-dominated systems.

## Required Metadata

Record:

- case name and source model/script
- signal kind: `current`, `voltage`, or generic `signal`
- fundamental frequency (Hz)
- carrier / switching frequency (Hz)
- fixed-step sample time (s) of the captured waveform
- solver description (e.g. fixed-step discrete, ode23tb local) and solver step
- dead-time / blanking time (s)
- modulation method: `SPWM`, `SVPWM`, `DPWM`, `hysteresis`, or documented other
- device-loss mode: `ideal`, `on-resistance`, `on-resistance+Vf`, or a
  switching-loss model; ideal switches cannot support a loss claim
- units (A, V, pu) and base values if pu
- transient event window (start/end s) the evidence is meant to judge
- related averaged/RMS run or required follow-up run

A waveform with undocumented carrier, sample time, or modulation method is
`provisional`: report it, but do not use it for harmonic, loss, or protection
claims.

## Metrics

System-level outputs:

- fundamental magnitude and frequency (located near `FundamentalHz`)
- THD as a fraction and percent (harmonic bins of the fundamental, up to a
  documented max harmonic)
- per-harmonic magnitude table (order, frequency, magnitude, fraction of
  fundamental) for the reported harmonics
- carrier-band content: magnitude near `CarrierHz` and its first sidebands,
  expressed relative to the fundamental
- ripple metric over the event window (peak-to-peak and RMS of the
  fundamental-removed signal) when an event window is supplied

## Discretization Adequacy

Compute and report:

- `samples_per_carrier = 1 / (carrier_hz * sample_time_s)`
- `nyquist_hz = 1 / (2 * sample_time_s)` and the highest harmonic it resolves
- `deadtime_steps = dead_time_s / sample_time_s`

Adequacy flags:

- `WARN` undersampled when `samples_per_carrier < 20`
- `WARN` aliasing risk when the max harmonic of interest exceeds `nyquist_hz`
- `WARN` unrepresented dead-time when `deadtime_steps < 1` but dead-time > 0
- `WARN` sample-time mismatch when a documented `sample_time_s` disagrees with
  the waveform's own median grid step beyond a relative tolerance (default 5%).
  The metadata is treated as stale; the spectrum uses the grid step, not the
  declared one, and `sample_time_mismatch` records declared/inferred/rel_error.

## Evidence Provenance and model_backed

Switching evidence carries a provenance block and a single `model_backed` flag
so a synthetic curve can never be mistaken for a model or hardware result.

- `source_type`: `simulation_output`, `mat_file`, `generated`, `captured`, or
  `synthetic`. Unknown tags collapse to `synthetic`.
- `evidence_level`:
  - `model_backed` - a real simulation/model source, identified, not synthetic;
  - `model_referenced` - a model source that is not fully substantiated;
  - `contract_only` - synthetic/generated data that validates the contract only.
- `model_backed = true` requires ALL of: the caller asserts it, `source_type`
  is a model source (`simulation_output`/`mat_file`), a `source_id` is recorded,
  and the run is NOT flagged `synthetic`. Any shortfall forces `model_backed =
  false` and records `downgrade_reasons` (provenance downgrade).
- The summarizer is the single authority for this decision; the ingestion
  helper only asserts the declared source type. A synthetic-only run that
  asserts `model_backed` is downgraded with an explicit reason, never silently.
- Hardware-backed evidence is a separate, higher bar: it is NOT implied by
  `model_backed` and must be supplied as real HIL/hardware capture, not inferred
  from a simulation.

## Interpretation Rules

- A switching waveform proves what the discretization resolves and no more.
  Aliased or undersampled content is not harmonic evidence.
- THD and per-harmonic numbers are meaningful only when the fundamental is well
  located and the grid resolves the reported harmonics.
- A device-loss claim requires a non-ideal `device_loss_mode`. With ideal
  switches, report loss as N/A, not zero.
- Dead-time effects below one fixed step are not represented; do not report a
  dead-time distortion the grid cannot resolve.
- A carrier-band magnitude that rivals the fundamental usually means a filter or
  modulation problem, not a grid problem.
- If carrier, sample time, or modulation method is undocumented, the analysis is
  provisional.
- Do not claim hardware-level validation from a simulated waveform.

## Status Wording

- `PASS` documented metadata, adequate discretization, fundamental located.
- `WARN` provisional metadata, OR an adequacy flag fired (undersampled, aliasing
  risk, or unrepresented dead-time), OR fundamental poorly located.
- `MISSING` waveform supplied but empty/too short to transform.
- `N/A` a metric that does not apply to the supplied signal/loss mode.

## Device-Loss and Thermal Evidence

Loss and thermal evidence (`summarize_device_loss_thermal_evidence`) is reported
per metric, each with its own evidence level:

- conduction loss: `model_backed` only when integrated from an actual non-ideal
  model run; `contract_only` for a declared placeholder; N/A for an ideal device.
- switching loss: an estimate from per-event energy x counted event rate is
  `model_referenced`, not `model_backed`; absent inputs leave it `not_assessed`
  (it does not penalise the status).
- total loss: takes the WEAKEST contributing evidence level.
- thermal rise: a first-order Tj = Ta + P*Rth (with tau = Rth*Cth when Cth is
  given) is a modelling estimate. It inherits the loss level but is CAPPED at
  `model_backed`; a junction temperature is never `hardware_backed` without
  measured temperature data.

Rules:

- An ideal device (`Ron = Vf = 0`) yields loss and thermal N/A, never 0 W / 0 C.
- A model-backed dead-time effect requires `dead_time_steps >= 1`; below one
  fixed step the dead-time is reported but not claimed as represented.
- Contract-pass, model-validation-pass, and hardware-validation-pass are
  distinct: a green contract test does not imply a model ran, and a model run
  does not imply hardware behaviour.

## Relation To Other Evidence

- Fidelity: `model-fidelity-selector` decides whether switching-level EMT is
  warranted at all; this contract assumes that decision was made and recorded.
- Averaged equivalence: when an averaged model is meant to replace this waveform
  above the bandwidth of interest, the averaged model must document the loss and
  ripple assumptions this evidence measured.
- Impedance: route switching-harmonic resonance suspicion to
  `impedance-frequency-analysis`; a carrier-band peak there and here at the same
  frequency is agreeing evidence.
- IBR evidence: `ibr-model-validation-evidence` may cite a switching summary as
  the switching-level artifact; pass the report path explicitly.

## Failure Routing

- Undocumented carrier or sample time: report provisional and request them.
- Undersampled / aliasing flag: refine the fixed step before quoting THD.
- Carrier-band content near the fundamental: review filter and modulation design
  rather than the grid.
- Loss claim with ideal switches: request a non-ideal device model before
  reporting loss.
- Dead-time below one step: refine the step or drop the dead-time claim.
