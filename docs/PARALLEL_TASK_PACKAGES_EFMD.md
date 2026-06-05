# Parallel E/F/M/D Task Packages

Date: 2026-06-05
Base branch: `integration/skills-maturation-2026-06`
Base commit: `5006a9a chore: align project package backlog`
Approval: user approved opening E/F/M/D work packages for parallel Claude Code
branches.

This file is tracked so new branch/worktree conversations can read the task
assignment without scanning the whole repository or relying on ignored handoff
files.

## Global Rules

- Keep task package names stable. Do not rename packages across handoffs.
- Start from the assigned branch. Do not merge parallel packages together.
- Keep changes package-local unless a validation-blocking issue requires a
  shared file edit.
- Do not restore `NEBUS39V2.slx`. It is intentionally absent because the user
  marked it privacy-sensitive.
- If a model reference is required, use the desktop read-only lab simulation
  archive folder. If the Chinese folder name is garbled in the terminal, list
  Desktop directories in PowerShell and identify the archive folder by
  inspection; do not copy private models back into the repo.
- Run `checkcode` on changed MATLAB files when MATLAB is available.
- Run package-specific smoke/contract tests.
- If a runnable Simulink/Simscape model is created or changed, actually load,
  update, or simulate it. Do not claim model validation from text alone.
- Write package artifacts under `build/reports/<package_slug>/`.
- Write branch handoff notes under
  `build/reports/agent_handoff/<package_slug>_claude_packet.md`.

## Branch Map

| Package | Branch | Primary Write Scope |
| --- | --- | --- |
| `E1 EMT/switching-level converter modeling` | `codex/e1-emt-switching-level` | `.agents/skills/emt-switching-level-converter/`, `scripts/analysis/summarize_switching_waveform_evidence.m`, `tests/emt_switching_evidence_contract_test.m` |
| `E2 detailed-average-dynamic-phasor model switching` | `codex/e2-fidelity-model-switching` | `.agents/skills/detailed-average-dynamic-phasor-switching/`, `scripts/analysis/summarize_fidelity_switch_evidence.m`, `tests/fidelity_switching_contract_test.m` |
| `F1 analytic FHA and impedance derivation` | `codex/f1-analytic-fha-impedance` | `.agents/skills/analytic-fha-impedance-derivation/`, `scripts/analysis/summarize_fha_impedance_response.m`, `tests/fha_impedance_derivation_contract_test.m` |
| `F2 multivariable control and cross-regulation tuning` | `codex/f2-control-cross-regulation` | `.agents/skills/multivariable-control-cross-regulation/`, `scripts/analysis/summarize_cross_regulation_tuning.m`, `tests/cross_regulation_tuning_contract_test.m` |
| `F3 perturbation and stability boundary scan` | `codex/f3-stability-boundary-scan` | `.agents/skills/perturbation-stability-boundary-scan/`, `scripts/analysis/summarize_stability_boundary_scan.m`, `tests/stability_boundary_scan_contract_test.m` |
| `M1 hybrid solver and multirate simulation` | `codex/m1-hybrid-solver-multirate` | `.agents/skills/hybrid-solver-multirate-simulation/`, `scripts/analysis/summarize_multirate_solver_plan.m`, `tests/multirate_solver_contract_test.m` |
| `M2 HIL readiness and real-time deployment prep` | `codex/m2-hil-readiness` | `.agents/skills/hil-readiness-real-time-prep/`, `scripts/analysis/summarize_hil_readiness.m`, `tests/hil_readiness_contract_test.m` |
| `D1 VSC/GFL-GFM support and evidence` | `codex/d1-vsc-gfl-gfm` | `.agents/skills/device-pack-vsc-gfl-gfm/`, `scripts/analysis/summarize_vsc_gfl_gfm_support.m`, `tests/vsc_gfl_gfm_support_contract_test.m` |
| `D2 MMC/HVDC support and evidence` | `codex/d2-mmc-hvdc` | `.agents/skills/device-pack-mmc-hvdc/`, `scripts/analysis/summarize_mmc_hvdc_support.m`, `tests/mmc_hvdc_support_contract_test.m` |
| `D3 storage/battery/BMS support and evidence` | `codex/d3-storage-bms` | `.agents/skills/device-pack-storage-bms/`, `scripts/analysis/summarize_storage_bms_support.m`, `tests/storage_bms_support_contract_test.m` |

## Package Plans

### E1 EMT/switching-level converter modeling

Build a contract-first project-local skill for detailed converter EMT work. It
must cover PWM, dead-time, switching-frequency limits, sample time, solver step,
device losses, harmonic evidence, transient event windows, and the boundary
between switching-level evidence and average-model evidence.

Minimum validation: a package-local smoke/contract test using synthetic data or
a tiny non-private model. If no runnable model is created, mark the branch as
contract-only.

