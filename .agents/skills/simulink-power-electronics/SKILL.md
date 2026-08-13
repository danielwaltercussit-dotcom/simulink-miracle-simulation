---
name: simulink-power-electronics
description: Use when working on Simulink or Simscape Electrical power-electronics models, including inverter, DC-DC converter, rectifier, motor-drive, battery/BMS, renewable-grid, HVDC/FACTS, converter layout, gate-routing, solver, waveform, control-algorithm, or simulation validation tasks.
---

# Simulink Power Electronics

Use this skill for Simulink/Simscape Electrical PE inspection, waveform/control
debugging, schematic layout, validation, and approved corpus improvement. Keep
conclusions grounded in inspected paths, logged signals, simulations, and checks.

## Core Workflow

1. Classify by domain, topology, and control objective.
2. Load only narrow context: usually `references/workflow.md`, one domain
   subskill, and one triggered reference.
3. Prefer MATLAB MCP and Simulink Agentic Toolkit evidence. If model tools are
   unavailable, continue with file/script review and report the blocked tier.
4. Track validation state explicitly: `opened`, `compiled`, `simulated`,
   `measured`.

## Lean Loading Rules

- Treat this root file as a **router**, not a handbook.
- Do not bulk-load every reference or every subskill.
- Read platform and MCP setup details only when tool status is uncertain.
- Run corpus/self-improvement only when the user explicitly allows it; promote
  notes only when grounded in official sources, inspected models, or validation.

## Read When Needed

- `references/domain-map.md`: choose the domain subskill.
- `references/workflow.md`: inspect -> diagnose -> edit -> validate.
- `references/model-standards.md`: before editing PE models.
- `references/layout-patterns-from-examples.md` and `references/simscape-layout.md`:
  generated or repaired Simscape schematics.
- `references/control-algorithm-debugging.md`: control tracing, PI/feedforward,
  and P/Q checks.
- `references/simulink-command-line-sop.md`: command-line simulation/output reading.
- `references/mcp-simulink-troubleshooting.md`: supported platform, MCP, or tools.
- `references/output-standards.md`: before reports.
- `references/capability-map.md`: only when asked about scope.
- `references/self-iteration-loop.md` and `references/example-derived-patterns.md`:
  user-approved corpus/self-improvement.
- Route fidelity, modal, weak-grid, GFL/GFM, and validation-evidence questions to
  `model-fidelity-selector`, `small-signal-modal-analysis`,
  `weak-grid-scr-scenario`, `gfl-gfm-control-comparison`, and
  `ibr-model-validation-evidence`.
- Use `subskills/three-phase-grid-inverter/SKILL.md` for active grid-inverter work;
  treat other `subskills/*/SKILL.md` files as evidence guides until populated.
- Use Simulink Agentic Toolkit/model-based-design skills for generic build, edit,
  simulate, and test mechanics; this skill adds PE-specific routing and evidence.
- Use `assets/` templates only when output needs a project README or diagnostic
  report.

## Operating Rules

- Inspect before editing: active/reference paths, commented subsystems,
  From/Goto routing, sample times, solver settings, measurement polarity, and
  generated artifacts.
- For control defects, trace backward level by level from modulation output to
  raw measurements.
- Parameters have physical meaning. Do not fit a ratio to hide line/phase
  voltage, transform, sign, or unit errors.
- For Simscape layout, classify nodes before drawing and keep common/return
  nodes local.
- When generating or rebuilding models, prefer visible block-and-connection
  structure over hiding complex plant or controller relationships inside one
  large MATLAB Function block. Use functions only for small, well-contained
  algorithms or when the user explicitly asks for script/function generation.
- Before declaring that a PE model is "accurate", name the chosen fidelity and
  the dynamics it excludes. If the study is about weak-grid damping, fault
  recovery, protection, harmonics, or GFL/GFM control choice, route through the
  corresponding project skill before accepting the result.
- For block-heavy PE models, make the top level an architecture view: separate
  plant/power electronics from control/scenario/diagnostics, then connect those
  areas with named `Goto`/`From` tags or buses.
- Keep subsystem names short and conventional. Prefer names like `Power`,
  `Control`, `Diagnostics`, `Load`, `Plant`, or `Power_Electronics` over long
  descriptive names that clutter the top level.
- Validate before success: update diagram, run the minimum relevant
  simulation, compare plant-side gates, check legal switch states, and report
  numeric results.
- Keep validation claims tiered. `opened` means the model file was accessible;
  `compiled` means update diagram passed; `simulated` means `sim` completed for
  the stated stop time; `measured` means relevant plant/control signals were
  logged or numerically checked. Do not upgrade a claim across tiers without
  evidence.
- If a waveform, gate, or control defect appears at a specific time step, route
  to `simulink-debug-commandline` / `sldebug` before making speculative
  topology edits. If the issue is solver resets, zero crossings, algebraic
  loops, or stiffness, route to `simulink-solver-profiler-analyzer`.
- Ask for missing model data, logs, or GUI state when available tools cannot
  access them.

## Boundary And Reporting

- If the domain is ambiguous, classify by source/load, topology, control
  objective, and validation signals first.
- This skill adds PE-specific routing, evidence standards, and diagnostics; it
  does not replace build/simulate/test skills or manage OS schedulers.
- Keep downloaded corpora, generated models, caches, and long-loop outputs out
  of source control under `data/pe-loop/` or `data/generated-models/`.
- Report root cause, changed paths, validation state, and remaining risks in the
  user's language.
