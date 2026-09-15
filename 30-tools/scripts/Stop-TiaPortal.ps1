<#
.SYNOPSIS
    Cierra las instancias headless de TIA Portal que deja Openness.

.DESCRIPTION
    VERIFICADO 2026-09-14: `Disconnect` del servidor MCP NO cierra TIA Portal.
    Suelta la conexion y deja el proceso Siemens.Automation.Portal vivo,
    consumiendo ~1,3 GB.

    Eso no es necesariamente malo: una instancia caliente hace que el siguiente
    `Connect` tarde 0,3 s en vez de 28 s. Pero si no la cierras nunca, se
    acumulan.

    Este script las cierra con red de seguridad: antes de matar nada comprueba,
    a traves del propio servidor MCP, si hay un proyecto abierto. Si lo hay, se
    niega salvo que pases -Force.

.PARAMETER Force
    Cierra aunque haya un proyecto abierto. PELIGRO: los cambios no guardados
    se pierden.

.PARAMETER IncludeGui
    Cierra tambien las instancias CON ventana. Por defecto NO se tocan: una
    instancia con ventana la ha abierto la persona que esta delante, y cerrarla
    le tira el trabajo. Las instancias que arranca Openness son headless y no
    tienen ventana principal, asi que el filtro por defecto acierta.

.PARAMETER WhatIf
    Solo informa de lo que haria.

.EXAMPLE
    .\Stop-TiaPortal.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Force,
    [switch]$IncludeGui
)

$ErrorActionPreference = 'Stop'

$all = @(Get-Process 'Siemens.Automation.Portal' -ErrorAction SilentlyContinue)
if ($all.Count -eq 0) {
    Write-Host "No hay instancias de TIA Portal en marcha." -ForegroundColor Green
    return
}

Write-Host "Instancias encontradas: $($all.Count)" -ForegroundColor Cyan
foreach ($p in $all) {
    $gui = $p.MainWindowHandle -ne 0
    $tag = if ($gui) { 'CON VENTANA (de la persona)' } else { 'headless (de Openness)' }
    $col = if ($gui) { 'Yellow' } else { 'Gray' }
    Write-Host ("  PID {0,-6} {1,6:n0} MB  {2:HH:mm:ss}  {3}" -f $p.Id, ($p.WorkingSet64/1MB), $p.StartTime, $tag) -ForegroundColor $col
    if ($gui -and $p.MainWindowTitle) { Write-Host ("           {0}" -f $p.MainWindowTitle) -ForegroundColor DarkGray }
}

if ($IncludeGui) {
    Write-Host "!! -IncludeGui: se cerraran TAMBIEN las instancias con ventana." -ForegroundColor Red
    $procs = $all
} else {
    $procs = @($all | Where-Object { $_.MainWindowHandle -eq 0 })
    $skipped = $all.Count - $procs.Count
    if ($skipped -gt 0) {
        Write-Host "Se respetan $skipped instancia(s) con ventana. Cierralas tu, o usa -IncludeGui." -ForegroundColor Yellow
    }
}

if ($procs.Count -eq 0) {
    Write-Host "Nada que cerrar." -ForegroundColor Green
    return
}
Write-Host ""

# --- red de seguridad: mirar si hay un proyecto abierto ------------------
$projectOpen = $null
try {
    $r = & (Join-Path $PSScriptRoot 'Invoke-TiaMcp.ps1') -TimeoutSeconds 120 -Calls @(
        @{ name = 'Connect' }, @{ name = 'GetState' }, @{ name = 'Disconnect' }
    ) 3>$null 4>$null
    $state = $r | Where-Object { $_.Tool -eq 'GetState' } | Select-Object -First 1
    if ($state -and -not $state.IsError) {
        $parsed = $state.Text | ConvertFrom-Json
        if ($parsed.project -and $parsed.project -ne '-') { $projectOpen = $parsed.project }
    }
} catch {
    Write-Host "  (no se pudo consultar el estado via MCP: $($_.Exception.Message))" -ForegroundColor DarkYellow
    Write-Host "  Se continua, pero sin saber si hay un proyecto abierto." -ForegroundColor DarkYellow
}

if ($projectOpen) {
    Write-Host ""
    Write-Host "!! HAY UN PROYECTO ABIERTO: $projectOpen" -ForegroundColor Red
    if (-not $Force) {
        Write-Host "   No se cierra nada. Guarda desde TIA, o repite con -Force si estas seguro." -ForegroundColor Red
        return
    }
    Write-Host "   -Force indicado: se cierra igualmente. Los cambios sin guardar se pierden." -ForegroundColor Red
}

foreach ($p in $procs) {
    if ($PSCmdlet.ShouldProcess("TIA Portal PID $($p.Id)", "Cerrar")) {
        try {
            $p.CloseMainWindow() | Out-Null      # cierre limpio primero
            if (-not $p.WaitForExit(10000)) {
                Write-Host "  PID $($p.Id) no responde, se fuerza." -ForegroundColor Yellow
                $p.Kill()
                $p.WaitForExit(10000) | Out-Null
            }
            Write-Host "  PID $($p.Id) cerrado." -ForegroundColor Green
        } catch {
            Write-Host "  PID $($p.Id): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
