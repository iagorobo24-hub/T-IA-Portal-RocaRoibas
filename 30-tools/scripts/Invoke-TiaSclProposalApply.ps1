<##
.SYNOPSIS
    Valida y, opcionalmente, aplica una propuesta SCL a un proyecto TIA V20.

.DESCRIPTION
    Por defecto solo valida y deja un informe PREVIEW. Con -Apply ejecuta el ciclo completo:
    backup -> guardia de instancia -> Connect/Open -> lectura de rutas y bloque -> preview local
    -> comprobacion tools/list -> importacion acotada -> CompileSoftware -> SaveProject -> export y lectura posterior.
    Si el perfil no registra el importador requerido, se bloquea antes de la mutacion.

    La herramienta solo acepta propuestas PROPOSED producidas por New-TiaSclProposal. No descarga
    a ningun PLC, no cambia el modo de una CPU y no permite aplicar a un proyecto distinto del que
    genero la propuesta.
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
    [switch]$Apply,
    [switch]$AcknowledgeWriteProfile,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $PSScriptRoot 'TiaSclSafety.ps1')

if ($Help) {
    Write-Output @'
Invoke-TiaSclProposalApply.ps1: valida y aplica propuestas SCL con gates de seguridad.
Sin -Apply: preview local, sin TIA. Con -Apply: requiere -Profile write y -AcknowledgeWriteProfile;
fixture manifest, aislado, backup, lectura, preview, tools/list, importador registrado,
compile limpio, save, export y readback. Si no existe el importador, informa BLOCKED sin mutar.
Nunca descarga hardware.
'@
    exit 0
}

$ProposalPath = [IO.Path]::GetFullPath($ProposalPath)
$ProjectFile = [IO.Path]::GetFullPath($ProjectFile)
$mcpArguments = $null
if (-not $ReportRoot) { $ReportRoot = Join-Path $root '70-runs\e2e\proposal-apply' }
$ReportRoot = [IO.Path]::GetFullPath($ReportRoot)
$null = New-Item -ItemType Directory -Path $ReportRoot -Force
$runDirectory = Join-Path $ReportRoot ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N'))
$reportPath = Join-Path $runDirectory 'apply-report.json'
New-Item -ItemType Directory -Path $runDirectory -ErrorAction Stop | Out-Null

$report = [ordered]@{
    schemaVersion = 1
    startedAt = [DateTimeOffset]::Now.ToString('o')
    status = if ($Apply) { 'RUNNING' } else { 'PREVIEW' }
    profile = $Profile
    writeProfileAcknowledged = [bool]$AcknowledgeWriteProfile
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
    preview = [ordered]@{ success = $false }
    import = [ordered]@{ attempted = $false; success = $false; capabilityChecked = $false; capabilityAvailable = $false; requiredTool = $null }
    compile = [ordered]@{ attempted = $false; success = $false; errorCount = $null; warningCount = $null }
    save = [ordered]@{ attempted = $false; success = $false }
    export = [ordered]@{ attempted = $false; success = $false }
    verification = [ordered]@{ success = $false }
    cleanup = [ordered]@{ attempted = $false; success = $false }
    errors = @()
}

function Get-Call([object]$Sequence, [string]$Name) {
    return @($Sequence.calls | Where-Object { [string]$_.name -eq $Name }) | Select-Object -Last 1
}

function Read-CallJson([object]$Call, [string]$Context) {
    if (-not $Call -or $Call.success -ne $true) { throw "$Context did not succeed." }
    try { return ([string]$Call.text | ConvertFrom-Json) } catch { throw "$Context did not return JSON: $([string]$Call.text)" }
}

