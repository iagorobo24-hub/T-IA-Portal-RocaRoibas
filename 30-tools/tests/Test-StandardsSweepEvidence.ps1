[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
function Resolve-RecordedPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $candidate = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    # Archived evidence can retain the machine root it was produced under. Rebase only
    # paths under this workspace's durable 70-runs tree, never arbitrary locations.
    $normalized = $Path.Replace('/', '\')
    $marker = '\' + (Split-Path -Leaf $WorkspaceRoot) + '\70-runs\'
    $index = $normalized.LastIndexOf($marker, [StringComparison]::OrdinalIgnoreCase)
    if ($index -lt 0) { return $null }
    $rebased = Join-Path $WorkspaceRoot ('70-runs\' + $normalized.Substring($index + $marker.Length))
    if (Test-Path -LiteralPath $rebased) { return [IO.Path]::GetFullPath($rebased) }
    return $null
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $WorkspaceRoot '70-runs\standards\sweep-20260915-all\sweep-report.json'
}
if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "Standards sweep evidence is missing: $ReportPath"
}
$report = Get-Content -Raw -LiteralPath $ReportPath | ConvertFrom-Json
if ($report.readOnly -ne $true) { throw 'Standards sweep evidence is not marked read-only.' }
if ([int]$report.projectCount -ne 7) { throw "Expected 7 projects, got $($report.projectCount)." }
if ([int]$report.collectedCount -ne 7) { throw "Expected 7 collected projects, got $($report.collectedCount)." }
if ([int]$report.collectionErrorCount -ne 0) { throw "Collection errors: $($report.collectionErrorCount)." }
foreach ($project in @($report.projects)) {
    $inventoryPath = Resolve-RecordedPath ([string]$project.inventoryPath)
    if (-not $inventoryPath) {
        throw "Missing inventory for $($project.projectPath) (recorded: $($project.inventoryPath))."
    }
    $standardsPath = Resolve-RecordedPath ([string]$project.standardsPath)
    if (-not $standardsPath) {
        throw "Missing standards result for $($project.projectPath) (recorded: $($project.standardsPath))."
    }
}
Write-Output "PASS: standards sweep evidence covers $($report.projectCount) projects with no collection errors"
