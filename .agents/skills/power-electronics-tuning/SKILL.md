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

## Rules

- Tune only registered knobs.
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
