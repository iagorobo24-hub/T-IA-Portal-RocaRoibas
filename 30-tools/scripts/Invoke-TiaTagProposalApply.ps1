<##
.SYNOPSIS
    Valida y, opcionalmente, aplica una propuesta de tag PLC a un fixture TIA V20 aislado.

.DESCRIPTION
    Por defecto solo valida la propuesta y deja un informe PREVIEW, sin abrir TIA. Con -Apply
    ejecuta el ciclo de ADR-019 sobre una copia desechable:
    fixture -> inventario completo -> tabla exacta -> tag exacto -> backup de la tabla ->
    mutacion unica -> readback -> compilacion 0/0 -> guardado -> export -> verificacion post-guardado.

    La ruta es siempre la aislada (tia-inspect --isolated --fixture-root --allow-write); no se
    usa la ruta adjunta porque no hay evidencia live de CreateTag/UpdateTag sobre el proyecto
    abierto. No descarga a ningun PLC, no cambia el modo online de una CPU y no toca hardware.

    Un cambio minimo nunca usa ImportPlcTagTable: la mutacion es exactamente una llamada a
    CreateTag, UpdateTag o DeleteTag sobre un unico tag de una unica tabla.

    -McpExecutablePath/-McpArguments existen solo para arneses de prueba: el informe queda marcado
    con testInjection=true y no es evidencia live.
##>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProposalPath,

    [Parameter(Mandatory = $true)]
    [string]$ProjectFile,

    [string]$FixtureRoot,
    [string]$ReportRoot,
    [ValidateSet('read', 'write')]
    [string]$Profile = 'read',
    # Inyeccion restringida a pruebas: solo valida con -Apply y deja testInjection=true.
    [string]$McpExecutablePath,
    [string]$McpArguments,
    [switch]$Apply,
    [switch]$AcknowledgeWriteProfile,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $PSScriptRoot 'TiaSclSafety.ps1')

if ($Help) {
    Write-Output @'
Invoke-TiaTagProposalApply.ps1: valida y aplica propuestas de tags PLC con gates fail-closed.
Sin -Apply: preview local, sin TIA. Con -Apply: requiere -Profile write, -AcknowledgeWriteProfile
y -FixtureRoot apuntando a una copia desechable con .tia-agent-fixture.json valido.

Operaciones: create | update | delete sobre un unico tag de una unica tabla. Nunca usa
ImportPlcTagTable para un cambio minimo. Exige inventario GetTags completo y sin tags Safety,
tabla exacta por GetTagTableInfo, tag exacto por GetTagInfo (o ausencia probada en create),
backup ExportTagTable, una sola mutacion, readback exacto, compile 0/0, guardado y export.

Estados: PREVIEW, BLOCKED, APPLIED_AND_VERIFIED, APPLIED_CONTENT_MISMATCH (mutado sin guardar),
APPLIED_EXPORT_FAILED (guardado sin export), APPLIED_VERIFICATION_FAILED (guardado pero el
readback post-guardado no coincide) y FAILED (mutado, compile roto, sin guardar).
No descarga hardware ni cambia el modo online de la CPU.
'@
    exit 0
}

$ProposalPath = [IO.Path]::GetFullPath($ProposalPath)
$ProjectFile = [IO.Path]::GetFullPath($ProjectFile)
$testInjection = [bool]($McpExecutablePath -or $McpArguments)
if (-not $ReportRoot) { $ReportRoot = Join-Path $root '70-runs\e2e\tag-apply' }
$ReportRoot = [IO.Path]::GetFullPath($ReportRoot)
$null = New-Item -ItemType Directory -Path $ReportRoot -Force
$runDirectory = Join-Path $ReportRoot ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N'))
$reportPath = Join-Path $runDirectory 'tag-apply-report.json'
New-Item -ItemType Directory -Path $runDirectory -ErrorAction Stop | Out-Null

$report = [ordered]@{
    schemaVersion = 1
    startedAt = [DateTimeOffset]::Now.ToString('o')
    status = if ($Apply) { 'RUNNING' } else { 'PREVIEW' }
    profile = $Profile
    writeProfileAcknowledged = [bool]$AcknowledgeWriteProfile
    testInjection = $testInjection
    applied = $false
    readOnly = $true
    tiaMutation = $false
    proposalPath = $ProposalPath
    projectFile = $ProjectFile
    fixture = [ordered]@{ success = $false; snapshotVerified = $false }
    mcp = [ordered]@{ server = 'tia-inspect'; profile = 'write'; isolated = $false; writeEnabled = $false }
    backup = [ordered]@{ attempted = $false; success = $false }
    localValidation = [ordered]@{ success = $false }
    sessionGuard = [ordered]@{ success = $false; visiblePids = @() }
    preflight = [ordered]@{ success = $false }
    inventory = [ordered]@{ success = $false }
    table = [ordered]@{ success = $false }
    tagBefore = [ordered]@{ success = $false }
    backupExport = [ordered]@{ attempted = $false; success = $false }
    mutation = [ordered]@{ attempted = $false; success = $false }
    readback = [ordered]@{ attempted = $false; success = $false }
    compile = [ordered]@{ attempted = $false; success = $false; errorCount = $null; warningCount = $null }
    save = [ordered]@{ attempted = $false; success = $false }
    export = [ordered]@{ attempted = $false; success = $false }
    verification = [ordered]@{ success = $false }
    errors = @()
}

