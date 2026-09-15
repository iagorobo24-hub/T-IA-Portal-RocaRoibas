$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path $PSScriptRoot -Parent

$requiredPaths = @(
    'README-INSTALL.md',
    'install/Install-TIA-Claude.ps1',
    'install/Verify-TIA-Claude.ps1',
    'manifests/repositories.json',
    'workspace/AGENTS.md',
    'workspace/30-tools/mcp/tia-inspect/bin/v20/TiaMcpServer.exe'
)

$missing = @($requiredPaths | Where-Object { -not (Test-Path -LiteralPath (Join-Path $packageRoot $_)) })
if ($missing.Count -gt 0) {
    throw "Portable package is incomplete. Missing: $($missing -join ', ')"
}

Write-Output "PASS: portable package structure is complete"
