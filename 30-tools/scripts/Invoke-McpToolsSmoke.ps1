<##
.SYNOPSIS
    Comprueba que un servidor MCP arranca y publica herramientas concretas.

.DESCRIPTION
    Smoke test de transporte stdio. No abre TIA ni llama herramientas de proyecto:
    solo ejecuta initialize y tools/list. Es seguro para verificar runtimes MCP.
##>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExecutablePath,
    [string]$Arguments = '',
    [string[]]$ExpectedTool = @(),
    [string]$OutputPath,
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
$ExecutablePath = [IO.Path]::GetFullPath($ExecutablePath)
if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) { throw "Executable does not exist: $ExecutablePath" }

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
    $process.StandardInput.WriteLine(($Payload | ConvertTo-Json -Depth 20 -Compress))
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
        params = @{ protocolVersion = '2025-06-18'; capabilities = @{}; clientInfo = @{ name = 'TIA-Claude-smoke'; version = '1.0' } }
    })
    $initialize = Read-Response 1
    if ($initialize.error) { throw "initialize failed: $($initialize.error.message)" }
    Send-Json ([ordered]@{ jsonrpc = '2.0'; method = 'notifications/initialized'; params = @{} })
    Send-Json ([ordered]@{ jsonrpc = '2.0'; id = 2; method = 'tools/list'; params = @{} })
    $list = Read-Response 2
    if ($list.error) { throw "tools/list failed: $($list.error.message)" }
    $names = @($list.result.tools | ForEach-Object { [string]$_.name })
    $missing = @($ExpectedTool | Where-Object { $_ -notin $names })
    $report = [ordered]@{
        schemaVersion = 1
        success = ($missing.Count -eq 0)
        executable = $ExecutablePath
        arguments = $Arguments
        serverInfo = $initialize.result.serverInfo
        toolCount = $names.Count
        tools = $names
        expectedTools = @($ExpectedTool)
        missingTools = $missing
    }
}
finally {
    try { $process.StandardInput.Close() } catch { }
    if (-not $process.WaitForExit(5000)) { try { $process.Kill() } catch { } }
    try { $null = $stderrTask.GetAwaiter().GetResult() } catch { }
    $process.Dispose()
}

$json = $report | ConvertTo-Json -Depth 20
if ($OutputPath) {
    $OutputPath = [IO.Path]::GetFullPath($OutputPath)
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
    $json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
Write-Output $json
if (-not $report.success) { exit 1 }
exit 0
