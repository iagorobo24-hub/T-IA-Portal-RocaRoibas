<#
.SYNOPSIS
    Ejecuta la aceptación PLC sobre PLCSIM con gates explícitos y trazabilidad.

.DESCRIPTION
    El modo predeterminado solo genera un preview. El modo -Run exige todos los
    datos del proyecto, una confirmación de destino y un artefacto reciente de Computer Use
    que vincula la identidad visual del CPU simulado al proyecto exacto antes de la descarga.
    Se adjunta al proyecto ya abierto (AttachToOpenProject) sin abrir, cerrar ni
    sustituir ningún proyecto; con -AllowOpenProjectFallback cada sesión abre ella
    misma la fixture exacta (OpenProject con closeForeignProject=false, que rechaza
    tocar un proyecto ajeno) porque el TIA headless muere con su servidor MCP.
    Recompila, consulta CheckDownloadReadiness y solo entonces descarga si la ruta
    PG/PC identifica inequívocamente al adaptador virtual solicitado.
    Nunca elige una NIC por heurística cuando el destino es
    ambiguo. En Softbus solo reenvía pgPcInterface='PLCSIM' exacto (los targets
    Softbus no llevan IP); en TCP/IP local reenvía interfaz exacta + IP objetivo.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [string]$ReadinessPath,
    [string]$OutputPath,
    [string]$ProjectFile,
    [string]$ProjectName,
    [string]$DevicePath,
    [string]$SoftwarePath,
    [string]$SimulationTargetEvidencePath,
    [string]$TargetIpAddress,
    [string]$VirtualInterfacePattern = 'PLCSIM',
    [ValidateSet('softbus', 'tcpip-local')]
    [string]$PlcSimTransport = 'softbus',
    [string]$PlcSimAdapterPath,
    [string]$PlcSimAdapterArguments,
    [string]$PlcSimInterface = 'Siemens PLCSIM Virtual Ethernet Adapter',
    [string]$VirtualPlcName = 'TIAClaudeAcceptance_1513',
    [int]$PlcSimTimeoutMs = 60000,
    [string]$McpExecutablePath,
    [string]$McpArguments = '--tia-major-version 20 --profile full --allow-write',
    [string]$IoPlanPath,
    [int]$TimeoutSeconds = 900,
    [switch]$Run,
    [switch]$StartVirtualPlc,
    [switch]$AcknowledgeVirtualTarget,
    [switch]$AllowOpenProjectFallback
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { $WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
if ([string]::IsNullOrWhiteSpace($ReadinessPath)) { $ReadinessPath = Join-Path $WorkspaceRoot '70-runs\simulation\readiness-latest.json' }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $WorkspaceRoot '70-runs\simulation\acceptance-latest.json' }
if ([string]::IsNullOrWhiteSpace($McpExecutablePath)) { $McpExecutablePath = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe' }
$ReadinessPath = [IO.Path]::GetFullPath($ReadinessPath)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if (-not [string]::IsNullOrWhiteSpace($ProjectFile)) {
    if (-not [IO.Path]::IsPathRooted($ProjectFile)) {
        $ProjectFile = Join-Path $WorkspaceRoot $ProjectFile
    }
    $ProjectFile = [IO.Path]::GetFullPath($ProjectFile)
}
if (-not [string]::IsNullOrWhiteSpace($SimulationTargetEvidencePath)) {
    if (-not [IO.Path]::IsPathRooted($SimulationTargetEvidencePath)) {
        $SimulationTargetEvidencePath = Join-Path $WorkspaceRoot $SimulationTargetEvidencePath
    }
    $SimulationTargetEvidencePath = [IO.Path]::GetFullPath($SimulationTargetEvidencePath)
}
if ([string]::IsNullOrWhiteSpace($PlcSimAdapterPath)) {
    $apiResolver = Join-Path $WorkspaceRoot '30-tools\plcsim\Resolve-PlcSimApi.ps1'
    if (-not (Test-Path -LiteralPath $apiResolver -PathType Leaf)) { throw "PLCSIM API resolver is missing: $apiResolver" }
    . $apiResolver
    $api = Get-TiaPlcSimApiInstallation
    $apiMajor = if ($api) { $api.Major } else { 6 }
    $PlcSimAdapterPath = Join-Path $WorkspaceRoot "30-tools\plcsim\bin\v$apiMajor\tia-claude-plcsim-adapter.exe"
}
$PlcSimAdapterPath = [IO.Path]::GetFullPath($PlcSimAdapterPath)

function Read-Json([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "JSON file does not exist: $Path" }
    Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Write-Report([hashtable]$Report, [int]$ExitCode) {
    Save-ReportSnapshot $Report
    Write-Output (Get-Content -Raw -LiteralPath $OutputPath)
    if ($ExitCode -ne 0) { exit $ExitCode }
}

function Save-ReportSnapshot([object]$Report) {
    $directory = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $Report.lastUpdatedAt = [DateTimeOffset]::Now.ToString('o')
    $temporaryPath = $OutputPath + '.pending'
    ($Report | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $OutputPath -Force
}

function Get-StderrHint([object]$Sequence) {
    # A failed MCP sequence is otherwise opaque: the child's stderr carries the real
    # reason (missing fixture, parse error, execution policy). Keep the tail bounded.
    if (-not $Sequence -or [string]::IsNullOrWhiteSpace([string]$Sequence.stderr)) { return '' }
    $stderrText = ([string]$Sequence.stderr).Trim()
    if ($stderrText.Length -gt 1200) { $stderrText = '...' + $stderrText.Substring($stderrText.Length - 1200) }
    return " | stderr: $stderrText"
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
        activeSequence = $null
        lastUpdatedAt = $null
        simulationTargetEvidence = $null
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
        if ($PlcSimTransport -eq 'softbus') {
            '--register-acceptance --name "{0}" --cpu 1513 --transport softbus --timeout-ms {1}' -f $VirtualPlcName, $PlcSimTimeoutMs
        } else {
            '--register-acceptance --name "{0}" --cpu 1513 --transport tcpip-local --interface "{1}" --ip "{2}" --timeout-ms {3}' -f $VirtualPlcName, $PlcSimInterface, $TargetIpAddress, $PlcSimTimeoutMs
        }
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
    try {
        $read = $process.StandardOutput.ReadLineAsync()
        if (-not $read.Wait($PlcSimTimeoutMs)) {
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
    catch {
        if ($process -and -not $process.HasExited) {
            try { $process.StandardInput.WriteLine('stop'); $process.StandardInput.Close() } catch { }
            if (-not $process.WaitForExit(5000)) { try { $process.Kill() } catch { } }
        }
        if ($process) { try { $process.Dispose() } catch { } }
        throw
    }
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

function Read-ValidatedSimulationTargetEvidence([string]$Path, [object]$Readiness) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Falta -SimulationTargetEvidencePath; la descarga exige evidencia Computer Use del destino simulado.'
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No existe la evidencia visual del destino simulado: $Path"
    }
    $evidence = Read-Json $Path
    if ([int]$evidence.schemaVersion -ne 1 -or [string]$evidence.source -cne 'native-computer-use' -or
        -not (Test-StrictTrue $evidence.confirmed)) {
        throw 'La evidencia debe declarar schemaVersion=1, source=native-computer-use y confirmed=true.'
    }
    $evidenceProjectFile = [string]$evidence.projectFile
    if (-not [IO.Path]::IsPathRooted($evidenceProjectFile)) { $evidenceProjectFile = Join-Path $WorkspaceRoot $evidenceProjectFile }
    if ([IO.Path]::GetFullPath($evidenceProjectFile) -ine [IO.Path]::GetFullPath($ProjectFile) -or
        [string]$evidence.projectName -cne $ProjectName -or [string]$evidence.devicePath -cne $DevicePath) {
        throw 'La evidencia visual no corresponde al mismo ProjectFile, ProjectName y DevicePath de esta ejecución.'
    }
    $expectedMajor = [int]$Readiness.versions.tiaMajor
    if ([int]$evidence.tiaMajorVersion -ne $expectedMajor) {
        throw "La evidencia visual es de TIA V$($evidence.tiaMajorVersion), pero readiness declara TIA V$expectedMajor."
    }
    $expectedRoute = if ($PlcSimTransport -eq 'softbus') { 'PLCSIM' } else { $PlcSimInterface }
    if ([string]$evidence.pgPcInterface -ine $expectedRoute) {
        throw "La evidencia visual confirma '$($evidence.pgPcInterface)', no la ruta seleccionada '$expectedRoute'."
    }
    if ([string]$evidence.targetDisplayName -cne 'CPU-1500 Simulation' -or
        [string]$evidence.windowState -ine 'maximized' -or [string]$evidence.stage -cne 'before-download' -or
        [string]$evidence.downloadNotice -notmatch '(?i)The downloads are performed on a simulated CPU') {
        throw 'La evidencia debe mostrar TIA maximizado, CPU-1500 Simulation y el aviso de CPU simulada antes de descargar.'
    }
    $evidenceIp = $null
    $expectedIp = $null
    if (-not [Net.IPAddress]::TryParse([string]$evidence.targetIpAddress, [ref]$evidenceIp) -or
        -not [Net.IPAddress]::TryParse($TargetIpAddress, [ref]$expectedIp) -or $evidenceIp.ToString() -ne $expectedIp.ToString()) {
        throw 'La evidencia visual no confirma la misma TargetIpAddress solicitada para esta ejecución.'
    }
    try {
        if ($evidence.observedAt -is [DateTimeOffset]) { $observedAt = $evidence.observedAt }
        elseif ($evidence.observedAt -is [datetime]) { $observedAt = [DateTimeOffset]::new([datetime]$evidence.observedAt) }
        else { $observedAt = [DateTimeOffset]::Parse([string]$evidence.observedAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind) }
    }
    catch { throw 'La evidencia visual necesita observedAt en formato de fecha ISO 8601.' }
    $ageMinutes = ([DateTimeOffset]::Now - $observedAt).TotalMinutes
    if ($ageMinutes -gt 30 -or $ageMinutes -lt -2) {
        throw 'La evidencia visual del destino debe tener como máximo 30 minutos y no puede estar fechada en el futuro.'
    }
    [ordered]@{
        confirmed = $true
        source = [string]$evidence.source
        path = [IO.Path]::GetFullPath($Path)
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        observedAt = $observedAt.ToString('o')
        targetDisplayName = [string]$evidence.targetDisplayName
        downloadNotice = [string]$evidence.downloadNotice
        pgPcInterface = [string]$evidence.pgPcInterface
        windowState = [string]$evidence.windowState
    }
}

function Get-RequiredBoolean([object]$InputObject, [string]$PropertyName, [string]$Context) {
    $property = if ($null -ne $InputObject) { $InputObject.PSObject.Properties[$PropertyName] } else { $null }
    if (-not $property -or $property.Value -isnot [bool]) {
        throw "$Context lacks an explicit boolean '$PropertyName'; simulation download is blocked."
    }
    return [bool]$property.Value
}

function Assert-DownloadSafetyInventory([object]$BlocksPayload, [object]$TagsPayload) {
    if (-not $BlocksPayload -or -not (Test-StrictTrue $BlocksPayload.meta.success) -or
        -not $BlocksPayload.PSObject.Properties['items']) {
        throw 'GetBlocks did not return a complete successful inventory; simulation download is blocked.'
    }
    $blocks = @($BlocksPayload.items)
    if ($blocks.Count -eq 0) { throw 'GetBlocks returned no PLC blocks; simulation download is blocked.' }
    foreach ($block in $blocks) {
        $label = if ($block.path) { [string]$block.path } elseif ($block.name) { [string]$block.name } else { '<unknown block>' }
        $languageProperty = if ($null -ne $block) { $block.PSObject.Properties['programmingLanguage'] } else { $null }
        if (-not $languageProperty -or $languageProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$languageProperty.Value)) {
            throw "Block '$label' lacks an explicit programming-language classification; simulation download is blocked."
        }
        if ([string]$languageProperty.Value -match '^(?i:F(?:[-_ ]|$))') {
            throw "Block '$label' reports failsafe programming language '$($languageProperty.Value)'; simulation download is blocked."
        }
        if (Get-RequiredBoolean $block 'isFailsafe' "Block '$label'") {
            throw "Block '$label' is F/Safety; simulation download is blocked."
        }
        if (Get-RequiredBoolean $block 'isKnowHowProtected' "Block '$label'") {
            throw "Block '$label' has know-how protection; simulation download is blocked."
        }
        if (-not (Get-RequiredBoolean $block 'isConsistent' "Block '$label'")) {
            throw "Block '$label' is inconsistent after compile; simulation download is blocked."
        }
        $simulationAttribute = @($block.attributes | Where-Object {
            [string]::Equals([string]$_.name, 'PLCSimAdvancedSupport', [StringComparison]::OrdinalIgnoreCase)
        } | Select-Object -First 1)
        if ($simulationAttribute.Count -ne 1 -or $simulationAttribute[0].value -isnot [bool] -or $simulationAttribute[0].value -ne $true) {
            throw "Block '$label' does not explicitly confirm PLCSIM Advanced compilation support; enable project simulation support, compile, and read back again."
        }
    }

    if (-not $TagsPayload -or -not $TagsPayload.PSObject.Properties['items'] -or
        -not $TagsPayload.PSObject.Properties['meta'] -or -not $TagsPayload.meta.PSObject.Properties['count'] -or
        -not $TagsPayload.meta.PSObject.Properties['complete'] -or -not $TagsPayload.meta.PSObject.Properties['success']) {
        throw 'GetTags did not return items/meta.count/meta.complete/meta.success; simulation download is blocked.'
    }
    if (-not (Test-StrictTrue $TagsPayload.meta.success)) {
        throw 'GetTags did not report meta.success=true; the tag inventory may be partial. Simulation download is blocked.'
    }
    if (-not (Test-StrictTrue $TagsPayload.meta.complete)) {
        throw 'GetTags reports meta.complete=false; nested tag tables may be missing. Simulation download is blocked.'
    }
    $tags = @($TagsPayload.items)
    $expectedTagCount = 0L
    if ($TagsPayload.meta.count -is [bool] -or
        -not [long]::TryParse([string]$TagsPayload.meta.count, [ref]$expectedTagCount) -or
        $expectedTagCount -ne $tags.Count) {
        throw 'GetTags inventory count (meta.count) is incomplete or inconsistent with items; simulation download is blocked.'
    }
    foreach ($tag in $tags) {
        $label = if ($tag.path) { [string]$tag.path } elseif ($tag.name) { [string]$tag.name } else { '<unknown tag>' }
        if (Get-RequiredBoolean $tag 'isSafety' "PLC tag '$label'") {
            throw "PLC tag '$label' is Safety or ambiguously classified; simulation download is blocked."
        }
    }
    [ordered]@{ blockCount = $blocks.Count; tagCount = $tags.Count; safetyBlocks = 0; protectedBlocks = 0; safetyTags = 0; allBlocksSimulationSupported = $true }
}

$readiness = Read-Json $ReadinessPath
$report = New-BaseReport $readiness
$requiredGates = @('plcToolchainReady', 'plcsimCompatibleWithTia', 'tiaInstanceSafeForApply')
$gateBlockers = [System.Collections.Generic.List[string]]::new()
foreach ($gate in $requiredGates) {
    $gateProperty = if ($readiness.gates) { $readiness.gates.PSObject.Properties[$gate] } else { $null }
    if (-not $gateProperty -or -not (Test-StrictTrue $gateProperty.Value)) {
        $gateBlockers.Add("Readiness gate '$gate' must be the JSON boolean true.")
    }
}

$tiaMajor = $null
$advancedMajor = $null
if ($readiness.versions -and $null -ne $readiness.versions.tiaMajor) { $tiaMajor = [int]$readiness.versions.tiaMajor }
if ($readiness.versions -and [string]$readiness.versions.plcsimAdvanced -match '^\s*(\d+)') { $advancedMajor = [int]$Matches[1] }
$compatiblePair = ($null -ne $tiaMajor -and $null -ne $advancedMajor -and
    (($tiaMajor -eq 20 -and $advancedMajor -ge 7) -or
     ($tiaMajor -ge 14 -and $tiaMajor -le 19 -and $advancedMajor -ge 6)))
if (-not $compatiblePair) {
    $gateBlockers.Add("TIA Portal $tiaMajor + PLCSIM Advanced $($readiness.versions.plcsimAdvanced) no está en la matriz local admitida; simulación bloqueada.")
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

if (-not (Test-Path -LiteralPath $ProjectFile -PathType Leaf)) {
    $report.status = 'BLOCKED'
    $report.blockers = @("El proyecto TIA exacto no existe: $ProjectFile")
    $report.nextActions = @('Resuelva ProjectFile desde WorkspaceRoot o proporcione la ruta absoluta al .ap20 de la fixture.')
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

try { $report.simulationTargetEvidence = Read-ValidatedSimulationTargetEvidence -Path $SimulationTargetEvidencePath -Readiness $readiness }
catch {
    $report.status = 'BLOCKED'
    $report.blockers = @($_.Exception.Message)
    $report.nextActions = @('Confirme en TIA, sobre el proyecto y dispositivo exactos, CPU-1500 Simulation y el aviso de CPU simulada; guarde la evidencia Computer Use reciente y repita.')
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
        $report.status = 'RUNNING'
        $report.phase = 'VIRTUAL_PLC_START'
        Save-ReportSnapshot $report
        $virtualAdapterResult = Start-VirtualPlcProcess
        $virtualProcess = $virtualAdapterResult.process
        $report.virtualPlc = [ordered]@{
            started = $true
            adapterPath = [IO.Path]::GetFullPath($PlcSimAdapterPath)
            name = $VirtualPlcName
            transport = $PlcSimTransport
            interface = if ($PlcSimTransport -eq 'softbus') { 'PLCSIM' } else { $PlcSimInterface }
            targetIpAddress = $TargetIpAddress
            ready = $virtualAdapterResult.ready
        }
        Save-ReportSnapshot $report
    }
    else {
        $report.virtualPlc = [ordered]@{ started = $false; reason = 'StartVirtualPlc no solicitado; el proceso debe estar gestionado externamente.' }
    }

    $report.phase = 'PREFLIGHT'
    # Headless TIA dies with its MCP server process, so Attach across sessions is
    # impossible there: with -AllowOpenProjectFallback each session opens the exact
    # fixture path itself (closeForeignProject=false still refuses to touch a foreign
    # open project). Default (UI flow) stays Attach-only.
    $openCall = if ($AllowOpenProjectFallback) {
        @{ name = 'OpenProject'; args = @{ path = $ProjectFile; closeForeignProject = $false } }
    } else {
        @{ name = 'AttachToOpenProject'; args = @{ projectName = $ProjectName } }
    }
    $preflightCalls = @(
    @{ name = 'Bootstrap'; args = @{} },
        @{ name = 'Connect'; args = @{} },
        $openCall,
        @{ name = 'GetProjectTree'; args = @{} },
        @{ name = 'GetSoftwareTree'; args = @{ softwarePath = $SoftwarePath } },
        @{ name = 'GetDeviceIpAddress'; args = @{ devicePath = $DevicePath } },
        @{ name = 'CompileSoftware'; args = @{ softwarePath = $SoftwarePath; password = '' } },
        @{ name = 'GetBlocks'; args = @{ softwarePath = $SoftwarePath; regexName = '' } },
        @{ name = 'GetTags'; args = @{ softwarePath = $SoftwarePath } },
        @{ name = 'CheckDownloadReadiness'; args = @{ softwarePath = $SoftwarePath } },
        @{ name = 'Disconnect'; args = @{} }
    )
    $callsJsonPath = $preflightSequencePath + '.calls.json'
    ($preflightCalls | ConvertTo-Json -Depth 20 -Compress) | Set-Content -LiteralPath $callsJsonPath -Encoding UTF8
    $report.status = 'RUNNING'
    $report.activeSequence = [ordered]@{ kind = 'preflight'; outputPath = $preflightSequencePath; startedAt = [DateTimeOffset]::Now.ToString('o') }
    Save-ReportSnapshot $report
    & $pwsh -NoProfile -NonInteractive -File $sequenceScript -ExecutablePath $McpExecutablePath -Arguments $McpArguments -CallsJsonPath $callsJsonPath -OutputPath $preflightSequencePath -TimeoutSeconds $TimeoutSeconds -CaptureStderr | Out-Null
    $preflight = if (Test-Path -LiteralPath $preflightSequencePath) { Read-Json $preflightSequencePath } else { $null }
    $report.activeSequence = $null
    if ($preflight) { $report.calls = @($preflight.calls) }
    Save-ReportSnapshot $report
    if (-not $preflight -or -not (Test-StrictTrue $preflight.success)) {
        $sequenceFailure = if ($preflight.error) { [string]$preflight.error } else { 'no sequence result file was produced' }
        throw "The MCP preflight sequence did not complete successfully: $sequenceFailure$(Get-StderrHint $preflight)"
    }
    $openCallName = if ($AllowOpenProjectFallback) { 'OpenProject' } else { 'AttachToOpenProject' }
    $attachCall = @($preflight.calls | Where-Object name -eq $openCallName | Select-Object -Last 1)
    if ($attachCall.Count -ne 1 -or -not (Test-StrictTrue $attachCall[0].success)) { throw "$openCallName did not bind the exact project '$ProjectName' ('$ProjectFile'); refusing to open or replace any other project." }
    $attachPayload = Get-ToolPayload ($attachCall | Select-Object -First 1)
    $attachText = if ($attachPayload.message) { [string]$attachPayload.message } else { [string]$attachCall[0].text }
    if ($attachText -notmatch [regex]::Escape($ProjectName)) { throw "$openCallName did not confirm the exact project '$ProjectName'." }
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
    $blocksCall = @($preflight.calls | Where-Object name -eq 'GetBlocks' | Select-Object -Last 1)
    $tagsCall = @($preflight.calls | Where-Object name -eq 'GetTags' | Select-Object -Last 1)
    $blocksPayload = Get-ToolPayload ($blocksCall | Select-Object -First 1)
    $tagsPayload = Get-ToolPayload ($tagsCall | Select-Object -First 1)
    $report.safetyPreflight = Assert-DownloadSafetyInventory -BlocksPayload $blocksPayload -TagsPayload $tagsPayload
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
    if ([string]$adapterReady.status -ne 'ready') { throw 'PLCSIM runtime no confirma status=ready.' }
    if ($PlcSimTransport -eq 'softbus') {
        if ([string]$adapterReady.networkMode -ne 'SOFTBUS' -or [string]$adapterReady.interfaceName -ne 'PLCSIM' -or $null -ne $adapterReady.ip) {
            throw 'La instancia no confirma Softbus local (SOFTBUS/PLCSIM/sin IP).'
        }
        $adapterIp = $null
    } else {
        if ([string]$adapterReady.networkMode -ne 'TCPIP_SINGLE_ADAPTER') { throw 'La instancia no confirma TCP/IP Single Adapter.' }
        $adapterIp = $null
        if (-not [Net.IPAddress]::TryParse([string]$adapterReady.ip, [ref]$adapterIp) -or $adapterIp.ToString() -ne $parsedTargetIp.ToString()) {
            throw "La instancia PLCSIM lista no confirma la misma IP objetivo ($TargetIpAddress)."
        }
        $adapterInterfaces = @([string]$adapterReady.interfaceName, [string]$adapterReady.interfaceDescription) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
        if (@($adapterInterfaces | Where-Object { [string]::Equals($_, $PlcSimInterface, [StringComparison]::OrdinalIgnoreCase) }).Count -ne 1) {
            throw "La instancia PLCSIM no confirma la interfaz virtual esperada '$PlcSimInterface'."
        }
    }
    # NOTE: the runner-managed adapter identity above never selects the download route by
    # itself. Route selection below uses only the exact names enumerated by
    # CheckDownloadReadiness; no NIC heuristic is applied.
    $expectedRouteName = if ($PlcSimTransport -eq 'softbus') { 'PLCSIM' } else { $PlcSimInterface }
    $virtualRoutes = @($routes | Where-Object {
        $routeName = [string]$_.pgPcInterface
        $patternMatch = $false
        try { $patternMatch = ($routeName -match $VirtualInterfacePattern) } catch { throw "VirtualInterfacePattern no es una expresión válida: $VirtualInterfacePattern" }
        # Exact name match on purpose: a substring would confuse Softbus 'PLCSIM' with the
        # TCP/IP 'Siemens PLCSIM Virtual Ethernet Adapter' NIC. Never fall back to another NIC.
        $exactNameMatch = [string]::Equals($routeName, $expectedRouteName, [StringComparison]::OrdinalIgnoreCase)
        $patternMatch -and $exactNameMatch
    })
    if ($virtualRoutes.Count -ne 1) {
        if ($PlcSimTransport -eq 'softbus') {
            throw "Softbus route 'PLCSIM' is not enumerated exactly once by CheckDownloadReadiness (found $($virtualRoutes.Count)). Possible causes: no virtual instance running, or the TIA PG/PC access path is not set to PLCSIM. Falling back to a physical NIC is forbidden; fix the Softbus setup and retry."
        }
        throw "Se esperaba exactamente una ruta para '$expectedRouteName' con patrón '$VirtualInterfacePattern'; se encontraron $($virtualRoutes.Count)."
    }
    $selectedRoute = $virtualRoutes[0]
    if ($PlcSimTransport -eq 'softbus') {
        # Softbus targets carry no IP (runtime reports ip=null); the project IP was already
        # validated against GetDeviceIpAddress above. Passing targetIpAddress here would make
        # the server filter routes against TargetAddresses and reject the download, so only
        # the exact PG/PC interface name is forwarded.
        $downloadRouteArgs = @{ pgPcInterface = [string]$selectedRoute.pgPcInterface }
    }
    else {
        foreach ($ipPropertyName in @('targetIpAddress', 'ipAddress', 'cpuIpAddress', 'targetAddress')) {
            $routeIpProperty = $selectedRoute.PSObject.Properties[$ipPropertyName]
            if ($routeIpProperty -and -not [string]::Equals([string]$routeIpProperty.Value, $parsedTargetIp.ToString(), [StringComparison]::OrdinalIgnoreCase)) {
                throw "La ruta seleccionada declara $ipPropertyName='$($routeIpProperty.Value)', no la IP objetivo '$TargetIpAddress'."
            }
        }
        $downloadRouteArgs = @{ pgPcInterface = [string]$selectedRoute.pgPcInterface; targetIpAddress = $parsedTargetIp.ToString() }
    }
    $report.preflight = [ordered]@{
        readiness = $downloadReadiness
        configuredDeviceIpAddresses = $configuredIpAddresses
        virtualInstance = [ordered]@{ transport = $PlcSimTransport; ip = if ($adapterIp) { $adapterIp.ToString() } else { $null }; interfaceName = $adapterReady.interfaceName; interfaceDescription = $adapterReady.interfaceDescription }
        selectedRoutes = @($selectedRoute)
        downloadRouteArgs = $downloadRouteArgs
    }

    $downloadArgs = @{ softwarePath = $SoftwarePath; consistentBlocksOnly = $true; keepActualValues = $true; startAfterDownload = $true; stopBeforeDownload = $true; password = '' }
    foreach ($key in @($downloadRouteArgs.Keys)) { $downloadArgs[$key] = $downloadRouteArgs[$key] }
    $downloadCalls = @(
        @{ name = 'Bootstrap'; args = @{} },
        @{ name = 'Connect'; args = @{} },
        $openCall,
        @{ name = 'DownloadToPlc'; args = $downloadArgs },
        @{ name = 'GetOnlineState'; args = @{ softwarePath = $SoftwarePath } },
        @{ name = 'Disconnect'; args = @{} }
    )
    $report.phase = 'DOWNLOAD_AND_ONLINE_CHECK'
    $report.status = 'RUNNING'
    $report.mutationAttempted = $true
    $report.activeSequence = [ordered]@{ kind = 'download'; outputPath = $downloadSequencePath; startedAt = [DateTimeOffset]::Now.ToString('o'); outcome = 'not yet recorded' }
    Save-ReportSnapshot $report
    $downloadCallsPath = $downloadSequencePath + '.calls.json'
    ($downloadCalls | ConvertTo-Json -Depth 20 -Compress) | Set-Content -LiteralPath $downloadCallsPath -Encoding UTF8
    & $pwsh -NoProfile -NonInteractive -File $sequenceScript -ExecutablePath $McpExecutablePath -Arguments $McpArguments -CallsJsonPath $downloadCallsPath -OutputPath $downloadSequencePath -TimeoutSeconds $TimeoutSeconds -CaptureStderr | Out-Null


    $download = if (Test-Path -LiteralPath $downloadSequencePath) { Read-Json $downloadSequencePath } else { $null }
    $report.activeSequence = $null
    if ($download) { $report.calls += @($download.calls) }
    Save-ReportSnapshot $report
    if (-not $download.success) {
        $downloadFailure = if ($download.error) { [string]$download.error } else { 'inspect calls in the report' }
        throw "Download sequence failed: $downloadFailure$(Get-StderrHint $download)"
    }
    $downloadOpenCall = @($download.calls | Where-Object name -eq $openCallName | Select-Object -Last 1)
    if ($downloadOpenCall.Count -ne 1 -or -not (Test-StrictTrue $downloadOpenCall[0].success)) { throw "Download session did not bind the exact project via $openCallName; refusing to download." }
    $downloadCall = @($download.calls | Where-Object name -eq 'DownloadToPlc' | Select-Object -Last 1)
    $downloadPayload = Get-ToolPayload ($downloadCall | Select-Object -First 1)
    $downloadState = if ($downloadPayload) { $downloadPayload.PSObject.Properties['state'] } else { $null }
    if (-not $downloadState -or [string]$downloadState.Value -cne 'Success') {
        throw "DownloadToPlc did not report an explicit Success state; acceptance is blocked. Response: $($downloadCall.text)"
    }
    $report.download = [ordered]@{ success = $true; state = [string]$downloadState.Value; response = $downloadPayload }
    $onlineCall = @($download.calls | Where-Object name -eq 'GetOnlineState' | Select-Object -Last 1)
    $onlinePayload = Get-ToolPayload ($onlineCall | Select-Object -First 1)
    $onlineState = if ($onlinePayload) { $onlinePayload.PSObject.Properties['state'] } else { $null }
    if (-not $onlineState -or [string]$onlineState.Value -cne 'Online') {
        throw "GetOnlineState did not confirm Online after download; acceptance is blocked. Response: $($onlineCall.text)"
    }
    $report.online = [ordered]@{ confirmed = $true; state = [string]$onlineState.Value; response = $onlinePayload }
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
        if (-not $cleanup -or $cleanup.status -ne 'stopped') {
            $report.status = 'FAILED'
            $report.phase = 'VIRTUAL_PLC_CLEANUP'
            $report.blockers = @('El adaptador PLCSIM no confirmó la limpieza completa.')
            $exitCode = 1
        }
        try { $virtualProcess.Dispose() } catch { }
    }
    Save-ReportSnapshot $report
    foreach ($path in @($preflightSequencePath, $preflightSequencePath + '.calls.json', $downloadSequencePath, $downloadSequencePath + '.calls.json')) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

Write-Report $report $exitCode
