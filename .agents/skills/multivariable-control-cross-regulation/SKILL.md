---
name: multivariable-control-cross-regulation
description: Use when tuning or reviewing strongly coupled converter control loops in Simulink power-electronics and converter-dominated power-system models, including dq current loops, AC/DC voltage loops, PLL, droop/VSG outer loops, and cross-regulation between active/reactive or voltage/current channels. Covers PI/PID gains, sampling, saturation/anti-windup, loop-bandwidth targets, the cross-coupling matrix, disturbance channels, and stability/damping margins, and separates a documented tuning result from an undocumented gain tweak.
---

# Multivariable Control / Cross-Regulation Tuning

Use this skill when a converter control design has **more than one interacting
loop** and tuning one loop changes another: dq current loops that couple through
omega*L terms, an outer voltage/power loop riding on an inner current loop, a PLL
that couples the synchronization frame into the current controllers, or
active/reactive channels that fight through a weak grid. It is the
**evidence-contract layer** for coupled tuning: it does not pick gains for you,
it checks that a tuning result carries enough metadata to be trusted and
reproduced.

## Core Rule

A gain change is only **tuning evidence** when it is documented at a stated
operating point with: before->after gains, sample time, saturation/anti-windup
handling, a loop-bandwidth target, a stability or damping margin, a retune
rationale, and a documented cross-coupling structure when 2+ loops interact.
A gain change with none of that is an **undocumented gain tweak**, not a result.
Linear margins (phase/gain margin, damping ratio) are small-signal screens; they
do NOT prove closed-loop stability or acceptable cross-regulation. Confirm in the
time domain (step/disturbance response, EMT/RMS) before claiming improvement.

Evidence is tiered, and the report states which tier it reached:
`contract_consistency` (metadata only) < `model_backed` (a same-iteration
simulation disturbance run is linked) < `hardware_backed` (a measurement
artifact). An **improvement** is reported as `supported` only when before/after
margins improve AND a model-backed (or measured) time-domain run backs it.
Never convert a documented gain change into an improvement claim without that
measured evidence.

## When To Use vs power-electronics-tuning

- Use `power-electronics-tuning` for the **S6 tuning registry**: which knobs
  exist, their bounds/units, and the ai-in-loop probe direction policy. That
  skill owns the *mechanics* of changing a registered knob.
- Use **this skill** for the **multivariable reasoning and evidence**: whether
  loops are coupled, whether the cross-regulation was screened, whether a tuning
  change is documented to a contract, and how to report margins per loop.
- They compose: register a knob in `power-electronics-tuning`, then record the
  coupled-loop tuning result against this skill's contract.

## When To Use vs Other Evidence

- `small-signal-modal-analysis`: eigenvalue/damping ownership of a coupled mode.
  A weak per-loop margin here and a low-damping mode there should agree.
- `impedance-frequency-analysis`: if retuning a current-loop bandwidth moves a
  negative-resistance band, re-run the impedance summary at the same operating
  point and link both artifacts.
- `weak-grid-scr-scenario`: cross-regulation usually worsens as SCR drops; tune
  and report margins at the weak-grid operating point, not only the stiff grid.
- `multitimescale-analysis`: use it first when it is unclear whether the
  dominant behavior is inner-current, outer-voltage, or electromechanical scale.

## Workflow

1. Identify every loop in the coupled set and the **control frame** (dq,
   sequence, abc). Record the operating point (load, SCR/ESCR, GFL/GFM mode).
2. For each loop, capture before->after gains, sample time, saturation limits
   (or `unsaturated=true`), anti-windup, the bandwidth target, and the rationale.
3. Build the **cross-coupling matrix** over the loops (relative 0..1). Anything
   off-diagonal at or above the strong-coupling threshold means the set must be
   tuned as a coupled MIMO system, not independent SISO loops.
4. When a steady-state (or at-frequency) **gain matrix** `G` is available from
   the model or identification, supply it. The helper computes the **Relative
   Gain Array (RGA)** and a **singular-value screen** (sigma_max, sigma_min,
   condition number) as a reproducible interaction metric and an input-output
   pairing recommendation.
5. Attach a per-loop **margin metric** (phase margin, gain margin, or damping
   ratio). For an improvement claim, supply both **before and after** margins
   (`phase_margin_before_deg`/`phase_margin_after_deg`, etc.).