function Invoke-Sequence([array]$Calls, [string]$Name) {
    $sequenceScript = Join-Path $root '30-tools\scripts\Invoke-McpToolSequence.ps1'
    $exe = Join-Path $root '30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe'
    $sequencePath = Join-Path $runDirectory ("sequence-$Name.json")
    if (-not (Test-Path -LiteralPath $sequenceScript -PathType Leaf)) { throw "Missing MCP sequence runner: $sequenceScript" }
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Missing tia-inspect V20 executable: $exe" }
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }
    # El JSON va por FICHERO: pasado por la linea de comandos de un proceso nativo,
    # Windows PowerShell 5.1 elimina las comillas dobles y el MCP recibe un JSON corrupto.
    $callsPath = $sequencePath + '.calls.json'
    [IO.File]::WriteAllText($callsPath, ($Calls | ConvertTo-Json -Depth 30 -Compress), (New-Object Text.UTF8Encoding($false)))
    if ([string]::IsNullOrWhiteSpace($mcpArguments)) { throw 'Isolated write server arguments have not been configured from a validated fixture manifest.' }
    $output = (& $pwsh -NoProfile -NonInteractive -File $sequenceScript -ExecutablePath $exe -Arguments $mcpArguments -CallsJsonPath $callsPath -OutputPath $sequencePath -TimeoutSeconds 900 2>&1 | Out-String).Trim()
    $exitCode = $LASTEXITCODE
    $sequence = if (Test-Path -LiteralPath $sequencePath -PathType Leaf) { Get-Content -Raw -LiteralPath $sequencePath | ConvertFrom-Json } else { $null }
    if (-not $sequence) { throw "$Name MCP sequence produced no report. $output" }
    $sequence | Add-Member -NotePropertyName processExitCode -NotePropertyValue $exitCode -Force
    if ($exitCode -ne 0 -or $sequence.success -ne $true) {
        $failed = @($sequence.calls | Where-Object { $_.success -ne $true }) | Select-Object -First 1
        $detail = if ($failed) { "$($failed.name): $([string]$failed.text)" } else { $output }
        throw "$Name MCP sequence failed: $detail"
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

function Get-TiaFixtureContext([string]$RootPath, [string]$ExpectedProjectFile) {
    if ([string]::IsNullOrWhiteSpace($RootPath)) { throw 'Apply requires -FixtureRoot pointing to a disposable fixture run directory.' }
    $rootFull = [IO.Path]::GetFullPath($RootPath).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) { throw "FixtureRoot does not exist: $rootFull" }
    $manifestPath = Join-Path $rootFull '.tia-agent-fixture.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "FixtureRoot has no .tia-agent-fixture.json manifest: $rootFull" }
    try { $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json }
    catch { throw "Fixture manifest is not valid JSON: $manifestPath" }
    if ($manifest.schemaVersion -ne 1 -or $manifest.disposable -ne $true) { throw 'Fixture manifest must use schemaVersion 1 and disposable=true.' }

    foreach ($field in @('projectPath', 'backupProjectPath', 'sourceProjectPath')) {
        if ([string]::IsNullOrWhiteSpace([string]$manifest.$field) -or -not [IO.Path]::IsPathRooted([string]$manifest.$field)) {
            throw "Fixture manifest field '$field' must contain an absolute path."
        }
    }
    $manifestProject = [IO.Path]::GetFullPath([string]$manifest.projectPath)
    $backupProject = [IO.Path]::GetFullPath([string]$manifest.backupProjectPath)
    $sourceProject = [IO.Path]::GetFullPath([string]$manifest.sourceProjectPath)
    $expectedProject = [IO.Path]::GetFullPath($ExpectedProjectFile)
    if (-not [string]::Equals($manifestProject, $expectedProject, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Fixture manifest projectPath '$manifestProject' does not exactly match ProjectFile '$expectedProject'."
    }
    if ([IO.Path]::GetExtension($manifestProject) -ine '.ap20' -or [IO.Path]::GetExtension($backupProject) -ine '.ap20') {
        throw 'Fixture and backup manifest paths must point to V20 .ap20 project files.'
    }
    if (-not (Test-Path -LiteralPath $manifestProject -PathType Leaf)) { throw "Manifest project file does not exist: $manifestProject" }
    if (-not (Test-Path -LiteralPath $backupProject -PathType Leaf)) { throw "Manifest backup project file does not exist: $backupProject" }
    if (-not (Test-Path -LiteralPath $sourceProject -PathType Leaf)) { throw "Manifest source project file does not exist: $sourceProject" }

    $rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    foreach ($path in @($manifestProject, $backupProject)) {
        if (-not $path.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fixture project and backup must remain below FixtureRoot: $path"
        }
    }
    if ($sourceProject.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The source project must remain outside FixtureRoot.'
    }
    if ([string]::Equals($manifestProject, $backupProject, [StringComparison]::OrdinalIgnoreCase) -or
        [string]::Equals($manifestProject, $sourceProject, [StringComparison]::OrdinalIgnoreCase) -or
        [string]::Equals($backupProject, $sourceProject, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Fixture, backup, and source project paths must be distinct.'
    }
    $projectDirectory = Split-Path -Parent $manifestProject
    $backupDirectory = Split-Path -Parent $backupProject
    if ([string]::Equals($projectDirectory, $backupDirectory, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Fixture project and its backup must be in separate directories.'
    }

    $expectedSnapshot = [string]$manifest.projectSnapshotSha256
    if ($expectedSnapshot -notmatch '^[a-fA-F0-9]{64}$') { throw 'Fixture manifest projectSnapshotSha256 is missing or malformed.' }
    $projectSnapshot = Get-TiaDirectoryFingerprint $projectDirectory
    $backupSnapshot = Get-TiaDirectoryFingerprint $backupDirectory
    if ($projectSnapshot -ne $expectedSnapshot.ToLowerInvariant()) {
        throw "Fixture project directory snapshot differs from its manifest (expected $expectedSnapshot, got $projectSnapshot)."
    }
    if ($backupSnapshot -ne $expectedSnapshot.ToLowerInvariant()) {
        throw "Fixture backup directory snapshot differs from its manifest (expected $expectedSnapshot, got $backupSnapshot)."
    }
    return [pscustomobject]@{
        root = $rootFull; manifestPath = $manifestPath; projectPath = $manifestProject; backupProjectPath = $backupProject
        sourceProjectPath = $sourceProject; projectSnapshotSha256 = $projectSnapshot; backupSnapshotSha256 = $backupSnapshot
        projectDirectory = $projectDirectory; backupDirectory = $backupDirectory
    }
}

function Get-ExactBlock([object]$BlocksPayload, [string]$Name, [string]$ExpectedPath) {
    $items = @($BlocksPayload.items | Where-Object { [string]$_.name -ieq $Name })
    if ($items.Count -ne 1) { throw "Expected exactly one existing block '$Name'; found $($items.Count)." }
    if ($ExpectedPath -and [string]$items[0].path -ne $ExpectedPath) { throw "Existing block path '$($items[0].path)' differs from proposal path '$ExpectedPath'." }
    if ([bool]$items[0].isKnowHowProtected) { throw "Block '$Name' is know-how protected." }
    if ($items[0].PSObject.Properties.Name -contains 'isConsistent' -and -not [bool]$items[0].isConsistent) { throw "Block '$Name' is inconsistent." }
    return $items[0]
}

function Get-ValidatedBlockPath([string]$BlockPath, [string]$BlockName) {
    if ([string]::IsNullOrWhiteSpace($BlockPath)) { throw 'Proposal block path is empty.' }
    if ([IO.Path]::IsPathRooted($BlockPath) -or $BlockPath -match '^[A-Za-z]:') {
        throw 'Proposal block path must be a relative TIA object path, not a rooted filesystem path.'
    }

    # TIA object paths use hierarchy separators, not filesystem paths. Normalize both accepted
    # separator styles before validating each segment; never let Join-Path interpret '..'.
    $normalizedPath = $BlockPath.Replace([char]92, '/')
    $segments = @($normalizedPath.Split([char]'/'))
    if ($segments.Count -eq 0 -or @($segments | Where-Object { [string]::IsNullOrEmpty($_) }).Count -gt 0) {
        throw 'Proposal block path contains an empty hierarchy segment.'
    }
    foreach ($segment in $segments) {
        if ($segment -in @('.', '..')) { throw 'Proposal block path cannot contain dot or parent segments.' }
        if ($segment -match '[<>:"/\\|?*\x00-\x1F]' -or $segment.EndsWith('.') -or $segment.EndsWith(' ')) {
            throw "Proposal block path contains an invalid filesystem staging segment: '$segment'."
        }
        if ($segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$') {
            throw "Proposal block path contains a reserved Windows device name: '$segment'."
        }
    }
    if ($segments[$segments.Count - 1] -cne $BlockName) { throw 'Proposal block name and path disagree.' }

    $groupSegments = if ($segments.Count -gt 1) { @($segments[0..($segments.Count - 2)]) } else { @() }
    return [pscustomobject]@{
        normalizedPath = $normalizedPath
        groupPath = ($groupSegments -join '/')
        groupSegments = $groupSegments
    }
}

function Assert-TiaStagingPathContained([string]$Path, [string]$AllowedRoot, [string]$RunRoot) {
    $pathFull = [IO.Path]::GetFullPath($Path)
    $rootFull = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $pathFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Staging path escapes its allowed root: $pathFull"
    }
    $runFull = [IO.Path]::GetFullPath($RunRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $runPrefix = $runFull + [IO.Path]::DirectorySeparatorChar
    if (-not [string]::Equals($rootFull, $runFull, [StringComparison]::OrdinalIgnoreCase) -and
        -not $rootFull.StartsWith($runPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Staging root escapes its unique run directory: $rootFull"
    }

    # The run directory is newly created without reuse. Refuse unexpected junctions/symlinks
    # below it before each staging write; proposal paths cannot create reparse points.
    $relative = $pathFull.Substring($runFull.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $cursor = $runFull
    foreach ($part in $relative.Split([char][IO.Path]::DirectorySeparatorChar)) {
        if ([string]::IsNullOrEmpty($part)) { continue }
        $cursor = Join-Path $cursor $part
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Staging path traverses a reparse point: $cursor"
            }
        }
    }
    return $pathFull
}

try {
    if ($Apply -and $Profile -ne 'write') { throw 'Apply requires -Profile write.' }
    if ($Apply -and -not $AcknowledgeWriteProfile) { throw 'Apply requires -AcknowledgeWriteProfile.' }
    if (-not (Test-Path -LiteralPath $ProposalPath -PathType Leaf)) { throw "Proposal does not exist: $ProposalPath" }
    if (-not (Test-Path -LiteralPath $ProjectFile -PathType Leaf)) { throw "Project file does not exist: $ProjectFile" }
    $proposal = Get-Content -Raw -LiteralPath $ProposalPath | ConvertFrom-Json
    if ([string]$proposal.status -ne 'PROPOSED') { throw "Proposal status must be PROPOSED, got '$($proposal.status)'." }
    if ($proposal.readOnly -ne $true -or $proposal.applied -ne $false -or $proposal.tiaMutation -ne $false) { throw 'Proposal safety flags are invalid.' }
    if ([string]$proposal.projectPath -and [IO.Path]::GetFullPath([string]$proposal.projectPath) -ne $ProjectFile) {
        throw "Proposal targets '$($proposal.projectPath)', not '$ProjectFile'."
    }
    if ([string]$proposal.block.language -ne 'SCL') { throw 'Only SCL proposals can be applied by this runner.' }
    if ([string]$proposal.block.name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { throw 'Proposal block name is not a valid symbolic identifier.' }
    if ($proposal.checks.uniqueReplacement -ne $true) { throw 'Proposal does not claim a unique replacement.' }
    # noBlockingFindings is untrusted proposal data; live block, source, tag and import gates below
    # independently decide whether this write is eligible.
    $report.proposalClaims = [ordered]@{ noBlockingFindings = $proposal.checks.noBlockingFindings; findingCount = @($proposal.findings).Count }
    $proposedSource = [IO.Path]::GetFullPath([string]$proposal.source.proposedPath)
    $sourceExtension = [IO.Path]::GetExtension($proposedSource).ToLowerInvariant()
    if ($sourceExtension -notin @('.s7dcl', '.scl')) { throw 'Proposal source must be .s7dcl or .scl.' }
    if (-not (Test-Path -LiteralPath $proposedSource -PathType Leaf)) { throw "Proposed source does not exist: $proposedSource" }
    $proposedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $proposedSource).Hash.ToLowerInvariant()
    if ($proposedHash -ne [string]$proposal.source.proposedSha256) { throw 'Proposed source hash does not match proposal.json; it may have been altered.' }
    $originalSource = [IO.Path]::GetFullPath([string]$proposal.source.originalPath)
    if (-not (Test-Path -LiteralPath $originalSource -PathType Leaf)) { throw "Original source does not exist: $originalSource" }
    $originalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $originalSource).Hash.ToLowerInvariant()
    if ($originalHash -ne [string]$proposal.source.originalSha256) { throw 'Original source hash does not match proposal.json; the source changed after proposal generation.' }
    $proposedText = Get-Content -Raw -LiteralPath $proposedSource
    $sourceDeclaration = Assert-TiaSclSourceTarget -SourceText $proposedText -ExpectedName ([string]$proposal.block.name)

    $blockPath = [string]$proposal.block.path
    $separator = $blockPath.LastIndexOf('/')
    if ($separator -lt 0) { $separator = $blockPath.LastIndexOf('\') }
    $groupPath = if ($separator -gt 0) { $blockPath.Substring(0, $separator) } else { '' }
    $blockName = [string]$proposal.block.name
    if ($separator -ge 0 -and $blockPath.Substring($separator + 1) -ne $blockName) { throw 'Proposal block name and path disagree.' }
    $blockPathInfo = Get-ValidatedBlockPath -BlockPath $blockPath -BlockName $blockName
    $blockPath = $blockPathInfo.normalizedPath
    $groupPath = $blockPathInfo.groupPath
    $softwarePath = [string]$proposal.plc
    if ([string]::IsNullOrWhiteSpace($softwarePath)) { throw 'Proposal has no PLC softwarePath.' }

    $projectDirectory = Split-Path -Parent $ProjectFile
    $documentsDirectory = [IO.Path]::GetFullPath((Join-Path $runDirectory 'documents'))
    New-Item -ItemType Directory -Path $documentsDirectory -Force | Out-Null
    $documentsDirectory = Assert-TiaStagingPathContained -Path $documentsDirectory -AllowedRoot $runDirectory -RunRoot $runDirectory
    $stagedDocument = $null
    $stagedSourceRoot = $null
    if ($sourceExtension -eq '.s7dcl') {
        $stagedDocument = Assert-TiaStagingPathContained -Path (Join-Path $documentsDirectory ($blockName + '.s7dcl')) -AllowedRoot $documentsDirectory -RunRoot $runDirectory
        Copy-Item -LiteralPath $proposedSource -Destination $stagedDocument -Force
    }
    else {
        $stagedSourceRoot = Join-Path $documentsDirectory 'Program blocks'
        foreach ($groupSegment in $blockPathInfo.groupSegments) {
            $stagedSourceRoot = Join-Path $stagedSourceRoot $groupSegment
        }
        $stagedSourceRoot = Assert-TiaStagingPathContained -Path $stagedSourceRoot -AllowedRoot $documentsDirectory -RunRoot $runDirectory
        New-Item -ItemType Directory -Path $stagedSourceRoot -Force | Out-Null
        $stagedSourceRoot = Assert-TiaStagingPathContained -Path $stagedSourceRoot -AllowedRoot $documentsDirectory -RunRoot $runDirectory
        $stagedDocument = Assert-TiaStagingPathContained -Path (Join-Path $stagedSourceRoot ($blockName + '.scl')) -AllowedRoot $stagedSourceRoot -RunRoot $runDirectory
        Copy-Item -LiteralPath $proposedSource -Destination $stagedDocument -Force
    }
    $companionSource = [IO.Path]::ChangeExtension($proposedSource, '.s7res')
    $stagedCompanion = $null
    if ($sourceExtension -eq '.s7dcl' -and (Test-Path -LiteralPath $companionSource -PathType Leaf)) {
        $stagedCompanion = Assert-TiaStagingPathContained -Path (Join-Path $documentsDirectory ($blockName + '.s7res')) -AllowedRoot $documentsDirectory -RunRoot $runDirectory
        Copy-Item -LiteralPath $companionSource -Destination $stagedCompanion -Force
    }
    $report.localValidation = [ordered]@{
        success = $true
        projectMatch = $true
        block = $blockName
        blockPath = $blockPath
        softwarePath = $softwarePath
        groupPath = $groupPath
        proposedSource = $proposedSource
        proposedSha256 = $proposedHash
        originalSource = $originalSource
        originalSha256 = $originalHash
        stagedDocument = $stagedDocument
        stagedSourceRoot = $stagedSourceRoot
        stagedCompanion = $stagedCompanion
        importMode = if ($sourceExtension -eq '.s7dcl') { 'document' } else { 'external-source' }
        sourceDeclaration = $sourceDeclaration
    }

    if (-not $Apply) {
        $report.status = 'PREVIEW'
        $report.preview = [ordered]@{
            success = $true
            kind = if ($sourceExtension -eq '.s7dcl') { 'document' } else { 'external-source' }
            tool = 'local-validation'
            block = $blockName
            blockPath = $blockPath
            groupPath = $groupPath
            response = [ordered]@{
                exactBlock = $true
                importMode = if ($sourceExtension -eq '.s7dcl') { 'ImportFromDocuments' } else { 'ImportSources' }
                stagedDocument = $stagedDocument
                overwrite = $true
                note = 'No se conecto con TIA; preview local solamente.'
            }
        }
        $report.message = 'Local validation passed. No TIA connection or project mutation was attempted.'
    }
    else {
        if ($sourceExtension -eq '.s7dcl') {
            $report.import.requiredTool = 'ImportFromDocuments'
            throw 'Apply blocked: .s7dcl import-result counts and exact object readback contract are not verified. Keep this input in local preview only.'
        }
        $fixtureContext = Get-TiaFixtureContext -RootPath $FixtureRoot -ExpectedProjectFile $ProjectFile
        $FixtureRoot = $fixtureContext.root
        $report.fixture = [ordered]@{
            success = $true; snapshotVerified = $true; manifestPath = $fixtureContext.manifestPath
            fixtureRoot = $fixtureContext.root; projectPath = $fixtureContext.projectPath
            backupProjectPath = $fixtureContext.backupProjectPath; sourceProjectPath = $fixtureContext.sourceProjectPath
            projectSnapshotSha256 = $fixtureContext.projectSnapshotSha256; backupSnapshotSha256 = $fixtureContext.backupSnapshotSha256
        }
        $mcpArguments = "--tia-major-version 20 --isolated --fixture-root `"$FixtureRoot`" --allow-write"
        $report.mcp = [ordered]@{
            server = 'tia-inspect'; profile = 'write'; isolated = $true; writeEnabled = $true
            fixtureRoot = $FixtureRoot; arguments = $mcpArguments
        }

        $tiaProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $_.ProcessName -like 'Siemens.Automation.Portal*'
        })
        $visiblePids = @($tiaProcesses | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object Id)
        $report.sessionGuard.visiblePids = $visiblePids
        if ($tiaProcesses.Count -gt 0) {
            $report.sessionGuard = [ordered]@{
                success = $false; status = 'tia-process-already-running'; visiblePids = $visiblePids
                processIds = @($tiaProcesses.Id)
                message = 'No se aplica mientras haya cualquier proceso TIA Portal: tia-inspect no permite adjuntar con seguridad a la instancia exacta.'
            }
            throw 'Apply blocked: a TIA Portal process already exists.'
        }
        $report.sessionGuard = [ordered]@{ success = $true; status = 'no-existing-tia-process'; visiblePids = @(); processIds = @() }

        $backupDirectory = Join-Path $runDirectory 'backup-project'
        $report.backup.attempted = $true
        Copy-Item -LiteralPath $projectDirectory -Destination $backupDirectory -Recurse -Force
        $backupFile = Join-Path $backupDirectory ([IO.Path]::GetFileName($ProjectFile))
        if (-not (Test-Path -LiteralPath $backupFile -PathType Leaf)) { throw 'Backup did not contain the project file.' }
        $backupSnapshot = Get-TiaDirectoryFingerprint $backupDirectory
        if ($backupSnapshot -ne $fixtureContext.projectSnapshotSha256) { throw 'The fresh pre-write backup differs from the manifest-authorized project snapshot.' }
        $report.backup = [ordered]@{
            attempted = $true; success = $true; path = $backupDirectory; projectFile = $backupFile
            projectHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backupFile).Hash
            projectSnapshotSha256 = $fixtureContext.projectSnapshotSha256; copiedSnapshotSha256 = $backupSnapshot
        }

        $preflightSequence = Invoke-Sequence @(
            @{ name = 'Doctor' },
            @{ name = 'tools/list'; method = 'tools/list' },
            @{ name = 'Connect' },
            @{ name = 'GetState' }
        ) 'preflight'
        $requiredImportTool = if ($sourceExtension -eq '.s7dcl') { 'ImportFromDocuments' } else { 'ImportSources' }
        $report.import.requiredTool = $requiredImportTool
        $report.import.capabilityChecked = $true
        $toolListCall = Get-Call $preflightSequence 'tools/list'
        if (-not $toolListCall -or $toolListCall.success -ne $true) {
            throw 'The active MCP profile did not provide a successful tools/list response; import capability is unknown.'
        }
        Assert-TiaSclImportCapability -ToolListPayload $toolListCall.response -RequiredTool $requiredImportTool
        $report.import.capabilityAvailable = $true
        $state = Read-CallJson (Get-Call $preflightSequence 'GetState') 'GetState'
        $expectedProject = [IO.Path]::GetFileNameWithoutExtension($ProjectFile)
        if ([string]$state.session -and [string]$state.session -ne '-') { throw 'A Multiuser session is open, but this runner has no verified SaveSession path.' }
        if ([string]$state.project -ne '-' -and [string]$state.project -ne $expectedProject) { throw "A different project is already open: '$($state.project)'." }
        $report.preflight = [ordered]@{ success = $true; state = $state; openedByRunner = ([string]$state.project -eq '-') }

        $open = @()
        if ([string]$state.project -eq '-') { $open += @{ name = 'OpenProject'; args = @{ path = $ProjectFile } } }
        $inspectCalls = @(
            @{ name = 'Connect' }
        ) + $open + @(
            @{ name = 'GetProjectTree' },
            @{ name = 'GetSoftwareTree'; args = @{ softwarePath = $softwarePath; sections = 'blocks,tags,types,sources' } },
            @{ name = 'GetBlocks'; args = @{ softwarePath = $softwarePath; regexName = $blockName } },
            @{ name = 'GetTags'; args = @{ softwarePath = $softwarePath; tagTablePath = ''; regexName = '' } },
            @{ name = 'GetBlockSource'; args = @{ softwarePath = $softwarePath; blockPath = $blockPath; format = 'document'; maxChars = 2147483647 } }
        )
        $inspectSequence = Invoke-Sequence $inspectCalls 'inspect-preview'
        $blocksPayload = Read-CallJson (Get-Call $inspectSequence 'GetBlocks') 'GetBlocks'
        $existing = Get-ExactBlock $blocksPayload $blockName $blockPath
        Assert-TiaSclBlockWritable -Block $existing -ExpectedName $blockName -ExpectedPath $blockPath
        Assert-TiaSclDeclarationMatchesBlock -DeclarationKind $sourceDeclaration.kind -Block $existing
        $tagsPayload = Read-CallJson (Get-Call $inspectSequence 'GetTags') 'GetTags'
        Assert-TiaSclTagInventoryWritable -TagPayload $tagsPayload
        $liveSource = Read-CallJson (Get-Call $inspectSequence 'GetBlockSource') 'GetBlockSource before import'
        if ($liveSource.truncated -ne $false -or [string]::IsNullOrWhiteSpace([string]$liveSource.text)) {
            throw 'Existing block source is truncated, empty, or lacks an explicit complete-read result.'
        }
        if ([string]$liveSource.path -cne $blockPath) { throw "Live source path '$($liveSource.path)' differs from '$blockPath'." }
        $originalText = Get-Content -Raw -LiteralPath $originalSource
        if (-not [string]::Equals(
            (ConvertTo-TiaComparableSource ([string]$liveSource.text)),
            (ConvertTo-TiaComparableSource ([string]$originalText)),
            [StringComparison]::Ordinal
        )) {
            throw 'The live TIA block source differs from the source used to generate the proposal; regenerate the proposal before writing.'
        }
        $sourceBytes = [Text.Encoding]::UTF8.GetBytes([string]$liveSource.text)
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try { $liveSourceHash = [BitConverter]::ToString($sha256.ComputeHash($sourceBytes)).Replace('-', '').ToLowerInvariant() }
        finally { $sha256.Dispose() }
        $report.sourceRead = [ordered]@{
            success = $true; blockPath = [string]$liveSource.path; format = [string]$liveSource.format
            totalChars = [int]$liveSource.totalChars; truncated = $false; sha256 = $liveSourceHash
        }
        $report.tagSafetyGate = [ordered]@{ success = $true; count = @($tagsPayload.items).Count; safetyTagCount = 0; mode = 'whole-plc-fail-closed' }
        if ($sourceExtension -eq '.s7dcl') {
            $previewCalls = @(
                @{ name = 'Connect' },
                @{ name = 'PreviewImport'; args = @{ softwarePath = $softwarePath; importPath = $documentsDirectory; kind = 'block'; groupPath = $groupPath } }
            )
            $previewSequence = Invoke-Sequence $previewCalls 'preview-import'
            $previewPayload = Read-CallJson (Get-Call $previewSequence 'PreviewImport') 'PreviewImport'
            if ($previewPayload.meta.success -ne $true -or @($previewPayload.items).Count -ne 1 -or
                $previewPayload.conflictCount -ne 0 -or [string]$previewPayload.items[0].name -ine $blockName -or
                [string]$previewPayload.items[0].effect -cne 'overwrite' -or
                [string]$previewPayload.items[0].existingPath -cne $blockPath) {
                throw 'PreviewImport did not confirm one unambiguous overwrite of the exact target block.'
            }
            $report.preview = [ordered]@{ success = $true; kind = 'document'; tool = 'PreviewImport'; block = $blockName; blockPath = $blockPath; groupPath = $groupPath; response = $previewPayload; existing = [ordered]@{ path = [string]$existing.path; type = [string]$existing.typeName; language = [string]$existing.programmingLanguage } }
            $mutationCalls = @{ name = 'ImportFromDocuments'; args = @{ softwarePath = $softwarePath; groupPath = $groupPath; importPath = $documentsDirectory; fileNameWithoutExtension = $blockName; importOption = 'Override' } }
        }
        else {
            $report.preview = [ordered]@{ success = $true; kind = 'external-source'; tool = 'local-validation'; block = $blockName; blockPath = $blockPath; groupPath = $groupPath; response = [ordered]@{ exactBlock = $true; stagedSource = $stagedDocument; overwrite = $true; note = 'ImportSources no expone un PreviewImport equivalente para .scl; la validacion previa es local y el gate real es la compilacion.' }; existing = [ordered]@{ path = [string]$existing.path; type = [string]$existing.typeName; language = [string]$existing.programmingLanguage } }
            $mutationCalls = @{ name = 'ImportSources'; args = @{ softwarePath = $softwarePath; importPath = $documentsDirectory; regexName = ('^' + [regex]::Escape($blockName) + '$'); keepOnError = $false } }
        }

        $report.tiaMutation = $true
        $report.readOnly = $false
        $report.import = [ordered]@{ attempted = $true; success = $false; mode = if ($sourceExtension -eq '.s7dcl') { 'document' } else { 'external-source' }; tool = [string]$mutationCalls.name }
        $importSequence = Invoke-Sequence @(@{ name = 'Connect' }, $mutationCalls) 'import'
        $importPayload = Read-CallJson (Get-Call $importSequence ([string]$mutationCalls.name)) ([string]$mutationCalls.name)
        if ($sourceExtension -eq '.scl') {
            Assert-TiaSclImportResult -ImportPayload $importPayload -ExpectedName $blockName -ExpectedPath $blockPath
        }
        elseif ($importPayload.meta.success -ne $true) {
            throw 'ImportFromDocuments did not report a successful import.'
        }
        $report.import.success = $true
        $report.import.response = $importPayload

        $verifySequence = Invoke-Sequence @(
            @{ name = 'Connect' },
            @{ name = 'GetBlocks'; args = @{ softwarePath = $softwarePath; regexName = $blockName } },
            @{ name = 'GetBlockSource'; args = @{ softwarePath = $softwarePath; blockPath = $blockPath; format = 'document'; maxChars = 2147483647 } }
        ) 'verify-import'
        $compiledBlock = Read-CallJson (Get-Call $verifySequence 'GetBlocks') 'GetBlocks after import'
        $importedBlock = Get-ExactBlock $compiledBlock $blockName $blockPath
        Assert-TiaSclBlockWritable -Block $importedBlock -ExpectedName $blockName -ExpectedPath $blockPath
        Assert-TiaSclDeclarationMatchesBlock -DeclarationKind $sourceDeclaration.kind -Block $importedBlock
        $postImportSource = Read-CallJson (Get-Call $verifySequence 'GetBlockSource') 'GetBlockSource after import'
        if ($postImportSource.truncated -ne $false -or [string]::IsNullOrWhiteSpace([string]$postImportSource.text)) {
            throw 'Imported block source is truncated, empty, or lacks an explicit complete-read result.'
        }
        if ([string]$postImportSource.path -cne $blockPath) { throw "Post-import source path '$($postImportSource.path)' differs from '$blockPath'." }
        if (-not [string]::Equals(
            (ConvertTo-TiaComparableSource ([string]$postImportSource.text)),
            (ConvertTo-TiaComparableSource ([string]$proposedText)),
            [StringComparison]::Ordinal
        )) {
            throw 'TIA readback differs from the proposed SCL source; compile and save are blocked.'
        }

        $compileSequence = Invoke-Sequence @(
            @{ name = 'Connect' },
            @{ name = 'CompileSoftware'; args = @{ softwarePath = $softwarePath; password = '' } }
        ) 'compile'
        $compilePayload = Read-CallJson (Get-Call $compileSequence 'CompileSoftware') 'CompileSoftware'
        $report.compile = [ordered]@{ attempted = $true; success = ($compilePayload.errorCount -eq 0 -and $compilePayload.warningCount -eq 0); state = $compilePayload.state; errorCount = [int]$compilePayload.errorCount; warningCount = [int]$compilePayload.warningCount; messages = @($compilePayload.messages) }
        if (-not $report.compile.success) { throw "Compile gate failed: $($report.compile.errorCount) error(s), $($report.compile.warningCount) warning(s). Save was not attempted." }

        $exportDirectory = Join-Path $runDirectory 'export'
        $persistSequence = Invoke-Sequence @(
            @{ name = 'Connect' },
            @{ name = 'SaveProject' },
            @{ name = 'ExportPlcAsSourceTree'; args = @{ softwarePath = $softwarePath; exportPath = $exportDirectory } },
            @{ name = 'GetBlockSource'; args = @{ softwarePath = $softwarePath; blockPath = $blockPath; format = 'document'; maxChars = 50000 } }
        ) 'save-export'
        $report.save = [ordered]@{ attempted = $true; success = $true; response = Read-CallJson (Get-Call $persistSequence 'SaveProject') 'SaveProject' }
        $exportPayload = Read-CallJson (Get-Call $persistSequence 'ExportPlcAsSourceTree') 'ExportPlcAsSourceTree'
        $readback = Read-CallJson (Get-Call $persistSequence 'GetBlockSource') 'GetBlockSource'
        if (-not $readback) { throw 'GetBlockSource returned no readback.' }
        $report.export = [ordered]@{ attempted = $true; success = $true; path = $exportDirectory; response = $exportPayload }
        $report.verification = [ordered]@{ success = $true; blockPath = $blockPath; source = $readback }
        $report.applied = $true
        $report.status = 'APPLIED_AND_VERIFIED'
        if ($report.preflight.openedByRunner) {
            $cleanupSequence = Invoke-Sequence @(
                @{ name = 'Connect' },
                @{ name = 'CloseProject' },
                @{ name = 'Disconnect' }
            ) 'cleanup'
            $report.cleanup = [ordered]@{ attempted = $true; success = $true; response = $cleanupSequence }
        }
    }
}
catch {
    $report.status = if (-not $report.tiaMutation) { 'BLOCKED' } else { 'FAILED' }
    $report.errors = @($report.errors + [string]$_.Exception.Message)
    if ($report.compile.attempted -and -not $report.compile.success) { $report.save = [ordered]@{ attempted = $false; success = $false; reason = 'compile-gate' } }
    throw
}
finally {
    $report.completedAt = [DateTimeOffset]::Now.ToString('o')
    $report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "Proposal apply report written to $reportPath"
}

if (-not ($report.status -in @('PREVIEW', 'APPLIED_AND_VERIFIED'))) { exit 1 }
exit 0
