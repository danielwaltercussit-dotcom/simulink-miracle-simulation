# 实验室仿真模型建模模式库 (v0.1)

来源: `C:\Users\jonas\Desktop\实验室仿真模型汇总`
适用: 当用户提"换电源 / 换风机 / 换台数 / 改电压等级 / 改线路距离"等小改动时,**优先复用本库的现成参数与布局**,避免每次从零推算控制器 PI、基准容量和坐标。

补充参考源: `C:\Users\jonas\Desktop\AI summary of simulation models` 中 6.3 以后的模型可作为 AI 生成结果参考; 本仓库只读这些外部参考,不在清理时移动或删除。

旧 `REFERENCE_MODEL_LAYOUT_OBSERVATIONS.md` 与 `IEEE39_LAYOUT_REFERENCES.md` 已并入本文件的布局规则。IEEE39 顶层布局采用横向电气主路径、区域对称和测量信号 Goto/From 的组合; 三相物理连接仍必须显式连线。

## 0. 库索引

| 编号 | 模型 | 拓扑 | 状态量 | Sb / 频率 | 关键文件 |
|---|---|---|---|---|---|
| M01 | `4M2A_DFIG_csy 数学` | 4 机 2 区, VSG×2 + PLL×2 全 DFIG | 100 | 100 MVA / 50 Hz | `NF_4_model_VSG_20260425_cross.m` + `NF_parameter_1220.m` |
| M02 | `4M2A_DFIG_csy 物理` | 同上, SPS 电磁暂态 | — | 100 MVA / 50 Hz | `phscial_4M2A_PLL_VSG_1_to_4.m` + `DFIG_VSG_direct_4M2A_phsical_PLL_VSG_0429.slx` |
| M03 | `DFIG_math` | 双 DFIG 两机 PLL 控制 | 50 | 100 MVA / 50 Hz | `DFIGmfile.m` + `DFIG_stea_v2.m` + `DFIG_math.slx` |
| M04 | `两机两区域 VSC` | 双 VSC (1 VSG + 1 PLL) + 无穷大 | 16 (网络) | 2 MVA / 50 Hz | `two_VSC_parameters.m` + `Net_2machine.m` |
| M05 | `柔直四机两区` | 4 SG + MMC 柔直, 多电压等级 | 99 | 1500 MVA / 50 Hz | `Copy_3_of_x2_TWOarea_FOURmachine.m` |
| M06 | `LCC` | CIGRE LCC HVDC 双端, 整流 CC + 逆变 CV | — (时步法) | — | `LCC_NEW0529.m` + `Cigre_LCC_Inverter_fuben.pscx` |
| M07 | `SGbyhjq` | 单机 NEBUS 标准 SG (sub-transient) | — | 1000 MVA / 50 Hz | `SGbyhjq.slx` (内嵌 NEBUS39 mac_con/AVR/MB/PSS) |
| M08 | `VSCbyhjq` | 三母线 VSC 并网 + 测量信号 Goto/From | — | 100 MVA / 50 Hz | `VSCbyhjq.slx` |

## 1. 通用基准与电压等级

### 1.1 基准容量

| 场景 | Sbase | 来源 |
|---|---|---:|
| DFIG 风电场, 中高压并网 | 100 MVA | M01/M02/M03 |
| 单机 SG benchmark NEBUS | 1000 MVA (mac_con) | M07 |
| MMC 柔直系统 | 1500 MVA | M05 |
| 小型 VSC 实验台 | 2 MVA | M04 |

### 1.2 电压等级

- **20 kV**: SG 端电压 (`Vac_power2`,M05);DFIG 单机端 690 V 升 20 kV
- **230 kV**: 中压交流主网,LCC 逆变侧 (`Vnom230`,M03);MMC AC 主侧 (M05)
- **291 kV**: MMC 高压侧 (`Vac_power=291e3`,M05),变比 `kmmc=291/230`
- **345 kV**: LCC 整流侧交流,`V_norm_r=303.895=345e3*sqrt(2/3)`
- **500 kV**: MMC 直流极间,`Udc=500e3`

### 1.3 标幺值基准计算约定 (M05 是参考实现)

