<##
.SYNOPSIS
    Inventaria todos los proyectos V20 de los ejemplos y ejecuta el checker.

.DESCRIPTION
    Operacion de SOLO LECTURA. Usa el perfil read de tia-inspect, no compila,
    no guarda, no importa y no modifica ningun proyecto. Abre cada .ap20,
    obtiene arbol, software, resumen y bloques, y comprueba las fuentes src
    que ya existen junto al proyecto. Los hallazgos son evidencia, no cambios.

.PARAMETER ProjectPath
    Uno o varios .ap20 concretos. Si se omite, descubre todos los .ap20 de 50-examples.

.PARAMETER OutputRoot
    Carpeta de resultados. Por defecto, 70-runs/standards/sweep-<timestamp>.

.PARAMETER FailOnFindings
    Devuelve codigo 1 si algun ejemplo tiene hallazgos bloqueantes.

.PARAMETER Help
    Muestra esta ayuda y termina.
##>
[CmdletBinding()]
param(
    [string[]]$ProjectPath,
    [string]$OutputRoot,
    [switch]$FailOnFindings,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

if ($Help) {
    Write-Output @'
Invoke-TiaStandardsSweep.ps1: barrido de estandares en SOLO LECTURA.
Descubre .ap20, usa tia-inspect en perfil read, no guarda ni modifica proyectos,
y escribe inventarios y hallazgos JSON en 70-runs/standards.
'@
    exit 0
}

$invoke = Join-Path $PSScriptRoot 'Invoke-TiaMcp.ps1'
$checker = Join-Path $PSScriptRoot 'Check-TiaStandards.ps1'
if (-not (Test-Path -LiteralPath $invoke -PathType Leaf)) { throw "Missing MCP invoker: $invoke" }
if (-not (Test-Path -LiteralPath $checker -PathType Leaf)) { throw "Missing standards checker: $checker" }

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $root ('70-runs\standards\sweep-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

if ($ProjectPath) {
    $projects = @($ProjectPath | ForEach-Object {
        $candidate = [IO.Path]::GetFullPath($_)
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "Project does not exist: $candidate" }
        Get-Item -LiteralPath $candidate
    })
}
else {
    $examples = Join-Path $root '50-examples'
    $projects = @(Get-ChildItem -LiteralPath $examples -Recurse -File -Filter '*.ap20' |
        Where-Object { $_.DirectoryName -notmatch '\.backup$' } |
        Sort-Object FullName)
}
if ($projects.Count -eq 0) { throw 'No V20 .ap20 projects were found.' }

function Get-ToolResult([object[]]$Results, [string]$Tool) {
    return $Results | Where-Object { $_.Tool -eq $Tool } | Select-Object -Last 1
}

function Read-ToolJson([object]$Result, [string]$Context) {
    if (-not $Result -or $Result.IsError) {
        $detail = if ($Result) { [string]$Result.Text } else { 'no response' }
        throw "$Context failed: $detail"
    }
    return ([string]$Result.Text | ConvertFrom-Json)
}

function Get-SoftwarePaths([string]$TreeText) {
    return @([regex]::Matches($TreeText, 'PlcSoftware:\s*(.+?)\s*\[') |
        ForEach-Object { $_.Groups[1].Value.Trim() } |
        Where-Object { $_ } | Select-Object -Unique)
}

function Get-DefaultTagCount([string]$TreeText) {
    $match = [regex]::Match($TreeText, 'Default tag table\s*\[Tag table,\s*(\d+)\s*tags')
    if ($match.Success) { return [int]$match.Groups[1].Value }
    return 0
}

$rows = [System.Collections.Generic.List[object]]::new()
foreach ($project in $projects) {
    $relative = $project.FullName
    if ($project.FullName.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        $relative = $project.FullName.Substring($root.Length).TrimStart('\')
    }
    $slug = ($relative -replace '[^A-Za-z0-9._-]', '_') -replace '\.ap20$', ''
    $projectOut = Join-Path $OutputRoot $slug
    New-Item -ItemType Directory -Path $projectOut -Force | Out-Null
    Write-Host "[READ] $relative" -ForegroundColor Cyan

    $row = [ordered]@{
        projectPath = $project.FullName
        relativePath = $relative
        opened = $false
        projectTree = $null
        plcs = @()
        inventoryPath = $null
        exportPath = $null
        standardsPath = $null
        collectionErrors = @()
    }

    try {
        $openResults = & $invoke -TimeoutSeconds 900 -ContinueOnError -Calls @(
            @{ name = 'Connect' },
            @{ name = 'OpenProject'; args = @{ path = $project.FullName } },
            @{ name = 'GetProjectTree' }
        )
        $open = Get-ToolResult $openResults 'OpenProject'
        $treeResult = Get-ToolResult $openResults 'GetProjectTree'
        if (-not $open -or $open.IsError) { throw "OpenProject failed: $([string]$open.Text)" }
        if (-not $treeResult -or $treeResult.IsError) { throw "GetProjectTree failed: $([string]$treeResult.Text)" }
        $row.opened = $true
        $tree = Read-ToolJson $treeResult 'GetProjectTree'
        $row.projectTree = [string]$tree.tree
        $softwarePaths = Get-SoftwarePaths $row.projectTree
        $row.plcs = @($softwarePaths)
        $plcInventories = [System.Collections.Generic.List[object]]::new()

        foreach ($softwarePath in $softwarePaths) {
            $softwareResults = & $invoke -TimeoutSeconds 900 -ContinueOnError -Calls @(
                @{ name = 'Connect' },
                @{ name = 'GetSoftwareTree'; args = @{ softwarePath = $softwarePath; sections = 'blocks,tags,types,sources' } },
                @{ name = 'GetPlcSummary'; args = @{ softwarePath = $softwarePath } },
                @{ name = 'GetBlocks'; args = @{ softwarePath = $softwarePath; regexName = '' } }
            )
            $softwareTreeResult = Get-ToolResult $softwareResults 'GetSoftwareTree'
            $summaryResult = Get-ToolResult $softwareResults 'GetPlcSummary'
            $blocksResult = Get-ToolResult $softwareResults 'GetBlocks'
            $softwareTree = Read-ToolJson $softwareTreeResult "GetSoftwareTree $softwarePath"
            $summary = Read-ToolJson $summaryResult "GetPlcSummary $softwarePath"
            $blocksPayload = Read-ToolJson $blocksResult "GetBlocks $softwarePath"
            $blockItems = @($blocksPayload.items | ForEach-Object {
                [ordered]@{
                    path = [string]$_.path
                    name = [string]$_.name
                    typeName = [string]$_.typeName
                    programmingLanguage = [string]$_.programmingLanguage
                    isConsistent = [bool]$_.isConsistent
                    isKnowHowProtected = [bool]$_.isKnowHowProtected
                    comment = [bool](-not [string]::IsNullOrWhiteSpace([string]$_.headerName))
                }
            })
            $plcInventories.Add([ordered]@{
                name = [string]$summary.name
                softwarePath = $softwarePath
                summary = $summary
                softwareTree = [string]$softwareTree.tree
                blocks = $blockItems
                defaultTagCount = Get-DefaultTagCount ([string]$softwareTree.tree)
            })
        }

        $inventory = [ordered]@{
            schemaVersion = 1
            readOnly = $true
            generatedAt = [DateTimeOffset]::Now.ToString('o')
            projectPath = $project.FullName
            projectTree = $row.projectTree
            plcs = @($plcInventories)
            blocks = @($plcInventories | ForEach-Object { $_.blocks })
            defaultTagCount = [int](@($plcInventories | ForEach-Object { $_.defaultTagCount }) | Measure-Object -Sum).Sum
        }
        $inventoryPath = Join-Path $projectOut 'inventory.json'
        $inventory | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8
        $row.inventoryPath = $inventoryPath

        $exportCandidates = @(
            (Join-Path $project.Directory.FullName 'src'),
            (Join-Path $project.Directory.Parent.FullName 'src'),
            (Join-Path $project.Directory.Parent.Parent.FullName 'src')
        ) | Select-Object -Unique
        $exportPath = $exportCandidates |
            Where-Object {
                (Test-Path -LiteralPath $_ -PathType Container) -and
                @(Get-ChildItem -LiteralPath $_ -Recurse -File -ErrorAction SilentlyContinue).Count -gt 0
            } |
            Select-Object -First 1
        if (-not $exportPath) {
            $exportPath = Join-Path $projectOut 'empty-export'
            New-Item -ItemType Directory -Path $exportPath -Force | Out-Null
        }
        $row.exportPath = $exportPath
        $standardsPath = Join-Path $projectOut 'standards.json'
        $standardsOutput = (& $checker -InventoryPath $inventoryPath -ExportPath $exportPath -OutputPath $standardsPath 2>&1 | Out-String).Trim()
        $standardsExit = $LASTEXITCODE
        $row.standardsPath = $standardsPath
        if ($standardsExit -ne 0 -and $FailOnFindings) { throw "Standards findings: $standardsOutput" }
    }
    catch {
        $row.collectionErrors = @([string]$_.Exception.Message)
        Write-Host "  ERROR: $($row.collectionErrors[0])" -ForegroundColor Red
    }
    finally {
        try {
            & $invoke -TimeoutSeconds 300 -ContinueOnError -Calls @(
                @{ name = 'Connect' },
                @{ name = 'CloseProject' },
                @{ name = 'Disconnect' }
            ) | Out-Null
        }
        catch { }
    }
    $rows.Add([pscustomobject]$row)
}

$blockingFindings = 0
foreach ($row in $rows) {
    if ($row.standardsPath -and (Test-Path -LiteralPath $row.standardsPath -PathType Leaf)) {
        try {
            $standards = Get-Content -Raw -LiteralPath $row.standardsPath | ConvertFrom-Json
            $blockingFindings += [int]$standards.summary.blockingFindings
        }
        catch { }
    }
}
$report = [ordered]@{
    schemaVersion = 1
    readOnly = $true
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    outputRoot = $OutputRoot
    projectCount = $rows.Count
    collectedCount = @($rows | Where-Object { $_.collectionErrors.Count -eq 0 }).Count
    collectionErrorCount = @($rows | Where-Object { $_.collectionErrors.Count -gt 0 }).Count
    blockingFindingCount = $blockingFindings
    success = (@($rows | Where-Object { $_.collectionErrors.Count -gt 0 }).Count -eq 0 -and (-not $FailOnFindings -or $blockingFindings -eq 0))
    projects = @($rows)
}
$reportPath = Join-Path $OutputRoot 'sweep-report.json'
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Output ($report | ConvertTo-Json -Depth 6)
Write-Host "Evidence: $reportPath" -ForegroundColor Green
if (-not $report.success) { exit 1 }
exit 0
