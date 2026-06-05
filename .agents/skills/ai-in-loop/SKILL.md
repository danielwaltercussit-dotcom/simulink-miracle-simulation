---
name: ai-in-loop
description: Use when the user asks for an AI-in-the-loop / closed-loop modeling cycle for the simulink_agent_v1 project. Triggers Spec to Build to Layout to Compile to Smoke-Sim to Tuning to sltest to Diagnose to Report iteration over the IEEE39 SG5/DFIG5 NEBUS layout case. Routes to the correct project-local skills, enforces report and traceability artifacts, and stops only when convergence and test targets are met or the iteration budget is exhausted.
---

# AI-in-Loop Orchestrator

This skill is the project-local **router and loop driver** for closed-loop power-system Simulink work in `C:\Users\jonas\Desktop\simulink_agent_v1`. It does not replace the existing skills — it sequences them and enforces a deterministic stop condition.

The current target case is `ieee39_10m39bus_sg5_dfig5_nebus_layout` (see Section 21 of `docs/MODELING_WORKFLOW_DRAFT.md`).

## Trigger

Invoke this skill when the user says any of:

- "跑一轮 AI 在环 / 闭环建模"
- "把 spec 改成 X，然后重建并验证"
- "排查 NaN / 失步 / 收敛失败"
- "为当前模型补一组 sltest 用例并跑通"
- "对 G4-G8 -> DFIG 替换跑完整闭环"
- 任何"换电源 / 换台数 / 改电压等级 / 改线路距离"的小改动

## Template-First Fast Path (token-saving)

When the user request matches one of the patterns in
`docs/MODELING_PATTERN_LIBRARY.md` Section 8 ("AI 复用流程"), do NOT re-derive
parameters from first principles. Instead:

1. Identify the matching pattern row (e.g., "改 200 km → 400 km 双回线").
2. Apply the prescribed one-line parameter change directly to the spec.
3. Skip S1 spec validation re-derivation; jump to S2 BUILD.
4. Reference the source model in `build/reports/loop/iter_<NN>/report.md`
   under `template_source` (e.g., `M01 NF_parameter_1220.m`).
5. Only fall back to full S1–S6 re-derivation if smoke or tune fails.

The full pattern catalogue (M01–M08) lives in
`docs/MODELING_PATTERN_LIBRARY.md`. Read its Sections 1–5 lazily, only when
the matching row in Section 8 references them.

## Hard Rules

1. Do **not** edit `NEBUS39V2.slx`, `NE39bus_dataV2.m`, `power_KundurTwoAreaSystem.slx`, `power_wind_dfig_avg.slx`. They are oracles.
2. Always work on a derived model under `build/generated_models/`.
3. Every loop iteration must end with a Markdown report under `build/reports/loop/` and a JSON status under `build/reports/loop/status.json`.
4. Three-phase physical SPS connections must never be replaced by `Goto/From`. Only ordinary Simulink measurement/control signals may.
5. Any parameter change must be recorded with `before -> after`, source spec section, and the loop iteration index.
6. If the same failure signature appears 2 iterations in a row with the same proposed fix, stop and ask the user.

## Loop State Machine

```
S0 INIT             → load project, check tools, read spec
S1 SPEC             → validate spec; if missing fields, ask user
S2 BUILD            → instantiate from templates per Section 6 of MODELING_WORKFLOW_DRAFT
S3 LAYOUT           → deterministic NEBUS-style coordinates; only auto-layout for control/measurement
S4 COMPILE          → SimulationCommand update; capture diagnostics
S5 SMOKE            → sim() to t_smoke (default 0.05 s)
S6 TUNE             → real closed-loop tuning: extract metrics → diagnose → set_param → re-sim, up to MaxRounds (default 5). Driven by tuning_registry.m + extract_tuning_metrics.m. See "S6 Closed-Loop Tuning" below.
S7 SLTEST           → run testing-simulink-model-verification fallback and any available testing-simulink-models harness
S7B MODELADVISOR    → independent Model Advisor gate (FS-016); soft-skips without Simulink Check
S8 DIAGNOSE         → match failure signature → propose fix → loop back to S2/S3/S6
S9 REPORT           → Markdown + status.json + screenshots + optional diagnostic figure manifest
```

Transitions:

- S4/S5/S6/S7 failure, or any blocking stage status other than `PASS`, → S8.
- S8 with no rule match → stop and report unknown failure.
- S9 PASS and `iteration_index == 0` → stop, success.
- S9 PASS and `iteration_index > 0` → stop, recovered.
- S9 still failing and `iteration_index >= max_iter` → stop, escalate to user.

