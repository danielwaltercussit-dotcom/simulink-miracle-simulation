# Parameter Cheatsheet

Lookup tables for default PI sets, base values, and electrical constants.
The full derivation is in `docs/MODELING_PATTERN_LIBRARY.md`.

## §1 DFIG (M01 default — copy this block verbatim)

```matlab
% Machine
P15 = 1.5e6;
Rs  = 0.023;  Rr = 0.016;
Lm  = 2.9;    Lls = 0.18; Ls = Lls + Lm;
Llr = 0.16;   Lr  = Llr + Lm;
Rg  = 0.003;  Lg  = 0.3;

% Wind aero (Heier coefficients)
c1=0.6450; c2=116; c3=0.4; c4=5; c5=21; c6=0.00912; c7=0.08; c8=0.035;
CpMax=0.5; lambda_CpMax=9.9495; wind_speed_CpMax=11; rated_omegar=1.2;
P_rated_omegar_theta_zero=0.75;
J=4.32*2 + 0.685*2;     % equivalent inertia
F=0; Pitch_time_constant=0.01;

% DC link
Clink_per_unit = 10000e-6;     % per-machine DC capacitance
Udc0_VSG = 1150;
Udc0_PLL = 1200;

% VSG controllers
kpw = 3;        kiw = 0.6;
Tj  = 14;       D   = 60;       Rv = 0.5;       kiv = 40;
Kpfc = 50;      Kifc = 10;       % primary-frequency droop
kppc = 3;       kipc = 30;       % pitch compensation
kpig = 0.83;    kiig = 5;        % grid-side current
kpdc = 8/8;     kidc = 400/64;   % DC link (slow)
kppll = 80*sqrt(2); kipll = 1400*2;

% PLL controllers (apply to PLL-based units; replace VSG block above)
kpw = 3;        kiw = 0.6;
kppll = 60;     kipll = 1400;
kpvol = 3;      kivol = 10;
kpir  = 0.6;    kiir  = 8;       % rotor current (atan PI)
kppc  = 3;      kipc  = 30;
kpig  = 0.83;   kiig  = 5;
kpdc  = 8;      kidc  = 400;

% Network (200 km double circuit)
LT = 0.016667;
Dista = 200;
L_L = 0.001/2 * Dista;
R_L = 0;
C0  = 1e-3;
Lload = 0.098;
Rload = 0.4753;
```

## §2 Synchronous machine (M07 NEBUS, sub-transient)

mac_con format (19 columns):

```text
[Mach# Bus# Sb_MVA x_l r_a x_d x'_d x"_d T'_do T"_do x_q x'_q x"_q T'_qo T"_qo H d_o d_1 BusNo]
```

Reference row (Bus 31, 1000 MVA):

```text
2  31  1000  0.350  0.027  2.95  0.697  0.4  6.56  0.003  2.82  1.7  0.5  1.5  0.005  3.03  0  0  31
```

AVR (IEEE Type 1, 12 columns):

```text
[Tr Vimax Vimin Tc Tb Ka Ta Vrmax Vrmin Kc Kf Tf]
0.01 0.1 -0.1 1.0 10 200 0.015 5 -5 0 0 1.0
```

MBPSS (multi-band, 7 columns):

```text
[G  FL  KL  FI  KI  FH  KH]
1   0.2 30  1.25 40 12  160
```

For 1500 MVA SG (M05):

```matlab
Rs_pu=2.85e-3;  Ls1_pu=0.114;  Lmd_pu=1.19;   Lmq_pu=0.36;
Rfd_pu=5.79e-4; L1fd_pu=0.114;
Rkd_pu=1.17e-2; L1kd_pu=0.182; Rkq_pu=1.97e-2; L1kq_pu=0.384;
H=1.2; p=1;
```

## §3 Multi-voltage base set (M05 pattern — required for hybrid AC/DC)

