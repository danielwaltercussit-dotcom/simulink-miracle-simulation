# Failure Signature Catalogue

Each entry maps an observed symptom to a confidence level, the most likely root cause, the recommended automated fix in the loop, and the loop stage to jump back to.

Add a new entry only when the user confirms the diagnosis or when the same fix has been validated by smoke + sltest.

## FS-001 SimulationCommand update fails with unresolved variable

- **Symptom**: `Unrecognized function or variable 'X'` during S4.
- **Likely cause**: `InitFcn` did not run `NE39bus_dataV2.m` or alias variable missing (e.g., one of `Tnum1_PSS`, `Tden1_PSS`, `Twashout_PSS`, `Tw_PSS`, `Tsensor_PSS`, `Ts_PSS`, `K_PSS`, `Vmax_PSS`, `Vmin_PSS`).
- **Auto-fix**: ensure derived model `InitFcn` calls `NE39bus_dataV2`; inject the alias block from Section 21 of `MODELING_WORKFLOW_DRAFT.md`. Re-run S4.
- **Jump to**: S2 (regenerate InitFcn) → S4.

## FS-002 Algebraic loop on root canvas

- **Symptom**: compile reports algebraic loop; usually after rotating or moving control blocks.
- **Likely cause**: reorder broke a Memory/UnitDelay or duplicated a feedthrough path.
- **Auto-fix**: revert the last layout move on the offending subsystem; if it persists, insert `Memory` block at the loop break recommended by Simulink diagnostic.
- **Jump to**: S3 → S4.

## FS-003 Solver step returned NaN within first 1 ms

- **Symptom**: `sim()` aborts with NaN at t < 1 ms.
- **Likely cause**: bad initial conditions on DFIG W3x — usually `WindSpeed` or `Vdc0` not provided after replacing `G4`-`G8`.
- **Auto-fix**: re-apply DFIG mask defaults from `power_wind_dfig_avg.slx`; verify `UserData.benchmark_machine_id` exists.
- **Jump to**: S2 (re-apply parameters) → S4 → S5.

## FS-004 Loss of synchronism within 1 s

- **Symptom**: max rotor angle deviation > 90 deg in smoke run.
- **Likely cause**: governor / AVR gains incompatible with replacement scenario (e.g., G4-G8 governor still active after SG removal).
- **Auto-fix**: zero out governor references for replaced rows; recompute Pref from spec; re-run S5.
- **Jump to**: S6 → S5.

## FS-005 Root layout overlap > 0 (excluding DFIG aux)

- **Symptom**: `Root overlap count excluding DFIG signal auxiliaries > 0` in layout audit.
- **Likely cause**: deterministic offset for new DFIG block did not clear an existing measurement block.
- **Auto-fix**: nudge offending DFIG aux by one block-width on the orientation-orthogonal axis; do not auto-route SPS lines.
- **Jump to**: S3 → S4.

## FS-006 sltest assertion fails on bus voltage range

- **Symptom**: `voltage_pu in [0.9, 1.1]` violated for some bus.
- **Likely cause**: missing reactive support after DFIG replacement; PV/PQ classification mismatch.
- **Auto-fix**: tune DFIG `q_control` to `voltage` mode for that bus; re-run S6 → S5 → S7.
- **Jump to**: S6.

## FS-007 Same failure signature twice with same fix

- **Symptom**: identical entry in two consecutive `iter_<NN>/status.json`.
- **Auto-fix**: stop the loop. Surface the signature, the fix that did not work, and the relevant log path to the user.
- **Jump to**: end loop, ask user.

## FS-008 Missing oracle file

- **Symptom**: `NEBUS39V2.slx`, `NE39bus_dataV2.m`, `power_wind_dfig_avg.slx`, or `power_KundurTwoAreaSystem.slx` not found.
- **Auto-fix**: stop. Do not attempt to regenerate.
- **Jump to**: end loop, ask user.

## Adding new entries

When adding FS-009+, include: ID, symptom, evidence path, likely cause, auto-fix, target loop stage to jump to, and date observed. Keep entries terse — link to the generating `iter_<NN>/report.md` for detail.

## FS-019 Spec validation failed before build

- **Symptom**: S1 returns `AIInLoop:SpecValidationFail`.
- **Likely cause**: missing required `system` field, missing `convergence_targets`, no `topology` / `replacement_policy`, invalid sample time, unsupported frequency, or invalid fault window.
- **Auto-fix**: do not build. Patch the spec using `simulink-spec-validator` and, if needed, `scenario-fault-library`; re-run S1.
- **Jump to**: S1.

## FS-020 Device adapter contract failed during build

