# Derivation Cookbook

How to build a new derived Simulink model in this project, distilled from the
2026-06-01 successful run (`nebus39_dfig1_v0` — first try 5 s sim PASS, fault
recovery 18 ms).

## When to invoke this cookbook

Trigger when the user asks to:
- "搭一个新模型" / "派生一个新模型" / "做一个类似的模型"
- "在 X 基础上改 Y"
- "新建一个 NEBUS39 + Z 的模型"

Companion: [[../../ai-in-loop/SKILL.md]] runs the closed loop **after** this
cookbook produces a build script. Use [[../../simulink-device-adapters/SKILL.md]]
while authoring the build script so adapter ports, InitFcn self-containment,
mask-name introspection, and trace metadata are not deferred until simulation.

## Recipe

### 1. Pick donor + scaffolding

| Need | Use |
|---|---|
| NEBUS39 single-machine top frame | M07 `SGbyhjq.slx` (5 root blocks: powergui + Vsrc + RLC + Ground; clean) |
| 4-machine 2-area top frame | M02 `DFIG_VSG_direct_4M2A_phsical_PLL_VSG_0429.slx` (复杂, 注意 22 顶层子系统) |
| MMC HVDC top frame | M05 `SG_mmc_phy.slx` |
| LCC HVDC | M06 (no .slx, `LCC_NEW0529.m` time-step script) |
| **Working DFIG subsystem** | `ieee39_10m39bus_sg5_dfig5_nebus_layout.slx/W33` (project baseline, already PASS, 1862 blocks self-contained) |
| Working SG subsystem | M07 `SGbyhjq.slx/G2` |
| Working VSC subsystem | M08 `VSCbyhjq.slx` (full root) |

**Rule of thumb**: copy a **whole working subsystem** (`add_block(srcPath,
dstPath)`), don't try subtraction (delete 30+ blocks from a complex donor).

### 2. Author the spec FIRST

`specs/case_<modelname>.yaml`. Sections required:

```yaml
system:
  name: <modelname>
  base_mva: <Sb>
  frequency_hz: 50            # or 60
  stop_time: 5.0
  solver: FixedStepDiscrete
  sample_time: 5e-5
  parent_models:
    sg_top: <which donor for top scaffolding>
    dfig_donor: <which donor for the gen subsystem>
  derivation_strategy: |
    <one paragraph: copy what from where>

topology:
  source: ...
  tie_line: ...
  step_up_transformer: ...
  generator: ...
  ground: Ground

convergence_targets:
  smoke: { duration_s: 0.005, no_nan: true }
  steady_state: { duration_s: 5.0, voltage_band_pu: [0.94, 1.06] }
  fault_recovery: { fault_window_s: [t1, t2], recovery_window_s: 1.0 }
```

### 3. Build script template

`scripts/build_<modelname>.m`. Structure:

```matlab
function build_<modelname>(varargin)
% 1. parse Force flag, decide outPath
% 2. load donor models (load_system on baseline)
% 3. new_system + load_system the new model
% 4. add_block donor subsystems with explicit Position
% 5. add powergui + Vsrc + RLC + measurement + transformer + ground
% 6. set_param each block — INTROSPECT MASK NAMES FIRST (FS-017)
% 7. add_line for physical RConn/LConn (3 phases, explicit)
% 8. add_line for signal inputs (Wind / Qref / etc)
% 9. set_param model: StopTime, SolverType=Fixed-step, FixedStep, etc
% 10. save_system to build/generated_models/
end
```

### 4. set_param mask name introspection (FS-017 prevention)

Before writing `set_param(blk, 'X', 'val')`, introspect:

```matlab
add_block(libRef, dstPath);
fprintf('--- %s mask names ---\n', dstPath);
disp(get_param(dstPath,'MaskNames'));
```

Known traps (already documented in [[../../ai-in-loop/references/failure-signatures.md]] FS-017):

