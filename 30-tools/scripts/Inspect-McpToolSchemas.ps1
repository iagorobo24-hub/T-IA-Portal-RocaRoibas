[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExecutablePath,
    [string]$Arguments = '',
    [string[]]$ToolName = @(),
    [string]$OutputPath,
    [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'
$ExecutablePath = [IO.Path]::GetFullPath($ExecutablePath)
if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
    throw "Executable does not exist: $ExecutablePath"
}

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
$process = $null

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

try {
    $process = [Diagnostics.Process]::Start($psi)
    $stderrTask = $process.StandardError.ReadToEndAsync()
    Send-Json ([ordered]@{
        jsonrpc = '2.0'
        id = 1
        method = 'initialize'
        params = @{
            protocolVersion = '2025-06-18'
            capabilities = @{}
            clientInfo = @{ name = 'TIA-Claude-schema-inspector'; version = '1.0' }
        }
    })
    $initialize = Read-Response 1
    if ($initialize.error) { throw "initialize failed: $($initialize.error.message)" }
    Send-Json ([ordered]@{ jsonrpc = '2.0'; method = 'notifications/initialized'; params = @{} })
    Send-Json ([ordered]@{ jsonrpc = '2.0'; id = 2; method = 'tools/list'; params = @{} })
    $listed = Read-Response 2
    if ($listed.error) { throw "tools/list failed: $($listed.error.message)" }

    $allTools = @($listed.result.tools)
    $selected = if ($ToolName.Count -gt 0) {
        @($allTools | Where-Object { $ToolName -contains $_.name })
    }
    else {
        $allTools
    }
    $missing = if ($ToolName.Count -gt 0) {
        @($ToolName | Where-Object { $_ -notin @($selected | ForEach-Object name) })
    }
    else { @() }

    $report = [ordered]@{
        schemaVersion = 1
        generatedAt = [DateTimeOffset]::Now.ToString('o')
        readOnly = $true
        executable = $ExecutablePath
        arguments = $Arguments
        listedToolCount = $allTools.Count
        requestedTools = @($ToolName)
        missingRequestedTools = @($missing)
        tools = @($selected)
    }
    $json = $report | ConvertTo-Json -Depth 40
    if ($OutputPath) {
        $OutputPath = [IO.Path]::GetFullPath($OutputPath)
        New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
        $json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    }
    Write-Output $json
}
finally {
    if ($process) {
        try { $process.StandardInput.Close() } catch { }
        if (-not $process.WaitForExit(5000)) { try { $process.Kill() } catch { } }
        if ($stderrTask) { try { $null = $stderrTask.GetAwaiter().GetResult() } catch { } }
        $process.Dispose()
    }
}

$global:LASTEXITCODE = 0
exit 0
