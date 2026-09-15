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

    $createConfigPath = Join-Path $tempRoot 'create.json'
    & pwsh -NoProfile -NonInteractive -File $scriptPath -WorkspaceRoot $WorkspaceRoot -Profile create -OutputPath $createConfigPath 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Create profile was generated without explicit acknowledgement.' }
    & $scriptPath -WorkspaceRoot $WorkspaceRoot -Profile create -AcknowledgeWriteProfile -OutputPath $createConfigPath
    if ($LASTEXITCODE -ne 0) { throw 'Create profile failed with explicit acknowledgement.' }
    $createConfig = Get-Content -Raw -LiteralPath $createConfigPath | ConvertFrom-Json
    $createServer = $createConfig.mcpServers.'tia-create'
    if ($null -eq $createServer) { throw 'Generated create config lacks tia-create.' }
    if (@($createServer.args) -notcontains '--profile') { throw 'Create config must pin the lite profile.' }

    Write-Output 'PASS: harness config synchronization contract'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
