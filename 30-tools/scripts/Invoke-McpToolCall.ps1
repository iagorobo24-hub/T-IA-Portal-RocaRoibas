<##
.SYNOPSIS
    Ejecuta una unica llamada MCP contra un servidor stdio y devuelve su resultado.

.DESCRIPTION
    Cliente minimo para smoke tests y fixtures. Inicializa el servidor, llama una
    herramienta y cierra el proceso. No añade permisos: el ejecutable y sus
    argumentos determinan el perfil. Para ScaffoldProject, el primer paso debe
    ser siempre dryRun=true.
##>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExecutablePath,
    [string]$Arguments = '',
    [Parameter(Mandatory = $true)]
    [string]$ToolName,
    [Parameter(Mandatory = $true)]
    [string]$ToolArgumentsJson,
    [string]$OutputPath,
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$ExecutablePath = [IO.Path]::GetFullPath($ExecutablePath)
if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) { throw "Executable does not exist: $ExecutablePath" }
$toolArguments = $ToolArgumentsJson | ConvertFrom-Json

$psi = [Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $ExecutablePath
$psi.Arguments = $Arguments
$psi.WorkingDirectory = Split-Path -Parent $ExecutablePath
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [Text.Encoding]::UTF8
$process = [Diagnostics.Process]::Start($psi)
$stderrTask = $process.StandardError.ReadToEndAsync()

function Send-Json([object]$Payload) {
    $process.StandardInput.WriteLine(($Payload | ConvertTo-Json -Depth 30 -Compress))
    $process.StandardInput.Flush()
}

function Read-Response([int]$Id) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $remaining = [int]((($deadline) - (Get-Date)).TotalMilliseconds)
        if ($remaining -le 0) { break }
        $read = $process.StandardOutput.ReadLineAsync()
        if (-not $read.Wait($remaining)) { break }
        $line = $read.Result
        if ($null -eq $line) { break }
        if (-not $line.Trim()) { continue }
        try { $json = $line | ConvertFrom-Json } catch { continue }
        if ($json.id -eq $Id) { return $json }
    }
    throw "Timeout waiting for MCP response id=$Id"
}

$report = $null
try {
    Send-Json ([ordered]@{
        jsonrpc = '2.0'; id = 1; method = 'initialize'
        params = @{ protocolVersion = '2025-06-18'; capabilities = @{}; clientInfo = @{ name = 'TIA-Claude-call'; version = '1.0' } }
    })
    $init = Read-Response 1
    if ($init.error) { throw "initialize failed: $($init.error.message)" }
    Send-Json ([ordered]@{ jsonrpc = '2.0'; method = 'notifications/initialized'; params = @{} })
    Send-Json ([ordered]@{
        jsonrpc = '2.0'; id = 2; method = 'tools/call'
        params = @{ name = $ToolName; arguments = $toolArguments }
    })
    $response = Read-Response 2
    $isError = ($response.error -ne $null) -or ($response.result.isError -eq $true)
    $texts = @($response.result.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string]$_.text })
    $report = [ordered]@{
        schemaVersion = 1
        success = (-not $isError)
        executable = $ExecutablePath
        arguments = $Arguments
        toolName = $ToolName
        toolResponseIsError = $isError
        text = ($texts -join "`n")
        initialize = $init.result
        response = $response.result
        error = if ($response.error) { $response.error.message } else { $null }
    }
}
finally {
    try { $process.StandardInput.Close() } catch { }
    if (-not $process.WaitForExit(5000)) { try { $process.Kill() } catch { } }
    try { $null = $stderrTask.GetAwaiter().GetResult() } catch { }
    $process.Dispose()
}

$json = $report | ConvertTo-Json -Depth 30
if ($OutputPath) {
    $OutputPath = [IO.Path]::GetFullPath($OutputPath)
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
    $json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
Write-Output $json
if (-not $report.success) { exit 1 }
exit 0
