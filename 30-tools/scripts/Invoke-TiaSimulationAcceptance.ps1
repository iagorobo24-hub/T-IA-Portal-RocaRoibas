<#
.SYNOPSIS
    Ejecuta la aceptación PLC sobre PLCSIM con gates explícitos y trazabilidad.

.DESCRIPTION
    El modo predeterminado solo genera un preview. El modo -Run exige todos los
    datos del proyecto y una confirmación explícita de que el destino es virtual.
    Abre el proyecto indicado, recompila, consulta CheckDownloadReadiness y solo
    entonces descarga si la ruta PG/PC contiene el adaptador PLCSIM solicitado.
    Nunca elige una NIC por heurística cuando el destino es ambiguo.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ReadinessPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '70-runs\simulation\readiness-latest.json'),
    [string]$OutputPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '70-runs\simulation\acceptance-latest.json'),
    [string]$ProjectFile,
    [string]$ProjectName,
    [string]$SoftwarePath,
    [string]$TargetIpAddress,
    [string]$VirtualInterfacePattern = 'PLCSIM',
    [string]$PlcSimAdapterPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '30-tools\plcsim\bin\v6\tia-claude-plcsim-adapter.exe'),
    [string]$PlcSimAdapterArguments,
    [string]$PlcSimInterface = 'Siemens PLCSIM Virtual Ethernet Adapter',
    [string]$VirtualPlcName = 'TIAClaudeAcceptance_1516F',
    [int]$PlcSimTimeoutMs = 60000,
    [string]$McpExecutablePath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'),
    [string]$McpArguments = '--tia-major-version 20 --profile full --allow-write',
    [string]$IoPlanPath,
    [int]$TimeoutSeconds = 900,
    [switch]$Run,
    [switch]$StartVirtualPlc,
    [switch]$AcknowledgeVirtualTarget
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$ReadinessPath = [IO.Path]::GetFullPath($ReadinessPath)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)