- **Symptom**: S2 returns `AIInLoop:AdapterContractFail` and writes `build/reports/adapters/<model>.md`.
- **Likely cause**: a generated device subsystem has no adapter-facing ports, duplicate device naming, missing self-contained model `InitFcn`, or missing trace metadata when strict trace is enabled.
- **Auto-fix**: patch the build script with `simulink-device-adapters`: keep physical SPS ports explicit, add signal ports only for control/measurement, set donor aliases in `InitFcn`, and attach `UserData` trace metadata where practical. Rebuild before compile/sim.
- **Jump to**: S2.

## FS-021 Model quality / layout audit failed

- **Symptom**: S3 returns `AIInLoop:ModelQualityLayoutFail` and writes `build/reports/layout/<model>.md`.
- **Likely cause**: root canvas overlap, Goto/From tag that appears to carry physical SPS terminals, missing measurement/logging surface, or missing project oracle files.
- **Auto-fix**: use `simulink-model-quality-layout` plus `simulink-auto-layout-github`; keep physical three-phase wiring explicit, reserve Goto/From for signal tags like `Utabc` / `Itabc`, add `To Workspace` or root `Outport` logging, and re-run S3.
- **Jump to**: S3.

## FS-022 Reported bus voltage is near zero but SPS netlist is connected

- **Symptom**: one monitored bus appears near `0 V` while compile succeeds and
  `power_analyze` shows its transformer/network nodes are connected.
- **Likely cause**: the VI measurement block emits per-unit voltage while
  downstream analysis assumes physical volts and divides by `Vbase` again, or
  otherwise mixes phase-to-ground and phase-to-phase measurement contracts.
- **Auto-fix**: compare the suspect VI block with a healthy peer; audit
  `VoltageMeasurement`, `Vpu`, `VpuLL`, `Vbase`, output tag, and downstream
  normalization. Directly log the raw output. Change physical wiring only if
  the corrected raw physical-voltage signal remains near zero.
- **Jump to**: S5/S7 measurement and evidence checks, then S2 only if a real
  electrical disconnection is proven.
- **Observed**: 2026-06-09, IEEE39 SG5/DFIG5 bus 34 false-island diagnosis.

## FS-009 DFIG `wpll` long-time below 1.0, not converging

- **Symptom**: PLL angular frequency stuck below the system base.
- **Likely cause**: dq frame mismatch — `theta_pll - theta_s` not used in coordinate rotation; PLL kp insufficient bandwidth.
- **Auto-fix**: verify rotation `cos(theta_pll - theta_s)` is applied to `igdvsg`/`igqvsg`; multiply PLL kp by `sqrt(2)` (per M01).
- **Jump to**: S2 → S5.

## FS-010 VSG terminal voltage magnitude collapses to 0

- **Symptom**: `Vtmag` drops to ~0 and `x_ut_` saturates.
- **Likely cause**: `Uref` and `Vtmag` are in different coordinate frames; `x_ut` integrator initialised at 0.
- **Auto-fix**: ensure both in pu line-to-line peak; initialise `x_ut1 ≈ 0.53`, `x_ut2 ≈ 0.79` per M01 `Initial_data_doudfig_case2_VSGtest_1220.m`.
- **Jump to**: S2 → S5.

## FS-011 LCC inverter alpha locks at 90 deg

- **Symptom**: `Alpha_inv` saturates at `alpha_min_inv`.
- **Likely cause**: voltage filter time constant or initial value missing; `Vdc_inv_filt(1)` left at 0.
- **Auto-fix**: set `T_filt_V = 0.02 s`, initial `Vdc_inv_filt = 1.0` pu (per M06).
- **Jump to**: S2 → S5.

## FS-012 MMC arm current spike at start

- **Symptom**: arm current peaks far beyond rating in the first ms.
- **Likely cause**: arm reactance using wrong base; `Lm_pu` computed against system Lbase but Carm is in real units.
- **Auto-fix**: keep `Carm = 6.17e-5` in SI; `Lm_pu = 0.05 / Lbase` against the **MMC-side** base (291 kV in M05).
- **Jump to**: S2 → S5.

## FS-013 50 Hz oscillation does not damp

- **Symptom**: 50 Hz mode persists in time domain.
- **Likely cause**: M03-style oscillation amplifier coefficients (`Co_Rrs / Co_Lm / Co_Lls / Co_Lrs / Ls2`) accidentally left at study values.
- **Auto-fix**: reset all `Co_*` to 1.0 unless the spec explicitly requests oscillation analysis mode.
- **Jump to**: S6 → S5.

## FS-014 ~2 Hz low-frequency oscillation