Defaults: `max_iter = 5`, `t_smoke = 0.05 s`, `t_full = 1.0 s`, project root fixed.

Current implementation also runs S0.25 when `fidelity_decision=true` (default):
it writes `fidelity_decision.md/json` in the iteration directory and mirrors
the canonical decision under `build/reports/fidelity/`. Successful iterations
can also run S10C when `validation_evidence=true` (default), writing
`ibr_validation_evidence.md/json` for handoff-ready IBR model packages.

S2 now includes a hard device-adapter contract gate. `ai_in_loop_stage_build`
runs `scripts/adapters/inspect_device_adapter_contract.m` for both reused and
rebuilt derived models, writes `build/reports/adapters/<model>.md`, and maps
failures to `FS-020`.

S3 now includes a model quality / layout gate. `ai_in_loop_stage_layout` runs
`scripts/layout/audit_model_quality_layout.m`, writes
`build/reports/layout/<model>.md`, and maps failures to `FS-021`.

## Skill Routing per Stage

| Stage | Primary skill | Fallback / supporting |
|---|---|---|
| S0 | `building-simulink-models` (toolkit init) | `simulink-interactions` for inspection |
| S0.25 | `model-fidelity-selector` | run before build when the study objective may need RMS/phasor/EMT/small-signal/hybrid selection |
| S0.5 | `simulink-modeling-assistant` (pattern-match fast path) | skip if no M-row matches |
| S1 | `specifying-plant-models`, `specifying-mbd-algorithms` | `generate-requirement-drafts` |
| S2 | `building-simulink-models` | `simulink-modeling-assistant` for layout/parameter recipes; `simulink-interactions` for surgical edits |
| S3 | `simulink-auto-layout-github` | `simulink-modeling-assistant` layout cookbook for power-grid templates |
| S4 | `simulating-simulink-models` | `simulink-debug-commandline` |
| S5 | `simulating-simulink-models` | `simulink-profile-initialization` if init slow |
| S6 | `simulink-power-electronics` (PE) + project tuning scripts | `multitimescale-analysis` and `small-signal-modal-analysis` for cross-window or low-damping diagnosis; `impedance-frequency-analysis` for resonance/passivity evidence when frequency-response data exists; `weak-grid-scr-scenario` for low-SCR sensitivity; `simulink-solver-profiler-analyzer` if numeric issue; `matlab-optimize-performance` for slow tuning scripts |
| S7 | `simulink-model-verification`, `testing-simulink-models` | `sltest-harness-generation` for persistent S7 tests; `baseline-regression` for golden-run comparisons; `filing-bug-reports` if real defect found; `matlab-write-performance-tests` for `matlab.perftest` regressions in `scripts/loop/`; mathworks-ci-verify reference: `LaneFollowingExecModelAdvisor.m` pattern for ModelAdvisor harness |
| S8 | this skill (router) | `diagnostic-plotting` for failure-localization figures; `gfl-gfm-control-comparison` for controller-choice failures; `simulink-profiler-analyzer` for perf, `code-simplifier` / `matlab-modernize-code` for script cleanups |
| S9 | this skill | `diagnostic-plotting` for logsout figures and `figure_manifest.json` |
| S10 | this skill + `snapshot-auditor` | `snapshot-auditor` for copied package completeness before handoff; `ibr-model-validation-evidence` for handoff-ready plant/model credibility packages |

For S9 report figures, use `diagnostic-plotting` when smoke, tuning, scenario,
or regression evidence needs waveform plots beyond the root `top.png` layout
screenshot. Use `snapshot-auditor` before treating a copied AI summary package
as reusable evidence outside this workspace.

Use `model-fidelity-selector` before S2 when the requested study could be
answered at multiple fidelities (RMS/phasor, averaged EMT, switching EMT,
small-signal, impedance, or hybrid). Use `weak-grid-scr-scenario` and
`gfl-gfm-control-comparison` when the acceptance question depends on low system
strength or PLL/VSG/GFM/GFL control choice rather than only compile/smoke
success.
External reference repos (read-only, do not auto-import scripts):

