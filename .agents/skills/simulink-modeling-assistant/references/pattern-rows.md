# Pattern Rows: One-Liner Recipes per Reference Model

When the user request matches a row, copy the listed parameters verbatim.
For full algebraic derivation see `docs/MODELING_PATTERN_LIBRARY.md`.

## M01 — 4M2A DFIG, VSG×2 + PLL×2, 数学模型

- Use case: hybrid grid-forming + grid-following DFIG study, 100 state vars.
- Sb / freq: 100 MVA / 50 Hz, `wb = 100*pi`.
- Files: `4M2A_DFIG_csy/代码数学模型/{NF_4_model_VSG_20260425_cross.m, NF_parameter_1220.m, Initial_data_doudfig_case2_VSGtest_1220.m}`.
- VSG defaults: `Tj=14, D=60, Rv=0.5, kiv=40, Uref=1.0–1.01, Udc0=1150`.
- PLL defaults: `Tj_NA, kp_pll=60, ki_pll=1400, Udc0=1200`.
- Network: `LT=0.016667, Dista=200 km, L_L=0.001/2*200, R_L=0`.
- Load: `Lload=0.098, Rload=0.4753` (z=0.975/(1.9+0.4j)).
- Wind speed: 14 m/s (constant power region).
- Use as default DFIG parameter source unless user explicitly opts into M03.

## M02 — 4M2A DFIG 物理电磁暂态 (与 M01 配对)

- Use case: SPS three-phase verification of M01 controllers.
- File: `4M2A_DFIG_csy/物理电磁暂态模型/DFIG_VSG_direct_4M2A_phsical_PLL_VSG_0429.slx`.
- Parameter file: `phscial_4M2A_PLL_VSG_1_to_4.m`.
- Layout: see `layout-cookbook.md` §3 (4M2A symmetric).
- Switching banks: `dgsc1_switch=100, qrotor1_switch=50` mark "default = nominal" before/after switch.
- PI params for grid-side / rotor-side: same as M01 §2.4.

## M03 — 双 DFIG 两机 PLL, 50 状态量, 振荡分析专用

- Use case: 50 Hz / 2 Hz oscillation experiments.
- Files: `DFIG_math_m/{DFIGmfile.m, DFIG_stea_v2.m, DFIG_math.slx}`.
- **Different from M01**: `Co_Rrs=4, Co_Lm=1.5, Co_Lls=1.5, Co_Lrs=1.5,
  Ls2=Ls*1.x` deliberately amplify oscillations. Reset to 1.0 for normal use.
- `Cow=5` => `kpw=15, kiw=15` (raised speed loop bandwidth).
- `Copll=0.5, Covol=0.8, Covdcki1=5` are study-specific multipliers.
- Use only when user mentions oscillation / 振荡 / damping study.

## M04 — 双 VSC 两区, 16 网络状态量

- Use case: small VSC PLL+VSG comparison rig, 2 MVA, 50 Hz.
- Files: `两机两区域/{two_VSC_parameters.m, two_VSC_mathmodel_PLLVSG_PLLxy.slx, 代码模型/Net_2machine.m}`.
- VSG defaults: `Tj1=5, D1=50` (lighter inertia than DFIG).
- DC: `Cdc=1.5e-2, Udc_nom=1.45 pu, kp_dc=2, ki_dc=20*kp_dc`.
- VSC current loop: kp=0.5, ki=10 (M1 d-axis); for M2: kp=0.4, ki=10.
- Voltage loop: `kp_v=2, ki_v = kp^2 * 10` (kesai pattern).
- PLL: `kp_PLL2=100, ki_PLL2=10000` (50 Hz cutoff).
- Network base: `Sb_WT=2 MVA, Lline=600 (300×2)`.

## M05 — MMC 柔直 + 4 SG 两区, 99 状态量, 多电压等级

- Use case: AC/DC hybrid system, 1500 MVA base.
- File: `柔直四机两区模型/{Copy_3_of_x2_TWOarea_FOURmachine.m, SG_mmc_phy.slx, SG_mmc_math.slx}`.
- Voltage levels: `Vac_power=291e3 / 230e3 / 20e3`. Maintain three base sets
  (`Zbase / Zbase1 / Zbase2`) — see `parameter-cheatsheet.md` §3.
- DC: `Udc=500e3`, `Pbase=1500e6`, `Carm=6.17e-5` (SI).
- MMC PI: `Kp_pll=100, Ki_pll=300; kpcc=1, kicc=100; kpcir=1, kicir=100;
  kpp=0.1, kip=10`.
- Transformer: 230/291 kV, `kmmc=291/230, Rt=0.0055, Lt=0.015 pu`;
  20/230 kV, `ksg=230/20, Rt=0.005, Lt=0.015 pu`.
- SG sub-transient: see `parameter-cheatsheet.md` §2.
- Line: π section, `r1_pu / l1_pu / c1_pu = (0.0001*529, 0.0001*529/377, 0.00175/529/377)/base`.

## M06 — CIGRE LCC HVDC 双端 (整流 CC + 逆变 CV)

- Use case: HVDC LCC time-step simulation.
- File: `LCC模型/LCC_NEW0529.m` (no .slx; m-script only).
- Sb=1000 MVA, Vtr_rec=213.4557, Vtr_inv=209.2288 (折算到副边), X_pu=0.18.
- Rec CC PI: `Kp=1.0989, Ki=Kp/0.01092` (over `I_base=2.0`).
- Inv CV PI: `Kp=0.7506, Ki=Kp/0.054`, `Vdc_ref=1.0 pu`,
  voltage filter `G=0.002, T=0.02 s`.
- PLL: rec `Kp/Ki = 10/w0, 50/w0`; inv `Kp/Ki = 50/w0, 2000/w0`.
- Alpha limits: rec `[5°, 150°]`; inv `[90°, 150°]`.
- Time step: `Ts=50e-6`. AC: 7-order matrix filter (rec) / 8-order (inv).
- The model is a hand-written discrete loop, not a Simulink schematic.

## M07 — SGbyhjq, NEBUS39 单机基准 (sub-transient)

- Use case: single-machine drop-in for IEEE 39-bus replacement studies.
- File: `SGbyhjq.slx`.
- Sb=1000 MVA, mac_con row format = NEBUS standard 19 cols. Embedded
  `mac_con / AVR_Data / MB / STG_Data` directly in `InitFcn` (good template
  for derived models).
- Top layout: 5 root blocks (`powergui / G2 / 3-phase RLC / programmable
  source / Ground`), see `layout-cookbook.md` §1.

## M08 — VSCbyhjq, 三母线 VSC 并网

- Use case: VSC measurement-and-Goto/From example.
- File: `VSCbyhjq.slx`.
- Top layout: B1 / B2 / B3 buses + 1 VSC SubSystem + Goto/From for measurement
  signals (Utabc, Itabc, Inetabc, Unetabc) feeding a Scope at top-right.
- Use as the canonical example when teaching the agent which signals are
  legal Goto/From candidates.
