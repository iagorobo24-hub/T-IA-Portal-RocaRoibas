<##
.SYNOPSIS
    Construye un dossier semantico de un proyecto TIA a partir de un inventario MCP y sus fuentes exportadas.

.DESCRIPTION
    Operacion de SOLO LECTURA. No conecta con TIA, no importa, no compila y no modifica el proyecto.
    Consume el inventario producido por tia-inspect/Invoke-TiaStandardsSweep y un arbol de fuentes
    exportadas. Genera JSON estable para agentes y Markdown legible para ingenieria.

    La separacion es intencionada: primero se prueba la capa de analisis con snapshots reproducibles;
    una futura capa de aplicacion podra consumir el dossier sin mezclar lectura y escritura.
##>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InventoryPath,

    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [string]$OutputPath,
    [string]$Objective = '',
    [switch]$FailOnBlockingFindings,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

if ($Help) {
    Write-Output @'
Invoke-TiaProjectAnalysis.ps1: dossier semantico de SOLO LECTURA.
Entrada: inventory.json de MCP + carpeta src exportada.
Salida: analysis.json y analysis.md. No abre, modifica, compila ni guarda TIA.
'@
    exit 0
}

$InventoryPath = [IO.Path]::GetFullPath($InventoryPath)
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
if (-not (Test-Path -LiteralPath $InventoryPath -PathType Leaf)) { throw "Inventory does not exist: $InventoryPath" }
if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) { throw "Source root does not exist: $SourceRoot" }

$inventory = Get-Content -Raw -LiteralPath $InventoryPath | ConvertFrom-Json
if ($inventory.readOnly -ne $true) { throw 'The analysis input must be a read-only MCP inventory.' }
if ($null -eq $inventory.plcs) { throw 'Inventory has no plcs collection.' }