```matlab
Ubase  = Vac_phase_phase * sqrt(2)/sqrt(3);   % 相电压峰值
Ibase  = 2 * Pbase / 3 / Ubase;
Zbase  = Ubase / Ibase;
Lbase  = Zbase / wnom;   % wnom = 2*pi*50
Cbase  = 1 / (wnom*Zbase);
Ybase  = 1 / Zbase;
```

每个新电压等级要建一组 `*base` 变量,而不是用同一组覆盖。例如 M05 同时维护 `Zbase / Zbase1 / Zbase2` 三套。

### 1.4 电网频率

全部模型 50 Hz,`wb = 100*pi`。仅 LCC (M06) 用 `w0=2*pi*50` 但同义。

## 2. DFIG 风机标准参数包 (M01/M02/M03 三套互相印证)

### 2.1 单机额定

```matlab
P15 = 1.5e6;                       % 单机 1.5 MW
rated_omegar = 1.2;                % pu, 同步转速 1.0 之上 20%
wind_speed_CpMax = 11;             % m/s, 最佳风速
lambda_CpMax = 9.9495;             % 最佳叶尖速比
CpMax = 0.5;
P_rated_omegar_theta_zero = 0.75;
J = 4.32*2 + 0.685*2;              % 等效转动惯量
Wind_speed_default = 14;           % 恒功率区典型值; 12 用于恒转速区; 10.5 用于MPPT区
```

### 2.2 风机气动 Cp 多项式系数 (Heier 风机模型,所有 DFIG 模型一致)

```matlab
c1=0.6450; c2=116; c3=0.4; c4=5; c5=21; c6=0.00912; c7=0.08; c8=0.035;
```

### 2.3 电机参数 (pu,转子折算到定子)

```matlab
Rs = 0.023;  Rr = 0.016;
Lm = 2.9;
Lls = 0.18;  Ls = Lls + Lm;
Llr = 0.16;  Lr = Llr + Lm;
Rg  = 0.003;  Lg = 0.3;            % 网侧滤波器 RL
Clink_per_unit = 10000e-6;          % DC link 单机电容; 实际电容 = Clink_per_unit * num
Udc_nom = 1150 (VSG) 或 1200 (PLL);
```

> 注: M03 在调试时把 `Rs/Rr/Lm/Lls/Llr` 都乘了 1.5~4 (`Co_Rrs`, `Co_Lm`, `Co_Lls`),以激发 50 Hz 振荡分析。**默认建模请用 1×,只有专门做振荡研究时才放系数。**

### 2.4 控制器 PI(三组对照,稳态收敛已验证)

| 控制环 | M01 VSG (`NF_parameter_1220.m`) | M01 PLL | M03 PLL (`DFIGmfile.m`) | 备注 |
|---|---|---|---|---|
| 速度环 | kp=3, ki=0.6 | kp=3, ki=0.6 | kp=3·5=15, ki=0.6·25=15 | M03 系数 `Cow=5` 用于带宽提升 |
| 网侧电流 (igd/igq) | kp=0.83, ki=5 | kp=0.83, ki=5 | kp=0.83·0.7, ki=5·0.49 | M03 `Cogi=0.7` |
| 直流电压 (Udc) | kp=8·1/8=1, ki=400·1/64=6.25 | kp=8, ki=400 | kp=8·0.7, ki=400·5 | VSG 用 `Covdc=1/8` 故意慢 |
| 转子电流 (ird/irq) | (atan PI) kp=0.6, ki=8 | kp=0.6, ki=8 | kp=0.6, ki=8 | atan 限幅,不做线性 |
| 端电压 | (积分式) ki=20~40 | kp=3, ki=10 | kp=3·0.8, ki=10·0.64·1.8 | M03 `Covol=0.8` |
| 锁相环 PLL | kp=80·sqrt(2), ki=1400·2 | kp=60, ki=1400 | kp=60·0.5, ki=1400·0.25 | sqrt(2) 系数让带宽 21.8 Hz, 阻尼 1.07 |
| VSG 虚拟惯量 | Tj=14, D=60~80 | — | — | Rv=0.5 用作虚拟阻抗 |
| 一次调频 Kpfc | 50~100 | 50 | 100 | Kifc=10 (积分调差) |
| 桨距角补偿 | kppc=3, kipc=30 | kppc=3, kipc=30 | kpcom=15, kicom=45 | "默认 15/30",激发零阻尼时调小 |

