---
name: simulink-model-quality-layout
description: Use when auditing or improving Simulink power-system model quality and layout in simulink_agent_v1, beyond simple root overlap checks. Covers root block count, subsystem encapsulation, legal Goto/From signal policy, measurement/logging completeness, oracle immutability, and layout conventions derived from the desktop lab model archive.
---

# Simulink Model Quality Layout

Use this skill before declaring a generated model layout-ready, readable, or
snapshot-ready.

Primary helper:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
init_simulink_agent_project
addpath("scripts/layout")
r = audit_model_quality_layout("nebus39_dfig2_weakgrid_v0", ...
    "ReportPath", "build/reports/layout/nebus39_dfig2_weakgrid_v0.md");
assert(r.passed)
```

## Contract

The helper is a layout/quality gate, not an auto-layout tool. It checks:

- root canvas overlap
- root block count and subsystem encapsulation ratio
- Goto/From use: allowed for measurement/control signals only
- measurement/logging presence
- oracle files are present and treated as read-only references
- reference availability for `C:\Users\jonas\Desktop\实验室仿真模型汇总`

Read `references/layout-quality-contract.md` before changing layout rules or
making root-canvas edits.

## Routing

- Use `simulink-auto-layout-github` for mechanical placement/routing help.
- Use this skill for the S3 audit and quality report.
- Use `simulink-device-adapters` for device-facing ports before S3.
- Use `simulink-model-verification` after S3 for compile/sim checks.
