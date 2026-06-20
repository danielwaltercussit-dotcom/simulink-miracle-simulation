---
name: simulink-auto-layout-github
description: Use for MATLAB/Simulink model layout, block placement, line routing, readability cleanup, and GitHub-sourced layout tooling. Trigger when improving Simulink diagrams, arranging generated models, reducing crossings, applying Auto-Layout, Graphviz, GraphPlot, routeLine, Goto/From policies, or power-system component layout.
---

# Simulink Auto Layout GitHub

Use this skill when a Simulink model needs visual cleanup or deterministic placement. It binds the project to GitHub-sourced layout tools downloaded under `external/github/` and keeps global MATLAB configuration untouched.

Read `references/layout-policy.md` before changing block positions. It defines
full versus incremental layout, the power-system top-level exception, and the
required structure-preservation checks.

## Sources

Read `references/github-layout-sources.md` before choosing a tool. Current local sources:

- `external/github/McSCert-Auto-Layout`
- `external/github/McSCert-Simulink-Utility`
- `external/github/simulink-skills-upstream`
- `external/simulink-agentic-toolkit` as a reference for the official
  `full`/`incremental` layout policy; do not install it globally from this skill
- built-in MATLAB/Simulink layout APIs, especially `Simulink.BlockDiagram.arrangeSystem` and `Simulink.BlockDiagram.routeLine`

## Workflow

1. Inspect the model first. Count top-level blocks, hierarchy depth, signal/physical line density, and subsystem boundaries.
2. Classify the canvas:
   - Use deterministic coordinates for power-grid one-line diagrams, busbars, three-phase physical networks, and benchmark topology views.
   - Use GitHub Auto-Layout only for ordinary Simulink control/measurement subsystems where semantic coordinates are not part of the model meaning.
   - Use `Goto`/`From` only for ordinary Simulink control or measurement signals, never for physical electrical connections or conservation ports.
3. From the repository root, initialize project-local tools from MATLAB:

   ```matlab
   addpath(".agents/skills/simulink-auto-layout-github/scripts")
   setup_layout_tools
   ```

4. Capture a pre-layout structure snapshot with
   `scripts/layout/capture_layout_structure.m`.
5. Select `full`, `incremental`, or deterministic layout according to
   `references/layout-policy.md`.
6. Prefer a copy of the model or a generated next version. Do not run full-layout algorithms directly on the only reference model.
7. Verify the post-layout structure against the snapshot, then run the layout
   quality audit, compile/update, and a smoke simulation when possible. Export
   at least one screenshot for visual QA.

## Tool Selection

- **Generated power-system overview:** use deterministic coordinate templates and short block labels.
- **New or empty ordinary control subsystem:** use full layout.
- **Existing ordinary control subsystem:** use incremental layout and preserve established block positions.
- **Dense control subsystem:** use built-in layout first; if it fails, use McSCert Auto-Layout GraphPlot or DepthBased on a derived copy.
- **Line crossing cleanup:** use `routeLine` or McSCert line utilities after block positions are fixed.
- **Large executable physical detail:** keep it executable and explicit, then add a separate review/navigation layer instead of forcing all physical details into a beautiful top-level canvas.

## Guardrails

- Do not edit `startup.m` or global MATLAB paths.
- Do not install these tools globally unless explicitly requested.
- Never call `arrangeSystem` on the root of a power-system, SPS, or Simscape
  electrical network. Use deterministic coordinates there, even when the model
  is newly generated.
- Never treat layout success as structural success. Block inventory,
  resolvable signal connectivity, line count, and disconnected-line count must
  match the pre-layout snapshot.
- Do not apply automatic layout to a standard benchmark model without saving a derived copy.
- Keep report artifacts in `build/reports/` and generated models in `build/generated_models/`.
