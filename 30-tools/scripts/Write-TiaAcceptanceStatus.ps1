[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '70-runs\acceptance\status-latest.json'),
    [string]$ChecksPath,
    [string]$EnvironmentPath,
    [string]$ReadinessPath,
    [string]$PortableValidationPath,
    [string]$PortableCoreManifestPath,
    [string[]]$ComputerUseEvidencePaths
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $ChecksPath) { $ChecksPath = Join-Path $WorkspaceRoot '70-runs\checks\latest.json' }
if (-not $EnvironmentPath) { $EnvironmentPath = Join-Path $WorkspaceRoot '70-runs\environment\latest.json' }
if (-not $ReadinessPath) { $ReadinessPath = Join-Path $WorkspaceRoot '70-runs\simulation\readiness-latest.json' }
if (-not $PortableCoreManifestPath) { $PortableCoreManifestPath = Join-Path $WorkspaceRoot 'TIA-Claude_Portable\dist\TIA-Claude_Core\manifests\package-manifest.json' }
$ChecksPath = [IO.Path]::GetFullPath($ChecksPath)
$EnvironmentPath = [IO.Path]::GetFullPath($EnvironmentPath)
$ReadinessPath = [IO.Path]::GetFullPath($ReadinessPath)
$PortableCoreManifestPath = [IO.Path]::GetFullPath($PortableCoreManifestPath)

if (-not $ComputerUseEvidencePaths -or $ComputerUseEvidencePaths.Count -eq 0) {
    $computerUseEvidenceDirectory = Join-Path $WorkspaceRoot '70-runs\environment'
    $ComputerUseEvidencePaths = @(
        Get-ChildItem -LiteralPath $computerUseEvidenceDirectory -Filter 'computer-use-*.json' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime |
            ForEach-Object { $_.FullName }
    )
}
$ComputerUseEvidencePaths = @(
    $ComputerUseEvidencePaths |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
        ForEach-Object { [IO.Path]::GetFullPath([string]$_) } |
        Select-Object -Unique
)

function Read-JsonIfPresent([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } catch { return $null }
}

function Add-UniqueFinding([System.Collections.Generic.List[string]]$List, [string]$Value) {
    if (-not [string]::IsNullOrWhiteSpace($Value) -and -not ($List -contains $Value)) {
        $List.Add($Value) | Out-Null
    }
}

function Get-ComputerUseAction($Evidence, [string]$ActionName) {
    if (-not $Evidence -or -not $Evidence.actions) { return $null }
    return @($Evidence.actions | Where-Object { $_.action -eq $ActionName } | Select-Object -First 1)[0]
}

function Test-ComputerUseAction($Evidence, [string]$ActionName) {
    $action = Get-ComputerUseAction $Evidence $ActionName
    return [bool]($action -and (($action.status -eq 'verified') -or ($action.result -eq 'verified')))
}

function Test-ComputerUseProperty($Object, [string[]]$Names) {
    if ($null -eq $Object) { return $false }
    foreach ($name in $Names) {
        if ($null -ne $Object.PSObject.Properties[$name]) { return $true }
    }
    return $false
}

function Test-ComputerUseSafetyEvidencePresent($Evidence) {
    if (-not $Evidence) { return $false }

    # A present-but-empty safety object is not a declaration. Require explicit
    # fields covering the download, Safety/F-block, and original-project
    # boundaries before allowing an evidence record to establish a boundary.
    if ($null -ne $Evidence.safetyAndHardware -and
        (Test-ComputerUseProperty $Evidence.safetyAndHardware @('physicalDownload')) -and
        (Test-ComputerUseProperty $Evidence.safetyAndHardware @('safetyOrFBlockEdited', 'knowHowTouched')) -and
        (Test-ComputerUseProperty $Evidence.safetyAndHardware @('originalProjectModified', 'originalProjectChange', 'originalProjectOpened'))) {
        return $true
    }
    if ($null -ne $Evidence.safety -and
        (Test-ComputerUseProperty $Evidence.safety @('physical_download')) -and
        (Test-ComputerUseProperty $Evidence.safety @('f_blocks_or_safety_tags_modified', 'know_how_touched')) -and
        (Test-ComputerUseProperty $Evidence.safety @('original_project_modified', 'original_project_opened'))) {
        return $true
    }
    if ($Evidence.originalSourcePreserved -eq $true -and
        ($Evidence.sourceBaselineCompared -eq $true -or $Evidence.sourceBaselineUnchanged -eq $true)) {
        return $true
    }
    foreach ($actionName in @('physicalDownload', 'safetyOrKnowHowChange', 'originalProjectChange')) {
        $action = Get-ComputerUseAction $Evidence $actionName
        if ($action -and (
                $action.status -in @('verified', 'not_performed') -or
                $action.result -in @('verified', 'not_performed'))) {
            return $true
        }
    }
    return $false
}

