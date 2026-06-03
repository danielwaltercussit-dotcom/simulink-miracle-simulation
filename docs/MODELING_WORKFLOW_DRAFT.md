# 流程化电力系统 Simulink 建模规范初稿

版本：v0.1  
状态：草案，后续根据新的需求、设备模型和实际建模结果持续修订  
适用项目：`C:\Users\jonas\Desktop\simulink_agent_v1`

## 1. 目标

本规范的目标是形成一套可移植、可复用、可检查的 Simulink 电力系统建模流程。使用者或 Agent 只需要提供系统拓扑、节点设备类型、设备参数和替换规则，即可基于已有单机模型库快速生成完整系统模型。

目标能力包括：

- 基于已有单机模型构建多机系统，例如 IEEE 10 机 39 节点系统。
- 支持同步发电机、双馈风机，后续扩展 VSC、MMC、储能等设备。
- 通过规格文件驱动模型生成，减少手工拖拽和重复连线。
- 支持参数调整和收敛修复流程。
- 在模型中保留可溯源、可检查的节点信息。
- 形成可交给其他 Agent 使用的标准建模文档。

## 2. 总体原则

1. 规格驱动，而不是临时手工建模。
2. 模型库组件化，而不是直接复制完整示例模型。
3. 每类设备通过统一接口接入系统网络。
4. 参数、拓扑、模板版本和生成过程必须可追踪。
5. 建模、初始化、收敛调参、检查报告必须流程化。
6. 每次自动生成或修改模型后都要运行结构检查和基础仿真检查。

## 3. 推荐项目结构

```text
simulink_agent_v1/
  models/
    libraries/
      component_library.slx
      templates/
        SG_Template.slx
        DFIG_Template.slx
        VSC_Template.slx
        MMC_Template.slx

  specs/
    case_ieee39.yaml
    case_kundur.yaml

  scripts/
    build_system_from_spec.m
    validate_spec.m
    instantiate_device.m
    connect_network.m
    apply_device_params.m
    run_initialization.m
    run_smoke_test.m

    trace/
      attach_trace_metadata.m
      export_traceability_index.m
      check_traceability.m
      compare_spec_to_model.m

    tuning/
      run_tuning_workflow.m
      evaluate_convergence.m
      diagnose_failure.m
      propose_parameter_update.m
      apply_parameter_update.m

  build/
    generated_models/
    reports/
    traceability_index.json

  docs/
    MODELING_WORKFLOW_DRAFT.md
    DEVICE_TEMPLATE_STANDARD.md
    SPEC_SCHEMA.md
    AGENT_MODELING_GUIDE.md
```

当前项目已有的原始参考模型：

- `power_KundurTwoAreaSystem.slx`：四机两区系统，同步发电机模板来源之一。
- `power_wind_dfig_avg.slx`：双馈风机单机并网模型，DFIG 模板来源之一。

## 4. 建模输入

建模输入应统一保存为规格文件，建议使用 YAML 或 JSON。规格文件至少包含：

- 系统基本信息：模型名、基准容量、频率、仿真时长、采样时间、solver。
- 母线列表：母线编号、电压等级、节点类型、初始电压。
- 支路列表：线路、变压器、阻抗、并联电纳、分接头。
- 负荷列表：连接母线、有功、无功、负荷模型类型。
- 设备列表：同步机、DFIG、VSC、MMC 等。
- 替换规则：例如将 IEEE 39 节点中的某些同步机替换为等容量 DFIG。
- 控制参数：AVR、PSS、governor、PLL、电流环、直流电压环等。
- 收敛目标和调参边界。

示例：

```yaml
system:
  name: ieee39_sg_dfig
  base_mva: 100
  frequency_hz: 60
  solver: FixedStepDiscrete
  sample_time: 5e-5
  stop_time: 10

buses:
  - id: 30
    voltage_kv: 20
    type: generator

branches:
  - id: line_001_002
    from: 1
    to: 2
    type: line
    r_pu: 0.0035
    x_pu: 0.0411
    b_pu: 0.6987

devices:
  - id: G30
    type: synchronous_generator
    bus: 30
    template: SG_Template
    rated_mva: 1000
    p_mw: 250
    v_pu: 1.0475

  - id: W33
    type: dfig_wind
    bus: 33
    template: DFIG_Template
    rated_mva: 1000
    p_mw: 650
    q_control: voltage
```

## 5. 模型库和设备模板规范

每类设备需要整理成可复用模板。模板应尽量从完整示例模型中剥离出来，而不是把整个示例模型直接复制到目标系统。

每个设备模板应满足：

- 有明确的三相电气接口，例如 `A/B/C`。
- 有明确的控制输入，例如 `Pref`、`Qref`、`Vref`、`WindSpeed`。
- 有统一测量输出，例如 `m` 或 measurement bus。
- 使用 mask 或初始化脚本接收参数。
- 支持参数从规格文件注入。
- 模板内部不应硬编码目标系统的母线编号、线路、负荷或外部网络。
- 模板应有版本号和来源说明。

