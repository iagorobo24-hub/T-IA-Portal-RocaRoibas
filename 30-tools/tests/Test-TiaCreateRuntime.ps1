[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$smoke = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolsSmoke.ps1'
$exe = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
$reportPath = Join-Path $WorkspaceRoot '70-runs\environment\tia-create-smoke.json'
foreach ($path in @($smoke, $exe)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing runtime smoke input: $path" }
}

$output = & $smoke -ExecutablePath $exe -Arguments '--tia-major-version 20 --profile lite --logging 1' -ExpectedTool @('FindTools', 'CallTool', 'Doctor', 'CreateProject', 'ScaffoldProject') -OutputPath $reportPath
if ($LASTEXITCODE -ne 0) { throw "tia-create runtime smoke failed: $output" }
$result = $output | Out-String | ConvertFrom-Json
if ($result.toolCount -lt 5) { throw "Expected multiple lite tools, got $($result.toolCount)." }
if (@($result.missingTools).Count -ne 0) { throw "Missing expected tools: $($result.missingTools -join ', ')" }
Write-Output "PASS: tia-create V20 MCP smoke ($($result.toolCount) lite tools)"
