---
name: simulink-modeling-assistant
description: Use when the user asks to build, modify, or extend a Simulink power-system model in this project (IEEE39 SG/DFIG, 4-machine 2-area, MMC HVDC, LCC HVDC, single-machine NEBUS benchmark). Routes "swap source / change unit count / change voltage level / change line distance / add primary frequency control / convert VSG to PLL" requests to the project's pattern library first, falling back to MathWorks core skills only when no pattern matches.
---

# Simulink Modeling Assistant

This is a **router** skill, not a handbook. It maps a user request to:

1. The matching row in `docs/MODELING_PATTERN_LIBRARY.md` Section 8 (fast path), or
2. The right combination of project skills (`building-simulink-models`,
   `simulink-auto-layout-github`, `simulink-power-electronics`,
   `simulink-device-adapters`, `simulink-model-quality-layout`,
   `simulating-simulink-models`, `testing-simulink-models`, `ai-in-loop`).

The goal is **token economy**: when a request is similar to one of the
M01–M08 reference models, reuse their parameters and layout instead of
re-deriving from first principles.

## Trigger

- "用 M01 / M03 / M05 / M07 的参数建一个 ..."
- "把 NEBUS39 中的 SG 替换为 DFIG"
- "改电压等级 / 改基准容量 / 改线路距离 / 改台数"
- "加一次调频 / 加 VSG / 加 PLL / 加 PSS"
- "在已有模型基础上扩展为 ..."

## Hard Rules

1. Read `docs/MODELING_PATTERN_LIBRARY.md` Section 0 (index) **before**
   choosing parameters. Identify the matching M-row.
2. Do not re-derive base values when a row in Section 8 covers the request.
3. Three-phase physical SPS connections must remain explicit (no Goto/From).
4. Goto/From are only for ordinary Simulink measurement/control signals
   (`Utabc, Itabc, Inetabc, Unetabc, WindSpeed, Pref, Qref, Vref, Pe_i, wr_i`).
5. Never modify the eight oracle files:
   - `simulink_agent_v1`: `NEBUS39V2.slx`, `NE39bus_dataV2.m`,
     `power_KundurTwoAreaSystem.slx`, `power_wind_dfig_avg.slx`.
   - `实验室仿真模型汇总`: `SGbyhjq.slx`, `VSCbyhjq.slx`, the four reference
     `.slx` under `4M2A_DFIG_csy/物理电磁暂态模型/`,
     `两机两区域/`, `柔直四机两区模型/`.
6. Output goes under `build/generated_models/` and `build/reports/`.

## Decision Flow

```
user request
   ↓
classify (DFIG | SG | MMC | LCC | VSC | hybrid)
   ↓
look up Section 8 of MODELING_PATTERN_LIBRARY for matching row
   ↓
match? ──yes──▶ apply one-line param change, jump to ai-in-loop S2 BUILD
   │
   no
   ↓
classify by request type:
   build new model     ──▶ building-simulink-models + this skill's §3
   layout fix          ──▶ simulink-auto-layout-github + §4 layout cookbook
   PE-specific (VSC,
       PLL, gating,
       waveform debug) ──▶ simulink-power-electronics
   simulate / verify   ──▶ simulating-simulink-models + ai-in-loop S4-S5
   write tests         ──▶ testing-simulink-models + ai-in-loop S7
```

## Read When Needed

- `references/pattern-rows.md` — compact recipe per M01–M08.
- `references/layout-cookbook.md` — the 6 layout rules + ASCII templates per topology.
- `references/parameter-cheatsheet.md` — DFIG / SG / MMC / LCC default PI sets.
- `references/derivation-cookbook.md` — end-to-end recipe to build a new derived model (donor pick, spec, build script, FS-017 prevention, validation gate, AI-summary snapshot). **Read this when user asks for a new derived model.**
- `docs/MODELING_PATTERN_LIBRARY.md` — full pattern catalogue (load lazily).

## Stage Routing

When authoring or reviewing a build script for a derived model, use
`simulink-device-adapters` before S4 compile so device names, adapter ports,
InitFcn self-containment, mask introspection, and trace metadata are checked
as part of S2 rather than discovered after simulation.

When touching root layout, use `simulink-model-quality-layout` after the
layout cookbook. The desktop `实验室仿真模型汇总` folder is a read-only style
reference for M01/M02 spacing, M07 compact single-machine templates, and M08
signal-only Goto/From practice.

Same routing table as `ai-in-loop` SKILL.md, with one extra:

| Stage | Primary | Note |
|---|---|---|
| **S0.5 PATTERN-MATCH** | this skill | Run before S1; if match, mark `template_source` in iter status.json |

If S0.5 finds a match, `iteration_index` starts at 0 with `template_source`
set; otherwise the loop proceeds normally.

## Output Style

- Final chat reply ≤ 120 lines, in user's language.
- Cite the matched M-row (e.g., `M01 §2.4`) so the user can verify by file.
- Never paste full mac_con / AVR_Data tables — point to the file path.
- Detailed evidence stays under `build/reports/`.

## What This Skill Does Not Do

- Symbolic small-signal A-matrix derivation. Use the reference `.m` files
  (`NF_4_model_VSG_*.m`, `DFIGmfile.m`, `Copy_3_of_x2_*.m`) as ground truth.
- Stateflow / HDL / PIL / SIL workflows.
- Toolbox-license-gated features without checking `license`.