function Test-ComputerUseSafetyBoundary($Evidence) {
    if (-not (Test-ComputerUseSafetyEvidencePresent $Evidence)) { return $false }

    $physicalDownload = ($Evidence.physicalDownload -eq $true) -or ($Evidence.safety -and $Evidence.safety.physical_download -eq $true)
    $originalProjectModified = ($Evidence.originalProjectModified -eq $true) -or
        ($Evidence.safety -and $Evidence.safety.original_project_modified -eq $true)
    if ($physicalDownload -or $originalProjectModified) { return $false }
    if ($Evidence.safetyAndHardware -and (
            $Evidence.safetyAndHardware.physicalDownload -eq $true -or
            $Evidence.safetyAndHardware.safetyOrFBlockEdited -eq $true -or
            $Evidence.safetyAndHardware.knowHowTouched -eq $true -or
            $Evidence.safetyAndHardware.originalProjectModified -eq $true -or
            $Evidence.safetyAndHardware.originalProjectChange -eq $true)) {
        return $false
    }
    if ($Evidence.safety -and (
            $Evidence.safety.f_blocks_or_safety_tags_modified -eq $true -or
            $Evidence.safety.know_how_touched -eq $true)) {
        return $false
    }

    foreach ($actionName in @('physicalDownload', 'safetyOrKnowHowChange', 'originalProjectChange')) {
        $action = Get-ComputerUseAction $Evidence $actionName
        if ($action -and (($action.status -eq 'verified') -or ($action.result -eq 'verified'))) { return $false }
    }
    return $true
}

$verified = [System.Collections.Generic.List[string]]::new()
$notVerified = [System.Collections.Generic.List[string]]::new()
$blocked = [System.Collections.Generic.List[string]]::new()
$assumptions = [System.Collections.Generic.List[string]]::new()

$checks = Read-JsonIfPresent $ChecksPath
function Has-PassingCheck([string]$Name) {
    return [bool]($checks -and @($checks.checks | Where-Object { $_.name -eq $Name -and $_.status -eq 'PASS' }).Count -gt 0)
}

$environment = Read-JsonIfPresent $EnvironmentPath
$activeTiaMajor = if ($environment -and $environment.tiaMajor) {
    [int]$environment.tiaMajor
} elseif ($environment -and $environment.activeTiaMajorVersion) {
    [int]$environment.activeTiaMajorVersion
} elseif ($environment -and $environment.calls -and $environment.calls[0].response.structuredContent.activeTiaMajorVersion) {
    [int]$environment.calls[0].response.structuredContent.activeTiaMajorVersion
} else { $null }
if ($activeTiaMajor -eq 20) { $verified.Add('TIA Portal/Openness V20 baseline') }
else { $notVerified.Add('TIA Portal/Openness V20 baseline') }

$createSmoke = Read-JsonIfPresent (Join-Path $WorkspaceRoot '70-runs\environment\tia-create-smoke.json')
if ($createSmoke -and $createSmoke.success -eq $true) { $verified.Add('tia-create MCP startup and lite tool roster') }
else { $notVerified.Add('tia-create MCP startup and lite tool roster') }

$portableValidation = if ($PortableValidationPath) { Read-JsonIfPresent ([IO.Path]::GetFullPath($PortableValidationPath)) } else { $null }
$portableChecks = if ($portableValidation -and $portableValidation.checks) { @($portableValidation.checks.PSObject.Properties | ForEach-Object { $_.Value.status }) } else { @() }
$portableOk = $portableValidation -and $portableChecks.Count -gt 0 -and (@($portableChecks | Where-Object { $_ -ne 'PASS' }).Count -eq 0)
if ($portableOk -or (-not $portableValidation -and (Has-PassingCheck 'portable-install-relocation'))) { $verified.Add('portable core installation and relocation') }
else { $notVerified.Add('portable core installation and relocation') }

if (Has-PassingCheck 'harness-adapters') { $verified.Add('deterministic cross-harness MCP adapters') }
else { $notVerified.Add('deterministic cross-harness MCP adapters') }

