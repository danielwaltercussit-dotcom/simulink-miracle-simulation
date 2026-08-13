# Portable Skills Migration

Use this runbook to move the authoritative modeling skills and distilled
experience to another agent or host. This is not a workspace backup and does
not carry simulation state.

## Portable Boundary

The authoritative source is `.agents/skills` in the reviewed
`simulink_agent_v1` revision. Transfer only:

- `.agents/skills/`, including skill-local scripts, references, and assets;
- `AGENTS.md` and `CLAUDE.md`;
- the six project docs referenced by those instructions and skills;
- this runbook and `init_simulink_agent_project.m`.

Do not transfer models, tests, `build/`, `Claude_demo/`, `dif11_work/`,
`slprj/`, `.slxc`, handoff packets, raw run evidence, worktree snapshots, or
lab/reference archives. Keep `${LAB_MODEL_ARCHIVE}` external and read-only.

## Publish A Reviewed Revision

Before publishing, validate the source revision and review its diff. Push a
reviewed commit or tag to the project remote; do not publish a dirty worktree as
a migration payload.

## Sparse Checkout On A New Host

Replace `<repo-url>` and `<reviewed-ref>` with the approved remote and commit,
branch, or tag:

```powershell
git clone --filter=blob:none --no-checkout <repo-url> simulink_agent_portable
Set-Location simulink_agent_portable
git sparse-checkout init --no-cone
@'
/.agents/skills/
/AGENTS.md
/CLAUDE.md
/docs/CODEX_CLAUDE_COLLABORATION.md
/docs/CONTROL_FEEDBACK_POLARITY_GATE.md
/docs/CONTROL_TUNING_PRIORITY_AND_BOUNDARY.md
/docs/FRESH_SESSION_HANDOFF_TEMPLATES.md
/docs/HOST_MIGRATION_RUNBOOK.md
/docs/MODELING_PATTERN_LIBRARY.md
/docs/MODELING_WORKFLOW_DRAFT.md
/init_simulink_agent_project.m
'@ | git sparse-checkout set --stdin
git checkout <reviewed-ref>
```

This checkout is itself a usable project-local skills workspace. A consuming
project may copy `.agents/skills` from this reviewed checkout, but should not
copy run artifacts or model files with it.

## Validate The New Host

Run the dependency-free skill validator for every top-level skill, then run the
repository-local reference check:

```powershell
$validator = '.agents/skills/skill-creator/scripts/quick_validate.py'
$failed = @()
Get-ChildItem '.agents/skills' -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName 'SKILL.md')
} | ForEach-Object {
    & python $validator $_.FullName
    if ($LASTEXITCODE -ne 0) { $failed += $_.Name }
}
if ($failed.Count -gt 0) { throw "Skill validation failed: $($failed -join ', ')" }

python .agents/skills/simulink-power-electronics/scripts/validate_skill_structure.py --quiet
if ($LASTEXITCODE -ne 0) { throw 'Repository-local reference validation failed.' }
```

Also verify that no excluded payload slipped into the sparse checkout:

```powershell
$forbidden = @(Get-ChildItem -Recurse -File | Where-Object {
    $_.Extension -in @('.slx', '.mdl', '.slxc') -or
    $_.FullName -match '\\(build|tests|Claude_demo|dif11_work|slprj)\\'
})
if ($forbidden.Count -gt 0) { throw 'Non-portable simulation content found.' }
```

For periodic updates, check out the next reviewed revision and rerun these
checks. Distill new reusable lessons into existing skill references; retain the
original reports on the source host as provenance.
