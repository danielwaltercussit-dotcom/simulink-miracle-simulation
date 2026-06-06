# MMC / HVDC Device Support Contract

Use this contract when generating or reviewing MMC/HVDC converter-station
evidence for Simulink/Simscape power-electronics studies. It is the durable
specification; the `summarize_mmc_hvdc_support` helper conforms to it.

## Required Metadata

Record (a missing required field downgrades that section and makes the package
provisional):

- `case_name` and `source_model_or_script`
- `station_topology`: `symmetric_monopole`, `asymmetric_monopole`, `bipole`, or
  `back_to_back`
- `submodule_type`: `half_bridge`, `full_bridge`, or `clamp_double`
- `n_submodules_per_arm` (positive integer)
- `submodule_capacitance_F`, `arm_inductance_H`
- `rated_power_MW`, `dc_voltage_kV`, `ac_voltage_kV`
- `model_fidelity`: `switching`, `arm_averaged`, `energy_averaged`, or `rms`
- `control_mode`: `pq`, `vdc_q`, `droop`, `gfm`, or `islanded`
- `modulation`: `nlc`, `psc_pwm`, `ps_pwm`, or `averaged_na`
- `capacitor_voltage_balancing`: `sorting`, `tolerance_band`, `closed_loop`, or
  `averaged_na`
- `circulating_current_control`: `ccsc`, `second_harmonic_suppression`, `none`,
  or `averaged_na`
- `dc_link_dynamics`: how DC voltage/cable/capacitor is represented (free text)
- `ac_fault_handling`: `current_limit_ride_through`, `block_and_restart`,
  `trip`, or `none`
- `dc_fault_handling`: `converter_blocking`, `dc_breaker`, `ac_breaker_clearing`,
  `ride_through`, or `none`
- `related_time_domain_run` or a required follow-up run

## Evidence Status

Reuse the project-wide per-section labels (see
`ibr-model-validation-evidence/references/evidence-contract.md`):

- `PASS`: required metadata present and the cross-checks for the section hold.
- `WARN`: present but flagged. Every WARN carries a `severity`:
  - `blocking`: the evidence asserts something physically impossible or
    self-contradictory (half-bridge claiming DC-fault converter blocking; an
    averaged-fidelity model carrying switching-level metadata; a malformed
    topology/fidelity field that invalidates downstream checks). A blocking WARN
    means the contract is `BLOCKED` and the package is NOT handoff-ready.
  - `advisory`: conformant but flagged for human attention (a plausibility-band
    miss, `circulating_current_control=none`, an unrecognized non-gating enum).
    Advisory WARNs do not block handoff.
- `MISSING`: a required field for the section is absent.
- `N/A`: not meaningful for the stated fidelity/topology (e.g. capacitor
  balancing for an `rms` model).

## Evidence Tiers (contract vs model vs hardware)

The summary reports three independent tiers; do not collapse them:

- `contract_status`: metadata completeness/consistency only.
  `PASS` (clean) / `WARN` (advisory only) / `BLOCKED` (>=1 blocking WARN) /
  `MISSING` (>=1 required field absent). Metadata can reach `PASS` here.
- `model_validation_status`: only set by an ACTUAL model probe supplied via the
  `ModelProbe` option (a real load/update/compile/simulate). `PASS` when the
  probe ran and passed, `WARN` when it ran but did not pass, `MISSING` when no
  probe was supplied. Metadata consistency can NEVER set this to `PASS`.
- `hardware_validation_status`: always `N/A` in software scope; never claimed.

`handoff_ready` is true only when the contract is clean enough (no `MISSING`
field and no `blocking` WARN) AND `model_validation_status == PASS`. Advisory
WARNs are allowed through (flagged for review, not correctness defects). A
correctness defect (blocking WARN), a missing required field, or an absent/
failed model-backed probe each keep the package out of handoff-ready — even
when no field is `MISSING`.

## Cross-Checks (the value beyond a checklist)

1. DC-fault vs submodule type. A `half_bridge` MMC cannot block DC-side fault
   current. If `dc_fault_handling` is `converter_blocking` while
   `submodule_type` is `half_bridge`, the DC-fault section is a `blocking` WARN
   (contract `BLOCKED`, not handoff-ready) with an explicit note that converter
   blocking needs `full_bridge`, `clamp_double`, a DC breaker (`dc_breaker`), or
   AC-side clearing (`ac_breaker_clearing`). `full_bridge` and `clamp_double`
   may claim `converter_blocking`.
2. Fidelity vs switching-level evidence. With `model_fidelity` in
   {`arm_averaged`, `energy_averaged`, `rms`}, switching-level claims
   (`modulation`, `capacitor_voltage_balancing`, switching-frequency
   circulating-current detail) are `N/A` and any non-`averaged_na`/non-`none`
   value there is a `blocking` WARN (averaged model claiming switching
   evidence).
3. Circulating current vs fidelity. `ccsc`/`second_harmonic_suppression` is
   meaningful for `switching`/`arm_averaged`; for `rms` it is `N/A`.
4. Modulation/balancing consistency. `averaged_na` modulation with a non-`na`
   balancing method (or vice versa) is a `blocking` WARN (mixed averaged/
   switching metadata).
5. Stored-energy plausibility. Arm stored energy per rated power for a real MMC
   HVDC station is typically ~20-50 kJ/MVA. Compute
   `E = 6 * N * 0.5 * C * Vc^2` with per-submodule voltage
   `Vc = Vdc / N` (so the arm capacitor stack supports the DC bus), and
   `energy_per_mva_kJ = E / rated_power_MW`. An `advisory` WARN outside
   [10, 80] kJ/MVA; report the value either way. This is a plausibility screen,
   not a design rule, so it does not block handoff on its own.

## Interpretation Rules

- The summary describes the supplied metadata and the consistency between
  fields. It does NOT by itself prove the model simulates correctly; a runnable
  model must be loaded/updated/simulated and linked.
- An averaged or RMS MMC model is valid evidence for slow DC-voltage,
  energy-balancing, and AC-side dynamics, but not for capacitor-voltage ripple,
  individual submodule balancing, or switching harmonics.
- Do not claim hardware/HIL-level validation from a software model.
- If `related_time_domain_run` is absent, the package is provisional and a
  time-domain run is the required follow-up.

## Relation To Other Evidence

- Fidelity: `model-fidelity-selector` owns the switching-vs-averaged decision;
  this pack records and cross-checks it, it does not re-derive it.
- Impedance: an MMC AC-terminal impedance sweep belongs in
  `impedance-frequency-analysis`; cite its report path.
- Modal: DC-voltage and arm-energy modes belong in
  `small-signal-modal-analysis`; agreement at a frequency is non-circular
  evidence.
- Weak grid: re-run at the low-SCR operating point from
  `weak-grid-scr-scenario` so resonance and fault evidence share an op-point.
- Packaging: `ibr-model-validation-evidence` may cite this summary as the
  device-level artifact; pass the report path explicitly.

## Failure Routing

- Half-bridge claiming DC-fault blocking: require full-bridge/clamp-double, a DC
  breaker, or AC-side clearing, and re-state the claim.
- Averaged model claiming switching evidence: route to `model-fidelity-selector`
  and either raise fidelity or drop the switching claim.
- Energy-per-MVA outside band: re-check N, C, and Vdc before trusting capacitor
  sizing.
- Missing time-domain run: route to `simulating-simulink-models` to produce it.