**经验**: 调试参数集都用乘系数 (`Cow / Cogi / Covdc / Copll`),便于 token-省力的"放大/缩小一组"操作。新建模型时复制 M01 那一列默认值即可。

### 2.5 机组数缩放

```matlab
Pyuliu = 1;
num1 = 66.67/5/Pyuliu;             % 机组台数(等效一台 100 MVA 的等容量并联数)
num2 = 69.313/5/Pyuliu;
% 工作区切换:
% 恒功率区 1.0:    num=66.67/69.313, wind=14
% 恒功率区 0.9:    num=74/75
% 恒转速区 0.81:   num=82/83, wind=12
% MPPT区 0.9*0.48: num=173/174, wind=10.5
```

### 2.6 网络 (M01 默认参数)

```matlab
LT1 = LT2 = 0.016667;              % pu 升压变漏抗
Dista = 200;                        % km, 200 km 双回
L_L = 0.001/2*Dista;                % pu/km/双回
R_L = 0;                            % 损耗忽略
C0 = 1e-3;                          % pu 公共母线电容
% 负荷阻抗
Lload = 0.098;
Rload = 0.4753;                     % 来源 z=0.975/(1.9+0.4j)
```

## 3. 同步发电机标准参数包 (M07 = NEBUS39 标准)

### 3.1 mac_con 行格式

19 列: `[Mach# Bus# Sb x_l r_a x_d x'_d x"_d T'_do T"_do x_q x'_q x"_q T'_qo T"_qo H d_o d_1 BusNo]`

M07 单机示例 (Bus 31, 1000 MVA):

```text
2  31  1000  0.350 0.027 2.95 0.697 0.4 6.56 0.003 2.82 1.7 0.5 1.5 0.005 3.03 0 0 31
```

### 3.2 AVR_Data (12 列, IEEE Type 1)

```text
[Tr Vimax Vimin Tc Tb Ka Ta Vrmax Vrmin Kc Kf Tf]
0.01 0.1 -0.1 1.0 10 200 0.015 5 -5 0 0 1.0
```

### 3.3 MBPSS (7 列,多带通)

```text
[G  FL_Hz  KL  FI_Hz  KI  FH_Hz  KH]
1   0.2    30  1.25   40  12     160
```

## 4. MMC 柔直 + 多机 (M05 标准参数包)

```matlab
% MMC 桥臂
Carm = 6.17e-5;     Lm_pu  = 0.05/Lbase;    Rm_pu = 0.3/Zbase;
Lac_pu = (0.014256*2)/Lbase;
% 滤波 (5% Q)
Cf  = 0.05*Pbase/3/wnom/Ubase^2;     Rf = 10*Zbase;
% 变压器 230kV/291kV, 容量 Pbase
Rtl_pu = 0.0055;   Ltl_pu = 0.015;
% 同步机 (1500 MVA 基准,sub-transient)
Rs=2.85e-3, Ls1=0.114, Lmd=1.19, Lmq=0.36, Rfd=5.79e-4, L1fd=0.114
Rkd=1.17e-2, L1kd=0.182, Rkq=1.97e-2, L1kq=0.384
H=1.2, p=1
% 控制器
Kp_pll=100, Ki_pll=300       % MMC PLL
kpcc=1, kicc=100             % 电流内环
kpcir=1, kicir=100           % 环流抑制
kpp=0.1, kip=10              % 受端 PQ
% 故障
Tfault=10, Trecover=0.1, Ron=0.001, Rg=0.01
```

## 5. LCC HVDC (M06 标准包)

