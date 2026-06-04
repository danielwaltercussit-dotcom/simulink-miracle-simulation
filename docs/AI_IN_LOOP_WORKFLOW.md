# AI-in-Loop Workflow

Project: `C:\Users\jonas\Desktop\simulink_agent_v1`
Status: v0.1 (initial closed-loop spec, derived from `docs/MODELING_WORKFLOW_DRAFT.md` Sections 6, 8, 11, 21)

## 1. Why this exists

The project already has good static skills for **what** to build (templates, layout, PE rules) and **how** to inspect a model. What was missing is a deterministic **loop driver** that keeps Spec, Build, Layout, Compile, Smoke Sim, Tuning, sltest and Diagnose in lockstep, with reports under `build/reports/loop/`.

`AI-in-loop` is that driver. It does not replace any existing skill — it sequences them.

## 2. Loop overview

```
spec.yaml ─▶ S0.25 fidelity ─▶ S1 validate ─▶ S2 build ─▶ S3 layout ─▶ S4 compile ─▶ S5 smoke
                                                                              │
                                                                              ▼
                                            S6 tune ◀── S8 diagnose ◀─────────┘
                                               │             ▲
                                               ▼             │
                                            S7 sltest ───────┘
                                               │
                                               ▼
                                            S7B model-advisor
                                               │
                                               ▼
                                            S9 report ─▶ S10 snapshot ─▶ S10B snapshot-audit ─▶ S10C IBR-evidence
```

S0.25 (fidelity decision) and S10C (IBR validation evidence) are optional,
on by default, and gated by `fidelity_decision` / `validation_evidence`.
S10/S10B run when `snapshot` is enabled.

Stages, primary skills and stop conditions are documented in
`.agents/skills/ai-in-loop/SKILL.md`. This document is the human-facing
explanation; the SKILL.md is the agent-facing contract.

## 3. Iteration artifacts

Every iteration writes:

```
build/reports/loop/iter_<NN>/
  report.md
  status.json
  top.png
  fidelity_decision.md/json      # only if S0.25 ran (fidelity_decision=true)
  tuning_report.md               # only if S6 ran
  sltest_summary.md              # only if S7 ran
  model_verification_summary.md  # only if S7 ran
  snapshot_audit.md              # only if S10B ran (snapshot enabled)
  ibr_validation_evidence.md/json # only if S10C ran (validation_evidence=true)
build/reports/loop/status.json   # always points to latest iteration
```

The canonical fidelity decision is also mirrored under
`build/reports/fidelity/<case>_fidelity_decision.md/json`.

On successful iterations the runner also snapshots the model package to:

```text
C:\Users\jonas\Desktop\AI summary of simulation models\<model>\
```

The snapshot includes the generated `.slx`, spec, build script, project or loop
report, relevant PNGs, latest loop status, and a `snapshot_manifest.json`.

The agent never echoes full logs into chat. It quotes paths.

## 4. Stop conditions

The loop stops when any of:

1. The chosen `goal` is met and all checks PASS.
2. `max_iter` is reached.
3. The same failure signature appears two iterations in a row with the same proposed fix (FS-007).
4. Spec validation needs user input.
5. An oracle file is missing (FS-008).

## 5. Goals

- `smoke` — minimum: build → compile → 50 ms simulation.
- `tune` — adds: load-flow + initialization + 1 s simulation under convergence targets.
- `sltest` — adds: run persistent model tests. If Simulink Test `.mldatx`
  artifacts are present and the Test Manager API is available, S7 runs them.
  S7 also runs `tests/ai_in_loop_functional_model_test.m`, which delegates to
  `scripts/verification/verify_power_system_model.m` for compile, smoke-sim,
  finite-output, InitFcn, and root-overlap checks.
- `full` — all of the above + screenshot exports + traceability index refresh.

## 6. MATLAB entry

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
init_simulink_agent_project
ai_in_loop_run('goal','smoke','max_iter',5)
```

See `scripts/loop/ai_in_loop_run.m`.

## 7. Evidence policy

Evidence rules inherit from `simulink-power-electronics`:

- `opened` < `compiled` < `simulated` < `measured`. The loop never claims a higher state than has actually been verified.
- For each stage transition, append the achieved state to `status.json`.
- For `goal=sltest` or `goal=full`, `status.json` must contain literal
  `sltest=true` before S9 can pass.
- A stage may not declare overall success merely by returning a struct. The
  loop checks each required `status` and sends `FAIL` or blocking `SKIPPED`
  states to S8 diagnosis.
- S9 re-reads `iter_<NN>/status.json`, verifies required artifacts, and checks
  literal `update/smoke/tune/sltest` booleans before PASS is final.

## 8. Skill routing

See the table in `.agents/skills/ai-in-loop/SKILL.md`. Prefer official MathWorks MBD core skills; only fall back to community / project-local skills when their scope is the better match (e.g., layout for power-grid one-line diagrams, PE-specific routing).

## 9. Out of scope

This skill does not:

- Modify oracle models (`NEBUS39V2.slx`, `NE39bus_dataV2.m`,
  `power_KundurTwoAreaSystem.slx`, `power_wind_dfig_avg.slx`).
- Manage OS-level schedulers, CI, or Git operations.
- Replace three-phase physical SPS connections with `Goto/From`.

## 10. Future work

- Wire up `matlab/skills` and `matlab/matlab-agentic-toolkit` skills once they
  are cloned under `external/github/`. Candidate list:
  - `matlab/skills` — official MATLAB Agent Skills collection.
  - `matlab/matlab-agentic-toolkit` — MATLAB session sharing + MCP server, complements
    `simulink-agentic-toolkit`.
  - `mathworks/Continuous-Integration-Verification-Simulink-Models` — CI verification patterns.
  - `obra/superpowers` — generic Claude Code skill router (if the user wants a
    cross-skill orchestrator at agent level rather than at MATLAB level).
- Add `S10 EXPORT` for HIL targets (Speedgoat / RT) when needed.
- Add `S11 RL_TUNE` to wrap Reinforcement Learning Toolbox tuning when rule-based
  S6 can no longer make progress.