$sweep = Read-JsonIfPresent (Join-Path $WorkspaceRoot '70-runs\standards\sweep-20260915-all\sweep-report.json')
if ($sweep -and $sweep.success -eq $true -and $sweep.collectionErrorCount -eq 0) { $verified.Add('read-only inventory of all seven examples') }
else { $notVerified.Add('read-only inventory of all seven examples') }

$writeReports = @(Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'report.json' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending)
$writeReport = $null
foreach ($candidate in $writeReports) {
    $parsed = Read-JsonIfPresent $candidate.FullName
    if ($parsed -and $parsed.compile -and $parsed.save -and $parsed.export) { $writeReport = $parsed; break }
}
if ($writeReport -and $writeReport.compile.success -eq $true -and $writeReport.save.success -eq $true -and $writeReport.export.success -eq $true) { $verified.Add('reversible write loop with compile/save/export evidence') }
else { $notVerified.Add('reversible write loop with compile/save/export evidence') }

$scaffoldFiles = @(Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'scaffold-report.json' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending)
$scaffold = if ($scaffoldFiles) { Read-JsonIfPresent $scaffoldFiles[0].FullName } else { $null }
$dryRunOk = $scaffold -and $scaffold.dryRun -and $scaffold.dryRun.exitCode -eq 0
# A historical scaffold report with compile 0/0 is not enough. The current
# runner must prove that creation, CloseProject, and Disconnect happened in the
# same MCP sequence before its isolated post-readback is accepted.
$applySequence = if ($scaffold -and $scaffold.apply -and $scaffold.apply.report) { $scaffold.apply.report.sequence } else { $null }
$closeInSequence = if ($applySequence -and $applySequence.calls) { @($applySequence.calls | Where-Object { $_.name -eq 'CloseProject' -and $_.success -eq $true }).Count -gt 0 } else { $false }
$disconnectInSequence = if ($applySequence -and $applySequence.calls) { @($applySequence.calls | Where-Object { $_.name -eq 'Disconnect' -and $_.success -eq $true }).Count -gt 0 } else { $false }
$applyOk = $scaffold -and $scaffold.applied -eq $true -and $scaffold.apply -and $scaffold.apply.exitCode -eq 0 -and $scaffold.postApply -and $scaffold.postApply.success -eq $true -and $closeInSequence -and $disconnectInSequence
if ($dryRunOk) { $verified.Add('agent-demo ScaffoldProject dry-run') } else { $notVerified.Add('agent-demo ScaffoldProject dry-run') }
if ($applyOk) { $verified.Add('agent-demo real scaffold/apply') } else { $notVerified.Add('agent-demo real scaffold/apply') }

$tiaProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -like 'Siemens.Automation.Portal*' -and $_.MainWindowTitle
})
# The session guard is authoritative for the current scaffold run: a visible
# TIA start window with no project is allowed, while an unidentified/open
# project remains a blocker.
$visibleTiaAllowed = $scaffold -and $scaffold.sessionGuard -and $scaffold.sessionGuard.allowed -eq $true
if (-not $applyOk -and $tiaProcesses.Count -gt 0 -and -not $visibleTiaAllowed) {
    $blocked.Add('TIA Portal tiene una instancia de usuario abierta; no se sustituye ni se cierra automáticamente')
}

$readiness = Read-JsonIfPresent $ReadinessPath
$runtimeDoc = Join-Path $WorkspaceRoot '70-runs\simulation\runtime-advanced-v20.md'
$runtimeVerified = $readiness -and $readiness.gates -and $readiness.gates.hmiRuntimeAdvancedV20Ready -eq $true
if ((Test-Path -LiteralPath $runtimeDoc -PathType Leaf) -and $runtimeVerified) {
    $verified.Add('HMI Runtime Advanced V20 compatible y probado')
} else {
    $notVerified.Add('HMI Runtime Advanced V20 compatible y probado')
}
if ($readiness -and $readiness.readOnly -eq $true -and $readiness.gates) {
    $verified.Add('preflight determinista de preparación para simulación')
} else {
    $notVerified.Add('preflight determinista de preparación para simulación')
}
if ($readiness -and $readiness.gates -and $readiness.gates.plcsimVirtualAdapterReady -ne $true) {
    $blocked.Add('El adaptador virtual Siemens PLCSIM no está operativo')
}
if ($readiness -and $readiness.gates -and $readiness.gates.hmiRuntimeAdvancedV20Ready -ne $true) {
    $blocked.Add('WinCC Runtime Advanced V20 compatible no está verificado')
}
$notVerified.Add('comportamiento funcional PLC probado en PLCSIM')
$notVerified.Add('PA-1 ejecutada dos veces desde sesión fría en dos harnesses')
$assumptions.Add('La compilación y el smoke MCP no demuestran comportamiento de runtime')

