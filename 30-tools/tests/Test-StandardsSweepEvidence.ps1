[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
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
    if (-not $project.inventoryPath -or -not (Test-Path -LiteralPath $project.inventoryPath -PathType Leaf)) {
        throw "Missing inventory for $($project.projectPath)."
    }
    if (-not $project.standardsPath -or -not (Test-Path -LiteralPath $project.standardsPath -PathType Leaf)) {
        throw "Missing standards result for $($project.projectPath)."
    }
}
Write-Output "PASS: standards sweep evidence covers $($report.projectCount) projects with no collection errors"
