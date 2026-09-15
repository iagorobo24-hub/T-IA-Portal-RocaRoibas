[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\New-TiaE2EFixture.ps1'
$source = Join-Path $WorkspaceRoot '50-examples\npatel-iot\02_S7_Project\IOT2050_S7_CompleteProject_V20'
$tempRoot = Join-Path $env:TEMP ('tia-claude-fixture-test-' + [guid]::NewGuid().ToString('N'))
$destination = Join-Path $tempRoot 'fixture'

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Expected fixture script does not exist: $scriptPath"
    }
    & $scriptPath -WorkspaceRoot $WorkspaceRoot -SourceProjectDirectory $source -DestinationDirectory $destination -SkipMcp

    $project = Get-ChildItem -LiteralPath $destination -File -Filter '*.ap20' | Select-Object -First 1
    $baseline = Join-Path $destination 'baseline.json'
    if ($null -eq $project) { throw 'Fixture does not contain an .ap20 project.' }
    if (-not (Test-Path -LiteralPath $baseline -PathType Leaf)) { throw 'Fixture baseline.json is missing.' }

    $data = Get-Content -Raw -LiteralPath $baseline | ConvertFrom-Json
    foreach ($property in @('sourceProjectDirectory', 'fixtureDirectory', 'createdAt', 'mcp')) {
        if (-not ($data.PSObject.Properties.Name -contains $property)) { throw "Baseline missing '$property'." }
    }
    if ($data.mcp.skipped -ne $true) { throw 'SkipMcp fixture must record mcp.skipped=true.' }

    Write-Output 'PASS: disposable E2E fixture contract'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
