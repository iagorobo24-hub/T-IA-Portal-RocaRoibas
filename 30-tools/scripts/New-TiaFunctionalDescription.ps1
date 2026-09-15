<##
.SYNOPSIS
    Genera una descripción funcional trazable a partir de un dossier semántico.

.DESCRIPTION
    Operacion de SOLO LECTURA. No inventa secuencias, requisitos ni comportamiento de runtime:
    resume únicamente bloques, fuentes, referencias, hallazgos y una lista de E/S opcional.
##>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AnalysisPath,

    [string]$IoListPath,
    [string]$OutputPath,
    [string]$Objective = '',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if ($Help) {
    Write-Output @'
New-TiaFunctionalDescription.ps1: genera functional-description.json y .md en solo lectura.
Entrada: analysis.json y, opcionalmente, io-list.json.
'@
    exit 0
}
$AnalysisPath = [IO.Path]::GetFullPath($AnalysisPath)
if (-not (Test-Path -LiteralPath $AnalysisPath -PathType Leaf)) { throw "Analysis does not exist: $AnalysisPath" }
$analysis = Get-Content -Raw -LiteralPath $AnalysisPath | ConvertFrom-Json
if ($analysis.readOnly -ne $true) { throw 'The analysis dossier must be read-only.' }
if (-not $OutputPath) { $OutputPath = Join-Path $root ('70-runs\documentation\functional-description-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json') }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$io = $null
if ($IoListPath) {
    $IoListPath = [IO.Path]::GetFullPath($IoListPath)
    if (-not (Test-Path -LiteralPath $IoListPath -PathType Leaf)) { throw "I/O list does not exist: $IoListPath" }
    $io = Get-Content -Raw -LiteralPath $IoListPath | ConvertFrom-Json
    if ($io.readOnly -ne $true) { throw 'The I/O list must be read-only.' }
}

$report = [ordered]@{
    schemaVersion = 1
    readOnly = $true
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    projectPath = [string]$analysis.projectPath
    analysisPath = $AnalysisPath
    ioListPath = $IoListPath
    objective = if ($Objective) { $Objective } else { [string]$analysis.objective }
    project = $analysis.project
    blocks = @($analysis.blocks)
    references = $analysis.references
    sources = $analysis.sources
    findings = @($analysis.findings)
    summary = $analysis.summary
    io = if ($io) { [ordered]@{ summary = $io.summary; rows = @($io.rows); findings = if ($io.PSObject.Properties.Name -contains 'findings') { @($io.findings) } else { @() } } } else { $null }
}
$report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$markdownPath = [IO.Path]::ChangeExtension($OutputPath, '.md')
$md = [System.Text.StringBuilder]::new()
$null = $md.AppendLine('# Descripción funcional')
$null = $md.AppendLine()
$null = $md.AppendLine('> Documento generado desde evidencia MCP/exportada en modo **solo lectura**. No sustituye una especificación funcional validada ni una prueba de runtime.')
$null = $md.AppendLine()
$null = $md.AppendLine('## Resumen')
$null = $md.AppendLine()
$null = $md.AppendLine("- Proyecto: ``$($report.projectPath)``")
$null = $md.AppendLine("- Objetivo: $($report.objective)")
$null = $md.AppendLine("- PLCs: $($report.project.plcCount) · Bloques: $($report.project.blockCount) · Cobertura de fuentes: $($report.summary.sourceCoveragePercent)%")
$null = $md.AppendLine("- Hallazgos: $($report.summary.blockingFindings) bloqueantes, $($report.summary.warningFindings) avisos")
$null = $md.AppendLine()
$null = $md.AppendLine('## Bloques')
$null = $md.AppendLine()
$null = $md.AppendLine('| PLC | Ruta | Nombre | Tipo | Lenguaje | Fuente | Consistente |')
$null = $md.AppendLine('|---|---|---|---|---|---|---:|')
foreach ($block in @($report.blocks)) {
    $null = $md.AppendLine("| $($block.plc) | $($block.path) | $($block.name) | $($block.type) | $($block.language) | $($block.source) | $($block.consistent) |")
}
$null = $md.AppendLine()
$null = $md.AppendLine('## Referencias')
$null = $md.AppendLine()
if (@($report.references.calls).Count -eq 0) { $null = $md.AppendLine('No hay llamadas detectadas en las fuentes analizadas.') }
else {
    $null = $md.AppendLine('| Desde | Destino | Veces |')
    $null = $md.AppendLine('|---|---|---:|')
    foreach ($call in @($report.references.calls)) { $null = $md.AppendLine("| $($call.fromFile) | $($call.target) | $($call.count) |") }
}
$null = $md.AppendLine()
$null = $md.AppendLine('## E/S')
$null = $md.AppendLine()
if ($io) {
    $null = $md.AppendLine("Total: $($io.summary.total) · Entradas: $($io.summary.inputs) · Salidas: $($io.summary.outputs) · Memoria: $($io.summary.memory) · Revisión: $($io.summary.requiresReview)")
    $null = $md.AppendLine()
    $null = $md.AppendLine('| Nombre | Tipo | Dirección | Clase |')
    $null = $md.AppendLine('|---|---|---|---|')
    foreach ($row in @($io.rows)) { $null = $md.AppendLine("| $($row.name) | $($row.dataType) | $($row.address) | $($row.direction) |") }
}
else { $null = $md.AppendLine('No se adjuntó una lista detallada de E/S. Este documento no infiere señales.') }
$null = $md.AppendLine()
$null = $md.AppendLine('## Hallazgos')
$null = $md.AppendLine()
if (@($report.findings).Count -eq 0) { $null = $md.AppendLine('No hay hallazgos en el dossier.') }
else { foreach ($finding in @($report.findings)) { $null = $md.AppendLine("- **$($finding.severity)** `$($finding.code)`: $($finding.message)") } }
$md | Set-Content -LiteralPath $markdownPath -Encoding UTF8
Write-Output ($report | ConvertTo-Json -Depth 10)
Write-Host "Evidence: $OutputPath" -ForegroundColor Green
Write-Host "Markdown: $markdownPath" -ForegroundColor Green
exit 0