6. Link a **time-domain disturbance run** (`time_domain.artifact_path` +
   `source`) so the improvement gate can reach `model_backed`. A `simulation`
   or `measurement` artifact that exists and is same-iteration is model-backed;
   a `synthetic` source stays contract-consistent.
7. List the **disturbance channels** each loop is responsible for rejecting.
8. Summarize with the helper and read the classification, the `improvement`
   verdict, and the `evidence_tier`. If classification is
   `undocumented_gain_tweak` or `provisional`, fill the `missing_required`
   fields before claiming a tuning result.
9. Only report a tuning **improvement** when `improvement.status == "supported"`
   (before/after margins improved AND a model-backed disturbance run is linked).
   `margin_only_unverified` and `claimed_unverified` are NOT improvements.

## Lab References

Treat the desktop lab archive as read-only ground truth. Relevant here:

- converter control subsystems with inner-current / outer-voltage structure,
  dq decoupling terms, PLL, and droop/VSG outer loops;
- use lab parameter sets, sample times, saturation limits, and loop-bandwidth
  conventions; never edit archive files. Use `lab-model-pattern-miner` only when
  checking the archive.

Do not restore or recreate `NEBUS39V2.slx`; it is intentionally absent.

## Helper

Use the project helper when you already have the tuning metadata:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
tuning = struct();
tuning.operating_point = "P=0.8pu, SCR=2.5, GFL";
tuning.control_frame = "dq";
tuning.model_path = "models/vsc_dq_current.slx";
tuning.cross_coupling = [1 0.4; 0.4 1];   % id<->iq coupling via omega*L
tuning.gain_matrix = [1.0 0.35; 0.30 1.0]; % steady-state G for RGA / sigma
tuning.time_domain = struct( ...           % measured/sim disturbance run
    "artifact_path","build/reports/f2_cross_regulation/vsc_dq_current_frt/dist_run.json", ...
    "source","simulation", "disturbance","grid voltage 0.5pu dip 100ms", ...
    "settling_time_s",0.012, "overshoot_pct",8.5, "peak_coupling",0.06);
tuning.loops(1) = struct("name","id_current","type","PI", ...
    "kp_before",0.8,"kp_after",1.2,"ki_before",60,"ki_after",90, ...
    "sample_time_s",1e-4,"bandwidth_target_hz",300, ...
    "output_min",-1,"output_max",1,"anti_windup","back-calculation", ...
    "phase_margin_before_deg",38,"phase_margin_after_deg",52, ...
    "rationale","raise BW to 300Hz for FRT current step");
tuning.loops(2) = struct("name","iq_current","type","PI", ...
    "kp_before",0.8,"kp_after",1.2,"ki_before",60,"ki_after",90, ...
    "sample_time_s",1e-4,"bandwidth_target_hz",300, ...
    "output_min",-1,"output_max",1,"anti_windup","back-calculation", ...
    "phase_margin_before_deg",40,"phase_margin_after_deg",50, ...
    "rationale","match id loop for symmetric dq response");
summary = summarize_cross_regulation_tuning(tuning, ...
    "CaseName","vsc_dq_current_frt", ...
    "CurrentIterationDir","build/reports/f2_cross_regulation/vsc_dq_current_frt", ...
    "OutputDir","build/reports/f2_cross_regulation/vsc_dq_current_frt");
```

The helper is pure base-MATLAB (no Control System Toolbox required): it does not
compute margins or run a tuning loop. It ingests the margins and the gain matrix
you supply, computes the RGA / singular-value interaction metric with base-MATLAB
`inv`/`svd`, compares before/after margins, and gates the improvement verdict on
a model-backed time-domain artifact. Supply margins from your own `margin`/`bode`
analysis or a time-domain estimate; supply `gain_matrix` from a linearization or
identification. The helper does not itself run the model.

## Output

Write cross-regulation reports under:

```text
build/reports/f2_cross_regulation/<case>/
  cross_regulation_summary.md
  cross_regulation_summary.json
  loop_tuning.csv
```

Read `references/cross-regulation-contract.md` before changing the required
metadata, the classification labels, or the coupling/margin thresholds.
