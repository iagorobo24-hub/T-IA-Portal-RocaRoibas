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

function Get-ProjectDirectoryInventory([string]$DirectoryPath) {
    if ([string]::IsNullOrWhiteSpace($DirectoryPath) -or
        -not (Test-Path -LiteralPath $DirectoryPath -PathType Container)) { return $null }
    $root = [IO.Path]::GetFullPath($DirectoryPath).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    return @(Get-ChildItem -LiteralPath $root -File -Recurse -Force | ForEach-Object {
        [pscustomobject]@{
            path = $_.FullName.Substring($root.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            length = [long]$_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    } | Sort-Object path)
}

function Compare-ProjectDirectoryInventories([string]$LeftPath, [string]$RightPath) {
    $left = Get-ProjectDirectoryInventory $LeftPath
    $right = Get-ProjectDirectoryInventory $RightPath
    if ($null -eq $left -or $null -eq $right) {
        return [pscustomobject]@{ comparable = $false; leftCount = 0; rightCount = 0; differences = @('missing directory') }
    }
    $leftMap = @{}
    foreach ($entry in $left) { $leftMap[[string]$entry.path] = "$($entry.length)|$($entry.sha256)" }
    $rightMap = @{}
    foreach ($entry in $right) { $rightMap[[string]$entry.path] = "$($entry.length)|$($entry.sha256)" }
    $keys = @(@($leftMap.Keys) + @($rightMap.Keys) | Select-Object -Unique)
    $differences = @($keys | Where-Object {
        -not $leftMap.ContainsKey($_) -or -not $rightMap.ContainsKey($_) -or $leftMap[$_] -cne $rightMap[$_]
    })
    return [pscustomobject]@{ comparable = $true; leftCount = $left.Count; rightCount = $right.Count; differences = $differences }
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

# The watch-table lifecycle report is an independent disposable-fixture result.
# Use the newest report as the authoritative candidate and fail closed if it is
# malformed or misses any part of the offline create/export/compile/save/delete
# and independent-readback contract. A previous valid run must not mask a newer
# failed or incomplete run.
$watchLifecycleFinding = 'MCP watch table lifecycle: create/export/compile/save/delete + independent readback'
$watchLifecycleFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'mcp-watch-acceptance-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
)
$watchLifecyclePath = if ($watchLifecycleFiles.Count -gt 0) { $watchLifecycleFiles[0].FullName } else { $null }
$watchLifecycleInvalidEvidence = [System.Collections.Generic.List[string]]::new()
$watchLifecycleFailureReasons = [System.Collections.Generic.List[string]]::new()
$watchLifecycleEvidence = if ($watchLifecyclePath) { Read-JsonIfPresent $watchLifecyclePath } else { $null }
$watchLifecycleVerified = $false

if (-not $watchLifecyclePath) {
    $watchLifecycleFailureReasons.Add('No mcp-watch-acceptance evidence file was found.') | Out-Null
} elseif ($null -eq $watchLifecycleEvidence) {
    $watchLifecycleInvalidEvidence.Add($watchLifecyclePath) | Out-Null
    $watchLifecycleFailureReasons.Add('The newest mcp-watch-acceptance evidence is not valid JSON.') | Out-Null
} else {
    if ($watchLifecycleEvidence.success -ne $true) {
        $watchLifecycleFailureReasons.Add('success must be true.') | Out-Null
    }
    if ($watchLifecycleEvidence.verdict -ne 'VERIFIED_WATCH_TABLE_CREATE_EXPORT_COMPILE_SAVE_DELETE_AND_INDEPENDENT_READBACK') {
        $watchLifecycleFailureReasons.Add('verdict does not match the required watch-table lifecycle verdict.') | Out-Null
    }

    $fixture = $watchLifecycleEvidence.fixture
    if ($null -eq $fixture -or $fixture.restored -ne $true -or $fixture.sourceUntouched -ne $true) {
        $watchLifecycleFailureReasons.Add('fixture.restored and fixture.sourceUntouched must both be true.') | Out-Null
    }
    if ($null -eq $fixture -or [string]::IsNullOrWhiteSpace([string]$fixture.initialSha256) -or
        $fixture.initialSha256 -ne $fixture.backupSha256 -or
        $fixture.initialSha256 -ne $fixture.projectSha256AfterRestore -or
        $fixture.initialSha256 -ne $fixture.sourceSha256) {
        $watchLifecycleFailureReasons.Add('fixture initial, backup, source, and restored project hashes must match.') | Out-Null
    }

    $preflight = $watchLifecycleEvidence.preflight
    if ($null -eq $preflight -or $preflight.allBlocksStandard -ne $true -or
        $preflight.allTagsNonSafety -ne $true -or $preflight.watchTablesBefore -ne 0 -or
        $preflight.forceTablesUntouched -ne $true) {
        $watchLifecycleFailureReasons.Add('preflight must prove standard blocks, non-Safety tags, no probe table, and untouched force tables.') | Out-Null
    }

    $mutation = $watchLifecycleEvidence.mutation
    if ($null -eq $mutation) {
        $watchLifecycleFailureReasons.Add('mutation evidence is required.') | Out-Null
    } else {
        if ([string]::IsNullOrWhiteSpace([string]$mutation.watchName) -or
            [string]::IsNullOrWhiteSpace([string]$mutation.createdPath) -or
            $mutation.watchName -ne $mutation.createdPath -or
            [string]$mutation.createdKind -notmatch '(?i)^Watch table$' -or
            $mutation.createdReadback -ne 1 -or $mutation.createdConsistent -ne $true -or
            $mutation.createdEntryCount -ne 0) {
            $watchLifecycleFailureReasons.Add('created path/kind/readback must prove one empty consistent Watch table.') | Out-Null
        }
        if ($mutation.exported -ne $true -or [string]::IsNullOrWhiteSpace([string]$mutation.exportPath) -or
            [int]$mutation.exportLength -le 0 -or
            [string]$mutation.exportSha256 -notmatch '(?i)^[0-9a-f]{64}$') {
            $watchLifecycleFailureReasons.Add('the created watch table must have a non-empty exported XML artifact and SHA-256.') | Out-Null
        }
        foreach ($compileName in @('compileBeforeDelete', 'compileAfterDelete')) {
            $compile = $mutation.$compileName
            if ($null -eq $compile -or $compile.state -ne 'Success' -or
                $compile.errors -ne 0 -or $compile.warnings -ne 0) {
                $watchLifecycleFailureReasons.Add("$compileName must report Success with zero errors and warnings.") | Out-Null
            }
        }
        if ($mutation.saveBeforeDeleteSucceeded -ne $true -or $mutation.deleteSucceeded -ne $true -or
            $mutation.afterDeleteCount -ne 0 -or $mutation.saveAfterDeleteSucceeded -ne $true) {
            $watchLifecycleFailureReasons.Add('save/delete/readback cleanup must succeed and leave zero probe tables.') | Out-Null
        }
    }

    $independentReadback = $watchLifecycleEvidence.independentReadback
    if ($null -eq $independentReadback -or $independentReadback.success -ne $true -or
        $independentReadback.watchTableCount -ne 0) {
        $watchLifecycleFailureReasons.Add('independentReadback must succeed with zero watch tables.') | Out-Null
    }
    $watchLifecycleVerified = $watchLifecycleFailureReasons.Count -eq 0
}

if ($watchLifecycleVerified) {
    Add-UniqueFinding $verified $watchLifecycleFinding
} else {
    Add-UniqueFinding $notVerified 'MCP watch table lifecycle evidence'
}

$watchLifecycle = [ordered]@{
    status = if ($watchLifecycleVerified) { 'verified' } elseif ($watchLifecycleInvalidEvidence.Count -gt 0) { 'invalid' } else { 'not_verified' }
    finding = $watchLifecycleFinding
    path = $watchLifecyclePath
    verdict = if ($watchLifecycleEvidence) { $watchLifecycleEvidence.verdict } else { $null }
    failureReasons = @($watchLifecycleFailureReasons)
    invalidEvidence = @($watchLifecycleInvalidEvidence)
}

# The Instance DB lifecycle report is an independent disposable-fixture result.
# It is accepted only when the DB was classified safe, compiled before export,
# saved, deleted, compiled/saved again, and absent in a separate read-only session.
$instanceDbLifecycleFinding = 'MCP Instance DB lifecycle: create/compile/export/save/references/delete + independent readback'
$instanceDbLifecycleFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'mcp-instancedb-acceptance-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
)
$instanceDbLifecyclePath = if ($instanceDbLifecycleFiles.Count -gt 0) { $instanceDbLifecycleFiles[0].FullName } else { $null }
$instanceDbLifecycleInvalidEvidence = [System.Collections.Generic.List[string]]::new()
$instanceDbLifecycleFailureReasons = [System.Collections.Generic.List[string]]::new()
$instanceDbLifecycleEvidence = if ($instanceDbLifecyclePath) { Read-JsonIfPresent $instanceDbLifecyclePath } else { $null }
$instanceDbLifecycleVerified = $false

if (-not $instanceDbLifecyclePath) {
    $instanceDbLifecycleFailureReasons.Add('No mcp-instancedb-acceptance evidence file was found.') | Out-Null
} elseif ($null -eq $instanceDbLifecycleEvidence) {
    $instanceDbLifecycleInvalidEvidence.Add($instanceDbLifecyclePath) | Out-Null
    $instanceDbLifecycleFailureReasons.Add('The newest mcp-instancedb-acceptance evidence is not valid JSON.') | Out-Null
} else {
    if ($instanceDbLifecycleEvidence.success -ne $true -or
        $instanceDbLifecycleEvidence.verdict -ne 'VERIFIED_INSTANCE_DB_CREATE_COMPILE_EXPORT_SAVE_DELETE_AND_INDEPENDENT_READBACK') {
        $instanceDbLifecycleFailureReasons.Add('success and verdict must match the required Instance DB lifecycle.') | Out-Null
    }

    $fixture = $instanceDbLifecycleEvidence.fixture
    if ($null -eq $fixture -or $fixture.restored -ne $true -or $fixture.sourceUntouched -ne $true -or
        [string]::IsNullOrWhiteSpace([string]$fixture.initialSha256) -or
        $fixture.initialSha256 -ne $fixture.backupSha256 -or
        $fixture.initialSha256 -ne $fixture.projectSha256AfterRestore -or
        [string]::IsNullOrWhiteSpace([string]$fixture.source) -or
        [string]::IsNullOrWhiteSpace([string]$fixture.sourceSha256) -or
        -not (Test-Path -LiteralPath ([string]$fixture.source) -PathType Leaf) -or
        (Get-FileHash -LiteralPath ([string]$fixture.source) -Algorithm SHA256).Hash -ne $fixture.sourceSha256 -or
        $fixture.sourceSha256 -ne $fixture.initialSha256) {
        $instanceDbLifecycleFailureReasons.Add('fixture must be restored, source-untouched, and have matching initial/backup/restored/source hashes.') | Out-Null
    }

    $preflight = $instanceDbLifecycleEvidence.preflight
    if ($null -eq $preflight -or $preflight.allBlocksStandard -ne $true -or
        $preflight.allTagsNonSafety -ne $true -or $preflight.sourceFailsafe -ne $false -or
        $preflight.sourceKnowHowProtected -ne $false -or $preflight.destinationAbsentBefore -ne $true -or
        $preflight.instanceDbNumberFree -ne $true -or $preflight.instanceDbNumber -le 0 -or
        @($preflight.occupiedBlockNumbers) -contains $preflight.instanceDbNumber) {
        $instanceDbLifecycleFailureReasons.Add('preflight must prove standard blocks, non-Safety tags, safe source metadata, absent destination, and a free positive DB number.') | Out-Null
    }

    $mutation = $instanceDbLifecycleEvidence.mutation
    if ($null -eq $mutation -or [string]::IsNullOrWhiteSpace([string]$mutation.instanceDbName) -or
        $mutation.createdPath -ne $mutation.instanceDbName -or $mutation.createdType -ne 'InstanceDB' -or
        $mutation.createdLanguage -ne 'DB' -or $mutation.createdFailsafe -ne $false -or
        $mutation.createdKnowHowProtected -ne $false -or $mutation.number -le 0 -or
        $mutation.autoNumber -ne $false -or $mutation.consistentAfterCompile -ne $true -or
        $mutation.exported -ne $true -or [int]$mutation.exportLength -le 0 -or
        [string]$mutation.exportSha256 -notmatch '(?i)^[0-9a-f]{64}$' -or
        $mutation.saveSucceeded -ne $true -or $mutation.deleteSucceeded -ne $true -or
        $mutation.afterDeleteCount -ne 0 -or $mutation.saveAfterDeleteSucceeded -ne $true) {
        $instanceDbLifecycleFailureReasons.Add('mutation must prove explicit-number Instance DB creation, compile consistency, export, save, delete and zero remaining matches.') | Out-Null
    }
    if ($mutation -and $mutation.crossReferenceCount -le 0) {
        $instanceDbLifecycleFailureReasons.Add('crossReferenceCount must be positive for the instance DB to prove its FB dependency.') | Out-Null
    }
    $deleteReport = if ($instanceDbLifecycleEvidence.reports -and $instanceDbLifecycleEvidence.reports.delete) {
        Read-JsonIfPresent ([string]$instanceDbLifecycleEvidence.reports.delete)
    } else { $null }
    $crossReferenceCall = if ($deleteReport) {
        $deleteReport.calls | Where-Object { $_.name -eq 'GetCrossReferences' } | Select-Object -Last 1
    } else { $null }
    $crossReferences = if ($crossReferenceCall) { $crossReferenceCall.response.structuredContent } else { $null }
    $crossReferenceSourceNames = if ($crossReferences) {
        @($crossReferences.sources | ForEach-Object {
            [string]$_.name
            @($_.references | ForEach-Object { [string]$_.name })
        })
    } else { @() }
    if ($null -eq $deleteReport -or $deleteReport.success -ne $true -or $null -eq $crossReferenceCall -or
        $null -eq $crossReferences -or $crossReferences.referenceCount -le 0 -or
        [string]$preflight.sourceBlock -notin $crossReferenceSourceNames) {
        $instanceDbLifecycleFailureReasons.Add('the delete-session report must contain successful cross references to the preflight source FB.') | Out-Null
    }
    if ($mutation -and [string]$mutation.exported -eq 'True') {
        if ([string]::IsNullOrWhiteSpace([string]$mutation.exportPath) -or
            -not (Test-Path -LiteralPath ([string]$mutation.exportPath) -PathType Leaf)) {
            $instanceDbLifecycleFailureReasons.Add('the exported XML path must exist as a file.') | Out-Null
        } else {
            $actualExportHash = (Get-FileHash -LiteralPath ([string]$mutation.exportPath) -Algorithm SHA256).Hash
            if ($actualExportHash -ne [string]$mutation.exportSha256) {
                $instanceDbLifecycleFailureReasons.Add('the exported XML SHA-256 must match the file on disk.') | Out-Null
            }
        }
    }
    foreach ($compileName in @('compileBeforeExport', 'compileAfterDelete')) {
        $compile = if ($mutation) { $mutation.$compileName } else { $null }
        if ($null -eq $compile -or $compile.state -ne 'Success' -or $compile.errors -ne 0 -or $compile.warnings -ne 0) {
            $instanceDbLifecycleFailureReasons.Add("$compileName must report Success with zero errors and warnings.") | Out-Null
        }
    }

    $independentReadback = $instanceDbLifecycleEvidence.independentReadback
    if ($null -eq $independentReadback -or $independentReadback.success -ne $true -or
        $independentReadback.allowWrite -ne $false -or $independentReadback.instanceDbCount -ne 0) {
        $instanceDbLifecycleFailureReasons.Add('independentReadback must be read-only and show zero Instance DB matches.') | Out-Null
    }
    if ($independentReadback -and [string]::IsNullOrWhiteSpace([string]$independentReadback.report)) {
        $instanceDbLifecycleFailureReasons.Add('independentReadback.report is required.') | Out-Null
    } elseif ($independentReadback) {
        $independentReport = Read-JsonIfPresent ([string]$independentReadback.report)
        $stateCall = if ($independentReport) { $independentReport.calls | Where-Object { $_.name -eq 'GetState' } | Select-Object -Last 1 } else { $null }
        $blocksCall = if ($independentReport) { $independentReport.calls | Where-Object { $_.name -eq 'GetBlocks' } | Select-Object -Last 1 } else { $null }
        $independentState = if ($stateCall) { $stateCall.response.structuredContent } else { $null }
        $independentBlocks = if ($blocksCall) { $blocksCall.response.structuredContent.items } else { $null }
        if ($null -eq $independentReport -or $independentReport.success -ne $true -or
            $null -eq $independentState -or $independentState.allowWrite -ne $false -or
            $null -eq $blocksCall -or @($independentBlocks).Count -ne 0) {
            $instanceDbLifecycleFailureReasons.Add('independentReadback.report must be valid, read-only, successful and contain zero probe blocks.') | Out-Null
        }
    }
    $instanceDbLifecycleVerified = $instanceDbLifecycleFailureReasons.Count -eq 0
}

if ($instanceDbLifecycleVerified) {
    Add-UniqueFinding $verified $instanceDbLifecycleFinding
} else {
    Add-UniqueFinding $notVerified 'MCP Instance DB lifecycle evidence'
}

$instanceDbLifecycle = [ordered]@{
    status = if ($instanceDbLifecycleVerified) { 'verified' } elseif ($instanceDbLifecycleInvalidEvidence.Count -gt 0) { 'invalid' } else { 'not_verified' }
    finding = $instanceDbLifecycleFinding
    path = $instanceDbLifecyclePath
    verdict = if ($instanceDbLifecycleEvidence) { $instanceDbLifecycleEvidence.verdict } else { $null }
    failureReasons = @($instanceDbLifecycleFailureReasons)
    invalidEvidence = @($instanceDbLifecycleInvalidEvidence)
}

# The PLC tag-table lifecycle report is another disposable-fixture result. It
# covers an empty user table only; tag values and Safety tags stay out of scope.
$tagTableLifecycleFinding = 'MCP PLC tag table lifecycle: create/export/compile/save/delete + independent readback'
$tagTableLifecycleFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'mcp-tagtable-acceptance-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
)
$tagTableLifecyclePath = if ($tagTableLifecycleFiles.Count -gt 0) { $tagTableLifecycleFiles[0].FullName } else { $null }
$tagTableLifecycleInvalidEvidence = [System.Collections.Generic.List[string]]::new()
$tagTableLifecycleFailureReasons = [System.Collections.Generic.List[string]]::new()
$tagTableLifecycleEvidence = if ($tagTableLifecyclePath) { Read-JsonIfPresent $tagTableLifecyclePath } else { $null }
$tagTableLifecycleVerified = $false

