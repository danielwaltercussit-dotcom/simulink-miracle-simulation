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
- use planning/review skills, including GitHub-sourced planning skills when
  useful, as Codex-only planning aids without adding them to the modeling skill
  routing surface;
- maintain this collaboration protocol and memory handoff notes;
- keep the user-facing backlog concise and ordered by value.

Claude Code owns focused implementation:

- implement the next scoped optimization item on the integration branch;
- keep edits local to the relevant skill/script/doc surface;
- run the smallest meaningful MATLAB or static validation;
- leave a compact handoff packet for Codex review;
- use engineering creativity inside the stated user goal, evidence contract,
  and safety boundaries; Codex should point Claude Code to the target and
  constraints, not prescribe every implementation detail;
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

The handoff packet should be the live pointer for the next agent. If it is
fresh and specific, Claude Code should start there instead of scanning the whole
project. Codex is responsible for keeping that packet directional enough to
explain what changed, what was intentionally not changed, and what target
Claude should pursue next.

## 2.1 Planning-Only Skills

Codex may use planning and review skills for project planning, backlog
ordering, GitHub skill research, or global user-need analysis. These aids are
Codex-only unless the user explicitly promotes them into the project-local
modeling workflow.

Rules:

- Do not copy, install, or register planning-only skills into `.agents/skills`
  just because Codex used them for planning.
- Do not ask Claude Code to load planning-only skills while it is implementing
  or optimizing modeling skills.
- If Codex uses a GitHub-sourced planning skill or external planning framework,
  record the source and the planning insight in the handoff packet, not in the
  AI-in-loop modeling skill router.
- Planning skills may shape the backlog, acceptance criteria, and handoff
  format; they must not pollute the runtime modeling skill set.
- For this repo, the modeling default is this file plus the relevant
  project-local Simulink skills. Global non-modeling skills are ignored unless
  the user explicitly asks for them.

## 2.2 Human Approval Gate for Claude Plans

When Codex creates a new project-optimization plan for Claude Code, Codex must
show the plan to the user first and wait for confirmation before writing it into
`build/reports/agent_handoff/latest_claude_packet.md` as a Claude-directed
instruction.

Rules:

- Draft the plan for the user in chat first: objective, scope, candidate files,
  validation, risks, and where Claude Code may choose creatively.
- Treat the user's confirmation as a human inspection node before Claude Code
  receives the plan.
- Only after confirmation should Codex integrate the approved plan into the
  handoff packet.
- If the user changes priorities, update the plan and ask for confirmation
  again before changing Claude's next-task instructions.
- Codex may still update the handoff immediately for process rules, review
  findings, file deltas, or safety warnings that prevent Claude from undoing or
  re-scanning work.
- The handoff packet should record whether a Claude-directed plan is
  `draft_pending_user_approval`, `approved_by_user`, or `not_applicable`.

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

## 5.1 AI-in-Loop Pattern for Skill Optimization

When Claude Code optimizes the modeling skills library, it should use the
AI-in-loop idea as the work pattern, even when the task is skill/document/helper
work rather than a full Simulink model run.

Use this lightweight loop:

1. Define the study or user capability gap.
2. Select the target skill and read only its `SKILL.md` plus one needed
   contract/reference file.
3. State the expected artifact contract before changing code or docs.
4. Make a focused implementation change.
5. Run the smallest meaningful validation: static check, helper smoke test,
   synthetic evidence, or one fast MATLAB run when needed.
6. Re-read the generated artifact or changed contract from disk.
7. Update `build/reports/agent_handoff/latest_claude_packet.md` with changed
   files, validation, artifacts, known gaps, and the next iteration target.

The point is to preserve the closed-loop discipline: every skill improvement
must have a user-facing purpose, a contract, evidence, and a handoff. It should
not become a broad file scan or a vague skill rewrite.

## 5.2 Stable Task Package Names

Codex and Claude Code must keep task package names stable across handoffs. The
name is the durable handle for the work; do not rename it just because the
wording of the next step changes.

Use these current package names:

- `P3-A impedance-frequency-analysis contract hardening`
- `P3-B impedance helper persistent validation`
- `P4-A IBR frequency-domain evidence intake`
- `P5-A opt-in research evidence profile`
- `E1 EMT/switching-level converter modeling`
- `E2 detailed-average-dynamic-phasor model switching`
- `F1 analytic FHA and impedance derivation`
- `F2 multivariable control and cross-regulation tuning`
- `F3 perturbation and stability boundary scan`
- `M1 hybrid solver and multirate simulation`
- `M2 HIL readiness and real-time deployment prep`
- `D1 VSC/GFL-GFM support and evidence`
- `D2 MMC/HVDC support and evidence`
- `D3 storage/battery/BMS support and evidence`

