---
name: multitimescale-analysis
description: Use when analyzing Simulink power-system runs across electrical, converter-control, mechanical, and scenario time scales in simulink_agent_v1, especially when smoke, tuning, fault, or regression evidence shows oscillation, slow recovery, or cross-timescale coupling.
---

# Multitimescale Analysis

Use this skill when a model can run, but the behavior needs to be separated by
time scale before choosing the next tuning, modeling, or verification action.

Project scope:

```matlab
projectRoot = getenv("SIMULINK_AGENT_ROOT");
if isempty(projectRoot), projectRoot = pwd; end
cd(projectRoot)
init_simulink_agent_project
```

## Core Rule

Do not collapse every dynamic issue into one "unstable" label. Classify the
dominant evidence by time scale, then route the next action through the matching
project skill:

- electrical/network transients: `simulink-model-verification`,
  `simulink-debug-commandline`
- converter or PLL control oscillations: `power-electronics-tuning`
- mechanical or rotor-speed dynamics: `power-electronics-tuning`
- fault and recovery windows: `scenario-fault-library`
- report figures and overlays: `diagnostic-plotting`
- closed-loop retry and artifact contract: `ai-in-loop`

## Time-Scale Buckets

Use project-specific signals and metrics where available:

- **microseconds to milliseconds**: switching, solver events, algebraic loops,
  current spikes, first NaN/Inf sample
- **milliseconds to hundreds of milliseconds**: PLL, current loops, voltage
  recovery, fault clearing, weak-grid oscillation onset
- **hundreds of milliseconds to seconds**: rotor speed, DFIG power recovery,
  DC-link settling, damping ratio, governor or VSG outer loops
- **scenario horizon**: full fault window, pre/post disturbance comparison,
  regression baseline versus candidate

## Workflow

1. Start from the latest loop or verification artifact, not theory alone.
2. Identify the shortest time window that contains the failure or borderline
   metric.
3. Map each relevant signal to a bucket and note which bucket dominates the
   decision.
4. Ask `diagnostic-plotting` for only the figures needed to support that
   decision.
5. Route one next action: tune a registered knob, add logging, fix the model
   structure, strengthen the scenario, or rerun `ai-in-loop`.

## Causal Evidence Bridge

When a long baseline reveals a low-frequency or cross-timescale candidate, do
not jump straight to tuning. First decide whether the record length is enough to
estimate the dominant band and damping. If not, extend the unchanged baseline
without changing plant, device, or controller parameters.

After the unchanged baseline is long enough, bridge causality with a
single-factor perturbation:

- control/reference-side injection for PLL or converter-control candidates;
- mechanical power, load, or fault-clearance perturbation for synchronous
  electromechanical candidates;
- wind-speed step/ramp or DFIG reference perturbation for wind-unit candidates.

Do not combine line-parameter changes, wind-speed changes, synchronous machine
speed changes, and controller-gain changes in the same first causal test. A
combined study is allowed only after single-factor signatures are separated.

## Scientific Qualification

Read
`../simulink-modeling-assistant/references/current-simulation-experience.md`
before comparing stages or declaring a mode absent.

- Qualify the pre-event operating point before interpreting band presence.
- Preserve per-signal native time vectors and align them explicitly.
- Derive frequency resolution from the selected window.
- If either stage lacks a separable band, suppress frequency-shift language.
- State "not observed in this qualified record"; require model-based modal
  evidence before claiming structural absence.

## Output

Write compact notes into the current report when the analysis is part of an
AI-in-loop iteration:

```text
build/reports/loop/iter_<NN>/multitimescale_notes.md
```

Include:

- model and run id
- source artifact paths
- dominant bucket and supporting signals
- observed metric values when available
- next routed skill and one proposed action

For standalone analysis, write:

```text
build/reports/multitimescale/<model>/<run_id>/
  timescale_index.md
  summary.json
  metrics.csv
```

Read `references/analysis-contract.md` when defining windows, metric names, or
the standalone `summary.json` / `metrics.csv` schema.
