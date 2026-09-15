[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$checker = Join-Path $WorkspaceRoot '30-tools\scripts\Check-TiaStandards.ps1'
if (-not (Test-Path -LiteralPath $checker -PathType Leaf)) {
    throw 'Check-TiaStandards.ps1 is missing.'
}

$testRoot = Join-Path $WorkspaceRoot ('90-tmp\standards-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$passExport = Join-Path $testRoot 'pass-export'
$failExport = Join-Path $testRoot 'fail-export'
New-Item -ItemType Directory -Path (Join-Path $passExport 'Program blocks') -Force | Out-Null
New-Item -ItemType Directory -Path $failExport -Force | Out-Null
try {
    $passInventory = [ordered]@{
        schemaVersion = 1
        blocks = @(
            [ordered]@{ path = '40_Devices/FB_Motor'; name = 'FB_Motor'; programmingLanguage = 'SCL'; isConsistent = $true; isKnowHowProtected = $false; comment = $true }
        )
        tagTables = @(
            [ordered]@{ name = '10_Internal'; isDefault = $false }
        )
        defaultTagCount = 0
    }
    $failInventory = [ordered]@{
        schemaVersion = 1
        blocks = @(
            [ordered]@{ path = 'Program blocks/BadBlock'; name = 'BadBlock'; programmingLanguage = 'SCL'; isConsistent = $false; isKnowHowProtected = $false; comment = $false }
        )
        tagTables = @(
            [ordered]@{ name = 'Default tag table'; isDefault = $true }
        )
        defaultTagCount = 2
    }
    $passInventoryPath = Join-Path $testRoot 'pass.json'
    $failInventoryPath = Join-Path $testRoot 'fail.json'
    $passInventory | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $passInventoryPath -Encoding UTF8
    $failInventory | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $failInventoryPath -Encoding UTF8
    'valid export' | Set-Content -LiteralPath (Join-Path $passExport 'Program blocks\FB_Motor.s7dcl') -Encoding UTF8

    $passOutput = (& $checker -InventoryPath $passInventoryPath -ExportPath $passExport | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Passing fixture was rejected: $passOutput" }
    $passResult = $passOutput | ConvertFrom-Json
    if (-not $passResult.success) { throw 'Passing fixture did not report success.' }

    $failOutput = (& $checker -InventoryPath $failInventoryPath -ExportPath $failExport | Out-String).Trim()
    if ($LASTEXITCODE -eq 0) { throw 'Failing fixture was unexpectedly accepted.' }
    $failResult = $failOutput | ConvertFrom-Json
    $codes = @($failResult.findings | ForEach-Object { $_.code })
    foreach ($requiredCode in @('INCONSISTENT_BLOCK', 'DEFAULT_TAG_TABLE', 'MISSING_EXPORT')) {
        if ($codes -notcontains $requiredCode) { throw "Missing expected finding $requiredCode." }
    }
    Write-Output 'PASS: TIA standards checker gates consistent blocks, tag tables and exports'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
