param(
    [switch]$Apply,
    [switch]$ConfirmGlobalArchive,
    [string]$SkillRoot = "$env:USERPROFILE\.codex\skills",
    [string]$ArchiveRoot = "$env:USERPROFILE\.codex\archived_skills"
)

$ErrorActionPreference = "Stop"

$keep = @(
    ".system",
    "keep-codex-fast",
    "context-management",
    "gh-fix-ci",
    "gh-address-comments",
    "repomix-explorer",
    "andrej-karpathy-skills"
)

$candidateNames = @(
    "agent-deep-links",
    "brand-guidelines",
    "canvas-design",
    "changelog-generator",
    "code-simplifier",
    "codebase-migrate",
    "competitive-ads-extractor",
    "connect",
    "connect-apps",
    "content-research-writer",
    "create-plan",
    "datadog-logs",
    "deploy-pipeline",
    "developer-growth-analysis",
    "document-skills",
    "domain-name-brainstormer",
    "email-draft-polish",
    "file-organizer",
    "find-skill",
    "follow-builders",
    "helium-mcp",
    "image-enhancer",
    "internal-comms",
    "invoice-organizer",
    "issue-triage",
    "langsmith-fetch",
    "lead-research-assistant",
    "linear",
    "mcp-builder",
    "meeting-insights-analyzer",
    "meeting-notes-and-actions",
    "nature-citation",
    "nature-figure",
    "nature-polishing",
    "neat-freak",
    "notion-knowledge-capture",
    "notion-meeting-intelligence",
    "notion-research-documentation",
    "notion-spec-to-implementation",
    "paperjsx",
    "pr-review-ci-fix",
    "raffle-winner-picker",
    "sentry-triage",
    "skill-share",
    "slack-gif-creator",
    "spreadsheet-formula-helper",
    "support-ticket-triage",
    "tailored-resume-generator",
    "theme-factory",
    "video-downloader",
    "webapp-testing"
)

if (-not (Test-Path -LiteralPath $SkillRoot)) {
    throw "Skill root does not exist: $SkillRoot"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$archiveDir = Join-Path $ArchiveRoot "simulink_agent_v1_token_slim_$timestamp"
$existing = foreach ($name in $candidateNames) {
    $path = Join-Path $SkillRoot $name
    if ((Test-Path -LiteralPath $path) -and ($keep -notcontains $name)) {
        [pscustomobject]@{
            Name = $name
            Source = $path
            Destination = Join-Path $archiveDir $name
        }
    }
}

if (-not $existing) {
    Write-Host "No archive candidates found under $SkillRoot."
    exit 0
}

Write-Host "Archive candidates:"
$existing | Sort-Object Name | Format-Table -AutoSize

if (-not $Apply) {
    Write-Host ""
    Write-Host "Dry run only. Re-run with -Apply to move these skills into:"
    Write-Host "  $archiveDir"
    Write-Host ""
    Write-Host "Project policy: do not use -Apply for normal Simulink modeling optimization."
    Write-Host "Use docs/TOKEN_BUDGET_AUDIT.md to ignore unrelated skills project-locally instead."
    exit 0
}

if (-not $ConfirmGlobalArchive) {
    throw "Refusing global skill archive. Pass both -Apply and -ConfirmGlobalArchive only when the user explicitly wants global skills moved."
}

New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null

$manifestPath = Join-Path $archiveDir "manifest.csv"
$restorePath = Join-Path $archiveDir "restore_archived_skills.ps1"

$existing | Export-Csv -NoTypeInformation -Path $manifestPath

foreach ($item in $existing) {
    Move-Item -LiteralPath $item.Source -Destination $item.Destination
}

@'
param(
    [string]$ManifestPath = "$PSScriptRoot\manifest.csv"
)

$ErrorActionPreference = "Stop"
$items = Import-Csv -Path $ManifestPath
foreach ($item in $items) {
    if (Test-Path -LiteralPath $item.Destination) {
        Move-Item -LiteralPath $item.Destination -Destination $item.Source
    }
}
Write-Host "Restored archived skills from $ManifestPath"
'@ | Set-Content -Encoding UTF8 -Path $restorePath

Write-Host "Archived $($existing.Count) skills into $archiveDir"
Write-Host "Restore with: powershell -ExecutionPolicy Bypass -File `"$restorePath`""
