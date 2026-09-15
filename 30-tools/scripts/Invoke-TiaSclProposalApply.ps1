<##
.SYNOPSIS
    Valida y, opcionalmente, aplica una propuesta SCL a un proyecto TIA V20.

.DESCRIPTION
    Por defecto solo valida y deja un informe PREVIEW. Con -Apply ejecuta el ciclo completo:
    backup -> guardia de instancia -> Connect/Open -> lectura de rutas y bloque -> preview local
    -> importacion de documento o fuente SCL -> CompileSoftware -> SaveProject -> export y lectura posterior.

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

    [string]$ReportRoot,
    [switch]$Apply,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

if ($Help) {
    Write-Output @'
Invoke-TiaSclProposalApply.ps1: aplica propuestas SCL con gates de backup y compilacion.
Sin -Apply: preview local, sin TIA. Con -Apply: backup, lectura, preview, import, compile limpio,
save, export y readback. Usa ImportFromDocuments para .s7dcl o ImportSources para .scl.
Nunca descarga hardware.
'@
    exit 0
}

$ProposalPath = [IO.Path]::GetFullPath($ProposalPath)
$ProjectFile = [IO.Path]::GetFullPath($ProjectFile)
if (-not $ReportRoot) { $ReportRoot = Join-Path $root '70-runs\e2e\proposal-apply' }
$ReportRoot = [IO.Path]::GetFullPath($ReportRoot)
$runDirectory = Join-Path $ReportRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
$reportPath = Join-Path $runDirectory 'apply-report.json'
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null