function Read-Json([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "JSON file does not exist: $Path" }
    Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Write-Report([hashtable]$Report, [int]$ExitCode) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
    ($Report | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-Output (Get-Content -Raw -LiteralPath $OutputPath)
    if ($ExitCode -ne 0) { exit $ExitCode }
}

function Get-ToolPayload([object]$Call) {
    if (-not $Call) { return $null }
    $text = [string]$Call.text
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    try { $value = $text | ConvertFrom-Json } catch { return $null }
    if ($value.message -is [string]) {
        try { return ([string]$value.message | ConvertFrom-Json) } catch { }
    }
    return $value
}

function New-BaseReport([object]$Readiness) {
    [ordered]@{
        schemaVersion = 1
        generatedAt = [DateTimeOffset]::Now.ToString('o')
        readOnly = (-not $Run)
        mode = if ($Run) { 'run' } else { 'preview' }
        status = 'PREVIEW'
        phase = 'PREFLIGHT'
        mutationAttempted = $false
        project = [ordered]@{ file = $ProjectFile; name = $ProjectName; softwarePath = $SoftwarePath; targetIpAddress = $TargetIpAddress }
        virtualTarget = [ordered]@{ acknowledged = [bool]$AcknowledgeVirtualTarget; interfacePattern = $VirtualInterfacePattern }
        blockers = @()
        nextActions = @()
        calls = @()
        readiness = $Readiness
    }
}

function Start-VirtualPlcProcess {
    if (-not (Test-Path -LiteralPath $PlcSimAdapterPath -PathType Leaf)) {
        throw "No existe el adaptador nativo PLCSIM: $PlcSimAdapterPath"
    }
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = [IO.Path]::GetFullPath($PlcSimAdapterPath)
    $psi.Arguments = if ([string]::IsNullOrWhiteSpace($PlcSimAdapterArguments)) {
        '--register-acceptance --name "{0}" --interface "{1}" --ip "{2}" --timeout-ms {3}' -f $VirtualPlcName, $PlcSimInterface, $TargetIpAddress, $PlcSimTimeoutMs
    } else { $PlcSimAdapterArguments }
    $psi.WorkingDirectory = Split-Path -Parent $psi.FileName
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $process = [Diagnostics.Process]::Start($psi)
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $read = $process.StandardOutput.ReadLineAsync()
    if (-not $read.Wait($PlcSimTimeoutMs)) {
        try { $process.Kill() } catch { }
        throw "Timeout esperando el estado ready del adaptador PLCSIM ($PlcSimTimeoutMs ms)."
    }
    $line = $read.Result
    if ([string]::IsNullOrWhiteSpace($line)) { throw 'El adaptador PLCSIM terminó sin emitir estado inicial.' }
    try { $ready = $line | ConvertFrom-Json } catch { throw "El adaptador PLCSIM emitió JSON inválido: $line" }
    if ([string]$ready.status -ne 'ready') {
        throw "El adaptador PLCSIM no está listo: $line"
    }
    [pscustomobject]@{ process = $process; ready = $ready; stderrTask = $stderrTask }
}

function Invoke-IoPlan([Diagnostics.Process]$Process, [string]$Path) {
    if ($null -eq $Process) { throw 'IoPlanPath requiere -StartVirtualPlc para disponer del proceso nativo.' }
    $plan = Read-Json $Path
    $steps = @($plan.steps)
    if ($steps.Count -eq 0) { throw "El plan de E/S no contiene steps: $Path" }
    $results = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $steps.Count; $index++) {
        $step = $steps[$index]
        $command = [string]$step.command
        if ([string]::IsNullOrWhiteSpace($command)) { throw "El step $index no tiene command." }
        $Process.StandardInput.WriteLine($command)
        $Process.StandardInput.Flush()
        $read = $Process.StandardOutput.ReadLineAsync()
        if (-not $read.Wait($PlcSimTimeoutMs)) { throw "Timeout esperando respuesta del step $index ($command)." }
        $line = $read.Result
        try { $response = $line | ConvertFrom-Json } catch { throw "Respuesta JSON inválida en step ${index}: ${line}" }
        if ([string]$response.status -ne 'ok') { throw "El step $index falló: $line" }
        if ($step.expect) {
            foreach ($expected in $step.expect.PSObject.Properties) {
                $actualProperty = $response.PSObject.Properties[$expected.Name]
                if ($null -eq $actualProperty -or [string]$actualProperty.Value -ne [string]$expected.Value) {
                    throw "El step $index no cumple expect.$($expected.Name): esperado '$($expected.Value)', recibido '$($actualProperty.Value)'."
                }
            }
        }
        $results.Add([ordered]@{ index = $index; command = $command; response = $response })
    }
    [ordered]@{
        schemaVersion = 1
        name = [string]$plan.name
        planPath = [IO.Path]::GetFullPath($Path)
        verified = $true
        steps = @($results)
    }
}

$readiness = Read-Json $ReadinessPath
$report = New-BaseReport $readiness
$requiredGates = @('plcToolchainReady', 'plcsimVirtualAdapterReady', 'tiaInstanceSafeForApply')
$gateBlockers = [System.Collections.Generic.List[string]]::new()
foreach ($gate in $requiredGates) {
    if (-not [bool]$readiness.gates.$gate) { $gateBlockers.Add("Readiness gate '$gate' is false.") }
}
if (@($readiness.blockers).Count -gt 0) {
    foreach ($blocker in @($readiness.blockers)) { $gateBlockers.Add([string]$blocker) }
}

if (-not $Run) {
    $report.nextActions = @('Revisar este preview; para ejecutar, proporcionar proyecto, softwarePath, IP objetivo y -AcknowledgeVirtualTarget -Run.')
    Write-Report $report 0
}

if ($gateBlockers.Count -gt 0) {
    $report.status = 'BLOCKED'
    $report.blockers = @($gateBlockers | Select-Object -Unique)
    $report.nextActions = @($readiness.nextActions | ForEach-Object { [string]$_ })
    Write-Report $report 2
}

