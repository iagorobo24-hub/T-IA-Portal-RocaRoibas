[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Invoke-TiaSimulationAcceptance.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-simulation-acceptance-test-' + [guid]::NewGuid().ToString('N'))
$readinessPath = Join-Path $temp 'readiness.json'
$reportPath = Join-Path $temp 'acceptance.json'

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    [ordered]@{
        schemaVersion = 1
        status = 'READY_WITH_BLOCKERS'
        gates = [ordered]@{
            plcToolchainReady = $true
            plcsimVirtualAdapterReady = $false
            hmiRuntimeAdvancedV20Ready = $false
            plcBehaviorVerified = $false
            tiaInstanceSafeForApply = $false
        }
        blockers = @('El adaptador virtual Siemens PLCSIM no está operativo')
        nextActions = @('Activar el adaptador virtual')
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $readinessPath -Encoding UTF8

    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }
    & $pwsh -NoProfile -NonInteractive -File $script -ReadinessPath $readinessPath -OutputPath $reportPath -Run 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 2) { throw "Blocked preflight must exit 2, got $LASTEXITCODE." }
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'Acceptance report was not created.' }

    $report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
    if ($report.status -ne 'BLOCKED' -or $report.phase -ne 'PREFLIGHT') {
        throw 'Acceptance runner did not record a blocked preflight.'
    }
    if ($report.mutationAttempted -ne $false) { throw 'Blocked preflight must not attempt mutation.' }
    if (@($report.blockers) -notcontains 'El adaptador virtual Siemens PLCSIM no está operativo') {
        throw 'Readiness blocker was not propagated to the acceptance report.'
    }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance refuses to run before all readiness gates are true'

    $fixtureServer = Join-Path $temp 'mcp-fixture.ps1'
    @'