```matlab
S_base=1000 MVA, w0=2*pi*50
Vtr_rec_base=213.4557 (折到副边), Vtr_inv_base=209.2288
X_pu=0.18 (变压器漏抗)
% 整流: CC (定电流) Kp=1.0989, Ki=Kp/0.01092
% 逆变: CV (定电压, ref=1 pu) Kp=0.7506, Ki=Kp/0.054
% PLL (rec): Kp=10/w0, Ki=50/w0
% PLL (inv): Kp=50/w0, Ki=2000/w0
alpha_min_rec=5°, alpha_max_rec=150°
alpha_min_inv=90°, alpha_max_inv=150°
Ts=50e-6  % 时步法仿真步长
```

## 6. 顶层布局观察 (从 .slx 提取)

### 6.1 单机基准 (M07 SGbyhjq)

```text
顶层只放 5 块,坐标紧凑 (500-895, 170-340):
+----+
|powergui (500,170)
+--+
|G2 SubSystem (550,251)            ← 主设备
+--+
|Three-Phase Series RLC Branch (645,238) ← 升压变/线路等值
+--+
|Three-Phase Programmable Voltage Source (775,251) ← 无穷大母线
+--+
|Ground (874,315)
+----+
```

模式: **powergui 左上 → 主设备 → 串联支路 → 等值源 → Ground**,横向一字排开。

### 6.2 单 VSC 三母线 (M08 VSCbyhjq)

```text
顶层 17 块,坐标 (470-1500, 200-400):
B1 (730) - VSC SubSystem (540) - B2 (965) - 升压变 (1045) - B3 (1195) - 等值源 (1305)
                                                                        |
                              Goto/From (470/1005/1235): Utabc/Itabc/Inetabc/Unetabc
                              Scope (1425), Ground (1484)
```

模式: **物理网络横向左→右一条线;测量信号 (Utabc, Itabc, Inetabc, Unetabc) 用 Goto/From 引出到右上角的 Scope**。

### 6.3 4 机 2 区 (M02 DFIG_VSG_direct_4M2A)

```text
顶层 6 个主 SubSystem,坐标 (770-3460, 380-1750):
                       [G3 (3410, 421)]
[wind farmG1 (910, 854)]                    [DFIG WIND FARM3 (2845, 862)]
[wind farmG2 (1330, 907)]
                       [G4 (2975, 1117)]
[DFIG WIND FARM2 (910, 1401)]               [对称] 
两端: 各侧 2 个 DFIG 风电场 + 1 个 SG;中间: Three-Phase PI Section Line ×2 (跨区联络线)
故障元件: Three-Phase Fault ×2 中间区域
```

模式: **左区 / 右区对称布置, 跨区双回线在中间**。设备宽度 ≈ 75 px, 高度 ≈ 60–140 px;同区不同设备 Y 坐标错开 ≈ 250 px 避免重叠。

### 6.4 MMC 柔直 4 机两区 (M05 SG_mmc_phy)

113 个 systems, 顶层 313 块。布局可读性靠**子系统封装**: 每条 Line 一个 SubSystem,每个 SG 一个 SubSystem,每个 MATLAB Function 一个独立块。元件类型分布:

```text
70 From + 39 Goto    ← 大量普通信号 (测量/控制) 用 Goto/From
12 Ground            ← 每条物理母线必有
7  Three-Phase RLC + 7 VI Measurement
6  两绕组变压器
3  同步机, 2 故障
3  3-phase Power 测量块  ← 用作系统级监测
```

### 6.5 总结的 6 条布局规则

1. **顶层只放电气主路径 + powergui** (左上角固定),其余进 SubSystem。
2. **横向 = 电气流向** (源→变→母线→设备→母线→变→等值);**纵向 = 复制对称** (双回线/双区域)。
3. **三相物理连接显式**, **测量/控制信号** Goto/From, **不混用**。
4. 元件块大小: SubSystem 75×60–140, RLC 支路 70×60, 测量/源 70×50, 母线短小条 5×80, Goto/From 35×16。
5. **块间距 ≥ 块宽** (避免重叠);设备 Y 坐标按 250 px 分层。
6. 命名: 母线 `B1/B2/...`, 同步机 `G1/G2/...`, 风电场 `wind farmG1` 或 `DFIG WIND FARM2`, 跨区线 `Line1/Line2/...`, 测量信号 `Utabc/Itabc/Inetabc/Unetabc`。

## 7. 命名 / 状态量 / Goto-From 规范

