# External Pattern Notes (2026-06-01)

记录从 2026-06-01 新克隆的外部仓里挑出来、对 ai-in-loop 真正有用的模式。源仓只读,**不要**把它们的脚本直接拷进项目;按下文要点在项目自己的 `scripts/loop/` 内重写或扩展。

## 来源 1: `external/github/mathworks-ci-verify` (LaneFollowing CI 示例)

域不对(ADAS,不是电力系统),但 CI 流程组织值得借鉴:

- `Scripts/LaneFollowingExecModelAdvisor.m` — Model Advisor 批量运行 + 报告生成模板。
  对应 ai-in-loop 的 **S7 扩展**:把"Model Advisor 静态检查"作为 sltest 之外的另一道独立检查门,失败也单独写 `model_advisor_summary.md`,不要混进 sltest 报告。
- `Tests/LaneFollowingTestScenarios.mldatx/.slmx` — Test Manager 工程组织方式。
  对应 **S7 内部组织**:测试用例资源用 `.mldatx` 集中管理,不要散在 `.m` 里;每个 case 单独评估、单独导出 JUnit XML。
- `SltestLaneFollowingExample.prj` — Simulink Project 入口约定。
  对应 **S0 选项**:目前我们没用 SLProj,如果以后用,沿用这种"一个 .prj 拉起整个 CI 上下文"的模式。

不抄的部分:`createLaneFollowingController.m`、`helperLFSetUp.m`、ADAS 数据集 — 都是 ADAS 域,与电力系统无关。

## 来源 2: `external/github/obra-superpowers` (跨 skill 编排器)

不装载 superpowers 本身(它会拦截 brainstorming/writing-skills 等通用 hook,与项目本地 skill 路由冲突),但提取若干通用规则到 ai-in-loop:

- `skills/verification-before-completion` — 已写入 SKILL.md "Verification Before Completion (S9 contract)" 一节。
  核心规则:**任何"完成"判定必须从磁盘 re-read,不靠内存状态**。S9 必须重读 `status.json`。
- `skills/systematic-debugging` — 强化 [[FS-007]]:每轮迭代只允许一个根因假设;同一签名 + 同一修复连续两次出现就停止。
- `skills/test-driven-development` — 借鉴顺序:先写最小 sltest harness 再改模型(对应"先扩 S7 用例,再回 S2 改实现")。
- `skills/dispatching-parallel-agents` — **暂不采用**:本项目串行 9 阶段足够,并行化收益不及增加的状态合并复杂度。

## 来源 3: `external/matlab-agentic-toolkit/skills-catalog` (官方 MATLAB skill 集)

已 mklink 进 `.agents/skills/` 的 3 个:

- `matlab-write-performance-tests` — 用于给 `scripts/loop/` 的 stage 函数加 `matlab.perftest` 回归测试(防止重构 ai_in_loop_run 后变慢)。S7 fallback。
- `matlab-optimize-performance` — 当某次 `tune` 阶段耗时异常增长时由 S6/S8 触发。
- `matlab-modernize-code` — 备用,主路径仍用 project-local `code-simplifier`。

未 link 的领域(`automotive`, `image-processing-and-computer-vision`, `wireless-communications`, `rf-and-mixed-signal`, `robotics-and-autonomous-systems` 等):与电力系统无关,放在 catalog 里按需查阅,不注册。

## 不纳入

- `external/github/matlab-actions-run-tests` — GitHub Action,本地 MATLAB 调用无意义;只作为 `runtests` / `sltest.testmanager` 调用形状的参考。
- `external/github/matlab-agent-skills-playground` (= 远端 `matlab/skills`) — sandbox,内容覆盖率低于 `matlab-agentic-toolkit/skills-catalog`,继续参考但不 link。

## 同步约定

每次 `external/` 子仓 `git pull` 后:

1. 重读本文件并确认引用的脚本路径仍然存在。
2. 如果 mklink 目标移动或重命名,先重做 junction,再更新本文件。
3. 改动登记在 `MODELING_WORKFLOW_DRAFT.md` Section 19 里。