if (-not $tagTableLifecyclePath) {
    $tagTableLifecycleFailureReasons.Add('No mcp-tagtable-acceptance evidence file was found.') | Out-Null
} elseif ($null -eq $tagTableLifecycleEvidence) {
    $tagTableLifecycleInvalidEvidence.Add($tagTableLifecyclePath) | Out-Null
    $tagTableLifecycleFailureReasons.Add('The newest mcp-tagtable-acceptance evidence is not valid JSON.') | Out-Null
} else {
    if ($tagTableLifecycleEvidence.success -ne $true -or
        $tagTableLifecycleEvidence.verdict -ne 'VERIFIED_TAG_TABLE_CREATE_EXPORT_COMPILE_SAVE_DELETE_AND_INDEPENDENT_READBACK') {
        $tagTableLifecycleFailureReasons.Add('success and verdict must match the required tag-table lifecycle.') | Out-Null
    }
    $fixture = $tagTableLifecycleEvidence.fixture
    if ($null -eq $fixture -or $fixture.restored -ne $true -or $fixture.sourceUntouched -ne $true -or
        $fixture.initialSha256 -ne $fixture.backupSha256 -or $fixture.initialSha256 -ne $fixture.projectSha256AfterRestore -or
        [string]::IsNullOrWhiteSpace([string]$fixture.source) -or [string]::IsNullOrWhiteSpace([string]$fixture.sourceSha256) -or
        -not (Test-Path -LiteralPath ([string]$fixture.source) -PathType Leaf) -or
        (Get-FileHash -LiteralPath ([string]$fixture.source) -Algorithm SHA256).Hash -ne $fixture.sourceSha256 -or
        $fixture.sourceSha256 -ne $fixture.initialSha256) {
        $tagTableLifecycleFailureReasons.Add('fixture must be restored, source-untouched, and have matching initial/backup/restored/source hashes.') | Out-Null
    }
    $preflight = $tagTableLifecycleEvidence.preflight
    if ($null -eq $preflight -or $preflight.allBlocksStandard -ne $true -or
        $preflight.allTagsNonSafety -ne $true -or $preflight.destinationAbsentBefore -ne $true -or
        $preflight.forceTablesUntouched -ne $true) {
        $tagTableLifecycleFailureReasons.Add('preflight must prove standard blocks, non-Safety tags, absent destination, and untouched force tables.') | Out-Null
    }
    $mutation = $tagTableLifecycleEvidence.mutation
    if ($null -eq $mutation -or [string]::IsNullOrWhiteSpace([string]$mutation.tagTableName) -or
        $mutation.createdPath -ne $mutation.tagTableName -or $mutation.createdKind -notmatch '(?i)^Tag table$' -or
        $mutation.createdReadback -ne 1 -or $mutation.tagCount -ne 0 -or $mutation.userConstantCount -ne 0 -or
        $mutation.exported -ne $true -or [int]$mutation.exportLength -le 0 -or
        [string]$mutation.exportSha256 -notmatch '(?i)^[0-9a-f]{64}$' -or
        $mutation.saveBeforeDeleteSucceeded -ne $true -or $mutation.deleteSucceeded -ne $true -or
        $mutation.afterDeleteCount -ne 0 -or $mutation.saveAfterDeleteSucceeded -ne $true) {
        $tagTableLifecycleFailureReasons.Add('mutation must prove one empty user table, export, save, delete and zero remaining matches.') | Out-Null
    }
    if ($mutation -and [string]$mutation.exported -eq 'True') {
        if ([string]::IsNullOrWhiteSpace([string]$mutation.exportPath) -or
            -not (Test-Path -LiteralPath ([string]$mutation.exportPath) -PathType Leaf)) {
            $tagTableLifecycleFailureReasons.Add('the exported tag-table XML path must exist as a file.') | Out-Null
        } else {
            $actualExportHash = (Get-FileHash -LiteralPath ([string]$mutation.exportPath) -Algorithm SHA256).Hash
            if ($actualExportHash -ne [string]$mutation.exportSha256) {
                $tagTableLifecycleFailureReasons.Add('the exported tag-table XML SHA-256 must match the file on disk.') | Out-Null
            }
        }
    }
    foreach ($compileName in @('compileBeforeDelete', 'compileAfterDelete')) {
        $compile = if ($mutation) { $mutation.$compileName } else { $null }
        if ($null -eq $compile -or $compile.state -ne 'Success' -or $compile.errors -ne 0 -or $compile.warnings -ne 0) {
            $tagTableLifecycleFailureReasons.Add("$compileName must report Success with zero errors and warnings.") | Out-Null
        }
    }
    $independentReadback = $tagTableLifecycleEvidence.independentReadback
    if ($null -eq $independentReadback -or $independentReadback.success -ne $true -or
        $independentReadback.allowWrite -ne $false -or $independentReadback.tagTableCount -ne 0 -or
        [string]::IsNullOrWhiteSpace([string]$independentReadback.report)) {
        $tagTableLifecycleFailureReasons.Add('independentReadback must be read-only and show zero tag tables.') | Out-Null
    } else {
        $independentReport = Read-JsonIfPresent ([string]$independentReadback.report)
        $stateCall = if ($independentReport) { $independentReport.calls | Where-Object { $_.name -eq 'GetState' } | Select-Object -Last 1 } else { $null }
        $tablesCall = if ($independentReport) { $independentReport.calls | Where-Object { $_.name -eq 'GetTagTables' } | Select-Object -Last 1 } else { $null }
        $independentState = if ($stateCall) { $stateCall.response.structuredContent } else { $null }
        $independentTables = if ($tablesCall) { $tablesCall.response.structuredContent.items } else { $null }
        if ($null -eq $independentReport -or $independentReport.success -ne $true -or
            $null -eq $independentState -or $independentState.allowWrite -ne $false -or
            $null -eq $tablesCall -or @($independentTables).Count -ne 0) {
            $tagTableLifecycleFailureReasons.Add('independentReadback.report must be valid, read-only, successful and contain zero probe tables.') | Out-Null
        }
    }
    $tagTableLifecycleVerified = $tagTableLifecycleFailureReasons.Count -eq 0
}