### 7.1 状态量后缀约定 (从 M01/M03 提炼)

```text
phi_s[d|q][i]     定子磁链   (i = 机组号)
phi_r[d|q][i]     转子磁链
isd/isq/ird/irq   电机电流 (有 vsg/p 上标区分坐标系)
igd/igq           网侧电流
udp/uqp           网侧端电压 (PLL 旋转坐标系)
udvsg/uqvsg       网侧端电压 (VSG 旋转坐标系)
urd/urq           转子电压
wpll              PLL 角频率
wr                转子机械角速度
theta_pll         PLL 相角
theta_s           VSG 相角
delta_dfig        VSG 与系统坐标系的相位差
x_*               PI 积分态 (e.g. x_pll1_1, x_udc_re1)
*_   (尾下划线)    导数 / 状态方程右端
```

### 7.2 PSS 兼容性别名 (来自 NEBUS39 项目, 当前生成模型必须注入)

```text
Tnum1_PSS, Tden1_PSS, Tnum2_PSS, Tden2_PSS,
Twashout_PSS, Tw_PSS, Tsensor_PSS, Ts_PSS,
K_PSS, Vmax_PSS, Vmin_PSS
```

### 7.3 Goto/From 仅用于以下信号

允许: `Utabc`, `Itabc`, `Inetabc`, `Unetabc`, `WindSpeed`, `Pref`, `Qref`, `Vref`, 各 `Pe_i`, `wr_i` 等控制/测量。
禁止: 三相导线 (a/b/c)、Simscape 物理端口、电流/电压守恒节点。

## 8. AI 复用流程: "换电源/换台数/改电压"如何省 token

当用户提以下需求,**直接套本库参数**,不再重新推算:

| 需求 | 操作 | token 节省 |
|---|---|---|
| "把 5 台 SG 换成 5 台 DFIG" | 用 §2 标准参数 + §6.3 4-2 区布局; benchmark_machine_id 从 NEBUS mac_con 读出 | 不必重新推 PI |
| "改成 8 台风机" | `Pyuliu` 不变, 改 `num1, num2`; `Clinki = 10000e-6 * numi` 自动跟变 | 一行参数 |
| "换 230 kV → 291 kV 高压侧" | 复制 §1.3 三套 base 计算; 变压器变比 `kmmc=291/230` | 复用 M05 的算式 |
| "200 km → 400 km 双回线" | `Dista=400`, `L_L=0.001/2*Dista*0.5`; 调试时配 `R_L=0.0001/2*Dista*2` (M03) | 一行 |
| "想做 50 Hz 振荡分析" | M03 的 `Co_Rrs=4, Co_Lm=1.5, Co_Lls=1.5, Co_Lrs=1.5, Ls2=Ls*1.x` | 已知参数集 |
| "VSG 改 PLL 控制" | M01 中 VSG = (1/2 机), PLL = (3/4 机); 直接换 `delta_dfig` 计算分支 | 同模型对照 |
| "加一次调频" | `pf_enable=1`,`Kpfc=50~100, Kifc=10` | 三参数 |

## 9. 已知失败签名补充 (供 ai-in-loop FS 字典扩展)

| 签名 | 现象 | 来源 | 修复 |
|---|---|---|---|
| FS-009 | DFIG `wpll` 长期 < 1.0 不收敛 | M01 调试 | 检查 `theta_pll - theta_s` 是否参与 dq 旋转;PLL `kp` 加 `sqrt(2)` 系数 |
| FS-010 | VSG 端电压幅值跳到 0 | M01 | `Uref` 与 `Vtmag` 同坐标系;`x_ut_` 积分态初值非零 |
| FS-011 | LCC 逆变 α 死锁在 90° | M06 | 检查 `T_filt_V=0.02 s` 滤波;`Vdc_inv_filt` 初值给 1.0 pu |
| FS-012 | MMC 桥臂电流冲击 | M05 | `Lm_pu=0.05/Lbase` 不能用错基准;`Carm=6.17e-5` 单独维度 |
| FS-013 | 50 Hz 振荡持续不衰减 | M03 | 检查 `Co_*` 系数; `Ls2=Ls*1.x` 越大越激发 |
| FS-014 | 低频 (~2 Hz) 持续振荡 | M03 | `Covol` 调小; PLL `kp` 别太高 |