Rules:

- Handoff packets should refer to these package names exactly.
- If a package splits, keep the prefix and append a suffix such as `P4-A.1`.
- If priorities change, mark the package `paused`, `blocked`, or `done`; do not
  invent a new name for the same work.
- Codex may plan several packages in parallel, but each package needs its own
  objective, file boundary, validation expectation, and current status.

## 5.3 Codex Validation Standard

Codex owns result validation after Claude Code work. Reviews should prefer
actual execution over trusting prose summaries.

Validation expectations:

- For MATLAB helper-only changes, run `checkcode`, run the helper smoke test,
  and re-read generated markdown/json/csv artifacts from disk.
- For model, loop, evidence-chain, or `.slx`-touching changes, run the smallest
  real model-level validation that is feasible: `ai_in_loop_run`, `sim`,
  compile/update, sltest/model-verification fallback, or a focused MATLAB
  script against the actual referenced model file.
- If a full model run is too slow or blocked, Codex must say exactly what was
  not run, why, and what smaller validation was run instead.
- Do not mark a result as verified from a handoff note alone. The handoff is an
  input to review, not evidence by itself.
- Always re-read generated artifacts from disk before accepting PASS claims, to
  avoid stale-artifact or hallucinated-result failures.

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
Plan approval:
- status: draft_pending_user_approval | approved_by_user | not_applicable
- user approval note:

Changed files:
- path

Codex review delta:
- created:
- modified:
- deleted:
- intentionally not touched:

Validation:
- command/result

User-visible artifacts:
- path

Important findings:
- one-line finding

What Codex did:
- concrete action

What Codex did not do:
- concrete non-action

Known gaps / next step:
- one-line next step

Implementation freedom:
- what Claude may decide creatively inside the target boundary

Do not review:
- unrelated paths
```

If a change should persist for future agents, also update the appropriate
tracked doc or skill contract. Do not rely on the ignored handoff packet for
long-term project knowledge.

If Codex resumes and this packet is missing or stale, Codex should ask Claude
Code to provide it before reviewing anything broad. The packet should keep
Codex from spending tokens re-deriving what changed.

When Codex performs a global review, it must update this packet with:

- the files it created, modified, or deleted;
- the files it observed as in-flight work and deliberately preserved;
- the decisions it made, the work it did not do, and the next planning target;
- whether Claude Code should repair, extend, or leave each changed area alone.

This prevents Claude Code from blindly restoring deleted files, undoing Codex
review edits, or re-scanning the whole repository to infer intent.

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
- Parallel Claude Code packages must use dedicated worktrees. The primary
  `simulink_agent_v1` working directory is the Codex review/staging workspace
  and must not be used by multiple Claude conversations that repeatedly switch
  branches.
- Use the stable worktree shape
  `C:\Users\jonas\Desktop\simulink_agent_v1__<package-slug>`.
- Before editing, Claude Code must record `git rev-parse --abbrev-ref HEAD` and
  `git status --short --branch` in its branch packet. If the branch changes
  unexpectedly, stop instead of continuing in the shared tree.
- A parallel package is not ready for Codex review until its owned files are
  committed on its assigned branch. Leaving all deliverables untracked in the
  primary worktree is an invalid handoff.
- Stage package files by explicit path. Never use `git add -A` or `git add .`
  while sibling-package files are visible.
- The branch-specific packet is the authoritative parallel-work record:
  `build/reports/agent_handoff/<package_slug>_claude_packet.md`. Keep it under
  120 lines. `latest_claude_packet.md` is only the compact global index.
- Commit focused changes with messages like:
  - `feat(loop): attach weak-grid matrix evidence`
  - `feat(skill): add lab model pattern miner`
  - `fix(loop): prevent stale evidence reuse`
- Do not commit `build/`, `.ctx/`, `slprj/`, or `.slxc` artifacts.
- Do not modify oracle models or lab archive models.
- Do not install/register project skills globally unless the user explicitly
  asks.

## 9. Token-Saving Rules

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
- In parallel work, Claude Code must update its branch-specific packet and may
  update `latest_claude_packet.md` only as a compact index entry. Do not append
  full package plans or test transcripts to the latest packet.
- Project-local skills to avoid by default during modeling/review:
  `skill-creator`, `code-simplifier`; `find-skill` and `document-skills` were
  removed from this project-local registry.
- Optional global skills remain installed for other tasks, but do not load
  document, design, Notion/Slack/Gmail, broad refactor, or skill discovery
  skills during normal Simulink work.
