---
name: simulink-spec-validator
description: Use when creating, reviewing, patching, or validating YAML/JSON specs for derived Simulink power-electronics or converter-interfaced power-system models in simulink_agent_v1. Checks required sections, base units, frequency, solver timing, convergence targets, fault windows, replacement/topology intent, and writes a spec validation report before model generation or AI-in-loop S1 PASS.
---

# Simulink Spec Validator

Use this before building or modifying any derived model from a spec.

Primary helper:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/verification")
r = validate_power_system_spec("specs/case_nebus39_dfig2_weakgrid_v0.yaml", ...
    "ReportPath", "build/reports/spec_validation/case_nebus39_dfig2_weakgrid_v0.md");
assert(r.passed)
```

## Required Contract

The spec must declare:

- `system.name`
- `system.base_mva`
- `system.frequency_hz` as 50 or 60
- `system.stop_time`
- `system.sample_time`
- `convergence_targets`
- either `topology` or `replacement_policy`

If `fault_injection` exists, validate `t_start_s < t_end_s <= stop_time` and
`0 <= amplitude_pu_during_fault <= 1.5`.

Read `references/spec-contract.md` when expanding the schema.

## Routing

- Use this skill for S1 validation and spec review.
- Use `scenario-fault-library` to generate safe scenario patches.
- Use `ai-in-loop` after S1 passes.
