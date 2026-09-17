<#
.SYNOPSIS
    Informative check: warns when no eval run evidence exists under 00-meta/eval/runs/, or when
    the most recent one is older than -MaxAgeDays. Never blocks — see 00-meta/eval/README.md for
    why this cannot judge answer correctness by itself.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [int]$MaxAgeDays = 30
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$runsDir = Join-Path $WorkspaceRoot '00-meta\eval\runs'

if (-not (Test-Path -LiteralPath $runsDir -PathType Container)) {
    Write-Output "WARN: no eval run evidence found ($runsDir does not exist). See 00-meta/eval/README.md to run the protocol."
    exit 0
}

$latest = Get-ChildItem -LiteralPath $runsDir -Filter '*.md' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latest) {
    Write-Output "WARN: 00-meta/eval/runs/ exists but has no run files yet. See 00-meta/eval/README.md."
    exit 0
}

$ageDays = [math]::Round(((Get-Date) - $latest.LastWriteTime).TotalDays, 1)
if ($ageDays -gt $MaxAgeDays) {
    Write-Output "WARN: most recent eval run ($($latest.Name)) is $ageDays days old (limit $MaxAgeDays). Consider repeating the protocol."
    exit 0
}

Write-Output "OK: most recent eval run ($($latest.Name)) is $ageDays days old."
exit 0
