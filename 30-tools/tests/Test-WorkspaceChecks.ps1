[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$runner = Join-Path $WorkspaceRoot '30-tools\scripts\Run-WorkspaceChecks.ps1'
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) { throw 'Run-WorkspaceChecks.ps1 is missing.' }
$outputPath = Join-Path $WorkspaceRoot ('90-tmp\workspace-checks-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.json')
try {
    $output = (& $runner -WorkspaceRoot $WorkspaceRoot -OutputPath $outputPath | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Workspace checks returned an unsafe state: $output" }
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { throw 'Workspace checks did not write its report.' }
    $report = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if ($report.schemaVersion -ne 1 -or $null -eq $report.checks) { throw 'Workspace checks report is incomplete.' }
    if (@($report.checks | Where-Object { $_.status -eq 'PASS' }).Count -eq 0) { throw 'Workspace checks reported no passing checks.' }
    Write-Output 'PASS: workspace checks aggregate evidence and distinguish warnings from blockers'
}
finally {
    if (Test-Path -LiteralPath $outputPath) { Remove-Item -LiteralPath $outputPath -Force }
}
