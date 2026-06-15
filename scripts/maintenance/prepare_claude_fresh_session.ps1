[CmdletBinding()]
param(
    [ValidateSet("ModelingTest", "SkillsLibrary")]
    [string]$TaskKind = "ModelingTest",

    [Parameter(Mandatory = $true)]
    [string]$PackagePacket,

    [Parameter(Mandatory = $true)]
    [string]$WorkDirectory,

    [Parameter(Mandatory = $true)]
    [string]$Task,

    [string[]]$Context = @(),

    [string[]]$ReadFirst = @(),

    [string[]]$AllowedWritePaths = @(),

    [string[]]$Validation = @("Run the named validation and re-read its evidence."),

    [string[]]$ResultContract = @("Report final_state, verified facts, evidence, changed files, validation, and next decision."),

    [string[]]$StopCondition = @("Overwrite the package packet with HANDBACK and stop."),

    [string]$OutputPath = "build/reports/agent_handoff/next_claude_prompt.md",

    [string]$TextOutputPath = "build/reports/agent_handoff/next_claude_prompt.txt",

    [string]$LatestPointerPath = "build/reports/agent_handoff/latest_claude_packet.md",

    [string]$ReviewPath = "",

    [switch]$QuietExecutor,

    [switch]$CopyToClipboard
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Resolve-RepoPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
}

function Get-PointerDisplayPath([string]$Path) {
    $prefix = $repoRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if ($Path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($prefix.Length)
    }
    return $Path
}

function Format-Lines([string[]]$Items, [string]$EmptyText) {
    if ($Items.Count -eq 0) {
        return "- $EmptyText"
    }
    return ($Items | Select-Object -Unique | ForEach-Object { "- ``$_``" }) -join [Environment]::NewLine
}

function Format-TextLines([string[]]$Items, [string]$EmptyText) {
    $clean = @($Items | Where-Object { $_ -and $_.Trim().Length -gt 0 } | Select-Object -Unique)
    if ($clean.Count -eq 0) {
        return "- $EmptyText"
    }
    return ($clean | ForEach-Object { "- $_" }) -join [Environment]::NewLine
}

function Get-PacketField([string[]]$Lines, [string]$Name) {
    $match = $Lines | Where-Object { $_ -match "^\s*$([regex]::Escape($Name))\s*:\s*(.+?)\s*$" } |
        Select-Object -First 1
    if (-not $match) {
        throw "Package packet is missing required field '$Name'."
    }
    return ([regex]::Match($match, "^\s*$([regex]::Escape($Name))\s*:\s*(.+?)\s*$")).Groups[1].Value
}

function Assert-LineLimit([string]$Name, [string[]]$Value, [int]$Limit) {
    $count = @($Value | ForEach-Object { $_ -split "\r?\n" } |
        Where-Object { $_.Trim().Length -gt 0 }).Count
    if ($count -gt $Limit) {
        throw "$Name exceeds $Limit non-empty lines."
    }
}

$packetPath = Resolve-RepoPath $PackagePacket
$outputFullPath = Resolve-RepoPath $OutputPath
$textOutputFullPath = Resolve-RepoPath $TextOutputPath
$latestFullPath = Resolve-RepoPath $LatestPointerPath
$workFullPath = [System.IO.Path]::GetFullPath($WorkDirectory)

if (-not (Test-Path -LiteralPath $packetPath -PathType Leaf)) {
    throw "Package packet not found: $packetPath"
}
if (-not (Test-Path -LiteralPath $workFullPath -PathType Container)) {
    throw "Work directory not found: $workFullPath"
}
$packetLines = Get-Content -LiteralPath $packetPath
if ($packetLines.Count -gt 60) {
    throw "Package packet exceeds 60 lines; overwrite and compact it first: $packetPath"
}
$packageId = Get-PacketField $packetLines "id"
$packageState = Get-PacketField $packetLines "state"
if ($packageState -ne "READY") {
    throw "Package packet state must be READY before prompt generation; found '$packageState'."
}

$ReadFirst = @($ReadFirst | Where-Object { $_ } | Select-Object -Unique)
$AllowedWritePaths = @($AllowedWritePaths | Where-Object { $_ } | Select-Object -Unique)
if ($ReadFirst.Count -gt 3) {
    throw "ReadFirst exceeds the three-file handoff limit."
}
if ($QuietExecutor -and $ReadFirst.Count -ne 1) {
    throw "QuietExecutor requires exactly one compact startup read."
}
foreach ($path in $ReadFirst) {
    $evidencePath = if ([System.IO.Path]::IsPathRooted($path)) {
        [System.IO.Path]::GetFullPath($path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $workFullPath $path))
    }
    if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
        throw "Mandatory evidence file not found: $evidencePath"
    }
}
Assert-LineLimit "Task" $Task 8
Assert-LineLimit "Context" $Context 5
Assert-LineLimit "Validation" $Validation 5
Assert-LineLimit "ResultContract" $ResultContract 4
Assert-LineLimit "StopCondition" $StopCondition 4