$report = [ordered]@{
    schemaVersion = 1
    startedAt = [DateTimeOffset]::Now.ToString('o')
    status = if ($Apply) { 'RUNNING' } else { 'PREVIEW' }
    applied = $false
    readOnly = (-not $Apply)
    tiaMutation = $false
    proposalPath = $ProposalPath
    projectFile = $ProjectFile
    backup = [ordered]@{ attempted = $false; success = $false }
    localValidation = [ordered]@{ success = $false }
    sessionGuard = [ordered]@{ success = $false; visiblePids = @() }
    preflight = [ordered]@{ success = $false }
    preview = [ordered]@{ success = $false }
    import = [ordered]@{ attempted = $false; success = $false }
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
    $callsJson = $Calls | ConvertTo-Json -Depth 30 -Compress
    $output = (& $pwsh -NoProfile -NonInteractive -File $sequenceScript -ExecutablePath $exe -Arguments '--tia-major-version 20 --allow-write' -CallsJson $callsJson -OutputPath $sequencePath -TimeoutSeconds 900 2>&1 | Out-String).Trim()
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

function Get-ExactBlock([object]$BlocksPayload, [string]$Name, [string]$ExpectedPath) {
    $items = @($BlocksPayload.items | Where-Object { [string]$_.name -ieq $Name })
    if ($items.Count -ne 1) { throw "Expected exactly one existing block '$Name'; found $($items.Count)." }
    if ($ExpectedPath -and [string]$items[0].path -ne $ExpectedPath) { throw "Existing block path '$($items[0].path)' differs from proposal path '$ExpectedPath'." }
    if ([bool]$items[0].isKnowHowProtected) { throw "Block '$Name' is know-how protected." }
    if ($items[0].PSObject.Properties.Name -contains 'isConsistent' -and -not [bool]$items[0].isConsistent) { throw "Block '$Name' is inconsistent." }
    return $items[0]
}

try {
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
    if ($proposal.checks.noBlockingFindings -ne $true -or $proposal.checks.uniqueReplacement -ne $true) { throw 'Proposal checks are not clean.' }
    $proposedSource = [IO.Path]::GetFullPath([string]$proposal.source.proposedPath)
    $sourceExtension = [IO.Path]::GetExtension($proposedSource).ToLowerInvariant()
    if ($sourceExtension -notin @('.s7dcl', '.scl')) { throw 'Proposal source must be .s7dcl or .scl.' }
    if (-not (Test-Path -LiteralPath $proposedSource -PathType Leaf)) { throw "Proposed source does not exist: $proposedSource" }
    $proposedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $proposedSource).Hash.ToLowerInvariant()
    if ($proposedHash -ne [string]$proposal.source.proposedSha256) { throw 'Proposed source hash does not match proposal.json; it may have been altered.' }

    $blockPath = [string]$proposal.block.path
    $separator = $blockPath.LastIndexOf('/')
    if ($separator -lt 0) { $separator = $blockPath.LastIndexOf('\') }
    $groupPath = if ($separator -gt 0) { $blockPath.Substring(0, $separator) } else { '' }
    $blockName = [string]$proposal.block.name
    if ($separator -ge 0 -and $blockPath.Substring($separator + 1) -ne $blockName) { throw 'Proposal block name and path disagree.' }
    $softwarePath = [string]$proposal.plc
    if ([string]::IsNullOrWhiteSpace($softwarePath)) { throw 'Proposal has no PLC softwarePath.' }

    $projectDirectory = Split-Path -Parent $ProjectFile
    $documentsDirectory = Join-Path $runDirectory 'documents'
    New-Item -ItemType Directory -Path $documentsDirectory -Force | Out-Null
    $stagedDocument = $null
    $stagedSourceRoot = $null
    if ($sourceExtension -eq '.s7dcl') {
        $stagedDocument = Join-Path $documentsDirectory ($blockName + '.s7dcl')
        Copy-Item -LiteralPath $proposedSource -Destination $stagedDocument -Force
    }
    else {
        $stagedSourceRoot = Join-Path $documentsDirectory 'Program blocks'
        if ($groupPath) { $stagedSourceRoot = Join-Path $stagedSourceRoot ($groupPath -replace '/', '\') }
        New-Item -ItemType Directory -Path $stagedSourceRoot -Force | Out-Null
        $stagedDocument = Join-Path $stagedSourceRoot ($blockName + '.scl')
        Copy-Item -LiteralPath $proposedSource -Destination $stagedDocument -Force
    }
    $companionSource = [IO.Path]::ChangeExtension($proposedSource, '.s7res')
    $stagedCompanion = $null
    if ($sourceExtension -eq '.s7dcl' -and (Test-Path -LiteralPath $companionSource -PathType Leaf)) {
        $stagedCompanion = Join-Path $documentsDirectory ($blockName + '.s7res')
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
        stagedDocument = $stagedDocument
        stagedSourceRoot = $stagedSourceRoot
        stagedCompanion = $stagedCompanion
        importMode = if ($sourceExtension -eq '.s7dcl') { 'document' } else { 'external-source' }
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
        $visible = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $_.ProcessName -like 'Siemens.Automation.Portal*' -and $_.MainWindowHandle -ne 0
        })
        $report.sessionGuard.visiblePids = @($visible.Id)
        if ($visible.Count -gt 0) {
            $report.sessionGuard = [ordered]@{ success = $false; status = 'visible-tia-instance'; visiblePids = @($visible.Id); message = 'No se aplica mientras haya una ventana visible de TIA: tia-inspect V20 no expone Attach seguro.' }
            throw 'Apply blocked: a visible TIA Portal instance exists.'
        }
        $report.sessionGuard = [ordered]@{ success = $true; status = 'no-visible-tia'; visiblePids = @() }

        $backupDirectory = Join-Path $runDirectory 'backup-project'
        $report.backup.attempted = $true
        Copy-Item -LiteralPath $projectDirectory -Destination $backupDirectory -Recurse -Force
        $backupFile = Join-Path $backupDirectory ([IO.Path]::GetFileName($ProjectFile))
        if (-not (Test-Path -LiteralPath $backupFile -PathType Leaf)) { throw 'Backup did not contain the project file.' }
        $report.backup = [ordered]@{ attempted = $true; success = $true; path = $backupDirectory; projectFile = $backupFile; projectHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backupFile).Hash }

        $preflightSequence = Invoke-Sequence @(
            @{ name = 'Doctor' },
            @{ name = 'Connect' },
            @{ name = 'GetState' }
        ) 'preflight'
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
            @{ name = 'GetBlocks'; args = @{ softwarePath = $softwarePath; regexName = $blockName } }
        )
        $inspectSequence = Invoke-Sequence $inspectCalls 'inspect-preview'
        $blocksPayload = Read-CallJson (Get-Call $inspectSequence 'GetBlocks') 'GetBlocks'
        $existing = Get-ExactBlock $blocksPayload $blockName $blockPath
        if ($sourceExtension -eq '.s7dcl') {
            $previewCalls = @(
                @{ name = 'Connect' },
                @{ name = 'PreviewImport'; args = @{ softwarePath = $softwarePath; importPath = $documentsDirectory; kind = 'block'; groupPath = $groupPath } }
            )
            $previewSequence = Invoke-Sequence $previewCalls 'preview-import'
            $previewPayload = Read-CallJson (Get-Call $previewSequence 'PreviewImport') 'PreviewImport'
            $report.preview = [ordered]@{ success = $true; kind = 'document'; tool = 'PreviewImport'; block = $blockName; blockPath = $blockPath; groupPath = $groupPath; response = $previewPayload; existing = [ordered]@{ path = [string]$existing.path; type = [string]$existing.typeName; language = [string]$existing.programmingLanguage } }
            $mutationCalls = @{ name = 'ImportFromDocuments'; args = @{ softwarePath = $softwarePath; groupPath = $groupPath; importPath = $documentsDirectory; fileNameWithoutExtension = $blockName; importOption = 'Override' } }
        }
        else {
            $report.preview = [ordered]@{ success = $true; kind = 'external-source'; tool = 'local-validation'; block = $blockName; blockPath = $blockPath; groupPath = $groupPath; response = [ordered]@{ exactBlock = $true; stagedSource = $stagedDocument; overwrite = $true; note = 'ImportSources no expone un PreviewImport equivalente para .scl; la validacion previa es local y el gate real es la compilacion.' }; existing = [ordered]@{ path = [string]$existing.path; type = [string]$existing.typeName; language = [string]$existing.programmingLanguage } }
            $mutationCalls = @{ name = 'ImportSources'; args = @{ softwarePath = $softwarePath; importPath = $documentsDirectory; regexName = ('^' + [regex]::Escape($blockName) + '$'); keepOnError = $false } }
        }

        $mutationSequence = Invoke-Sequence @(
            @{ name = 'Connect' },
            $mutationCalls,
            @{ name = 'GetBlocks'; args = @{ softwarePath = $softwarePath; regexName = $blockName } },
            @{ name = 'CompileSoftware'; args = @{ softwarePath = $softwarePath; password = '' } }
        ) 'import-compile'
        $report.tiaMutation = $true
        $report.readOnly = $false
        $report.import = [ordered]@{ attempted = $true; success = $true; mode = if ($sourceExtension -eq '.s7dcl') { 'document' } else { 'external-source' }; tool = [string]$mutationCalls.name; response = Read-CallJson (Get-Call $mutationSequence ([string]$mutationCalls.name)) ([string]$mutationCalls.name) }
        $compiledBlock = Read-CallJson (Get-Call $mutationSequence 'GetBlocks') 'GetBlocks after import'
        $null = Get-ExactBlock $compiledBlock $blockName $blockPath
        $compilePayload = Read-CallJson (Get-Call $mutationSequence 'CompileSoftware') 'CompileSoftware'
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
    $report.status = if ($report.status -eq 'PREVIEW') { 'BLOCKED' } else { 'FAILED' }
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