if ($tagTableLifecycleVerified) {
    Add-UniqueFinding $verified $tagTableLifecycleFinding
} else {
    Add-UniqueFinding $notVerified 'MCP PLC tag table lifecycle evidence'
}

$tagTableLifecycle = [ordered]@{
    status = if ($tagTableLifecycleVerified) { 'verified' } elseif ($tagTableLifecycleInvalidEvidence.Count -gt 0) { 'invalid' } else { 'not_verified' }
    finding = $tagTableLifecycleFinding
    path = $tagTableLifecyclePath
    verdict = if ($tagTableLifecycleEvidence) { $tagTableLifecycleEvidence.verdict } else { $null }
    failureReasons = @($tagTableLifecycleFailureReasons)
    invalidEvidence = @($tagTableLifecycleInvalidEvidence)
}

# ImportPlcTagTable is exposed by tia-create/full rather than the default
# tia-inspect/write profile.  Keep its acceptance separate from the create /
# delete lifecycle above: the tool has no dryRun and TIA V20 persists index
# state in System/PEData.* alongside the .ap20, so the fixture must be restored
# as a complete directory and read back in a read-only session.
$tagTableImportLifecycleFinding = 'MCP PLC tag table import: import/compile/save + independent readback and directory restore'
$tagTableImportLifecycleFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'mcp-import-tagtable-acceptance-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
)
$tagTableImportLifecyclePath = if ($tagTableImportLifecycleFiles.Count -gt 0) { $tagTableImportLifecycleFiles[0].FullName } else { $null }
$tagTableImportLifecycleInvalidEvidence = [System.Collections.Generic.List[string]]::new()
$tagTableImportLifecycleFailureReasons = [System.Collections.Generic.List[string]]::new()
$tagTableImportLifecycleEvidence = if ($tagTableImportLifecyclePath) { Read-JsonIfPresent $tagTableImportLifecyclePath } else { $null }
$tagTableImportLifecycleVerified = $false