初始模板来源建议：

- 同步机模板：从 `power_KundurTwoAreaSystem.slx` 中的 `M1 900 MVA`、`M1: Turbine & Regulators` 等结构整理。
- DFIG 模板：从 `power_wind_dfig_avg.slx` 中的 `DFIG Wind Turbine` 整理。

后续新增设备时，每种设备至少补充：

- 模板 `.slx` 或 library block。
- 参数 schema。
- 初始化规则。
- 端口说明。
- adapter 函数。
- smoke test。

## 6. 自动建模流程

标准建模流程如下：

```text
读取规格文件
  ↓
校验拓扑和参数
  ↓
创建空白 Simulink 模型
  ↓
设置 powergui、solver、采样时间和仿真参数
  ↓
生成母线、线路、变压器、负荷
  ↓
按设备类型实例化模板
  ↓
注入设备参数和控制参数
  ↓
根据拓扑连接设备与网络
  ↓
写入可溯源元数据
  ↓
生成 traceability index
  ↓
运行结构检查
  ↓
运行初始化和短时仿真检查
  ↓
输出模型、日志和检查报告
```

核心脚本建议：

- `validate_spec.m`：检查规格文件是否完整、参数是否在合理范围内。
- `build_system_from_spec.m`：总入口。
- `instantiate_device.m`：根据设备类型调用具体 adapter。
- `connect_network.m`：按拓扑连接三相端口。
- `apply_device_params.m`：注入额定容量、控制器参数、初始值。
- `run_initialization.m`：执行潮流或设备初值映射。
- `run_smoke_test.m`：运行短时无扰动仿真。

## 7. 设备实例化流程

每个设备通过 adapter 生成，Agent 不应直接深入模板内部随意改线。

建议 adapter 接口：

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

示例规则：

- `type = synchronous_generator` 调用 `instantiate_sg.m`
- `type = dfig_wind` 调用 `instantiate_dfig.m`
- `type = vsc` 调用 `instantiate_vsc.m`
- `type = mmc` 调用 `instantiate_mmc.m`

## 8. 参数收敛和调参流程

当系统架构和运行方式固定，但参数不确定时，应使用独立的调参流程，而不是无记录地手动改参数。

收敛分为三层：

1. 潮流收敛：母线电压、P/Q、PV/PQ 节点满足约束。
2. 初始化收敛：设备初始状态、电流、电压、控制器积分状态一致。
3. 时域仿真稳定：模型能跑完指定时长，无 NaN、无失步、无明显数值发散。

调参流程：

```text
读取待调参数和边界
  ↓
运行潮流或初始化
  ↓
运行短时无扰动仿真
  ↓
计算收敛指标
  ↓
诊断失败原因
  ↓
按规则提出参数更新
  ↓
应用参数更新
  ↓
重复直到满足目标或达到最大轮数
  ↓
输出 tuned spec 和 tuning report
```

推荐先采用规则型调参，再采用优化型调参。

规则型调参优先级：

1. 潮流相关参数：P/Q、PV/PQ 节点、无功补偿、分接头。
2. 设备初始值：机械功率、励磁、电机转速、DFIG 滑差、直流电压。
3. 控制器参数：AVR、PSS、governor、PLL、电流环、直流电压环。
4. 数值仿真设置：步长、滤波器时间常数、snubber 等。

示例目标：

```yaml
convergence_targets:
  load_flow:
    voltage_range_pu: [0.9, 1.1]
    max_power_mismatch_pu: 0.02

  initialization:
    max_initial_current_pu: 2.0
    max_initial_power_mismatch_pu: 0.02

  simulation:
    duration_s: 10
    no_nan: true
    no_loss_of_synchronism: true
    max_voltage_deviation_pu: 0.2
    max_frequency_deviation_hz: 1.0
```

每次调参必须输出：

- `case_name_tuned.yaml`
- `tuning_report.md`
- 每轮参数改动记录
- 改动前后指标对比
- 未满足目标时的失败原因

## 9. 可溯源和可检查节点

每个自动生成的关键模型节点都必须有唯一 ID。推荐命名：

- `bus_001`
- `line_001_002`
- `load_018`
- `sg_G30`
- `dfig_G33`
- `vsc_005`

每个关键 block 或 subsystem 必须写入 trace metadata：

```matlab
trace.id = "dfig_G33";
trace.component_type = "dfig_wind";
trace.source_spec = "specs/case_ieee39.yaml";
trace.source_section = "devices[3]";
trace.template = "DFIG_Template";
trace.template_version = "v0.1";
trace.bus = 33;
trace.rated_mva = 1000;
trace.generated_by = "build_system_from_spec.m";
trace.generated_at = datetime("now");
trace.check_status = "unchecked";

set_param(blockPath, "UserData", trace);
set_param(blockPath, "UserDataPersistent", "on");
set_param(blockPath, "AttributesFormatString", "ID: dfig_G33\nBus: 33\nType: DFIG");
```