# Computer Use is a separate evidence surface.  It is discovered from explicit
# JSON reports and never inferred from browser inventory, a schema, or a TIA
# process.  The checks below are deliberately structural: a free-form status
# string alone cannot promote an operation to verified.
$computerUseRecords = [System.Collections.Generic.List[object]]::new()
$computerUseMissing = [System.Collections.Generic.List[string]]::new()
$computerUseInvalid = [System.Collections.Generic.List[string]]::new()
foreach ($computerUsePath in $ComputerUseEvidencePaths) {
    if (-not (Test-Path -LiteralPath $computerUsePath -PathType Leaf)) {
        $computerUseMissing.Add($computerUsePath) | Out-Null
        continue
    }
    $computerUseEvidence = Read-JsonIfPresent $computerUsePath
    if ($null -eq $computerUseEvidence) {
        $computerUseInvalid.Add($computerUsePath) | Out-Null
        continue
    }
    $computerUseRecords.Add([pscustomobject]@{
        path = $computerUsePath
        data = $computerUseEvidence
    }) | Out-Null
}

$computerUseNativeWindowPaths = [System.Collections.Generic.List[string]]::new()
$computerUseNativeWindowVerified = $false
$computerUsePlcGuiPaths = [System.Collections.Generic.List[string]]::new()
$computerUsePlcGuiVerified = $false
$computerUseHmiPaths = [System.Collections.Generic.List[string]]::new()
$computerUseHmiVisualVerified = $false
$computerUseHmiCompileBlocked = $false
$computerUseCreateDeletePaths = [System.Collections.Generic.List[string]]::new()
$computerUseCreateDeleteVerified = $false
$computerUsePlcsimPaths = [System.Collections.Generic.List[string]]::new()
$computerUsePlcsimVerified = $false
$computerUseRuntimePaths = [System.Collections.Generic.List[string]]::new()
$computerUseRuntimeBlocked = $false
$computerUseSafetyBoundaryPaths = [System.Collections.Generic.List[string]]::new()
$computerUseSafetyBoundaryViolationPaths = [System.Collections.Generic.List[string]]::new()
$computerUseSafetyBoundaryMissingPaths = [System.Collections.Generic.List[string]]::new()
$computerUseSafetyBoundaryVerified = $false
$computerUseSclCreationUnverified = $false

