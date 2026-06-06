---
name: hil-readiness-real-time-prep
description: Use when preparing a Simulink / Simscape power-electronics model for future RTDS, OPAL-RT, Speedgoat, or other real-time / hardware-in-the-loop deployment, and you need a software-side readiness assessment - fixed-step feasibility, algebraic-loop risk, codegen-unsupported blocks, code-generation constraints, subsystem partitioning, I/O mapping placeholders, and per-step latency budget. Produces software-readiness evidence only; it does NOT claim hardware-in-the-loop validation unless real HIL hardware evidence is supplied.
---

# HIL / Real-Time Readiness Prep (Software-Side)

Use this skill to decide whether a model is *ready to attempt* real-time /
hardware-in-the-loop bring-up, and to record what still blocks it. It is a
software-side gate that runs on model metadata, before any hardware is touched.

## Core Rule

This skill produces **software-readiness evidence only**. It reasons over a
readiness *manifest* (metadata the caller already has); it does not open,
compile, or simulate a model, and it never writes RTDS / OPAL-RT / Speedgoat
target configuration. A clean result means "the software side looks ready to
*attempt* real-time deployment", not "this runs in real time on hardware".

Results are labeled `software_readiness_only` and `real_time_deployable=false`
unless the manifest supplies real HIL hardware evidence (a logged real-time run
with no overruns). Never upgrade a software check to a hardware claim.

## Three-Status Headline

The helper deliberately separates three ideas so a complete contract is never
mistaken for a deployable model (this is the M1/D2 review lesson):

- `contract_status`: `PASS` | `WARN` | `MISSING` - manifest completeness and
  internal consistency.
- `readiness_class`: `software_readiness_only` | `hardware_backed` - only
  `hardware_backed` when real HIL evidence is attached.
- `handoff_ready`: true only when no **blocking** finding remains. Non-blocking
  WARNs (I/O placeholders, single-rate assumption, latency not yet computed)
  are allowed to carry forward.
- `real_time_deployable`: true only when `handoff_ready` AND `hardware_backed`.

## The Seven Checks

| # | Check | Blocking | Looks for |
|---|---|---|---|
| 1 | `fixed_step_feasibility` | yes | fixed-step solver; step resolves the fastest event (>=2x) |
| 2 | `algebraic_loop_risk` | yes | no algebraic loops, or explicitly broken |
| 3 | `unsupported_blocks` | yes | a support scan ran; no codegen-unsupported blocks remain |
| 4 | `codegen_constraints` | yes | target supported; continuous states discretized under fixed step |
| 5 | `partitioning` | no | subsystem partitions declared with rate (+ compute) |
| 6 | `io_mapping` | no | I/O channels declared; placeholders flagged for binding |
| 7 | `latency_budget` | yes | total per-step compute fits the step budget across cores |

Blocking checks veto `handoff_ready`. Non-blocking checks (partitioning,
io_mapping) surface follow-up work but do not block bring-up.

## Workflow

1. Assemble a readiness manifest (see `references/hil-readiness-contract.md`).
   Undocumented solver / loops / codegen fields become `MISSING`, not silent
   passes.
2. Run the helper to classify all seven checks and the three-status headline.
3. Resolve blocking findings first: pick a fixed-step solver, break algebraic
   loops, remove unsupported blocks, fix the codegen target, or re-budget
   compute / step size.
4. Treat non-blocking WARNs (I/O placeholders, single-rate assumption) as
   bring-up to-dos; they may be carried into handoff.
5. Only mark `hardware_backed` once a real HIL run log (no overruns) exists.

## Helper

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
manifest = struct( ...
    "case_name", "vsc_rt_candidate", ...
    "source_model_or_script", "my_vsc_model", ...
    "solver_type", "fixed_step", "fixed_step_s", 20e-6, ...
    "fastest_event_s", 100e-6, ...
    "algebraic_loops_present", false, ...
    "unsupported_blocks_checked", true, "unsupported_blocks", {{}}, ...
    "codegen_target_supported", true, "continuous_states_present", false, ...
    "cpu_cores", 2, "step_budget_s", 20e-6);
summary = summarize_hil_readiness(manifest, ...
    "OutputDir", "build/reports/m2_hil_readiness/vsc_rt_candidate");
```

The helper is pure base-MATLAB (no toolbox dependency). It does not run a model;
supply the metadata.

## Output

```text
build/reports/m2_hil_readiness/<case>/
  hil_readiness_summary.md
  hil_readiness_summary.json
```

## Privacy / Model Boundary

Do not restore `NEBUS39V2.slx`. If a real model reference is needed, use the
read-only desktop lab simulation archive as reference only; never copy private
models into the repo. This skill does not need a model file to run.

Read `references/hil-readiness-contract.md` before changing checks, status
semantics, blocking policy, or the software-vs-hardware labeling.
