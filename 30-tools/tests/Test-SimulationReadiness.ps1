[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Write-TiaSimulationReadiness.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw 'Simulation readiness report script is missing.'
}

$tempRoot = Join-Path $env:TEMP ('tia-claude-simulation-readiness-' + [guid]::NewGuid().ToString('N'))
$fixtureRoot = Join-Path $tempRoot 'workspace'
$environmentDir = Join-Path $fixtureRoot '70-runs\environment'
$outputPath = Join-Path $tempRoot 'readiness.json'
try {
    New-Item -ItemType Directory -Path $environmentDir -Force | Out-Null
    $environment = [ordered]@{
        tiaMajor = 20
        installedTia = @([ordered]@{ majorVersion = 20; engineeringExists = $true; portalExists = $true })
        mcpServers = @([ordered]@{ name = 'tia-inspect' }, [ordered]@{ name = 'tia-create' })
        plcsim = [ordered]@{ classicInstalled = $true; advancedInstalled = $true; advancedVersion = 'V6.0' }
        runtimeAdvanced = [ordered]@{
            installedEntries = @([ordered]@{ displayName = 'SIMATIC WinCC Runtime Advanced V17.0 UPD8'; displayVersion = 'V17.0 UPD8' })
            executable = [ordered]@{ productVersion = 'V17.0 HF8' }
        }
    }
    $environment | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $environmentDir 'latest.json') -Encoding UTF8

    & $scriptPath -WorkspaceRoot $fixtureRoot -OutputPath $outputPath -SkipLiveProcessCheck | Out-Null
    $report = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if ($report.readOnly -ne $true) { throw 'Read-only flag is missing.' }
    if ($report.gates.plcToolchainReady -ne $true) { throw 'PLC toolchain should be ready in the fixture.' }
    if ($report.gates.hmiRuntimeAdvancedV20Ready -ne $false) { throw 'V17 runtime must not pass the V20 HMI gate.' }
    if ($report.blockers -notcontains 'WinCC Runtime Advanced V20 compatible no está verificado') { throw 'Expected HMI compatibility blocker is missing.' }
    Write-Output 'PASS: simulation readiness report is deterministic and version-gated'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