foreach ($computerUseRecord in $computerUseRecords) {
    $evidence = $computerUseRecord.data
    $path = $computerUseRecord.path
    $isNativeHarness = [bool](
        ([string]$evidence.harness -match '(?i)native') -or
        ([string]$evidence.harness -match '(?i)@oai/sky') -or
        ([string]$evidence.surface -match '(?i)native Computer Use')
    )
    $isV20 = [bool](
        ($evidence.tiaMajorVersion -eq 20) -or
        ([string]$evidence.tiaWindow.app -match '(?i)Portal V20') -or
        ([string]$evidence.app -match '(?i)Portal V20')
    )
    $hasTargetWindow = [bool](
        ($evidence.windowSelection -and
            [string]$evidence.windowSelection -match '(?i)(TIA|Portal|window)' -and
            -not [string]::IsNullOrWhiteSpace([string]$evidence.windowSelection)) -or
        ($evidence.tiaWindow -and
            [string]$evidence.tiaWindow.app -match '(?i)Portal V20' -and
            -not [string]::IsNullOrWhiteSpace([string]$evidence.tiaWindow.titleWhenIdle)) -or
        ([string]$evidence.app -match '(?i)Portal V20' -and
            (-not [string]::IsNullOrWhiteSpace([string]$evidence.titleBefore) -or
             -not [string]::IsNullOrWhiteSpace([string]$evidence.titleAfter)))
    )
    if ($isNativeHarness -and $isV20 -and $hasTargetWindow) {
        $computerUseNativeWindowVerified = $true
        $computerUseNativeWindowPaths.Add($path) | Out-Null
    }

    $boundarySignal = Test-ComputerUseSafetyEvidencePresent $evidence
    $boundaryOk = Test-ComputerUseSafetyBoundary $evidence
    if ($boundarySignal -and $boundaryOk) {
        $computerUseSafetyBoundaryPaths.Add($path) | Out-Null
    } elseif ($boundarySignal) {
        $computerUseSafetyBoundaryViolationPaths.Add($path) | Out-Null
    } elseif ($isV20 -and ($evidence.actions -or $evidence.visualEdit -or $evidence.installedAndObserved)) {
        $computerUseSafetyBoundaryMissingPaths.Add($path) | Out-Null
    }

    $compile = Get-ComputerUseAction $evidence 'compileSoftwareOnlyChanges'
    $compileClean = [bool]($compile -and $null -ne $compile.errors -and $null -ne $compile.warnings -and
        [int]$compile.errors -eq 0 -and [int]$compile.warnings -eq 0)
    $plcGuiComplete = [bool](
        $isNativeHarness -and $isV20 -and $hasTargetWindow -and $boundaryOk -and
        (Test-ComputerUseAction $evidence 'visualEdit') -and
        $compileClean -and
        (Test-ComputerUseAction $evidence 'saveProject') -and
        (Test-ComputerUseAction $evidence 'visualReadback')
    )
    if ($plcGuiComplete) {
        $computerUsePlcGuiVerified = $true
        $computerUsePlcGuiPaths.Add($path) | Out-Null
    }

    $hmiVisualComplete = [bool](
        $isNativeHarness -and $isV20 -and $hasTargetWindow -and $boundaryOk -and
        ($evidence.phase -eq 'computer-use-hmi-visual-edit' -or $evidence.visualEdit) -and
        (
            (
                (Test-ComputerUseAction $evidence 'visualCreateTextObject') -and
                (Test-ComputerUseAction $evidence 'setText') -and
                (Test-ComputerUseAction $evidence 'saveProject') -and
                (Test-ComputerUseAction $evidence 'closeAndReopen') -and
                (Test-ComputerUseAction $evidence 'visualReadback')
            ) -or
            (
                $evidence.visualEdit.status -eq 'verified_on_disposable_clone' -and
                $evidence.visualEdit.saved -eq $true -and
                $evidence.visualEdit.closedAndReopened -eq $true -and
                $evidence.visualEdit.visualReadback -eq $true
            )
        )
    )
    if ($hmiVisualComplete) {
        $computerUseHmiVisualVerified = $true
        $computerUseHmiPaths.Add($path) | Out-Null
    }
    $hmiCompileAction = Get-ComputerUseAction $evidence 'compile'
    if (($hmiCompileAction -and $hmiCompileAction.status -eq 'blocked') -or
        ([string]$evidence.visualEdit.compile -match '(?i)^blocked_')) {
        $computerUseHmiCompileBlocked = $true
        $computerUseHmiPaths.Add($path) | Out-Null
    }
    if ($evidence.visualEdit -and [string]$evidence.visualEdit.status -match '(?i)verified' -and
        [string]$evidence.visualEdit.objectPath -match '(?i)HMI') {
        $computerUseHmiPaths.Add($path) | Out-Null
    }

    $createBlock = Get-ComputerUseAction $evidence 'create_standard_block'
    $createReadback = Get-ComputerUseAction $evidence 'save_close_reopen_readback'
    $deleteBlocks = Get-ComputerUseAction $evidence 'delete_created_blocks'
    $createDeleteComplete = [bool]($isNativeHarness -and $isV20 -and $hasTargetWindow -and $boundaryOk -and
        $createBlock -and $createBlock.result -eq 'verified' -and
        $createReadback -and $createReadback.result -eq 'verified' -and
        $deleteBlocks -and $deleteBlocks.result -eq 'verified')
    if ($createDeleteComplete) {
        $computerUseCreateDeleteVerified = $true
        $computerUseCreateDeletePaths.Add($path) | Out-Null
    }
    foreach ($blockAction in @($evidence.actions | Where-Object { $_.action -eq 'create_standard_block' })) {
        if ($blockAction.name -eq 'CU_ComputerUse_FB_SCL' -and $blockAction.language -eq 'not_verified') {
            $computerUseSclCreationUnverified = $true
        }
    }

    $plcsim = $evidence.installedAndObserved.plcsimAdvanced
    if ($isNativeHarness -and $isV20 -and $hasTargetWindow -and $boundaryOk -and
        $plcsim -and $plcsim.launched -eq $true -and $plcsim.closed -eq $true -and
        $plcsim.activeInstanceObserved -eq $false -and $plcsim.instanceCreated -eq $false -and
        $plcsim.downloadPerformed -eq $false) {
        $computerUsePlcsimVerified = $true
        $computerUsePlcsimPaths.Add($path) | Out-Null
    }

    $runtime = $evidence.installedAndObserved.hmiRuntimeAdvancedV20
    if ($runtime -and $runtime.status -eq 'blocked') {
        $computerUseRuntimeBlocked = $true
        $computerUseRuntimePaths.Add($path) | Out-Null
    } elseif ($evidence.visualEdit -and $evidence.visualEdit.runtime -eq 'not_performed') {
        $computerUseRuntimePaths.Add($path) | Out-Null
    }
}