同时生成外部索引：

```text
build/traceability_index.json
```

索引应包含：

- spec ID
- block path
- SID
- component type
- bus
- template
- parameter hash
- connected components
- generated time
- check status

## 10. 检查报告

每次建模后必须生成检查报告：

```text
build/reports/model_check_report.md
```

报告至少包含：

- 母线数量是否与规格文件一致。
- 线路和变压器数量是否一致。
- 设备数量和类型是否一致。
- 每个设备是否连接到正确母线。
- 每个关键 block 是否有 trace metadata。
- 每个参数是否来自规格文件或默认策略。
- 是否存在未连接端口。
- 是否存在规格文件中有、模型中缺失的节点。
- 是否存在模型中有、规格文件中没有来源的节点。
- 短时仿真是否通过。

## 11. 模型排版和可读性规则

自动生成的 Simulink 模型必须在建模完成后执行布局流程。排版不是装饰性工作，而是模型可检查、可复核、可移植的一部分。

### 11.1 总体布局原则

1. 模型布局应表达系统逻辑，而不是只追求块之间距离最短。
2. 顶层模型优先呈现系统级拓扑：母线、支路、设备和测量/报告节点。
3. 设备内部控制细节应保留在模板或子系统内部，不在顶层展开成噪声。
4. 同类对象应尺寸一致、命名一致、颜色一致。
5. 连接线应尽量正交、少交叉、少重叠；必要时使用脚本化重新路由。
6. 自动布局必须可重复运行，不允许只依赖手工拖拽。

### 11.2 电力系统顶层布局

对于网络型电力系统模型，顶层推荐使用拓扑感知布局：

- 对 IEEE 39、IEEE 118、Kundur 两区等标准算例，如果存在被论文和教材广泛使用的单线图，应优先采用标准单线图坐标模板。
- 母线节点按系统网络拓扑或标准单线图放置，而不是简单按编号排成一行。
- 支路线/线路块放在连接母线的中点附近。
- 发电机、DFIG、VSC、MMC、负荷等设备放在其接入母线附近。
- 当某个块被用作母线连接点时，顶层视觉上应尽量接近窄 busbar，而不是占据大面积的负荷块外观。
- 线路、断路器、变压器等串联元件应沿实际连接方向拉伸或旋转，使元件本身承担主要视觉距离，减少母线到元件之间的长飞线。
- `powergui`、初始化、仿真配置类模块放在左上角或固定配置区。
- 报告、Scope、检查节点放在右侧或底部，避免混入主电气网络。
- 对大型系统，允许使用子系统分区，例如 `Network`、`Devices`、`Measurements`、`Reports`。
- 顶层标签保持短小：母线优先显示编号，线路优先依靠块名或 trace index 检查，详细来源和类型写入 `UserData` 与外部 traceability index，避免完整元数据铺满顶层图。

### 11.2.1 参考模型经验

项目内 `power_KundurTwoAreaSystem.slx` 和 `power_wind_dfig_avg.slx` 的排版经验应作为自动生成模型的优先参考：

- 主电气路径保持清晰的电路图风格；径向或区域间链路优先按左到右排列。
- 母线用窄 busbar 或紧凑连接节点表达，设备内部细节放进子系统。
- 三相线尽量保持平行且局部化，避免大范围绕线。
- 测量、控制、Scope、报告区与主电气网络分开，通常放在右侧、下方或单独浅色区域。
- 对长距离测量/控制信号使用 `Goto/From` 标签；物理电气连接不使用 `Goto/From` 替代，应通过局部布线、旋转元件或子系统端口解决。

更详细的观察记录见：

```text
docs/REFERENCE_MODEL_LAYOUT_OBSERVATIONS.md
```

### 11.3 颜色和视觉编码

推荐使用稳定的颜色语义：

- 母线/负荷连接节点：浅蓝色。
- 支路/线路：白色或浅灰色。
- 同步发电机：浅绿色。
- DFIG/风电设备：橙色。
- VSC/MMC/电力电子设备：浅紫或浅青色，后续设备规范中固定。
- 仿真配置和 `powergui`：黄色。
- 检查、报告、警告节点：浅灰或黄色注释。

颜色只是辅助信息，不能替代 trace metadata 和命名规则。

### 11.4 间距和尺寸

建议规则：

- 母线节点尺寸保持一致。
- 支路块尺寸保持一致，放在对应两端母线中点附近。
- 支路块可以按连接方向拉伸；横向支路保持水平，纵向支路可旋转为竖向，斜向支路优先分解为局部水平/垂直段或放入子系统。
- 大设备块与其母线保持足够距离，避免遮挡母线名和线路。
- 顶层块之间至少保留一个块宽度的阅读间隔。
- 不允许关键文字、块名、端口或线段互相覆盖。
- 对自动生成的大模型，应在布局脚本中统一设置 `Position`，并在报告中记录布局策略。

