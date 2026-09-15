<##
.SYNOPSIS
    Genera una lista de E/S a partir de un inventario MCP con tags detalladas.

.DESCRIPTION
    Operacion de SOLO LECTURA. No intenta deducir tags desde contadores o texto del arbol:
    exige que el inventario contenga tagTables/tags detalladas obtenidas mediante GetTagTables
    y GetTags (o una estructura equivalente). Clasifica direcciones I/Q/M y deja simbolicas o
    ambiguas como pendientes de revision.
##>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InventoryPath,

    [string]$OutputPath,
    [string]$Objective = '',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

if ($Help) {
    Write-Output @'
New-TiaIoList.ps1: genera io-list.json, io-list.csv e io-list.md en solo lectura.
El inventario debe contener detalles de tags; no se infieren E/S desde contadores.
'@
    exit 0
}

$InventoryPath = [IO.Path]::GetFullPath($InventoryPath)
if (-not (Test-Path -LiteralPath $InventoryPath -PathType Leaf)) { throw "Inventory does not exist: $InventoryPath" }
$inventory = Get-Content -Raw -LiteralPath $InventoryPath | ConvertFrom-Json
if ($inventory.readOnly -ne $true) { throw 'The input inventory must be read-only.' }
if (-not $OutputPath) { $OutputPath = Join-Path $root ('70-runs\documentation\io-list-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json') }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Get-Field([object]$Object, [string[]]$Names) {
    foreach ($name in $Names) {
        if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $name) {
            $value = $Object.$name
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) { return $value }
        }
    }
    return $null
}

function Get-Direction([string]$Address) {
    if ([string]::IsNullOrWhiteSpace($Address)) { return 'Symbolic' }
    $normalized = $Address.Trim().ToUpperInvariant()
    if ($normalized -match '^%?I(?:[0-9]|W|D)') { return 'Input' }
    if ($normalized -match '^%?Q(?:[0-9]|W|D)') { return 'Output' }
    if ($normalized -match '^%?M(?:[0-9]|W|D)') { return 'Memory' }
    return 'Unknown'
}

$tagCandidates = [System.Collections.Generic.List[object]]::new()
function Add-TagTable([object]$Table, [string]$FallbackPath) {
    $tablePath = [string](Get-Field $Table @('path', 'tablePath', 'name'))
    if ([string]::IsNullOrWhiteSpace($tablePath)) { $tablePath = $FallbackPath }
    $tags = @()
    if ($Table.PSObject.Properties.Name -contains 'tags') { $tags = @($Table.tags) }
    elseif ($Table.PSObject.Properties.Name -contains 'items') { $tags = @($Table.items) }
    foreach ($tag in $tags) {
        $tagCandidates.Add([ordered]@{ table = $tablePath; tag = $tag })
    }
}

if ($inventory.PSObject.Properties.Name -contains 'tagTables') {
    foreach ($table in @($inventory.tagTables)) { Add-TagTable $table 'PLC tags' }
}
if ($inventory.PSObject.Properties.Name -contains 'tags') {
    foreach ($tag in @($inventory.tags)) { $tagCandidates.Add([ordered]@{ table = 'PLC tags'; tag = $tag }) }
}
foreach ($plc in @($inventory.plcs)) {
    if ($plc.PSObject.Properties.Name -contains 'tagTables') {
        foreach ($table in @($plc.tagTables)) { Add-TagTable $table ([string]$plc.softwarePath) }
    }
    if ($plc.PSObject.Properties.Name -contains 'tags') {
        foreach ($tag in @($plc.tags)) { $tagCandidates.Add([ordered]@{ table = [string]$plc.softwarePath; tag = $tag }) }
    }
}
if ($tagCandidates.Count -eq 0) {
    throw 'Inventory has no detailed tags. Run GetTagTables and GetTags (or export their detailed result) before generating an I/O list; counters and softwareTree text are insufficient evidence.'
}