$computerUseSafetyRelevantCount = $computerUseSafetyBoundaryPaths.Count +
    $computerUseSafetyBoundaryViolationPaths.Count + $computerUseSafetyBoundaryMissingPaths.Count
$computerUseSafetyBoundaryVerified = $computerUseSafetyRelevantCount -gt 0 -and
    $computerUseMissing.Count -eq 0 -and $computerUseInvalid.Count -eq 0 -and
    $computerUseSafetyBoundaryViolationPaths.Count -eq 0 -and
    $computerUseSafetyBoundaryMissingPaths.Count -eq 0

if ($computerUseNativeWindowVerified) {
    Add-UniqueFinding $verified 'Computer Use nativo y ventana TIA V20 identificados'
} else {
    Add-UniqueFinding $notVerified 'Computer Use nativo y ventana TIA V20 identificados'
}
if ($computerUsePlcGuiVerified) {
    Add-UniqueFinding $verified 'Computer Use: edición PLC, compilación 0/0, guardado y readback en clon'
} else {
    Add-UniqueFinding $notVerified 'Computer Use: edición PLC, compilación 0/0, guardado y readback en clon'
}
if ($computerUseHmiVisualVerified) {
    Add-UniqueFinding $verified 'Computer Use: edición visual HMI y readback en clon'
} else {
    Add-UniqueFinding $notVerified 'Computer Use: edición visual HMI y readback en clon'
}
if ($computerUseCreateDeleteVerified) {
    Add-UniqueFinding $verified 'Computer Use: creación y borrado de bloques estándar en clon'
} else {
    Add-UniqueFinding $notVerified 'Computer Use: creación y borrado de bloques estándar en clon'
}
if ($computerUsePlcsimVerified) {
    Add-UniqueFinding $verified 'Computer Use: disponibilidad de PLCSIM Advanced observada'
} else {
    Add-UniqueFinding $notVerified 'Computer Use: disponibilidad de PLCSIM Advanced observada'
}
if ($computerUseSafetyBoundaryVerified) {
    Add-UniqueFinding $verified 'Computer Use: límites de seguridad respetados en la evidencia'
} else {
    Add-UniqueFinding $notVerified 'Computer Use: límites de seguridad respetados en la evidencia'
}
if ($computerUseSafetyBoundaryViolationPaths.Count -gt 0) {
    Add-UniqueFinding $blocked 'Computer Use evidence violates the physical/Safety/original-project boundary'
}
if ($computerUseSafetyBoundaryMissingPaths.Count -gt 0) {
    Add-UniqueFinding $notVerified 'Computer Use: falta una declaración explícita de límites de seguridad'
}
if ($computerUseHmiCompileBlocked) {
    Add-UniqueFinding $blocked 'Computer Use: compilación HMI bloqueada por dispositivo no soportado'
}
if ($computerUseRuntimeBlocked) {
    Add-UniqueFinding $blocked 'Computer Use: Runtime Advanced V20 no disponible/verificado'
} else {
    Add-UniqueFinding $notVerified 'Computer Use: ejecución de runtime HMI'
}
if ($computerUseSclCreationUnverified) {
    Add-UniqueFinding $notVerified 'Computer Use: lenguaje SCL del FB creado por GUI'
}
if ($computerUseMissing.Count -gt 0) {
    Add-UniqueFinding $notVerified ('Computer Use: faltan evidencias (' + $computerUseMissing.Count + ')')
}
if ($computerUseInvalid.Count -gt 0) {
    Add-UniqueFinding $notVerified ('Computer Use: hay evidencias JSON inválidas (' + $computerUseInvalid.Count + ')')
}