| Block | Wrong guess | Real name |
|---|---|---|
| Three-Phase Programmable Voltage Source | `Amplitude`, `Frequency`, `TimeVariationOf`, `StepMagnitude`, `VariationTimingSecVariationEntryTimes` | `PositiveSequence`, `VariationEntity`, `VariationType`, `VariationStep`, `VariationTiming` |
| Three-Phase Transformer (Two Windings) | `Winding1Type`, `Winding2Type`, `Magnetization` | `Winding1Connection`, `Winding2Connection`, `Rm`, `Lm` |

### 5. Wiring rules (project hard rule)

- 3-phase physical: explicit per-phase, `add_line(mn, 'A/RConn1','B/LConn1','autorouting','on')` × 3
- **NEVER** use Goto/From to substitute three-phase wiring
- Goto/From is allowed only for: `Utabc`, `Itabc`, `WindSpeed`, `Pref`, `Qref`, `Vref`

### 6. Fault injection (no separate Fault block needed)

Drive the programmable source amplitude:
```matlab
set_param([mn '/Vsrc'], ...
    'PositiveSequence','[Vll 0 50]', ...
    'VariationEntity','Amplitude', ...
    'VariationType','Step', ...
    'VariationStep','-0.5', ...     % drop magnitude in pu
    'VariationTiming','[0.5 0.7]'); % start, end
```

### 7. Logging via `out.<varname>`

```matlab
add_block('simulink/Sinks/To Workspace', [mn '/Vabc_log'], ...
    'VariableName','Vabc_HV','SaveFormat','Structure With Time');
% ... wire VI_meas/1 -> Vabc_log/1
out = sim(mn,'StopTime','5.0','ReturnWorkspaceOutputs','on');
Vs = out.Vabc_HV;     % do NOT read from base ws — unreliable
```

### 8. Validation gate (per derived model)

After build, run sequentially via MCP. Each must PASS before next:

```matlab
load_system(outPath);
set_param(mn,'SimulationCommand','update');         % S4
out = sim(mn,'StopTime','0.005');                    % S5 smoke
out = sim(mn,'StopTime','5.0','ReturnWorkspaceOutputs','on'); % S5+ full
% Then check: NaN count, |V| pu band, fault depth, recovery time
```

### 8.4. No-overlap layout self-check (FS-005 prevention)

The build script **must** call `scan_block_overlap` before `save_system` so
overlapping root blocks are caught at build time, not at the next derivation:

```matlab
scan_block_overlap(modelName, 'ThrowOnFail', true);
save_system(modelName, outPath);
```

See `references/layout-cookbook.md` "Hard rule: zero overlap at root canvas".
Common cause: putting a Constant input at the same x-range as a transformer
block. Fix: shift to the gap between transformer and consuming subsystem.

### 8.5. Self-containment InitFcn (FS-018 prevention)

The build script **must** set the model's own InitFcn so the .slx runs without
the project on path. Donor subsystems (W33, power_wind_dfig_avg) reference
workspace `Ts`. Without this the model fails outside the project with 14+
`BlkParamUndefined` causes.

```matlab
set_param(modelName,'InitFcn', sprintf([ ...
    'Ts = 5e-5;            %% sample time used by donor blocks\n' ...
    'Tsample = Ts;         %% common alias\n']));
```

### 8.6. Isolation test before snapshot

After in-project sim PASS but **before** copying to AI summary, run:

```bash
"/d/Program Files/MATLAB/R2024b/bin/matlab.exe" -batch "
  restoredefaultpath;  % clear ALL project paths
  addpath('C:\Users\jonas\AppData\Roaming\MathWorks\MATLAB Add-Ons\Toolboxes\MATLAB MCP Core Server Toolbox');
  load_system('<outPath>');
  set_param('<model>','SimulationCommand','update');
  out = sim('<model>','StopTime','0.005');
"
```

If this fails with FS-017/FS-018, fix in the build script (not in the .slx
manually) and re-build, so the next derivation inherits the fix.

### 8.7. Device adapter contract check

Run the S2 adapter gate before compile/smoke, especially after copying a donor
subsystem or adding SG/DFIG/VSC/MMC/LCC/storage devices:

