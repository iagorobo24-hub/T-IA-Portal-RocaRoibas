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
    Write-Output 'PASS: acceptance status distinguishes verified, incomplete and blocked work'
}
finally {
    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
}
