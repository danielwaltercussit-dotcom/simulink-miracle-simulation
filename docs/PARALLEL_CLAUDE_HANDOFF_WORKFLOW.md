# Parallel Claude Handoff Workflow

Use this workflow for every parallel E/F/M/D Claude Code conversation.

## Lifecycle

1. **Assign**
   - Codex writes a user-approved package target and explicit write scope.
   - Package name and branch name remain stable.

2. **Isolate**
   - Use a dedicated worktree:
     `C:\Users\jonas\Desktop\simulink_agent_v1__<package-slug>`.
   - Never perform parallel implementation in the primary review workspace.
   - Confirm branch and status before editing.

3. **Implement**
   - Read only `AGENTS.md`, the collaboration protocol, this workflow, the
     package plan, and directly relevant skill/contract files.
   - Keep tests and artifacts package-local.
   - Do not restore `NEBUS39V2.slx`.

4. **Validate**
   - Run `checkcode` for changed MATLAB files.
   - Run package-specific contract/smoke tests.
   - Re-read generated artifacts from disk.
   - If a model is created or changed, actually load/update/simulate it.
   - Separate contract consistency from model-backed or hardware-backed claims.

5. **Commit**
   - Stage only explicit package paths.
   - Commit on the assigned branch before handback.
   - Do not merge.

6. **Hand Back**
   - Write
     `build/reports/agent_handoff/<package_slug>_claude_packet.md`.
   - Keep the packet under 120 lines.
   - Include branch, commit, files, validation commands/results, artifact paths,
     PASS/WARN/MISSING states, known gaps, and intentionally untouched files.

7. **Codex Review**
   - Codex verifies branch ownership, reruns tests, checks status semantics, and
     decides repair/extend/merge.

## Mandatory Preflight

```powershell
git rev-parse --abbrev-ref HEAD
git status --short --branch --untracked-files=all
git log -1 --oneline --decorate
```

Stop if the active branch is not the assigned branch or sibling-package files
are present in the worktree.

## Mandatory Handback Checklist

- [ ] Dedicated worktree used.
- [ ] Assigned branch confirmed.
- [ ] Only package-owned files changed.
- [ ] `checkcode` run, or exact blocker recorded.
- [ ] Package tests run.
- [ ] Generated evidence re-read from disk.
- [ ] Contract-only, model-backed, and hardware-backed claims distinguished.
- [ ] Package commit created.
- [ ] Branch-specific packet updated and under 120 lines.
- [ ] No merge performed.
