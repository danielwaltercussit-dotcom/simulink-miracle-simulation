---
name: device-pack-storage-bms
description: Use when modeling, reviewing, or validating battery energy storage systems (BESS), battery/BMS behavior, or bidirectional grid-storage converters in Simulink power-electronics and converter-dominated power-system studies. Covers SOC/SOH, thermal limits, protection, grid-support mode, DC-link interactions, and the evidence boundary between true battery/BMS evidence and generic DC-link converter evidence. Complements device-pack-vsc-gfl-gfm and impedance-frequency-analysis.
---

# Storage / Battery / BMS Device Support

Use this skill when a study involves a battery energy storage system: a battery
plus its BMS, a bidirectional DC-DC or grid-side converter, and a grid-support
control mode. It connects storage-specific assumptions (SOC/SOH, thermal,
protection) to the shared evidence chains (weak-grid, modal, impedance,
time-domain) without pretending a generic converter model already covers the
battery.

## Core Rule

A storage support summary describes declared assumptions and evidence-artifact
pointers. It does NOT run a Simulink model and does NOT prove a physical result.
A PASS means the assumption is documented or the named artifact pointer is
present and same-study; it never proves SOC accuracy, thermal safety, or
stability by itself. Storage claims still need the named time-domain (EMT/RMS)
evidence and, where applicable, modal/impedance evidence.

## The Battery/BMS vs DC-Link Boundary

This is the package's central discipline. A converter model with a stiff DC
voltage source on the DC link is NOT a battery model. Do not let generic
DC-link converter evidence stand in for battery/BMS evidence.

- **Battery/BMS evidence** is specific to the cell/pack and its management:
  state of charge (SOC), state of health (SOH), open-circuit-voltage curve,
  internal resistance, cell/pack thermal model, and BMS protection logic
  (overvoltage, undervoltage, overcurrent, over/under-temperature, SOC limits).
- **DC-link converter evidence** is the bidirectional power-electronics
  interface: DC-link voltage regulation, capacitor sizing, charge/discharge
  current control, and grid-side active/reactive control.

If a case supplies only DC-link converter evidence, the battery/BMS dimensions
must read MISSING (when required) — not PASS. The helper enforces this so a
study cannot claim battery validation from a constant-DC-source converter run.

## Workflow

1. Confirm the case identity: chemistry/model type, rated energy/power, DC-link
   topology, and grid-support mode. Undocumented identity makes the case
   provisional.
2. Declare battery/BMS evidence separately from DC-link converter evidence. Each
   has its own artifact pointer and required flag.
3. Record SOC/SOH operating window, thermal limits, and protection thresholds.
4. Declare the grid-support mode (peak shaving, frequency response, PCS
   voltage/var, black start) and route control-mode questions to
   `device-pack-vsc-gfl-gfm`.
5. Summarize per-dimension PASS/WARN/MISSING/N/A and a battery-vs-DC-link
   separation screen.
6. For each grid-interaction claim, map to the named time-domain run and, where
   relevant, to impedance (`impedance-frequency-analysis`) and modal
   (`small-signal-modal-analysis`) evidence.

## When To Use vs Other Device Packs

- Use `device-pack-vsc-gfl-gfm` for the grid-side converter sync paradigm
  (GFL/GFM, PLL/VSG) and weak-grid SCR sensitivity. A BESS grid-side converter
  reuses that evidence; this pack adds the battery/BMS and DC-link layer beneath
  it.
- Use `device-pack-mmc-hvdc` for MMC submodule/arm-energy studies; do not borrow
  storage SOC/thermal assumptions there.
- Use this pack when the battery, its state, and its protection are part of the
  claim — not just the converter.

## Lab References

Treat the desktop lab archive as read-only ground truth. Storage-relevant:

- Battery/BESS and bidirectional-converter models where SOC/thermal/protection
  parameters or grid-support scenarios are available or reconstructable.
- Use lab parameter sets, state names, and scenario windows; never edit, copy,
  or move archive files. Use `lab-model-pattern-miner` only when checking the
  archive. Do not restore or recreate `NEBUS39V2.slx`.

## Helper

Use the project helper when you have a declared storage case descriptor:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
descriptor = struct( ...
    "case_name", "bess_freq_response", ...
    "battery_model", "equivalent_circuit_2RC", ...
    "grid_support_mode", "frequency_response", ...
    "study_root", "build/reports/d3_storage_bms/bess_freq_response", ...
    "soc_soh", struct("soc_window", [0.2 0.9], "soh", 0.95), ...
    "thermal", struct("limit_c", 45, "model", "lumped_RC"), ...
    "protection", struct("ov", 1, "uv", 1, "oc", 1, "ot", 1), ...
    "battery_evidence", struct("artifact", "build/reports/.../batt.json", "required", true, ...
        "operating_point", struct("soc", 0.5, "temperature_c", 25, "p_kw", 200)), ...
    "dc_link", struct("artifact", "build/reports/.../dclink.json", "required", true, ...
        "operating_point", struct("soc", 0.5, "temperature_c", 25, "p_kw", 200)), ...
    "time_domain_validation", struct("artifact", "build/reports/.../emt.json", "required", true));
summary = summarize_storage_bms_support(descriptor, ...
    "OutputDir", "build/reports/d3_storage_bms/bess_freq_response");
```

The helper is pure base-MATLAB (no toolbox). It does not run a Simulink model;
it intakes declared assumptions and artifact pointers and reports status.

Optional `study_root` enables the same-study check: when declared, every present
evidence artifact must resolve under that root. Distinct battery and DC-link
artifact paths are necessary but not sufficient — a battery run from one study
stapled onto a DC-link run from another study sets `same_study=false` and blocks
`handoff_ready`, even though the paths differ. This never substitutes for the
battery-layer gate: generic DC-link evidence still cannot prove the battery.

Optional per-artifact `operating_point` (`soc`, `temperature_c`, `p_kw`, `scr`)
enables the same-operating-condition (同工况) check: same-study is still not
enough, because two runs under one root can be taken at different SOC,
temperature, or power. The battery point is the anchor; converter/time-domain
points are compared within tolerance (override via `OpConditionTolerance`). A
mismatch sets `same_operating_condition=false` and blocks `handoff_ready` even
when `same_study=true` and the battery layer is proven. It is a metadata
consistency check, not proof of correct behaviour at that point.

The same operating temperatures are also screened against the case's declared
BMS thermal limit (`thermal.limit_c`): any artifact whose
`operating_point.temperature_c` is above the limit sets
`within_thermal_limit=false` and blocks `handoff_ready`, independently of the
op-condition and battery-layer gates. Evidence collected above the BMS thermal
limit is out of spec and must not back a validated-BESS claim. Like the others
this is opt-in (`[]` when no limit or no temperature is declared) and is a
metadata check, not a thermal simulation.

## Output

Write storage support reports under:

```text
build/reports/d3_storage_bms/<case>/
  storage_bms_support.md
  storage_bms_support.json
```

Read `references/storage-bms-support-contract.md` before changing dimensions,
status rules, the battery-vs-DC-link separation logic, or pass/fail wording.