### 11.5 自动布局脚本

每个自动生成的系统模型应提供可重复运行的布局脚本，例如：

```text
scripts/layout_ieee39_physical_v02.m
```

布局脚本应完成：

- 根据标准单线图坐标模板、拓扑或功能区计算块坐标。
- 设置关键块大小和位置。
- 对关键对象设置稳定颜色。
- 添加必要的布局说明 annotation。
- 对普通信号线可调用线路路由函数；对高密度三相物理电气线，应优先重建局部连接或分层封装，避免通用自动路由生成大范围回环。
- 保存模型并生成布局报告。

MathWorks 官方提供 `Simulink.BlockDiagram.arrangeSystem` 用于重新排列、调整大小、移动块并拉直信号线，也提供 `Simulink.BlockDiagram.routeLine` 作为连线重路由工具。对于电网拓扑模型，应优先使用自定义标准单线图布局或拓扑布局；当通用自动排列或自动路由破坏标准电网图的空间语义时，应改用确定性的局部布线策略。

IEEE 39 节点模型的布局参考见：

```text
docs/IEEE39_LAYOUT_REFERENCES.md
```

### 11.6 布局检查报告

每次布局后应生成报告，例如：

```text
build/reports/layout_v02_report.md
```

报告至少包含：

- 使用的布局策略。
- 母线、支路、设备的摆放原则。
- 颜色语义。
- 是否保留 trace metadata。
- 是否重新路由顶层连线。
- 是否在布局后重新通过 compile/smoke test。

### 11.7 分层模型结构

当系统规模达到多机、多区域、多支路，且顶层三相物理连线已经影响检查效率时，应升级为分层模型，而不是继续在根层展开全部物理连接。

推荐层次：

- 根层：导航层，只放 `Topology_Overview`、`Electrical_Network_Detail`、`Measurements`、`Reports_Trace` 等入口。
- `Topology_Overview`：标准单线图式概览层，用轻量 busbar、线路块和设备块表达拓扑；隐藏大部分支路标签，只保留母线编号和设备类型。
- `Electrical_Network_Detail`：可执行物理网络层，保留真实 SPS/Simscape 物理连接、模板设备和 powergui。
- `Measurements`：测量、PMU、Scope、报告输出层；长距离测量/控制信号可使用 `Goto/From`。
- `Reports_Trace`：规格、traceability index、检查报告和调参报告入口。

分层原则：

- 顶层不再承载全部三相物理连线，只提供导航和系统级检查入口。
- 物理电气连接不使用 `Goto/From` 替代；跨层物理连接应通过子系统端口、连接适配器或保持在 detail 层内部。
- `Topology_Overview` 是可读视图，不替代可执行网络；它必须能追溯到 detail 层中的真实 bus、branch 和 device。
- 当 `branch_count > 30`、三相物理线超过约 `100` 条、或布局报告显示大跨度/交叉线过多时，应默认生成分层模型。
- 分层模型仍必须通过 compile check 和 smoke simulation，确认封装没有改变仿真行为。

当前 IEEE39 v0.3 分层示例：

```text
scripts/build_ieee39_sg5_dfig5_hierarchical_v03.m
build/generated_models/ieee39_sg5_dfig5_hierarchical_v03.slx
build/reports/hierarchical_v03_report.md
```

## 12. Agent 工作规则

其他 Agent 接手本项目时，应遵守：

1. 先读取本文件和 `AGENTS.md`。
2. 不直接修改原始参考模型，除非用户明确要求。
3. 建模时优先生成新模型到 `build/generated_models/`。
4. 新增设备类型时，先补模板规范和 adapter，再接入系统 builder。
5. 自动生成的关键节点必须写入 trace metadata。
6. 自动建模完成后必须生成 traceability index 和检查报告。
7. 调参必须保留参数修改记录，不允许无记录手改。
8. 对不确定的物理参数，应在报告中标注来源、默认值或待确认状态。
9. 自动生成或更新模型后必须运行布局脚本，并生成布局报告。
10. 布局后必须重新运行结构检查、compile check 或 smoke test，确认排版没有破坏模型。

## 13. 当前待办

近期建议按以下顺序推进：

1. 建立 `models/libraries/templates/` 目录。
2. 从四机两区模型中抽取同步机模板草案。
3. 从 DFIG 模型中抽取双馈风机模板草案。
4. 定义 `SPEC_SCHEMA.md`。
5. 定义 `DEVICE_TEMPLATE_STANDARD.md`。
6. 编写第一个 `case_kundur.yaml` 作为小规模验证样例。
7. 实现 `validate_spec.m` 和最小版 `build_system_from_spec.m`。
8. 实现 trace metadata 和检查报告。
9. 再扩展到 IEEE 39 节点混合同步机/DFIG 系统。