- `external/github/mathworks-ci-verify` — pattern source for ModelAdvisor + sltest harness organisation. Treat as a template, not as code-on-path.
- `external/github/obra-superpowers/skills/verification-before-completion` — adopt the rule "do not declare PASS until artifacts exist on disk and have been re-read"; mirror this in S9 by re-reading `status.json` after writing.
- `external/github/obra-superpowers/skills/systematic-debugging` — adopt the "one root cause per iteration" rule; tracks against [[FS-007]] (consecutive identical signature → stop).
- `external/github/matlab-actions-run-tests` — GitHub Action only; do NOT call locally. Use as authoritative shape for `runtests` / `sltest.testmanager` invocations when expanding S7.

When in doubt, prefer official MathWorks MBD core skills (`building-simulink-models`, `simulating-simulink-models`, `testing-simulink-models`) over community ones.

For S2 device-template or donor-subsystem work, pair `building-simulink-models`
with `simulink-device-adapters` before moving to compile or simulation.
For S3 readability and layout work, pair `simulink-auto-layout-github` with
`simulink-model-quality-layout`; use the desktop lab archive as the read-only
style reference for spacing, grouping, and legal Goto/From use.

## Failure Signature Catalogue

Read `references/failure-signatures.md` before any S8 step. Add new entries only after the user confirms the diagnosis.

## Inputs

- `spec_path` (default `specs/case_ieee39_sg5_dfig5_v0.yaml`)
- `iteration_index` (auto, starts at 0)
- `max_iter`, `t_smoke`, `t_full`, `goal` (`smoke` | `tune` | `sltest` | `full`)
- `study_objective` (default `closed-loop Simulink model validation`)
- `fidelity` (`auto` or an explicit fidelity label)
- `fidelity_decision` (default `true`)
- `validation_evidence` (default `true`)

## Required Reports per Iteration

Under `build/reports/loop/iter_<NN>/`:

- `report.md` — outcome, stage results, diffs, screenshots
- `status.json` — machine-readable state for the next iteration
- `top.png` — root layout
- `diagnostics/figure_manifest.json` (if diagnostic plotting was requested or logsout is available)
- `tuning_report.md` (if S6 ran)
- `sltest_summary.md` (if S7 ran)
- `model_verification_summary.md` (if S7 ran)
- `snapshot_audit.md` when S10 snapshot export is enabled
- `fidelity_decision.md` or a linked fidelity report when model fidelity is
  part of the study question
- `ibr_validation_evidence.md` when the output is intended as a handoff-ready
  IBR plant/model package

The aggregate status at `build/reports/loop/status.json` always points to the latest iteration.

## MATLAB Entry Point

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
init_simulink_agent_project
ai_in_loop_run('goal','smoke','max_iter',5)
```

Implementation skeleton lives in `scripts/loop/`. Do not call internal helpers directly from chat — go through `ai_in_loop_run`.

## Execution Path (Agent → MATLAB)

The orchestrator is invoked through one of two channels. Pick MCP first; fall back to `-batch` only if MCP is unavailable.

### Primary: MATLAB MCP server

`mathworks/matlab-mcp-core-server` registered globally in `~/.claude.json` as the `matlab` MCP server. R2024b runs in `nodesktop` mode; session is persistent so subsequent calls hit a warm MATLAB. Typical per-call latency: 1–3 s.

Use this for any interactive iteration where the agent needs `sim()`, model inspection, or rapid `ai_in_loop_run` calls. Restart the Claude Code session after first install to pick up the MCP tools.

### Fallback: `matlab -batch`

When MCP is offline or being debugged:

```bash
"D:/Program Files/MATLAB/R2024b/bin/matlab.exe" -batch \
  "cd('C:/Users/jonas/Desktop/simulink_agent_v1'); init_simulink_agent_project; ai_in_loop_run('goal','smoke','max_iter',1,'fast',true)"
