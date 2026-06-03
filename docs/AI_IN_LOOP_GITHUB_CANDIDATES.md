# GitHub Skill Candidates for AI-in-Loop

Generated: 2026-05-30. Updated 2026-06-01: 上一会话因 `github.com:443` 直连超时未能克隆,本会话改用 `https://gh-proxy.com/` 前缀通过 codeload 镜像完成克隆。所有候选仓已落地,见下方 ✅ 标记。

```powershell
cd C:\Users\jonas\Desktop\simulink_agent_v1
```

## Clone status (2026-06-01)

| # | Repo | 路径 | 状态 |
|---|---|---|---|
| 1 | matlab/skills (= matlab/agent-skills-playground) | `external/github/matlab-agent-skills-playground` | ✅ 已存在,新克隆与原副本同源,删除重复副本 |
| 2 | matlab/matlab-agentic-toolkit | `external/matlab-agentic-toolkit` | ✅ 新增,含 `skills-catalog/` 12 个领域子目录 |
| 3 | mathworks/Continuous-Integration-Verification-Simulink-Models | `external/github/mathworks-ci-verify` | ✅ 新增 |
| 4 | obra/superpowers | `external/github/obra-superpowers` | ✅ 新增 |
| 5 | matlab-actions/run-tests | `external/github/matlab-actions-run-tests` | ✅ 新增 |

镜像命令模板(本会话采用):

```bash
git clone --depth 1 https://gh-proxy.com/https://github.com/<owner>/<repo> external/github/<dir>
```

## Recommended (clone these first)

### 1. matlab/skills

Official MathWorks Agent Skills collection for MATLAB. Complements the project's existing `simulink-agentic-toolkit` and `simulink/skills` (Simulink-specific subset).

```powershell
git clone https://github.com/matlab/skills external\github\matlab-skills
```

After cloning, list the skills inside `matlab-skills/` and selectively junction the relevant ones into `.agents/skills/`. Likely candidates: anything covering MATLAB scripting, debugging, performance, plotting, or test running that the loop's S6/S7 stages can call.

### 2. matlab/matlab-agentic-toolkit

MathWorks toolkit that wraps a shared MATLAB session with an MCP server. Today the project initializes only the Simulink toolkit (`satk_initialize`); adding this exposes general MATLAB execution to the agent without giving up the Simulink-specific scopes.

```powershell
git clone https://github.com/matlab/matlab-agentic-toolkit external\matlab-agentic-toolkit
```

After cloning, decide whether `init_simulink_agent_project.m` should also `matlab_agentic_initialize` or whether it stays Simulink-only. Default: keep them separate; AI-in-loop S6/S8 may call MATLAB Toolkit scripts via path, not via mandatory init.

### 3. mathworks/Continuous-Integration-Verification-Simulink-Models

Reference patterns for Simulink CI: model advisor, structural checks, sltest, coverage. Useful as a template for S7 expansion.

```powershell
git clone https://github.com/mathworks/Continuous-Integration-Verification-Simulink-Models external\github\mathworks-ci-verify
```

Treat as a reference repo; do not auto-import any of its scripts. Cherry-pick model-advisor and sltest patterns into `tests/` as needed.

## Optional

### 4. obra/superpowers

Generic Claude Code skill router and meta-orchestrator. The project's
`simulink-power-electronics/SKILL.md` already references a `superpowers` or
similarly-named local skill. Install if you want a cross-skill orchestrator at
the agent layer rather than (or in addition to) the MATLAB-side `ai-in-loop`
loop.

```powershell
git clone https://github.com/obra/superpowers external\github\obra-superpowers
```

If installed, copy its core SKILL.md into `.agents/skills/superpowers/` only
after reviewing — do not register globally.

### 5. matlab-actions/run-tests

GitHub Action for running MATLAB unit + Simulink Test runs in CI. Useful only
once the project moves to a CI runner with a MATLAB license. Reference, not for
local install.

```powershell
git clone https://github.com/matlab-actions/run-tests external\github\matlab-actions-run-tests
```

## Already cloned

For reference, the project already has under `external/github/`:

- `simulink-skills-upstream` (Guy on Simulink skills mirror)
- `McSCert-Auto-Layout`, `McSCert-Simulink-Utility`
- `pwrsys-matlab` (efantnu)
- `Simscape_Electrical_Support_Library` (R2025b+, kept as reference only on R2024b)
- `huanhyougo-matlab-power-electronics-skill` (parked, encoding issues)
- `matlab-agent-skills-playground`
- `npuzsy-simulink-power-electronics`

## Wiring after clone

After any of the above is cloned:

1. Read its `LICENSE` and verify it permits local reuse.
2. For each skill you want active, mklink (NTFS junction) the inner skill folder
   into `.agents/skills/<skill-name>` using the same pattern already used for
   `simulink-auto-layout-github`. Example:
   ```powershell
   mklink /J ".agents\skills\matlab-debug" "external\github\matlab-skills\debug"
   ```
3. Update `init_simulink_agent_project.m` only if a skill ships MATLAB code that
   needs to be on path. Most skill content is documentation; do not add to path
   reflexively.
4. Add a one-line note to Section 19 of `docs/MODELING_WORKFLOW_DRAFT.md`
   recording the new GitHub source.
5. Run `ai_in_loop_run('goal','smoke','max_iter',1)` to confirm nothing on path
   broke.

## What was deliberately not picked

- Reinforcement-learning Simulink demos (`mdehghani86/...`,
  `cea-wismar/...`, `yoriyuki-aist/Falsify`): out of scope for the current
  rule-based S6 stage. Revisit only if `ai_in_loop_run('goal','tune')` plateaus
  on rule-based fixes.
- Generic skill-router repos (`hussi9/skill-router`, `mashroecom/...`,
  community Claude Code orchestrator kits): the in-project AI-in-loop driver
  already covers stage routing; an external router is redundant unless you also
  use Claude Code on unrelated projects.
- `subspace-lab/matlab-skills`, `rrmaram2000/matlab-toolbox-skills`: smaller
  community variants of `matlab/skills`. Pick only after auditing.
