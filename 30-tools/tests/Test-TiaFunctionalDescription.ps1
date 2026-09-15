[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\New-TiaFunctionalDescription.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-functional-description-test-' + [guid]::NewGuid().ToString('N'))
$analysisPath = Join-Path $temp 'analysis.json'
$ioPath = Join-Path $temp 'io-list.json'
$outputPath = Join-Path $temp 'functional-description.json'

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    [ordered]@{
        schemaVersion = 1; readOnly = $true; projectPath = 'C:\fixture\Demo_V20.ap20'; objective = 'Control de motor'
        project = [ordered]@{ plcCount = 1; blockCount = 2; plcs = @([ordered]@{ name = 'PLC_1'; softwarePath = 'PLC_1'; blockCount = 2; defaultTagCount = 0 }) }
        blocks = @(
            [ordered]@{ plc = 'PLC_1'; path = 'Main'; name = 'Main'; type = 'OB'; language = 'SCL'; consistent = $true; sourcePresent = $true; source = 'Main.scl' }
            [ordered]@{ plc = 'PLC_1'; path = 'FB_Motor'; name = 'FB_Motor'; type = 'FB'; language = 'SCL'; consistent = $true; sourcePresent = $true; source = 'FB_Motor.scl' }
        )
        references = [ordered]@{ calls = @([ordered]@{ fromFile = 'Main.scl'; target = 'FB_Motor'; count = 1 }) }
        sources = [ordered]@{ fileCount = 2; scl = 2; xml = 0; s7res = 0 }
        findings = @([ordered]@{ severity = 'WARNING'; code = 'MISSING_BLOCK_COMMENT'; block = 'FB_Motor'; message = 'Falta comentario' })
        summary = [ordered]@{ blockingFindings = 0; warningFindings = 1; sourceCoveragePercent = 100 }
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $analysisPath -Encoding UTF8
    [ordered]@{
        schemaVersion = 1; readOnly = $true; projectPath = 'C:\fixture\Demo_V20.ap20'
        rows = @([ordered]@{ name = 'DI_Start'; direction = 'Input'; dataType = 'Bool'; address = '%I0.0'; table = 'Area'; comment = 'Start' })
        summary = [ordered]@{ total = 1; inputs = 1; outputs = 0; memory = 0; symbolic = 0; requiresReview = $false }
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $ioPath -Encoding UTF8

    & $script -AnalysisPath $analysisPath -IoListPath $ioPath -OutputPath $outputPath
    if ($LASTEXITCODE -ne 0) { throw "Functional description failed with exit code $LASTEXITCODE." }
    $report = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if ($report.readOnly -ne $true) { throw 'Functional description must be read-only.' }
    if ($report.blocks.Count -ne 2) { throw 'Expected two blocks.' }
    if ($report.references.calls.Count -ne 1) { throw 'Expected one call reference.' }
    if ($report.io.summary.total -ne 1) { throw 'Expected I/O summary.' }
    $markdownPath = [IO.Path]::ChangeExtension($outputPath, '.md')
    $markdown = Get-Content -Raw -LiteralPath $markdownPath
    foreach ($section in @('# Descripción funcional', '## Resumen', '## Bloques', '## Referencias', '## E/S', '## Hallazgos')) {
        if ($markdown -notmatch [regex]::Escape($section)) { throw "Missing Markdown section: $section" }
    }
    Write-Output 'PASS: functional description composes the semantic dossier and I/O evidence without mutation'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
