[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
$server = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
$outputPath = Join-Path $env:TEMP ('tia-claude-sequence-' + [guid]::NewGuid().ToString('N') + '.json')
try {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw 'Generic MCP sequence script is missing.' }
    if (-not (Test-Path -LiteralPath $server -PathType Leaf)) { throw 'tia-create V20 runtime is missing.' }
    $calls = @(
        @{ name = 'Bootstrap'; args = @{} },
        @{ name = 'Connect'; args = @{} },
        @{ name = 'GetState'; args = @{} },
        @{ name = 'Disconnect'; args = @{} }
    )
    & $scriptPath -ExecutablePath $server -Arguments '--tia-major-version 20 --profile lite' -Calls $calls -OutputPath $outputPath -TimeoutSeconds 120 | Out-Null
    $report = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if ($report.schemaVersion -ne 1 -or $report.calls.Count -ne 4) { throw 'MCP sequence report is incomplete.' }
    if (@($report.calls | Where-Object { $_.name -eq 'Bootstrap' -and $_.success }).Count -ne 1) { throw 'Bootstrap did not succeed.' }
    if (@($report.calls | Where-Object { $_.name -eq 'GetState' }).Count -ne 1) { throw 'GetState result is missing.' }
    Write-Output 'PASS: generic MCP sequence preserves one session and records every call'
}
finally {
    if (Test-Path -LiteralPath $outputPath) { Remove-Item -LiteralPath $outputPath -Force }
}
