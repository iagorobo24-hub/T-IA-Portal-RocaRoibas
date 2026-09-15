[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Sync-HarnessConfigs.ps1'
$tempRoot = Join-Path $env:TEMP ('tia-claude-sync-test-' + [guid]::NewGuid().ToString('N'))
$configPath = Join-Path $tempRoot '.mcp.json'

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Expected synchronizer does not exist: $scriptPath"
    }

    & $scriptPath -WorkspaceRoot $WorkspaceRoot -Profile read -OutputPath $configPath
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw "Synchronizer did not create $configPath"
    }

    $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
    $server = $config.mcpServers.'tia-inspect'
    if ($null -eq $server) { throw 'Generated config lacks tia-inspect.' }
    if (@($server.args) -contains '--allow-write') { throw 'Read config contains --allow-write.' }
    if (-not (Test-Path -LiteralPath ([string]$server.command) -PathType Leaf)) {
        throw "Generated MCP command does not exist: $($server.command)"
    }

    Write-Output 'PASS: harness config synchronization contract'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
