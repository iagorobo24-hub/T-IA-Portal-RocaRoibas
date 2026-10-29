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
    [ValidateSet('isolated', 'attached')]
    [string]$Route = 'isolated',
    [string]$AttachProjectName,
    # Inyección restringida a pruebas (mismo patrón que Invoke-TiaSimulationAcceptance):
    # solo válida con -Route attached; la ruta aislada mantiene su binding exacto de fixture.
    [string]$McpExecutablePath,
    [string]$McpArguments,
    # Inyección del readback (puerta de delta de contenido ADR-018): tia-create no expone
    # GetBlockSource, por lo que la verificación final de texto se hace con tia-inspect
    # adjuntado a la misma instancia visible. Solo válida con -Route attached -Apply.
    [string]$ReadbackExecutablePath,
    [string]$ReadbackMcpArguments,
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
Sin -Apply: preview local, sin TIA. Con -Apply: requiere -Profile write y -AcknowledgeWriteProfile.

-Route isolated (por defecto): fixture manifest, aislado, backup, lectura, preview, tools/list,
importador registrado, compile limpio, save, export y readback. Si no existe el importador,
informa BLOCKED sin mutar. Nunca descarga hardware.

-Route attached: ruta con sesión adjunta al TIA Portal ya abierto vía tia-create --profile full
(AttachToOpenProject). Requiere -AttachProjectName, ventana TIA visible, .scl (no .s7dcl),
bloque en el nivel raíz (groupPath vacio, lounico verificado en vivo), gates F/Safety/protección
completos por readback y compile 0/0 antes de SaveProject. Tras guardar, compara el texto vivo
con tia-inspect (GetBlockSource adjuntado) contra la propuesta: solo entonces emite
APPLIED_AND_VERIFIED; en mismatch emite APPLIED_CONTENT_MISMATCH y si el readback no puede
ejecutarse APPLIED_READBACK_FAILED (ambos salen con exit 1 y ordenan restaurar). No descarga
hardware ni cambia el modo online de la CPU: GoOffline es un paso local de sesión de
ingenieria, no un download. No copia .ap20: la restauración es reimportar la fuente original
del proposal con el mismo runner.
'@
    exit 0
}

$ProposalPath = [IO.Path]::GetFullPath($ProposalPath)
$ProjectFile = [IO.Path]::GetFullPath($ProjectFile)
$mcpServerArguments = $null
$attachedRoute = ($Route -eq 'attached')
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
    readback = [ordered]@{ attempted = $false; success = $false }
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

