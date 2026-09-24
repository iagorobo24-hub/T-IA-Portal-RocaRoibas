[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$FixtureRoot,
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
    if ([string]::IsNullOrWhiteSpace($FixtureRoot)) {
        throw '-RunLive requires -FixtureRoot for a manifested disposable V20 project.'
    }
    $fixtureRootFull = [IO.Path]::GetFullPath($FixtureRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $manifestValidator = Join-Path $WorkspaceRoot '30-tools\scripts\Assert-TiaFixtureManifest.ps1'
    $fixture = & $manifestValidator -FixtureRoot $fixtureRootFull

    $sequence = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
    $output = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-isolated-live-' + [guid]::NewGuid().ToString('N') + '.json')
    $calls = '[{"name":"Connect","args":{}},{"name":"GetState","args":{}},{"name":"Disconnect","args":{}}]'
    $escapedFixtureRoot = $fixtureRootFull.Replace('"', '\"')
    $serverArguments = "--tia-major-version 20 --isolated --fixture-root `"$escapedFixtureRoot`""
    try {
        & $sequence -ExecutablePath $binary -Arguments $serverArguments -CallsJson $calls -OutputPath $output -TimeoutSeconds 180 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Isolated live sequence failed with exit code $LASTEXITCODE." }
        $report = Get-Content -Raw -LiteralPath $output | ConvertFrom-Json
        if (-not $report.success) { throw 'Isolated live sequence did not report success.' }
        $connect = @($report.calls | Where-Object name -eq 'Connect' | Select-Object -Last 1)
        if (-not $connect.success) { throw 'Isolated Connect did not succeed.' }
        $stateCall = @($report.calls | Where-Object name -eq 'GetState' | Select-Object -Last 1)
        if (-not $stateCall.success) { throw 'Isolated GetState did not succeed.' }
        $state = [string]$stateCall.text | ConvertFrom-Json
        if ([string]$state.project -ne '-') { throw 'The live isolated smoke test unexpectedly opened a project.' }
        $disconnect = @($report.calls | Where-Object name -eq 'Disconnect' | Select-Object -Last 1)
        if (-not $disconnect.success) { throw 'Isolated Disconnect did not succeed.' }
        $fixtureAfter = & $manifestValidator -FixtureRoot $fixtureRootFull
        if ($fixtureAfter.projectSnapshotSha256 -ne $fixture.projectSnapshotSha256 -or
            $fixtureAfter.backupSnapshotSha256 -ne $fixture.backupSnapshotSha256) {
            throw 'The read-only isolated smoke test changed the fixture or backup snapshot.'
        }
        Write-Output 'PASS: isolated headless TIA session used the exact manifested fixture root, reported no project open, disconnected, and preserved fixture/backup hashes'
    }
    finally {
        if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
    }
}

Write-Output 'PASS: isolated TIA mode contract and V20 Doctor'