if (-not $tagTableImportLifecyclePath) {
    $tagTableImportLifecycleFailureReasons.Add('No mcp-import-tagtable-acceptance evidence file was found.') | Out-Null
} elseif ($null -eq $tagTableImportLifecycleEvidence) {
    $tagTableImportLifecycleInvalidEvidence.Add($tagTableImportLifecyclePath) | Out-Null
    $tagTableImportLifecycleFailureReasons.Add('The newest mcp-import-tagtable-acceptance evidence is not valid JSON.') | Out-Null
} else {
    if ($tagTableImportLifecycleEvidence.success -ne $true -or
        $tagTableImportLifecycleEvidence.verdict -ne 'VERIFIED_PLC_TAG_TABLE_IMPORT_COMPILE_SAVE_INDEPENDENT_READBACK_AND_DIRECTORY_RESTORE') {
        $tagTableImportLifecycleFailureReasons.Add('success and verdict must match the required PLC tag-table import lifecycle.') | Out-Null
    }
    $fixture = $tagTableImportLifecycleEvidence.fixture
    $fixtureHashesMatch = $fixture -and
        $fixture.initialSha256 -eq $fixture.backupSha256 -and
        $fixture.initialSha256 -eq $fixture.projectSha256AfterRestore -and
        $fixture.initialSha256 -eq $fixture.sourceSha256
    if ($null -eq $fixture -or $fixture.restored -ne $true -or $fixture.sourceUntouched -ne $true -or
        $fixture.directoryRestored -ne $true -or $fixture.directoryFileDiffCountAfterRestore -ne 0 -or
        -not $fixtureHashesMatch -or
        [string]::IsNullOrWhiteSpace([string]$fixture.source) -or
        -not (Test-Path -LiteralPath ([string]$fixture.source) -PathType Leaf) -or
        (Get-FileHash -LiteralPath ([string]$fixture.source) -Algorithm SHA256).Hash -ne [string]$fixture.sourceSha256) {
        $tagTableImportLifecycleFailureReasons.Add('fixture must restore the complete project directory, preserve the source, and match all baseline hashes.') | Out-Null
    } else {
        $projectPath = [string]$fixture.project
        $backupPath = [string]$fixture.backup
        $projectDirectory = if (Test-Path -LiteralPath $projectPath -PathType Leaf) { Split-Path -Parent $projectPath } else { $null }
        $backupDirectory = if (Test-Path -LiteralPath $backupPath -PathType Leaf) { Split-Path -Parent $backupPath } else { $null }
        $directoryComparison = Compare-ProjectDirectoryInventories $projectDirectory $backupDirectory
        if (-not $directoryComparison.comparable -or $directoryComparison.differences.Count -ne 0 -or
            $directoryComparison.leftCount -ne $fixture.directoryFileCount -or
            $directoryComparison.rightCount -ne $fixture.directoryFileCount) {
            $tagTableImportLifecycleFailureReasons.Add('the restored project directory must match its backup on disk by file path, size and SHA-256, including TIA sidecars.') | Out-Null
        }
    }
    $preflight = $tagTableImportLifecycleEvidence.preflight
    if ($null -eq $preflight -or $preflight.allBlocksStandard -ne $true -or
        $preflight.allBlocksNonFailsafe -ne $true -or $preflight.allBlocksUnprotected -ne $true -or
        $preflight.allTagsNonSafety -ne $true -or $preflight.destinationAbsentBefore -ne $true -or
        $preflight.importToolHasDryRun -ne $false -or
        [string]::IsNullOrWhiteSpace([string]$preflight.report)) {
        $tagTableImportLifecycleFailureReasons.Add('preflight must prove standard unprotected non-Safety content, an absent destination, and the no-dryRun import guard.') | Out-Null
    } else {
        $preflightReport = Read-JsonIfPresent ([string]$preflight.report)
        $preflightBlocksCall = if ($preflightReport) { $preflightReport.calls | Where-Object { $_.name -eq 'GetBlocks' } | Select-Object -Last 1 } else { $null }
        $preflightTagsCall = if ($preflightReport) { $preflightReport.calls | Where-Object { $_.name -eq 'GetTags' } | Select-Object -Last 1 } else { $null }
        $preflightTablesCall = if ($preflightReport) { $preflightReport.calls | Where-Object { $_.name -eq 'GetTagTables' } | Select-Object -Last 1 } else { $null }
        $preflightBlocks = if ($preflightBlocksCall) { $preflightBlocksCall.response.structuredContent.items } else { $null }
        $preflightTags = if ($preflightTagsCall) { $preflightTagsCall.response.structuredContent.items } else { $null }
        $preflightTables = if ($preflightTablesCall) { $preflightTablesCall.response.structuredContent.items } else { $null }
        $probeName = [string]$tagTableImportLifecycleEvidence.mutation.tableName
        if ($null -eq $preflightReport -or $preflightReport.success -ne $true -or
            $null -eq $preflightBlocksCall -or $preflightBlocksCall.success -ne $true -or
            @($preflightBlocks | Where-Object { $_.isFailsafe -ne $false -or $_.isKnowHowProtected -ne $false -or [string]::IsNullOrWhiteSpace([string]$_.programmingLanguage) }).Count -gt 0 -or
            $null -eq $preflightTagsCall -or $preflightTagsCall.success -ne $true -or
            @($preflightTags | Where-Object { $_.isSafety -ne $false }).Count -gt 0 -or
            $null -eq $preflightTablesCall -or $preflightTablesCall.success -ne $true -or
            @($preflightTables | Where-Object { $_.path -eq $probeName }).Count -ne 0) {
            $tagTableImportLifecycleFailureReasons.Add('preflight.report must be successful and independently confirm non-Safety blocks/tags and an absent destination table.') | Out-Null
        }
    }
    $mutation = $tagTableImportLifecycleEvidence.mutation
    if ($null -eq $mutation -or $mutation.tool -ne 'ImportPlcTagTable' -or
        [string]::IsNullOrWhiteSpace([string]$mutation.tableName) -or $mutation.importSucceeded -ne $true -or
        $mutation.beforeTagTableCount -ne 2 -or $mutation.afterImportTagTableCount -eq $mutation.beforeTagTableCount -or
        $mutation.afterSaveTagTableCount -ne $mutation.afterImportTagTableCount -or $mutation.createdReadback -ne $true -or
        $mutation.createdKind -notmatch '(?i)^Tag table$' -or $mutation.tagCount -ne 0 -or
        $mutation.userConstantCount -ne 0 -or $mutation.compile.state -ne 'Success' -or
        $mutation.compile.errors -ne 0 -or $mutation.compile.warnings -ne 0 -or
        $mutation.saveSucceeded -ne $true -or $mutation.noPhysicalHardwareTouched -ne $true -or
        $mutation.noSafetyBlocksOrTagsTouched -ne $true -or [string]::IsNullOrWhiteSpace([string]$mutation.report)) {
        $tagTableImportLifecycleFailureReasons.Add('mutation must prove one imported table, compile 0/0, save, and the safety/hardware boundaries.') | Out-Null
    } else {
        $mutationReport = Read-JsonIfPresent ([string]$mutation.report)
        $importCall = if ($mutationReport) { $mutationReport.calls | Where-Object { $_.name -eq 'ImportPlcTagTable' } | Select-Object -Last 1 } else { $null }
        $compileCall = if ($mutationReport) { $mutationReport.calls | Where-Object { $_.name -eq 'CompileSoftware' } | Select-Object -Last 1 } else { $null }
        $saveCall = if ($mutationReport) { $mutationReport.calls | Where-Object { $_.name -eq 'SaveProject' } | Select-Object -Last 1 } else { $null }
        $compileData = if ($compileCall) { $compileCall.text | ConvertFrom-Json -ErrorAction SilentlyContinue } else { $null }
        $importData = if ($importCall) { $importCall.text | ConvertFrom-Json -ErrorAction SilentlyContinue } else { $null }
        $tableCalls = if ($mutationReport) { @($mutationReport.calls | Where-Object { $_.name -eq 'GetPlcTagTables' }) } else { @() }
        $beforeTables = if ($tableCalls.Count -ge 1) { ($tableCalls[0].text | ConvertFrom-Json -ErrorAction SilentlyContinue).items } else { $null }
        $afterImportTables = if ($tableCalls.Count -ge 2) { ($tableCalls[1].text | ConvertFrom-Json -ErrorAction SilentlyContinue).items } else { $null }
        $afterSaveTables = if ($tableCalls.Count -ge 3) { ($tableCalls[2].text | ConvertFrom-Json -ErrorAction SilentlyContinue).items } else { $null }
        $inputXmlPath = [string]$mutation.importPath
        $xmlValid = $false
        if (-not [string]::IsNullOrWhiteSpace($inputXmlPath) -and (Test-Path -LiteralPath $inputXmlPath -PathType Leaf)) {
            try {
                [xml]$importXml = Get-Content -LiteralPath $inputXmlPath -Raw
                $xmlTables = @($importXml.Document.'SW.Tags.PlcTagTable')
                $xmlTableName = [string]$xmlTables[0].AttributeList.Name
                $xmlValid = $xmlTables.Count -eq 1 -and $xmlTableName -ceq [string]$mutation.tableName -and
                    $importXml.Document.Engineering.version -eq 'V20' -and
                    $null -eq $xmlTables[0].SelectSingleNode('.//SW.Tags.PlcTag') -and
                    $null -eq $xmlTables[0].SelectSingleNode('.//SW.Tags.PlcUserConstant')
            } catch { $xmlValid = $false }
        }
        if ($null -eq $mutationReport -or $mutationReport.success -ne $true -or
            $null -eq $importCall -or $importCall.success -ne $true -or
            $null -eq $importData -or $importData.meta.success -ne $true -or
            -not $xmlValid -or
            $null -eq $compileCall -or $compileCall.success -ne $true -or
            $null -eq $compileData -or $compileData.state -ne 'Success' -or $compileData.errorCount -ne 0 -or $compileData.warningCount -ne 0 -or
            $null -eq $saveCall -or $saveCall.success -ne $true -or
            $tableCalls.Count -lt 3 -or @($beforeTables).Count -ne $mutation.beforeTagTableCount -or
            @($afterImportTables | Where-Object { $_ -ceq [string]$mutation.tableName }).Count -ne 1 -or
            @($afterSaveTables | Where-Object { $_ -ceq [string]$mutation.tableName }).Count -ne 1) {
            $tagTableImportLifecycleFailureReasons.Add('mutation.report must prove the exact V20 empty-table XML import, table readback before/after save, CompileSoftware 0/0, and SaveProject.') | Out-Null
        }
    }
    $independentReadback = $tagTableImportLifecycleEvidence.independentReadback
    if ($null -eq $independentReadback -or $independentReadback.success -ne $true -or
        $independentReadback.allowWrite -ne $false -or $independentReadback.probeTableCount -ne 1 -or
        [string]::IsNullOrWhiteSpace([string]$independentReadback.report) -or
        $null -eq $independentReadback.restored -or $independentReadback.restored.success -ne $true -or
        $independentReadback.restored.allowWrite -ne $false -or $independentReadback.restored.probeTableCount -ne 0 -or
        $independentReadback.restored.tableAbsentAfterFullDirectoryRestore -ne $true -or
        [string]::IsNullOrWhiteSpace([string]$independentReadback.restored.report)) {
        $tagTableImportLifecycleFailureReasons.Add('independentReadback must prove read-only visibility after import and absence after complete directory restoration.') | Out-Null
    } else {
        $independentReport = Read-JsonIfPresent ([string]$independentReadback.report)
        $restoredReport = Read-JsonIfPresent ([string]$independentReadback.restored.report)
        $independentStateCall = if ($independentReport) { $independentReport.calls | Where-Object { $_.name -eq 'GetState' } | Select-Object -Last 1 } else { $null }
        $independentTablesCall = if ($independentReport) { $independentReport.calls | Where-Object { $_.name -eq 'GetTagTables' } | Select-Object -Last 1 } else { $null }
        $restoredStateCall = if ($restoredReport) { $restoredReport.calls | Where-Object { $_.name -eq 'GetState' } | Select-Object -Last 1 } else { $null }
        $restoredTablesCall = if ($restoredReport) { $restoredReport.calls | Where-Object { $_.name -eq 'GetTagTables' } | Select-Object -Last 1 } else { $null }
        $independentState = if ($independentStateCall) { $independentStateCall.response.structuredContent } else { $null }
        $independentTables = if ($independentTablesCall) { $independentTablesCall.response.structuredContent.items } else { $null }
        $restoredState = if ($restoredStateCall) { $restoredStateCall.response.structuredContent } else { $null }
        $restoredTables = if ($restoredTablesCall) { $restoredTablesCall.response.structuredContent.items } else { $null }
        $probeName = [string]$tagTableImportLifecycleEvidence.mutation.tableName
        $importedTable = @($independentTables | Where-Object { $_.path -eq $probeName }) | Select-Object -First 1
        if ($null -eq $independentReport -or $independentReport.success -ne $true -or
            $null -eq $independentState -or $independentState.allowWrite -ne $false -or
            $null -eq $independentTablesCall -or @($importedTable).Count -ne 1 -or
            $importedTable.isDefault -ne $false -or $importedTable.tagCount -ne 0 -or $importedTable.userConstantCount -ne 0 -or
            $null -eq $restoredReport -or $restoredReport.success -ne $true -or
            $null -eq $restoredState -or $restoredState.allowWrite -ne $false -or
            $null -eq $restoredTablesCall -or @($restoredTables | Where-Object { $_.path -eq $probeName }).Count -ne 0) {
            $tagTableImportLifecycleFailureReasons.Add('independent and restored reports must be valid read-only sessions with the expected table presence/absence.') | Out-Null
        }
    }
    $tagTableImportLifecycleVerified = $tagTableImportLifecycleFailureReasons.Count -eq 0
}

