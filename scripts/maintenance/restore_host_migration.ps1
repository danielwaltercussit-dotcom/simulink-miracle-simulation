[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot,

    [Parameter(Mandatory = $true)]
    [string]$DesktopRoot
)

$ErrorActionPreference = "Stop"
$package = (Resolve-Path -LiteralPath $PackageRoot).Path
$desktop = (Resolve-Path -LiteralPath $DesktopRoot).Path
$payload = Join-Path $package "payload"
$projectSource = Join-Path $payload "simulink_agent_v1"
$projectTarget = Join-Path $desktop "simulink_agent_v1"
$worktreeReport = Join-Path $package "migration_reports\worktrees.json"
$junctionReport = Join-Path $package "migration_reports\junctions.json"

function Copy-Tree {
    param([string]$Source, [string]$Target)
    if (Test-Path -LiteralPath $Target) {
        throw "Refusing to overwrite existing target: $Target"
    }
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    & robocopy $Source $Target /E /COPY:DAT /DCOPY:DAT /R:2 /W:2 /XJ /NFL /NDL /NJH /NJS
    if ($LASTEXITCODE -gt 7) {
        throw "Robocopy failed with exit code $LASTEXITCODE while copying $Source"
    }
}

if (-not (Test-Path -LiteralPath $projectSource)) {
    throw "Missing project payload: $projectSource"
}

Copy-Tree -Source $projectSource -Target $projectTarget

if (Test-Path -LiteralPath $junctionReport) {
    $junctions = Get-Content -LiteralPath $junctionReport -Raw | ConvertFrom-Json
    foreach ($junction in $junctions) {
        $linkRelative = [string]$junction.LinkRelativePath
        $targetRelative = [string]$junction.TargetRelativePath
        $link = Join-Path $projectTarget $linkRelative
        $target = Join-Path $projectTarget $targetRelative
        if (Test-Path -LiteralPath $link) {
            throw "Refusing to replace an existing restored junction path: $link"
        }
        if (-not (Test-Path -LiteralPath $target -PathType Container)) {
            throw "Restored junction target is missing: $target"
        }
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    }
}

$externalSource = Join-Path $payload "Claude_demo\ieee39_sg5_dfig5_skills_test"
if (Test-Path -LiteralPath $externalSource) {
    $claudeDemo = Join-Path $desktop "Claude_demo"
    New-Item -ItemType Directory -Path $claudeDemo -Force | Out-Null
    Copy-Tree -Source $externalSource -Target (Join-Path $claudeDemo "ieee39_sg5_dfig5_skills_test")
}

$referencesSource = Join-Path $payload "reference_archives"
if (Test-Path -LiteralPath $referencesSource) {
    foreach ($directory in Get-ChildItem -LiteralPath $referencesSource -Directory) {
        Copy-Tree -Source $directory.FullName -Target (Join-Path $desktop $directory.Name)
    }
}

$copiedWorktreeMetadata = Join-Path $projectTarget ".git\worktrees"
if (Test-Path -LiteralPath $copiedWorktreeMetadata) {
    $resolvedMetadata = (Resolve-Path -LiteralPath $copiedWorktreeMetadata).Path
    $resolvedGit = (Resolve-Path -LiteralPath (Join-Path $projectTarget ".git")).Path
    if (-not $resolvedMetadata.StartsWith($resolvedGit + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove worktree metadata outside restored Git directory: $resolvedMetadata"
    }
    [System.IO.Directory]::Delete(("\\?\" + $resolvedMetadata), $true)
}

if (Test-Path -LiteralPath $worktreeReport) {
    $worktrees = Get-Content -LiteralPath $worktreeReport -Raw | ConvertFrom-Json
    foreach ($worktree in $worktrees) {
        if ($worktree.IsPrimary) {
            continue
        }

        $target = Join-Path $desktop $worktree.Name
        if (Test-Path -LiteralPath $target) {
            throw "Refusing to overwrite existing worktree target: $target"
        }

        & git -C $projectTarget worktree add $target $worktree.Branch
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to recreate worktree $($worktree.Branch) at $target"
        }

        if ($worktree.SnapshotRelativePath) {
            $snapshot = Join-Path $package $worktree.SnapshotRelativePath
            & robocopy $snapshot $target /E /COPY:DAT /DCOPY:DAT /R:2 /W:2 /XJ /NFL /NDL /NJH /NJS
            if ($LASTEXITCODE -gt 7) {
                throw "Failed to overlay dirty worktree snapshot: $snapshot"
            }
        }

        if ($worktree.IndexRelativePath) {
            $savedIndex = Join-Path $package $worktree.IndexRelativePath
            $targetIndex = (& git -C $target rev-parse --path-format=absolute --git-path index 2>&1) -join ""
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $savedIndex)) {
                throw "Failed to locate saved or restored worktree index for $($worktree.Name)"
            }
            Copy-Item -LiteralPath $savedIndex -Destination $targetIndex -Force
        }
    }
}

$notice = @"
Restore completed at $(Get-Date -Format o).
Primary project: $projectTarget

Read these files before continuing:
1. AGENTS.md
2. docs/MIGRATION_CURRENT_STATE.md
3. .ctx/checkpoint.md
4. build/reports/agent_handoff/latest_claude_packet.md

Old absolute Desktop paths may need scoped repair if the username changed.
Do not launch t1base2, authorize S6, or write tuning parameters during takeover.
"@
$noticeDirectory = Join-Path $projectTarget "build\reports\migration"
New-Item -ItemType Directory -Path $noticeDirectory -Force | Out-Null
$notice | Set-Content -LiteralPath (Join-Path $noticeDirectory "MIGRATION_RESTORE_NOTICE.txt") -Encoding UTF8

Write-Host "PASS: restored project and registered worktrees."
Write-Host "Read $projectTarget\docs\MIGRATION_CURRENT_STATE.md before continuing."
