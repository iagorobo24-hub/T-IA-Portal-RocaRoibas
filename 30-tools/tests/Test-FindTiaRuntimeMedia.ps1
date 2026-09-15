[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Find-TiaRuntimeMedia.ps1'
$tempRoot = Join-Path $env:TEMP ('tia-claude-media-test-' + [guid]::NewGuid().ToString('N'))
$root = Join-Path $tempRoot 'media'
$reportPath = Join-Path $tempRoot 'report.json'
try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'WinCC_Runtime_Advanced_V20.iso') -Value 'fixture' -Encoding ASCII
    & $scriptPath -SearchRoot $root -OutputPath $reportPath | Out-Null
    $report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
    if ($report.readOnly -ne $true -or $report.candidateCount -ne 1) { throw 'Runtime media scan did not identify the fixture.' }
    if ($report.nextStep -notmatch 'confirmation') { throw 'Runtime media scan lacks confirmation gate.' }
    Write-Output 'PASS: runtime media discovery is read-only and confirmation-gated'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