if ($tagTableImportLifecycleVerified) {
    Add-UniqueFinding $verified $tagTableImportLifecycleFinding
} else {
    Add-UniqueFinding $notVerified 'MCP PLC tag table import lifecycle evidence'
}

$tagTableImportLifecycle = [ordered]@{
    status = if ($tagTableImportLifecycleVerified) { 'verified' } elseif ($tagTableImportLifecycleInvalidEvidence.Count -gt 0) { 'invalid' } else { 'not_verified' }
    finding = $tagTableImportLifecycleFinding
    path = $tagTableImportLifecyclePath
    verdict = if ($tagTableImportLifecycleEvidence) { $tagTableImportLifecycleEvidence.verdict } else { $null }
    failureReasons = @($tagTableImportLifecycleFailureReasons)
    invalidEvidence = @($tagTableImportLifecycleInvalidEvidence)
}

$blockGroupLifecycleFinding = 'MCP block-group lifecycle: create/delete/compile/save + independent readback'
$blockGroupLifecycleFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'mcp-blockgroup-acceptance-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
)
$blockGroupLifecyclePath = if ($blockGroupLifecycleFiles.Count -gt 0) { $blockGroupLifecycleFiles[0].FullName } else { $null }
$blockGroupLifecycleInvalidEvidence = [System.Collections.Generic.List[string]]::new()
$blockGroupLifecycleFailureReasons = [System.Collections.Generic.List[string]]::new()
$blockGroupLifecycleEvidence = if ($blockGroupLifecyclePath) { Read-JsonIfPresent $blockGroupLifecyclePath } else { $null }
$blockGroupLifecycleVerified = $false