```

Cold start cost: 60–90 s for `init_simulink_agent_project`. Mitigations:

1. **`init_simulink_agent_project_cache`** — run once interactively to write project paths to MATLAB `pathdef.m`. Future `-batch` runs can drop the `init_simulink_agent_project` call and start in ~30 s.
2. **`'fast', true`** — skip layout audit on iter 0 and refuse to rebuild even if mtime is stale. Use only when the on-disk model is known good.

Do NOT use `-batch` from inside the loop iterations themselves — each iteration would pay the cold-start cost.

## Stopping Conditions

Stop and report to user when any of:

1. `goal` met and all checks PASS.
2. `max_iter` reached without success.
3. Same failure signature + same proposed fix observed 2 iterations in a row.
4. Spec validation fails and user input is needed.
5. Required oracle file is missing.

## Verification Before Completion (S9 contract)

Adapted from `external/github/obra-superpowers/skills/verification-before-completion`:

Before declaring PASS, S9 must:

1. Re-read `build/reports/loop/iter_<NN>/status.json` from disk (do not rely on in-memory state).
2. Confirm every required artifact in §"Required Reports per Iteration" exists and is non-empty.
3. Confirm `update`, `smoke`, and (if `goal>=tune`) `tune` flags in status.json are literal `true`, not strings.
4. If any check fails, mark iteration as `state: "incomplete"` and loop back to S2 unless `max_iter` exhausted.

This rule prevents "happy-path lying" where the orchestrator declares PASS while artifacts on disk show otherwise.

Current implementation hardens this contract in `scripts/loop/ai_in_loop_run.m`:

- each returned stage struct is checked by a hard gate; `FAIL` and blocking
  `SKIPPED` statuses enter S8 instead of being promoted to PASS.
- non-fast S2 compares model mtime against the build script and spec; stale
  derived `.slx` files are rebuilt.
- S3 writes `build/reports/layout/<model>.md` through
  `scripts/layout/audit_model_quality_layout.m`, checking overlap,
  signal-only Goto/From policy, logging surface, and oracle/reference hygiene.
- S7 writes/runs `tests/ai_in_loop_functional_model_test.m` and delegates to
  `scripts/verification/verify_power_system_model.m`; when Simulink Test
  `.mldatx` artifacts are present and the Test Manager API is available, it
  runs those artifacts before the functional fallback. It emits
  `sltest_summary.md` and `model_verification_summary.md`.
- S9 re-reads `status.json`, verifies `update/smoke/tune` booleans, verifies
  required `sltest` boolean for `goal>=sltest`, checks required artifacts, and
  ensures `top.png` and enabled `fidelity_decision` artifacts exist.
- successful iterations snapshot the model package to
  `C:\Users\jonas\Desktop\AI summary of simulation models\<model>\`.
- S10C writes `ibr_validation_evidence.md/json` through
  `scripts/loop/ai_in_loop_stage_ibr_validation_evidence.m` when
  `validation_evidence=true`.

## Output Style

- Final chat response: under 200 lines, in user's language, with paths to artifacts.
- Detailed evidence stays in `build/reports/loop/iter_<NN>/`.
- Never paste full `.slx` content or full MATLAB logs into chat. Reference paths.

## S6 Closed-Loop Tuning (real, since 2026-06-02)

S6 is **not** a pass-through anymore. It runs an inner loop:

```
1. sim(modelName, StopTime=tFull) → out
2. m = extract_tuning_metrics(out)
   - returns: nan_count, steady_V_pu, fault_recovery_ms,
     I_dom_freq_hz, I_osc_amp_A, I_osc_growth, damping_ratio,
     stable, fs_signature
3. if m.stable: PASS, return
4. else:
   - reg = tuning_registry(modelName)
   - knob = first reg entry whose fs_targets contains m.fs_signature
   - direction: if I_osc_growth > 1.05 → raise (+1) else lower (-1)
   - newVal = knob.scale_fcn(currentVal, direction); clamp to [min, max]
   - set_param(knob.block_path, knob.mask_param, mat2str(newVal))
   - save_system; goto 1
5. cap at MaxRounds (default 5)
```

Files:
- `scripts/loop/extract_tuning_metrics.m` — metric extractor
- `scripts/loop/tuning_registry.m` — per-model knob registry (currently
  covers W33 PLL ParK; expand here to add rotor-side / DC-link / speed loops)
- `scripts/loop/ai_in_loop_stage_tune.m` — the inner loop driver
- References: `.agents/skills/simulink-modeling-assistant/references/dfig-pll-tuning-refs.md`

Important behaviour notes:
- Direction is **empirical** (driven by `I_osc_growth`), not from prior
  literature. The literature rule "weak grid → lower PLL bandwidth" was the
  starting hypothesis but was wrong on this Asynchronous-Machine-based DFIG;
  the inner loop self-corrected by reading the live growth metric.
- The stage saves the model at every round so a CTRL-C / crash leaves the
  last attempted parameters on disk; reproducibility comes from re-running
  the build script (which resets the unstable initial state).
- Reference test bench: `nebus39_dfig_weakgrid_v0` — built specifically with
  an unstable PLL to exercise S6. Converges in 3 rounds: `[15 9.6 3 150]`
  → `[33.75 21.6 6.75 337.5]`, oscillation amplitude 298 A → 1 A.