$missing = @(
    @{ name = 'ProjectFile'; value = $ProjectFile },
    @{ name = 'ProjectName'; value = $ProjectName },
    @{ name = 'SoftwarePath'; value = $SoftwarePath },
    @{ name = 'TargetIpAddress'; value = $TargetIpAddress }
) | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.value) }
if ($missing.Count -gt 0 -or -not $AcknowledgeVirtualTarget) {
    $report.status = 'BLOCKED'
    $report.blockers = @($missing | ForEach-Object { "Falta el parámetro obligatorio '$($_.name)'." })
    if (-not $AcknowledgeVirtualTarget) { $report.blockers += 'Falta -AcknowledgeVirtualTarget; no se permite descargar sin declarar que el destino es PLCSIM.' }
    $report.nextActions = @('Revisar el destino y repetir con los parámetros obligatorios.')
    Write-Report $report 2
}

if (-not (Test-Path -LiteralPath $McpExecutablePath -PathType Leaf)) {
    $report.status = 'BLOCKED'
    $report.blockers = @("No existe el servidor MCP: $McpExecutablePath")
    Write-Report $report 2
}

$sequenceScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }
$preflightSequencePath = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-acceptance-preflight-' + [guid]::NewGuid().ToString('N') + '.json')
$downloadSequencePath = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-acceptance-download-' + [guid]::NewGuid().ToString('N') + '.json')
$virtualProcess = $null
$virtualAdapterResult = $null
$exitCode = 0