if (-not $OutputPath) {
    $OutputPath = Join-Path $root ('70-runs\analysis\analysis-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$markdownPath = [IO.Path]::ChangeExtension($OutputPath, '.md')

function Get-Declaration([string]$Text) {
    $matches = [regex]::Matches($Text, '(?im)^\s*(FUNCTION_BLOCK|FUNCTION|DATA_BLOCK|ORGANIZATION_BLOCK)\s+"?([^"\r\n]+?)"?(?:\s|$)')
    return @($matches | ForEach-Object {
        [ordered]@{
            kind = [string]$_.Groups[1].Value.ToUpperInvariant()
            name = [string]$_.Groups[2].Value.Trim()
        }
    })
}

function Get-XmlDeclaration([string]$Text) {
    try {
        $xml = [xml]$Text
        $blockNode = $xml.SelectSingleNode('//*[starts-with(local-name(), "SW.Blocks.")][1]')
        if (-not $blockNode) { return @() }
        $nameNode = $blockNode.SelectSingleNode('.//*[local-name()="Name"][1]')
        if (-not $nameNode -or [string]::IsNullOrWhiteSpace([string]$nameNode.InnerText)) { return @() }
        $kind = ([string]$blockNode.LocalName -replace '^SW\.Blocks\.', '').ToUpperInvariant()
        return @([ordered]@{
            kind = $kind
            name = [string]$nameNode.InnerText.Trim()
        })
    }
    catch {
        return @()
    }
}

function Get-Calls([string]$Text) {
    $excluded = @('IF', 'ELSIF', 'FOR', 'WHILE', 'REPEAT', 'CASE', 'TON', 'TOF', 'TP', 'LIMIT', 'SEL', 'MUX')
    $names = [regex]::Matches($Text, '"([^"]+)"\s*\(') | ForEach-Object { [string]$_.Groups[1].Value }
    return @($names | Where-Object { $_ -and $_ -notin $excluded } | Group-Object | Sort-Object Name | ForEach-Object {
        [ordered]@{ name = $_.Name; count = [int]$_.Count }
    })
}

function Get-RelativePath([string]$Path, [string]$Base) {
    if ($Path.StartsWith($Base, [StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($Base.Length).TrimStart('\', '/')
    }
    return $Path
}

$sourceFiles = @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -File |
    Where-Object { $_.Extension -in @('.s7dcl', '.scl', '.s7res', '.xml') } | Sort-Object FullName)
$sourceRows = [System.Collections.Generic.List[object]]::new()
$declarations = [System.Collections.Generic.List[object]]::new()
$calls = [System.Collections.Generic.List[object]]::new()

foreach ($file in $sourceFiles) {
    $text = Get-Content -Raw -LiteralPath $file.FullName
    $fileDeclarations = @(Get-Declaration $text)
    if ($file.Extension -eq '.xml') {
        $fileDeclarations = @(Get-XmlDeclaration $text)
    }
    $fileCalls = @(Get-Calls $text)
    foreach ($decl in $fileDeclarations) {
        $declarations.Add([ordered]@{
            name = $decl.name
            kind = $decl.kind
            file = Get-RelativePath $file.FullName $SourceRoot
        })
    }
    foreach ($call in $fileCalls) {
        $calls.Add([ordered]@{
            fromFile = Get-RelativePath $file.FullName $SourceRoot
            target = $call.name
            count = $call.count
        })
    }
    $sourceRows.Add([ordered]@{
        path = Get-RelativePath $file.FullName $SourceRoot
        extension = $file.Extension.ToLowerInvariant()
        bytes = [int64]$file.Length
        lines = @($text -split "`r?`n").Count
        declarations = @($fileDeclarations)
    })
}

$inventoryBlocks = [System.Collections.Generic.List[object]]::new()
foreach ($plc in @($inventory.plcs)) {
    foreach ($block in @($plc.blocks)) {
        $inventoryBlocks.Add([ordered]@{
            softwarePath = [string]$plc.softwarePath
            path = [string]$block.path
            name = [string]$block.name
            typeName = [string]$block.typeName
            programmingLanguage = [string]$block.programmingLanguage
            isConsistent = [bool]$block.isConsistent
            isKnowHowProtected = [bool]$block.isKnowHowProtected
            comment = [bool]$block.comment
        })
    }
}
foreach ($block in @($inventory.blocks)) {
    if (-not (@($inventoryBlocks | Where-Object { $_.path -eq [string]$block.path -and $_.name -eq [string]$block.name }).Count)) {
        $inventoryBlocks.Add([ordered]@{
            softwarePath = [string]$block.softwarePath
            path = [string]$block.path
            name = [string]$block.name
            typeName = [string]$block.typeName
            programmingLanguage = [string]$block.programmingLanguage
            isConsistent = [bool]$block.isConsistent
            isKnowHowProtected = [bool]$block.isKnowHowProtected
            comment = [bool]$block.comment
        })
    }
}

$declarationNames = @($declarations | ForEach-Object { $_.name } | Select-Object -Unique)
$blockRows = [System.Collections.Generic.List[object]]::new()
$findings = [System.Collections.Generic.List[object]]::new()

foreach ($block in $inventoryBlocks) {
    $name = [string]$block.name
    $match = $declarations | Where-Object { $_.name -eq $name } | Select-Object -First 1
    $hasSource = $null -ne $match
    $blockRows.Add([ordered]@{
        plc = [string]$block.softwarePath
        path = [string]$block.path
        name = $name
        type = [string]$block.typeName
        language = [string]$block.programmingLanguage
        consistent = [bool]$block.isConsistent
        knowHowProtected = [bool]$block.isKnowHowProtected
        hasComment = [bool]$block.comment
        source = if ($match) { [string]$match.file } else { $null }
        sourcePresent = $hasSource
    })

    if ($block.isKnowHowProtected) {
        $findings.Add([ordered]@{ severity = 'BLOCKING'; code = 'KNOW_HOW_PROTECTED'; block = $name; message = 'El bloque esta protegido y no se puede editar mediante el agente.' })
    }
    if ($block.isConsistent -eq $false) {
        $findings.Add([ordered]@{ severity = 'BLOCKING'; code = 'INCONSISTENT_BLOCK'; block = $name; message = 'El bloque figura como inconsistente; no se debe escribir ni guardar.' })
    }
    if (-not $hasSource) {
        $findings.Add([ordered]@{ severity = 'WARNING'; code = 'SOURCE_NOT_EXPORTED'; block = $name; message = 'No se encontro una declaracion exportada para este bloque.' })
    }
    if ($block.comment -eq $false) {
        $findings.Add([ordered]@{ severity = 'WARNING'; code = 'MISSING_BLOCK_COMMENT'; block = $name; message = 'El bloque no tiene comentario de cabecera verificable en el inventario.' })
    }
    if ([string]$block.typeName -match '(?i)F-|Safety' -or $name -match '(?i)^F_|Safety') {
        $findings.Add([ordered]@{ severity = 'BLOCKING'; code = 'SAFETY_OBJECT'; block = $name; message = 'El objeto parece relacionado con safety; requiere auditoria y no se edita.' })
    }
}

$defaultTagCount = [int]$inventory.defaultTagCount
if ($defaultTagCount -gt 0) {
    $findings.Add([ordered]@{ severity = 'WARNING'; code = 'DEFAULT_TAG_TABLE'; block = $null; message = "La tabla de tags por defecto contiene $defaultTagCount tags; conviene separar tags por area o funcion." })
}

function Get-Counts([object[]]$Items, [string]$Property) {
    $result = [ordered]@{}
    foreach ($group in @($Items | Group-Object -Property { $_[$Property] } | Sort-Object Name)) {
        if ($group.Name) { $result[$group.Name] = [int]$group.Count }
    }
    return $result
}

$blockingCount = @($findings | Where-Object { $_.severity -eq 'BLOCKING' }).Count
$warningCount = @($findings | Where-Object { $_.severity -eq 'WARNING' }).Count
$sclCount = @($sourceFiles | Where-Object { $_.Extension -in @('.s7dcl', '.scl') }).Count
$xmlCount = @($sourceFiles | Where-Object { $_.Extension -eq '.xml' }).Count
$resCount = @($sourceFiles | Where-Object { $_.Extension -eq '.s7res' }).Count
$nextActions = [System.Collections.Generic.List[string]]::new()
if ($blockingCount -gt 0) { $nextActions.Add('Resolver los hallazgos BLOCKING antes de cualquier escritura.') }
if ($sclCount -gt 0) { $nextActions.Add('Usar las fuentes SCL exportadas como base de lectura y propuesta.') }
if ($xmlCount -gt 0) { $nextActions.Add('Tratar los XML como evidencia estructural; no generar LAD a mano.') }
if ($inventoryBlocks.Count -gt 0) { $nextActions.Add('Leer el bloque de entrada y sus referencias antes de proponer cambios.') }
if ($nextActions.Count -eq 0) { $nextActions.Add('Ejecutar un inventario MCP completo antes de proponer cambios.') }

$report = [ordered]@{
    schemaVersion = 1
    readOnly = $true
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    projectPath = [string]$inventory.projectPath
    inventoryPath = $InventoryPath
    sourceRoot = $SourceRoot
    objective = $Objective
    project = [ordered]@{
        plcCount = @($inventory.plcs).Count
        plcs = @($inventory.plcs | ForEach-Object { [ordered]@{ name = [string]$_.name; softwarePath = [string]$_.softwarePath; blockCount = @($_.blocks).Count; defaultTagCount = [int]$_.defaultTagCount } })
        blockCount = $inventoryBlocks.Count
        blockTypes = Get-Counts (@($inventoryBlocks | ForEach-Object { $_ })) 'typeName'
        languages = Get-Counts (@($inventoryBlocks | ForEach-Object { $_ })) 'programmingLanguage'
    }
    sources = [ordered]@{
        fileCount = $sourceFiles.Count
        scl = $sclCount
        s7res = $resCount
        xml = $xmlCount
        declarations = @($declarations)
        files = @($sourceRows)
    }
    blocks = @($blockRows)
    references = [ordered]@{ calls = @($calls) }
    findings = @($findings)
    summary = [ordered]@{
        blockingFindings = $blockingCount
        warningFindings = $warningCount
        sourceCoveragePercent = if ($inventoryBlocks.Count -eq 0) { 0 } else { [math]::Round((@($blockRows | Where-Object { $_.sourcePresent }).Count / $inventoryBlocks.Count) * 100, 1) }
        success = ($blockingCount -eq 0)
    }
    nextActions = @($nextActions)
}

$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

$md = [System.Text.StringBuilder]::new()
$null = $md.AppendLine('# Analisis de proyecto TIA')
$null = $md.AppendLine()
$null = $md.AppendLine('> Informe generado en modo **solo lectura**. No implica cambios aplicados en TIA Portal.')
$null = $md.AppendLine()
$null = $md.AppendLine("- Proyecto: ``$($report.projectPath)``")
$null = $md.AppendLine("- PLCs: $($report.project.plcCount)")
$null = $md.AppendLine("- Bloques: $($report.project.blockCount)")
$null = $md.AppendLine("- Cobertura de fuentes: $($report.summary.sourceCoveragePercent)%")
$null = $md.AppendLine("- Hallazgos: $blockingCount bloqueantes, $warningCount avisos")
$null = $md.AppendLine()
$null = $md.AppendLine('## Bloques')
$null = $md.AppendLine()
$null = $md.AppendLine('| PLC | Ruta | Tipo | Lenguaje | Consistente | Fuente |')
$null = $md.AppendLine('|---|---|---|---|---:|---|')
foreach ($block in $blockRows) {
    $source = if ($block.source) { $block.source } else { '—' }
    $null = $md.AppendLine("| $($block.plc) | ``$($block.path)`` | $($block.type) | $($block.language) | $($block.consistent) | ``$source`` |")
}
$null = $md.AppendLine()
$null = $md.AppendLine('## Hallazgos')
$null = $md.AppendLine()
if ($findings.Count -eq 0) {
    $null = $md.AppendLine('No hay hallazgos.')
}
else {
    foreach ($finding in $findings) {
        $target = if ($finding.block) { " [$($finding.block)]" } else { '' }
        $null = $md.AppendLine("- **$($finding.severity)** ``$($finding.code)``$target — $($finding.message)")
    }
}
$null = $md.AppendLine()
$null = $md.AppendLine('## Siguiente paso recomendado')
$null = $md.AppendLine()
foreach ($action in $nextActions) { $null = $md.AppendLine("- $action") }
$md.ToString() | Set-Content -LiteralPath $markdownPath -Encoding UTF8

Write-Output ($report | ConvertTo-Json -Depth 8)
Write-Host "Evidence: $OutputPath" -ForegroundColor Green
Write-Host "Evidence: $markdownPath" -ForegroundColor Green
if ($FailOnBlockingFindings -and $blockingCount -gt 0) { exit 1 }
exit 0
