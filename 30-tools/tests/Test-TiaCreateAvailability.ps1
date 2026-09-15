[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $WorkspaceRoot '30-tools\mcp\servers.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'MCP manifest is missing.' }
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$definition = $manifest.servers.PSObject.Properties['tia-create'].Value
if ($null -eq $definition) { throw 'tia-create must have an explicit manifest entry, even when unavailable.' }
if ([string]$definition.status -eq 'not-installed') {
    $command = Join-Path $WorkspaceRoot ([string]$definition.commandRelative -replace '/', '\')
    if (Test-Path -LiteralPath $command -PathType Leaf) { throw 'tia-create is marked not-installed but its executable exists.' }
    Write-Output 'PASS: tia-create blocker is explicit and executable is absent'
    exit 0
}
if ([string]$definition.status -eq 'installed') {
    $command = Join-Path $WorkspaceRoot ([string]$definition.commandRelative -replace '/', '\')
    if (-not (Test-Path -LiteralPath $command -PathType Leaf)) { throw "tia-create is marked installed but is missing: $command" }
    Write-Output 'PASS: tia-create installed runtime is present'
    exit 0
}
throw "Unsupported tia-create status '$($definition.status)'. Use installed or not-installed."
