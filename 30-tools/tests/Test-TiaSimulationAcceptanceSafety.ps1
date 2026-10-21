[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Invoke-TiaSimulationAcceptance.ps1'
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-simulation-safety-test-' + [guid]::NewGuid().ToString('N'))

# El runner exige evidencia de que el destino es una CPU simulada antes de descargar
# (puerta anadida en d25e399). Aqui el destino es un fixture MCP simulado, asi que la
# evidencia tambien es de fixture, pero con las mismas claves y la misma caducidad que
# exige el runner: proyecto y dispositivo exactos, TIA V20, la ruta PG/PC de este
# transporte, "CPU-1500 Simulation", ventana maximizada, aviso de CPU simulada y menos
# de 30 minutos de antiguedad.
function New-SimulationTargetEvidence([string]$Name, [string]$Transport) {
    $path = Join-Path $temp ($Name + '-target-evidence.json')
    $pgPcInterface = if ($Transport -eq 'softbus') { 'PLCSIM' } else { 'Siemens PLCSIM Virtual Ethernet Adapter' }
    [ordered]@{
        schemaVersion = 1
        source = 'native-computer-use'
        confirmed = $true
        observedAt = [DateTimeOffset]::Now.ToString('o')
        projectFile = [IO.Path]::GetFullPath($projectFile)
        projectName = 'Fixture Project'
        devicePath = 'Fixture PLC'
        tiaMajorVersion = 20
        pgPcInterface = $pgPcInterface
        targetDisplayName = 'CPU-1500 Simulation'
        windowState = 'maximized'
        stage = 'before-download'
        downloadNotice = 'The downloads are performed on a simulated CPU. No real PLC is affected.'
        targetIpAddress = '192.168.0.1'
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Invoke-Runner([string]$Name, [string]$RouteMode, [string]$PlanPath, [switch]$StartVirtualPlc, [string]$AdapterIp = '192.168.0.1', [string]$ReadinessPathOverride, [string]$Transport = 'tcpip-local', [switch]$Fallback) {
    $reportPath = Join-Path $temp ($Name + '-report.json')
    $capturePath = Join-Path $temp ($Name + '-download.json')
    $targetEvidencePath = New-SimulationTargetEvidence -Name $Name -Transport $Transport
    $deviceIp = if ($RouteMode -eq 'project-ip-mismatch') { '192.168.0.99' } else { '192.168.0.1' }
    $fixtureArguments = ' -NoProfile -NonInteractive -File "' + $fixtureServer + '" -RouteMode ' + $RouteMode + ' -DeviceIp ' + $deviceIp + ' -CapturePath "' + $capturePath + '"'
    $adapterRunArguments = ' -NoProfile -NonInteractive -File "' + $adapterPath + '" -Ip ' + $AdapterIp + ' -Transport ' + $Transport
    $arguments = @(
        '-NoProfile', '-NonInteractive', '-File', $script,
        '-ReadinessPath', $(if ($ReadinessPathOverride) { $ReadinessPathOverride } else { $readinessPath }), '-OutputPath', $reportPath,
        '-ProjectFile', $projectFile, '-ProjectName', 'Fixture Project',
        '-SoftwarePath', 'Fixture PLC', '-DevicePath', 'Fixture PLC',
        '-TargetIpAddress', '192.168.0.1', '-VirtualInterfacePattern', 'PLCSIM',
        '-PlcSimInterface', 'Siemens PLCSIM Virtual Ethernet Adapter', '-PlcSimTransport', $Transport,
        '-McpExecutablePath', $pwsh, '-McpArguments', $fixtureArguments,
        '-PlcSimAdapterPath', $pwsh, '-PlcSimAdapterArguments', $adapterRunArguments,
        '-SimulationTargetEvidencePath', $targetEvidencePath,
        '-AcknowledgeVirtualTarget', '-Run'
    )
    if (-not [string]::IsNullOrWhiteSpace($PlanPath)) { $arguments += @('-IoPlanPath', $PlanPath) }
    if ($StartVirtualPlc) { $arguments += '-StartVirtualPlc' }
    if ($Fallback) { $arguments += '-AllowOpenProjectFallback' }
    $output = & $pwsh @arguments 2>&1 | Out-String
    [pscustomobject]@{
        exitCode = $LASTEXITCODE
        output = $output
        reportPath = $reportPath
        capturePath = $capturePath
        report = if (Test-Path -LiteralPath $reportPath -PathType Leaf) { Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json } else { $null }
    }
}

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $readinessPath = Join-Path $temp 'readiness.json'
    [ordered]@{
        schemaVersion = 1
        status = 'READY_WITH_BLOCKERS'
        versions = [ordered]@{ tiaMajor = 20; plcsimAdvanced = '7.0.0.0' }
        gates = [ordered]@{
            plcToolchainReady = $true
            plcsimCompatibleWithTia = $true
            plcsimVirtualAdapterReady = $true
            hmiRuntimeAdvancedV20Ready = $false
            plcBehaviorVerified = $false
            tiaInstanceSafeForApply = $true
        }
        blockers = @('WinCC Runtime Advanced V20 compatible no está verificado', 'El comportamiento PLC en runtime no está demostrado')
        nextActions = @('Verificar runtime HMI', 'Ejecutar aceptación PLC')
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $readinessPath -Encoding UTF8

    $projectFile = Join-Path $temp 'Fixture.ap20'
    'fixture project' | Set-Content -LiteralPath $projectFile -Encoding UTF8

    $fixtureServer = Join-Path $temp 'mcp-fixture.ps1'
    @'
param([string]$RouteMode = 'unique', [string]$DeviceIp = '192.168.0.1', [string]$CapturePath)
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
        $argsObject = $request.params.arguments
        switch ($name) {
            'GetProjectTree' { $payload = [ordered]@{ tree = "Fixture Project`n|-- Fixture PLC [PLC Program]"; message = 'Project tree retrieved' } }
            'AttachToOpenProject' { $payload = [ordered]@{ message = "Attached to open project 'Fixture Project'"; meta = @{ success = $true } } }
            'OpenProject' { $payload = [ordered]@{ message = "Opened project 'Fixture Project'"; meta = @{ success = $true } } }
            'GetSoftwareTree' { $payload = [ordered]@{ tree = "Fixture PLC`n|-- Main [OB]"; message = 'Software tree retrieved' } }
            'GetDeviceIpAddress' { $payload = [ordered]@{ message = (@{ Ok = $true; Data = @{ found = $true; device = 'Fixture PLC'; ipAddress = $DeviceIp; nodeCount = 1; nodes = @(@{ nodeName = 'X1'; address = $DeviceIp; nodeType = 'Ethernet'; isIndustrialEthernet = $true }) }; Errors = $null; Warnings = $null; Message = "PLC IP: $DeviceIp" } | ConvertTo-Json -Depth 20 -Compress) } }
            'GetBlocks' { $payload = [ordered]@{ meta = @{ success = $true }; items = @(@{ name = 'Main'; path = 'Main'; programmingLanguage = 'LAD'; isFailsafe = $false; isKnowHowProtected = $false; isConsistent = $true; attributes = @(@{ name = 'PLCSimAdvancedSupport'; value = $true }) }) } }
            'GetTags' { $payload = [ordered]@{ meta = @{ success = $true; complete = $true; count = 1 }; items = @(@{ name = 'Cmd_Enable'; path = 'Agent_Signals/Cmd_Enable'; isSafety = $false }) } }
            'CompileSoftware' {
                if ($RouteMode -eq 'compile-error') { $payload = [ordered]@{ state = 'Failure'; errorCount = 1; warningCount = 0; message = 'fixture compile error' } }
                elseif ($RouteMode -eq 'compile-warning') { $payload = [ordered]@{ state = 'Warning'; errorCount = 0; warningCount = 1; message = 'fixture compile warning' } }
                else { $payload = [ordered]@{ state = 'Success'; errorCount = 0; warningCount = 0; message = 'Compiling finished (errors: 0; warnings: 0)' } }
            }
            'CheckDownloadReadiness' {
                $routeIp = if ($RouteMode -eq 'route-ip-mismatch') { '192.168.0.99' } else { '192.168.0.1' }
                $routeName = if ($RouteMode -eq 'softbus') { 'PLCSIM' } else { 'Siemens PLCSIM Virtual Ethernet Adapter' }
                $route = @{ pgPcInterface = $routeName; preferred = $true; targetInterface = '1 X1'; targetIpAddress = $routeIp }
                $routes = if ($RouteMode -eq 'ambiguous') { @($route, (@{} + $route + @{ targetInterface = '2 X1'; targetIpAddress = '192.168.0.2' })) } else { @($route) }
                if ($RouteMode -eq 'no-softbus-route') {
                    # Live shape 2026-09-25: five PN/IE NIC routes, no PLCSIM entry, empty addresses, none preferred.
                    $routes = @('Realtek PCIe GbE Family Controller', 'Siemens PLCSIM Virtual Ethernet Adapter', 'ASIX USB to Gigabit Ethernet Family Adapter', 'TAP-Windows Adapter V9', 'Realtek 8822CE Wireless LAN 802.11ac PCI-E NIC') |
                        ForEach-Object { @{ mode = 'PN/IE'; pgPcInterface = $_; pgPcInterfaceNumber = 1; pgPcAddresses = ''; targetInterface = '1 X1'; targetAddresses = ''; preferred = $false } }
                }
                $payload = [ordered]@{ Ready = $true; IsConsistent = $true; Message = 'ready'; Meta = @{ downloadRoutes = $routes } }
            }
            'DownloadToPlc' {
                $argsObject | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $CapturePath -Encoding UTF8
                $payload = [ordered]@{ State = 'Success'; Message = 'downloaded to virtual target' }
            }
            'GetOnlineState' { $payload = [ordered]@{ State = 'Online'; Message = 'online' } }
            default { $payload = [ordered]@{ success = $true; message = $name } }
        }
        $result = [ordered]@{ content = @(@{ type = 'text'; text = ($payload | ConvertTo-Json -Depth 20 -Compress) }) }
    }
    else { $result = [ordered]@{ content = @(@{ type = 'text'; text = '{"success":true}' }) } }
    [ordered]@{ jsonrpc = '2.0'; id = $request.id; result = $result } | ConvertTo-Json -Depth 30 -Compress
}
'@ | Set-Content -LiteralPath $fixtureServer -Encoding UTF8

    $adapterPath = Join-Path $temp 'adapter-fixture.ps1'
    @'
param([string]$Ip = '192.168.0.1', [string]$Transport = 'tcpip-local')
$ready = if ($Transport -eq 'softbus') { @{ status = 'ready'; instanceName = 'FixtureVirtualPlc'; interfaceName = 'PLCSIM'; interfaceDescription = 'Local Softbus'; ip = $null; networkMode = 'SOFTBUS' } } else { @{ status = 'ready'; instanceName = 'FixtureVirtualPlc'; interfaceName = 'Siemens PLCSIM Virtual Ethernet Adapter'; interfaceDescription = 'Siemens PLCSIM Virtual Ethernet Adapter'; ip = $Ip; networkMode = 'TCPIP_SINGLE_ADAPTER' } }
[Console]::Out.WriteLine(($ready | ConvertTo-Json -Compress))
[Console]::Out.Flush()
while ($line = [Console]::In.ReadLine()) {
    if ($line -eq 'stop' -or $line -eq 'quit') {
        [Console]::Out.WriteLine('{"status":"stopped","powerOffCode":"0x0","unregisterCode":"0x0","destroyCode":"0x0"}')
        [Console]::Out.Flush()
        break
    }
    [Console]::Out.WriteLine('{"status":"ok","op":"read-bit","value":false}')
    [Console]::Out.Flush()
}
'@ | Set-Content -LiteralPath $adapterPath -Encoding UTF8
    $weakPlanPath = Join-Path $temp 'weak-plan.json'
    [ordered]@{
        schemaVersion = 1
        name = 'transport-only-plan'
        steps = @([ordered]@{ command = 'read-bit output 0 0'; expect = [ordered]@{ status = 'ok'; op = 'read-bit' } })
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $weakPlanPath -Encoding UTF8
    $validPlanPath = Join-Path $temp 'valid-plan.json'
    [ordered]@{
        schemaVersion = 1
        name = 'observable-output-plan'
        steps = @([ordered]@{ command = 'read-bit output 0 0'; expect = [ordered]@{ status = 'ok'; op = 'read-bit'; value = $false } })
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $validPlanPath -Encoding UTF8

    $missingPlan = Invoke-Runner -Name 'missing-plan' -RouteMode 'unique' -PlanPath ''
    if ($missingPlan.exitCode -ne 2 -or $missingPlan.report.status -ne 'BLOCKED' -or $missingPlan.report.mutationAttempted -ne $false) {
        throw "Run without an I/O plan must block before mutation. Output: $($missingPlan.output)"
    }
    if (@($missingPlan.report.blockers | Where-Object { $_ -match 'Runtime Advanced|comportamiento PLC en runtime' }).Count -gt 0) {
        throw 'PLC acceptance must not use aggregated HMI/runtime-result blockers as PLC preconditions.'
    }
    Write-Output 'PASS: PLC readiness is independent of HMI and pending PLC behavior blockers'

    $weak = Invoke-Runner -Name 'weak-plan' -RouteMode 'unique' -PlanPath $weakPlanPath -StartVirtualPlc
    if ($weak.exitCode -ne 2 -or $weak.report.status -ne 'BLOCKED' -or $weak.report.mutationAttempted -ne $false) {
        throw "A transport-only I/O plan must block before mutation. Output: $($weak.output)"
    }
    Write-Output 'PASS: transport-only expectations cannot authorize a behavior acceptance download'

    foreach ($nonBehaviorPlan in @(
        @{ name = 'size-only-plan'; command = 'read-area-size input'; expect = [ordered]@{ size = 64 } },
        @{ name = 'input-echo-plan'; command = 'read-bit input 0 0'; expect = [ordered]@{ value = $false } }
    )) {
        $nonBehaviorPath = Join-Path $temp ($nonBehaviorPlan.name + '.json')
        [ordered]@{ schemaVersion = 1; name = $nonBehaviorPlan.name; steps = @([ordered]@{ command = $nonBehaviorPlan.command; expect = $nonBehaviorPlan.expect }) } |
            ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $nonBehaviorPath -Encoding UTF8
        $nonBehavior = Invoke-Runner -Name $nonBehaviorPlan.name -RouteMode 'unique' -PlanPath $nonBehaviorPath -StartVirtualPlc
        if ($nonBehavior.exitCode -ne 2 -or $nonBehavior.report.status -ne 'BLOCKED' -or $nonBehavior.report.mutationAttempted -ne $false) {
            throw "A plan without an observed PLC output must block before mutation: $($nonBehaviorPlan.name)."
        }
        if (Test-Path -LiteralPath $nonBehavior.capturePath -PathType Leaf) { throw "Non-behavior plan reached DownloadToPlc: $($nonBehaviorPlan.name)." }
    }
    Write-Output 'PASS: memory sizing and input echo do not count as functional output observations'

    $gateCases = @(
        @{ name = 'gate-false'; kind = 'value'; value = $false },
        @{ name = 'gate-null'; kind = 'value'; value = $null },
        @{ name = 'gate-string-false'; kind = 'value'; value = 'false' },
        @{ name = 'gate-missing'; kind = 'missing' }
    )
    foreach ($gateCase in $gateCases) {
        $caseReadinessPath = Join-Path $temp ($gateCase.name + '.json')
        # Sin -AsHashtable: el fallback a Windows PowerShell 5.1 que este propio test declara
        # en las lineas 7-8 no soporta ese parametro, y el JSON resultante es identico.
        $caseReadiness = Get-Content -Raw -LiteralPath $readinessPath | ConvertFrom-Json
        if ($gateCase.kind -eq 'missing') { $caseReadiness.gates.PSObject.Properties.Remove('tiaInstanceSafeForApply') }
        else { $caseReadiness.gates.tiaInstanceSafeForApply = $gateCase.value }
        $caseReadiness | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $caseReadinessPath -Encoding UTF8
        $gateResult = Invoke-Runner -Name $gateCase.name -RouteMode 'unique' -PlanPath $validPlanPath -StartVirtualPlc -ReadinessPathOverride $caseReadinessPath
        if ($gateResult.exitCode -ne 2 -or $gateResult.report.status -ne 'BLOCKED' -or $gateResult.report.mutationAttempted -ne $false) {
            throw "PLC readiness gate case '$($gateCase.name)' must block before startup or mutation. Output: $($gateResult.output)"
        }
        if (Test-Path -LiteralPath $gateResult.capturePath -PathType Leaf) { throw "PLC readiness gate '$($gateCase.name)' reached DownloadToPlc." }
    }
    Write-Output 'PASS: PLC readiness gates require literal JSON true values'

    foreach ($compileCase in @(@{ name = 'compile-failure'; mode = 'compile-error' }, @{ name = 'compile-warning'; mode = 'compile-warning' })) {
        $compileFailure = Invoke-Runner -Name $compileCase.name -RouteMode $compileCase.mode -PlanPath $validPlanPath -StartVirtualPlc
        if ($compileFailure.exitCode -ne 1 -or $compileFailure.report.status -ne 'FAILED' -or $compileFailure.report.mutationAttempted -ne $false) {
            throw "A compile error/warning must stop before download. Output: $($compileFailure.output)"
        }
        if (Test-Path -LiteralPath $compileFailure.capturePath -PathType Leaf) { throw 'Compile failure reached DownloadToPlc.' }
    }
    Write-Output 'PASS: compile errors or warnings block before download'

    $ambiguous = Invoke-Runner -Name 'ambiguous-route' -RouteMode 'ambiguous' -PlanPath $validPlanPath -StartVirtualPlc
    if ($ambiguous.exitCode -ne 1 -or $ambiguous.report.status -ne 'FAILED' -or $ambiguous.report.mutationAttempted -ne $false) {
        throw "Ambiguous route must stop before DownloadToPlc. Output: $($ambiguous.output)"
    }
    if (Test-Path -LiteralPath $ambiguous.capturePath -PathType Leaf) { throw 'Ambiguous route reached DownloadToPlc.' }
    Write-Output 'PASS: ambiguous virtual routes stop before download'

    foreach ($mismatch in @(
        @{ name = 'project-ip-mismatch'; mode = 'project-ip-mismatch'; adapterIp = '192.168.0.1' },
        @{ name = 'route-ip-mismatch'; mode = 'route-ip-mismatch'; adapterIp = '192.168.0.1' },
        @{ name = 'instance-ip-mismatch'; mode = 'unique'; adapterIp = '192.168.0.99' }
    )) {
        $mismatchResult = Invoke-Runner -Name $mismatch.name -RouteMode $mismatch.mode -PlanPath $validPlanPath -StartVirtualPlc -AdapterIp $mismatch.adapterIp
        if ($mismatchResult.exitCode -ne 1 -or $mismatchResult.report.status -ne 'FAILED' -or $mismatchResult.report.mutationAttempted -ne $false) {
            throw "IP mismatch '$($mismatch.name)' must stop in preflight before download. Output: $($mismatchResult.output)"
        }
        if (Test-Path -LiteralPath $mismatchResult.capturePath -PathType Leaf) { throw "IP mismatch '$($mismatch.name)' reached DownloadToPlc." }
    }
    Write-Output 'PASS: project, route, and virtual instance IP must agree before download'

    $unique = Invoke-Runner -Name 'unique-route' -RouteMode 'unique' -PlanPath $validPlanPath -StartVirtualPlc
    if ($unique.exitCode -ne 0 -or $unique.report.status -ne 'VERIFIED') {
        throw "Single virtual route with an observed value should pass the fixture. Output: $($unique.output)"
    }
    $downloadArgs = Get-Content -Raw -LiteralPath $unique.capturePath | ConvertFrom-Json
    if ($downloadArgs.pgPcInterface -ne 'Siemens PLCSIM Virtual Ethernet Adapter') {
        throw "DownloadToPlc did not receive the exact selected interface: '$($downloadArgs.pgPcInterface)'"
    }
    if ($downloadArgs.targetIpAddress -ne '192.168.0.1') { throw 'DownloadToPlc did not receive the checked target IP.' }
    if ($unique.report.behavior.verified -ne $true) { throw 'A successful download without an observed behavior result cannot be verified.' }
    Write-Output 'PASS: the unique exact interface and checked IP are passed to DownloadToPlc'

    $softbus = Invoke-Runner -Name 'softbus-route' -RouteMode 'softbus' -PlanPath $validPlanPath -StartVirtualPlc -Transport 'softbus'
    if ($softbus.exitCode -ne 0 -or $softbus.report.status -ne 'VERIFIED') { throw "Softbus route should pass the fixture. Output: $($softbus.output)" }
    $softbusDownload = Get-Content -Raw -LiteralPath $softbus.capturePath | ConvertFrom-Json
    if ($softbusDownload.pgPcInterface -ne 'PLCSIM') { throw 'Softbus acceptance did not select the PLCSIM PG/PC route.' }
    if ($softbusDownload.PSObject.Properties['targetIpAddress']) { throw 'Softbus acceptance must not forward a target IP: Softbus targets carry no address and the server filters targetIpAddress against TargetAddresses.' }
    if ($softbus.report.preflight.virtualInstance.ip -ne $null -or $softbus.report.preflight.virtualInstance.transport -ne 'softbus') { throw 'Softbus preflight incorrectly depended on an IP adapter.' }
    Write-Output 'PASS: Softbus local mode selects PLCSIM and does not require a TCP/IP adapter address'

    $noSoftbus = Invoke-Runner -Name 'no-softbus-route' -RouteMode 'no-softbus-route' -PlanPath $validPlanPath -StartVirtualPlc -Transport 'softbus'
    if ($noSoftbus.exitCode -ne 1 -or $noSoftbus.report.status -ne 'FAILED' -or $noSoftbus.report.mutationAttempted -ne $false) {
        throw "A Softbus request without an enumerated PLCSIM route must fail before download. Output: $($noSoftbus.output)"
    }
    if (Test-Path -LiteralPath $noSoftbus.capturePath -PathType Leaf) { throw 'Missing Softbus route reached DownloadToPlc.' }
    if (@($noSoftbus.report.blockers | Where-Object { $_ -match 'not enumerated exactly once' }).Count -ne 1) {
        throw 'The missing Softbus route was not reported as an explicit Softbus setup failure.'
    }
    if ($noSoftbus.report.virtualPlc.cleanup.status -ne 'stopped') { throw 'The started virtual PLC was not cleaned up after the Softbus route failure.' }
    Write-Output 'PASS: Softbus without an enumerated PLCSIM route blocks before download and never falls back to a NIC'

    $fallback = Invoke-Runner -Name 'open-fallback' -RouteMode 'unique' -PlanPath $validPlanPath -StartVirtualPlc -Fallback
    if ($fallback.exitCode -ne 0 -or $fallback.report.status -ne 'VERIFIED') { throw "OpenProject fallback should pass the fixture. Output: $($fallback.output)" }
    $fallbackDownload = Get-Content -Raw -LiteralPath $fallback.capturePath | ConvertFrom-Json
    if ($fallbackDownload.pgPcInterface -ne 'Siemens PLCSIM Virtual Ethernet Adapter') { throw 'Fallback acceptance did not select the exact virtual interface.' }
    Write-Output 'PASS: AllowOpenProjectFallback binds the exact fixture in every session without Attach'
}
finally {
    if (Test-Path -LiteralPath $temp -PathType Container) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
