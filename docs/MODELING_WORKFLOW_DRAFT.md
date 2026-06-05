# 流程化电力系统 Simulink 建模规范

适用项目：`C:\Users\jonas\Desktop\simulink_agent_v1`

本文件是当前建模流程的精简版。历史 v0.5-v0.9 试验记录、GitHub 候选清单和旧布局观察已被压缩到当前规则；需要旧上下文时先看 `docs/OLD_CONTEXT_KEYWORDS.md`，不要重新加载旧 `.ctx`。

## 1. 目标

形成一套可复用、可检查、可交接的 Simulink 电力系统建模流程：

- 用规格文件描述拓扑、设备、参数、替换规则和验证目标。
- 基于模板或 donor 子系统生成派生模型，而不是手工拖拽。
- 支持 SG、DFIG、VSC、MMC、LCC/HVDC、储能和弱电网场景扩展。
- 每次生成都产出 traceability、检查报告、仿真证据和 agent handoff。
- 优先服务电力电子主导电力系统：弱网、PLL/GFM/GFL、跨时间尺度、IBR 证据。

## 2. 当前参考源

项目内 oracle 仍被脚本引用，不能直接删除或改写：

- `NEBUS39V2.slx`
- `NE39bus_dataV2.m`
- `power_KundurTwoAreaSystem.slx`
- `power_wind_dfig_avg.slx`

当前主要外部参考源：

- `C:\Users\jonas\Desktop\实验室仿真模型汇总`：完整实验室模型库，仅读取，不编辑。
- `C:\Users\jonas\Desktop\AI summary of simulation models`：保留 6.3 以后模型作为生成结果参考。
- `.agents/skills/*`：项目本地技能契约。
- `docs/MODELING_PATTERN_LIBRARY.md`：M01-M08 参数、布局和复用模式。

## 3. 输入规格

规格文件建议放在 `specs/`，使用 YAML/JSON。最小字段：

- `system`: 名称、base MVA、频率、solver、sample time、stop time。
- `buses`: 母线编号、电压等级、节点类型、初始电压。
- `branches`: 线路、变压器、阻抗、电纳、分接头。
- `loads`: 母线、有功、无功、负荷模型。
- `devices`: SG、DFIG、VSC、MMC、LCC、storage 等设备。
- `replacement`: SG 到 DFIG/VSC/MMC 的替换规则。
- `controls`: AVR、PSS、governor、PLL、电流环、直流电压环、VSG/GFM 参数。
- `convergence_targets`: 潮流、初始化、时域稳定、弱网、故障和证据目标。

任何模型生成前先运行规格校验。AI-in-loop 中对应 S1。

## 4. 标准建模流程

```text
读取规格
  -> S1 规格校验
  -> S0.25 选择建模保真度
  -> 创建/派生目标模型
  -> 设置 powergui、solver、采样时间
  -> 生成母线、线路、变压器、负荷
  -> 通过 adapter 实例化设备
  -> 注入参数、控制器和初始化变量
  -> 连接三相物理端口
  -> 写入 trace metadata
  -> S2 adapter contract 检查
  -> S3 layout/quality 检查
  -> S5/S6 smoke/tuning
  -> S5B weak-grid SCR evidence when enabled
  -> S7/S7B model verification / sltest fallback
  -> S8B modal evidence when enabled
  -> S10/S10B/S10C snapshot, audit, IBR evidence
```

## 5. 设备实例化规则

设备一律通过 adapter 生成，Agent 不应直接深入模板内部随意改线。

推荐接口：

```matlab
deviceInfo = instantiate_device(modelName, deviceSpec, libraryConfig)
```

`deviceInfo` 至少返回：

- `trace_id`
- `block_path`
- `sid`
- `device_type`
- `bus`
- `electrical_ports`
- `measurement_ports`
- `parameter_hash`

优先级：

1. 已验证 donor 子系统。
2. 项目内 oracle/template。
3. 实验室模型库模式。
4. 官方 MathWorks MBD core skills。
5. GitHub 候选库，只作参考，不直接污染 runtime 技能路由。

## 6. 参数与调参

收敛分三层：

- 潮流收敛：母线电压、P/Q、PV/PQ 约束。
- 初始化收敛：设备初始状态、电流、电压、控制器积分状态一致。
- 时域稳定：无 NaN、无失步、无明显发散，扰动后恢复符合目标。

调参要记录：

- 修改的参数和边界。
- 修改前后指标。
- 失败签名。
- 是否应用 best-so-far rollback。
- 生成的 tuning report 和机器可读 JSON。

控制器、基准值、DFIG/SG/MMC/LCC 参数优先从 `docs/MODELING_PATTERN_LIBRARY.md` 读取。

## 7. Traceability 和报告

每个关键 block/subsystem 必须写入 trace metadata：

```matlab
trace.id = "dfig_G33";
trace.component_type = "dfig_wind";
trace.source_spec = "specs/case_nebus39_dfig_weakgrid_v0.yaml";
trace.template = "DFIG donor subsystem";
trace.bus = 33;
trace.parameter_hash = "...";
set_param(blockPath, "UserData", trace);
set_param(blockPath, "UserDataPersistent", "on");
```

生成报告位置：

- `build/reports/spec_validation/`
- `build/reports/adapters/`
- `build/reports/layout/`
- `build/reports/fidelity/`
- `build/reports/scenarios/`
- `build/reports/modal/`
- `build/reports/validation/`
- `build/reports/snapshots/`

`build/` 是生成物目录，可清理；持久规则必须写回 tracked docs 或 skill contract。

## 8. 布局规则

核心规则来自 `docs/MODELING_PATTERN_LIBRARY.md` 的 M01-M08：

- 顶层只放电气主路径、powergui、少量系统级测量；复杂逻辑进 SubSystem。
- 横向代表电气流向，纵向代表区域/并行支路/设备复制。
- 三相物理连接显式连线，不能用 Goto/From 替代。
- 测量和控制信号可用 Goto/From。
- 块间距至少接近块宽，避免重叠和交叉线。
- 对称系统按左区/右区或源/网侧镜像布置。

旧 `REFERENCE_MODEL_LAYOUT_OBSERVATIONS.md` 和 `IEEE39_LAYOUT_REFERENCES.md` 已合并到本规则和模式库。

## 9. AI-in-loop 工作规则

Claude Code 每轮工作必须：

1. 读取最新 `build/reports/agent_handoff/latest_claude_packet.md`。
2. 只读目标 skill 的 `SKILL.md` 和必要的一份 reference/contract。
3. 明确 artifact contract。
4. 做最小必要修改。
5. 运行最小验证：`checkcode`、helper smoke、synthetic evidence 或一次 fast MATLAB run。
6. 重读生成 artifact。
7. 更新 handoff packet 后再交回 Codex。

Codex 默认负责 review：

- bug
- 边界问题
- 漏测
- stale artifact
- 不必要改动
- 是否违反“不重构，只修关键文件”

## 10. 当前目标与保留策略

当前分支：`integration/skills-maturation-2026-06`

当前 backlog：

- P3 `impedance-frequency-analysis`：补充阻抗/频域证据。
- P4 stronger IBR evidence：把同轮 S5/S6/S7/S8B/S10B 证据接入 S10C。

模型保留策略：

- 项目内生成模型只保留最近两天修改过、或最新 handoff 明确引用的模型。
- 桌面实验室模型库和 `AI summary of simulation models` 不由本仓库清理。
- 项目内 oracle 暂时保留，除非代码迁移到外部参考库路径。