## 14. 后续修订原则

这份文档是初稿。之后新增需求时，应优先更新规范，再更新脚本和模板。每次新增设备或流程能力时，应同步补充：

- 输入参数格式。
- 模板接口。
- 初始化方法。
- 收敛检查指标。
- 可溯源字段。
- 示例规格文件。
- Agent 操作说明。

## 15. v0.5 排版优化补充

v0.5 的 IEEE39 分区模型在 v0.4 基础上增加一条更细的排版规则：顶层既要保留可执行物理网络，也要避免让普通信号线把区域块和跨区联络线淹没。

- 根层跨区物理 SPS 联络线仍应保持为显式物理连接，不使用 `Goto`/`From` 替代。
- 根层较长的普通 Simulink 测量/控制信号线可以替换为 `Goto`/`From` 标签对，尤其是穿过多个区域块或跨越大半个画布的信号。
- `Goto`/`From` 只用于普通 Simulink 信号，不用于电气守恒端口、三相导线或物理网络拓扑。
- 在母线、支路和设备已经按确定性坐标放置后，不再对同一物理细节层运行整层 `arrangeSystem`；如需整理连线，应在固定块位置后做局部 `routeLine`。
- 区域子系统边界端口应按最近可读边缘分组放置；端口标签造成拥挤时可隐藏，详细来源仍以 trace index 和 block `UserData` 为准。
- 生成模型可以同时提供两类视图：用于审图的清洁拓扑/导航视图，以及用于仿真和底层检查的可执行物理细节视图。

## 16. v0.6 子模块排线补充

v0.6 进一步区分“可读审图层”和“可执行物理细节层”。直接把大量三相物理端口暴露在同一个区域子系统中，会产生端口遮挡、长矩形回线和交叉线；这类画布不适合作为第一审图入口。

- 区域子模块默认先提供 `Regional_Overviews` 中的清洁单线图，只显示母线、支路和设备类型。
- 可执行 SPS 物理连接保留在 `Area_Partitioned_Physical_Detail` 中，用于仿真、compile 和底层核查。
- 区域内部较长的普通 Simulink 控制/测量线使用局部 `Goto`/`From` 标签；物理连接线仍保持显式连接。
- `Connection Port` 按端口排架分组，端口标签默认隐藏，避免遮挡三相线和设备标签。
- 小尺度区域单线图默认隐藏支路文字标签，支路来源依赖块名、trace metadata 和外部 trace index。
- 当物理细节层由于跨区端口过多而不可读时，不应继续依赖全局自动布线；应新增清洁导航层或区域审图层，并把复杂物理细节作为可执行下钻层。

## 17. v0.7 案例学习与反思

v0.7 参考了 MathWorks 官方电力系统示例和 Simulink 建模规范后，进一步把“审图视图”和“执行视图”分开。优秀电力系统模型通常不会把发电机控制、负荷、测量、三相电网和跨区联络线全部摊在同一个子系统第一层，而是通过分层和清晰的单线图入口降低阅读负担。

本轮新增经验：

- 优先优化元器件位置和尺寸，再谈自动布线。块互相重叠时，任何自动路由都会生成难看的绕线。
- 区域审图图中，母线和设备要留出足够间距；支路块设置最大长度，避免为了连接远距离节点而被拉伸得过长。
- 小尺度区域图中默认隐藏支路文字标签，只保留母线编号和设备短标签，例如 `G32`、`W34`。
- 可执行物理细节层允许复杂，但不应作为人工审图的默认入口；默认入口应是 `Topology_Overview` 和 `Regional_Overviews`。
- 每次改布局后必须导出截图自查，至少检查一个最密集区域，例如 IEEE39 的 `Zone_Central_Overview`。
- 旧版本生成物应及时清理，只保留最近一到两个可用版本，避免后续 Agent 误用过时模型。

历史版本记录（已被第 21 节的 NEBUS39V2 干净重建版取代）：

- `scripts/build_ieee39_sg5_dfig5_layout_optimized_v07.m`
- `build/generated_models/ieee39_sg5_dfig5_layout_optimized_v07.slx`
- `build/reports/layout_optimized_v07_report.md`

## 18. v0.8 标准模型对齐规则

v0.8 引入用户新导入的标准 New England 39-bus 模型作为基准参照：

```text
NEBUS39V2.slx
NE39bus_dataV2.m
```

对比结论：

