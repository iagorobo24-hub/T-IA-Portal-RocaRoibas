[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
$server = Join-Path $WorkspaceRoot '30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe'
$outputPath = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-stderr-' + [guid]::NewGuid().ToString('N') + '.json')
$fakeRoot = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-stderr-child-' + [guid]::NewGuid().ToString('N'))
$fakeServerPath = Join-Path $fakeRoot 'Fake-McpServer.ps1'
$fakeOutputPath = Join-Path $fakeRoot 'report.json'
$childPidPath = Join-Path $fakeRoot 'child.pid'
$gateRoot = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-sequence-gate-' + [guid]::NewGuid().ToString('N'))
$gateServerPath = Join-Path $gateRoot 'Fake-McpServer.ps1'
$gateReportPath = Join-Path $gateRoot 'report.json'
$saveMarkerPath = Join-Path $gateRoot 'save-called-after-failure.marker'
$saveSuccessMarkerPath = Join-Path $gateRoot 'save-called-after-success.marker'

try {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw 'Generic MCP sequence script is missing.' }
    if (-not (Test-Path -LiteralPath $server -PathType Leaf)) { throw 'tia-inspect V20 runtime is missing.' }

    $calls = @(@{ name = 'GetState'; args = @{} })
    & $scriptPath -ExecutablePath $server -Arguments '--tia-major-version 20 --logging 1' `
        -Calls $calls -CaptureStderr -OutputPath $outputPath -TimeoutSeconds 30 | Out-Null

    $report = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if ($report.schemaVersion -ne 1 -or $report.calls.Count -ne 1) { throw 'MCP sequence report is incomplete.' }
    if (-not $report.success -or -not $report.calls[0].success) { throw 'Read-only GetState call did not succeed.' }
    if ([string]::IsNullOrWhiteSpace([string]$report.stderr)) { throw 'Requested stderr capture is empty.' }
    if ($report.stderr -notmatch 'Logging to stderr') { throw 'Expected MCP startup diagnostics were not captured.' }

    New-Item -ItemType Directory -Path $fakeRoot -Force | Out-Null
    @'
$ErrorActionPreference = 'Stop'
$childPidPath = $args[0]
function Write-JsonLine([object]$Value) {
    [Console]::Out.WriteLine(($Value | ConvertTo-Json -Depth 20 -Compress))
    [Console]::Out.Flush()
}
while ($line = [Console]::In.ReadLine()) {
    $request = $line | ConvertFrom-Json
    if ($request.method -eq 'initialize') {
        Write-JsonLine @{ jsonrpc = '2.0'; id = $request.id; result = @{ protocolVersion = '2025-06-18'; capabilities = @{ tools = @{} }; serverInfo = @{ name = 'stderr-test'; version = '1.0' } } }
    }
    elseif ($request.method -eq 'tools/list') {
        Write-JsonLine @{ jsonrpc = '2.0'; id = $request.id; result = @{ tools = @(@{ name = 'ImportSources'; description = 'fixture capability'; inputSchema = @{ type = 'object'; properties = @{} } }) } }
    }
    elseif ($request.method -eq 'tools/call') {
        [Console]::Error.WriteLine('partial-stderr-capture-marker')
        [Console]::Error.Flush()
        $childPath = Join-Path $PSHOME 'pwsh.exe'
        $child = Start-Process -FilePath $childPath -ArgumentList '-NoLogo -NoProfile -Command Start-Sleep -Seconds 30' -NoNewWindow -PassThru
        [IO.File]::WriteAllText($childPidPath, [string]$child.Id)
        Write-JsonLine @{ jsonrpc = '2.0'; id = $request.id; result = @{ content = @(@{ type = 'text'; text = 'fake tool result' }); structuredContent = @{ probe = $request.params.arguments.probe } } }
    }
}
'@ | Set-Content -LiteralPath $fakeServerPath -Encoding UTF8

    $pwshPath = Join-Path $PSHOME 'pwsh.exe'
    $fakeArguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $fakeServerPath + '" "' + $childPidPath + '"'
    $fakeCalls = @(
        @{ name = 'tools/list'; method = 'tools/list' },
        @{ name = 'Fake'; args = @{ probe = 'argument-forwarded' } }
    )
    & $scriptPath -ExecutablePath $pwshPath -Arguments $fakeArguments -Calls $fakeCalls -CaptureStderr -OutputPath $fakeOutputPath -TimeoutSeconds 20 | Out-Null
    $fakeReport = Get-Content -Raw -LiteralPath $fakeOutputPath | ConvertFrom-Json
    if (-not $fakeReport.success -or $fakeReport.calls.Count -ne 2 -or -not $fakeReport.calls[0].success -or -not $fakeReport.calls[1].success) { throw 'Fake MCP tool listing/call sequence did not succeed.' }
    if ($fakeReport.calls[0].response.tools[0].name -ne 'ImportSources') { throw 'MCP tools/list response was not retained in the sequence report.' }
    if ($fakeReport.calls[1].response.structuredContent.probe -ne 'argument-forwarded') { throw 'Hashtable call arguments were not forwarded to the MCP tool.' }
    if ($fakeReport.stderr -notmatch 'partial-stderr-capture-marker') { throw 'Partial stderr was lost when the child process kept the pipe open.' }

    New-Item -ItemType Directory -Path $gateRoot -Force | Out-Null
    @'
$ErrorActionPreference = 'Stop'
$saveMarkerPath = $args[0]
function Write-JsonLine([object]$Value) {
    [Console]::Out.WriteLine(($Value | ConvertTo-Json -Depth 20 -Compress))
    [Console]::Out.Flush()
}
while ($line = [Console]::In.ReadLine()) {
    $request = $line | ConvertFrom-Json
    if ($request.method -eq 'initialize') {
        Write-JsonLine @{ jsonrpc = '2.0'; id = $request.id; result = @{ protocolVersion = '2025-06-18'; capabilities = @{ tools = @{} }; serverInfo = @{ name = 'gate-test'; version = '1.0' } } }
    }
    elseif ($request.method -eq 'tools/call') {
        if ($request.params.name -eq 'CompileSoftware') {
            $requestedErrorCount = [int]$request.params.arguments.syntheticErrorCount
            $payload = @{ state = 'Success'; errorCount = $requestedErrorCount; warningCount = 0; messages = @(@{ description = 'synthetic compile result'; errorCount = $requestedErrorCount; warningCount = 0 }); meta = @{ success = $true } } | ConvertTo-Json -Depth 10 -Compress
            Write-JsonLine @{ jsonrpc = '2.0'; id = $request.id; result = @{ content = @(@{ type = 'text'; text = $payload }) } }
        }
        elseif ($request.params.name -eq 'SaveProject') {
            [IO.File]::WriteAllText([string]$request.params.arguments.markerPath, 'called')
            Write-JsonLine @{ jsonrpc = '2.0'; id = $request.id; result = @{ content = @(@{ type = 'text'; text = '{"message":"saved","meta":{"success":true}}' }) } }
        }
    }
}
'@ | Set-Content -LiteralPath $gateServerPath -Encoding UTF8

    $gateArguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $gateServerPath + '" "' + $saveMarkerPath + '"'
    $gateCalls = @(
        @{ name = 'CompileSoftware'; args = @{ softwarePath = 'PLC_1'; syntheticErrorCount = 1 }; assertJson = @{ state = 'Success'; 'meta.success' = $true; errorCount = 0; warningCount = 0; 'messages[0].errorCount' = 0 } },
        @{ name = 'SaveProject'; args = @{ markerPath = $saveMarkerPath } }
    )
    & $scriptPath -ExecutablePath $pwshPath -Arguments $gateArguments -Calls $gateCalls -OutputPath $gateReportPath -TimeoutSeconds 20 | Out-Null
    if ($LASTEXITCODE -eq 0) { throw 'A failed compile assertion should fail the MCP sequence.' }
    $gateReport = Get-Content -Raw -LiteralPath $gateReportPath | ConvertFrom-Json
    if ($gateReport.success -ne $false -or $gateReport.calls.Count -ne 1) { throw 'A failed compile assertion should stop the sequence before SaveProject.' }
    if ($gateReport.calls[0].success -ne $true -or $gateReport.calls[0].assertionsPassed -ne $false) { throw 'The report must distinguish a successful MCP call from its failed compile gate.' }
    if (Test-Path -LiteralPath $saveMarkerPath) { throw 'SaveProject ran after the compile gate reported an error.' }

    $passingCalls = @(
        @{ name = 'CompileSoftware'; args = @{ softwarePath = 'PLC_1'; syntheticErrorCount = 0 }; assertJson = @{ state = 'Success'; 'meta.success' = $true; errorCount = 0; warningCount = 0; 'messages[0].errorCount' = 0 } },
        @{ name = 'SaveProject'; args = @{ markerPath = $saveSuccessMarkerPath } }
    )
    $passingReportPath = Join-Path $gateRoot 'passing-report.json'
    & $scriptPath -ExecutablePath $pwshPath -Arguments $gateArguments -Calls $passingCalls -OutputPath $passingReportPath -TimeoutSeconds 20 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'A successful compile assertion should allow the sequence to continue.' }
    $passingReport = Get-Content -Raw -LiteralPath $passingReportPath | ConvertFrom-Json
    if (-not $passingReport.success -or $passingReport.calls.Count -ne 2 -or $passingReport.calls[0].assertionsPassed -ne $true) { throw 'A successful compile gate should pass and continue to SaveProject.' }
    if (-not (Test-Path -LiteralPath $saveSuccessMarkerPath)) { throw 'SaveProject did not run after the successful compile gate.' }

    Write-Output 'PASS: opt-in stderr capture preserves diagnostics, forwards arguments, and stops before save when a compile assertion fails.'
}
finally {
    if (Test-Path -LiteralPath $childPidPath) {
        $childPid = 0
        if ([int]::TryParse((Get-Content -Raw -LiteralPath $childPidPath), [ref]$childPid)) {
            $childProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $childPid" -ErrorAction SilentlyContinue
            if ($childProcess -and $childProcess.ExecutablePath -eq (Join-Path $PSHOME 'pwsh.exe') -and $childProcess.CommandLine -match 'Start-Sleep -Seconds 30') {
                Stop-Process -Id $childPid -Force -ErrorAction SilentlyContinue
            }
        }
    }
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $resolvedOutput = [IO.Path]::GetFullPath($outputPath)
    if ($resolvedOutput.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedOutput)) {
        Remove-Item -LiteralPath $resolvedOutput -Force
    }
    $resolvedFakeRoot = [IO.Path]::GetFullPath($fakeRoot)
    if ($resolvedFakeRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedFakeRoot)) {
        Remove-Item -LiteralPath $resolvedFakeRoot -Recurse -Force
    }
    $resolvedGateRoot = [IO.Path]::GetFullPath($gateRoot)
    if ($resolvedGateRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedGateRoot)) {
        Remove-Item -LiteralPath $resolvedGateRoot -Recurse -Force
    }
}
