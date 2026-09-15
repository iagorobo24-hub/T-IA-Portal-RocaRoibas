[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..'))
)

$ErrorActionPreference = 'Stop'
$readme = Join-Path $WorkspaceRoot '30-tools\mcp\tia-inspect\README.md'
$errorCatalog = Join-Path $WorkspaceRoot '10-kb\50-errores\README.md'
$reportPath = Join-Path $WorkspaceRoot '70-runs\environment\latest.json'

if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) {
    throw "Missing tia-inspect README: $readme"
}
if (-not (Test-Path -LiteralPath $errorCatalog -PathType Leaf)) {
    throw "Missing error catalog: $errorCatalog"
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Missing environment report: $reportPath"
}

$report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
$readmeText = Get-Content -Raw -LiteralPath $readme
$errorCatalogText = Get-Content -Raw -LiteralPath $errorCatalog
$groupMembership = [bool]$report.opennessGroupMember

if ($groupMembership -and $readmeText -match "User in 'Siemens TIA Openness' user group: False") {
    throw 'tia-inspect README contradicts the current Doctor report: it says Openness group membership is False.'
}
if ((-not $groupMembership) -and $readmeText -notmatch "User in 'Siemens TIA Openness' user group: False") {
    throw 'tia-inspect README must report the current Openness group membership as False.'
}
if ($groupMembership -and $errorCatalogText -match 'Verificado en esta máquina — es el estado actual') {
    throw 'The error catalog still claims the Openness group is currently False.'
}

Write-Output 'PASS: documentation reflects current environment report'
