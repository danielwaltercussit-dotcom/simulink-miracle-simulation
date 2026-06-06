---
name: device-pack-mmc-hvdc
description: Use when modeling, reviewing, or validating Modular Multilevel Converter (MMC) and HVDC converter-station evidence in Simulink/Simscape, including submodule type (half-bridge/full-bridge/clamp-double), arm energy and capacitor sizing, circulating-current suppression, DC-link/DC-voltage dynamics, AC and DC fault handling, station control mode (P/Q, Vdc, droop, GFM), and the fidelity boundary between switching-level and arm-averaged MMC models.
---

# MMC / HVDC Device Support Pack

Use this skill when a study involves an MMC-based HVDC converter station and you
must connect device assumptions (submodule type, arm energy, circulating-current
control, DC-link dynamics, fault handling, control mode) to validation evidence.
It is the MMC/HVDC sibling of `device-pack-vsc-gfl-gfm`; route generic two-level
VSC GFL/GFM questions there and keep this branch MMC/HVDC-specific.

## Core Rule

Describe the converter you actually modeled, not the converter you wish you had.
An MMC evidence claim is only as strong as the consistency between its submodule
type, modulation/balancing method, fidelity level, and fault-handling claim. The
most common silent error is claiming DC-fault blocking from a half-bridge MMC:
half-bridge submodules cannot interrupt DC-side fault current (the freewheeling
diodes still conduct), so a DC-fault clearing claim needs full-bridge or
clamp-double submodules, a DC breaker, or AC-side clearing. Do not let an
averaged model claim switching-level circulating-current or capacitor-balancing
evidence.

## When To Use vs Neighboring Skills

- Two-level VSC, PLL/GFL vs VSG/GFM control comparison: `device-pack-vsc-gfl-gfm`.
- Choosing switching vs averaged vs RMS fidelity: `model-fidelity-selector`.
- Frequency-domain impedance / resonance evidence: `impedance-frequency-analysis`.
- Eigenvalue / damping / mode ownership: `small-signal-modal-analysis`.
- Weak-grid SCR/ESCR scenarios at the AC terminal: `weak-grid-scr-scenario`.
- Packaging the final handoff evidence set: `ibr-model-validation-evidence`.

## Workflow

1. Record station identity and topology: symmetric/asymmetric monopole, bipole,
   or back-to-back; submodule type; submodules-per-arm N; arm inductance and
   submodule capacitance; rated power; DC and AC voltage.
2. Pick and record the model fidelity: switching-level, arm-averaged (Type 4/5),
   energy-based averaged, or RMS/phasor. This gates which evidence is even
   meaningful.
3. State the control mode (P/Q, Vdc-Q, droop, GFM/VSG, islanded) and modulation
   plus capacitor-voltage balancing (NLC sorting, PSC-PWM, tolerance band, or
   averaged-model N/A).
4. State circulating-current handling (CCSC / 2nd-harmonic suppression, or none)
   and DC-link dynamics (DC-voltage control, DC capacitor/cable model, droop).
5. State AC-fault ride-through and DC-fault handling, and cross-check DC-fault
   handling against submodule type.
6. Summarize with `summarize_mmc_hvdc_support`, then attach time-domain,
   modal, and impedance evidence. Confirm a runnable model by load/update/sim;
   never claim MMC validation from text alone.

## Lab References

Treat the desktop lab archive as read-only ground truth. Use MMC/HVDC station
parameter sets, submodule counts, arm sizing, and fault scenarios from it for
patterns and plausibility bands; never edit, copy, or move archive files. Do not
restore `NEBUS39V2.slx`; it is intentionally absent as privacy-sensitive.

## Helper

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
evidence = struct( ...
    "case_name","mmc_hvdc_symmonopole", ...
    "source_model_or_script","models/mmc_station.slx", ...
    "station_topology","symmetric_monopole", ...
    "submodule_type","half_bridge", ...
    "n_submodules_per_arm",200, ...
    "submodule_capacitance_F",10e-3, ...
    "arm_inductance_H",50e-3, ...
    "rated_power_MW",1000, ...
    "dc_voltage_kV",640, ...
    "ac_voltage_kV",333, ...
    "model_fidelity","switching", ...
    "control_mode","vdc_q", ...
    "modulation","nlc", ...
    "capacitor_voltage_balancing","sorting", ...
    "circulating_current_control","ccsc", ...
    "dc_link_dynamics","dc_voltage_control_with_cable", ...
    "ac_fault_handling","current_limit_ride_through", ...
    "dc_fault_handling","ac_breaker_clearing", ...
    "related_time_domain_run","build/reports/.../emt_run.json");
summary = summarize_mmc_hvdc_support(evidence, ...
    "OutputDir","build/reports/d2_mmc_hvdc/mmc_hvdc_symmonopole");
```

The helper is pure base-MATLAB (no toolbox dependency). It validates the
contract metadata, runs the submodule/DC-fault and fidelity cross-checks,
computes a stored-energy-per-MVA plausibility figure, and emits PASS/WARN/
MISSING/N/A per section. Every WARN has a `severity`: `blocking` (a physical
impossibility or fidelity contradiction) or `advisory` (conformant but flagged).

It reports three independent evidence tiers, kept separate on purpose:

- `contract_status` (metadata consistency): PASS / WARN / BLOCKED / MISSING.
- `model_validation_status`: only set by an actual model probe passed via the
  `ModelProbe` option. Metadata alone can NEVER make this PASS.
- `hardware_validation_status`: always `N/A` (software scope).

`handoff_ready` is true only when the contract is clean enough (no MISSING
field and no blocking WARN) AND `model_validation_status == PASS`. Advisory
WARNs (e.g. an energy plausibility-band miss) are allowed through. A half-bridge
station that claims DC-fault converter blocking is a blocking WARN, so it is
`BLOCKED` and never handoff-ready even though no field is missing.

To attach model-backed evidence, run a real load/update/compile/sim and pass the
outcome:

```matlab
probe = run_mmc_dc_link_probe();   % see skill assets/ fixture below
summary = summarize_mmc_hvdc_support(evidence, ...
    "ModelProbe", probe, ...
    "OutputDir", "build/reports/d2_mmc_hvdc/mmc_hvdc_symmonopole");
```

A small non-private runnable MMC DC-link fixture and its probe live under
`assets/` in this skill (`build_mmc_dc_link_fixture.m`,
`run_mmc_dc_link_probe.m`). It builds, updates, and simulates a programmatically
generated Simscape Electrical model; it does not depend on any lab/private
model. Use it as the reference pattern for wiring a real model probe.

## Output

```text
build/reports/d2_mmc_hvdc/<case>/
  mmc_hvdc_support.md
  mmc_hvdc_support.json
```

Read `references/mmc-hvdc-contract.md` before changing required metadata,
status rules, cross-check logic, or the energy plausibility band.