$computerUseAcceptanceReady = [bool]($computerUseNativeWindowVerified -and $computerUsePlcGuiVerified -and
    $computerUseHmiVisualVerified -and $computerUseCreateDeleteVerified -and
    $computerUsePlcsimVerified -and $computerUseSafetyBoundaryVerified -and
    $computerUseSafetyBoundaryViolationPaths.Count -eq 0 -and
    $computerUseSafetyBoundaryMissingPaths.Count -eq 0 -and
    -not $computerUseHmiCompileBlocked -and -not $computerUseRuntimeBlocked -and
    -not $computerUseSclCreationUnverified -and $computerUseMissing.Count -eq 0 -and
    $computerUseInvalid.Count -eq 0)

$computerUse = [ordered]@{
    status = if ($computerUseRecords.Count -eq 0) { 'not_verified' } elseif ($computerUseAcceptanceReady) { 'verified' } else { 'verified_partial' }
    acceptanceReady = $computerUseAcceptanceReady
    nativeWindowInventory = [ordered]@{
        status = if ($computerUseNativeWindowVerified) { 'verified' } else { 'not_verified' }
        evidence = @($computerUseNativeWindowPaths)
    }
    plcGuiEdit = [ordered]@{
        status = if ($computerUsePlcGuiVerified) { 'verified' } else { 'not_verified' }
        evidence = @($computerUsePlcGuiPaths)
    }
    hmiGuiInspection = [ordered]@{
        status = if ($computerUseHmiVisualVerified) { 'verified' } else { 'not_verified' }
        compile = if ($computerUseHmiCompileBlocked) { 'blocked_device_unsupported' } else { 'not_verified' }
        evidence = @($computerUseHmiPaths | Select-Object -Unique)
    }
    createDelete = [ordered]@{
        status = if ($computerUseCreateDeleteVerified) { 'verified' } else { 'not_verified' }
        evidence = @($computerUseCreateDeletePaths)
    }
    plcsimUiInspection = [ordered]@{
        status = if ($computerUsePlcsimVerified) { 'verified_availability_only' } else { 'not_verified' }
        behavior = 'not_verified'
        evidence = @($computerUsePlcsimPaths)
    }
    runtimeUiInspection = [ordered]@{
        status = if ($computerUseRuntimeBlocked) { 'blocked' } else { 'not_verified' }
        evidence = @($computerUseRuntimePaths | Select-Object -Unique)
    }
    safetyBoundary = [ordered]@{
        status = if ($computerUseSafetyBoundaryViolationPaths.Count -gt 0) { 'blocked' } elseif ($computerUseSafetyBoundaryVerified) { 'verified' } else { 'not_verified' }
        evidence = @($computerUseSafetyBoundaryPaths | Select-Object -Unique)
        violations = @($computerUseSafetyBoundaryViolationPaths | Select-Object -Unique)
        missingDeclaration = @($computerUseSafetyBoundaryMissingPaths | Select-Object -Unique)
    }
    physicalDownload = if ($computerUseSafetyBoundaryViolationPaths.Count -gt 0) { 'violation' } else { 'not_performed' }
    evidence = @($ComputerUseEvidencePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    missingEvidence = @($computerUseMissing)
    invalidEvidence = @($computerUseInvalid)
}

# The tag lifecycle report is an independent fixture result.  Use the newest
# report as the authoritative candidate and fail closed if that report is
# malformed or misses any required proof.  An older valid report must not mask
# a newer failed or incomplete run.
$tagLifecycleFinding = 'MCP tag lifecycle: create/update/export/compile/save/delete + independent readback'
$tagLifecycleFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'mcp-tag-lifecycle-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
)
$tagLifecyclePath = if ($tagLifecycleFiles.Count -gt 0) { $tagLifecycleFiles[0].FullName } else { $null }
$tagLifecycleInvalidEvidence = [System.Collections.Generic.List[string]]::new()
$tagLifecycleFailureReasons = [System.Collections.Generic.List[string]]::new()
$tagLifecycleEvidence = if ($tagLifecyclePath) { Read-JsonIfPresent $tagLifecyclePath } else { $null }
$tagLifecycleVerified = $false