```matlab
addpath("scripts/adapters")
r = inspect_device_adapter_contract(modelName, ...
    "ReportPath", fullfile("build","reports","adapters", modelName + ".md"));
assert(r.passed)
```

The check is intentionally lightweight: it catches missing root device
subsystems, duplicate adapter names, absent adapter-facing ports, and missing
self-contained `InitFcn`. Trace metadata is a warning by default unless
`StrictTrace=true`.

### 8.8. Drive ai-in-loop closed loop (verifies S2-S9 chain)

After the model passes manual sim + isolation test, run the full closed loop
to verify the project's stage chain still works on this derived model:

```matlab
status = ai_in_loop_run( ...
    'goal','full', ...                                % S2-S7B + S9
    'spec_path','specs/case_<model>.yaml', ...
    'model_name','<model>', ...
    'build_fcn','build_<model>', ...
    't_smoke',0.005,'t_full',1.0,'fast',true);
```

Goals: `smoke` runs S2-S5, `tune` adds S6, `full` adds S7+S7B (Model Advisor).
S6/S7/S7B may legitimately SKIP on this model:
- **S7 SLTEST SKIPPED** if no `tests/` dir — author harnesses via the
  `testing-simulink-models` skill if needed.
- **S7B Model Advisor SKIPPED** when `license('test','Simulink_Check')==0`
  on this MATLAB instance — Simulink Check addon installed but license not
  in the seat. The skip is permanent for this license; not a project bug.

### 9. Snapshot to AI summary folder (after PASS)

Per [[../../../../../../C:/Users/jonas/.claude/projects/C--Users-jonas-Desktop-Claude-demo/memory/ai-summary-snapshot-routine.md]]:
copy `<model>.slx`, `case_<model>.yaml`, `build_<model>.m`, `<model>_report.md`,
`<model>_*.png` to `~/Desktop/AI summary of simulation models/<model>/`.
Update its README index table.

## Reference instance: nebus39_dfig1_v0

- Spec: `specs/case_nebus39_dfig1_v0.yaml`
- Build script: `scripts/build_nebus39_dfig1_v0.m`
- Output: `build/generated_models/nebus39_dfig1_v0.slx`
- Report: `build/reports/nebus39_dfig1_v0_report.md`
- Total time from "go" to "5 s sim PASS": ~10 minutes (incl. two FS-017 retries)
- Tuning iterations needed: 0 (template-first fast path)

## 11. Closed-loop tuning (when S6 has real work to do)

When the model needs parameter tuning (the model_template's defaults are not
optimal for the new topology, or the SCR / electrical context differs), use
the closed-loop tuning infrastructure added 2026-06-02:

### 11.1. What needs to exist for a model to be auto-tunable

1. **Logged signals**: at minimum `Vabc_HV` and `Iabc_HV` via To Workspace
   blocks set to "Structure With Time". The metric extractor reads from
   `out.<varname>` after `sim(... 'ReturnWorkspaceOutputs','on')`.
2. **A registry entry** in `scripts/loop/tuning_registry.m`. For each
   tunable knob declare: block_path, mask_param, [min vec, max vec],
   units, fs_targets (which FS codes it can fix), scale_fcn (vector op).
3. **A test bench** that puts the model in a non-trivial state. The
   easiest pattern is: build script intentionally sets one knob to a
   destabilising value, S6 detunes back.

### 11.2. Direction policy

Don't trust prior literature alone — DFIG donors differ enough that the
"raise vs lower bandwidth" decision flips. Use the live metric:
- `I_osc_growth > 1.05` (oscillation amplifying) → raise (+1)
- otherwise (oscillation steady or shrinking but not stable) → lower (-1)

Reference test bench `nebus39_dfig_weakgrid_v0` proved this:
literature said "weak grid → lower PLL Kp/Ki" but raising it 2.25× actually
killed the oscillation. The empirical direction policy got there in 3 rounds.

