[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-TiaWriteE2E.ps1'
$fixtureRoot = Join-Path $WorkspaceRoot '90-tmp\e2e\IOT2050_S7_CompleteProject_E2E_V20'

if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Expected E2E write runner does not exist: $scriptPath"
}
if (-not (Test-Path -LiteralPath $fixtureRoot -PathType Container)) {
    throw "Expected E2E fixture does not exist: $fixtureRoot"
}

$report = Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Filter report.json -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $report) {
    throw 'No E2E write report exists yet.'
}

$data = Get-Content -Raw -LiteralPath $report.FullName | ConvertFrom-Json
foreach ($property in @('backup', 'preview', 'import', 'compile', 'save', 'export')) {
    if (-not ($data.PSObject.Properties.Name -contains $property)) { throw "E2E report missing '$property'." }
}
if ($data.compile.errorCount -ne 0) { throw "E2E compile has $($data.compile.errorCount) error(s)." }
if (-not $data.save.success) { throw 'E2E save did not succeed.' }

Write-Output "PASS: MCP write E2E report ($($report.FullName))"