$readLines = Format-Lines $ReadFirst "No mandatory reads; use the prompt context."
$writeLines = Format-Lines $AllowedWritePaths "No writes until the task proves one is required."
$contextLines = Format-TextLines $Context "No additional context."
$validationLines = Format-TextLines $Validation "Run the smallest meaningful validation and re-read evidence."
$resultLines = Format-TextLines $ResultContract "Write the required compact HANDBACK."
$stopLines = Format-TextLines $StopCondition "Overwrite the package packet with HANDBACK and stop."
$contract = if ($TaskKind -eq "ModelingTest") {
    "Use detached execution for runs over 60 seconds. Re-read evidence. Stop at failed gates; do not widen scope."
} else {
    "Keep contract, helper, test, and routing aligned. Run negative tests and checkcode. Do not widen scope."
}

$prompt = if ($QuietExecutor) {
@"
# QUIET EXECUTOR
package: $packageId
workdir: $workFullPath
handback: $packetPath
objective: $Task
read_only: $($ReadFirst -join ', ')
write_scope: $($AllowedWritePaths -join '; ')
gates: $($Validation -join ' | ')
stop: $($StopCondition -join ' | ')
result: $($ResultContract -join ' | ')
rules: read only this prompt then read_only; no old chat/repo scan/package read.
rules: client stream max 2 lines: one START, then one terminal BLOCKED or DONE.
rules: use targeted reads and compact output; never paste logs/diffs in chat.
rules: suggestions max 2, evidence-backed, disk handback only; Codex decides.
rules: complete all pre-approved gates in this long chunk; do not stop after small fixes.
rules: >60s run = prefer visible Background Task; BLOCKED if background unavailable.
rules: close terminal Background Task; never repeat an expensive failed run.
START format: START $packageId
BLOCKED format: BLOCKED <gate> <reason> <evidence-path>
DONE format: DONE <final_state> $packetPath
"@
} else {
@"
# Claude Work Chunk

kind: $TaskKind
package_id: $packageId
workdir: $workFullPath
handback_packet: $packetPath

## Objective
$Task

## Verified Context
$contextLines

## Mandatory Evidence Reads
$readLines

## Write Scope
$writeLines

## Execution Rule
$contract

## Validation
$validationLines

## Required Result
$resultLines

## Stop
$stopLines

Do not read old chats, the package packet, or repository-wide context at
startup. Overwrite the package packet with a compact HANDBACK under 60 lines.
"@
}

$outputDir = Split-Path -Parent $outputFullPath
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
Set-Content -LiteralPath $outputFullPath -Value $prompt -Encoding utf8
$textOutputDir = Split-Path -Parent $textOutputFullPath
New-Item -ItemType Directory -Force -Path $textOutputDir | Out-Null
Set-Content -LiteralPath $textOutputFullPath -Value $prompt -Encoding utf8

$promptLineLimit = if ($QuietExecutor) { 25 } else { 60 }
if ((Get-Content -LiteralPath $outputFullPath).Count -gt $promptLineLimit) {
    throw "Generated prompt exceeds $promptLineLimit lines; compact the task inputs."
}
if ((Get-Content -LiteralPath $textOutputFullPath).Count -gt $promptLineLimit) {
    throw "Generated text prompt exceeds $promptLineLimit lines; compact the task inputs."
}

$packetDisplay = Get-PointerDisplayPath $packetPath
$promptDisplay = Get-PointerDisplayPath $outputFullPath
$textPromptDisplay = Get-PointerDisplayPath $textOutputFullPath
$latest = @(
    "# Latest Handoff"
    "package: $packageId"
    "state: READY"
    "prompt: ``$promptDisplay``"
    "text_prompt: ``$textPromptDisplay``"
    "packet: ``$packetDisplay``"
)
if ($ReviewPath) {
    $latest += "review: ``$ReviewPath``"
}
if ($latest.Count -gt 8) {
    throw "Latest pointer exceeds 8 lines."
}
$latestDir = Split-Path -Parent $latestFullPath
New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
Set-Content -LiteralPath $latestFullPath -Value ($latest -join [Environment]::NewLine) -Encoding utf8

if ($CopyToClipboard) {
    Set-Clipboard -Value $prompt
}

Write-Output "Fresh-session prompt written: $outputFullPath"
Write-Output "Fresh-session text prompt written: $textOutputFullPath"
Write-Output "Latest pointer synchronized: $latestFullPath"
if ($CopyToClipboard) {
    Write-Output "Fresh-session prompt copied to clipboard."
}