function Get-Call([object]$Sequence, [string]$Name) {
    return @($Sequence.calls | Where-Object { [string]$_.name -eq $Name }) | Select-Object -Last 1
}

function Read-CallJson([object]$Call, [string]$Context) {
    if (-not $Call -or $Call.success -ne $true) { throw "$Context did not succeed." }
    try { return ([string]$Call.text | ConvertFrom-Json) } catch { throw "$Context did not return JSON: $([string]$Call.text)" }
}

function Invoke-Sequence {
    param(
        [Parameter(Mandatory = $true)] [array]$Calls,
        [Parameter(Mandatory = $true)] [string]$Name,
        [switch]$AllowFailure
    )

    $sequenceScript = Join-Path $root '30-tools\scripts\Invoke-McpToolSequence.ps1'
    if (-not (Test-Path -LiteralPath $sequenceScript -PathType Leaf)) { throw "Missing MCP sequence runner: $sequenceScript" }
    $exe = if ($McpExecutablePath) { [IO.Path]::GetFullPath($McpExecutablePath) } else { Join-Path $root '30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe' }
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Missing MCP V20 executable: $exe" }
    $serverArguments = if ($McpArguments) { $McpArguments } else { $mcpServerArguments }
    if ([string]::IsNullOrWhiteSpace($serverArguments)) { throw 'Server arguments have not been configured.' }
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }
    $sequencePath = Join-Path $runDirectory ("sequence-$Name.json")
    $callsPath = $sequencePath + '.calls.json'
    [IO.File]::WriteAllText($callsPath, ($Calls | ConvertTo-Json -Depth 30 -Compress), (New-Object Text.UTF8Encoding($false)))
    $output = (& $pwsh -NoProfile -NonInteractive -File $sequenceScript -ExecutablePath $exe -Arguments $serverArguments -CallsJsonPath $callsPath -OutputPath $sequencePath -TimeoutSeconds 900 2>&1 | Out-String).Trim()
    $exitCode = $LASTEXITCODE
    $sequence = if (Test-Path -LiteralPath $sequencePath -PathType Leaf) { Get-Content -Raw -LiteralPath $sequencePath | ConvertFrom-Json } else { $null }
    if (-not $sequence) { throw "$Name MCP sequence produced no report. $output" }
    $sequence | Add-Member -NotePropertyName processExitCode -NotePropertyValue $exitCode -Force
    if ($exitCode -ne 0 -or $sequence.success -ne $true) {
        if (-not $AllowFailure) {
            $failed = @($sequence.calls | Where-Object { $_.success -ne $true -or $_.assertionsPassed -eq $false }) | Select-Object -First 1
            $detail = if ($failed) { "$($failed.name): $([string]$failed.text) $([string]$failed.error) $(@($failed.assertionErrors) -join '; ')" } else { $output }
            throw "$Name MCP sequence failed: $detail"
        }
    }
    return $sequence
}