function Invoke-Sequence([array]$Calls, [string]$Name, [string]$ServerExecutable, [string]$ServerArguments) {
    $sequenceScript = Join-Path $root '30-tools\scripts\Invoke-McpToolSequence.ps1'
    if ($ServerExecutable) { $exe = [IO.Path]::GetFullPath($ServerExecutable) }
    elseif ($attachedRoute) {
        $exe = if ($McpExecutablePath) { [IO.Path]::GetFullPath($McpExecutablePath) } else { Join-Path $root '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe' }
    }
    else {
        $exe = Join-Path $root '30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe'
    }
    if (-not $ServerArguments) { $ServerArguments = $mcpServerArguments }
    $sequencePath = Join-Path $runDirectory ("sequence-$Name.json")
    if (-not (Test-Path -LiteralPath $sequenceScript -PathType Leaf)) { throw "Missing MCP sequence runner: $sequenceScript" }
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Missing MCP V20 executable: $exe" }
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }
    # El JSON va por FICHERO: pasado por la linea de comandos de un proceso nativo,
    # Windows PowerShell 5.1 elimina las comillas dobles y el MCP recibe un JSON corrupto.
    $callsPath = $sequencePath + '.calls.json'
    [IO.File]::WriteAllText($callsPath, ($Calls | ConvertTo-Json -Depth 30 -Compress), (New-Object Text.UTF8Encoding($false)))
    if ([string]::IsNullOrWhiteSpace($ServerArguments)) {
        throw 'Server arguments have not been configured: neither injected nor validated from a fixture manifest.'
    }
    $output = (& $pwsh -NoProfile -NonInteractive -File $sequenceScript -ExecutablePath $exe -Arguments $ServerArguments -CallsJsonPath $callsPath -OutputPath $sequencePath -TimeoutSeconds 900 2>&1 | Out-String).Trim()
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
    if (($McpExecutablePath -or $McpArguments) -and -not $attachedRoute) {
        throw 'Executable/arguments overrides are only permitted with -Route attached (test harness injection).'
    }
    if ($attachedRoute) { $mcpServerArguments = if ($McpArguments) { $McpArguments } else { '--tia-major-version 20 --profile full' } }
    if (($ReadbackExecutablePath -or $ReadbackMcpArguments) -and -not ($attachedRoute -and $Apply)) {
        throw 'Readback server overrides are only permitted with -Route attached -Apply (test harness injection).'
    }
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
    # Puerta de veto solo-cabecera (ADR-018, evidencia 2026-10-28): una propuesta cuyo
    # delta completo sean atributos VERSION no produce efecto observable y antes de la
    # puerta de readback declaraba exito igual. Se veta aqui, antes de abrir cualquier
    # sesion MCP.
    $originalText = Get-Content -Raw -LiteralPath $originalSource
    $sourceDelta = Get-TiaSourceLineDelta -OriginalText $originalText -ProposedText $proposedText
    Assert-TiaProposalNotHeaderOnly -SourceDelta $sourceDelta -BlockName ([string]$proposal.block.name)
    $report.proposalClaims.sourceDelta = [ordered]@{ added = @($sourceDelta.added); removed = @($sourceDelta.removed); changedCount = [int]$sourceDelta.changedCount }

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
        if ($attachedRoute) {
            if ([string]::IsNullOrWhiteSpace($AttachProjectName)) {
                throw 'Attached route requires -AttachProjectName naming the exact open project.'
            }
            if (-not [string]::IsNullOrWhiteSpace($groupPath)) {
                throw 'Attached route supports only top-level blocks: ImportPlcExternalSource con groupPath vacio es lo unico verificado en vivo (R28).'
            }

            # La ruta adjunta exige un TIA Portal ya abierto y visible; el runner nunca
            # lanza, cierra ni reinicia una instancia.
            $tiaProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
                $_.ProcessName -like 'Siemens.Automation.Portal*'
            })
            $windowPids = @($tiaProcesses | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object Id)
            $report.sessionGuard.visiblePids = $windowPids
            if ($tiaProcesses.Count -eq 0) {
                $report.sessionGuard = [ordered]@{
                    success = $false; status = 'no-tia-process'; visiblePids = @()
                    message = 'La ruta adjunta exige un TIA Portal ya abierto con el proyecto; el runner no lanza ninguna instancia.'
                }
                throw 'Apply blocked: the attached route requires an already open TIA Portal process.'
            }
            if (@($windowPids).Count -eq 0) {
                $report.sessionGuard = [ordered]@{
                    success = $false; status = 'no-visible-tia-window'; visiblePids = @()
                    processIds = @($tiaProcesses.Id)
                    message = 'La ruta adjunta exige una ventana TIA visible para identificar el proyecto; ninguna instancia la expone.'
                }
                throw 'Apply blocked: no visible TIA Portal window to attach to.'
            }
            $report.sessionGuard = [ordered]@{ success = $true; status = 'open-tia-window'; visiblePids = $windowPids; processIds = @($tiaProcesses.Id) }

            $report.fixture = [ordered]@{ success = $false; snapshotVerified = $false; skippedReason = 'attached-route-uses-open-project' }
            if ($McpExecutablePath) { $report.mcp.executableOverride = [IO.Path]::GetFullPath($McpExecutablePath) }
            $report.mcp = [ordered]@{ server = 'tia-create'; profile = 'full'; isolated = $false; writeEnabled = $true; arguments = $mcpServerArguments }

            # El roster live debe registrar TODAS las herramientas del ciclo verificado;
            # si falta una, se bloquea antes de tocar TIA.
            $requiredTools = @('AttachToOpenProject', 'GetProjectTree', 'GetBlocks', 'GetTags', 'GoOffline',
                'ImportPlcExternalSource', 'GenerateBlocksFromExternalSource', 'DeletePlcExternalSource',
                'CompileSoftware', 'SaveProject')
            $rosterSequence = Invoke-Sequence @(
                @{ name = 'Bootstrap' },
                @{ name = 'tools/list'; method = 'tools/list' }
            ) 'attached-roster'
            $report.import.capabilityChecked = $true
            $report.import.requiredTool = ($requiredTools -join ',')
            $rosterPayload = (Get-Call $rosterSequence 'tools/list').response
            Assert-TiaCreateApplyCapability -ToolListPayload $rosterPayload -RequiredTools $requiredTools
            $report.import.capabilityAvailable = $true

            # Identidad del proyecto adjunto: mensaje de AttachToOpenProject y raiz
            # del arbol, las dos evidencias en vivo del 2026-09-25.
            $attachSequence = Invoke-Sequence @(
                @{ name = 'Connect' },
                @{ name = 'AttachToOpenProject'; args = @{ projectName = $AttachProjectName } },
                @{ name = 'GetProjectTree' }
            ) 'attach-identity'
            $attachCall = Get-Call $attachSequence 'AttachToOpenProject'
            $treePayload = Read-CallJson (Get-Call $attachSequence 'GetProjectTree') 'GetProjectTree'
            Assert-TiaCreateAttachIdentity -AttachMessage ([string]$attachCall.text) -ProjectTreeText ([string]$treePayload.tree) -ExpectedProjectName $AttachProjectName
            $report.attach = [ordered]@{ success = $true; projectName = $AttachProjectName }

            $gateSequence = Invoke-Sequence @(
                @{ name = 'Connect' },
                @{ name = 'GetBlocks'; args = @{ softwarePath = $softwarePath } },
                @{ name = 'GetTags'; args = @{ softwarePath = $softwarePath } }
            ) 'attached-gates'
            $blocksPayload = Read-CallJson (Get-Call $gateSequence 'GetBlocks') 'GetBlocks'
            $existing = @($blocksPayload.items | Where-Object { [string]$_.name -ieq $blockName })[0]
            Assert-TiaCreateBlockWritable -BlocksPayload $blocksPayload -BlockName $blockName -DeclarationKind $sourceDeclaration.kind
            $tagsPayload = Read-CallJson (Get-Call $gateSequence 'GetTags') 'GetTags'
            Assert-TiaCreateTagInventoryWritable -TagPayload $tagsPayload
            $report.tagSafetyGate = [ordered]@{ success = $true; count = @($tagsPayload.items).Count; safetyTagCount = 0; mode = 'whole-plc-fail-closed'; source = 'tia-create' }

            $externalSourceName = [IO.Path]::GetFileNameWithoutExtension($stagedDocument)
            $report.preview = [ordered]@{
                success = $true; kind = 'external-source'; tool = 'ImportPlcExternalSource'
                block = $blockName; blockPath = $blockPath; groupPath = $groupPath
                stagedSource = $stagedDocument; externalSourceName = $externalSourceName
                response = [ordered]@{ exactBlock = $true; overwrite = $true; note = 'GenerateBlocksFromExternalSource actualiza el bloque existente, verificado en vivo (R28); el bloque lo protege el gate de nombre unico, SCL, no-F, no-protegido y consistente.' }
                existing = [ordered]@{ name = [string]$existing.name; typeName = [string]$existing.typeName; language = [string]$existing.programmingLanguage }
            }

            $report.tiaMutation = $true
            $report.readOnly = $false
            $report.import = [ordered]@{ attempted = $true; success = $false; mode = 'external-source'; tool = 'ImportPlcExternalSource'; stagedDocument = $stagedDocument; externalSourceName = $externalSourceName }
            # Ciclo verificado en vivo (ADR-015/R28): GoOffline -> fuente externa ->
            # generacion -> limpieza de la fuente temporal -> compile -> readback -> save.
            $mutationSequence = Invoke-Sequence @(
                @{ name = 'Connect' },
                @{ name = 'GoOffline'; args = @{ softwarePath = $softwarePath } },
                @{ name = 'ImportPlcExternalSource'; args = @{ softwarePath = $softwarePath; groupPath = ''; filePath = $stagedDocument } },
                @{ name = 'GenerateBlocksFromExternalSource'; args = @{ softwarePath = $softwarePath; externalSourceName = $externalSourceName } },
                @{ name = 'DeletePlcExternalSource'; args = @{ softwarePath = $softwarePath; externalSourceName = $externalSourceName } },
                @{ name = 'CompileSoftware'; args = @{ softwarePath = $softwarePath; password = '' } }
            ) 'attached-mutation'
            $report.import = [ordered]@{ attempted = $true; success = $true; mode = 'external-source'; tool = 'ImportPlcExternalSource'; stagedDocument = $stagedDocument; externalSourceName = $externalSourceName; response = Read-CallJson (Get-Call $mutationSequence 'GenerateBlocksFromExternalSource') 'GenerateBlocksFromExternalSource' }
            $compilePayload = Read-CallJson (Get-Call $mutationSequence 'CompileSoftware') 'CompileSoftware'
            $report.compile = [ordered]@{ attempted = $true; success = ($compilePayload.errorCount -eq 0 -and $compilePayload.warningCount -eq 0); state = $compilePayload.state; errorCount = [int]$compilePayload.errorCount; warningCount = [int]$compilePayload.warningCount; messages = @($compilePayload.messages) }
            if (-not $report.compile.success) { throw "Compile gate failed: $($report.compile.errorCount) error(s), $($report.compile.warningCount) warning(s). Save was not attempted." }

            # Puerta de delta de contenido (ADR-018): tia-create no expone GetBlockSource, asi
            # que el texto vivo se lee con tia-inspect adjuntado en modo de solo lectura a la
            # MISMA instancia visible, ANTES de SaveProject: un mismatch no guarda la mutacion
            # sin efecto.
            $report.readback = [ordered]@{ attempted = $true; success = $false; server = 'tia-inspect'; mode = 'attach' }
            $readbackExecutable = if ($ReadbackExecutablePath) { [IO.Path]::GetFullPath($ReadbackExecutablePath) } else { Join-Path $root '30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe' }
            $readbackArguments = if ($ReadbackMcpArguments) { $ReadbackMcpArguments } else { '--tia-major-version 20' }
            $readbackStatus = 'APPLIED_READBACK_FAILED'
            $readbackError = $null
            try {
                $readbackSequence = Invoke-Sequence @(
                    @{ name = 'Connect' },
                    @{ name = 'GetState' },
                    @{ name = 'GetBlockSource'; args = @{ softwarePath = $softwarePath; blockPath = $blockPath; format = 'document'; maxChars = 2147483647 } }
                ) 'attached-readback' $readbackExecutable $readbackArguments
                $readbackState = Read-CallJson (Get-Call $readbackSequence 'GetState') 'GetState before readback'
                if ([string]$readbackState.project -cne $AttachProjectName) {
                    throw "Readback GetState reports project '$($readbackState.project)', expected '$AttachProjectName'."
                }
                $postSaveSource = Read-CallJson (Get-Call $readbackSequence 'GetBlockSource') 'GetBlockSource after mutation'
                if ($postSaveSource.truncated -ne $false -or [string]::IsNullOrWhiteSpace([string]$postSaveSource.text)) {
                    throw 'Post-mutation block source is truncated, empty, or lacks an explicit complete-read result.'
                }
                if ([string]$postSaveSource.path -cne $blockPath) { throw "Post-mutation source path '$($postSaveSource.path)' differs from '$blockPath'." }
                # Evidencia permanente: el texto vivo generado por Openness queda en el informe,
                # sobre todo si el mimo rechaza cambiaciones de cabecera (APPLIED_CONTENT_MISMATCH).
                $report.readback.liveText = [string]$postSaveSource.text
                if (-not [string]::Equals(
                    (ConvertTo-TiaComparableSource ([string]$postSaveSource.text)),
                    (ConvertTo-TiaComparableSource ([string]$proposedText)),
                    [StringComparison]::Ordinal
                )) {
                    $readbackStatus = 'APPLIED_CONTENT_MISMATCH'
                    throw 'TIA readback differs from the proposed SCL source; the mutation has no observable effect as staged. Save is blocked.'
                }
            }
            catch { $readbackError = [string]$_.Exception.Message }
            if ($readbackError) {
                $report.readback.success = $false
                $report.readback.error = $readbackError
                $report.status = $readbackStatus
                $report.save = [ordered]@{ attempted = $false; success = $false; reason = 'readback-content-gate' }
                $report.postFailureInstruction = 'La mutacion quedo en el proyecto SIN guardar. No guardes: cierra el proyecto sin guardar o restaura reimportando la fuente original del proposal (originalSha256) con este mismo runner antes de cualquier reintento.'
                throw ("Readback content gate failed ($readbackStatus): $readbackError")
            }
            $report.readback.success = $true

            $verifySequence = Invoke-Sequence @(
                @{ name = 'Connect' },
                @{ name = 'GetBlocks'; args = @{ softwarePath = $softwarePath } },
                @{ name = 'SaveProject' },
                @{ name = 'Disconnect' }
            ) 'attached-persist'
            $importedPayload = Read-CallJson (Get-Call $verifySequence 'GetBlocks') 'GetBlocks after import'
            Assert-TiaCreateBlockWritable -BlocksPayload $importedPayload -BlockName $blockName -DeclarationKind $sourceDeclaration.kind
            $report.save = [ordered]@{ attempted = $true; success = $true; response = Read-CallJson (Get-Call $verifySequence 'SaveProject') 'SaveProject' }
            $report.export = [ordered]@{ attempted = $false; success = $false; reason = 'La ruta adjunta no incluye el export de arbol textual; ejecutar el ciclo R03 despues para exportar a src/.' }
            $report.verification = [ordered]@{
                success = $true; blockName = $blockName; blockPath = $blockPath
                readback = $importedPayload
                sourceCompared = $true
                note = 'El readback tia-create reafirma SCL/no-F/no-protegido/consistente; el texto vivo se comparo contra la propuesta via tia-inspect adjuntado (puerta de delta de contenido ADR-018) antes de SaveProject.'
            }
            $report.applied = $true
            $report.status = 'APPLIED_AND_VERIFIED'
        }
        else {
        $fixtureContext = Get-TiaFixtureContext -RootPath $FixtureRoot -ExpectedProjectFile $ProjectFile
        $FixtureRoot = $fixtureContext.root
        $report.fixture = [ordered]@{
            success = $true; snapshotVerified = $true; manifestPath = $fixtureContext.manifestPath
            fixtureRoot = $fixtureContext.root; projectPath = $fixtureContext.projectPath
            backupProjectPath = $fixtureContext.backupProjectPath; sourceProjectPath = $fixtureContext.sourceProjectPath
            projectSnapshotSha256 = $fixtureContext.projectSnapshotSha256; backupSnapshotSha256 = $fixtureContext.backupSnapshotSha256
        }
        $mcpServerArguments = "--tia-major-version 20 --isolated --fixture-root `"$FixtureRoot`" --allow-write"
        $report.mcp = [ordered]@{
            server = 'tia-inspect'; profile = 'write'; isolated = $true; writeEnabled = $true
            fixtureRoot = $FixtureRoot; arguments = $mcpServerArguments
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
}
catch {
    # APPLIED_CONTENT_MISMATCH y APPLIED_READBACK_FAILED son estados post-mutacion
    # explicitos: el catch generico no los debe reescribir como FAILED.
    if (-not ($report.status -in @('APPLIED_CONTENT_MISMATCH', 'APPLIED_READBACK_FAILED'))) {
        $report.status = if (-not $report.tiaMutation) { 'BLOCKED' } else { 'FAILED' }
    }
    $report.errors = @($report.errors + [string]$_.Exception.Message)
    if ($report.compile.attempted -and -not $report.compile.success) { $report.save = [ordered]@{ attempted = $false; success = $false; reason = 'compile-gate' } }
    if ($attachedRoute -and $report.compile.attempted -and -not $report.compile.success) {
        $report.postFailureInstruction = 'No guardes el proyecto abierto en TIA: cierralo sin guardar y restaura reimportando la fuente original del proposal (originalSha256) con este mismo runner.'
    }
    throw
}
finally {
    $report.completedAt = [DateTimeOffset]::Now.ToString('o')
    $report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "Proposal apply report written to $reportPath"
}

if (-not ($report.status -in @('PREVIEW', 'APPLIED_AND_VERIFIED'))) { exit 1 }
exit 0
