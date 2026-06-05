# Old Context Keywords

Generated: 2026-06-05

This is the compressed replacement for the deleted `.ctx/context.db`. It keeps
only keywords and source metadata. Do not restore or reload the old context
database unless the user explicitly asks for deep historical recovery.

## Core Keywords

Simulink, MATLAB, IEEE39, NEBUS39, NEBUS39V2, SG, DFIG, VSC, MMC, LCC, HVDC,
PLL, VSG, GFL, GFM, weak-grid, SCR, ESCR, modal, impedance, frequency-response,
passivity, resonance, damping, cross-timescale, EMT, RMS, averaged EMT,
small-signal, IBR validation, traceability, snapshot, snapshot-auditor,
diagnostic-plotting, baseline-regression, multitimescale-analysis,
sltest-harness-generation, model-fidelity-selector,
small-signal-modal-analysis, weak-grid-scr-scenario,
gfl-gfm-control-comparison, ibr-model-validation-evidence,
lab-model-pattern-miner, impedance-frequency-analysis.

## Workflow Keywords

ai-in-loop, S0.25, S1, S2, S3, S5, S5B, S6, S7, S7B, S8B, S9, S10, S10B, S10C,
spec validation, adapter contract, layout quality, smoke simulation, tuning,
sltest fallback, Model Advisor, report verification, snapshot copy, snapshot
audit, IBR evidence matrix, stale artifact cleanup, checkcode, fast MATLAB
validation, handoff packet, Codex review, Claude Code implementation.

## Model/Layout Keywords

Goto/From, explicit three-phase wiring, powergui, root overlap, subsystem
encapsulation, line routing, port orientation, source-to-grid horizontal flow,
left/right area symmetry, M01-M08 pattern library, lab archive read-only,
AI summary of simulation models, generated model cleanup, oracle preservation.

## Historical Sources Compressed

- `codex-rollout:simulink-long-session`: original oversized Simulink modeling
  thread, formerly about 12 MB in `.ctx/context.db`.
- MATLAB layout/build traces from 2026-05-14: v05/v06/v07 layout optimization,
  PMIO introspection, root line/port inspection, and generated report evidence.
- `docs/CODEX_CLAUDE_COLLABORATION.md` indexed snapshot from 2026-06-04.

## Current Replacement Sources

- `docs/CODEX_CLAUDE_COLLABORATION.md`: role split, backlog, review rules,
  token-saving rules, and handoff protocol.
- `build/reports/agent_handoff/latest_claude_packet.md`: latest in-flight
  Claude/Codex handoff.
- `docs/MODELING_WORKFLOW_DRAFT.md`: current modeling workflow.
- `docs/MODELING_PATTERN_LIBRARY.md`: reusable lab-model parameters and layout
  patterns.
- `.agents/skills/ai-in-loop/SKILL.md`: AI-in-loop stage router and gate map.