function Get-TiaDirectoryFingerprint([string]$Directory) {
    $directoryFull = [IO.Path]::GetFullPath($Directory).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $directoryFull -PathType Container)) { throw "Snapshot directory does not exist: $directoryFull" }
    $lines = @(Get-ChildItem -LiteralPath $directoryFull -File -Recurse -Force | Sort-Object { $_.FullName.Substring($directoryFull.Length) } | ForEach-Object {
        $relative = $_.FullName.Substring($directoryFull.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$relative`t$hash"
    })
    $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-ValidatedTiaRelativePath([string]$Path, [string]$Kind) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "Proposal $Kind path is empty." }
    if ([IO.Path]::IsPathRooted($Path) -or $Path -match '^[A-Za-z]:') {
        throw "Proposal $Kind path must be a relative TIA object path, not a rooted filesystem path."
    }
    $normalized = $Path.Replace([char]92, '/')
    $segments = @($normalized.Split([char]'/'))
    if ($segments.Count -eq 0) { throw "Proposal $Kind path is empty." }
    foreach ($segment in $segments) {
        if ([string]::IsNullOrEmpty($segment)) { throw "Proposal $Kind path contains an empty hierarchy segment." }
        if ($segment -in @('.', '..')) { throw "Proposal $Kind path cannot contain dot or parent segments." }
        if ($segment -match '[\x00-\x1F<>:"|?*]' -or $segment.EndsWith('.') -or $segment.EndsWith(' ')) {
            throw "Proposal $Kind path contains an invalid segment: '$segment'."
        }
        if ($segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$') {
            throw "Proposal $Kind path contains a reserved Windows device name: '$segment'."
        }
    }
    return $normalized
}

function Get-ValidatedTagName([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { throw 'Proposal tag name is empty.' }
    if ($Name.Contains('/') -or $Name.Contains('\')) { throw "Proposal tag name '$Name' must not contain a path separator." }
    if ($Name -in @('.', '..')) { throw 'Proposal tag name cannot be a dot segment.' }
    if ($Name -match '[\x00-\x1F<>:"|?*]' -or $Name.EndsWith('.') -or $Name.EndsWith(' ')) {
        throw "Proposal tag name '$Name' contains invalid characters."
    }
    if ($Name -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$') {
        throw "Proposal tag name '$Name' is a reserved Windows device name."
    }
    return $Name
}

function Assert-ContainedPath([string]$Path, [string]$RunRoot) {
    $pathFull = [IO.Path]::GetFullPath($Path)
    $runFull = [IO.Path]::GetFullPath($RunRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $runPrefix = $runFull + [IO.Path]::DirectorySeparatorChar
    if (-not $pathFull.StartsWith($runPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Staging path escapes the run directory: $pathFull"
    }
    return $pathFull
}

function Get-OnlyExportedXml([string]$Directory, [string]$Context) {
    $files = @(Get-ChildItem -LiteralPath $Directory -File -Recurse -Filter '*.xml' -ErrorAction SilentlyContinue)
    if ($files.Count -ne 1) { throw "$Context must contain exactly one exported XML file; found $($files.Count)." }
    return $files[0]
}

function Get-TagProposal {
    param([string]$Path, [string]$ExpectedProjectFile)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Proposal does not exist: $Path" }
    try { $proposal = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json }
    catch { throw "Proposal is not valid JSON: $Path" }

    if ($proposal.schemaVersion -ne 1) { throw 'Proposal schemaVersion must be 1.' }
    if ([string]$proposal.status -ne 'PROPOSED') { throw "Proposal status must be PROPOSED, got '$($proposal.status)'." }
    if ($proposal.readOnly -ne $true -or $proposal.applied -ne $false -or $proposal.tiaMutation -ne $false) {
        throw 'Proposal safety flags are invalid.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$proposal.projectPath)) { throw 'Proposal projectPath is empty.' }
    $proposalProject = [IO.Path]::GetFullPath([string]$proposal.projectPath)
    if (-not [string]::Equals($proposalProject, $ExpectedProjectFile, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Proposal targets '$proposalProject', not '$ExpectedProjectFile'."
    }
    if ($proposal.checks.exactTable -ne $true -or $proposal.checks.exactTag -ne $true) {
        throw 'Proposal must claim exactTable=true and exactTag=true.'
    }

    $operation = [string]$proposal.operation
    if ($operation -notin @('create', 'update', 'delete')) {
        throw "Proposal operation must be create, update or delete; got '$operation'."
    }
    $softwarePath = [string]$proposal.plc
    if ([string]::IsNullOrWhiteSpace($softwarePath)) { throw 'Proposal has no PLC softwarePath.' }
    if ([IO.Path]::IsPathRooted($softwarePath) -or $softwarePath -match '^[A-Za-z]:') {
        throw 'Proposal plc must be a relative TIA software path.'
    }

    $tablePath = Get-ValidatedTiaRelativePath -Path ([string]$proposal.tagTable.path) -Kind 'tag table'
    $tableLeaf = $tablePath.Substring($tablePath.LastIndexOf('/') + 1)
    if ($proposal.tagTable.PSObject.Properties.Name -contains 'name' -and
        -not [string]::IsNullOrWhiteSpace([string]$proposal.tagTable.name) -and
        [string]$proposal.tagTable.name -cne $tableLeaf) {
        throw "Proposal tagTable.name '$($proposal.tagTable.name)' does not match '$tableLeaf'."
    }

    $tagName = Get-ValidatedTagName -Name ([string]$proposal.target.name)
    $tagPath = Get-ValidatedTiaRelativePath -Path ([string]$proposal.target.path) -Kind 'tag'
    $expectedTagPath = $tablePath + '/' + $tagName
    if ($tagPath -cne $expectedTagPath) {
        throw "Proposal target.path '$tagPath' does not match the exact table/tag path '$expectedTagPath'."
    }

    $hasBefore = $null -ne $proposal.target.before
    $hasAfter = $null -ne $proposal.after
    $newName = $null
    switch ($operation) {
        'create' {
            if ($hasBefore) { throw 'create must not declare target.before.' }
            if (-not $hasAfter) { throw 'create requires after.' }
            if ([string]::IsNullOrWhiteSpace([string]$proposal.after.dataTypeName)) { throw 'create after.dataTypeName is required.' }
            if ([string]::IsNullOrWhiteSpace([string]$proposal.after.logicalAddress)) { throw 'create after.logicalAddress is required.' }
            if ($proposal.after.PSObject.Properties.Name -contains 'newName') { throw 'create must not declare after.newName; use target.name.' }
        }
        'update' {
            if (-not $hasBefore) { throw 'update requires target.before.' }
            if (-not $hasAfter) { throw 'update requires after.' }
            if ([string]::IsNullOrWhiteSpace([string]$proposal.target.before.dataTypeName) -or
                [string]::IsNullOrWhiteSpace([string]$proposal.target.before.logicalAddress)) {
                throw 'update target.before must declare dataTypeName and logicalAddress.'
            }
            if ($proposal.after.PSObject.Properties.Name -contains 'newName') {
                $newName = Get-ValidatedTagName -Name ([string]$proposal.after.newName)
            }
            $changed = $false
            foreach ($property in @($proposal.after.PSObject.Properties)) {
                if ($null -eq $property.Value) { continue }
                $beforeProperty = $proposal.target.before.PSObject.Properties[$property.Name]
                if (-not $beforeProperty -or [string]$beforeProperty.Value -ine [string]$property.Value) { $changed = $true }
            }
            if (-not $changed) { throw 'update after does not change any field declared in target.before; a no-op update is not allowed.' }
        }
        'delete' {
            if (-not $hasBefore) { throw 'delete requires target.before.' }
            if ($hasAfter) { throw 'delete must not declare after.' }
            if ([string]::IsNullOrWhiteSpace([string]$proposal.target.before.dataTypeName) -or
                [string]::IsNullOrWhiteSpace([string]$proposal.target.before.logicalAddress)) {
                throw 'delete target.before must declare dataTypeName and logicalAddress.'
            }
        }
    }

    $expectedAfter = [ordered]@{}
    $expectedAfter['name'] = if ($newName) { $newName } else { $tagName }
    $expectedAfter['path'] = $tablePath + '/' + $expectedAfter['name']
    if ($hasAfter) {
        foreach ($property in @($proposal.after.PSObject.Properties)) {
            if ($property.Name -eq 'newName') { continue }
            if ($null -ne $property.Value) { $expectedAfter[$property.Name] = $property.Value }
        }
    }

    return [pscustomobject]@{
        raw = $proposal
        projectPath = $proposalProject
        operation = $operation
        softwarePath = $softwarePath
        tablePath = $tablePath
        tableName = $tableLeaf
        tagName = $tagName
        tagPath = $tagPath
        newName = $newName
        readbackPath = $tablePath + '/' + $expectedAfter['name']
        hasBefore = $hasBefore
        hasAfter = $hasAfter
        before = $proposal.target.before
        after = $proposal.after
        expectedAfter = [pscustomobject]$expectedAfter
    }
}

try {
    if ($Apply -and $Profile -ne 'write') { throw 'Apply requires -Profile write.' }
    if ($Apply -and -not $AcknowledgeWriteProfile) { throw 'Apply requires -AcknowledgeWriteProfile.' }
    if ($testInjection -and -not $Apply) { throw 'Executable/arguments overrides are only permitted with -Apply (test harness injection).' }

    $proposal = Get-TagProposal -Path $ProposalPath -ExpectedProjectFile $ProjectFile
    $mutationTool = switch ($proposal.operation) {
        'create' { 'CreateTag' }
        'update' { 'UpdateTag' }
        'delete' { 'DeleteTag' }
    }
    $report.localValidation = [ordered]@{
        success = $true
        projectMatch = $true
        operation = $proposal.operation
        softwarePath = $proposal.softwarePath
        tablePath = $proposal.tablePath
        tagPath = $proposal.tagPath
        readbackPath = $proposal.readbackPath
        mutationTool = $mutationTool
        exactTableClaim = $true
        exactTagClaim = $true
    }

    if (-not $Apply) {
        $report.status = 'PREVIEW'
        $report.preview = [ordered]@{
            success = $true
            tool = 'local-validation'
            operation = $proposal.operation
            tablePath = $proposal.tablePath
            tagPath = $proposal.tagPath
            mutationTool = $mutationTool
            note = 'No se conecto con TIA; preview local solamente. Los gates live se ejecutan con -Apply.'
        }
        $report.message = 'Local validation passed. No TIA connection or project mutation was attempted.'
    }
    else {
        if ([string]::IsNullOrWhiteSpace($FixtureRoot)) { throw 'Apply requires -FixtureRoot pointing to a disposable fixture run directory.' }
        $FixtureRoot = [IO.Path]::GetFullPath($FixtureRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $fixtureValidator = Join-Path $PSScriptRoot 'Assert-TiaFixtureManifest.ps1'
        if (-not (Test-Path -LiteralPath $fixtureValidator -PathType Leaf)) { throw "Missing fixture manifest validator: $fixtureValidator" }
        $fixture = & $fixtureValidator -FixtureRoot $FixtureRoot
        $fixtureProject = [IO.Path]::GetFullPath([string]$fixture.projectPath)
        if (-not [string]::Equals($fixtureProject, $ProjectFile, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fixture project '$fixtureProject' does not exactly match ProjectFile '$ProjectFile'."
        }
        $report.fixture = [ordered]@{
            success = $true; snapshotVerified = $true; manifestPath = $fixture.manifestPath
            fixtureRoot = $fixture.fixtureRoot; projectPath = $fixtureProject
            backupProjectPath = $fixture.backupProjectPath; sourceProjectPath = $fixture.sourceProjectPath
            projectSnapshotSha256 = $fixture.projectSnapshotSha256; backupSnapshotSha256 = $fixture.backupSnapshotSha256
        }

        $mcpServerArguments = '--tia-major-version 20 --isolated --fixture-root "' + $FixtureRoot + '" --allow-write'
        $report.mcp = [ordered]@{
            server = 'tia-inspect'; profile = 'write'; isolated = $true; writeEnabled = $true
            fixtureRoot = $FixtureRoot; arguments = $mcpServerArguments
        }
        if ($McpExecutablePath) { $report.mcp.executableOverride = [IO.Path]::GetFullPath($McpExecutablePath) }
        if ($testInjection) { $report.mcp.testInjection = $true }

        # La ruta aislada exige que no haya ninguna instancia TIA abierta: nunca se adjunta ni se
        # cierra la instancia del usuario.
        $tiaProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Siemens.Automation.Portal*' })
        $visiblePids = @($tiaProcesses | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object Id)
        $report.sessionGuard.visiblePids = $visiblePids
        if ($tiaProcesses.Count -gt 0) {
            $report.sessionGuard = [ordered]@{
                success = $false; status = 'tia-process-already-running'; visiblePids = $visiblePids
                processIds = @($tiaProcesses.Id)
                message = 'No se aplica mientras haya cualquier proceso TIA Portal: la ruta aislada no se adjunta a una instancia del usuario.'
            }
            throw 'Apply blocked: a TIA Portal process already exists.'
        }
        $report.sessionGuard = [ordered]@{ success = $true; status = 'no-existing-tia-process'; visiblePids = @(); processIds = @() }

        $projectDirectory = Split-Path -Parent $fixtureProject
        $backupDirectory = Join-Path $runDirectory 'backup-project'
        $report.backup.attempted = $true
        Copy-Item -LiteralPath $projectDirectory -Destination $backupDirectory -Recurse -Force
        $backupFile = Join-Path $backupDirectory ([IO.Path]::GetFileName($fixtureProject))
        if (-not (Test-Path -LiteralPath $backupFile -PathType Leaf)) { throw 'Backup did not contain the project file.' }
        $backupSnapshot = Get-TiaDirectoryFingerprint $backupDirectory
        if ($backupSnapshot -ne $fixture.projectSnapshotSha256) { throw 'The fresh pre-write backup differs from the manifest-authorized project snapshot.' }
        $report.backup = [ordered]@{
            attempted = $true; success = $true; path = $backupDirectory; projectFile = $backupFile
            projectHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backupFile).Hash
            projectSnapshotSha256 = $fixture.projectSnapshotSha256; copiedSnapshotSha256 = $backupSnapshot
        }

        $expectedProjectName = [IO.Path]::GetFileNameWithoutExtension($ProjectFile)
        $requiredTools = @('Connect', 'OpenProject', 'GetState', 'GetTags', 'GetTagTables', 'GetTagTableInfo',
            'GetTagInfo', 'ExportTagTable', 'CompileSoftware', 'SaveProject', $mutationTool)
        $preflightSequence = Invoke-Sequence -Calls @(
            @{ name = 'Doctor' },
            @{ name = 'tools/list'; method = 'tools/list' },
            @{ name = 'Connect' },
            @{ name = 'OpenProject'; args = @{ path = $ProjectFile } },
            @{ name = 'GetState' }
        ) -Name 'preflight'
        $rosterCall = Get-Call $preflightSequence 'tools/list'
        if (-not $rosterCall -or $rosterCall.success -ne $true) {
            throw 'The active MCP profile did not provide a successful tools/list response; tag capability is unknown.'
        }
        Assert-TiaTagApplyCapability -ToolListPayload $rosterCall.response -RequiredTools $requiredTools
        $report.preflight.capability = [ordered]@{ success = $true; requiredTools = $requiredTools }
        $state = Read-CallJson (Get-Call $preflightSequence 'GetState') 'GetState'
        if ([string]$state.session -and [string]$state.session -ne '-') {
            throw 'A Multiuser session is open, but this runner has no verified SaveSession path.'
        }
        if ([string]$state.project -ine $expectedProjectName) {
            throw "OpenProject reports project '$($state.project)', expected '$expectedProjectName'."
        }
        $report.preflight = [ordered]@{ success = $true; state = $state; expectedProjectName = $expectedProjectName }

        $gateSequence = Invoke-Sequence -Calls @(
            @{ name = 'Connect' },
            @{ name = 'OpenProject'; args = @{ path = $ProjectFile } },
            @{ name = 'GetTags'; args = @{ softwarePath = $proposal.softwarePath; tagTablePath = ''; regexName = '' } },
            @{ name = 'GetTagTables'; args = @{ softwarePath = $proposal.softwarePath; regexName = '' } },
            @{ name = 'GetTagTableInfo'; args = @{ softwarePath = $proposal.softwarePath; tagTablePath = $proposal.tablePath } }
        ) -Name 'tag-gates'
        $tagsPayload = Read-CallJson (Get-Call $gateSequence 'GetTags') 'GetTags'
        Assert-TiaSclTagInventoryWritable -TagPayload $tagsPayload
        $report.inventory = [ordered]@{ success = $true; count = @($tagsPayload.items).Count; safetyTagCount = 0; mode = 'whole-plc-fail-closed' }
        $tablesPayload = Read-CallJson (Get-Call $gateSequence 'GetTagTables') 'GetTagTables'
        Assert-TiaTagTableInventoryReadable -TablePayload $tablesPayload
        $tableInfo = Read-CallJson (Get-Call $gateSequence 'GetTagTableInfo') 'GetTagTableInfo'
        Assert-TiaTagTableInfoMatches -TableInfo $tableInfo -ExpectedPath $proposal.tablePath
        $listedTables = @($tablesPayload.items | Where-Object { [string]$_.path -ceq $proposal.tablePath })
        if ($listedTables.Count -gt 1) { throw "GetTagTables returned duplicate entries for '$($proposal.tablePath)'." }
        $report.table = [ordered]@{
            success = $true; path = [string]$tableInfo.path; name = [string]$tableInfo.name
            isDefault = [bool]$tableInfo.isDefault; tagCount = $tableInfo.tagCount
            listedInGetTagTables = ($listedTables.Count -eq 1)
            note = if ($listedTables.Count -eq 0) { 'GetTagTables no enumero la tabla; la puerta exacta es GetTagTableInfo (evidencia 2026-09-23: enumeracion vacia con tabla existente).' } else { $null }
        }

        $probeSequence = Invoke-Sequence -Calls @(
            @{ name = 'Connect' },
            @{ name = 'OpenProject'; args = @{ path = $ProjectFile } },
            @{ name = 'GetTagInfo'; args = @{ softwarePath = $proposal.softwarePath; tagPath = $proposal.tagPath } }
        ) -Name 'tag-probe' -AllowFailure
        $probeCall = Get-Call $probeSequence 'GetTagInfo'
        $inventoryMatches = @($tagsPayload.items | Where-Object { [string]$_.path -ceq $proposal.tagPath })
        if ($proposal.operation -eq 'create') {
            if ($inventoryMatches.Count -gt 0) { throw "Complete GetTags inventory already contains '$($proposal.tagPath)'; create is blocked." }
            if (-not $probeCall) { throw 'GetTagInfo probe did not run; absence of the target tag is not proven.' }
            if ($probeCall.success -eq $true) { throw "Tag '$($proposal.tagPath)' already exists; create is blocked (no overwrite)." }
            $probeText = ([string]$probeCall.text + ' ' + [string]$probeCall.error).Trim()
            if ($probeText -notmatch '(?i)not found|does not exist|no existe|no se encontr') {
                throw "GetTagInfo failed for an unexpected reason; absence is not proven: $probeText"
            }
            $report.tagBefore = [ordered]@{ success = $true; exists = $false; path = $proposal.tagPath; probe = $probeText }
        }
        else {
            if ($inventoryMatches.Count -ne 1) {
                throw "Complete GetTags inventory must contain exactly one '$($proposal.tagPath)'; found $($inventoryMatches.Count)."
            }
            if (-not $probeCall -or $probeCall.success -ne $true) {
                $detail = if ($probeCall) { ([string]$probeCall.text + ' ' + [string]$probeCall.error).Trim() } else { 'GetTagInfo was not reached.' }
                throw "GetTagInfo could not read the target tag '$($proposal.tagPath)': $detail"
            }
            $tagInfo = Read-CallJson $probeCall 'GetTagInfo'
            if ([string]$tagInfo.path -cne $proposal.tagPath) { throw "Live tag path '$($tagInfo.path)' differs from '$($proposal.tagPath)'." }
            if ([string]$tagInfo.name -cne $proposal.tagName) { throw "Live tag name '$($tagInfo.name)' differs from '$($proposal.tagName)'." }
            Assert-TiaTagMatchesExpected -Tag $tagInfo -Expected $proposal.before -Context 'GetTagInfo(target.before)'
            $report.tagBefore = [ordered]@{
                success = $true; exists = $true; path = [string]$tagInfo.path; name = [string]$tagInfo.name
                dataTypeName = [string]$tagInfo.dataTypeName; logicalAddress = [string]$tagInfo.logicalAddress
                isSafety = $tagInfo.isSafety; response = $tagInfo
            }
        }

        $backupTagsDirectory = Assert-ContainedPath -Path (Join-Path $runDirectory 'backup\tags') -RunRoot $runDirectory
        New-Item -ItemType Directory -Path $backupTagsDirectory -Force | Out-Null
        $backupExportSequence = Invoke-Sequence -Calls @(
            @{ name = 'Connect' },
            @{ name = 'OpenProject'; args = @{ path = $ProjectFile } },
            @{ name = 'ExportTagTable'; args = @{ softwarePath = $proposal.softwarePath; tagTablePath = $proposal.tablePath; exportPath = $backupTagsDirectory } }
        ) -Name 'tag-backup-export'
        $backupExportCall = Get-Call $backupExportSequence 'ExportTagTable'
        if (-not $backupExportCall -or $backupExportCall.success -ne $true) { throw 'ExportTagTable backup did not succeed; the mutation is blocked.' }
        $backupXml = Get-OnlyExportedXml -Directory $backupTagsDirectory -Context 'Tag table backup'
        $report.backupExport = [ordered]@{
            attempted = $true; success = $true; path = $backupXml.FullName
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $backupXml.FullName).Hash.ToLowerInvariant()
            response = Read-CallJson $backupExportCall 'ExportTagTable'
        }

        $srcTagsDirectory = Assert-ContainedPath -Path (Join-Path $runDirectory 'src\tags') -RunRoot $runDirectory
        New-Item -ItemType Directory -Path $srcTagsDirectory -Force | Out-Null

        $mutationArgs = [ordered]@{ softwarePath = $proposal.softwarePath }
        if ($proposal.operation -eq 'create') {
            $mutationArgs['tagTablePath'] = $proposal.tablePath
            $mutationArgs['name'] = $proposal.tagName
            $mutationArgs['dataTypeName'] = [string]$proposal.after.dataTypeName
            $mutationArgs['logicalAddress'] = [string]$proposal.after.logicalAddress
        }
        else {
            $mutationArgs['tagPath'] = $proposal.tagPath
            if ($proposal.operation -eq 'update') {
                foreach ($property in @($proposal.after.PSObject.Properties)) {
                    if ($null -eq $property.Value) { continue }
                    $mutationArgs[$property.Name] = $property.Value
                }
            }
        }

        $readbackAssertions = [ordered]@{}
        $readbackCall = $null
        if ($proposal.operation -eq 'delete') {
            $readbackCall = @{
                name = 'GetTags'
                args = @{ softwarePath = $proposal.softwarePath; tagTablePath = $proposal.tablePath; regexName = ('^' + [regex]::Escape($proposal.tagName) + '$') }
                assertJson = [ordered]@{ 'meta.success' = $true; 'meta.totalTags' = 0 }
            }
        }
        else {
            $readbackAssertions['meta.success'] = $true
            foreach ($property in @($proposal.expectedAfter.PSObject.Properties)) {
                if ($null -ne $property.Value) { $readbackAssertions[$property.Name] = $property.Value }
            }
            $readbackCall = @{
                name = 'GetTagInfo'
                args = @{ softwarePath = $proposal.softwarePath; tagPath = $proposal.readbackPath }
                assertJson = $readbackAssertions
            }
        }

        $report.tiaMutation = $true
        $report.readOnly = $false
        $report.mutation = [ordered]@{ attempted = $true; success = $false; tool = $mutationTool; args = $mutationArgs }
        $mutationCalls = @(
            @{ name = 'Connect' },
            @{ name = 'OpenProject'; args = @{ path = $ProjectFile } },
            @{ name = $mutationTool; args = $mutationArgs },
            $readbackCall,
            @{ name = 'CompileSoftware'; args = @{ softwarePath = $proposal.softwarePath; password = '' }; assertJson = [ordered]@{ errorCount = 0; warningCount = 0 } },
            @{ name = 'SaveProject' },
            @{ name = 'ExportTagTable'; args = @{ softwarePath = $proposal.softwarePath; tagTablePath = $proposal.tablePath; exportPath = $srcTagsDirectory } }
        )
        $mutationSequence = Invoke-Sequence -Calls $mutationCalls -Name 'tag-mutation' -AllowFailure
        $mutationCall = Get-Call $mutationSequence $mutationTool
        if (-not $mutationCall -or $mutationCall.success -ne $true) {
            $report.tiaMutation = $false
            $report.readOnly = $true
            $detail = if ($mutationCall) { ([string]$mutationCall.text + ' ' + [string]$mutationCall.error).Trim() } else { 'The mutation call was not reached.' }
            throw "Mutation tool '$mutationTool' did not succeed; no tag change is reported. $detail"
        }
        $report.mutation = [ordered]@{
            attempted = $true; success = $true; tool = $mutationTool; args = $mutationArgs
            response = Read-CallJson $mutationCall $mutationTool
        }

        $readbackName = if ($proposal.operation -eq 'delete') { 'GetTags' } else { 'GetTagInfo' }
        $readbackResult = Get-Call $mutationSequence $readbackName
        if (-not $readbackResult -or $readbackResult.success -ne $true -or $readbackResult.assertionsPassed -eq $false) {
            $detail = if ($readbackResult) { ([string]$readbackResult.text + ' ' + [string]$readbackResult.error + ' ' + (@($readbackResult.assertionErrors) -join '; ')).Trim() } else { 'The readback call was not reached.' }
            $report.readback = [ordered]@{ attempted = $true; success = $false; tool = $readbackName; error = $detail }
            $report.status = 'APPLIED_CONTENT_MISMATCH'
            throw "Readback content gate failed (APPLIED_CONTENT_MISMATCH): $detail"
        }
        $report.readback = [ordered]@{
            attempted = $true; success = $true; tool = $readbackName
            response = Read-CallJson $readbackResult $readbackName
        }

        $compileCall = Get-Call $mutationSequence 'CompileSoftware'
        if (-not $compileCall -or $compileCall.success -ne $true) {
            $report.compile = [ordered]@{ attempted = $true; success = $false; errorCount = $null; warningCount = $null; error = 'CompileSoftware did not run.' }
            $report.status = 'FAILED'
            throw 'CompileSoftware did not run; Save was not attempted.'
        }
        $compilePayload = Read-CallJson $compileCall 'CompileSoftware'
        $report.compile = [ordered]@{
            attempted = $true; success = ($compilePayload.errorCount -eq 0 -and $compilePayload.warningCount -eq 0)
            state = $compilePayload.state; errorCount = [int]$compilePayload.errorCount; warningCount = [int]$compilePayload.warningCount
            messages = @($compilePayload.messages)
        }
        if (-not $report.compile.success -or $compileCall.assertionsPassed -eq $false) {
            $report.status = 'FAILED'
            throw "Compile gate failed: $($report.compile.errorCount) error(s), $($report.compile.warningCount) warning(s). Save was not attempted."
        }

        $saveCall = Get-Call $mutationSequence 'SaveProject'
        if (-not $saveCall -or $saveCall.success -ne $true) {
            $report.status = 'FAILED'
            throw 'SaveProject did not succeed; the mutation was not persisted.'
        }
        $report.save = [ordered]@{ attempted = $true; success = $true; response = Read-CallJson $saveCall 'SaveProject' }

        $exportCall = Get-Call $mutationSequence 'ExportTagTable'
        if (-not $exportCall -or $exportCall.success -ne $true) {
            $report.status = 'APPLIED_EXPORT_FAILED'
            throw 'The tag change was saved, but ExportTagTable failed; the src/tags export is missing.'
        }
        $srcXml = Get-OnlyExportedXml -Directory $srcTagsDirectory -Context 'Saved tag table export'
        $report.export = [ordered]@{
            attempted = $true; success = $true; path = $srcXml.FullName
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $srcXml.FullName).Hash.ToLowerInvariant()
            response = Read-CallJson $exportCall 'ExportTagTable'
        }

        # Verificacion post-guardado: un proceso nuevo abre el .ap20 ya guardado y vuelve a leer.
        # Esto prueba persistencia; el readback anterior solo probaba el estado en memoria.
        if ($proposal.operation -eq 'delete') {
            $verifyCalls = @(
                @{ name = 'Connect' },
                @{ name = 'OpenProject'; args = @{ path = $ProjectFile } },
                @{ name = 'GetTags'; args = @{ softwarePath = $proposal.softwarePath; tagTablePath = $proposal.tablePath; regexName = ('^' + [regex]::Escape($proposal.tagName) + '$') } }
            )
        }
        else {
            $verifyCalls = @(
                @{ name = 'Connect' },
                @{ name = 'OpenProject'; args = @{ path = $ProjectFile } },
                @{ name = 'GetTagInfo'; args = @{ softwarePath = $proposal.softwarePath; tagPath = $proposal.readbackPath } }
            )
        }
        $verifySequence = Invoke-Sequence -Calls $verifyCalls -Name 'tag-verify' -AllowFailure
        if ($proposal.operation -eq 'delete') {
            $verifyCall = Get-Call $verifySequence 'GetTags'
            if (-not $verifyCall -or $verifyCall.success -ne $true) {
                $report.status = 'APPLIED_VERIFICATION_FAILED'
                throw 'Post-save GetTags did not succeed; persistence of the deletion is not proven.'
            }
            $verifyPayload = Read-CallJson $verifyCall 'GetTags'
            if ([int]$verifyPayload.meta.totalTags -ne 0) {
                $report.status = 'APPLIED_VERIFICATION_FAILED'
                throw "Post-save GetTags still reports $($verifyPayload.meta.totalTags) matching tag(s); persistence is not proven."
            }
            $report.verification = [ordered]@{ success = $true; mode = 'absence'; totalTags = 0; response = $verifyPayload }
        }
        else {
            $verifyCall = Get-Call $verifySequence 'GetTagInfo'
            if (-not $verifyCall -or $verifyCall.success -ne $true) {
                $report.status = 'APPLIED_VERIFICATION_FAILED'
                throw 'Post-save GetTagInfo did not succeed; persistence is not proven.'
            }
            $verifiedTag = Read-CallJson $verifyCall 'GetTagInfo'
            try {
                Assert-TiaTagMatchesExpected -Tag $verifiedTag -Expected $proposal.expectedAfter -Context 'post-save GetTagInfo'
            }
            catch {
                $report.status = 'APPLIED_VERIFICATION_FAILED'
                throw
            }
            $report.verification = [ordered]@{ success = $true; mode = 'exact'; response = $verifiedTag }
        }
        $postSaveSnapshot = Get-TiaDirectoryFingerprint $projectDirectory
        if ($postSaveSnapshot -eq $fixture.projectSnapshotSha256) {
            $report.status = 'APPLIED_VERIFICATION_FAILED'
            throw 'The fixture project directory snapshot did not change after SaveProject; persistence is not proven.'
        }
        $report.verification.projectSnapshotSha256 = $postSaveSnapshot

        $report.applied = $true
        $report.status = 'APPLIED_AND_VERIFIED'
        $report.message = 'Tag change applied, read back exactly, compiled 0/0, saved and re-verified after reopening the project.'
    }
}
catch {
    if ($report.status -eq 'RUNNING') {
        $report.status = if ($report.tiaMutation) { 'FAILED' } else { 'BLOCKED' }
    }
    $report.errors = @($report.errors + [string]$_.Exception.Message)
    if ($report.tiaMutation -and -not $report.save.success) {
        $report.postFailureInstruction = 'La mutacion quedo solo en memoria; el proceso aislado cerro el proyecto sin guardar. Verifica el fixture contra el backup (backup-project y backup/tags) antes de reintentar.'
    }
    if ($report.status -eq 'APPLIED_EXPORT_FAILED') {
        $report.postFailureInstruction = 'El cambio se guardo pero falta el export a src/tags. No repitas la mutacion: vuelve a exportar la tabla desde el fixture ya guardado.'
    }
    throw
}
finally {
    $report.completedAt = [DateTimeOffset]::Now.ToString('o')
    $report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "Tag proposal apply report written to $reportPath"
}

if (-not ($report.status -in @('PREVIEW', 'APPLIED_AND_VERIFIED'))) { exit 1 }
exit 0