$ErrorActionPreference = 'Stop'
while ($line = [Console]::In.ReadLine()) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $request = $line | ConvertFrom-Json
    if ($request.method -eq 'notifications/initialized') { continue }
    if ($request.method -eq 'initialize') {
        $result = [ordered]@{ protocolVersion = '2025-06-18'; capabilities = @{}; serverInfo = @{ name = 'tia-claude-fixture'; version = '1.0' } }
    }
    elseif ($request.method -eq 'tools/call') {
        $name = [string]$request.params.name
        switch ($name) {
            'GetProjectTree' { $payload = [ordered]@{ tree = "Fixture Project`n└── Fixture PLC [PLC Program]"; message = 'Project tree retrieved' } }
            'CheckDownloadReadiness' { $payload = [ordered]@{ Ready = $true; IsConsistent = $true; Message = 'ready'; Meta = @{ downloadRoutes = @(@{ pgPcInterface = 'Siemens PLCSIM Virtual Ethernet Adapter'; preferred = $true; targetInterface = '1 X1' }) } } }
            'DownloadToPlc' { $payload = [ordered]@{ State = 'Success'; Message = 'downloaded to virtual target' } }
            'GetOnlineState' { $payload = [ordered]@{ State = 'Online'; Message = 'online' } }
            default { $payload = [ordered]@{ success = $true; message = $name } }
        }
        $result = [ordered]@{ content = @(@{ type = 'text'; text = ($payload | ConvertTo-Json -Depth 20 -Compress) }) }
    }
    else { $result = [ordered]@{ content = @(@{ type = 'text'; text = '{"success":true}' }) } }
    [ordered]@{ jsonrpc = '2.0'; id = $request.id; result = $result } | ConvertTo-Json -Depth 30 -Compress
}
'@ | Set-Content -LiteralPath $fixtureServer -Encoding UTF8

    $readyPath = Join-Path $temp 'ready.json'
    [ordered]@{
        schemaVersion = 1
        status = 'READY_WITH_BLOCKERS'
        gates = [ordered]@{
            plcToolchainReady = $true
            plcsimVirtualAdapterReady = $true
            hmiRuntimeAdvancedV20Ready = $false
            plcBehaviorVerified = $false
            tiaInstanceSafeForApply = $true
        }
        blockers = @()
        nextActions = @()
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $readyPath -Encoding UTF8
    $projectFile = Join-Path $temp 'Fixture.ap20'
    'fixture project' | Set-Content -LiteralPath $projectFile -Encoding UTF8
    $positiveReportPath = Join-Path $temp 'positive.json'
    $fixtureArguments = ' -NoProfile -NonInteractive -File "' + $fixtureServer + '"'
    $fixtureOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $positiveReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -McpExecutablePath $pwsh -McpArguments $fixtureArguments -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Fixture acceptance run failed with exit code $LASTEXITCODE. Output: $fixtureOutput" }
    $positive = Get-Content -Raw -LiteralPath $positiveReportPath | ConvertFrom-Json
    if ($positive.status -ne 'VERIFIED' -or $positive.mutationAttempted -ne $true) { throw 'Fixture acceptance did not reach verified download state.' }
    $downloadCall = @($positive.calls | Where-Object name -eq 'DownloadToPlc')
    if ($downloadCall.Count -ne 1) { throw 'Fixture acceptance did not execute exactly one DownloadToPlc call.' }
    if (@($positive.preflight.selectedRoutes).Count -ne 1) { throw 'Fixture acceptance did not record the selected PLCSIM route.' }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance validates the virtual route before one guarded download'

    $notReadyAdapter = Join-Path $temp 'not-ready-adapter.ps1'
    $notReadyPidPath = Join-Path $temp 'not-ready.pid'
    $escapedPidPath = $notReadyPidPath.Replace("'", "''")
    $notReadyScript = @'
Set-Content -LiteralPath '__PID_PATH__' -Value $PID -Encoding ASCII
[Console]::Out.WriteLine('{"status":"error","message":"fixture adapter refused registration"}')
[Console]::Out.Flush()
while ($line = [Console]::In.ReadLine()) {
    if ($line -eq 'stop' -or $line -eq 'quit') { break }
}
'@ -replace '__PID_PATH__', $escapedPidPath
    $notReadyScript | Set-Content -LiteralPath $notReadyAdapter -Encoding UTF8
    $notReadyReportPath = Join-Path $temp 'not-ready.json'
    $notReadyArguments = ' -NoProfile -NonInteractive -File "' + $notReadyAdapter + '"'
    $notReadyOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $notReadyReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -McpExecutablePath $pwsh -McpArguments $fixtureArguments -PlcSimAdapterPath $pwsh `
        -PlcSimAdapterArguments $notReadyArguments -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 1) { throw "Non-ready adapter must fail with exit code 1. Output: $notReadyOutput" }
    if (-not (Test-Path -LiteralPath $notReadyPidPath -PathType Leaf)) { throw 'Non-ready adapter did not publish its PID.' }
    $notReadyPid = [int](Get-Content -Raw -LiteralPath $notReadyPidPath)
    $orphan = Get-Process -Id $notReadyPid -ErrorAction SilentlyContinue
    if ($orphan) {
        try { $orphan.Kill() } catch { }
        throw 'Non-ready virtual PLC process was left running after startup failure.'
    }
    $notReady = Get-Content -Raw -LiteralPath $notReadyReportPath | ConvertFrom-Json
    if ($notReady.phase -ne 'VIRTUAL_PLC_START' -or $notReady.mutationAttempted -ne $false) {
        throw 'Non-ready adapter failure was not recorded as a pre-mutation startup failure.'
    }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance cleans up a virtual PLC that fails readiness'

    $adapterFixture = Join-Path $temp 'adapter-fixture.ps1'
    @'
[Console]::Out.WriteLine('{"status":"ready","instanceName":"FixtureVirtualPlc","interfaceName":"Fixture PLCSIM","ip":"192.168.0.1"}')
[Console]::Out.Flush()
while ($line = [Console]::In.ReadLine()) {
    if ($line -eq 'stop' -or $line -eq 'quit') {
        [Console]::Out.WriteLine('{"status":"stopped","powerOffCode":"0x0","unregisterCode":"0x0","destroyCode":"0x0"}')
        [Console]::Out.Flush()
        break
    }
    $operation = ($line -split '\s+')[0]
    [Console]::Out.WriteLine((@{ status = 'ok'; op = $operation; value = $false } | ConvertTo-Json -Compress))
    [Console]::Out.Flush()
}
'@ | Set-Content -LiteralPath $adapterFixture -Encoding UTF8
    $managedReportPath = Join-Path $temp 'managed.json'
    $managedAdapterArguments = ' -NoProfile -NonInteractive -File "' + $adapterFixture + '"'
    $managedOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $managedReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -McpExecutablePath $pwsh -McpArguments $fixtureArguments -PlcSimAdapterPath $pwsh `
        -PlcSimAdapterArguments $managedAdapterArguments -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Managed virtual PLC fixture failed with exit code $LASTEXITCODE. Output: $managedOutput" }
    $managed = Get-Content -Raw -LiteralPath $managedReportPath | ConvertFrom-Json
    if ($managed.status -ne 'VERIFIED' -or $managed.virtualPlc.started -ne $true -or $managed.virtualPlc.cleanup.status -ne 'stopped') {
        throw 'Managed virtual PLC lifecycle did not start and clean up deterministically.'
    }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance owns virtual PLC startup and cleanup'

    $ioPlanPath = Join-Path $temp 'io-plan.json'
    [ordered]@{
        schemaVersion = 1
        name = 'fixture-io-plan'
        steps = @(
            [ordered]@{ command = 'write-bit input 0 0 1'; expect = [ordered]@{ status = 'ok'; op = 'write-bit' }; delayMs = 1 },
            [ordered]@{ command = 'read-bit output 0 0'; expect = [ordered]@{ status = 'ok'; op = 'read-bit' } }
        )
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ioPlanPath -Encoding UTF8
    $behaviorReportPath = Join-Path $temp 'behavior.json'
    $behaviorOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $behaviorReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -McpExecutablePath $pwsh -McpArguments $fixtureArguments -PlcSimAdapterPath $pwsh `
        -PlcSimAdapterArguments $managedAdapterArguments -IoPlanPath $ioPlanPath `
        -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Behavior fixture failed with exit code $LASTEXITCODE. Output: $behaviorOutput" }
    $behavior = Get-Content -Raw -LiteralPath $behaviorReportPath | ConvertFrom-Json
    if ($behavior.status -ne 'VERIFIED' -or $behavior.behavior.verified -ne $true -or @($behavior.behavior.steps).Count -ne 2) {
        throw 'Behavior plan was not executed and recorded as verified.'
    }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance executes and records an I/O behavior plan'

    $weakPlanPath = Join-Path $temp 'weak-io-plan.json'
    [ordered]@{ schemaVersion = 1; name = 'weak-plan'; steps = @([ordered]@{ command = 'read-bit output 0 0' }) } |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $weakPlanPath -Encoding UTF8
    $weakReportPath = Join-Path $temp 'weak-plan-report.json'
    $weakOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $weakReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -McpExecutablePath $pwsh -McpArguments $fixtureArguments -PlcSimAdapterPath $pwsh `
        -PlcSimAdapterArguments $managedAdapterArguments -IoPlanPath $weakPlanPath `
        -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 1) { throw "Weak behavior plan must fail with exit code 1. Output: $weakOutput" }
    $weak = Get-Content -Raw -LiteralPath $weakReportPath | ConvertFrom-Json
    if ($weak.status -ne 'FAILED' -or $weak.phase -ne 'BEHAVIOR') { throw 'Weak behavior plan was not rejected in BEHAVIOR phase.' }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance rejects behavior plans without explicit expectations'

    $adapterFailureReportPath = Join-Path $temp 'adapter-failure.json'
    $missingAdapter = Join-Path $temp 'missing-tia-claude-plcsim-adapter.exe'
    $adapterOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $adapterFailureReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -McpExecutablePath $pwsh -McpArguments $fixtureArguments -PlcSimAdapterPath $missingAdapter `
        -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 1) { throw "Missing adapter must fail with exit code 1. Output: $adapterOutput" }
    $adapterFailure = Get-Content -Raw -LiteralPath $adapterFailureReportPath | ConvertFrom-Json
    if ($adapterFailure.status -ne 'FAILED' -or $adapterFailure.phase -ne 'VIRTUAL_PLC_START') {
        throw 'Missing adapter did not stop in VIRTUAL_PLC_START.'
    }
    if ($adapterFailure.mutationAttempted -ne $false) { throw 'Missing adapter must not mark mutation attempted.' }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance refuses before MCP when the native virtual PLC adapter is missing'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
