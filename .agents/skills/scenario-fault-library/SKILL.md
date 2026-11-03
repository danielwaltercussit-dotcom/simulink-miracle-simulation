---
name: scenario-fault-library
description: Use when adding or selecting reusable simulation scenarios for Simulink power-electronics and converter-interfaced power-system models in simulink_agent_v1, including voltage sag, weak grid SCR, wind step, frequency disturbance, line trip, PLL stress, LVRT, and scenario patches for specs and ai-in-loop validation.
---

# Scenario Fault Library

Use this skill to choose a reusable scenario before modifying a spec or build
script. Scenarios should become spec patches plus expected observables.

Primary helper:

```matlab
projectRoot = getenv("SIMULINK_AGENT_ROOT");
if isempty(projectRoot), projectRoot = pwd; end
cd(projectRoot)
addpath("scripts/scenarios")
p = generate_fault_scenario_patch("voltage_sag_0p5pu_200ms", ...
    "ModelName", "nebus39_dfig2_weakgrid_v0", ...
    "OutPath", "build/reports/scenarios/voltage_sag_0p5pu_200ms.yaml");
```

Read `references/scenario-catalog.md` to pick a scenario.

## GFL VSC经验补充（2026-11-02）

GFL选相跌落/升高与正负序输入，参见[选相语义条款](../device-pack-vsc-gfl-gfm/references/gfl-frt-wrapper-playbook.md)的VSC-R06；源相对地、装置端口和真实故障阻抗需区分。

## Scenario Card

Each scenario must specify:

- intent
- spec patch
- expected logged signals
- pass metrics
- likely failure signatures
- whether it is a smoke, tune, sltest, or full-loop scenario

Do not hide physical SPS wiring behind Goto/From when implementing a scenario.