if (-not $blockGroupLifecyclePath) {
    $blockGroupLifecycleFailureReasons.Add('No mcp-blockgroup-acceptance evidence file was found.') | Out-Null
} elseif ($null -eq $blockGroupLifecycleEvidence) {
    $blockGroupLifecycleInvalidEvidence.Add($blockGroupLifecyclePath) | Out-Null
    $blockGroupLifecycleFailureReasons.Add('The newest mcp-blockgroup-acceptance evidence is not valid JSON.') | Out-Null
} else {
    if ($blockGroupLifecycleEvidence.success -ne $true -or
        $blockGroupLifecycleEvidence.verdict -ne 'VERIFIED_BLOCK_GROUP_CREATE_DELETE_COMPILE_SAVE_AND_INDEPENDENT_READBACK') {
        $blockGroupLifecycleFailureReasons.Add('success and verdict must match the required block-group lifecycle.') | Out-Null
    }
    $fixture = $blockGroupLifecycleEvidence.fixture
    if ($null -eq $fixture -or $fixture.restored -ne $true -or $fixture.sourceUntouched -ne $true -or
        $fixture.initialSha256 -ne $fixture.backupSha256 -or $fixture.initialSha256 -ne $fixture.projectSha256AfterRestore -or
        [string]::IsNullOrWhiteSpace([string]$fixture.source) -or [string]::IsNullOrWhiteSpace([string]$fixture.sourceSha256) -or
        -not (Test-Path -LiteralPath ([string]$fixture.source) -PathType Leaf) -or
        (Get-FileHash -LiteralPath ([string]$fixture.source) -Algorithm SHA256).Hash -ne $fixture.sourceSha256 -or
        $fixture.sourceSha256 -ne $fixture.initialSha256) {
        $blockGroupLifecycleFailureReasons.Add('fixture must be restored, source-untouched, and have matching hashes.') | Out-Null
    }
    $preflight = $blockGroupLifecycleEvidence.preflight
    $mutation = $blockGroupLifecycleEvidence.mutation
    if ($null -eq $preflight -or $preflight.allBlocksStandard -ne $true -or $preflight.allTagsNonSafety -ne $true -or
        $preflight.destinationAbsentBefore -ne $true -or $preflight.forceTablesUntouched -ne $true -or
        $null -eq $mutation -or $mutation.createdPath -ne $mutation.groupName -or
        $mutation.createdKind -notmatch '(?i)^Block group$' -or $mutation.treeAfterCreateContains -ne $true -or
        $mutation.deleteSucceeded -ne $true -or $mutation.treeAfterDeleteAbsent -ne $true -or
        $mutation.compile.state -ne 'Success' -or $mutation.compile.errors -ne 0 -or $mutation.compile.warnings -ne 0 -or
        $mutation.saveSucceeded -ne $true) {
        $blockGroupLifecycleFailureReasons.Add('mutation must prove an empty group was created, visible, deleted, compiled 0/0 and saved.') | Out-Null
    }
    $independentReadback = $blockGroupLifecycleEvidence.independentReadback
    if ($null -eq $independentReadback -or $independentReadback.success -ne $true -or
        $independentReadback.allowWrite -ne $false -or $independentReadback.treeAbsent -ne $true -or
        $independentReadback.blockMatches -ne 0 -or [string]::IsNullOrWhiteSpace([string]$independentReadback.report)) {
        $blockGroupLifecycleFailureReasons.Add('independentReadback must be read-only and show an absent group/zero probe matches.') | Out-Null
    } else {
        $independentReport = Read-JsonIfPresent ([string]$independentReadback.report)
        if ($null -eq $independentReport -or $independentReport.success -ne $true) {
            $blockGroupLifecycleFailureReasons.Add('independentReadback.report must be valid and successful.') | Out-Null
        }
    }
    $blockGroupLifecycleVerified = $blockGroupLifecycleFailureReasons.Count -eq 0
}

