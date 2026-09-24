<#
.SYNOPSIS
    Executes an ordered sequence of calls against any compatible MCP stdio server.

.DESCRIPTION
    Keeps one MCP process and one protocol session for the whole sequence. This is
    important for Bootstrap -> Connect -> Attach/Open -> inspect workflows. The
    helper itself does not add write permissions; the executable arguments decide
    which tools exist. Call Bootstrap first for tia-create. Sequence entries default
    to MCP `tools/call`; set `method='tools/list'` to capture the active tool roster.
    A call may include an `assertJson` map of JSON paths and expected values; if any
    assertion fails, the sequence stops before sending the next request.
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
    [switch]$CaptureStderr,
    # Solo para inventario de capacidades en fixture de lectura. Ver el comentario en el bucle.
    [switch]$ContinueOnError,
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
$stderrLines = [System.Collections.Generic.List[string]]::new()
$stderrReadTask = $null
$stderrEnded = $false
$stderrText = $null
$stderrCaptureComplete = $false

function Pump-Stderr {
    if (-not $CaptureStderr -or -not $script:stderrReadTask) { return }
    while ($script:stderrReadTask.IsCompleted) {
        try { $line = $script:stderrReadTask.Result }
        catch { $script:stderrEnded = $true; $script:stderrReadTask = $null; return }
        if ($null -eq $line) {
            $script:stderrEnded = $true
            $script:stderrReadTask = $null
            return
        }
        $script:stderrLines.Add([string]$line)
        $script:stderrReadTask = $script:process.StandardError.ReadLineAsync()
    }
}

function Send-Json([object]$Payload) {
    $process.StandardInput.WriteLine(($Payload | ConvertTo-Json -Depth 30 -Compress))
    $process.StandardInput.Flush()
}

function Get-JsonPathValue([object]$InputObject, [string]$Path) {
    $tokens = [regex]::Matches($Path, '[^\.\[\]]+')
    if ($tokens.Count -eq 0) { return [pscustomobject]@{ exists = $false; value = $null } }
    $current = $InputObject
    foreach ($tokenMatch in $tokens) {
        $token = $tokenMatch.Value
        if ($token -match '^\d+$') {
            $index = [int]$token
            if ($current -isnot [System.Collections.IList] -or $index -lt 0 -or $index -ge $current.Count) {
                return [pscustomobject]@{ exists = $false; value = $null }
            }
            $current = $current[$index]
            continue
        }

        if ($current -is [System.Collections.IDictionary]) {
            $found = $false
            foreach ($key in $current.Keys) {
                if ([string]$key -ceq $token) {
                    $current = $current[$key]
                    $found = $true
                    break
                }
            }
            if (-not $found) { return [pscustomobject]@{ exists = $false; value = $null } }
            continue
        }

        $property = @($current.PSObject.Properties | Where-Object { $_.Name -ceq $token }) | Select-Object -First 1
        if (-not $property) { return [pscustomobject]@{ exists = $false; value = $null } }
        $current = $property.Value
    }
    return [pscustomobject]@{ exists = $true; value = $current }
}

function Test-JsonAssertions([object]$Payload, [object]$Assertions) {
    $failures = [System.Collections.Generic.List[string]]::new()
    if ($Assertions -is [System.Collections.IDictionary]) {
        $assertionProperties = @($Assertions.Keys | ForEach-Object { [pscustomobject]@{ Name = [string]$_; Value = $Assertions[$_] } })
    }
    else {
        $assertionProperties = @($Assertions.PSObject.Properties | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Value = $_.Value } })
    }

    foreach ($assertion in $assertionProperties) {
        $actual = Get-JsonPathValue -InputObject $Payload -Path $assertion.Name
        if (-not $actual.exists) {
            $failures.Add("JSON path '$($assertion.Name)' is missing.")
            continue
        }
        $actualJson = ConvertTo-Json -InputObject $actual.value -Depth 30 -Compress
        $expectedJson = ConvertTo-Json -InputObject $assertion.Value -Depth 30 -Compress
        if ($actualJson -cne $expectedJson) {
            $failures.Add("JSON path '$($assertion.Name)' expected $expectedJson but got $actualJson.")
        }
    }
    return [pscustomobject]@{ passed = ($failures.Count -eq 0); failures = @($failures) }
}

