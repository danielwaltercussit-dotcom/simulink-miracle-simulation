---
name: power-electronics-tuning
description: Use when tuning or reviewing controller parameters for Simulink power-electronics and converter-interfaced power-system models in simulink_agent_v1, including PLL, rotor-side current PI, grid-side current PI, DC-link PI, speed loop, VSG, MMC, LCC, weak-grid oscillation, fault recovery, and ai-in-loop S6 registry design.
---

# Power Electronics Tuning

Use this skill for S6 tuning design, tuning-registry review, and interpreting
oscillation/fault-recovery metrics.

Primary project hooks:

- `scripts/loop/tuning_registry.m`
- `scripts/loop/ai_in_loop_stage_tune.m`
- `scripts/loop/extract_tuning_metrics.m`

Generate a registry report:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
init_simulink_agent_project
addpath("scripts/loop")
addpath("scripts/tuning")
r = inspect_tuning_registry("nebus39_dfig2_weakgrid_v0", ...
    "ReportPath", "build/reports/tuning_registry/nebus39_dfig2_weakgrid_v0.md");
assert(r.passed)
```

Read `references/tuning-contract.md` before adding knobs or changing failure
signature routing.

Read `references/closed-loop-experience-library.md` before selecting a tuning
family for an established model. After each reviewed tuning round, add one
compact reusable record there; do not append raw logs or unreviewed guesses.

## Rules

- Tune only registered knobs.
- Apply `docs/CONTROL_TUNING_PRIORITY_AND_BOUNDARY.md` before any model write.
- Treat plant/device physical parameters and ratings as immutable. A registry
  entry must be proven control-only; reject unclassified entries.
- For the IEEE39 SG5/DFIG5 test model, run tuning-readiness inventory and an
  unchanged baseline before automatic S6 writes.
- A long unchanged baseline can promote a root-cause candidate, but it does not
  authorize S6 by itself. Require causal confirmation before writing controller
  parameters; if missing, route to `baseline-regression` and
  `multitimescale-analysis` for a single-factor perturbation contract.
- Follow the approved order: PLL and DFIG current PI; SG AVR/governor;
  virtual-inertia/POD/PSS/droop controls; then control-limit/protection/LVRT
  parameters.
- Record `before -> after`, FS target, units, bounds, and model path.
- Prefer one root cause per outer AI-in-loop iteration.
- Do not trust literature direction alone; use live metrics such as
  `I_osc_growth`, recovery time, voltage band, and dominant frequency.
- Use `multitimescale-analysis` before changing knobs when it is unclear
  whether the dominant behavior is converter-control, electromechanical, or
  scenario-recovery scale.
- Use `diagnostic-plotting` for before/after overlays whenever a tuning change
  is accepted, rejected, or ambiguous.
- If the same signature and same fix repeat, stop and ask the user.
- Preserve a rollback snapshot and restore it after simulation errors,
  rejected candidates, and non-converged tuning.
- Treat the experience library as reviewed guidance, not authorization to skip
  model-specific T0/T1 evidence or immutable-boundary checks.

## Data-Driven Assistant Routing

Use `data-driven-simulation-assistant` only for candidate retrieval, candidate
failure labels, missing-gate hints, or advisory experiment suggestions before a
tuning decision. The deterministic tuning contract, S6 registry, baseline
evidence, rollback policy, and live metrics own final knob selection,
direction, acceptance, and write permission.
