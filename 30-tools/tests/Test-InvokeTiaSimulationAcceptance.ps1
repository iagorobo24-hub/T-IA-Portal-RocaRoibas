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
            plcsimCompatibleWithTia = $true
            plcsimVirtualAdapterReady = $false
            hmiRuntimeAdvancedV20Ready = $false
            plcBehaviorVerified = $false
            tiaInstanceSafeForApply = $false
        }
        blockers = @('El adaptador virtual Siemens PLCSIM no está operativo')
        nextActions = @('Activar el adaptador virtual')
        versions = [ordered]@{ tiaMajor = 20; plcsimAdvanced = '7.0.0' }
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
    if (@($report.blockers) -notcontains "Readiness gate 'tiaInstanceSafeForApply' must be the JSON boolean true.") {
        throw 'The false PLC adapter gate was not reported as a required PLC precondition.'
    }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance refuses to run before all readiness gates are true'

    $mismatchedReadinessPath = Join-Path $temp 'mismatched-readiness.json'
    $mismatchedReportPath = Join-Path $temp 'mismatched-acceptance.json'
    [ordered]@{
        schemaVersion = 1
        status = 'READY'
        gates = [ordered]@{ plcToolchainReady = $true; plcsimCompatibleWithTia = $true; tiaInstanceSafeForApply = $true }
        versions = [ordered]@{ tiaMajor = 20; plcsimAdvanced = '6.0.0.1' }
        blockers = @()
        nextActions = @()
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $mismatchedReadinessPath -Encoding UTF8
    & $pwsh -NoProfile -NonInteractive -File $script -ReadinessPath $mismatchedReadinessPath -OutputPath $mismatchedReportPath -Run 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 2) { throw "Mismatched TIA/PLCSIM versions must be blocked before starting the simulator; exit=$LASTEXITCODE." }
    $mismatchReport = Get-Content -Raw -LiteralPath $mismatchedReportPath | ConvertFrom-Json
    if ($mismatchReport.status -ne 'BLOCKED' -or $mismatchReport.mutationAttempted -ne $false -or @($mismatchReport.blockers | Where-Object { $_ -match 'no está en la matriz local admitida' }).Count -ne 1) {
        throw 'The runner trusted a stale compatibility gate or failed to explain the TIA/PLCSIM version mismatch.'
    }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance independently blocks an unsupported TIA/PLCSIM pairing'

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
            'AttachToOpenProject' { $payload = [ordered]@{ message = "Attached to open project 'Fixture Project'"; meta = @{ success = $true } } }
            'OpenProject' { $payload = [ordered]@{ message = "Opened project 'Fixture Project'"; meta = @{ success = $true } } }
            'GetSoftwareTree' { $payload = [ordered]@{ tree = "Fixture PLC`n└── Main [OB]"; message = 'Software tree retrieved' } }
            'GetDeviceIpAddress' { $payload = [ordered]@{ message = (@{ Ok = $true; Data = @{ found = $true; device = 'Fixture PLC'; ipAddress = '192.168.0.1'; nodeCount = 1; nodes = @(@{ nodeName = 'X1'; address = '192.168.0.1'; nodeType = 'Ethernet'; isIndustrialEthernet = $true }) }; Errors = $null; Warnings = $null; Message = 'PLC IP: 192.168.0.1' } | ConvertTo-Json -Depth 20 -Compress) } }
            'CompileSoftware' { $payload = [ordered]@{ state = 'Success'; errorCount = 0; warningCount = 0; message = 'Compiling finished (errors: 0; warnings: 0)' } }
            'GetBlocks' {
                $block = [ordered]@{ name = 'Main'; path = 'Main'; programmingLanguage = 'LAD'; isFailsafe = $false; isKnowHowProtected = $false; isConsistent = $true; attributes = @(@{ name = 'PLCSimAdvancedSupport'; value = $true }) }
                if ($env:TIA_SIM_FIXTURE_BLOCK_MODE -eq 'f-block') { $block.isFailsafe = $true }
                if ($env:TIA_SIM_FIXTURE_BLOCK_MODE -eq 'f-language') { $block.programmingLanguage = 'F-LAD' }
                if ($env:TIA_SIM_FIXTURE_BLOCK_MODE -eq 'unclassified') { $block.Remove('isFailsafe') }
                if ($env:TIA_SIM_FIXTURE_BLOCK_MODE -eq 'simulation-disabled') { $block.attributes[0].value = $false }
                $blockMeta = @{ success = $true }
                if ($env:TIA_SIM_FIXTURE_BLOCK_MODE -eq 'blocks-meta-fail') { $blockMeta = @{ success = $false } }
                $payload = [ordered]@{ meta = $blockMeta; items = @($block) }
            }
            'GetTags' {
                $tag = [ordered]@{ name = 'Cmd_Enable'; path = 'Agent_Signals/Cmd_Enable'; isSafety = $false }
                if ($env:TIA_SIM_FIXTURE_BLOCK_MODE -eq 'safety-tag') { $tag.isSafety = $true }
                if ($env:TIA_SIM_FIXTURE_BLOCK_MODE -eq 'unclassified-tag') { $tag.Remove('isSafety') }
                # Live contract: meta.count/meta.complete/meta.success (no totalTags).
                $tagMeta = @{ success = $true; complete = $true; count = 1 }
                if ($env:TIA_SIM_FIXTURE_BLOCK_MODE -eq 'tag-incomplete') { $tagMeta.complete = $false }
                if ($env:TIA_SIM_FIXTURE_BLOCK_MODE -eq 'tag-success-false') { $tagMeta.success = $false }
                if ($env:TIA_SIM_FIXTURE_BLOCK_MODE -eq 'tag-count-mismatch') { $tagMeta.count = 99 }
                $payload = [ordered]@{ meta = $tagMeta; items = @($tag) }
            }
            'CheckDownloadReadiness' { $payload = [ordered]@{ Ready = $true; IsConsistent = $true; Message = 'ready'; Meta = @{ downloadRoutes = @(@{ pgPcInterface = 'Siemens PLCSIM Virtual Ethernet Adapter'; preferred = $true; targetInterface = '1 X1'; targetIpAddress = '192.168.0.1' }) } } }
            'DownloadToPlc' {
                $downloadState = if ($env:TIA_SIM_FIXTURE_DOWNLOAD_MODE -eq 'warning') { 'Warning' } else { 'Success' }
                $payload = [ordered]@{ State = $downloadState; Message = 'downloaded to virtual target' }
            }
            'GetOnlineState' {
                $onlineState = if ($env:TIA_SIM_FIXTURE_DOWNLOAD_MODE -eq 'offline') { 'Offline' } else { 'Online' }
                $payload = [ordered]@{ State = $onlineState; Message = 'online state fixture' }
            }
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
            plcsimCompatibleWithTia = $true
            plcsimVirtualAdapterReady = $true
            hmiRuntimeAdvancedV20Ready = $false
            plcBehaviorVerified = $false
            tiaInstanceSafeForApply = $true
        }
        blockers = @()
        nextActions = @()
        versions = [ordered]@{ tiaMajor = 20; plcsimAdvanced = '7.0.0' }
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $readyPath -Encoding UTF8
    $projectFile = Join-Path $temp 'Fixture.ap20'
    'fixture project' | Set-Content -LiteralPath $projectFile -Encoding UTF8
    $relativeProjectFile = [IO.Path]::GetRelativePath($root, $projectFile)
    $targetEvidencePath = Join-Path $temp 'target-confirmation.json'
    [ordered]@{
        schemaVersion = 1
        source = 'native-computer-use'
        confirmed = $true
        observedAt = [DateTimeOffset]::Now.ToString('o')
        tiaMajorVersion = 20
        projectFile = $projectFile
        projectName = 'Fixture Project'
        devicePath = 'Fixture PLC'
        targetIpAddress = '192.168.0.1'
        pgPcInterface = 'Siemens PLCSIM Virtual Ethernet Adapter'
        targetDisplayName = 'CPU-1500 Simulation'
        downloadNotice = 'The downloads are performed on a simulated CPU'
        windowState = 'maximized'
        stage = 'before-download'
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $targetEvidencePath -Encoding UTF8
    $positiveReportPath = Join-Path $temp 'positive.json'
    $ioPlanPath = Join-Path $temp 'io-plan.json'
    [ordered]@{
        schemaVersion = 1
        name = 'fixture-io-plan'
        steps = @([ordered]@{ command = 'read-bit output 0 0'; expect = [ordered]@{ status = 'ok'; op = 'read-bit'; value = $false } })
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ioPlanPath -Encoding UTF8
    $fixtureArguments = ' -NoProfile -NonInteractive -File "' + $fixtureServer + '"'
    $fixtureOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $positiveReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -DevicePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -McpExecutablePath $pwsh -McpArguments $fixtureArguments -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 2) { throw "Run without a managed virtual PLC and I/O plan must block, got exit code $LASTEXITCODE. Output: $fixtureOutput" }
    $positive = Get-Content -Raw -LiteralPath $positiveReportPath | ConvertFrom-Json
    if ($positive.status -ne 'BLOCKED' -or $positive.mutationAttempted -ne $false) { throw 'Unmanaged-target run was not blocked before mutation.' }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance blocks downloads without a runner-managed virtual PLC and I/O plan'

    $wrongTargetEvidencePath = Join-Path $temp 'wrong-target-confirmation.json'
    $wrongTargetEvidence = Get-Content -LiteralPath $targetEvidencePath -Raw | ConvertFrom-Json
    $wrongTargetEvidence.projectName = 'Other Project'
    $wrongTargetEvidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $wrongTargetEvidencePath -Encoding UTF8
    $wrongTargetReportPath = Join-Path $temp 'wrong-target.json'
    $wrongTargetOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $wrongTargetReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -DevicePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -SimulationTargetEvidencePath $wrongTargetEvidencePath -McpExecutablePath $pwsh -McpArguments $fixtureArguments `
        -PlcSimAdapterPath $pwsh -IoPlanPath $ioPlanPath -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 2) { throw "Evidence for a different project must block before starting PLCSIM. Output: $wrongTargetOutput" }
    $wrongTarget = Get-Content -Raw -LiteralPath $wrongTargetReportPath | ConvertFrom-Json
    if ($wrongTarget.status -ne 'BLOCKED' -or $wrongTarget.mutationAttempted -ne $false -or @($wrongTarget.calls).Count -ne 0) {
        throw 'The runner did not block a target confirmation belonging to a different project before MCP or PLCSIM.'
    }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance binds native visual target confirmation to the exact project before startup'

    $wrongRouteEvidencePath = Join-Path $temp 'wrong-route-confirmation.json'
    $wrongRouteEvidence = Get-Content -LiteralPath $targetEvidencePath -Raw | ConvertFrom-Json
    $wrongRouteEvidence.pgPcInterface = 'Siemens PLCSIM Virtual Ethernet Adapter'
    $wrongRouteEvidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $wrongRouteEvidencePath -Encoding UTF8
    $wrongRouteReportPath = Join-Path $temp 'wrong-route.json'
    $wrongRouteOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $wrongRouteReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -DevicePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -SimulationTargetEvidencePath $wrongRouteEvidencePath -McpExecutablePath $pwsh -McpArguments $fixtureArguments `
        -PlcSimAdapterPath $pwsh -PlcSimTransport softbus -IoPlanPath $ioPlanPath `
        -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 2) { throw "A TCP/IP UI confirmation must not authorize Softbus. Output: $wrongRouteOutput" }
    $wrongRoute = Get-Content -Raw -LiteralPath $wrongRouteReportPath | ConvertFrom-Json
    if ($wrongRoute.status -ne 'BLOCKED' -or $wrongRoute.mutationAttempted -ne $false -or @($wrongRoute.calls).Count -ne 0) {
        throw 'A TCP/IP visual target confirmation was accepted for a Softbus download.'
    }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance does not reuse TCP/IP visual confirmation for Softbus'

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
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -DevicePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -SimulationTargetEvidencePath $targetEvidencePath -McpExecutablePath $pwsh -McpArguments $fixtureArguments `
        -PlcSimAdapterPath $pwsh -PlcSimTransport tcpip-local -IoPlanPath $ioPlanPath `
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
[Console]::Out.WriteLine('{"status":"ready","instanceName":"FixtureVirtualPlc","interfaceName":"Siemens PLCSIM Virtual Ethernet Adapter","interfaceDescription":"Siemens PLCSIM Virtual Ethernet Adapter","ip":"192.168.0.1","networkMode":"TCPIP_SINGLE_ADAPTER"}')
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
        -ReadinessPath $readyPath -OutputPath $managedReportPath -ProjectFile $relativeProjectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -DevicePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -SimulationTargetEvidencePath $targetEvidencePath -McpExecutablePath $pwsh -McpArguments $fixtureArguments `
        -PlcSimAdapterPath $pwsh -PlcSimTransport tcpip-local -IoPlanPath $ioPlanPath `
        -PlcSimAdapterArguments $managedAdapterArguments -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Managed virtual PLC fixture failed with exit code $LASTEXITCODE. Output: $managedOutput" }
    $managed = Get-Content -Raw -LiteralPath $managedReportPath | ConvertFrom-Json
    if ($managed.status -ne 'VERIFIED' -or $managed.virtualPlc.started -ne $true -or $managed.virtualPlc.cleanup.status -ne 'stopped') {
        throw 'Managed virtual PLC lifecycle did not start and clean up deterministically.'
    }
    if ([IO.Path]::GetFullPath($managed.project.file) -cne [IO.Path]::GetFullPath($projectFile)) {
        throw 'Relative ProjectFile was not normalized to the exact absolute fixture path in the report.'
    }
    if ($managed.simulationTargetEvidence.confirmed -ne $true -or $managed.simulationTargetEvidence.sha256 -ne (Get-FileHash $targetEvidencePath -Algorithm SHA256).Hash) {
        throw 'The simulation target evidence was not validated and linked into the acceptance report.'
    }
    if ($managed.behavior.verified -ne $true) { throw 'The managed acceptance did not record observed behavior.' }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance owns virtual PLC startup and cleanup'

    $behaviorReportPath = Join-Path $temp 'behavior.json'
    $behaviorOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $behaviorReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -DevicePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -SimulationTargetEvidencePath $targetEvidencePath -McpExecutablePath $pwsh -McpArguments $fixtureArguments `
        -PlcSimAdapterPath $pwsh -PlcSimTransport tcpip-local `
        -PlcSimAdapterArguments $managedAdapterArguments -IoPlanPath $ioPlanPath `
        -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Behavior fixture failed with exit code $LASTEXITCODE. Output: $behaviorOutput" }
    $behavior = Get-Content -Raw -LiteralPath $behaviorReportPath | ConvertFrom-Json
    if ($behavior.status -ne 'VERIFIED' -or $behavior.behavior.verified -ne $true -or @($behavior.behavior.steps).Count -ne 1) {
        throw 'Behavior plan was not executed and recorded as verified.'
    }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance executes and records an I/O behavior plan'

    foreach ($unsafeMode in @('f-block', 'f-language', 'unclassified', 'simulation-disabled', 'safety-tag', 'unclassified-tag', 'blocks-meta-fail', 'tag-incomplete', 'tag-success-false', 'tag-count-mismatch')) {
        $unsafeReportPath = Join-Path $temp ("unsafe-$unsafeMode.json")
        $env:TIA_SIM_FIXTURE_BLOCK_MODE = $unsafeMode
        $unsafeOutput = & $pwsh -NoProfile -NonInteractive -File $script `
            -ReadinessPath $readyPath -OutputPath $unsafeReportPath -ProjectFile $projectFile `
            -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -DevicePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
            -SimulationTargetEvidencePath $targetEvidencePath -McpExecutablePath $pwsh -McpArguments $fixtureArguments `
            -PlcSimAdapterPath $pwsh -PlcSimTransport tcpip-local `
            -PlcSimAdapterArguments $managedAdapterArguments -IoPlanPath $ioPlanPath `
            -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
        $env:TIA_SIM_FIXTURE_BLOCK_MODE = $null
        if ($LASTEXITCODE -ne 1) { throw "Unsafe simulation inventory '$unsafeMode' must fail before download. Output: $unsafeOutput" }
        $unsafe = Get-Content -Raw -LiteralPath $unsafeReportPath | ConvertFrom-Json
        if ($unsafe.status -ne 'FAILED' -or $unsafe.mutationAttempted -ne $false -or $unsafe.virtualPlc.cleanup.status -ne 'stopped') {
            throw "Unsafe simulation inventory '$unsafeMode' was not blocked and cleaned up before download."
        }
        $global:LASTEXITCODE = 0
    }
    Write-Output 'PASS: simulation acceptance fails closed on F/Safety, missing metadata, and disabled simulation support'

    foreach ($downloadMode in @('warning', 'offline')) {
        $downloadCheckReportPath = Join-Path $temp ("download-check-$downloadMode.json")
        $env:TIA_SIM_FIXTURE_DOWNLOAD_MODE = $downloadMode
        $downloadCheckOutput = & $pwsh -NoProfile -NonInteractive -File $script `
            -ReadinessPath $readyPath -OutputPath $downloadCheckReportPath -ProjectFile $projectFile `
            -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -DevicePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
            -SimulationTargetEvidencePath $targetEvidencePath -McpExecutablePath $pwsh -McpArguments $fixtureArguments `
            -PlcSimAdapterPath $pwsh -PlcSimTransport tcpip-local `
            -PlcSimAdapterArguments $managedAdapterArguments -IoPlanPath $ioPlanPath `
            -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
        $env:TIA_SIM_FIXTURE_DOWNLOAD_MODE = $null
        if ($LASTEXITCODE -ne 1) { throw "Download result '$downloadMode' must fail acceptance. Output: $downloadCheckOutput" }
        $downloadCheck = Get-Content -Raw -LiteralPath $downloadCheckReportPath | ConvertFrom-Json
        if ($downloadCheck.status -ne 'FAILED' -or $downloadCheck.phase -ne 'DOWNLOAD_AND_ONLINE_CHECK' -or
            $downloadCheck.behavior -or $downloadCheck.virtualPlc.cleanup.status -ne 'stopped') {
            throw "Download result '$downloadMode' was accepted or the simulator was not cleaned up."
        }
        $global:LASTEXITCODE = 0
    }
    Write-Output 'PASS: simulation acceptance requires DownloadToPlc Success and GetOnlineState Online before behavior checks'

    $weakPlanPath = Join-Path $temp 'weak-io-plan.json'
    [ordered]@{ schemaVersion = 1; name = 'weak-plan'; steps = @([ordered]@{ command = 'read-bit output 0 0'; expect = [ordered]@{ status = 'ok'; op = 'read-bit' } }) } |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $weakPlanPath -Encoding UTF8
    $weakReportPath = Join-Path $temp 'weak-plan-report.json'
    $weakOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $weakReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -DevicePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -SimulationTargetEvidencePath $targetEvidencePath -McpExecutablePath $pwsh -McpArguments $fixtureArguments `
        -PlcSimAdapterPath $pwsh `
        -PlcSimAdapterArguments $managedAdapterArguments -PlcSimTransport tcpip-local -IoPlanPath $weakPlanPath `
        -StartVirtualPlc -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 2) { throw "Weak behavior plan must block with exit code 2. Output: $weakOutput" }
    $weak = Get-Content -Raw -LiteralPath $weakReportPath | ConvertFrom-Json
    if ($weak.status -ne 'BLOCKED' -or $weak.phase -ne 'PREFLIGHT' -or $weak.mutationAttempted -ne $false) { throw 'Weak behavior plan was not rejected before mutation.' }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance rejects behavior plans without explicit expectations'

    $adapterFailureReportPath = Join-Path $temp 'adapter-failure.json'
    $missingAdapter = Join-Path $temp 'missing-tia-claude-plcsim-adapter.exe'
    $adapterOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $adapterFailureReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -DevicePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -SimulationTargetEvidencePath $targetEvidencePath -McpExecutablePath $pwsh -McpArguments $fixtureArguments `
        -PlcSimAdapterPath $missingAdapter -PlcSimTransport tcpip-local -IoPlanPath $ioPlanPath `
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