- **Symptom**: slow ~2 Hz oscillation in voltage / power.
- **Likely cause**: terminal-voltage outer loop bandwidth too high (M03: `Covol > 0.8` triggers it); PLL kp too aggressive.
- **Auto-fix**: drop `Covol` to 0.6–0.8; if PLL `Kp` was multiplied by sqrt(2) for FS-009, halve it for the affected unit.
- **Jump to**: S6 → S5.

## FS-015 status.json claims PASS but artifact missing on disk

- **Symptom**: `iter_<NN>/status.json` has `state: "pass"` but `report.md` / `top.png` / `tuning_report.md` is missing or 0-byte.
- **Likely cause**: orchestrator declared completion from in-memory state without re-reading disk (violates "Verification Before Completion" contract).
- **Auto-fix**: rewrite the status to `state: "incomplete"`, do not bump iteration counter, jump back to the stage whose artifact is missing. If FS-015 fires twice in a row, stop loop and ask user (the writer itself is broken).
- **Jump to**: stage owning the missing artifact (S3 / S6 / S7 / S9).
- **Source**: adopted from `external/github/obra-superpowers/skills/verification-before-completion`.

## FS-016 Model Advisor reports critical findings on derived model

- **Symptom**: Model Advisor (run via S7-extended ModelAdvisor harness) flags one or more "Fail" / "Warn-as-fail" checks on `build/generated_models/*.slx`.
- **Likely cause**: deterministic build did not propagate sample times / data types after replacing G4-G8 subsystems; or rate-transition added by layout pass left a `Warning` check.
- **Auto-fix**: capture full report under `iter_<NN>/model_advisor_summary.md`; for sample-time warnings, set explicit `Ts` on inserted measurement blocks; for "unset" data type warnings, inherit from upstream port. Do **not** bypass by disabling the check.
- **Jump to**: S2 (parameter / wiring fix) → S4.
- **Source**: pattern from `external/github/mathworks-ci-verify/Scripts/LaneFollowingExecModelAdvisor.m`; do not import the script — re-implement in `scripts/loop/ai_in_loop_stage_modeladvisor.m` when adding the harness.

## FS-017 set_param failed: mask parameter name not real

- **Symptom**: `Simulink:Commands:ParamUnknown` at build-script `set_param`. Message form: ``<block> 没有名为 'X' 的参数``.
- **Likely cause**: build script guessed a friendly mask name (e.g. `Amplitude`, `Frequency`, `Winding1Type`) instead of the real internal mask name (e.g. `PositiveSequence`, `Winding1Connection`).
- **Auto-fix**: at build time, before calling set_param on a newly added masked block, introspect once: `names = get_param(blk,'MaskNames')`. Pick the real name from that list. Document the mapping in `scripts/build_*.m` next to the set_param call.
- **Jump to**: S2 (rewrite the build script with introspected names) → S4.
- **Hit example**: 2026-06-01 `build_nebus39_dfig1_v0.m` failed twice — `Three-Phase Programmable Voltage Source` wants `PositiveSequence / VariationEntity / VariationStep / VariationTiming`; `Three-Phase Transformer (Two Windings)` wants `Winding1Connection / Winding2Connection / Rm / Lm`.
- **Source**: derivation `nebus39_dfig1_v0` (build/reports/nebus39_dfig1_v0_report.md §6).

## FS-018 derived model fails outside project: BlkParamUndefined for `Ts`

- **Symptom**: model PASSes update + sim inside `simulink_agent_v1/` but fails when copied to `AI summary of simulation models/`. Error: `Simulink:Parameters:BlkParamUndefined` — `<block>/Discrete PI Controller` 中的参数 'Ts' 时出错; 14+ similar entries inside the donor DFIG subsystem.
- **Likely cause**: donor subsystem (W33 / power_wind_dfig_avg) uses workspace variables (`Ts`, `Tsample`, ...) supplied by the project's `init_simulink_agent_project` or a donor's InitFcn. The new derived model has no InitFcn that defines them, so it depends on caller workspace.
- **Auto-fix**: in the build script, set the model's own `InitFcn` to define the variables the donor expects:
  ```matlab
  set_param(modelName,'InitFcn', sprintf([ ...
      'Ts = 5e-5;\n' ...
      'Tsample = Ts;\n']));
  ```
  Then the .slx is self-contained — `load_system + update + sim` works from any cwd with no init.
- **Jump to**: S2 (patch InitFcn) → S4.
- **Hit example**: 2026-06-01 `nebus39_dfig1_v0` first delivery to `~/Desktop/AI summary of simulation models/` fired 14 BlkParamUndefined causes for `Ts`.
- **Prevention**: every new derived model build script must set a self-contained InitFcn. Run an isolation test (batch with `restoredefaultpath`) before declaring snapshot-ready.
