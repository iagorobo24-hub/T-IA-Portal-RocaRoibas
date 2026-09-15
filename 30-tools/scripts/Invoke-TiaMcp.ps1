<#
.SYNOPSIS
    Llama a herramientas del servidor MCP tia-inspect desde la linea de comandos.

.DESCRIPTION
    Un cliente MCP minimo por stdio. Sirve para dos cosas:
      - probar el servidor sin depender de un cliente MCP ni reiniciar sesion
      - scripting: inventariar proyectos, exportar en lote, diagnosticar

    Abre el proceso, hace el handshake, ejecuta las llamadas en orden sobre la
    MISMA conexion (importante: Connect y OpenProject dejan estado en el
    servidor, asi que tienen que ir en la misma invocacion que lo que venga
    despues) y devuelve los resultados.

.PARAMETER Calls
    Array de llamadas. Cada una: @{ name = 'GetProjectTree'; args = @{ ... } }
    El campo args es opcional.

.PARAMETER TiaMajor
    Version de TIA. 20 por defecto.

.PARAMETER AllowWrite
    Arranca el servidor con --allow-write, que registra las 40 herramientas de
    escritura. SIN esta bandera no existen: el modelo no puede llamar a lo que
    no ve. Ver AGENTS.md 3.2 antes de usarla.

.PARAMETER TimeoutSeconds
    Espera maxima por llamada. Por defecto 300: arrancar TIA en frio tarda
    minutos, no segundos.

.EXAMPLE
    .\Invoke-TiaMcp.ps1 -Calls @(@{name='Doctor'})

.EXAMPLE
    .\Invoke-TiaMcp.ps1 -Calls @(
        @{ name='Connect' },
        @{ name='OpenProject'; args=@{ projectPath='C:\...\Proyecto.ap20' } },
        @{ name='GetProjectTree' },
        @{ name='Disconnect' }
    )
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [array]$Calls,

    [ValidateSet(20, 21)]
    [int]$TiaMajor = 20,

    [switch]$AllowWrite,

    # Por defecto la cadena para al primer fallo: una llamada fallida suele
    # invalidar las siguientes (sin conexion, sin proyecto abierto...). Con esta
    # bandera sigue, util para lotes donde cada item es independiente.
    [switch]$ContinueOnError,

    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'

$exe = Join-Path $PSScriptRoot "..\mcp\tia-inspect\bin\v$TiaMajor\TiaMcpServer.exe"
$exe = [System.IO.Path]::GetFullPath($exe)
if (-not (Test-Path $exe)) {
    throw "No existe $exe. Compilalo con 30-tools\mcp\tia-inspect\build.ps1 -TiaMajor $TiaMajor"
}

$serverArgs = "--tia-major-version $TiaMajor"
if ($AllowWrite) {
    Write-Host "!! MODO ESCRITURA: 40 herramientas destructivas registradas" -ForegroundColor Red
    $serverArgs += " --allow-write"
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = $exe
$psi.Arguments              = $serverArgs
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute        = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8

$proc = [System.Diagnostics.Process]::Start($psi)
$stderrTask = $proc.StandardError.ReadToEndAsync()

function Send-Line([string]$json) {
    $proc.StandardInput.Write($json + "`n")
    $proc.StandardInput.Flush()
}

# Lee lineas hasta encontrar la respuesta con este id. Las notificaciones de
# progreso y los logs que puedan llegar por stdout se descartan.
function Read-Response([int]$id, [int]$timeoutSec) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        $task = $proc.StandardOutput.ReadLineAsync()
        $remaining = [int]((($deadline) - (Get-Date)).TotalMilliseconds)
        if ($remaining -le 0) { break }
        if (-not $task.Wait($remaining)) { break }
        $line = $task.Result
        if ($null -eq $line) { throw "El servidor cerro stdout inesperadamente" }
        if (-not $line.Trim()) { continue }
        try { $obj = $line | ConvertFrom-Json } catch { continue }
        if ($obj.PSObject.Properties.Name -contains 'id' -and $obj.id -eq $id) { return $obj }
    }
    throw "Timeout de ${timeoutSec}s esperando la respuesta id=$id"
}

try {
    # --- handshake -------------------------------------------------------
    $init = @{
        jsonrpc = '2.0'; id = 1; method = 'initialize'
        params  = @{
            protocolVersion = '2025-06-18'
            capabilities    = @{}
            clientInfo      = @{ name = 'Invoke-TiaMcp'; version = '1.0' }
        }
    } | ConvertTo-Json -Depth 10 -Compress
    Send-Line $init
    $r = Read-Response 1 30
    Write-Host ("Conectado a {0} v{1} (MCP {2})" -f `
        $r.result.serverInfo.name, $r.result.serverInfo.version, $r.result.protocolVersion) -ForegroundColor DarkGray

    Send-Line (@{ jsonrpc = '2.0'; method = 'notifications/initialized' } | ConvertTo-Json -Compress)

    # --- llamadas --------------------------------------------------------
    $id = 10
    $results = @()
    foreach ($call in $Calls) {
        $id++
        $params = @{ name = $call.name }
        if ($call.ContainsKey('args') -and $call.args) { $params.arguments = $call.args }

        $req = @{ jsonrpc = '2.0'; id = $id; method = 'tools/call'; params = $params } |
               ConvertTo-Json -Depth 20 -Compress

        Write-Host "-> $($call.name)" -ForegroundColor Cyan
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Send-Line $req
        $resp = Read-Response $id $TimeoutSeconds
        $sw.Stop()

        $isError = $false
        $text = $null
        if ($resp.PSObject.Properties.Name -contains 'error') {
            $isError = $true
            $text = $resp.error.message
        } else {
            $isError = [bool]$resp.result.isError
            $text = ($resp.result.content | Where-Object { $_.type -eq 'text' } |
                     ForEach-Object { $_.text }) -join "`n"
        }

        $color = if ($isError) { 'Red' } else { 'Green' }
        Write-Host ("   {0}  {1:n1}s" -f $(if ($isError) { 'ERROR' } else { 'ok' }), $sw.Elapsed.TotalSeconds) -ForegroundColor $color

        $results += [pscustomobject]@{
            Tool    = $call.name
            IsError = $isError
            Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            Text    = $text
            Raw     = $resp.result
        }

        if ($isError -and -not $ContinueOnError) {
            Write-Host "   Se detiene la cadena tras el fallo." -ForegroundColor Yellow
            break
        }
    }
    return $results
}
finally {
    try { $proc.StandardInput.Close() } catch {}
    if (-not $proc.WaitForExit(5000)) { try { $proc.Kill() } catch {} }
    try { $null = $stderrTask.GetAwaiter().GetResult() } catch {}
}
