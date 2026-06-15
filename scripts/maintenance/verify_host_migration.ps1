[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot
)

$ErrorActionPreference = "Stop"
$package = (Resolve-Path -LiteralPath $PackageRoot).Path
$manifestPath = Join-Path $package "migration_reports\payload_sha256.csv"
$requiredPath = Join-Path $package "migration_reports\required_paths.txt"

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing payload manifest: $manifestPath"
}

function Get-LongPath {
    param([string]$Path)
    if ($Path.StartsWith("\\?\")) {
        return $Path
    }
    return "\\?\$Path"
}

function Get-LongPathSha256 {
    param([string]$Path)
    $stream = [System.IO.File]::OpenRead((Get-LongPath -Path $Path))
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

$failures = [System.Collections.Generic.List[string]]::new()
$rows = Import-Csv -LiteralPath $manifestPath
foreach ($row in $rows) {
    $path = Join-Path $package $row.RelativePath
    $ioPath = Get-LongPath -Path $path
    if (-not [System.IO.File]::Exists($ioPath)) {
        $failures.Add("MISSING $($row.RelativePath)")
        continue
    }

    $file = [System.IO.FileInfo]::new($ioPath)
    if ([string]$file.Length -ne [string]$row.Length) {
        $failures.Add("SIZE $($row.RelativePath)")
        continue
    }

    $hash = Get-LongPathSha256 -Path $path
    if ($hash -ne $row.SHA256) {
        $failures.Add("HASH $($row.RelativePath)")
    }
}

if (Test-Path -LiteralPath $requiredPath) {
    foreach ($relative in Get-Content -LiteralPath $requiredPath) {
        if ($relative -and -not (Test-Path -LiteralPath (Join-Path $package $relative))) {
            $failures.Add("REQUIRED $relative")
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Migration verification failed with $($failures.Count) issue(s)."
}

Write-Host "PASS: verified $($rows.Count) payload files with zero mismatches."
Write-Host "Next: read MIGRATION_START_HERE.md before restoring or continuing work."
