<#
.SYNOPSIS
    Exporta el codigo de un proyecto TIA a texto, listo para git. Receta R03.

.DESCRIPTION
    Usa ExportPlcAsSourceTree, que escribe documentos SIMATIC SD (.s7dcl/.s7res)
    en vez de XML SimaticML. Los .s7dcl son texto: se leen y diffean.

    Requiere TIA V20+ y que el PLC compile: TIA nunca exporta objetos
    inconsistentes. El script compila antes y aborta si hay errores.

.PARAMETER ProjectPath
    Ruta al .ap20. Si se omite, exporta todos los *_V20 de 50-examples.

.PARAMETER OutRoot
    Donde dejar el export. Por defecto, <carpeta del ejemplo>\src\

.EXAMPLE
    .\Export-Sources.ps1
    .\Export-Sources.ps1 -ProjectPath "...\TrafficLight_V20\TrafficLight_V20.ap20"
#>
[CmdletBinding()]
param(
    [string]$ProjectPath,
    [string]$OutRoot
)

$ErrorActionPreference = 'Stop'
$root     = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$examples = Join-Path $root '50-examples'
$invoke   = Join-Path $PSScriptRoot 'Invoke-TiaMcp.ps1'

if ($ProjectPath) {
    $targets = @(Get-Item $ProjectPath)
} else {
    $targets = Get-ChildItem $examples -Recurse -File -Filter '*.ap20' |
               Where-Object { $_.DirectoryName -notmatch '\.backup$' } |
               Sort-Object FullName
}

Write-Host "Proyectos a exportar: $($targets.Count)" -ForegroundColor Cyan
$report = @()

foreach ($t in $targets) {
    # <ejemplo>\<Proyecto>_V20\x.ap20  ->  <ejemplo>\src
    $exampleDir = $t.Directory.Parent.FullName
    $dest = if ($OutRoot) { Join-Path $OutRoot $t.Directory.Name } else { Join-Path $exampleDir 'src' }

    Write-Host ("=" * 70) -ForegroundColor DarkGray
    Write-Host $t.Directory.Name -ForegroundColor Yellow

    $row = [ordered]@{ Proyecto = $t.Directory.Name; PLC = ''; Errores = ''; Ficheros = 0; s7dcl = 0; xml = 0; Nota = '' }

    $r = & $invoke -TimeoutSeconds 900 -ContinueOnError -Calls @(
        @{ name = 'Connect' },
        @{ name = 'OpenProject'; args = @{ path = $t.FullName } },
        @{ name = 'GetProjectTree' }
    )
    $open = $r | Where-Object { $_.Tool -eq 'OpenProject' } | Select-Object -First 1
    if (-not $open -or $open.IsError) {
        $row.Nota = 'no se pudo abrir'; Write-Host "  FALLO al abrir" -ForegroundColor Red
        $report += [pscustomobject]$row; continue
    }

    $tree = $r | Where-Object { $_.Tool -eq 'GetProjectTree' } | Select-Object -First 1
    $plcs = @()
    if ($tree -and -not $tree.IsError) {
        $plcs = [regex]::Matches(($tree.Text | ConvertFrom-Json).tree, 'PlcSoftware:\s*(.+?)\s*\[') |
                ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    }
    $row.PLC = $plcs -join ', '

    foreach ($sp in $plcs) {
        # TIA no exporta objetos inconsistentes: compilar primero es obligatorio
        $rc = & $invoke -TimeoutSeconds 900 -ContinueOnError -Calls @(
            @{ name = 'Connect' },
            @{ name = 'CompileSoftware'; args = @{ softwarePath = $sp } }
        )
        $cmp = $rc | Where-Object { $_.Tool -eq 'CompileSoftware' } | Select-Object -First 1
        if ($cmp -and -not $cmp.IsError) {
            $c = $cmp.Text | ConvertFrom-Json
            $row.Errores = $c.errorCount
            if ($c.errorCount -gt 0) {
                Write-Host "  $sp NO compila ($($c.errorCount) errores): no se exporta" -ForegroundColor Red
                $row.Nota = 'no compila'
                continue
            }
        }

        $outDir = if ($plcs.Count -gt 1) { Join-Path $dest $sp } else { $dest }
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null

        $re = & $invoke -TimeoutSeconds 900 -ContinueOnError -Calls @(
            @{ name = 'Connect' },
            @{ name = 'ExportPlcAsSourceTree'; args = @{ softwarePath = $sp; exportPath = $outDir } }
        )
        $exp = $re | Where-Object { $_.Tool -eq 'ExportPlcAsSourceTree' } | Select-Object -First 1
        if ($exp -and $exp.IsError) {
            Write-Host "  $sp export FALLO: $($exp.Text)" -ForegroundColor Red
            $row.Nota += " export fallo"
        } else {
            $files = @(Get-ChildItem $outDir -Recurse -File -ErrorAction SilentlyContinue)
            $row.Ficheros += $files.Count
            $row.s7dcl    += @($files | Where-Object { $_.Extension -eq '.s7dcl' }).Count
            $row.xml      += @($files | Where-Object { $_.Extension -eq '.xml' }).Count
            Write-Host ("  {0}: {1} ficheros ({2} .s7dcl, {3} .xml)" -f $sp, $files.Count, $row.s7dcl, $row.xml) -ForegroundColor Green
        }
    }

    & $invoke -TimeoutSeconds 300 -ContinueOnError -Calls @(
        @{ name = 'Connect' }, @{ name = 'CloseProject' }, @{ name = 'Disconnect' }
    ) | Out-Null

    $report += [pscustomobject]$row
}

Write-Host ""
Write-Host "RESUMEN" -ForegroundColor Cyan
$report | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
Write-Host "Recuerda cerrar TIA: .\Stop-TiaPortal.ps1" -ForegroundColor Yellow
