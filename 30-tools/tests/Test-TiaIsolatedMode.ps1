[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch]$RunLive
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Join-Path $WorkspaceRoot '30-tools\mcp\tia-inspect\upstream\src\TiaMcpServer'
$patchPath = Join-Path $WorkspaceRoot '30-tools\mcp\tia-inspect\patches\0001-tia-agent-workspace.patch'
$binary = Join-Path $WorkspaceRoot '30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe'
foreach ($path in @(
    (Join-Path $sourceRoot 'CliOptions.cs'),
    (Join-Path $sourceRoot 'Program.cs'),
    (Join-Path $sourceRoot 'Siemens\Engineering.cs'),
    (Join-Path $sourceRoot 'Siemens\Portal.cs'),
    $patchPath,
    $binary
)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Isolated mode artifact is missing: $path" }
}

$sourceText = @(
    Get-Content -Raw -LiteralPath (Join-Path $sourceRoot 'CliOptions.cs')
    Get-Content -Raw -LiteralPath (Join-Path $sourceRoot 'Program.cs')
    Get-Content -Raw -LiteralPath (Join-Path $sourceRoot 'Siemens\Engineering.cs')
    Get-Content -Raw -LiteralPath (Join-Path $sourceRoot 'Siemens\Portal.cs')
    Get-Content -Raw -LiteralPath $patchPath
) -join "`n"
foreach ($required in @('--isolated', 'IsolatedPortal', 'WithoutUserInterface')) {
    if ($sourceText -notmatch [regex]::Escape($required)) { throw "Isolated mode contract is missing: $required" }
}

$doctorOutput = & $binary --tia-major-version 20 --doctor --isolated 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -or $doctorOutput -notmatch 'Active Version: V20') {
    throw "The isolated-capable V20 server did not pass Doctor: $doctorOutput"
}

if ($RunLive) {
    $sequence = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
    $output = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-isolated-live-' + [guid]::NewGuid().ToString('N') + '.json')
    $calls = '[{"name":"Connect","args":{}},{"name":"GetState","args":{}},{"name":"Disconnect","args":{}}]'
    try {
        & $sequence -ExecutablePath $binary -Arguments '--tia-major-version 20 --isolated' -CallsJson $calls -OutputPath $output -TimeoutSeconds 180 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Isolated live sequence failed with exit code $LASTEXITCODE." }
        $report = Get-Content -Raw -LiteralPath $output | ConvertFrom-Json
        if (-not $report.success) { throw 'Isolated live sequence did not report success.' }
        $connect = @($report.calls | Where-Object name -eq 'Connect' | Select-Object -Last 1)
        if (-not $connect.success) { throw 'Isolated Connect did not succeed.' }
        Write-Output 'PASS: isolated headless TIA session connected and disconnected without opening a project'
    }
    finally {
        if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
    }
}

Write-Output 'PASS: isolated TIA mode contract and V20 Doctor'
