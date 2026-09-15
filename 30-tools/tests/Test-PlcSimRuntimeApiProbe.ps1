[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$project = Join-Path $WorkspaceRoot '30-tools\plcsim\TiaClaude.PlcSimProbe.csproj'
if (-not (Test-Path -LiteralPath $project -PathType Leaf)) { throw 'PLCSIM API probe project is missing.' }
$output = & dotnet run --project $project -- --json --manager-count 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "PLCSIM API probe failed: $output" }
$report = $output | ConvertFrom-Json
if ($report.status -ne 'initialized' -or $report.success -ne $true) { throw "PLCSIM API probe did not initialize: $output" }
if ($null -eq $report.managerInstanceCount -or [int64]$report.managerInstanceCount -lt 0) { throw "PLCSIM manager instance count is invalid: $output" }
Write-Output 'PASS: PLCSIM Advanced V6 runtime API initializes and releases safely'