try {
    if ($StartVirtualPlc) {
        $report.phase = 'VIRTUAL_PLC_START'
        $virtualAdapterResult = Start-VirtualPlcProcess
        $virtualProcess = $virtualAdapterResult.process
        $report.virtualPlc = [ordered]@{
            started = $true
            adapterPath = [IO.Path]::GetFullPath($PlcSimAdapterPath)
            name = $VirtualPlcName
            interface = $PlcSimInterface
            targetIpAddress = $TargetIpAddress
            ready = $virtualAdapterResult.ready
        }
    }
    else {
        $report.virtualPlc = [ordered]@{ started = $false; reason = 'StartVirtualPlc no solicitado; el proceso debe estar gestionado externamente.' }
    }

    $report.phase = 'PREFLIGHT'
    $preflightCalls = @(
        @{ name = 'Bootstrap'; args = @{} },
        @{ name = 'Connect'; args = @{} },
        @{ name = 'OpenProject'; args = @{ path = $ProjectFile; closeForeignProject = $false } },
        @{ name = 'GetProjectTree'; args = @{} },
        @{ name = 'CompileSoftware'; args = @{ softwarePath = $SoftwarePath; password = '' } },
        @{ name = 'CheckDownloadReadiness'; args = @{ softwarePath = $SoftwarePath } },
        @{ name = 'Disconnect'; args = @{} }
    )
    $callsJson = $preflightCalls | ConvertTo-Json -Depth 20 -Compress
    & $pwsh -NoProfile -NonInteractive -File $sequenceScript -ExecutablePath $McpExecutablePath -Arguments $McpArguments -CallsJson $callsJson -OutputPath $preflightSequencePath -TimeoutSeconds $TimeoutSeconds | Out-Null
    $preflight = if (Test-Path -LiteralPath $preflightSequencePath) { Read-Json $preflightSequencePath } else { $null }
    $report.calls = @($preflight.calls)
    $treeCall = @($preflight.calls | Where-Object name -eq 'GetProjectTree' | Select-Object -Last 1)
    $treePayload = Get-ToolPayload $treeCall
    $treeText = if ($treePayload.tree) { [string]$treePayload.tree } else { [string]$treeCall.text }
    if ($treeText -notmatch [regex]::Escape($ProjectName)) { throw "Project tree does not contain the expected project '$ProjectName'." }
    $readinessCall = @($preflight.calls | Where-Object name -eq 'CheckDownloadReadiness' | Select-Object -Last 1)
    $downloadReadiness = Get-ToolPayload $readinessCall
    if (-not $downloadReadiness.Ready) { throw "CheckDownloadReadiness did not return Ready=true: $($readinessCall.text)" }
    $routes = @($downloadReadiness.Meta.downloadRoutes)
    $virtualRoutes = @($routes | Where-Object { [string]$_.pgPcInterface -match $VirtualInterfacePattern })
    if ($virtualRoutes.Count -eq 0) { throw "No download route matches the virtual interface pattern '$VirtualInterfacePattern'." }
    $report.preflight = [ordered]@{ readiness = $downloadReadiness; selectedRoutes = $virtualRoutes }

    $downloadCalls = @(
        @{ name = 'Bootstrap'; args = @{} },
        @{ name = 'Connect'; args = @{} },
        @{ name = 'AttachToOpenProject'; args = @{ projectName = $ProjectName } },
        @{ name = 'DownloadToPlc'; args = @{ softwarePath = $SoftwarePath; consistentBlocksOnly = $true; keepActualValues = $true; startAfterDownload = $true; stopBeforeDownload = $true; password = ''; pgPcInterface = $VirtualInterfacePattern; targetIpAddress = $TargetIpAddress } },
        @{ name = 'GetOnlineState'; args = @{ softwarePath = $SoftwarePath } },
        @{ name = 'Disconnect'; args = @{} }
    )
    $report.mutationAttempted = $true
    $downloadJson = $downloadCalls | ConvertTo-Json -Depth 20 -Compress
    & $pwsh -NoProfile -NonInteractive -File $sequenceScript -ExecutablePath $McpExecutablePath -Arguments $McpArguments -CallsJson $downloadJson -OutputPath $downloadSequencePath -TimeoutSeconds $TimeoutSeconds | Out-Null
    $download = if (Test-Path -LiteralPath $downloadSequencePath) { Read-Json $downloadSequencePath } else { $null }
    $report.calls += @($download.calls)
    if (-not $download.success) { throw "Download sequence failed; inspect calls in the report." }
    if (-not [string]::IsNullOrWhiteSpace($IoPlanPath)) {
        $report.phase = 'BEHAVIOR'
        $report.behavior = Invoke-IoPlan $virtualProcess $IoPlanPath
    }
    $report.status = 'VERIFIED'
    if (-not $report.behavior) { $report.phase = 'DOWNLOAD_AND_ONLINE_CHECK' }
    $report.nextActions = @('Registrar el comportamiento observable de la planta y, si procede, iniciar una aceptación HMI separada.')
}
catch {
    $report.status = 'FAILED'
    if (@('VIRTUAL_PLC_START', 'BEHAVIOR', 'VIRTUAL_PLC_CLEANUP') -notcontains [string]$report.phase) {
        $report.phase = if ($report.mutationAttempted) { 'DOWNLOAD_AND_ONLINE_CHECK' } else { 'PREFLIGHT' }
    }
    $report.blockers = @($_.Exception.Message)
    $report.nextActions = @('No reintentar a ciegas: revisar calls, la ruta PG/PC y el mensaje exacto de Openness.')
    $exitCode = 1
}
finally {
    if ($virtualProcess) {
        $cleanupLines = @()
        try {
            $virtualProcess.StandardInput.WriteLine('stop')
            $virtualProcess.StandardInput.Flush()
            $virtualProcess.StandardInput.Close()
        }
        catch { }
        if (-not $virtualProcess.WaitForExit($PlcSimTimeoutMs)) {
            try { $virtualProcess.Kill() } catch { }
        }
        try {
            $remaining = $virtualProcess.StandardOutput.ReadToEnd()
            if ($remaining) { $cleanupLines = @($remaining -split "`r?`n" | Where-Object { $_.Trim() }) }
        }
        catch { }
        $cleanup = $null
        foreach ($cleanupLine in $cleanupLines) {
            try { $candidate = $cleanupLine | ConvertFrom-Json; if ($candidate.status -eq 'stopped' -or $candidate.status -eq 'cleanup-failed') { $cleanup = $candidate } } catch { }
        }
        if (-not $report.virtualPlc) { $report.virtualPlc = [ordered]@{} }
        $report.virtualPlc.cleanup = $cleanup
        if ($cleanup -and $cleanup.status -eq 'cleanup-failed') {
            $report.status = 'FAILED'
            $report.phase = 'VIRTUAL_PLC_CLEANUP'
            $report.blockers = @('El adaptador PLCSIM no confirmó la limpieza completa.')
            $exitCode = 1
        }
        try { $virtualProcess.Dispose() } catch { }
    }
    foreach ($path in @($preflightSequencePath, $downloadSequencePath)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

Write-Report $report $exitCode
