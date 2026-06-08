---
name: emt-switching-level-converter
description: Use when building, reviewing, or validating switching-level (detailed) EMT converter models in simulink_agent_v1 where PWM carrier, dead-time, modulation method, semiconductor loss, sub-cycle current limiting, or switching-harmonic/THD evidence is the decision variable. Defines when switching-level EMT is required versus averaged/RMS/phasor fidelity, and the metadata needed to trust a switching waveform.
---

# EMT / Switching-Level Converter Modeling

Use this skill when a converter study depends on the actual switching behavior:
PWM modulation, dead-time, carrier sidebands, semiconductor conduction/switching
loss, sub-cycle current limiting, or switching-harmonic / THD evidence. It is the
high-fidelity end of `model-fidelity-selector`: pick it only when averaged or
RMS/phasor models would hide the deciding dynamics.

## Core Rule

A switching-level waveform is trustworthy only when its discretization actually
resolves the switching. Evidence must record carrier frequency, fixed-step sample
time, solver step, dead-time, modulation method, and device-loss mode, and the
sample rate must resolve the carrier and its near sidebands. THD / harmonic
numbers and the transient event window are part of the evidence, not an
afterthought. If the carrier frequency, sample time, or modulation method is
undocumented, the waveform evidence is provisional and must not be used to claim
harmonic, loss, or protection-level validation.

## When Switching-Level EMT Is Required

Choose switching-level EMT when the answer depends on:

- harmonic spectrum, THD, inter-harmonics, or carrier sidebands;
- dead-time effects, minimum pulse width, or modulation-method differences
  (SPWM, SVPWM, DPWM, hysteresis);
- semiconductor conduction/switching loss or thermal duty;
- sub-cycle current limiting, blanking, or protection trip timing;
- ripple-driven DC-link or filter sizing.

## When To Step Down Fidelity Instead

Do NOT pay switching cost when the decision variable is slower than the carrier:

- averaged EMT for PLL/VSG control loops, DC-link recovery, weak-grid
  interaction, and fair GFL/GFM comparison (carrier removed);
- dynamic phasor / per-phase phasor for unbalanced faults without switching;
- positive-sequence RMS for electromechanical and planning-scale studies.

State the crossover explicitly: switching evidence above the bandwidth of
interest can usually be replaced by an averaged model whose loss and ripple
assumptions are documented. Route that handoff through `model-fidelity-selector`.

## Discretization Adequacy

Record and check, before trusting the waveform:

- `samples_per_carrier = 1 / (carrier_hz * sample_time_s)` — undersampled below
  ~20; aliased switching content is not real evidence.
- Nyquist headroom: `1/(2*sample_time_s)` must exceed the highest harmonic of
  interest (carrier + a few sidebands).
- dead-time vs step: a dead-time smaller than one fixed step is not represented;
  flag it rather than reporting a dead-time effect that the grid cannot resolve.

## Workflow

1. Confirm switching-level EMT is actually required (see above); if not, route to
   `model-fidelity-selector` and stop.
2. Record the metadata contract: carrier, sample time, solver step, dead-time,
   modulation method, device-loss mode, fundamental frequency, units, and the
   transient event window.
3. Run the model (or supply a captured waveform) and compute the THD / harmonic
   summary with the helper below.
4. Check discretization adequacy; downgrade to provisional if the grid does not
   resolve the carrier.
5. Map the transient event window to the observable being judged.
6. Hand the THD / harmonic summary to `ibr-model-validation-evidence` as the
   switching-level artifact, or to `impedance-frequency-analysis` when a
   frequency-domain interaction screen is also needed.

## Privacy / Lab References

Treat the desktop lab archive as read-only ground truth. Do NOT restore
`NEBUS39V2.slx` or copy private models into the repo. Use the archive only for
parameter ranges, carrier/sample-time conventions, and modulation patterns; never
edit archive files. Use `lab-model-pattern-miner` when inspecting the archive.

## Helper

Use the project helper when you have a time-domain switching waveform:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
summary = summarize_switching_waveform_evidence(timeS, waveform, ...
    "CaseName", "vsc_spwm_fault_window", ...
    "Signal", "current", ...
    "FundamentalHz", 50, ...
    "CarrierHz", 5000, ...
    "SampleTimeS", 2e-6, ...
    "DeadTimeS", 2e-6, ...
    "ModulationMethod", "SVPWM", ...
    "Solver", "fixed-step discrete", ...
    "DeviceLossMode", "on-resistance+Vf", ...
    "TransientEventWindowS", [0.10 0.18], ...
    "OutputDir", "build/reports/e1_emt_switching/vsc_spwm_fault_window");
