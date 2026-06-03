---
name: power-electronics-component-libraries
description: Use for MATLAB/Simulink power-electronics and converter-interfaced power-system component selection, library installation, model generation, benchmark comparison, and reusable VSC, MMC, inverter, PLL, PI, filter, machine, and power-system block guidance from GitHub libraries.
---

# Power Electronics Component Libraries

Use this skill when building or revising MATLAB/Simulink models for power-electronics-dominated power systems. It maps GitHub libraries downloaded under `external/github/` to this project's portable modeling workflow.

## Sources

Read `references/github-component-sources.md` before selecting components. Current local sources:

- `external/github/Simscape_Electrical_Support_Library`
- `external/github/pwrsys-matlab`
- `external/github/simulink-skills-upstream`
- existing project references: `NEBUS39V2.slx`, `NE39bus_dataV2.m`, `power_wind_dfig_avg.slx`

## Workflow

1. Start from the benchmark contract. For IEEE39/New England cases, preserve bus, branch, transformer, load, and ten-machine baseline data before applying converter scenarios.
2. Choose component source:
   - Use MathWorks Simscape Electrical Support Library as a reference for modern Simscape native assemblies, workflows, and examples when the MATLAB release supports it.
   - Use NTNU `pwrsys-matlab` as a reference for converter-interfaced equipment, VSC controls, PLLs, PI controllers, power theories, and voltage-source models.
   - Use existing project DFIG and synchronous-machine examples when compatibility with the current R2024b project is more important than newer component fidelity.
3. Initialize project-local paths in MATLAB:

   ```matlab
   cd("C:\Users\jonas\Desktop\simulink_agent_v1")
   init_github_power_electronics_layout_tools
   ```

4. Generate a traceable scenario overlay rather than mutating the benchmark. Record which original SG, load, line, or transformer each new converter component replaces or augments.
5. Compile, smoke simulate, and update `docs/MODELING_WORKFLOW_DRAFT.md` when a new component class becomes part of the workflow.

## Component Rules

- Keep component libraries as references or templates until their toolbox and release requirements are verified.
- Avoid silently mixing Specialized Power Systems and Simscape native components; use explicit interface blocks or keep them in separate detail layers.
- Every new converter component needs ports, parameter schema, initialization rules, trace metadata, and a smoke test.
- Prefer model masks and table-driven parameters over hardcoded block internals.
- Keep visual overview diagrams separate from executable physical-detail networks when models become dense.

## Release Compatibility

The current project runs MATLAB R2024b. `Simscape_Electrical_Support_Library` documents R2025b-or-newer support, so treat it as installed reference material in this project unless MATLAB is upgraded. `pwrsys-matlab` targets older MATLAB/Simscape Power Systems releases and may need compatibility checks before direct execution.
