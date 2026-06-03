# Multitimescale Analysis Contract

Use this reference when diagnosing power-system simulation behavior across
electrical, converter-control, electromechanical, and scenario time scales in
`simulink_agent_v1`.

## Data Priority

Use data in this order:

1. Existing AI-in-loop iteration artifacts under `build/reports/loop/`.
2. Existing `SimulationOutput` objects or saved MAT files from the run.
3. `logsout` signal logging.
4. `To Workspace` variables saved by the model.
5. Simulink Data Inspector export.
6. A new, bounded `sim()` run.

If none are available, do not infer behavior from the model diagram alone.
Record the logging gap and route to `simulink-model-verification` or the build
script that adds logging.

## Window Definitions

Use explicit windows in seconds:

- `baseline`: stable pre-event interval.
- `event`: known disturbance, fault, tuning step, or first bad-sample window.
- `recovery`: interval after event clearance or after the first metric jump.
- `post_recovery`: interval used for settling, growth, or damping checks.
- `full_smoke`: complete short smoke run when no event exists.

For unknown failures, find the first non-finite sample or the first metric that
crosses a hard threshold. Center the `event` window around that time.

## Signal Families

Electrical / electromagnetic:

- phase voltage and current
- RMS voltage or current
- snubber or switching-related current
- solver step or zero-crossing evidence when available

Converter control:

- PLL frequency, angle, or angle error
- current-loop references and measured currents
- DC-link voltage
- modulation or saturation indicators
- active/reactive power command tracking

Electromechanical:

- machine speed
- rotor angle or relative angle
- electrical/mechanical power
- bus frequency estimate
- damping or oscillation-envelope metrics

Scenario / protection:

- faulted bus voltage
- current limit or protection state
- trip, enable, or recovery signals
- pass/fail thresholds and settling bands

## Minimal Metrics

Only compute metrics that support a routing decision:

- first non-finite time and signal
- peak and trough value in the event or recovery window
- tolerance-band crossing time
- settling time after event clearance
- dominant frequency in a stated window
- growth ratio between early and late window peaks
- damping estimate when peaks are reliable
- final steady value and deviation from target

Report units. Do not compare per-unit and SI values without naming the base.

## Classification Rules

- If the first failure is non-finite and appears on many signals at the same
  timestamp, suspect solver, initialization, or missing parameter data before
  tuning.
- If current, PLL, or DC-link metrics grow while bus voltage remains bounded,
  route to converter-control tuning.
- If rotor speed, machine angle, active power, or frequency oscillates over
  hundreds of milliseconds to seconds, route to electromechanical analysis and
  tuning.
- If all signals are stable until a scripted disturbance, treat the case as
  scenario recovery; use explicit pass/fail windows.
- If plots show behavior but source data or thresholds are missing, mark the
  result as evidence incomplete, not PASS.

## Report Language

Use short evidence statements:

- "Observed from `logsout` signal `<name>` over `<t0>`-`<t1>` s."
- "Dominant behavior is converter-control scale: `<metric>` changes from
  `<a>` to `<b>` in `<window>`."
- "The analysis supports routing to `<skill>`; it is not a standalone PASS."
- "No logged signal covers `<band>`; rebuild logging before judging this band."

Avoid long theory sections. Keep formulas or literature context only when they
change the next modeling or tuning action.

## Artifact Schema

`summary.json` should include:

```json
{
  "model": "<model>",
  "run_id": "<run_id>",
  "source": "<artifact or command>",
  "dominant_band": "<band>",
  "status": "evidence_complete | evidence_incomplete | routed_to_debug | routed_to_tuning",
  "next_route": "<skill-or-script>",
  "windows": [
    {"name": "event", "t0": 0.1, "t1": 0.2}
  ],
  "metrics": [
    {"name": "dominant_frequency_hz", "signal": "<name>", "value": 12.3, "unit": "Hz"}
  ]
}
```

`metrics.csv` should use stable columns:

```text
window,band,signal,metric,value,unit,threshold,status
```
