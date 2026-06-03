---
name: simulink-auto-layout-github
description: Use for MATLAB/Simulink model layout, block placement, line routing, readability cleanup, and GitHub-sourced layout tooling. Trigger when improving Simulink diagrams, arranging generated models, reducing crossings, applying Auto-Layout, Graphviz, GraphPlot, routeLine, Goto/From policies, or power-system component layout.
---

# Simulink Auto Layout GitHub

Use this skill when a Simulink model needs visual cleanup or deterministic placement. It binds the project to GitHub-sourced layout tools downloaded under `external/github/` and keeps global MATLAB configuration untouched.

## Sources

Read `references/github-layout-sources.md` before choosing a tool. Current local sources:

- `external/github/McSCert-Auto-Layout`
- `external/github/McSCert-Simulink-Utility`
- `external/github/simulink-skills-upstream`
- built-in MATLAB/Simulink layout APIs, especially `Simulink.BlockDiagram.arrangeSystem` and `Simulink.BlockDiagram.routeLine`

## Workflow

1. Inspect the model first. Count top-level blocks, hierarchy depth, signal/physical line density, and subsystem boundaries.
2. Classify the canvas:
   - Use deterministic coordinates for power-grid one-line diagrams, busbars, three-phase physical networks, and benchmark topology views.
   - Use GitHub Auto-Layout only for ordinary Simulink control/measurement subsystems where semantic coordinates are not part of the model meaning.
   - Use `Goto`/`From` only for ordinary Simulink control or measurement signals, never for physical electrical connections or conservation ports.
3. Initialize project-local tools from MATLAB:

   ```matlab
   cd("C:\Users\jonas\Desktop\simulink_agent_v1")
   init_github_power_electronics_layout_tools
   ```

4. Prefer a copy of the model or a generated next version. Do not run full-layout algorithms directly on the only reference model.
5. After layout, run compile/update and a smoke simulation when possible. Export at least one screenshot for visual QA.

## Tool Selection

- **Generated power-system overview:** use deterministic coordinate templates and short block labels.
- **Dense control subsystem:** try built-in `arrangeSystem` first; if it fails, use McSCert Auto-Layout GraphPlot or DepthBased.
- **Line crossing cleanup:** use `routeLine` or McSCert line utilities after block positions are fixed.
- **Large executable physical detail:** keep it executable and explicit, then add a separate review/navigation layer instead of forcing all physical details into a beautiful top-level canvas.

## Guardrails

- Do not edit `startup.m` or global MATLAB paths.
- Do not install these tools globally unless explicitly requested.
- Do not apply automatic layout to a standard benchmark model without saving a derived copy.
- Keep report artifacts in `build/reports/` and generated models in `build/generated_models/`.
