---
name: device-pack-vsc-gfl-gfm
description: Use when modeling, reviewing, or assembling support evidence for voltage-source-converter (VSC) devices and grid-following vs grid-forming (GFL/GFM) renewable-interconnection studies in Simulink, including control mode, weak-grid SCR/ESCR, PLL vs virtual-oscillator/VSG synchronization, active/reactive control, fault ride-through, and the modal/impedance/time-domain validation artifacts that back a VSC case.
---

# Device Pack: VSC / GFL-GFM Support and Evidence

Use this skill when a study centers on a voltage-source converter and the
question is whether its declared assumptions (control mode, grid strength,
synchronization, active/reactive control) are backed by the right evidence
artifacts before any stability or fault-ride-through claim is trusted.

This is a **contract-first device pack**, not a model generator. It does not
build or run a Simulink model. It connects VSC device assumptions to the
existing evidence chains (`weak-grid-scr-scenario`, `small-signal-modal-analysis`,
`impedance-frequency-analysis`, `gfl-gfm-control-comparison`,
`ibr-model-validation-evidence`) and records, per dimension, whether the
assumption is documented and whether the named evidence artifact is present.

## Core Rule

A VSC case is only as trustworthy as its weakest documented dimension. Record
the control mode, grid strength, synchronization paradigm, active/reactive
control, fault case, and the evidence artifacts that back them. A `PASS` means
the assumption is documented or the evidence pointer is present and same-study,
never that a physical result has been proven. While the case identity is
undocumented (provisional), no artifact may read `PASS`.

## When To Use vs Related Skills

- Use `gfl-gfm-control-comparison` when you are *comparing* two control
  strategies on a fair scenario; use this pack to assemble the *support
  evidence* for a single VSC device case before or after that comparison.
- Use `weak-grid-scr-scenario` to build the SCR/ESCR matrix; this pack records
  whether that strength axis is documented for the VSC case.
- Use `small-signal-modal-analysis` / `impedance-frequency-analysis` to produce
  the modal and frequency-domain artifacts; this pack records whether they are
  attached and same-study.
- Use `ibr-model-validation-evidence` for the full handoff package; this pack
  is the VSC-device-specific intake feeding that package.

## VSC Device Dimensions

Two kinds of dimension are tracked:

- **Assumption dimensions** (documented or not): `control_mode`
  (GFL / GFM / grid_support), `grid_strength` (SCR/ESCR + method),
  `synchronization` (pll / vsg / droop / voc / vsm), `active_power_control`,
  `reactive_power_control`.
- **Artifact dimensions** (evidence pointer present or not):
  `fault_ride_through`, `modal_evidence`, `impedance_evidence`,
  `time_domain_validation`.

GFL vs GFM is the central axis:

- GFL converters synchronize through a PLL and behave as a controlled current
  source behind the PLL; weak-grid SCR sensitivity and PLL-band impedance
  shaping dominate their risk profile.
- GFM converters self-synchronize (VSG / droop / virtual oscillator) and form a
  voltage behind an impedance; they regulate voltage and contribute inertia and
  fault current differently. A GFM case declaring PLL sync or a fixed reactive
  setpoint is a contradiction the consistency screen surfaces.

## Workflow

1. Declare the VSC case descriptor: control mode, evidence source, operating
   point, base values, grid strength, synchronization, active/reactive control.
2. Attach the evidence artifact pointers you have: fault-ride-through run,
   modal summary, impedance summary, time-domain (EMT/RMS) run.
3. Summarize with the helper. Read the per-dimension PASS/WARN/MISSING/N/A and
   the control-mode consistency screen.
4. For any `MISSING` artifact, route to the producing skill
   (`weak-grid-scr-scenario`, `small-signal-modal-analysis`,
   `impedance-frequency-analysis`, or the model run) and re-summarize.
5. Resolve any consistency issue before claiming handoff readiness.
6. Feed the resulting summary into `ibr-model-validation-evidence` as the
   VSC-device intake.

## Lab References

Treat the desktop lab archive as read-only ground truth. Use VSC / converter
parameter sets, control-mode conventions, and weak-grid scenarios from it for
realistic descriptors; never edit, copy, or restore archive models, and never
restore `NEBUS39V2.slx`. Use `lab-model-pattern-miner` only when checking the
archive.

## Helper

Use the project helper with a case descriptor you already have:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
d = struct();
d.case_name = "vsc_gfm_weakgrid";
d.control_mode = "GFM";
d.evidence_source = "simulated";
d.operating_point = "0.8pu, SCR=2.0";
d.base_values = struct("s_base_mva", 100, "v_base_kv", 33, "f_base_hz", 50);
d.grid_strength = struct("scr", 2.0, "method", "thevenin_L");
d.synchronization = struct("type", "vsg");
d.active_power_control = struct("mode", "f_droop");
d.reactive_power_control = struct("mode", "v_droop");
d.time_domain_validation = struct("artifact", ...
    "build/reports/.../emt_run.json", "required", true);
summary = summarize_vsc_gfl_gfm_support(d, ...
    "OutputDir", "build/reports/d1_vsc_gfl_gfm/vsc_gfm_weakgrid");
```

The helper is pure base-MATLAB (no toolbox dependency). It does not run a
Simulink model; supply the assumptions and artifact pointers. When a path is
given for an artifact, the file must exist on disk or the dimension is
`MISSING`.

## Output

Write VSC support summaries under:

```text
build/reports/d1_vsc_gfl_gfm/<case>/
  vsc_gfl_gfm_support.md
  vsc_gfl_gfm_support.json
```

Read `references/vsc-support-contract.md` before changing dimensions, status
rules, consistency checks, or handoff-readiness wording.
