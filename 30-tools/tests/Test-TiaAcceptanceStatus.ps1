[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Write-TiaAcceptanceStatus.ps1'
$tempPath = Join-Path $env:TEMP ('tia-claude-acceptance-' + [guid]::NewGuid().ToString('N') + '.json')
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
    if ($null -eq $report.checks) { throw 'Acceptance status must expose the aggregate check summary.' }
    Write-Output 'PASS: acceptance status distinguishes verified, incomplete and blocked work'
}
finally {
    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
}
