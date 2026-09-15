<#
.SYNOPSIS
    Migra los proyectos de 50-examples a TIA V20, los compila y los inventaria.

.DESCRIPTION
    Por cada proyecto:
      OpenProject (migra solo via OpenWithUpgrade) -> GetProjectTree ->
      GetPlcSummary por cada PLC -> CompileSoftware -> SaveProject -> CloseProject

    El detalle crudo va a 70-runs\migracion-<fecha>\ (un .json por proyecto,
    mas el arbol en .txt). Por pantalla solo el resumen.

    Tolera fallos: si un proyecto revienta, lo anota y sigue con el siguiente.

.PARAMETER Only
    Migra solo los proyectos cuyo nombre de carpeta contenga este texto.

.PARAMETER SkipCompile
    No compila. Util para una primera pasada rapida de inventario.

.EXAMPLE
    .\Migrate-Examples.ps1
    .\Migrate-Examples.ps1 -Only iot
#>
[CmdletBinding()]
param(
    [string]$Only,
    [switch]$SkipCompile
)

$ErrorActionPreference = 'Stop'
$root     = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$examples = Join-Path $root '50-examples'
$invoke   = Join-Path $PSScriptRoot 'Invoke-TiaMcp.ps1'
$runDir   = Join-Path $root ("70-runs\migracion-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

# --- descubrir proyectos --------------------------------------------------
# Un proyecto es un .ap1x cuya carpeta NO termina en _V20 ni .backup, y que
# todavia no tiene su carpeta <nombre>_V20 al lado: reabrir un .ap16 ya
# migrado crearia un segundo _V20 y acabariamos con duplicados.
$all = Get-ChildItem $examples -Recurse -File -Filter '*.ap1*' |
    Where-Object { $_.DirectoryName -notmatch '_V20(\.backup)?$' } |
    Sort-Object FullName

$projects = @()
foreach ($p in $all) {
    $migratedDir = Join-Path $p.Directory.Parent.FullName ($p.Directory.Name + '_V20')
    if (Test-Path $migratedDir) {
        Write-Host ("YA MIGRADO, se salta: {0}" -f $p.Directory.Name) -ForegroundColor DarkGray
    } else {
        $projects += $p
    }
}

if ($Only) { $projects = $projects | Where-Object { $_.FullName -like "*$Only*" } }

Write-Host "Proyectos a migrar: $($projects.Count)" -ForegroundColor Cyan
Write-Host "Detalle en: $runDir" -ForegroundColor DarkGray
Write-Host ""

$report = @()

foreach ($proj in $projects) {
    $label = $proj.Directory.Parent.Name + '/' + $proj.Directory.Name
    $slug  = ($label -replace '[^\w\-]', '_')
    Write-Host ("=" * 70) -ForegroundColor DarkGray
    Write-Host $label -ForegroundColor Yellow

    $row = [ordered]@{
        Proyecto = $label; Migrado = $false; PLCs = ''
        Bloques = ''; Errores = ''; Avisos = ''; Nota = ''
    }

    # --- paso 1: abrir (migra si hace falta) y leer el arbol --------------
    $r = & $invoke -TimeoutSeconds 900 -ContinueOnError -Calls @(
        @{ name = 'Connect' },
        @{ name = 'OpenProject'; args = @{ path = $proj.FullName } },
        @{ name = 'GetState' },
        @{ name = 'GetProjectTree' }
    )

    $open = $r | Where-Object { $_.Tool -eq 'OpenProject' } | Select-Object -First 1
    if (-not $open -or $open.IsError) {
        $row.Nota = "OpenProject fallo: " + ($open.Text -replace '\s+', ' ')
        Write-Host "  FALLO al abrir" -ForegroundColor Red
        $report += [pscustomobject]$row
        & $invoke -TimeoutSeconds 120 -ContinueOnError -Calls @(@{name='CloseProject'},@{name='Disconnect'}) | Out-Null
        continue
    }
    $row.Migrado = $true

    $state = $r | Where-Object { $_.Tool -eq 'GetState' } | Select-Object -First 1
    if ($state -and -not $state.IsError) {
        $row.Nota = "proyecto: " + ($state.Text | ConvertFrom-Json).project
    }

    $tree = $r | Where-Object { $_.Tool -eq 'GetProjectTree' } | Select-Object -First 1
    $softwarePaths = @()
    if ($tree -and -not $tree.IsError) {
        $treeText = ($tree.Text | ConvertFrom-Json).tree
        Set-Content (Join-Path $runDir "$slug.tree.txt") -Value $treeText -Encoding UTF8
        # Heuristica: 'PlcSoftware: <nombre>' da el softwarePath en proyectos
        # de un solo nivel. En PC stations habria que componer la ruta.
        $softwarePaths = [regex]::Matches($treeText, 'PlcSoftware:\s*(.+?)\s*\[') |
                         ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        $hmi = [regex]::Matches($treeText, 'HmiTarget:\s*(.+?)\s*\[') |
               ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        if ($hmi) { $row.Nota += " | HMI: " + ($hmi -join ',') }
    }
    $row.PLCs = ($softwarePaths -join ', ')
    Write-Host ("  PLCs: " + $(if ($softwarePaths) { $softwarePaths -join ', ' } else { '(ninguno detectado)' }))

    # --- paso 2: compilar e inventariar cada PLC -------------------------
    $blocks = 0; $errs = 0; $warns = 0; $details = @()
    foreach ($sp in $softwarePaths) {
        $calls = @()
        if (-not $SkipCompile) { $calls += @{ name = 'CompileSoftware'; args = @{ softwarePath = $sp } } }
        $calls += @{ name = 'GetPlcSummary'; args = @{ softwarePath = $sp } }

        $r2 = & $invoke -TimeoutSeconds 900 -ContinueOnError -Calls (@(@{ name = 'Connect' }) + $calls)

        $cmp = $r2 | Where-Object { $_.Tool -eq 'CompileSoftware' } | Select-Object -First 1
        if ($cmp -and -not $cmp.IsError) {
            $c = $cmp.Text | ConvertFrom-Json
            $errs  += $c.errorCount
            $warns += $c.warningCount
            Write-Host ("  {0}: compila {1} ({2} err, {3} avisos)" -f $sp, $c.state, $c.errorCount, $c.warningCount) `
                -ForegroundColor $(if ($c.errorCount -gt 0) { 'Red' } else { 'Green' })
        } elseif ($cmp) {
            Write-Host "  ${sp}: compilacion FALLO" -ForegroundColor Red
            $row.Nota += " | compile error en $sp"
        }

        $sum = $r2 | Where-Object { $_.Tool -eq 'GetPlcSummary' } | Select-Object -First 1
        if ($sum -and -not $sum.IsError) {
            $s = $sum.Text | ConvertFrom-Json
            $blocks += $s.blockCount
            $details += $s
            Write-Host ("  {0}: {1} bloques, {2} tipos, {3} tags en {4} tablas, {5} inconsistentes" -f `
                $sp, $s.blockCount, $s.typeCount, $s.tagCount, $s.tagTableCount, $s.inconsistentObjects.Count)
        }
    }
    $row.Bloques = $blocks; $row.Errores = $errs; $row.Avisos = $warns
    if ($details) { $details | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $runDir "$slug.summary.json") -Encoding UTF8 }

    # --- paso 3: guardar y cerrar ----------------------------------------
    & $invoke -TimeoutSeconds 300 -ContinueOnError -Calls @(
        @{ name = 'Connect' }, @{ name = 'SaveProject' },
        @{ name = 'CloseProject' }, @{ name = 'Disconnect' }
    ) | Out-Null

    $report += [pscustomobject]$row
}

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor DarkGray
Write-Host "RESUMEN" -ForegroundColor Cyan
$report | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
$report | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $runDir 'resumen.json') -Encoding UTF8
Write-Host "Detalle completo en: $runDir" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Recuerda cerrar TIA: .\Stop-TiaPortal.ps1" -ForegroundColor Yellow
