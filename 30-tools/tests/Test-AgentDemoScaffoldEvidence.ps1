[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
if (-not $ReportPath) {
    $ReportPath = Join-Path $WorkspaceRoot '70-runs\e2e\agent-demo-scaffold-dryrun-run\scaffold-report.json'
}
if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) { throw "Scaffold evidence is missing: $ReportPath" }
$report = Get-Content -Raw -LiteralPath $ReportPath | ConvertFrom-Json
if ($report.success -ne $true -or $report.applied -ne $false) { throw 'Scaffold dry-run evidence is not a clean non-applied run.' }
if (-not (Test-Path -LiteralPath ([string]$report.dryRun.reportPath) -PathType Leaf)) { throw 'Nested dry-run report is missing.' }
$nested = Get-Content -Raw -LiteralPath ([string]$report.dryRun.reportPath) | ConvertFrom-Json
if ($nested.toolName -ne 'ScaffoldProject' -or $nested.toolResponseIsError -eq $true) { throw 'ScaffoldProject dry-run MCP call failed.' }
Write-Output 'PASS: agent-demo scaffold dry-run evidence is clean and created nothing'