$rows = [System.Collections.Generic.List[object]]::new()
$seen = @{}
$index = 0
foreach ($candidate in $tagCandidates) {
    $index++
    $tag = $candidate.tag
    $name = [string](Get-Field $tag @('name', 'tagName', 'symbolicName'))
    if ([string]::IsNullOrWhiteSpace($name)) { $name = "<unnamed-$index>" }
    $dataType = [string](Get-Field $tag @('dataType', 'type', 'typeName'))
    $address = [string](Get-Field $tag @('logicalAddress', 'address', 'physicalAddress'))
    $comment = [string](Get-Field $tag @('comment', 'description'))
    $table = [string]$candidate.table
    $key = (($table + '|' + $name + '|' + $address).ToUpperInvariant())
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $direction = Get-Direction $address
    $review = ([string]::IsNullOrWhiteSpace($dataType) -or $direction -eq 'Unknown' -or $name.StartsWith('<unnamed-'))
    $rows.Add([ordered]@{
        table = $table
        name = $name
        dataType = $dataType
        address = $address
        direction = $direction
        comment = $comment
        requiresReview = $review
    })
}
$rows = @($rows | Sort-Object table, name, address)
$findings = @($rows | Where-Object { $_.requiresReview } | ForEach-Object {
    [ordered]@{ severity = 'WARNING'; code = 'IO_REVIEW_REQUIRED'; tag = $_.name; message = 'La tag no tiene una clasificacion fisica o tipo completamente verificable.' }
})
$summary = [ordered]@{
    total = $rows.Count
    inputs = @($rows | Where-Object direction -eq 'Input').Count
    outputs = @($rows | Where-Object direction -eq 'Output').Count
    memory = @($rows | Where-Object direction -eq 'Memory').Count
    symbolic = @($rows | Where-Object direction -eq 'Symbolic').Count
    unknown = @($rows | Where-Object direction -eq 'Unknown').Count
    requiresReview = ($findings.Count -gt 0)
}
$report = [ordered]@{
    schemaVersion = 1
    readOnly = $true
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    projectPath = [string]$inventory.projectPath
    inventoryPath = $InventoryPath
    objective = $Objective
    rows = @($rows)
    findings = @($findings)
    summary = $summary
}
$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$csvPath = [IO.Path]::ChangeExtension($OutputPath, '.csv')
if ($rows.Count -gt 0) { $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8 }
else { 'table,name,dataType,address,direction,comment,requiresReview' | Set-Content -LiteralPath $csvPath -Encoding UTF8 }
$markdownPath = [IO.Path]::ChangeExtension($OutputPath, '.md')
$md = [System.Text.StringBuilder]::new()
$null = $md.AppendLine('# Lista de E/S')
$null = $md.AppendLine()
$null = $md.AppendLine('> Informe generado en modo **solo lectura** a partir de tags detalladas del inventario MCP.')
$null = $md.AppendLine()
$null = $md.AppendLine("- Proyecto: ``$($report.projectPath)``")
$null = $md.AppendLine("- Total: $($summary.total) · Entradas: $($summary.inputs) · Salidas: $($summary.outputs) · Memoria: $($summary.memory) · Simbolicas: $($summary.symbolic)")
$null = $md.AppendLine("- Revisión necesaria: $($summary.requiresReview)")
$null = $md.AppendLine()
$null = $md.AppendLine('| Tabla | Nombre | Tipo | Dirección | Clase | Comentario | Revisar |')
$null = $md.AppendLine('|---|---|---|---|---|---|---:|')
foreach ($row in $rows) {
    $null = $md.AppendLine("| $($row.table) | $($row.name) | $($row.dataType) | $($row.address) | $($row.direction) | $($row.comment) | $($row.requiresReview) |")
}
$md | Set-Content -LiteralPath $markdownPath -Encoding UTF8
Write-Output ($report | ConvertTo-Json -Depth 8)
Write-Host "Evidence: $OutputPath" -ForegroundColor Green
Write-Host "CSV: $csvPath" -ForegroundColor Green
Write-Host "Markdown: $markdownPath" -ForegroundColor Green
exit 0
