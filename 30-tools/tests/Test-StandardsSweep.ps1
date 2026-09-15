[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-TiaStandardsSweep.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw 'Invoke-TiaStandardsSweep.ps1 is missing.'
}

$help = & pwsh -NoProfile -NonInteractive -File $scriptPath -Help 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "Standards sweep help failed: $help" }
if ($help -notmatch 'read-only|solo lectura') {
    throw 'Standards sweep must document its read-only behavior.'
}
Write-Output 'PASS: standards sweep script exists and advertises read-only behavior'