**Patience matters** (lesson from multi-knob registry): when the first
same-direction move makes things worse (e.g. raising PLL bandwidth 1.5×
takes growth 1.25 → 1.44), do **not** flip direction immediately. Give
the same direction one more probe — sometimes the gradient field is
non-monotonic in the small steps but smooth at 2× scale. Current threshold
in `ai_in_loop_stage_tune.m`: 2 consecutive same-direction no-improvements
before flipping; 3 before marking the knob exhausted.

### 11.3. Convergence criteria

A model is `stable` when ALL hold:
- nan_count == 0
- steady_V_pu in [0.94, 1.06]
- fault_recovery_ms ≤ 1000
- (I_osc_growth ≤ 1.05) OR (damping_ratio ≥ 0.05)

Damping ratio is unreliable on short signals — the OR with growth is the
load-bearing check.

### 11.4. When the inner loop fails

If `MaxRounds` exhausted: read the iter_<NN>/report.md. Common causes:
- **Wrong knob**: the FS code matches a registered knob but that knob
  doesn't actually move the dominant mode. Add a different knob (e.g.
  rotor-side current loop) and target the same FS.
- **Reached bound**: knob hit min or max but still oscillating. Either the
  model itself is mis-built (wiring / ground / sample-time) or another
  knob entirely is the culprit.
- **Spurious FS**: extract_tuning_metrics returns FS-013 for any 5-30 Hz
  growing oscillation regardless of cause. If the source is mechanical
  (drive train torsional, pitch loop), the PLL knob can't fix it; widen
  the registry.
- **Knob has no causal effect**: the knob's mask param exists but tweaking it
  has zero impact on the dominant mode. The scheduler will try ±1.5x both
  directions, see no improvement either way, and mark the knob exhausted.
  This is correct behaviour — the FAIL with all knobs exhausted is a
  genuine "no rule-driven fix exists" verdict, not a loop bug.
- **Master knob saturates everything else**: if PLL is at MAX bound, the
  PI knobs also become inert because the system is already PLL-dominated.
  Test scenario `nebus39_dfig_weakgrid_v0` with `pll @ MAX + grid_pi broken`
  proved: rotor_pi/grid_pi/dc_pi all exhausted in succession, FAIL after
  4 knob attempts. This is the fallback path working as designed.

### 11.4b. Coupled multi-unit systems behave non-locally

Empirical finding from `nebus39_dfig2_weakgrid_v0` (2 DFIGs paralleled on a
weak feeder): **PLL oscillation is a system-level mode, not a per-unit fault**.
Tested four scenarios:

| pll_a | pll_b | Result |
|---|---|---|
| `[15…]` unstable | `[5…]` default | r0 unstable; r1 raises pll_a 1.5× → PASS |
| `[5…]` default | `[15…]` unstable | r0 unstable; r1 raises **pll_a anyway** → PASS |
| `[200…]` MAX | `[15…]` unstable | r0 already PASS — pll_a high bandwidth suppresses pll_b ringing |
| `[0.5…]` MIN | `[15…]` unstable | r0 already PASS — pll_a barely participates, system equivalent to single-unit |

**Implications for the loop**: don't expect "first FS-013 → fix wrong unit"
to look like "make 1-2 detuning attempts then fall back to the right knob".
For coupled systems the loop usually finds a stable point with **whichever
knob is registered first** — because all knobs influence the shared mode.
This makes per-unit fault localisation IMPRECISE but the convergence FAST.

If you need precise localisation (e.g. for closed-loop control design,
sensitivity ranking), don't rely on the rule-driven loop. Use eigen-analysis
or perturbation sweep instead.

### 11.5. Adding a new tunable knob

1. Find the block: `find_system(modelName,'LookUnderMasks','all',...)`
2. Confirm mask name with `get_param(blk,'MaskNames')` (FS-017 prevention)
3. Add registry entry — `scale_fcn` is a 2-arg function `(oldVal, dir) -> newVal`
4. Set realistic min/max bounds (one extra-cautious test sim per bound)
5. Add fs_targets — usually 1-2 FS codes the knob can plausibly fix