if ($blockGroupLifecycleVerified) {
    Add-UniqueFinding $verified $blockGroupLifecycleFinding
} else {
    Add-UniqueFinding $notVerified 'MCP block-group lifecycle evidence'
}

$blockGroupLifecycle = [ordered]@{
    status = if ($blockGroupLifecycleVerified) { 'verified' } elseif ($blockGroupLifecycleInvalidEvidence.Count -gt 0) { 'invalid' } else { 'not_verified' }
    finding = $blockGroupLifecycleFinding
    path = $blockGroupLifecyclePath
    verdict = if ($blockGroupLifecycleEvidence) { $blockGroupLifecycleEvidence.verdict } else { $null }
    failureReasons = @($blockGroupLifecycleFailureReasons)
    invalidEvidence = @($blockGroupLifecycleInvalidEvidence)
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
        watchLifecycle = $watchLifecycle
        instanceDbLifecycle = $instanceDbLifecycle
        tagTableLifecycle = $tagTableLifecycle
        tagTableImportLifecycle = $tagTableImportLifecycle
        blockGroupLifecycle = $blockGroupLifecycle
    }
    tagLifecycle = $tagLifecycle
    watchLifecycle = $watchLifecycle
    instanceDbLifecycle = $instanceDbLifecycle
    tagTableLifecycle = $tagTableLifecycle
    tagTableImportLifecycle = $tagTableImportLifecycle
    blockGroupLifecycle = $blockGroupLifecycle
}
$json = $result | ConvertTo-Json -Depth 10
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output $json