```matlab
F0=50; wnom=2*pi*F0;

% Base set 1: HVAC 291 kV, Pbase=1500 MVA
Vac_power=291e3;
Ubase  = Vac_power*sqrt(2)/sqrt(3);
Ibase  = 2*Pbase/3/Ubase;
Zbase  = Ubase/Ibase;
Lbase  = Zbase/wnom;
Cbase  = 1/(wnom*Zbase);

% Base set 2: AC main 230 kV (suffix 1)
Vac_power1=230e3;
Ubase1=Vac_power1*sqrt(2)/sqrt(3);
Ibase1=2*Pbase/3/Ubase1;
Zbase1=Ubase1/Ibase1;
Lbase1=Zbase1/wnom; Cbase1=1/(wnom*Zbase1);

% Base set 3: SG terminal 20 kV (suffix 2)
Vac_power2=20e3;
Ubase2=Vac_power2*sqrt(2)/sqrt(3);
Ibase2=2*Pbase/3/Ubase2;
Zbase2=Ubase2/Ibase2;
Lbase2=Zbase2/wnom; Cbase2=1/(wnom*Zbase2);
```

Always **maintain a `Zbase / Lbase / Cbase` per voltage level**. Sharing one base across voltage levels is FS-012's root cause.

## §4 MMC (M05)

```matlab
Carm = 6.17e-5;          % SI (NOT pu)
Lm_pu = 0.05/Lbase;      % arm inductor against MMC-side base
Rm_pu = 0.3/Zbase;
Lac_pu = 0.014256*2/Lbase;

Rf_pu = 10;              % filter R (large = lossy intentional)
Cf = 0.05*Pbase/3/wnom/Ubase^2; Cf_pu = Cf/Cbase;

% MMC controllers
Kp_pll=100;  Ki_pll=300;
kpcc=1;      kicc=100;       % inner current
kpcir=1;     kicir=100;       % circulating current
kpp=0.1;     kip=10;          % outer P/Q
```

## §5 LCC HVDC (M06)

```matlab
S_base=1000;  w0=2*pi*50;
Vtr_rec_base=213.4557; Vtr_inv_base=209.2288;
X_pu=0.18; Tap_rec=1.0; Tap_inv=1.0;
Xc_rec = X_pu*(Vtr_rec_base*Tap_rec)^2/603.73;   % S_trans_r=603.73
Xc_inv = X_pu*(Vtr_inv_base*Tap_inv)^2/591.79;
Rc_rec = 2*(3/pi)*Xc_rec;  Rc_inv = 2*(3/pi)*Xc_inv;

% Controllers
Kp_rec_cc=1.0989;  Ki_rec_cc=Kp_rec_cc/0.01092;     % rec CC
Kp_inv_cv=0.7506;  Ki_inv_cv=Kp_inv_cv/0.054;        % inv CV
Vdc_ref_pu=1.0; G_vdc=0.002; T_filt_V=0.02;          % Vdc filter

Kp_pll_r=10/w0; Ki_pll_r=50/w0;
Kp_pll_i=50/w0; Ki_pll_i=2000/w0;

alpha_min_rec=5*pi/180;  alpha_max_rec=150*pi/180;
alpha_min_inv=90*pi/180; alpha_max_inv=150*pi/180;
Ts=50e-6; T_filt_I=0.0012;
I_base=2.0;
```

## §6 PI shorthand from M04 (small VSC rig)

VSG: `Tj1=5, D1=50` (light). DC: `kp_dc=2, kesai_dc=20, ki_dc=kp^2*kesai_dc`.
VSC current loop pattern: `kp_id = kp_iq = kpi`, `ki = kii` (decoupled). Use `kpi=0.5, kii=10` for primary unit, `kpi=0.4, kii=10` for secondary.

Voltage outer: kesai-style `ki = kp^2 * kesai`. Default `kp=0.2, kesai=1000` then trim `ki=10`.

PLL: `kp_PLL=100, ki_PLL=10000` => 50 Hz cutoff with `kesai≈2`.

## §7 Common signal-rotation snippets (DFIG VSG↔PLL coordinate transforms)

```matlab
% port → PLL frame
udp = cos(theta_pll)*ud + sin(theta_pll)*uq;
uqp = -sin(theta_pll)*ud + cos(theta_pll)*uq;

% port → VSG frame (for VSG units)
udvsg = cos(delta_dfig + theta_s)*ud + sin(delta_dfig + theta_s)*uq;
uqvsg = -sin(delta_dfig + theta_s)*ud + cos(delta_dfig + theta_s)*uq;

% PLL frame → VSG frame
udvsg_from_pll = cos(theta_pll - theta_s)*udp + sin(theta_pll - theta_s)*uqp;
```

These three are the building blocks of M01's network section. Reuse, don't re-derive.
