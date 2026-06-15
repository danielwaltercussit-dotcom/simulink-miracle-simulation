# Host Migration Current State

Snapshot date: 2026-06-14

This file is the first project-state read on the new host. It records the
current scientific decision, active task, no-touch boundaries, and the files
that must survive the move. It is not a history log.

## Current Repository State

- Primary repo: `simulink_agent_v1`
- Active branch: `claude/dfig-grid-attach-lessons`
- Active commit at migration preparation: `0ee235d`
- Remote: `https://github.com/danielwaltercussit-dotcom/simulink-miracle-simulation.git`
- The primary worktree contains important modified, untracked, ignored
  `build/`, and ignored `.ctx/` files. A fresh clone is not a complete backup.
- `integration/skills-maturation-2026-06` is ahead of its remote and has
  additional uncommitted work. The remaining registered worktrees were
  reported clean by source Git status, but full snapshots are retained because
  old index stat caches can hide real byte differences.

## Active Scientific Task

- Active package: `TUNE-T1R.6`
- Accepted result: TUNE-T1R.5 bundle-integrity and success-flag gates passed.
- Current decision: `HOLD_PENDING_DISCRIMINATING_EVIDENCE`.
- Scientific blocker: the current T1 evidence does not establish causal
  controller ownership. Raw amplitude across different units and one selected
  bus are not sufficient for S6 authorization.
- Next action: execute the no-simulation TUNE-T1R.6 Q1-Q5 hardening chunk from
  `build/reports/agent_handoff/next_claude_prompt.txt`, then let Codex review
  the disk evidence.

## Hard Boundaries

- Do not launch the 24 s `t1base2` long baseline before T1R.6 Codex review and
  explicit user approval.
- Do not authorize S6 or write controller parameters, models, or oracle files.
- Device and plant physical parameters, ratings, and topology are immutable.
- Preserve all current modified and untracked files.
- Treat migrated lab/reference archives as read-only.

## Required Task-State Reads

Read these in order after migration:

1. `AGENTS.md`
2. `docs/MIGRATION_CURRENT_STATE.md`
3. `.ctx/checkpoint.md`
4. `build/reports/agent_handoff/latest_claude_packet.md`
5. `build/reports/agent_handoff/control_tuning_claude_packet.md`
6. `build/reports/agent_handoff/next_claude_prompt.txt`
7. The external T1R.6 evidence index named by the prompt.

The external T1R.6 workspace must be restored beside the project using this
relative Desktop layout:

```text
Desktop/
  simulink_agent_v1/
  Claude_demo/
    ieee39_sg5_dfig5_skills_test/
```

If the Windows username or Desktop path changes, old absolute paths in generated
handoff files are expected. The new-host agent must map the old Desktop prefix
to the new Desktop prefix, verify the target files exist, and regenerate the
fresh-session prompt before execution. Historical evidence must not be broadly
rewritten.

## Post-Migration Acceptance

Migration is accepted only after all of these are true:

1. `verify_host_migration.ps1` reports zero missing, changed, or unexpected
   required files.
2. The primary repo opens on `claude/dfig-grid-attach-lessons`, and its dirty
   state matches the exported status snapshot.
3. All local Git refs and full secondary worktree snapshots are restored.
   Additional modifications exposed after restore must be reviewed as recovered
   content, not discarded as migration noise.
4. The external DFIG workspace and T1R.6 evidence index are readable.
5. MATLAB R2024b and required products/licenses are installed, and
   `init_simulink_agent_project` completes.
6. The new agent reports the active package, current HOLD decision, next action,
   and hard boundaries correctly before doing work.
7. One bounded no-simulation validation or a verified blocker is completed
   before the old host is retired.

Do not delete or reformat the old host until the acceptance list passes.