if (-not $tagLifecyclePath) {
    $tagLifecycleFailureReasons.Add('No mcp-tag-lifecycle evidence file was found.') | Out-Null
} elseif ($null -eq $tagLifecycleEvidence) {
    $tagLifecycleInvalidEvidence.Add($tagLifecyclePath) | Out-Null
    $tagLifecycleFailureReasons.Add('The newest mcp-tag-lifecycle evidence is not valid JSON.') | Out-Null
} else {
    if ($tagLifecycleEvidence.success -ne $true) {
        $tagLifecycleFailureReasons.Add('success must be true.') | Out-Null
    }
    if ($tagLifecycleEvidence.verdict -ne 'VERIFIED_TAG_CREATE_UPDATE_EXPORT_COMPILE_SAVE_DELETE_AND_INDEPENDENT_READBACK') {
        $tagLifecycleFailureReasons.Add('verdict does not match the required tag lifecycle verdict.') | Out-Null
    }
    if ($null -eq $tagLifecycleEvidence.independentReadback -or $tagLifecycleEvidence.independentReadback.success -ne $true) {
        $tagLifecycleFailureReasons.Add('independentReadback.success must be true.') | Out-Null
    }
    if ($null -eq $tagLifecycleEvidence.independentReadback -or $tagLifecycleEvidence.independentReadback.remainingTagCount -ne 0) {
        $tagLifecycleFailureReasons.Add('independentReadback.remainingTagCount must be 0.') | Out-Null
    }

    $tagLifecycleOperations = @($tagLifecycleEvidence.operations)
    foreach ($operationName in @('CompileSoftware', 'SaveProject')) {
        $matchingOperations = @($tagLifecycleOperations | Where-Object { $_.name -eq $operationName })
        if ($matchingOperations.Count -ne 1) {
            $tagLifecycleFailureReasons.Add("$operationName must have exactly one operation summary.") | Out-Null
            continue
        }
        $operation = $matchingOperations[0]
        if ($null -eq $operation.count -or $null -eq $operation.success -or $null -eq $operation.failures -or
            [int]$operation.count -le 0 -or [int]$operation.success -ne [int]$operation.count -or
            [int]$operation.failures -ne 0) {
            $tagLifecycleFailureReasons.Add("$operationName must report all calls successful and zero failures.") | Out-Null
        }
    }
    if ($null -eq $tagLifecycleEvidence.exports -or $tagLifecycleEvidence.exports.semanticEqualIgnoringCreated -ne $true) {
        $tagLifecycleFailureReasons.Add('exports.semanticEqualIgnoringCreated must be true.') | Out-Null
    }
    if ($null -eq $tagLifecycleEvidence.project -or $tagLifecycleEvidence.project.sourceProjectUntouched -ne $true) {
        $tagLifecycleFailureReasons.Add('project.sourceProjectUntouched must be true.') | Out-Null
    }
    $tagLifecycleVerified = $tagLifecycleFailureReasons.Count -eq 0
}

if ($tagLifecycleVerified) {
    Add-UniqueFinding $verified $tagLifecycleFinding
} else {
    Add-UniqueFinding $notVerified 'MCP tag lifecycle evidence'
}

$tagLifecycle = [ordered]@{
    status = if ($tagLifecycleVerified) { 'verified' } elseif ($tagLifecycleInvalidEvidence.Count -gt 0) { 'invalid' } else { 'not_verified' }
    finding = $tagLifecycleFinding
    path = $tagLifecyclePath
    verdict = if ($tagLifecycleEvidence) { $tagLifecycleEvidence.verdict } else { $null }
    failureReasons = @($tagLifecycleFailureReasons)
    invalidEvidence = @($tagLifecycleInvalidEvidence)
}

$result = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    accepted = ($applyOk -and (($tiaProcesses.Count -eq 0) -or $visibleTiaAllowed) -and $notVerified.Count -eq 0 -and $blocked.Count -eq 0)
    verified = @($verified)
    notVerified = @($notVerified)
    blocked = @($blocked)
    assumptions = @($assumptions)
    computerUse = $computerUse
    checks = if ($checks) {
        [ordered]@{
            success = $checks.success
            summary = $checks.summary
            generatedAt = $checks.generatedAt
        }
    } else { $null }
    evidence = [ordered]@{
        checks = $ChecksPath
        environment = $EnvironmentPath
        simulationReadiness = if (Test-Path -LiteralPath $ReadinessPath -PathType Leaf) { $ReadinessPath } else { $null }
        scaffold = if ($scaffoldFiles) { $scaffoldFiles[0].FullName } else { $null }
        portableValidation = if ($PortableValidationPath) { [IO.Path]::GetFullPath($PortableValidationPath) } else { $null }
        portableCoreManifest = $PortableCoreManifestPath
        computerUse = @($ComputerUseEvidencePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
        tagLifecycle = $tagLifecycle
    }
    tagLifecycle = $tagLifecycle
}
$json = $result | ConvertTo-Json -Depth 10
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output $json
