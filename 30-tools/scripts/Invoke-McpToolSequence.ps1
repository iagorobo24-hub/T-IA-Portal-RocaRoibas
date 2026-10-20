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
    [string]$CallsJsonPath,
    [string]$OutputPath,
    [switch]$CaptureStderr,
    [int]$TimeoutSeconds = 120,
    [string]$LeaseName = 'Local\TIA-Claude-McpSession',
    [int]$LeaseTimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'
$ExecutablePath = [IO.Path]::GetFullPath($ExecutablePath)
if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) { throw "Executable does not exist: $ExecutablePath" }
# An isolated sequence owns the Openness session it opens: it is the only mode in which
# the runner may close a project or a TIA Portal process on the way out. In attach mode the
# visible TIA window belongs to the user and must never be closed by this script.
$isIsolated = $false
if ($Arguments -match '(?i)(?:^|\s)--isolated(?:\s|$)') {
    $isIsolated = $true
    if ($Arguments -notmatch '(?i)(?:^|\s)--fixture-root\s+(?:"([^"]+)"|(\S+))') {
        throw 'An isolated MCP sequence requires --fixture-root with a valid disposable fixture manifest.'
    }
    $fixtureRoot = if ($Matches[1]) { $Matches[1] } else { $Matches[2] }
    $manifestValidator = Join-Path $PSScriptRoot 'Assert-TiaFixtureManifest.ps1'
    if (-not (Test-Path -LiteralPath $manifestValidator -PathType Leaf)) { throw "Fixture manifest validator is missing: $manifestValidator" }
    $null = & $manifestValidator -FixtureRoot $fixtureRoot
}
# ConvertFrom-Json returns a JSON array as a single object, so wrapping the pipeline
# inline would nest the whole call list as element 0. Flatten explicitly.
$parsedCalls = $null
if ($CallsJsonPath) {
    if (-not (Test-Path -LiteralPath $CallsJsonPath -PathType Leaf)) { throw "Calls JSON file does not exist: $CallsJsonPath" }
    $parsedCalls = Get-Content -Raw -LiteralPath $CallsJsonPath | ConvertFrom-Json
} elseif ($CallsJson) { $parsedCalls = $CallsJson | ConvertFrom-Json }
if ($null -ne $parsedCalls) { $Calls = @($parsedCalls | ForEach-Object { $_ }) }
if (-not $Calls -or $Calls.Count -eq 0) { throw 'At least one MCP call is required.' }

# tia-inspect marks a headless session with the --isolated flag; tia-create marks it with the
# ConnectIsolated tool. Both open an Openness session that this script owns, so both are allowed
# to close their project and their TIA Portal process on the way out. An attach session (the user
# has TIA open) is detected by the absence of both and is never closed by this script.
if (-not $isIsolated) {
    foreach ($candidate in $Calls) {
        $candidateName = $null
        if ($candidate -is [System.Collections.IDictionary]) {
            if ($candidate.Contains('name')) { $candidateName = [string]$candidate['name'] }
        }
        else {
            $candidateProperty = $candidate.PSObject.Properties['name']
            if ($candidateProperty) { $candidateName = [string]$candidateProperty.Value }
        }
        if ($candidateName -eq 'ConnectIsolated') { $isIsolated = $true; break }
    }
}

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

function Read-Response([int]$Id, [int]$TimeoutOverride = 0) {
    $effectiveTimeout = if ($TimeoutOverride -gt 0) { $TimeoutOverride } else { $TimeoutSeconds }
    $deadline = (Get-Date).AddSeconds($effectiveTimeout)
    $stdoutReadTask = $null
    while ((Get-Date) -lt $deadline) {
        Pump-Stderr
        $remaining = [int]((($deadline) - (Get-Date)).TotalMilliseconds)
        if ($remaining -le 0) { break }
        # One pending read at a time: a line that is not our response (server noise,
        # a stale id) must advance to the next line instead of being re-read for the
        # whole timeout, which used to look like a hang.
        if ($null -eq $stdoutReadTask) { $stdoutReadTask = $process.StandardOutput.ReadLineAsync() }
        if (-not $stdoutReadTask.Wait([Math]::Min(50, [Math]::Max(1, $remaining)))) { continue }
        $line = $stdoutReadTask.Result
        $stdoutReadTask = $null
        if ($null -eq $line) { break }
        if (-not $line.Trim()) { continue }
        try { $json = $line | ConvertFrom-Json } catch { continue }
        if ($json.id -eq $Id) { return $json }
    }
    throw "Timeout waiting for MCP response id=$Id"
}