```

The helper is pure base-MATLAB (no Signal Processing Toolbox): the spectrum uses
`fft`, THD sums harmonic bins of the fundamental, and the carrier band is located
relative to `CarrierHz`. It does NOT run a Simulink model; supply the waveform.

## Evidence Ingestion and Provenance

To attach real provenance, ingest the waveform through the intake helper rather
than calling the summarizer directly. It accepts a `Simulink.SimulationOutput`,
a logged-signal struct (`time` + `signals`), a `.mat` artifact path, or a
generated `(t, x)` struct, and records where the data came from:

```matlab
summary = ingest_switching_waveform_evidence(simOut, ...
    "SignalName", "i_load", "CaseName", "vsc_leg_run1", ...
    "Signal", "current", "FundamentalHz", 50, "CarrierHz", 2000, ...
    "SampleTimeS", 5e-6, "ModulationMethod", "SPWM", ...
    "OutputDir", "build/reports/e1_emt_switching/vsc_leg_run1");
```

`summary.model_backed` is `true` ONLY for an identified, non-synthetic model
source; synthetic/generated data stays `contract_only`, and an over-asserted
synthetic source is downgraded with a recorded reason. `model_backed` is not a
hardware-validation claim. See the contract for the full taxonomy.

For a genuine model-backed run with no private model, build the tiny generic
half-bridge SPWM leg (programmatic, no saved `.slx`, no lab model) and feed its
SimulationOutput through the intake helper:

```matlab
art = build_tiny_switching_example("OutputDir", ...
    "build/reports/e1_emt_switching/model_backed_tiny_leg");
summary = ingest_switching_waveform_evidence(art, "Signal","current", ...
    "FundamentalHz",50, "CarrierHz",2000, "SampleTimeS",5e-6, ...
    "ModulationMethod","SPWM", "OutputDir", art_dir);
```

`build_tiny_switching_example` requires Simulink and actually compiles and
simulates the leg; it is a demonstration source for model-backed evidence, not a
power-system study model.

## Initializable Model, Dead-Time, Device Loss, Thermal

`build_tiny_switching_example` is initializable and exercises switching-level
non-idealities so their evidence is MODEL-BACKED, not asserted:

```matlab
art = build_tiny_switching_example("Ron", 0.05, "Vf", 1.0, ...
    "DeadTimeS", 15e-6, "InitialCurrent", 0, "SampleTimeS", 5e-6, ...
    "OutputDir", "build/reports/e1_emt_switching/model_backed_tiny_leg");
% art.conduction_loss_w, art.device_loss_mode, art.params.dead_time_steps
```

- `InitialCurrent` seeds the load current (verifiable at t=0).
- `DeadTimeS` is quantised to whole fixed steps; a dead-time that resolves
  (>= one step) actually distorts the waveform via current-polarity-dependent
  freewheeling. A sub-step dead-time reports `dead_time_steps = 0` and must not
  be claimed as a represented dead-time effect.
- `Ron`/`Vf` give a non-ideal conduction drop; the per-step conduction power
  `Ron*i^2 + Vf*|i|` is logged so `conduction_loss_w` comes from the run. With
  `Ron = Vf = 0` the leg is ideal and loss is reported N/A, never 0 W.

Summarize device-loss and thermal evidence with per-metric evidence levels:

```matlab
summary = summarize_device_loss_thermal_evidence( ...
    "CaseName", "tiny_leg_loss", "DeviceLossMode", art.device_loss_mode, ...
    "ConductionLossW", art.conduction_loss_w, "ConductionLossSource", "model", ...
    "ThermalRthCtoA", 0.5, "ThermalCth", 2.0, "AmbientC", 40, ...
    "OutputDir", "build/reports/e1_emt_switching/model_backed_tiny_leg");
```

Each metric (conduction, switching, total, thermal) carries its own
`contract_only` / `model_referenced` / `model_backed` / `hardware_backed` level;
total loss takes the weakest contributing level. A junction temperature from an
Rth/Cth network is a modelling estimate and is capped at `model_backed` — it is
NEVER hardware-backed without measured temperature data.

## Output

Write switching evidence under:

```text
build/reports/e1_emt_switching/<case>/
  switching_summary.md
  switching_summary.json
  switching_spectrum.csv
```

Read `references/switching-evidence-contract.md` before changing metrics, the THD
or carrier rules, the adequacy thresholds, or the PASS/WARN/provisional wording.
