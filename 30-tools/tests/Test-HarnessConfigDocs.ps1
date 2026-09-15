[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$claudeDoc = Join-Path $WorkspaceRoot '30-tools\harnesses\claude-code.md'
$localManifest = Join-Path $WorkspaceRoot '30-tools\mcp\servers.local.json'
$mcpConfig = Join-Path $WorkspaceRoot '.mcp.json'
foreach ($path in @($claudeDoc, $localManifest, $mcpConfig)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Harness artifact is missing: $path" }
}
$config = Get-Content -Raw -LiteralPath $mcpConfig | ConvertFrom-Json
$server = $config.mcpServers.'tia-inspect'
if ($null -eq $server) { throw 'Claude Code config does not contain tia-inspect.' }
if (@($server.args) -contains '--allow-write') { throw 'Default Claude Code config must be read-only.' }
if (-not (Test-Path -LiteralPath ([string]$server.command) -PathType Leaf)) { throw 'Claude Code command does not exist.' }
Write-Output 'PASS: Claude Code read profile and cross-harness manifest are valid'