$results = [System.Collections.Generic.List[object]]::new()
$sequenceSuccess = $true
$sequenceError = $null
# Snapshot the TIA Portal processes that already exist. Anything that appears later and is
# not in this set was started by this run (an isolated Openness session spawns its own headless
# Portal) and may be closed on the way out. A TIA window the user opened before the run stays
# untouched, which is what keeps attach mode safe.
$tiaProcessesBefore = @()
if ($isIsolated) {
    $tiaProcessesBefore = @(Get-Process -Name 'Siemens.Automation.Portal' -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
}
$cleanup = [ordered]@{
    attempted = $false
    projectClosed = $false
    sessionDisconnected = $false
    closedTiaProcessIds = @()
    notes = @()
}
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
        if ($isError -or ($hasAssertions -and -not $assertionsPassed)) { $sequenceSuccess = $false; break }
    }
}
catch {
    # Record the failure instead of aborting before the report: callers read a failed
    # sequence's error/stderr for diagnostics, and losing it makes failures opaque.
    $sequenceSuccess = $false
    $sequenceError = $_.Exception.Message
}
finally {
    if ($process -and -not $process.HasExited -and $isIsolated) {
        # The sequence aborts on the first failed call, so the CloseProject/Disconnect entries
        # queued after it never run and the Openness session stays open with the project
        # loaded. The next session then fails with "already been opened ... 2 minute delay".
        # Close the session over the still-alive channel before the server is killed.
        $cleanup.attempted = $true
        $cleanupId = 900
        foreach ($cleanupTool in @('CloseProject', 'Disconnect')) {
            try {
                $cleanupId++
                Send-Json ([ordered]@{
                    jsonrpc = '2.0'; id = $cleanupId; method = 'tools/call'
                    params = @{ name = $cleanupTool; arguments = @{} }
                })
                $cleanupResponse = Read-Response -Id $cleanupId -TimeoutOverride 20
                $cleanupOk = ($null -eq $cleanupResponse.error)
                if ($cleanupTool -eq 'CloseProject') { $cleanup.projectClosed = $cleanupOk }
                else { $cleanup.sessionDisconnected = $cleanupOk }
            }
            catch {
                $cleanup.notes += "$cleanupTool failed: $($_.Exception.Message)"
            }
        }
    }
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
    if ($isIsolated) {
        # Last resort: an isolated Openness session can leave a headless Portal process behind
        # holding the project open. Close only the ones this run started.
        try {
            $orphans = @(Get-Process -Name 'Siemens.Automation.Portal' -ErrorAction SilentlyContinue |
                Where-Object { $tiaProcessesBefore -notcontains $_.Id })
            foreach ($orphan in $orphans) {
                $closed = $false
                try { $closed = $orphan.CloseMainWindow() } catch { $closed = $false }
                if ($closed) {
                    if (-not $orphan.WaitForExit(15000)) { try { $orphan.Kill() } catch { } }
                }
                else {
                    try { $orphan.Kill() } catch { }
                }
                # A killed Portal can take a moment to disappear; wait so the report lists
                # only processes that were really gone and the next session is not blocked.
                $exited = $true
                try { $exited = $orphan.WaitForExit(10000) } catch { $exited = $true }
                if ($exited) { $cleanup.closedTiaProcessIds += [int]$orphan.Id }
                else { $cleanup.notes += "TIA Portal process $($orphan.Id) did not exit after close/kill." }
            }
        }
        catch {
            $cleanup.notes += "closing orphaned TIA processes failed: $($_.Exception.Message)"
        }
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
    error = $sequenceError
    executable = $ExecutablePath
    arguments = $Arguments
    leaseName = $LeaseName
    leaseCreated = $leaseCreated
    leaseAcquired = $leaseAcquired
    initialize = $initialize.result
    calls = @($results)
    cleanup = $cleanup
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