## 10. 派生新模型 cookbook (2026-06-01 nebus39_dfig1_v0 经验)

第一次走通"派生新模型 + 5 s sim 一次过 + 故障扰动 18 ms 恢复"的完整流程，提炼 6 条对 ai-in-loop / simulink-modeling-assistant 通用的经验：

### 10.1 优先级: donor 子系统 > 减法派生

不要从 M02 这类"包含太多干扰子系统"的模型用减法（删 30+ 块）。**正确做法**: 从已 PASS 的子系统作为 donor，用 `add_block(<baseline>/<sub>, <new>/<sub>)` 整搬过来。例: 从 baseline 拷 W33 子系统（1862 块），自动带全部内部连接 + 控制器 + InitFcn 数据流 — 不用动一根线。

### 10.2 顶层骨架走 M07 模板

NEBUS39 单机骨架 (M07 SGbyhjq) 是最干净的"加电源 + 故障注入 + 测量"模板:
- 1 个 powergui (Discrete, Ts=5e-5)
- 1 个 Three-Phase Programmable Voltage Source (做故障注入)
- 1 个 Three-Phase Series RLC (联络阻抗)
- 1 个 Three-Phase V-I Measurement (测量 + To Workspace logging)
- 1 个 Ground

整体 5 块以内顶层。复杂派生在 SubSystem 内部展开。

### 10.3 故障注入用 ProgrammableVoltageSource 的 amplitude step

不用单独加 `Three-Phase Fault` 块 — 可以直接配置程控源参数:
```matlab
'PositiveSequence','[Vrms_LL 0 50]', ...
'VariationEntity','Amplitude', ...
'VariationType','Step', ...
'VariationStep','-0.5', ...        % 跌落到 50%
'VariationTiming','[t_start t_end]'
```

### 10.4 物理端口连法

DFIG 子系统典型有 `[2 input + 1 output + 3 LConn + 0 RConn]`。物理三相连线用 `add_line(model, 'Vsrc/RConn1','Tie/LConn1','autorouting','on')` 逐相显式接，**禁止**用 Goto/From 替三相 (硬规则，见 [[simulink-agent-v1-project]])。

### 10.5 set_param mask 名要先 introspect

写 build 脚本不要凭"友好名"猜。**先**:
```matlab
names = get_param(blk,'MaskNames');   % 拿真实名清单
```
常见对照（已知会踩的坑，写进 FS-017）:
| 块类型 | 错的猜法 | 真实 mask 名 |
|---|---|---|
| Three-Phase Programmable Voltage Source | Amplitude / Frequency | `PositiveSequence` / `VariationEntity` / `VariationStep` / `VariationTiming` |
| Three-Phase Transformer (Two Windings) | Winding1Type / Magnetization | `Winding1Connection` / `Rm` / `Lm` |

### 10.6 logging 走 To Workspace + sim ReturnWorkspaceOutputs

```matlab
out = sim(modelName, 'StopTime','5.0', 'ReturnWorkspaceOutputs','on');
Vs = out.Vabc_HV; t = Vs.time; Vv = Vs.signals.values;
```
不要写 base ws (`assignin('base','Vabc',...)`) — sim 完后 base ws 不一定还有。`out.<varname>` 是稳定通道。

### 10.7 验证清单 (per-derived-model)

| 阶段 | 检查 | 通过判据 |
|---|---|---|
| S2 BUILD | `Force=true` 后 .slx 落盘 | 无 `ParamUnknown` |
| S4 COMPILE | `set_param(mn,'SimulationCommand','update')` | 无报错 |
| S5 SMOKE | sim 0.005 s | 无报错 |
| S5+ FULL | sim 5 s | NaN count = 0; 稳态 V ∈ [0.94,1.06] pu |
| S5+ FAULT | 故障期 V ≈ 设定 pu | 期望 vs 实测 误差 < 1% |
| S5+ RECOVERY | 故障后 V → ≥0.99 pu | 恢复时间 < 1 s（典型 < 100 ms） |