- 标准模型是完整十机同步机基准，而当前生成模型是 5 台同步机 + 5 台 DFIG 的场景模型；DFIG 替换必须作为显式 scenario overlay，而不是把原始十机参数静默丢弃。
- 标准模型把线路、变压器、同步机、AVR、PSS、调速器等数据集中在 `NE39bus_dataV2.m` 的表格变量中；后续生成模型也应优先采用“基准数据表 + 场景覆盖表”的数据组织方式。
- 标准模型顶层较多地直接暴露可执行电气元件和 G1-G10 设备，适合作为可执行 benchmark；生成模型可继续保留 v0.7 的审图层/物理细节层分离，但必须能追溯到标准 benchmark 中的母线、支路、变压器和机组表。
- 标准模型大量使用 `Goto`/`From` 处理测量和控制信号；该做法可以采纳，但仅限普通 Simulink 信号。三相物理电气连接、SPS 物理联络线和守恒端口仍必须显式连接。
- 标准模型的机组命名和数据索引清晰：G1-G10 对应 `mac_con`、`AVR_Data`、`PSS_Data`、`STG_Data` 的行。生成模型的 `sg_Gxx`、`dfig_Gxx` 必须额外保留 `benchmark_machine_id`、`benchmark_bus` 和 `scenario_role`。

新增工作规则：

1. 导入新的标准 `.slx` 后，先生成结构对比报告，至少统计 block、line、annotation、top-level block、Goto/From、Subsystem、主要 mask type 和 power-system block 样本。
2. 对 IEEE39/New England 39-bus 这类已有标准模型，先建立完整 SG benchmark contract，再定义 SG/DFIG/VSC/MMC 等替换场景。
3. 生成模型回调应能加载标准数据脚本；场景参数、调参结果和替换策略单独写入 `build/data`，不要直接写死在 mask 内部。
4. 每次替换场景都要校核母线、支路、变压器、负荷和原始机组数量，报告中明确“保留、替换、删除、新增”的对象。
5. 顶层模型应同时提供：
   - 标准基准入口，例如 `NEBUS39_Standard_Benchmark`
   - 场景覆盖入口，例如 `SG5_DFIG5_Scenario_Overlay`
   - 数据接口说明，例如 `Benchmark_Data_Interface`
   - 可读拓扑入口和可执行物理细节入口
6. 文档和模型报告必须记录所用经验库/skills，尤其是项目本地 `.agents/skills` 中部署的技能。

本轮已生成的标准对齐产物：

```text
scripts/compare_nebus39_reference_v08.m
scripts/build_ieee39_sg5_dfig5_reference_aligned_v08.m
build/generated_models/ieee39_sg5_dfig5_reference_aligned_v08.slx
build/reports/nebus39_reference_comparison_v08.md
build/reports/reference_aligned_v08_report.md
build/reports/ieee39_reference_aligned_v08_top.png
```

历史版本记录（已被第 21 节的 NEBUS39V2 干净重建版取代）：

- `scripts/build_ieee39_sg5_dfig5_reference_aligned_v08.m`
- `build/generated_models/ieee39_sg5_dfig5_reference_aligned_v08.slx`
- `build/reports/reference_aligned_v08_report.md`

## 19. GitHub 技能与电力电子库安装规则

当需要进一步优化电力电子化电力系统中的 MATLAB/Simulink 元器件排版、连线和组件库选择时，优先使用项目本地安装的 GitHub 来源，而不是临时手工搜索。

本轮已下载到：

```text
external/github/
```

已安装的关键来源：

- `simulink/skills`：Simulink agent skills，上游包含模型交互、命令行调试、初始化 profiling、仿真 profiling 和 solver profiling。
- `matlab/agent-skills-playground`：MATLAB/Simulink agent skill 示例与 MBSE 工作流样例。
- `McSCert/Auto-Layout`：Simulink 自动排版工具，支持 Graphviz、GraphPlot 和 DepthBased 排版方法。
- `McSCert/Simulink-Utility`：Simulink bounds、line routing、Goto/From、connected block 等实用函数。
- `mathworks/Simscape_Electrical_Support_Library`：面向电力系统工程师的 Simscape Electrical 支撑库和样例。当前项目 MATLAB 为 R2024b，而该库声明支持 R2025b 及更新版本，因此本项目中先作为参考库，不默认加入 path。
- `efantnu/pwrsys-matlab`：面向 converter-interfaced equipment 的开源 MATLAB/Simulink 电力系统库，可参考 VSC、PLL、PI、滤波器、功率理论、坐标变换和电压源组件。

新增项目本地 skill：

```text
.agents/skills/simulink-auto-layout-github
.agents/skills/power-electronics-component-libraries
```

使用规则：

1. 排版类任务先触发 `simulink-auto-layout-github`，再决定使用确定性坐标、`arrangeSystem`、McSCert Auto-Layout、局部 `routeLine`，或新增审图层。
2. 电力电子组件类任务先触发 `power-electronics-component-libraries`，再从标准基准、DFIG 模板、`pwrsys-matlab` 和 Simscape Electrical Support Library 中选择来源。
3. 三相物理电气连接与守恒端口不得用 `Goto`/`From` 替代；`Goto`/`From` 只用于普通 Simulink 测量/控制信号。
4. 不直接修改导入的标准模型；所有 GitHub 工具实验应作用在派生模型或新版本生成脚本上。
5. 每次用外部库引入新元器件时，报告中必须记录 source repo、本地路径、MATLAB/toolbox 版本要求、源 block、参数来源、替换关系和 smoke test 状态。

