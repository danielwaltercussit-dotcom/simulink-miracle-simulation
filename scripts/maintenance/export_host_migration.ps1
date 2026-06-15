[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DestinationRoot,

    [switch]$IncludeReferenceArchives,

    [string]$PackageName = ("simulink_agent_v1_migration_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$destination = [System.IO.Path]::GetFullPath($DestinationRoot)
$package = Join-Path $destination $PackageName

function Test-IsWithin {
    param([string]$Child, [string]$Parent)
    $childFull = [System.IO.Path]::GetFullPath($Child).TrimEnd('\') + '\'
    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
    return $childFull.StartsWith($parentFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Copy-Tree {
    param(
        [string]$Source,
        [string]$Target,
        [string[]]$ExcludeFiles = @()
    )
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    $arguments = @($Source, $Target, "/E", "/COPY:DAT", "/DCOPY:DAT", "/R:2", "/W:2", "/XJ", "/NFL", "/NDL", "/NJH", "/NJS")
    if ($ExcludeFiles.Count -gt 0) {
        $arguments += "/XF"
        $arguments += $ExcludeFiles
    }
    & robocopy @arguments
    if ($LASTEXITCODE -gt 7) {
        throw "Robocopy failed with exit code $LASTEXITCODE while copying $Source"
    }
}

function Invoke-GitText {
    param([string]$WorkingDirectory, [string[]]$Arguments, [string]$OutputPath)
    $output = & git -C $WorkingDirectory @Arguments 2>&1
    $output | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git -C $WorkingDirectory $($Arguments -join ' ')"
    }
}

function Get-LongPathSha256 {
    param([string]$Path)
    $ioPath = if ($Path.StartsWith("\\?\")) { $Path } else { "\\?\$Path" }
    $stream = [System.IO.File]::OpenRead($ioPath)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([System.BitConverter]::ToString($sha.ComputeHash($stream))).Replace("-", "")
        } finally {
            $sha.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

if (Test-IsWithin -Child $package -Parent $projectRoot) {
    throw "Destination must be outside the project root: $projectRoot"
}
if (Test-Path -LiteralPath $package) {
    throw "Refusing to overwrite existing migration package: $package"
}

$payload = Join-Path $package "payload"
$reports = Join-Path $package "migration_reports"
$worktreeSnapshots = Join-Path $payload "worktree_snapshots"
$worktreeIndexes = Join-Path $reports "worktree_indexes"
New-Item -ItemType Directory -Path $payload, $reports, $worktreeSnapshots, $worktreeIndexes -Force | Out-Null

Write-Host "Capturing Git state and all local refs..."
Invoke-GitText -WorkingDirectory $projectRoot -Arguments @("status", "--short", "--branch", "--ignored") -OutputPath (Join-Path $reports "primary_git_status.txt")
Invoke-GitText -WorkingDirectory $projectRoot -Arguments @("branch", "-vv") -OutputPath (Join-Path $reports "branches.txt")
Invoke-GitText -WorkingDirectory $projectRoot -Arguments @("submodule", "status") -OutputPath (Join-Path $reports "submodules.txt")
Invoke-GitText -WorkingDirectory $projectRoot -Arguments @("remote", "-v") -OutputPath (Join-Path $reports "remotes.txt")
& git -C $projectRoot bundle create (Join-Path $reports "all_refs.bundle") --all
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create all-refs Git bundle."
}

$worktreeLines = & git -C $projectRoot worktree list --porcelain
$worktrees = [System.Collections.Generic.List[object]]::new()
$current = @{}
foreach ($line in @($worktreeLines) + "") {
    if (-not $line) {
        if ($current.worktree) {
            $path = [string]$current.worktree
            $name = Split-Path -Leaf $path
            $branch = if ($current.branch) { ([string]$current.branch) -replace "^refs/heads/", "" } else { "" }
            $status = (& git -C $path status --short 2>&1) -join "`n"
            $isPrimary = ([System.IO.Path]::GetFullPath($path).TrimEnd('\') -eq $projectRoot.TrimEnd('\'))
            $snapshotRelative = ""
            if (-not $isPrimary) {
                $snapshotRelative = "payload\worktree_snapshots\$name"
                Copy-Tree -Source $path -Target (Join-Path $package $snapshotRelative) -ExcludeFiles @(".git")
            }
            $sourceIndex = (& git -C $path rev-parse --path-format=absolute --git-path index 2>&1) -join ""
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $sourceIndex)) {
                throw "Could not locate worktree index for $path"
            }
            $indexRelative = "migration_reports\worktree_indexes\$name.index"
            Copy-Item -LiteralPath $sourceIndex -Destination (Join-Path $package $indexRelative)
            $worktrees.Add([pscustomobject]@{
                Name = $name
                OriginalPath = $path
                Branch = $branch
                Head = [string]$current.HEAD
                IsPrimary = $isPrimary
                Dirty = [bool]$status
                Status = $status
                SnapshotRelativePath = $snapshotRelative
                IndexRelativePath = $indexRelative
            })
        }
        $current = @{}
        continue
    }
    $parts = $line -split " ", 2
    $current[$parts[0]] = if ($parts.Count -gt 1) { $parts[1] } else { $true }
}
$worktrees | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $reports "worktrees.json") -Encoding UTF8

$junctions = foreach ($item in Get-ChildItem -LiteralPath $projectRoot -Recurse -Force -Attributes ReparsePoint -ErrorAction SilentlyContinue) {
    if ($item.LinkType -ne "Junction") {
        continue
    }
    $target = [string]$item.Target[0]
    if (-not (Test-IsWithin -Child $target -Parent $projectRoot)) {
        throw "Project junction points outside the project and requires manual migration review: $($item.FullName) -> $target"
    }
    [pscustomobject]@{
        LinkRelativePath = $item.FullName.Substring($projectRoot.Length + 1)
        TargetRelativePath = $target.Substring($projectRoot.Length + 1)
    }
}
@($junctions) | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $reports "junctions.json") -Encoding UTF8

$environment = [ordered]@{
    CapturedAt = (Get-Date -Format o)
    SourceProjectRoot = $projectRoot
    OS = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture
    PowerShell = $PSVersionTable.PSVersion.ToString()
    Git = (& git --version)
    GitLfs = (& git lfs version 2>$null)
    Matlab = Get-Command matlab -ErrorAction SilentlyContinue | Select-Object Source
}
$environment | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $reports "source_environment.json") -Encoding UTF8

Write-Host "Copying complete primary project..."
Copy-Tree -Source $projectRoot -Target (Join-Path $payload "simulink_agent_v1")

$externalWorkspace = Join-Path (Split-Path -Parent $projectRoot) "Claude_demo\ieee39_sg5_dfig5_skills_test"
if (Test-Path -LiteralPath $externalWorkspace) {
    Write-Host "Copying external DFIG task workspace..."
    Copy-Tree -Source $externalWorkspace -Target (Join-Path $payload "Claude_demo\ieee39_sg5_dfig5_skills_test")
} else {
    throw "Required external DFIG workspace is missing: $externalWorkspace"
}

if ($IncludeReferenceArchives) {
    $desktop = Split-Path -Parent $projectRoot
    $labSummaryName = -join ([char[]](0x5B9E, 0x9A8C, 0x5BA4, 0x4EFF, 0x771F, 0x6A21, 0x578B, 0x6C47, 0x603B))
    $dfigLabName = -join ([char[]](0x5B9E, 0x9A8C, 0x5BA4, 0x53CC, 0x9988, 0x98CE, 0x673A, 0x6A21, 0x578B))
    $referenceNames = @(
        "AI summary of simulation models",
        $labSummaryName,
        $dfigLabName
    )
    foreach ($name in $referenceNames) {
        $source = Join-Path $desktop $name
        if (Test-Path -LiteralPath $source) {
            Write-Host "Copying read-only reference archive: $name"
            Copy-Tree -Source $source -Target (Join-Path $payload "reference_archives\$name")
        }
    }
}

Copy-Item -LiteralPath (Join-Path $projectRoot "scripts\maintenance\verify_host_migration.ps1") -Destination (Join-Path $package "verify_host_migration.ps1")
Copy-Item -LiteralPath (Join-Path $projectRoot "scripts\maintenance\restore_host_migration.ps1") -Destination (Join-Path $package "restore_host_migration.ps1")

$startHere = @"
# Migration Start Here

Package created: $(Get-Date -Format o)
Source project: $projectRoot

1. Run verify_host_migration.ps1 -PackageRoot <this-folder>.
2. Read payload/simulink_agent_v1/docs/MIGRATION_CURRENT_STATE.md.
3. Restore with restore_host_migration.ps1 only after verification passes.
4. Keep the old host and this package unchanged until new-host acceptance passes.

Current active task: TUNE-T1R.6.
Current decision: HOLD_PENDING_DISCRIMINATING_EVIDENCE.
Do not run t1base2, authorize S6, or write tuning parameters during takeover.
"@
$startHere | Set-Content -LiteralPath (Join-Path $package "MIGRATION_START_HERE.md") -Encoding UTF8

$required = @(
    "MIGRATION_START_HERE.md",
    "restore_host_migration.ps1",
    "verify_host_migration.ps1",
    "migration_reports\all_refs.bundle",
    "migration_reports\primary_git_status.txt",
    "migration_reports\worktrees.json",
    "migration_reports\junctions.json",
    "payload\simulink_agent_v1\.git",
    "payload\simulink_agent_v1\.ctx\checkpoint.md",
    "payload\simulink_agent_v1\docs\MIGRATION_CURRENT_STATE.md",
    "payload\simulink_agent_v1\build\reports\agent_handoff\next_claude_prompt.txt",
    "payload\Claude_demo\ieee39_sg5_dfig5_skills_test\reports\control\t1r6_execution_index.md"
)
$required | Set-Content -LiteralPath (Join-Path $reports "required_paths.txt") -Encoding UTF8

Write-Host "Hashing payload and recovery artifacts..."
$hashRoots = @(
    (Join-Path $package "payload"),
    (Join-Path $package "migration_reports")
)
$hashRows = foreach ($root in $hashRoots) {
    if (Test-Path -LiteralPath $root -PathType Leaf) {
        $files = @(Get-Item -LiteralPath $root)
    } else {
        $files = Get-ChildItem -LiteralPath $root -Recurse -Force -File
    }
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($package.Length + 1)
        [pscustomobject]@{
            RelativePath = $relative
            Length = $file.Length
            SHA256 = Get-LongPathSha256 -Path $file.FullName
        }
    }
}
$hashRows | Export-Csv -LiteralPath (Join-Path $reports "payload_sha256.csv") -NoTypeInformation -Encoding UTF8

Write-Host "PASS: migration package created at $package"
Write-Host "Run: powershell -ExecutionPolicy Bypass -File `"$package\verify_host_migration.ps1`" -PackageRoot `"$package`""
