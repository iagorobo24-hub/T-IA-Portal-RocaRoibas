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
    [string]$DevicePath,
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
        project = [ordered]@{ file = $ProjectFile; name = $ProjectName; devicePath = $DevicePath; softwarePath = $SoftwarePath; targetIpAddress = $TargetIpAddress }
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

function Invoke-IoPlan([Diagnostics.Process]$Process, [string]$Path, [object]$Plan, [string]$Sha256) {
    if ($null -eq $Process) { throw 'IoPlanPath requiere -StartVirtualPlc para disponer del proceso nativo.' }
    $plan = $Plan
    $steps = @($plan.steps)
    if ($steps.Count -eq 0) { throw "El plan de E/S no contiene steps: $Path" }
    $results = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $steps.Count; $index++) {
        $step = $steps[$index]
        $command = [string]$step.command
        if ([string]::IsNullOrWhiteSpace($command)) { throw "El step $index no tiene command." }
        if (-not $step.expect -or @($step.expect.PSObject.Properties).Count -eq 0) {
            throw "El step $index debe declarar expect para que la evidencia pueda marcarse como verificada."
        }
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
        if ($step.delayMs) {
            Start-Sleep -Milliseconds ([int]$step.delayMs)
        }
    }
    [ordered]@{
        schemaVersion = 1
        name = [string]$plan.name
        planPath = [IO.Path]::GetFullPath($Path)
        sha256 = $Sha256
        verified = $true
        steps = @($results)
    }
}

function Get-IpAddressPropertyValues([object]$InputObject) {
    $values = [System.Collections.Generic.List[string]]::new()
    $pending = [System.Collections.Generic.List[object]]::new()
    if ($null -ne $InputObject) { $pending.Add($InputObject) }
    $addressPropertyNames = @('primaryaddress', 'primaryipaddress', 'ipaddress', 'ip', 'address')
    while ($pending.Count -gt 0) {
        $lastIndex = $pending.Count - 1
        $node = $pending[$lastIndex]
        $pending.RemoveAt($lastIndex)
        if ($null -eq $node -or $node -is [string]) { continue }
        if ($node -is [System.Collections.IDictionary]) {
            foreach ($key in $node.Keys) {
                $value = $node[$key]
                if ($addressPropertyNames -contains ([string]$key).ToLowerInvariant() -and $value -is [string]) {
                    $parsed = $null
                    if ([Net.IPAddress]::TryParse([string]$value, [ref]$parsed)) { $values.Add($parsed.ToString()) }
                }
                if ($null -ne $value -and $value -isnot [string]) { $pending.Add($value) }
            }
            continue
        }
        if ($node -is [System.Collections.IEnumerable]) {
            foreach ($item in $node) { if ($null -ne $item) { $pending.Add($item) } }
            continue
        }
        foreach ($property in @($node.PSObject.Properties)) {
            if ($addressPropertyNames -contains $property.Name.ToLowerInvariant() -and $property.Value -is [string]) {
                $parsed = $null
                if ([Net.IPAddress]::TryParse([string]$property.Value, [ref]$parsed)) { $values.Add($parsed.ToString()) }
            }
            if ($null -ne $property.Value -and $property.Value -isnot [string]) { $pending.Add($property.Value) }
        }
    }
    @($values | Select-Object -Unique)
}

