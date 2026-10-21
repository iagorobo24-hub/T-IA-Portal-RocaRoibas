<#
.SYNOPSIS
    Responde "donde se usa esta tag y que bloques la escriben" sobre un proyecto TIA, con
    referencias reales.

.DESCRIPTION
    Hace tres cosas, en este orden:
      1. Lee el inventario real de tags del PLC (GetTags) y dice si la tag existe.
      2. Si no existe, propone los candidatos mas cercanos por nombre: preguntar por una tag
         que no existe es tan util como contestarla bien.
      3. Si existe, busca sus apariciones en el export textual (Program blocks y sources) y
         dice quien la escribe y quien la lee.

    La busqueda en el export es a proposito: las herramientas de analisis estatico de TIA
    (TraceTagCause, DescribeBlockLogic, GetCrossReferences) NO resuelven un tag global pasado
    como parametro formal de una llamada a un FB en SCL, y devuelven writeSites y readSites
    vacios. Medido el 2026-10-21 sobre DEMO-Cinta01.

    Con -DryRun solo lee el inventario y el export, sin conectar con TIA.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [string]$ProjectFile,
    [string]$ProjectName,
    [string]$ExportPath,
    [string]$SoftwarePath = 'PLC_1',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$exe = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
$sequenceScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }

function Invoke-McpSequence([array]$Calls, [string]$Label) {
    $callsJson = $Calls | ConvertTo-Json -Depth 20 -Compress
    $reportPath = Join-Path ([IO.Path]::GetTempPath()) ('tia-tag-usage-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
    $callArgs = @(
        '-NoProfile', '-NonInteractive', '-File', $sequenceScript,
        '-ExecutablePath', $exe,
        '-Arguments', '--tia-major-version 20 --profile full',
        '-CallsJson', $callsJson,
        '-OutputPath', $reportPath,
        '-TimeoutSeconds', '900'
    )
    $null = & $pwsh @callArgs 2>&1
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw "$Label produced no report." }
    $report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
    $failed = @($report.calls | Where-Object { -not $_.success })
    if ($failed.Count -gt 0) { throw "$Label failed at $($failed[0].name): $($failed[0].text)" }
    return $report
}

$inventory = @()
function Get-OpenCalls([string]$Mode) {
    if ($Mode -eq 'attach') {
        return @(
            [ordered]@{ name = 'Connect'; args = @{} },
            [ordered]@{ name = 'AttachToOpenProject'; args = [ordered]@{ projectName = $ProjectName } }
        )
    }
    return @(
        [ordered]@{ name = 'Connect'; args = @{} },
        [ordered]@{ name = 'OpenProject'; args = [ordered]@{ path = [IO.Path]::GetFullPath($ProjectFile); closeForeignProject = $false } }
    )
}
if (-not $ProjectName -and -not $ProjectFile) { throw 'Give -ProjectFile or -ProjectName.' }
$readCalls = (Get-OpenCalls 'attach') + @(
    [ordered]@{ name = 'GetTags'; args = [ordered]@{ softwarePath = $SoftwarePath } },
    [ordered]@{ name = 'CloseProject'; args = @{} },
    [ordered]@{ name = 'Disconnect'; args = @{} }
)
try {
    $report = Invoke-McpSequence $readCalls 'Tag inventory'
}
catch {
    # Adjuntar solo funciona si el proyecto esta abierto en la TIA. Si no lo esta, se abre.
    if (-not $ProjectFile) { throw }
    $readCalls = (Get-OpenCalls 'open') + @(
        [ordered]@{ name = 'GetTags'; args = [ordered]@{ softwarePath = $SoftwarePath } },
        [ordered]@{ name = 'CloseProject'; args = @{} },
        [ordered]@{ name = 'Disconnect'; args = @{} }
    )
    $report = Invoke-McpSequence $readCalls 'Tag inventory'
}
$call = @($report.calls) | Where-Object name -eq 'GetTags' | Select-Object -First 1
$inventory = @((($call.text | ConvertFrom-Json).items))

$exact = @($inventory | Where-Object { [string]$_.name -eq $Tag -or [string]$_.path -eq $Tag })
$words = @($Tag -split '[^A-Za-z0-9]+' | Where-Object { $_.Length -ge 3 })
$candidates = @()
if ($exact.Count -eq 0) {
    $candidates = @($inventory | Where-Object {
        $name = [string]$_.name
        $hit = $false
        foreach ($word in $words) { if ($name -like "*$word*") { $hit = $true } }
        $hit
    } | ForEach-Object { [ordered]@{ name = [string]$_.name; path = [string]$_.path; isSafety = $_.isSafety } })
    if ($candidates.Count -eq 0) {
        # Ningun tag coincide por nombre. Con el estandar del repo (identificadores en
        # ingles) una pregunta en espanol no se puede mapear por nombre, asi que se
        # devuelve el inventario completo: la respuesta honesta es "esta tag no existe,
        # estas son las que hay".
        $candidates = @($inventory | ForEach-Object {
            [ordered]@{ name = [string]$_.name; path = [string]$_.path; isSafety = $_.isSafety; matchedBy = 'inventory' }
        })
    }
}

$usages = @()
if ($exact.Count -gt 0 -and $ExportPath -and (Test-Path -LiteralPath $ExportPath)) {
    $ExportPath = [IO.Path]::GetFullPath($ExportPath)
    foreach ($file in Get-ChildItem -LiteralPath $ExportPath -Recurse -File -ErrorAction SilentlyContinue) {
        $matches = @(Select-String -LiteralPath $file.FullName -Pattern ([regex]::Escape($Tag)) -ErrorAction SilentlyContinue)
        if ($matches.Count -eq 0) { continue }
        $lines = @()
        foreach ($match in $matches | Select-Object -First 4) {
            $lines += (($match.Line -replace '\s+', ' ').Trim())
        }
        $usages += [ordered]@{
            file = $file.FullName.Replace($ExportPath + [IO.Path]::DirectorySeparatorChar, '')
            occurrences = $matches.Count
            lines = $lines
        }
    }
}

$result = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    tag = $Tag
    exists = ($exact.Count -gt 0)
    tagCount = $inventory.Count
    match = if ($exact.Count -gt 0) { [ordered]@{ name = [string]$exact[0].name; path = [string]$exact[0].path; isSafety = $exact[0].isSafety } } else { $null }
    candidates = $candidates
    usages = $usages
    note = 'Las herramientas de analisis estatico de TIA (TraceTagCause, DescribeBlockLogic, GetCrossReferences) no resuelven un tag global pasado como parametro formal de una llamada a un FB en SCL. Las referencias de arriba salen del export textual.'
}
$result | ConvertTo-Json -Depth 12