### E2 detailed-average-dynamic-phasor model switching

Build a contract-first skill for switching between detailed switching, average,
dynamic phasor, RMS, and phasor abstractions. It must define equivalence
evidence: operating point, base values, retained bandwidth, loss assumptions,
initialization mapping, error metrics, and time-step ratio.

Minimum validation: a smoke test that rejects incomplete equivalence metadata.

### F1 analytic FHA and impedance derivation

Build a contract-first analytical/FHA impedance skill that links topology
assumptions, operating point, units, base values, sequence frame, frequency
grid, approximation limits, Bode/impedance evidence, and related time-domain run
linkage.

Do not rewrite the existing P3/P4 impedance helper stack in this branch. Treat
`.agents/skills/impedance-frequency-analysis/SKILL.md` as read-only context and
write integration notes for Codex if needed.

Minimum validation: a smoke test with a known transfer function or synthetic
circuit curve.

### F2 multivariable control and cross-regulation tuning

Build a contract-first skill for bottom-loop tuning in strongly coupled
converter systems. It must cover PI/PID voltage and current loops, sampling,
saturation, bandwidth targets, cross-coupling matrix, disturbance channels,
damping/stability margins, and retune rationale.

Minimum validation: a smoke test that distinguishes documented tuning evidence
from an undocumented gain tweak.

### F3 perturbation and stability boundary scan

Build a contract-first skill for deterministic grid scans and Monte Carlo
boundary scans across parasitics, filter values, grid strength, controller
gains, and operating points. It must require varied parameters, ranges, random
seed, sample count, pass/fail metric, boundary interpolation method, and artifact
manifest.

Minimum validation: a synthetic scan smoke test.

### M1 hybrid solver and multirate simulation

Build a contract-first skill for cross-time-scale solver selection. It must
cover stiffness detection, fixed/variable step settings, local solver
boundaries, discrete step sizing, fastest switching event, slowest
electromechanical mode, rate transition policy, algebraic loop handling, and
numerical-stability warnings.

Minimum validation: a smoke test that catches impossible or undocumented
step-size choices.

### M2 HIL readiness and real-time deployment prep

Build a software-only HIL readiness skill for fixed-step feasibility,
algebraic-loop risk, unsupported blocks, code-generation constraints, subsystem
partitioning, I/O mapping placeholders, latency budget, and real-time
deployability evidence.

Minimum validation: a synthetic readiness manifest smoke test. Evidence must be
marked software-readiness only unless actual HIL hardware evidence is supplied.

### D1 VSC/GFL-GFM support and evidence

Build a VSC/GFL-GFM device support skill connecting control mode, weak-grid
SCR/ESCR, modal evidence, impedance evidence, fault ride-through,
active/reactive controls, PLL or grid-forming assumptions, and validation
artifacts.

Minimum validation: a package-local contract test/report.

### D2 MMC/HVDC support and evidence

Build an MMC/HVDC support skill covering submodule type, arm energy,
circulating-current control, DC-link dynamics, converter station assumptions,
AC/DC faults, control mode, and validation evidence.

Minimum validation: a synthetic contract test or tiny non-private example.

### D3 storage/battery/BMS support and evidence

Build a storage/BMS support skill connecting battery/BMS evidence,
bidirectional converter assumptions, SOC/SOH, thermal limits, protection,
grid-support mode, DC-link interactions, and validation artifacts.

Minimum validation: a contract test that separates battery/BMS evidence from
generic DC-link converter evidence.

## Copy-Paste Prompt Skeleton

For a new Claude Code dialog, use:

```text
You are working in C:\Users\jonas\Desktop\simulink_agent_v1 on branch <branch-name>.

Task package: <stable package name>.

First read AGENTS.md, docs/CODEX_CLAUDE_COLLABORATION.md, docs/PARALLEL_TASK_PACKAGES_EFMD.md, and build/reports/agent_handoff/latest_claude_packet.md if it exists in this worktree. Respect the privacy boundary: do not restore NEBUS39V2.slx; if needed, use the desktop read-only lab simulation archive folder as reference only. If the Chinese folder name is garbled in the terminal, list Desktop directories in PowerShell and identify it by inspection.

Use only the write scope listed for your package in docs/PARALLEL_TASK_PACKAGES_EFMD.md unless a validation-blocking issue forces a shared edit. Keep artifacts package-local. Run checkcode on changed MATLAB files and run your package smoke/contract test. If you create or change a runnable Simulink/Simscape model, actually load/update/simulate it or explain exactly why that was not possible.

At the end, update build/reports/agent_handoff/<package_slug>_claude_packet.md with: changed files, tests run, PASS/WARN/MISSING evidence, files intentionally not touched, and any integration notes for Codex. Do not merge this branch.
```
