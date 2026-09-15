# Agentic Simulink Modeling Policy

This file distills external Simulink modeling skill experience into the
project-local workflow. It is a reference only; do not install external skills
or global skill links from here.

## Official SATK Gates

Before model construction or extension, check whether the project has:

- `.satk/reuse-libraries.json`
- `.satk/block-policy.json`
- `.satk/library-kg/index.md`

If present, these files constrain block choice, custom-library preference,
blocked library blocks, and protected parameters. If
`reuse-libraries.json` declares `confirmedNone: true`, no custom-library gate
is required. If the files are missing, do not assume a custom-library policy;
ask before creating `.satk` policy state.

Use `model_read` before edits, `model_edit` for structural edits, `model_read`
after edits, and `model_check` before declaring the scope complete. When
`model_edit` reports a partial edit, immediately run both `model_read` and
`model_check`.

## Debug And Profiling Routing

- Wrong value at a specific time step or block method: use
  `simulink-debug-commandline` / `sldebug` before speculative rewiring.
- Slow update diagram or initialization: use
  `simulink-profile-initialization`.
- Slow simulation or release-to-release runtime regression: use
  `simulink-profiler-analyzer`.
- Solver resets, zero crossings, algebraic loops, Jacobian churn, or stiffness
  suspicion: use `simulink-solver-profiler-analyzer`.

Keep these as diagnostic routes, not as default build steps.

## Power-Electronics Evidence Boundary

For converter, HVDC, DFIG, VSG/GFL/GFM, weak-grid, storage, BMS, or Simscape
Electrical work:

- classify domain, topology, control objective, and active validation signals
  before editing;
- inspect active/commented/variant paths, From/Goto tags, sample times, solver
  settings, measurement polarity, and generated artifacts;
- track validation state explicitly as `opened`, `compiled`, `simulated`, and
  `measured`;
- do not call a waveform or controller issue fixed until relevant controller
  outputs and plant-side signals have numeric evidence.

## Layout Boundary

Ordinary signal-flow subsystems may use official `model_edit` layout modes:
`full` for empty scopes and `incremental` for existing scopes. Power-system
top-level canvases, SPS/Simscape one-line diagrams, benchmark topology views,
and busbar layouts use deterministic project coordinates. Never run global
root-level `arrangeSystem` on those scopes.

## External Skill Intake (2026-09-14)

User-authorized GitHub review installed only two lean, project-local MIT
adaptations. Fixed revisions below record what was inspected, not a promise
to follow upstream automatically. Preserve each installed skill's LICENSE.

| Repository | Inspected commit | Decision |
|---|---|---|
| [h4vzz/awesome-ai-agent-skills](https://github.com/h4vzz/awesome-ai-agent-skills/tree/1615e6bb5fc09492de89fa864cf3d1dc88a5db9e) | `1615e6bb5fc09492de89fa864cf3d1dc88a5db9e` | Adapt `knowledge-graph-creation`; Markdown relationships, no graph database or mandatory exports |
| [BESSER-PEARL/research-agent-skills](https://github.com/BESSER-PEARL/research-agent-skills/tree/03d3c49ac1698c9d29cc4c0f5e8eeca17210bd51) | `03d3c49ac1698c9d29cc4c0f5e8eeca17210bd51` | Adapt `research-paper-review`; formula/evidence/transfer checks, no venue-review boilerplate |
| [matlab/simulink-agentic-toolkit](https://github.com/matlab/simulink-agentic-toolkit/tree/9c591b28d998c51a87ca802d228c5c6a11a4bcd9) | `9c591b28d998c51a87ca802d228c5c6a11a4bcd9` | Distill frequency-response and fault-injection workflows into existing references; do not bulk-copy MathWorks-licensed skills |
| [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills/tree/0b2afe68a5f9379097ad815e028af664f1e222b7) | `0b2afe68a5f9379097ad815e028af664f1e222b7` | MIT; reviewed literature workflow, not installed: mandatory generated visuals and additional outputs do not fit this scope |
| [huanhyougo/matlab-power-electronics-skill](https://github.com/huanhyougo/matlab-power-electronics-skill/tree/4a0db6cf1c3e52da8ce12c41e8d38de1f36b7817) | `4a0db6cf1c3e52da8ce12c41e8d38de1f36b7817` | No declared repository license verified; retain existing local PE workflow, no new code/model copying |

Official upstream pointers inspected: `skills-catalog/control-systems/`
`simulink-frequency-response/SKILL.md` and
`skills-catalog/verification-validation-and-test/inject-faults/SKILL.md`.

For sweeps use the qualified experiment and duration gates in
[impedance contract](../../impedance-frequency-analysis/references/impedance-contract.md).
Do not inherit a zero-DC-gain failure heuristic or imply that PRBS always
identifies a meaningful linear model under discontinuities.

Fault-injection APIs are optional and toolbox/version-gated. A corrupted
measurement or signal is not an electrical short circuit. Define the actual
physical fault topology, impedance, timing, clearing/protection, and monitored
quantities for a power-system fault study. Record baseline fault states and
restore them after a probe; never remove another task's fault definitions.
No new fault-injection runtime was installed by this knowledge update.
