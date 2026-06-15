# Host Migration Runbook

This project must be migrated as a verified workspace snapshot, not only as a
Git clone. GitHub does not currently contain all active branches, uncommitted
work, ignored evidence, `.ctx` checkpoint state, or the external DFIG test
workspace.

## What The Export Contains

- a complete copy of the primary project, including `.git`, submodules,
  ignored evidence, caches, and current uncommitted work;
- a `git bundle` containing all local refs as a second recovery path;
- the external `Claude_demo/ieee39_sg5_dfig5_skills_test` workspace;
- full snapshots of every secondary Git worktree, including ones reported clean
  by Git status, because old index stat caches can hide real byte differences;
- optional read-only reference archives used by the modeling workflow;
- source Git/worktree/environment reports and a SHA-256 payload manifest;
- restore and verification scripts plus a new-host start file.

Git credentials, MATLAB licenses, Codex account state, and global tool
installations are intentionally not copied. Configure those separately.

## Export On The Old Host

Close MATLAB, Simulink, Claude Code, and editors that may still be writing files.
Then run from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\maintenance\export_host_migration.ps1 `
  -DestinationRoot E:\SimulinkMigration `
  -IncludeReferenceArchives
```

Use an external drive, network share, or another folder outside the project.
Do not choose a destination inside `simulink_agent_v1`.

After the export completes:

```powershell
powershell -ExecutionPolicy Bypass -File E:\SimulinkMigration\<package>\verify_host_migration.ps1 `
  -PackageRoot E:\SimulinkMigration\<package>
```

Do not make further project changes after the final export. If changes are
made, create a new export.

## Restore On The New Host

Install Git, Git LFS, MATLAB R2024b, and the required MATLAB/Simulink products.
Copy the migration package to the new host, verify it, then run:

```powershell
powershell -ExecutionPolicy Bypass -File D:\Transfer\<package>\restore_host_migration.ps1 `
  -PackageRoot D:\Transfer\<package> `
  -DesktopRoot $env:USERPROFILE\Desktop
```

The restore script refuses to overwrite existing target folders. It restores
the primary repo, external DFIG workspace, optional reference archives, and all
registered secondary worktrees. Dirty secondary worktree snapshots are overlaid
after their branches are recreated.

After restoration, Git may expose modifications in a secondary worktree that
the old host reported as clean. Treat those as recovered real file differences,
not migration noise. Review them before any discard or cleanup.

If the new Desktop path differs from the old one, generated current-task files
will still contain old absolute paths. The new agent must repair only the active
handoff/checkpoint path references and regenerate the fresh-session prompt.

## New-Host Read Order

Start the new Codex conversation with:

```text
Read AGENTS.md and docs/MIGRATION_CURRENT_STATE.md first. Verify the restored
workspace against migration_reports before doing any implementation. Report the
active package, current decision, next action, dirty worktrees, and no-touch
boundaries. Do not simulate or write tuning parameters during takeover.
```

Then complete the acceptance list in `docs/MIGRATION_CURRENT_STATE.md`. Keep the
old host and the migration package unchanged until takeover acceptance passes.
