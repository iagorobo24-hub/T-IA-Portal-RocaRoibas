<#
.SYNOPSIS
    Executes an ordered sequence of calls against any compatible MCP stdio server.

.DESCRIPTION
    Keeps one MCP process and one protocol session for the whole sequence. This is
    important for Bootstrap -> Connect -> Attach/Open -> inspect workflows. The
    helper itself does not add write permissions; the executable arguments decide
    which tools exist. Call Bootstrap first for tia-create.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExecutablePath,
    [string]$Arguments = '',
    [Parameter()]
    [array]$Calls,
    [string]$CallsJson,
    [string]$OutputPath,
    [int]$TimeoutSeconds = 120,
    [string]$LeaseName = 'Local\TIA-Claude-McpSession',
    [int]$LeaseTimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'
$ExecutablePath = [IO.Path]::GetFullPath($ExecutablePath)
if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) { throw "Executable does not exist: $ExecutablePath" }
if ($CallsJson) { $Calls = @($CallsJson | ConvertFrom-Json) }
if (-not $Calls -or $Calls.Count -eq 0) { throw 'At least one MCP call is required.' }

$mutex = $null
$leaseAcquired = $false
$leaseCreated = $false
try {
    $mutex = [Threading.Mutex]::new($false, $LeaseName, [ref]$leaseCreated)
    $leaseAcquired = $mutex.WaitOne([TimeSpan]::FromSeconds($LeaseTimeoutSeconds))
    if (-not $leaseAcquired) {
        throw "Could not acquire MCP/TIA session lease '$LeaseName' within $LeaseTimeoutSeconds seconds."
    }
}
catch {
    if ($mutex) { $mutex.Dispose() }
    throw
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
$stderrTask = $null

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

$results = [System.Collections.Generic.List[object]]::new()
$sequenceSuccess = $true
try {
    $process = [Diagnostics.Process]::Start($psi)
    $stderrTask = $process.StandardError.ReadToEndAsync()
    Send-Json ([ordered]@{
        jsonrpc = '2.0'; id = 1; method = 'initialize'
        params = @{ protocolVersion = '2025-06-18'; capabilities = @{}; clientInfo = @{ name = 'TIA-Claude-sequence'; version = '1.0' }
        }
    })
    $initialize = Read-Response 1
    if ($initialize.error) { throw "initialize failed: $($initialize.error.message)" }
    Send-Json ([ordered]@{ jsonrpc = '2.0'; method = 'notifications/initialized'; params = @{} })

    $id = 10
    foreach ($call in $Calls) {
        $id++
        $hasArgs = $call.PSObject.Properties.Name -contains 'args'
        $args = if ($hasArgs -and $null -ne $call.args) { $call.args } else { @{} }
        Send-Json ([ordered]@{ jsonrpc = '2.0'; id = $id; method = 'tools/call'; params = @{ name = [string]$call.name; arguments = $args } })
        $response = Read-Response $id
        $isError = ($response.error -ne $null) -or ($response.result.isError -eq $true)
        $texts = @($response.result.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string]$_.text })
        $item = [ordered]@{
            name = [string]$call.name
            success = (-not $isError)
            isError = $isError
            text = ($texts -join "`n")
            response = $response.result
            error = if ($response.error) { $response.error.message } else { $null }
        }
        $results.Add($item)
        if ($isError) { $sequenceSuccess = $false; break }
    }
}
finally {
    if ($process) {
        try { $process.StandardInput.Close() } catch { }
        if (-not $process.WaitForExit(5000)) { try { $process.Kill() } catch { } }
        if ($stderrTask) { try { $null = $stderrTask.GetAwaiter().GetResult() } catch { } }
        $process.Dispose()
    }
    if ($leaseAcquired) {
        try { $mutex.ReleaseMutex() } catch { }
    }
    if ($mutex) { $mutex.Dispose() }
}

$report = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    success = $sequenceSuccess
    executable = $ExecutablePath
    arguments = $Arguments
    leaseName = $LeaseName
    leaseCreated = $leaseCreated
    leaseAcquired = $leaseAcquired
    initialize = $initialize.result
    calls = @($results)
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
