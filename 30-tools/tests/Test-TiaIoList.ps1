[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\New-TiaIoList.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-io-list-test-' + [guid]::NewGuid().ToString('N'))
$inventoryPath = Join-Path $temp 'inventory.json'
$outputPath = Join-Path $temp 'io-list.json'
$blockedInventoryPath = Join-Path $temp 'incomplete-inventory.json'

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    [ordered]@{
        schemaVersion = 1; readOnly = $true; projectPath = 'C:\fixture\IoDemo_V20.ap20'
        tagTables = @(
            [ordered]@{ path = 'PLC tags/Area'; name = 'Area'; tags = @(
                [ordered]@{ name = 'DI_Start'; dataType = 'Bool'; address = '%I0.0'; comment = 'Start pushbutton' }
                [ordered]@{ name = 'Q_Motor'; dataType = 'Bool'; address = '%Q0.0'; comment = 'Motor contactor' }
                [ordered]@{ name = 'M_Auto'; dataType = 'Bool'; address = '%M0.0'; comment = 'Automatic mode' }
                [ordered]@{ name = 'Setpoint'; dataType = 'Real'; comment = 'Symbolic setpoint' }
            ) }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    & $script -InventoryPath $inventoryPath -OutputPath $outputPath -Objective 'Documentar E/S de prueba'
    if ($LASTEXITCODE -ne 0) { throw "I/O list failed with exit code $LASTEXITCODE." }
    $report = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if ($report.readOnly -ne $true) { throw 'I/O list must be read-only.' }
    if ($report.rows.Count -ne 4) { throw 'Expected four detailed tag rows.' }
    if (($report.rows | Where-Object direction -eq 'Input').Count -ne 1) { throw 'Expected one input.' }
    if (($report.rows | Where-Object direction -eq 'Output').Count -ne 1) { throw 'Expected one output.' }
    if (($report.rows | Where-Object direction -eq 'Memory').Count -ne 1) { throw 'Expected one memory tag.' }
    if (($report.rows | Where-Object direction -eq 'Symbolic').Count -ne 1) { throw 'Expected one symbolic tag.' }
    if ($report.summary.requiresReview -ne $false) { throw 'Complete fixture should not require review.' }
    foreach ($artifact in @($outputPath, [IO.Path]::ChangeExtension($outputPath, '.csv'), [IO.Path]::ChangeExtension($outputPath, '.md'))) {
        if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) { throw "Missing I/O artifact: $artifact" }
    }
    Write-Output 'PASS: I/O list extracts detailed tags, classifies addresses and emits traceable artifacts'

    [ordered]@{ schemaVersion = 1; readOnly = $true; projectPath = 'C:\fixture\Incomplete.ap20'; plcs = @() } |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $blockedInventoryPath -Encoding UTF8
    $blocked = $false
    try { & $script -InventoryPath $blockedInventoryPath -OutputPath (Join-Path $temp 'blocked.json') 2>&1 | Out-Null } catch { $blocked = $true }
    if (-not $blocked) { throw 'Missing detailed tags should be blocked instead of guessed.' }
    Write-Output 'PASS: I/O list refuses inventories without detailed tag evidence'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
