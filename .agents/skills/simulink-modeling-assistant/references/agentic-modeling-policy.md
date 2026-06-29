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