项目本地 MATLAB 初始化已更新：

```text
init_simulink_agent_project.m
scripts/init_github_power_electronics_layout_tools.m
```

安装记录见：

```text
build/reports/github_skill_install_2026_05_18.md
```

2026-05-29 新增项目本地 active skill：

```text
.agents/skills/simulink-power-electronics
```

来源与安装记录：

```text
external/github/npuzsy-simulink-power-electronics
build/reports/simulink_power_electronics_skill_install_2026_05_29.md
```

使用规则：

1. 当任务涉及 DFIG、并网逆变器、VSC、MMC、HVDC/FACTS、PWM/SVPWM、P/Q 控制、门极路由、波形诊断或电力电子布局时，先触发 `simulink-power-electronics` 做领域路由和证据要求。
2. 通用建模、连线、仿真、测试仍优先使用 MathWorks MBD skills：`building-simulink-models`、`simulating-simulink-models`、`testing-simulink-models`。
3. `simulink-power-electronics` 的 subskills 作为按需加载的领域经验库，尤其优先使用 `three-phase-grid-inverter`、`renewable-grid-systems`、`hvdc-facts` 和 `multilevel-mmc`。
4. `huanhyougo/matlab-power-electronics-skill` 已克隆到 `external/github/huanhyougo-matlab-power-electronics-skill` 作为参考案例库，但因其 `SKILL.md` 存在编码乱码和硬编码外部路径，暂不注册为 active skill。

## 20. v0.9 skill 优化模型规则

v0.9 使用新安装的项目本地 skills 对 v0.8 进行派生优化，而不是覆盖已有模型：

```text
.agents/skills/simulink-auto-layout-github
.agents/skills/power-electronics-component-libraries
```

本轮经验：

- 根层应继续作为审图和导航画布，不承载全部三相物理细节。v0.9 将根层重新组织为拓扑、区域概览、可执行物理细节、标准 benchmark、场景 overlay、数据接口、报告、排版审计、组件库指南和 GitHub 来源索引。
- `McSCert/Auto-Layout`、`McSCert/Simulink-Utility` 和 `pwrsys-matlab` 已在 MATLAB path 中激活；`Simscape_Electrical_Support_Library` 因当前 MATLAB R2024b 低于其 R2025b 要求，仅作为参考库记录。
- 自动排版工具只用于普通 Simulink 控制/测量子系统或根层普通信号线；物理 SPS 细节层不做全局自动排版，避免破坏电气连接语义。
- 电力电子组件选择应先查看 `Power_Electronics_Library_Guide`：DFIG 继续以 `power_wind_dfig_avg.slx` 为兼容来源，VSC/PLL/PI/滤波器可参考 `pwrsys-matlab`，现代 Simscape 组件可参考但暂不执行 `Simscape_Electrical_Support_Library`。
- 模型报告必须列出启用的 skill、GitHub 工具 path 状态、根层 overlap 审计、compile/smoke 结果和导出的截图。

本轮产物：

```text
scripts/build_ieee39_sg5_dfig5_skill_optimized_v09.m
build/generated_models/ieee39_sg5_dfig5_skill_optimized_v09.slx
build/reports/skill_optimized_v09_report.md
build/reports/ieee39_skill_optimized_v09_top.png
build/reports/ieee39_skill_optimized_v09_layout_audit.png
build/reports/ieee39_skill_optimized_v09_component_guide.png
```

历史版本记录（已被第 21 节的 NEBUS39V2 干净重建版取代）：

- `scripts/build_ieee39_sg5_dfig5_skill_optimized_v09.m`
- `build/generated_models/ieee39_sg5_dfig5_skill_optimized_v09.slx`
- `build/reports/skill_optimized_v09_report.md`

## 21. NEBUS39V2 干净重建规则（当前推荐）

用户明确要求后，v0.8/v0.9 这类带额外审图、报告、GitHub 来源索引、组件库指南等根层子模块的模型不再作为当前目标模型。当前目标是依照 `NEBUS39V2.slx` 的顶层布局重新建立 IEEE 10 机 39 节点标准系统场景，并将 5 台同步机替换为 DFIG。

当前推荐产物：

```text
scripts/build_ieee39_10m39bus_sg5_dfig5_nebus_layout.m
build/generated_models/ieee39_10m39bus_sg5_dfig5_nebus_layout.slx
build/reports/ieee39_10m39bus_sg5_dfig5_nebus_layout_report.md
build/reports/ieee39_10m39bus_sg5_dfig5_nebus_layout_top.png
```

替换关系：

```text
G4 -> W33, benchmark bus 33, mac_con row 4
G5 -> W34, benchmark bus 34, mac_con row 5
G6 -> W35, benchmark bus 35, mac_con row 6
G7 -> W36, benchmark bus 36, mac_con row 7
G8 -> W37, benchmark bus 37, mac_con row 8
```