function Read-Response([int]$Id) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $stdoutReadTask = $process.StandardOutput.ReadLineAsync()
    while ((Get-Date) -lt $deadline) {
        Pump-Stderr
        $remaining = [int]((($deadline) - (Get-Date)).TotalMilliseconds)
        if ($remaining -le 0) { break }
        if (-not $stdoutReadTask.Wait([Math]::Min(50, $remaining))) { continue }
        $line = $stdoutReadTask.Result
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
    if ($CaptureStderr) {
        $stderrReadTask = $process.StandardError.ReadLineAsync()
    }
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
        $assertions = $null
        $hasAssertions = $false
        if ($call -is [System.Collections.IDictionary]) {
            $callName = [string]$call['name']
            $hasMethod = $call.Contains('method')
            $rpcMethod = if ($hasMethod -and -not [string]::IsNullOrWhiteSpace([string]$call['method'])) { [string]$call['method'] } else { 'tools/call' }
            $hasArgs = $call.Contains('args')
            $callArgs = if ($hasArgs -and $null -ne $call['args']) { $call['args'] } else { @{} }
            $hasAssertions = $call.Contains('assertJson')
            if ($hasAssertions) { $assertions = $call['assertJson'] }
        }
        else {
            $nameProperty = $call.PSObject.Properties['name']
            if (-not $nameProperty) { throw 'Each MCP sequence call must include a name.' }
            $callName = [string]$nameProperty.Value
            $methodProperty = $call.PSObject.Properties['method']
            $rpcMethod = if ($methodProperty -and -not [string]::IsNullOrWhiteSpace([string]$methodProperty.Value)) { [string]$methodProperty.Value } else { 'tools/call' }
            $argsProperty = $call.PSObject.Properties['args']
            $callArgs = if ($argsProperty -and $null -ne $argsProperty.Value) { $argsProperty.Value } else { @{} }
            $assertionsProperty = $call.PSObject.Properties['assertJson']
            $hasAssertions = [bool]$assertionsProperty
            if ($hasAssertions) { $assertions = $assertionsProperty.Value }
        }
        if ([string]::IsNullOrWhiteSpace($callName)) { throw 'Each MCP sequence call must include a non-empty name.' }
        if ($rpcMethod -notin @('tools/call', 'tools/list')) { throw "Unsupported MCP sequence method '$rpcMethod'." }
        $requestParams = if ($rpcMethod -eq 'tools/list') { $callArgs } else { @{ name = $callName; arguments = $callArgs } }
        Send-Json ([ordered]@{ jsonrpc = '2.0'; id = $id; method = $rpcMethod; params = $requestParams })
        $response = Read-Response $id
        $isError = ($response.error -ne $null) -or ($response.result.isError -eq $true)
        $texts = @($response.result.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string]$_.text })
        $item = [ordered]@{
            name = $callName
            success = (-not $isError)
            isError = $isError
            text = ($texts -join "`n")
            response = $response.result
            error = if ($response.error) { $response.error.message } else { $null }
            assertionsPassed = $null
            assertionErrors = @()
        }
        $assertionsPassed = $true
        if ($hasAssertions) {
            if ($isError) {
                $assertionsPassed = $false
                $item.assertionErrors = @('Tool call failed; JSON assertions were not evaluated.')
            }
            else {
                try {
                    $payload = $item.text | ConvertFrom-Json
                    $assertionResult = Test-JsonAssertions -Payload $payload -Assertions $assertions
                    $assertionsPassed = [bool]$assertionResult.passed
                    $item.assertionErrors = @($assertionResult.failures)
                }
                catch {
                    $assertionsPassed = $false
                    $item.assertionErrors = @("Tool result is not valid JSON for assertions: $($_.Exception.Message)")
                }
            }
            $item.assertionsPassed = $assertionsPassed
        }
        $results.Add($item)
        if ($isError -or ($hasAssertions -and -not $assertionsPassed)) {
            $sequenceSuccess = $false
            # -ContinueOnError existe para el inventario de capacidades: recorrer un roster entero y
            # registrar cual falla es justo lo que se quiere medir, y parar en la primera obligaria a
            # reabrir TIA por cada herramienta. NO usarlo en secuencias que muten un proyecto: ahi
            # una llamada fallida debe detener el resto. El informe sigue marcando success=false.
            if (-not $ContinueOnError) { break }
        }
    }
}
finally {
    if ($process) {
        try { $process.StandardInput.Close() } catch { }
        if (-not $process.WaitForExit(5000)) { try { $process.Kill() } catch { } }
        # TIA Portal child processes may inherit stderr and keep the pipe open after
        # the MCP server exits. Drain incrementally for a bounded interval, retaining lines
        # already received even when EOF has not arrived.
        if ($CaptureStderr) {
            $drainDeadline = (Get-Date).AddSeconds(1)
            while (-not $script:stderrEnded -and (Get-Date) -lt $drainDeadline) {
                Pump-Stderr
                if ($script:stderrReadTask -and -not $script:stderrReadTask.IsCompleted) { [void]$script:stderrReadTask.Wait(50) }
            }
            Pump-Stderr
            $stderrText = $script:stderrLines -join [Environment]::NewLine
            $stderrCaptureComplete = $script:stderrEnded
        }
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
if ($CaptureStderr) {
    $report.stderr = $stderrText
    $report.stderrCaptureComplete = $stderrCaptureComplete
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
