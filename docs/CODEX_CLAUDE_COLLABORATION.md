# Codex / Claude Code Collaboration Protocol

Purpose: keep the Simulink power-electronics skills library moving quickly
without wasting user tokens. This file is the shared operating contract between
Codex and Claude Code for `simulink_agent_v1`.

## 1. Role Split

Codex owns global review and repository hygiene:

- review Claude Code changes for bugs, boundary conditions, missing tests,
  stale artifacts, and unnecessary edits;
- periodically scan branches and upload/push GitHub state;
- review the whole skills library from the user's perspective;
- identify high-impact gaps for power-electronics dominated power-system
  modeling, especially cross-time-scale dynamics and renewable grid integration;
- compare the skills library against the desktop lab reference archive;
- maintain this collaboration protocol and memory handoff notes;
- keep the user-facing backlog concise and ordered by value.

Claude Code owns focused implementation:

- implement the next scoped optimization item on the integration branch;
- keep edits local to the relevant skill/script/doc surface;
- run the smallest meaningful MATLAB or static validation;
- leave a compact handoff packet for Codex review;
- avoid broad redesign unless this file or the user explicitly requests it;
- when Codex hands back review findings, fix only the necessary files for the
  critical issue. Do not refactor unrelated files before the issue is validated
  and ready to merge.

The user remains the decision owner for major research direction, global
installation, destructive Git operations, and changes to the read-only lab
reference archive.

## 2. Current Branch and Source of Truth

Use this branch unless the user says otherwise:

```text
integration/skills-maturation-2026-06
```

Read these first, in order:

1. `AGENTS.md`
2. `docs/CODEX_CLAUDE_COLLABORATION.md`
3. `.agents/skills/ai-in-loop/SKILL.md`
4. `docs/MODELING_WORKFLOW_DRAFT.md` only when doing workflow-driven model
   generation or modifying the modeling loop
5. The specific skill being changed under `.agents/skills/<skill>/SKILL.md`

Do not bulk-read every skill. Route narrowly.

## 3. Domain Target

Optimize the skills library for complex Simulink modeling of
power-electronics dominated power systems:

- converter-interfaced generation and renewable grid integration;
- DFIG, VSC, MMC, LCC/HVDC, SG plus converter hybrid systems;
- weak-grid SCR/ESCR sensitivity;
- PLL/GFL versus VSG/droop/GFM comparisons;
- cross-time-scale behavior from converter controls to electromechanical
  dynamics;
- small-signal/modal evidence paired with EMT/RMS time-domain evidence;
- handoff-ready IBR model validation evidence.

The target reference corpus is:

```text
C:\Users\jonas\Desktop\实验室仿真模型汇总
```

If the Chinese folder name is garbled in a terminal, discover it from
PowerShell by listing Desktop directories and matching the lab/reference model
archive by human inspection:

```powershell
Get-ChildItem $env:USERPROFILE\Desktop -Directory
```

Treat that folder as read-only. Use it for patterns, parameters, state names,
layout conventions, and validation scenarios; never edit, overwrite, or move
its files.

## 4. Current Integrated Capabilities

The integration branch already includes these project-local skills:

- `model-fidelity-selector`
- `small-signal-modal-analysis`
- `weak-grid-scr-scenario`
- `gfl-gfm-control-comparison`
- `ibr-model-validation-evidence`
- `baseline-regression`
- `multitimescale-analysis`
- `diagnostic-plotting`
- `sltest-harness-generation`
- `snapshot-auditor`

`ai_in_loop_run` now has automatic:

- S0.25 fidelity decision generation;
- S10C IBR validation evidence generation;
- snapshot copying of `latest_ibr_validation_evidence.md/json`;
- iteration-directory cleanup to avoid stale evidence false positives.

Recent local commits also added:

- optional S5B weak-grid SCR measured evidence via `weakgrid_scr`;
- optional S8B modal evidence via `modal_analysis`;
- `lab-model-pattern-miner` as a report-only drift detector for the read-only
  lab archive and the curated pattern library.

## 5. High-Value Backlog for Claude Code

Work in this order unless the user changes priorities.

### Completed, Do Not Rebuild: P1/P2

P1 weak-grid SCR loop evidence and P2 lab-model pattern mining are already
present in local commits on `integration/skills-maturation-2026-06`.

Claude Code should not reimplement those from scratch. Only make narrow fixes
if Codex identifies a bug in the current files:

- P1 files: `scripts/loop/ai_in_loop_stage_weakgrid_scr.m`,
  `scripts/loop/ai_in_loop_stage_modal.m`,
  `scripts/loop/ai_in_loop_run.m`, and S10C wiring.
- P2 files: `.agents/skills/lab-model-pattern-miner/` and
  `scripts/analysis/mine_lab_model_patterns.m`.

### P3: Impedance / Frequency-Domain Analysis

Goal: complement modal analysis with impedance and frequency-response evidence
for converter-grid interaction studies.

Expected implementation:

- create `impedance-frequency-analysis` skill;
- define input/output contracts for impedance curves, frequency response,
  resonance flags, and relation to time-domain validation;
- avoid overclaiming when only modal evidence exists.

Validation:

- helper-level smoke test with synthetic transfer function data;
- no full model sweep unless requested.

### P4: Stronger IBR Evidence Package

Goal: make `ibr-model-validation-evidence` more than a checklist by attaching
real same-iteration evidence when `goal='sltest'` or `goal='full'`.

Expected implementation:

- improve S10C to consume S6/S7/S7B artifacts when they exist;
- distinguish PASS, WARN, MISSING, and N/A exactly;
- include links to fidelity, weak-grid, modal, regression, and diagnostic
  artifacts.

Validation:

- run `goal='sltest'` when time/tooling allows;
- verify no stale artifacts are consumed.

## 6. Efficient Handoff Packet

After each Claude Code work chunk, write exactly one compact handoff packet.
This is mandatory before handing the task back to Codex:

```text
build/reports/agent_handoff/latest_claude_packet.md
```

`build/` is ignored by Git, so this is local communication, not repository
noise. Keep it under 120 lines.

Use this format:

```markdown
# Claude Code Handoff

Branch:
Commit(s):
Task:

Changed files:
- path

Validation:
- command/result

User-visible artifacts:
- path

Important findings:
- one-line finding

Known gaps / next step:
- one-line next step

Do not review:
- unrelated paths
```

If a change should persist for future agents, also update the appropriate
tracked doc or skill contract. Do not rely on the ignored handoff packet for
long-term project knowledge.

If Codex resumes and this packet is missing or stale, Codex should ask Claude
Code to provide it before reviewing anything broad. The packet should keep
Codex from spending tokens re-deriving what changed.

## 7. Codex Review Checklist

When Codex resumes after Claude Code:

1. Run `git status --short --branch`.
2. Read `build/reports/agent_handoff/latest_claude_packet.md` if present.
3. Inspect `git log --oneline --max-count=8`.
4. Inspect `git diff --name-status origin/integration/skills-maturation-2026-06..HEAD`
   or the relevant local diff.
5. Verify only touched areas necessary for the task.
6. Run or review the smallest validation evidence.
7. Push to GitHub if the branch is clean and the work is coherent.
8. Add an ad hoc memory note only when the user requested persistent handoff
   tracking or the completed work changes future-agent behavior.

## 8. Commit and Branch Rules

- Prefer staying on `integration/skills-maturation-2026-06` for skill-library
  maturation unless the user requests a separate branch.
- Commit focused changes with messages like:
  - `feat(loop): attach weak-grid matrix evidence`
  - `feat(skill): add lab model pattern miner`
  - `fix(loop): prevent stale evidence reuse`
- Do not commit `build/`, `.ctx/`, `slprj/`, or `.slxc` artifacts.
- Do not modify oracle models or lab archive models.
- Do not install/register project skills globally unless the user explicitly
  asks.

## 9. Token-Saving Rules

- Use `docs/TOKEN_BUDGET_AUDIT.md` as the project skill profile.
- Prefer this file over chat history.
- Prefer the latest handoff packet over reading long logs.
- Prefer `git diff --name-status` before opening files.
- Prefer narrow `SKILL.md` plus one reference file over reading whole skill
  trees.
- Use MATLAB helpers and generated reports instead of pasting long logs.
- Put detailed evidence under `build/reports/`; summarize only the decision in
  chat.
- Treat global non-modeling skills as disabled in this project unless the user
  explicitly asks for that capability. Do not load document, design, Notion,
  Slack/Gmail, skill-discovery, or broad refactor skills during normal Simulink
  review/implementation.
- Claude Code handback reminder: do not refactor files; modify only the
  necessary files for the current issue until Codex confirms the bug,
  boundary-case, and test evidence are handled.
- Claude Code must update `build/reports/agent_handoff/latest_claude_packet.md`
  after every completed work chunk before handing the branch back to Codex.
