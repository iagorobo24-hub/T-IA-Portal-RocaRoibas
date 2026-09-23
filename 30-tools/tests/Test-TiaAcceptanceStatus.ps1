[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Write-TiaAcceptanceStatus.ps1'
$tempPath = Join-Path $env:TEMP ('tia-claude-acceptance-' + [guid]::NewGuid().ToString('N') + '.json')
$negativeEvidencePath = Join-Path $env:TEMP ('tia-claude-acceptance-negative-' + [guid]::NewGuid().ToString('N') + '.json')
$negativeOutputPath = Join-Path $env:TEMP ('tia-claude-acceptance-negative-result-' + [guid]::NewGuid().ToString('N') + '.json')
try {
    & $scriptPath -WorkspaceRoot $WorkspaceRoot -OutputPath $tempPath | Out-Null
    $report = Get-Content -Raw -LiteralPath $tempPath | ConvertFrom-Json
    if ($null -eq $report.verified -or $report.verified.Count -lt 3) { throw 'Acceptance status did not record verified evidence.' }
    if ($report.notVerified.Count -lt 2) { throw 'Acceptance status must preserve incomplete runtime claims.' }
    if ($report.accepted -eq $true) { throw 'Acceptance must remain false before live scaffold/simulation evidence.' }
    if (-not $report.evidence.simulationReadiness) { throw 'Acceptance status must reference the simulation readiness preflight.' }
    if ($report.verified -notcontains 'portable core installation and relocation') {
        throw 'Acceptance status must include the portable installation evidence.'
    }
    if ($report.verified -notcontains 'tia-create MCP startup and lite tool roster') {
        throw 'Acceptance status must include the tia-create smoke evidence.'
    }
    if ($report.notVerified -notcontains 'comportamiento funcional PLC probado en PLCSIM') {
        throw 'Acceptance status must preserve the missing PLCSIM behavior evidence.'
    }
    if ($null -eq $report.computerUse -or $report.computerUse.status -eq 'not_verified') {
        throw 'Acceptance status must expose native Computer Use evidence separately.'
    }
    if ($report.computerUse.safetyBoundary.status -ne 'verified') {
        throw 'Computer Use safety boundary must remain verified in acceptance output.'
    }
    if ($null -eq $report.evidence.computerUse -or $report.evidence.computerUse.Count -lt 1) {
        throw 'Acceptance status must reference the Computer Use evidence files.'
    }
    $tagLifecycleFinding = 'MCP tag lifecycle: create/update/export/compile/save/delete + independent readback'
    if ($report.verified -notcontains $tagLifecycleFinding) {
        throw 'Acceptance status must include the verified MCP tag lifecycle finding.'
    }
    if ($null -eq $report.evidence.tagLifecycle -or $report.evidence.tagLifecycle.status -ne 'verified') {
        throw 'Acceptance status must expose verified MCP tag lifecycle evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.tagLifecycle.path) -or
        [string]$report.evidence.tagLifecycle.path -notmatch '(?i)mcp-tag-lifecycle-.*\.json$') {
        throw 'Acceptance status must reference the mcp-tag-lifecycle evidence file.'
    }
    $watchLifecycleFinding = 'MCP watch table lifecycle: create/export/compile/save/delete + independent readback'
    if ($report.verified -notcontains $watchLifecycleFinding) {
        throw 'Acceptance status must include the verified MCP watch-table lifecycle finding.'
    }
    if ($null -eq $report.evidence.watchLifecycle -or $report.evidence.watchLifecycle.status -ne 'verified') {
        throw 'Acceptance status must expose verified MCP watch-table lifecycle evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.watchLifecycle.path) -or
        [string]$report.evidence.watchLifecycle.path -notmatch '(?i)mcp-watch-acceptance-.*\.json$') {
        throw 'Acceptance status must reference the mcp-watch-acceptance evidence file.'
    }

    $instanceDbLifecycleFinding = 'MCP Instance DB lifecycle: create/compile/export/save/references/delete + independent readback'
    if ($report.verified -notcontains $instanceDbLifecycleFinding) {
        throw 'Acceptance status must include the verified MCP Instance DB lifecycle finding.'
    }
    if ($null -eq $report.evidence.instanceDbLifecycle -or $report.evidence.instanceDbLifecycle.status -ne 'verified') {
        throw 'Acceptance status must expose verified MCP Instance DB lifecycle evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.instanceDbLifecycle.path) -or
        $report.evidence.instanceDbLifecycle.path -notmatch '(?i)mcp-instancedb-acceptance-.*\.json$') {
        throw 'Acceptance status must reference the mcp-instancedb-acceptance evidence file.'
    }
    $tagTableLifecycleFinding = 'MCP PLC tag table lifecycle: create/export/compile/save/delete + independent readback'
    if ($report.verified -notcontains $tagTableLifecycleFinding) {
        throw 'Acceptance status must include the verified MCP PLC tag-table lifecycle finding.'
    }
    if ($null -eq $report.evidence.tagTableLifecycle -or $report.evidence.tagTableLifecycle.status -ne 'verified') {
        throw 'Acceptance status must expose verified MCP PLC tag-table lifecycle evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.tagTableLifecycle.path) -or
        $report.evidence.tagTableLifecycle.path -notmatch '(?i)mcp-tagtable-acceptance-.*\.json$') {
        throw 'Acceptance status must reference the mcp-tagtable-acceptance evidence file.'
    }

    # A window id and version alone cannot establish a native target or the
    # physical/Safety boundary. Keep this regression probe deliberately sparse
    # so a future parser change cannot turn metadata into a false PASS.
    '{"harness":"native @oai/sky Computer Use","tiaMajorVersion":20,"windowId":123,"windowSelection":"yes","safetyAndHardware":{}}' |
        Set-Content -LiteralPath $negativeEvidencePath -Encoding UTF8
    & $scriptPath -WorkspaceRoot $WorkspaceRoot -OutputPath $negativeOutputPath -ComputerUseEvidencePaths $negativeEvidencePath | Out-Null
    $negative = Get-Content -Raw -LiteralPath $negativeOutputPath | ConvertFrom-Json
    if ($negative.computerUse.nativeWindowInventory.status -eq 'verified') {
        throw 'Sparse Computer Use evidence must not verify a native TIA window.'
    }
    if ($negative.computerUse.safetyBoundary.status -eq 'verified') {
        throw 'An empty safety declaration must not verify the safety boundary.'
    }
    if ($null -eq $report.checks) { throw 'Acceptance status must expose the aggregate check summary.' }
    Write-Output 'PASS: acceptance status distinguishes verified, incomplete and blocked work'
}
finally {
    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
    if (Test-Path -LiteralPath $negativeEvidencePath) { Remove-Item -LiteralPath $negativeEvidencePath -Force }
    if (Test-Path -LiteralPath $negativeOutputPath) { Remove-Item -LiteralPath $negativeOutputPath -Force }
}