建模规则：

1. `NEBUS39V2.slx` 是布局和网络 benchmark oracle；不要直接修改该标准模型，只从它派生新的目标模型。
2. 目标模型根层保留 NEBUS 风格的母线、线路、变压器、负荷和机组布局，不再复制 v0.8/v0.9 的额外 review、audit、source-index、component-guide 等子模块。
3. DFIG 来源继续使用 `power_wind_dfig_avg.slx/DFIG Wind Turbine`，只增加运行必须的风速、trip 和测量终端辅助块；这些辅助块不计入根层电气布局重叠审计。
4. 替换 SG 时必须删除原根层 `G4`-`G8` 块，并在 DFIG 块 `UserData` 中记录 `benchmark_machine_id`、`benchmark_bus`、`scenario_role` 和源 block。
5. 模型 `InitFcn` 必须加载 `NE39bus_dataV2.m`，并为 NEBUS/PSS 兼容性提供 `Tnum1_PSS`、`Tden1_PSS`、`Tnum2_PSS`、`Tden2_PSS`、`Twashout_PSS`、`Tw_PSS`、`Tsensor_PSS`、`Ts_PSS`、`K_PSS`、`Vmax_PSS`、`Vmin_PSS` 等别名。
6. 排版优先采用标准模型坐标；仅对替换后发生局部遮挡的 DFIG 块做确定性偏移，不使用全局自动排版破坏 SPS 电气连接语义。
7. 完成后必须生成报告并验证：`SimulationCommand update`、短时 `sim()` smoke、根层 DFIG 数量、剩余 G4-G8 数量、根层重叠数量。

本轮清理结论：

- 旧生成模型 `ieee39_sg5_dfig5_*_v06/v07/v08/v09.slx` 已从 `build/generated_models` 删除。
- 旧根目录 `ieee39_sg5_dfig5_*.slxc` 缓存已删除。
- 原始参考文件 `NEBUS39V2.slx`、`NE39bus_dataV2.m`、`power_KundurTwoAreaSystem.slx`、`power_wind_dfig_avg.slx` 保留。

当前验证结果：

```text
SimulationCommand update: PASS
sim() smoke run to 0.005 s: PASS
Root DFIG replacements found: 5
Remaining G4-G8 root SG blocks: 0
Root overlap count excluding DFIG signal auxiliaries: 0
```

## 22. 实验室仿真模型库与 simulink-modeling-assistant skill

2026-06-01 新增。从 `C:\Users\jonas\Desktop\实验室仿真模型汇总` 中的 8 个参考模型 (M01–M08) 抽取建模经验,沉淀为:

```text
docs/MODELING_PATTERN_LIBRARY.md
.agents/skills/simulink-modeling-assistant/
  SKILL.md
  references/
    pattern-rows.md
    layout-cookbook.md
    parameter-cheatsheet.md
```

主要规则:

1. 当用户提"换电源 / 换台数 / 改电压等级 / 改线路距离 / 加 PSS / 加一次调频"等小改动时,优先在 `MODELING_PATTERN_LIBRARY.md §8` 中找匹配行,直接套用 M01–M08 的现成参数和坐标,**不再从基本物理量重新推导**。
2. 实验室模型作为只读基准库,**任何派生工作只能写到** `simulink_agent_v1/build/` 下,不修改源 .slx / .m。
3. ai-in-loop 增加 `S0.5 PATTERN-MATCH` 阶段,命中后直接跳 S2 BUILD,在 `iter_<NN>/status.json` 写 `template_source` 字段(例: `M01 §2.4`)。
4. 失败签名字典扩展 FS-009 ~ FS-014 (DFIG 坐标系、VSG 端电压、LCC alpha 死锁、MMC 桥臂电流、50 Hz 振荡、2 Hz 振荡)。
5. 三相物理 SPS 连接仍禁止用 Goto/From 替代;Goto/From 仅限 `Utabc/Itabc/Inetabc/Unetabc/WindSpeed/Pref/Qref/Vref/Pe/wr` 等普通信号。

参考模型索引:

| ID | 模型 | 用途 |
|---|---|---|
| M01 | 4M2A_DFIG_csy 数学 | DFIG VSG/PLL 默认参数源 |
| M02 | 4M2A_DFIG_csy 物理 | M01 的 SPS 验证模型 |
| M03 | DFIG_math | 振荡分析专用,带 Co_* 系数 |
| M04 | 两机两区域 VSC | 小型 VSC 实验台 |
| M05 | 柔直四机两区 | MMC + 多电压等级 (291/230/20 kV) |
| M06 | LCC | CIGRE LCC HVDC 时步法 |
| M07 | SGbyhjq | NEBUS39 单机基准 (sub-transient) |
| M08 | VSCbyhjq | 三母线 VSC + 测量 Goto/From 范例 |