function Read-ValidatedIoPlan([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Falta -IoPlanPath; no se acepta una descarga sin plan de comportamiento.' }
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "El plan de E/S no existe: $fullPath" }
    $plan = Read-Json $fullPath
    if ($null -eq $plan -or [int]$plan.schemaVersion -ne 1) { throw 'El plan de E/S debe ser JSON con schemaVersion=1.' }
    if ([string]::IsNullOrWhiteSpace([string]$plan.name)) { throw 'El plan de E/S necesita un name no vacío.' }
    $steps = @($plan.steps)
    if ($steps.Count -eq 0) { throw 'El plan de E/S no contiene steps.' }
    $hasFunctionalObservation = $false
    $allowedCommands = @('read-area-size', 'read-bit', 'write-bit', 'read-byte', 'write-byte', 'read-bool-tag', 'write-bool-tag', 'read-uint8-tag', 'write-uint8-tag', 'read-float-tag', 'write-float-tag')
    foreach ($index in 0..($steps.Count - 1)) {
        $step = $steps[$index]
        $command = [string]$step.command
        if ([string]::IsNullOrWhiteSpace($command)) { throw "El step $index no tiene command." }
        if ($command -match '[\r\n\x00]') { throw "El step $index command debe ocupar una sola línea y no contener NUL." }
        $operation = ($command -split '\s+', 2)[0]
        if ($allowedCommands -notcontains $operation) { throw "El step $index usa una operación no permitida por el adaptador PLCSIM: '$operation'." }
        if (-not $step.expect -or @($step.expect.PSObject.Properties).Count -eq 0) { throw "El step $index debe declarar expect." }
        if ($operation -like 'read-*') {
            $functionalProperties = @($step.expect.PSObject.Properties | Where-Object { $_.Name -notin @('status', 'op') })
            if ($functionalProperties.Count -eq 0) { throw "El step de lectura $index debe comprobar al menos un valor funcional, además de status/op." }
            $tokens = @($command -split '\s+')
            $readsOutputArea = $operation -in @('read-bit', 'read-byte') -and $tokens.Count -gt 1 -and $tokens[1] -eq 'output'
            $readsSymbolicTag = $operation -in @('read-bool-tag', 'read-uint8-tag', 'read-float-tag')
            if ($readsOutputArea -or $readsSymbolicTag) { $hasFunctionalObservation = $true }
        }
    }
    if (-not $hasFunctionalObservation) { throw 'El plan debe leer y comprobar al menos un valor funcional observable.' }
    [pscustomobject]@{
        path = $fullPath
        plan = $plan
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
}

function Test-StrictTrue([object]$Value) {
    return ($Value -is [bool] -and $Value -eq $true)
}

$readiness = Read-Json $ReadinessPath
$report = New-BaseReport $readiness
$requiredGates = @('plcToolchainReady', 'plcsimVirtualAdapterReady', 'tiaInstanceSafeForApply')
$gateBlockers = [System.Collections.Generic.List[string]]::new()
foreach ($gate in $requiredGates) {
    $gateProperty = if ($readiness.gates) { $readiness.gates.PSObject.Properties[$gate] } else { $null }
    if (-not $gateProperty -or -not (Test-StrictTrue $gateProperty.Value)) {
        $gateBlockers.Add("Readiness gate '$gate' must be the JSON boolean true.")
    }
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
    @{ name = 'DevicePath'; value = $DevicePath },
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

if (-not $StartVirtualPlc) {
    $report.status = 'BLOCKED'
    $report.blockers = @('La aceptación requiere -StartVirtualPlc para identificar, mantener y limpiar la instancia virtual usada por el plan.')
    $report.nextActions = @('No use destinos externos gestionados fuera del runner; proporcione una instancia PLCSIM desechable gestionada por este flujo.')
    Write-Report $report 2
}

$validatedIoPlan = $null
try { $validatedIoPlan = Read-ValidatedIoPlan $IoPlanPath }
catch {
    $report.status = 'BLOCKED'
    $report.blockers = @($_.Exception.Message)
    $report.nextActions = @('Corrija el plan de E/S y compruebe sus expectativas funcionales antes de iniciar PLCSIM o contactar con el servidor MCP.')
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
        @{ name = 'GetSoftwareTree'; args = @{ softwarePath = $SoftwarePath } },
        @{ name = 'GetDeviceIpAddress'; args = @{ devicePath = $DevicePath } },
        @{ name = 'CompileSoftware'; args = @{ softwarePath = $SoftwarePath; password = '' } },
        @{ name = 'CheckDownloadReadiness'; args = @{ softwarePath = $SoftwarePath } },
        @{ name = 'Disconnect'; args = @{} }
    )
    $callsJson = $preflightCalls | ConvertTo-Json -Depth 20 -Compress
    & $pwsh -NoProfile -NonInteractive -File $sequenceScript -ExecutablePath $McpExecutablePath -Arguments $McpArguments -CallsJson $callsJson -OutputPath $preflightSequencePath -TimeoutSeconds $TimeoutSeconds | Out-Null
    $preflight = if (Test-Path -LiteralPath $preflightSequencePath) { Read-Json $preflightSequencePath } else { $null }
    if (-not $preflight -or -not (Test-StrictTrue $preflight.success)) { throw 'The MCP preflight sequence did not complete successfully.' }
    $report.calls = @($preflight.calls)
    $treeCall = @($preflight.calls | Where-Object name -eq 'GetProjectTree' | Select-Object -Last 1)
    $treePayload = Get-ToolPayload $treeCall
    $treeText = if ($treePayload.tree) { [string]$treePayload.tree } else { [string]$treeCall.text }
    if ($treeText -notmatch [regex]::Escape($ProjectName)) { throw "Project tree does not contain the expected project '$ProjectName'." }
    if ($treeText -notmatch [regex]::Escape($DevicePath)) { throw "DevicePath '$DevicePath' was not read from GetProjectTree." }
    if ($treeText -notmatch [regex]::Escape($SoftwarePath)) { throw "SoftwarePath '$SoftwarePath' was not read from GetProjectTree." }
    $softwareTreeCall = @($preflight.calls | Where-Object name -eq 'GetSoftwareTree' | Select-Object -Last 1)
    $softwareTreePayload = Get-ToolPayload $softwareTreeCall
    $softwareTreeText = if ($softwareTreePayload.tree) { [string]$softwareTreePayload.tree } else { [string]$softwareTreeCall.text }
    if ($softwareTreeText -notmatch [regex]::Escape($SoftwarePath)) { throw "GetSoftwareTree did not confirm the exact SoftwarePath '$SoftwarePath'." }
    $compileCall = @($preflight.calls | Where-Object name -eq 'CompileSoftware' | Select-Object -Last 1)
    $compilePayload = Get-ToolPayload $compileCall
    $compileStateProperty = if ($compilePayload) { $compilePayload.PSObject.Properties['state'] } else { $null }
    $compileErrorsProperty = if ($compilePayload) { $compilePayload.PSObject.Properties['errorCount'] } else { $null }
    $compileWarningsProperty = if ($compilePayload) { $compilePayload.PSObject.Properties['warningCount'] } else { $null }
    if (-not $compileStateProperty -or [string]$compileStateProperty.Value -ne 'Success' -or
        -not $compileErrorsProperty -or [int]$compileErrorsProperty.Value -ne 0 -or
        -not $compileWarningsProperty -or [int]$compileWarningsProperty.Value -ne 0) {
        throw 'CompileSoftware debe terminar en Success con 0 errores y 0 avisos antes de descargar.'
    }
    $deviceIpCall = @($preflight.calls | Where-Object name -eq 'GetDeviceIpAddress' | Select-Object -Last 1)
    $deviceIpPayload = Get-ToolPayload $deviceIpCall
    $configuredIpAddresses = @(Get-IpAddressPropertyValues $deviceIpPayload)
    $parsedTargetIp = $null
    if (-not [Net.IPAddress]::TryParse($TargetIpAddress, [ref]$parsedTargetIp)) { throw "TargetIpAddress no es una dirección IP válida: '$TargetIpAddress'." }
    if ($configuredIpAddresses -notcontains $parsedTargetIp.ToString()) {
        throw "La IP objetivo '$TargetIpAddress' no aparece en las direcciones leídas de GetDeviceIpAddress para '$DevicePath'."
    }
    $readinessCall = @($preflight.calls | Where-Object name -eq 'CheckDownloadReadiness' | Select-Object -Last 1)
    $downloadReadiness = Get-ToolPayload $readinessCall
    if (-not (Test-StrictTrue $downloadReadiness.Ready) -or -not (Test-StrictTrue $downloadReadiness.IsConsistent)) {
        throw "CheckDownloadReadiness debe devolver Ready=true e IsConsistent=true: $($readinessCall.text)"
    }
    $routes = @($downloadReadiness.Meta.downloadRoutes)
    $adapterReady = $virtualAdapterResult.ready
    $adapterIp = $null
    if (-not [Net.IPAddress]::TryParse([string]$adapterReady.ip, [ref]$adapterIp) -or $adapterIp.ToString() -ne $parsedTargetIp.ToString()) {
        throw "La instancia PLCSIM lista no confirma la misma IP objetivo ($TargetIpAddress)."
    }
    $adapterInterfaces = @(
        [string]$adapterReady.interfaceName,
        [string]$adapterReady.interfaceDescription
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    if (@($adapterInterfaces | Where-Object { [string]::Equals($_, $PlcSimInterface, [StringComparison]::OrdinalIgnoreCase) }).Count -ne 1) {
        throw "La instancia PLCSIM no confirma la interfaz virtual esperada '$PlcSimInterface'."
    }
    $virtualRoutes = @($routes | Where-Object {
        $routeName = [string]$_.pgPcInterface
        $patternMatch = $false
        try { $patternMatch = ($routeName -match $VirtualInterfacePattern) } catch { throw "VirtualInterfacePattern no es una expresión válida: $VirtualInterfacePattern" }
        $exactAdapterMatch = @($adapterInterfaces | Where-Object { [string]::Equals($_, $routeName, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
        $patternMatch -and $exactAdapterMatch
    })
    if ($virtualRoutes.Count -ne 1) { throw "Se esperaba exactamente una ruta para '$PlcSimInterface' con patrón '$VirtualInterfacePattern'; se encontraron $($virtualRoutes.Count)." }
    $selectedRoute = $virtualRoutes[0]
    foreach ($ipPropertyName in @('targetIpAddress', 'ipAddress', 'cpuIpAddress', 'targetAddress')) {
        $routeIpProperty = $selectedRoute.PSObject.Properties[$ipPropertyName]
        if ($routeIpProperty -and -not [string]::Equals([string]$routeIpProperty.Value, $parsedTargetIp.ToString(), [StringComparison]::OrdinalIgnoreCase)) {
            throw "La ruta seleccionada declara $ipPropertyName='$($routeIpProperty.Value)', no la IP objetivo '$TargetIpAddress'."
        }
    }
    $report.preflight = [ordered]@{
        readiness = $downloadReadiness
        configuredDeviceIpAddresses = $configuredIpAddresses
        virtualInstance = [ordered]@{ ip = $adapterIp.ToString(); interfaceName = $adapterReady.interfaceName; interfaceDescription = $adapterReady.interfaceDescription }
        selectedRoutes = @($selectedRoute)
    }

    $downloadCalls = @(
        @{ name = 'Bootstrap'; args = @{} },
        @{ name = 'Connect'; args = @{} },
        @{ name = 'AttachToOpenProject'; args = @{ projectName = $ProjectName } },
        @{ name = 'DownloadToPlc'; args = @{ softwarePath = $SoftwarePath; consistentBlocksOnly = $true; keepActualValues = $true; startAfterDownload = $true; stopBeforeDownload = $true; password = ''; pgPcInterface = [string]$selectedRoute.pgPcInterface; targetIpAddress = $parsedTargetIp.ToString() } },
        @{ name = 'GetOnlineState'; args = @{ softwarePath = $SoftwarePath } },
        @{ name = 'Disconnect'; args = @{} }
    )
    $report.mutationAttempted = $true
    $downloadJson = $downloadCalls | ConvertTo-Json -Depth 20 -Compress
    & $pwsh -NoProfile -NonInteractive -File $sequenceScript -ExecutablePath $McpExecutablePath -Arguments $McpArguments -CallsJson $downloadJson -OutputPath $downloadSequencePath -TimeoutSeconds $TimeoutSeconds | Out-Null
    $download = if (Test-Path -LiteralPath $downloadSequencePath) { Read-Json $downloadSequencePath } else { $null }
    $report.calls += @($download.calls)
    if (-not $download.success) { throw "Download sequence failed; inspect calls in the report." }
    $report.phase = 'BEHAVIOR'
    $report.behavior = Invoke-IoPlan $virtualProcess $validatedIoPlan.path $validatedIoPlan.plan $validatedIoPlan.sha256
    $report.status = 'VERIFIED'
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
