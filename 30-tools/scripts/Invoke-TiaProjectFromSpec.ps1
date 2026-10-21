<##
.SYNOPSIS
    Valida y, opcionalmente, genera el proyecto AgentDemo en una carpeta desechable.

.DESCRIPTION
    El comportamiento por defecto es SOLO DRY-RUN: no conecta a TIA ni crea nada.
    Con -Apply, y solo después de un dry-run limpio, llama a ScaffoldProject con
    dryRun=false. El destino debe no existir y siempre queda un informe JSON.
##>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ProjectDirectory,
    [string]$OutputRoot,
    [string]$SpecPath,
    [string]$HmiScreenPath,
    [string]$MirrorPath,
    [string]$ProjectReadmePath,
    [switch]$Recreate,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
if (-not $OutputRoot) { $OutputRoot = Join-Path $WorkspaceRoot ('70-runs\e2e\agent-demo-scaffold-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
$templatePath = if ($SpecPath) { [IO.Path]::GetFullPath($SpecPath) } else { Join-Path $WorkspaceRoot '50-examples\agent-demo\specs\scaffold.json' }
$defaultSourcePath = Join-Path $WorkspaceRoot '50-examples\agent-demo\sources\FB_AgentDemo.scl'
$exe = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
$callScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolCall.ps1'
$sequenceScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
$invoke = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-TiaMcp.ps1'
$metadataScript = Join-Path $WorkspaceRoot '30-tools\scripts\TiaBlockMetadata.ps1'
$fixtureManifestScript = Join-Path $WorkspaceRoot '30-tools\scripts\New-TiaFixtureManifest.ps1'
foreach ($path in @($templatePath, $exe, $callScript, $sequenceScript, $invoke, $metadataScript, $fixtureManifestScript)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing scaffold input: $path" }
}
. $metadataScript

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$spec = Get-Content -Raw -LiteralPath $templatePath | ConvertFrom-Json
if (-not $SpecPath) {
    # Comportamiento historico: el runner fija el nombre y la fuente del ejemplo.
    $spec.projectName = 'AgentDemo_V20'
    $spec.sclSourceFiles = @($defaultSourcePath)
}
# Las rutas relativas del spec se resuelven contra el workspace.
$spec.sclSourceFiles = @(@($spec.sclSourceFiles) | ForEach-Object {
    if ([string]::IsNullOrWhiteSpace([string]$_)) { throw 'The spec has an empty sclSourceFiles entry.' }
    if ([IO.Path]::IsPathRooted([string]$_)) { [string]$_ } else { Join-Path $WorkspaceRoot ([string]$_) }
})
if (-not $ProjectDirectory) { $ProjectDirectory = [string]$spec.directoryPath }
if ([string]::IsNullOrWhiteSpace($ProjectDirectory)) { $ProjectDirectory = Join-Path $WorkspaceRoot ('90-tmp\agent-demo-scaffold-v20-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$spec.directoryPath = $ProjectDirectory
$ProjectDirectory = [IO.Path]::GetFullPath($ProjectDirectory)
if ($Apply -and (Test-Path -LiteralPath $ProjectDirectory) -and -not $Recreate) { throw "Apply destination already exists: $ProjectDirectory. Use -Recreate to rebuild it from scratch." }
$sourcePath = @($spec.sclSourceFiles)[0]
foreach ($path in @($spec.sclSourceFiles)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing SCL source listed in the spec: $path" }
}
$specJson = $spec | ConvertTo-Json -Depth 30 -Compress
$effectiveSpecPath = Join-Path $OutputRoot 'spec-effective.json'
$spec | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $effectiveSpecPath -Encoding UTF8
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }

function Invoke-ScaffoldCall([bool]$DryRun, [string]$ReportPath) {
    $toolArgs = @{ spec = $specJson; dryRun = $DryRun } | ConvertTo-Json -Depth 30 -Compress
    $callArgs = @(
        '-NoProfile', '-NonInteractive', '-File', $callScript,
        '-ExecutablePath', $exe,
        '-Arguments', '--tia-major-version 20 --profile lite --logging 1',
        '-ToolName', 'ScaffoldProject',
        '-ToolArgumentsJson', $toolArgs,
        '-OutputPath', $ReportPath,
        '-TimeoutSeconds', '900'
    )
    $output = (& $pwsh @callArgs 2>&1 | Out-String).Trim()
    $exitCode = $LASTEXITCODE
    $parsed = if (Test-Path -LiteralPath $ReportPath -PathType Leaf) { Get-Content -Raw -LiteralPath $ReportPath | ConvertFrom-Json } else { $null }
    [pscustomobject]@{ dryRun = $DryRun; exitCode = $exitCode; reportPath = $ReportPath; output = $output; report = $parsed }
}

function Invoke-ScaffoldApplySequence([string]$ReportPath) {
    # Keep creation, close, and disconnect in one tia-create session. A separate
    # call would start a second Openness process and can leave the generated
    # project open while the post-apply inspection starts.
    # The required order is ScaffoldProject -> CloseProject -> Disconnect.
    $calls = @(
        @{ name = 'Bootstrap' },
        @{ name = 'ScaffoldProject'; args = @{ spec = $specJson; dryRun = $false } },
        @{ name = 'CloseProject' },
        @{ name = 'Disconnect' }
    )
    $callsJson = $calls | ConvertTo-Json -Depth 30 -Compress
    $callArgs = @(
        '-NoProfile', '-NonInteractive', '-File', $sequenceScript,
        '-ExecutablePath', $exe,
        '-Arguments', '--tia-major-version 20 --profile lite --logging 1',
        '-CallsJson', $callsJson,
        '-OutputPath', $ReportPath,
        '-TimeoutSeconds', '900'
    )
    $output = (& $pwsh @callArgs 2>&1 | Out-String).Trim()
    $exitCode = $LASTEXITCODE
    $sequence = if (Test-Path -LiteralPath $ReportPath -PathType Leaf) {
        Get-Content -Raw -LiteralPath $ReportPath | ConvertFrom-Json
    } else { $null }
    $scaffoldCall = if ($sequence) { @($sequence.calls | Where-Object name -eq 'ScaffoldProject') | Select-Object -Last 1 } else { $null }
    $closeCall = if ($sequence) { @($sequence.calls | Where-Object name -eq 'CloseProject') | Select-Object -Last 1 } else { $null }
    $disconnectCall = if ($sequence) { @($sequence.calls | Where-Object name -eq 'Disconnect') | Select-Object -Last 1 } else { $null }
    $scaffoldText = if ($scaffoldCall) { [string]$scaffoldCall.text } else { '' }
    $scaffoldPayload = try { $scaffoldText | ConvertFrom-Json } catch { $null }
    $sequenceSucceeded = ($null -ne $sequence -and [bool]$sequence.success -and $null -ne $scaffoldCall -and [bool]$scaffoldCall.success -and $null -ne $closeCall -and [bool]$closeCall.success -and $null -ne $disconnectCall -and [bool]$disconnectCall.success)
    $report = [ordered]@{
        schemaVersion = 1
        success = $sequenceSucceeded
        executable = $exe
        arguments = '--tia-major-version 20 --profile lite --logging 1'
        toolName = 'ScaffoldProject'
        toolResponseIsError = if ($scaffoldCall) { [bool]$scaffoldCall.isError } else { $true }
        text = $scaffoldText
        initialize = if ($sequence) { $sequence.initialize } else { $null }
        response = if ($scaffoldCall) { $scaffoldCall.response } else { $null }
        error = if ($scaffoldCall -and $scaffoldCall.error) { $scaffoldCall.error } elseif (-not $sequenceSucceeded) { 'ScaffoldProject sequence did not complete successfully.' } else { $null }
        sequence = $sequence
        closeProject = $closeCall
        disconnect = $disconnectCall
        payload = $scaffoldPayload
    }
    [pscustomobject]@{
        dryRun = $false
        exitCode = if ($sequenceSucceeded -and $exitCode -eq 0) { 0 } else { 1 }
        reportPath = $ReportPath
        output = $output
        report = [pscustomobject]$report
        sequence = $sequence
    }
}

function Get-SessionGuard([string]$ReportDirectory) {
    $guiTia = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'Siemens.Automation.Portal*' -and $_.MainWindowHandle -ne 0
    })
    if ($guiTia.Count -eq 0) {
        return [ordered]@{ allowed = $true; status = 'no-visible-tia'; visiblePids = @(); probe = $null }
    }

    $probePath = Join-Path $ReportDirectory 'session-guard.json'
    $calls = @(
        @{ name = 'Bootstrap' },
        @{ name = 'Connect' },
        @{ name = 'ListPortalProcessProjects' },
        @{ name = 'GetState' },
        @{ name = 'Disconnect' }
    )
    $callsJson = $calls | ConvertTo-Json -Depth 10 -Compress
    $callArgs = @(
        '-NoProfile', '-NonInteractive', '-File', $sequenceScript,
        '-ExecutablePath', $exe,
        '-Arguments', '--tia-major-version 20 --profile lite',
        '-CallsJson', $callsJson,
        '-OutputPath', $probePath,
        '-TimeoutSeconds', '120'
    )
    $probeOutput = (& $pwsh @callArgs 2>&1 | Out-String).Trim()
    $probe = if (Test-Path -LiteralPath $probePath -PathType Leaf) { Get-Content -Raw -LiteralPath $probePath | ConvertFrom-Json } else { $null }
    $listCall = if ($probe) { @($probe.calls | Where-Object name -eq 'ListPortalProcessProjects') | Select-Object -Last 1 } else { $null }
    $listText = if ($listCall) { [string]$listCall.text } else { '' }
    $listPayload = try { $listText | ConvertFrom-Json } catch { $null }
    $listLines = if ($listPayload -and $listPayload.items) { @($listPayload.items) -join "`n" } else { $listText }
    $unknown = [System.Collections.Generic.List[int]]::new()
    $projectsOpen = [System.Collections.Generic.List[int]]::new()
    foreach ($process in $guiTia) {
        $pidText = [string]$process.Id
        if ($listLines -notmatch "PID=$pidText attach: OK") { $unknown.Add($process.Id); continue }
        if ($listLines -notmatch "PID=$pidText projects=<empty>") { $projectsOpen.Add($process.Id) }
    }
    $allowed = ($probe -and $probe.success -and $unknown.Count -eq 0 -and $projectsOpen.Count -eq 0)
    $status = if ($allowed) { 'visible-tia-without-open-project' } elseif ($projectsOpen.Count -gt 0) { 'visible-tia-project-open' } else { 'visible-tia-project-unknown' }
    [ordered]@{
        allowed = $allowed
        status = $status
        visiblePids = @($guiTia.Id)
        projectPids = @($projectsOpen)
        unknownPids = @($unknown)
        probe = $probe
        probeOutput = $probeOutput
    }
}

function Get-ToolResult([object[]]$Results, [string]$ToolName) {
    return $Results | Where-Object { $_.Tool -eq $ToolName } | Select-Object -Last 1
}

function Read-ToolJson([object]$Result, [string]$Context) {
    if (-not $Result -or $Result.IsError) { throw "$Context failed: $([string]$Result.Text)" }
    try { return ([string]$Result.Text | ConvertFrom-Json) } catch { throw "$Context did not return JSON." }
}

function Assert-Results([object[]]$Results, [string]$Stage) {
    $failed = @($Results | Where-Object { $_.IsError })
    if ($failed.Count -gt 0) { throw "$Stage failed at $($failed[0].Tool): $($failed[0].Text)" }
}

function Invoke-PostApplyVerification([string]$ReportDirectory) {
    $post = [ordered]@{
        success = $false
        projectFile = $null
        scaffoldCompile = $null
        inspection = $null
        export = $null
        blockExport = $null
        standards = $null
    }
    $project = Get-ChildItem -LiteralPath $ProjectDirectory -Recurse -File -Filter '*.ap20' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $project) { throw "Scaffold reported success but no .ap20 was found under $ProjectDirectory." }
    if ($project.DirectoryName.Length -gt 143) {
        throw ("TIA no abre proyectos cuya carpeta supere 143 caracteres: '$($project.DirectoryName)' ($($project.DirectoryName.Length) caracteres). Mueve el proyecto a una ruta mas corta.")
    }

    # tia-inspect V20 only opens a project in isolated mode when the exact
    # project and an unchanged backup are recorded in a fixture manifest. The
    # ScaffoldProject response is produced by tia-create, so prepare a
    # byte-identical disposable inspection copy before starting tia-inspect.
    # TIA NO abre un proyecto cuya ruta supere 143 caracteres: responde
    # "The specified path '...' (N character) is too long. A maximum of 143 characters is
    # allowed", y en modo aislado esa excepcion se come y solo queda un
    # 'Failed to open project' sin detalle. Por eso la copia de inspeccion va a una ruta
    # CORTA bajo %TEMP%, y no dentro del directorio de informes, que en este workspace ya
    # es largo de por si.
    $inspectionFixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('tia-inspect-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $inspectionProjectDirectory = Join-Path $inspectionFixtureRoot 'project'
    $inspectionBackupDirectory = Join-Path $inspectionFixtureRoot 'backup'
    New-Item -ItemType Directory -Path $inspectionProjectDirectory, $inspectionBackupDirectory -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $ProjectDirectory -Force) {
        Copy-Item -LiteralPath $item.FullName -Destination $inspectionProjectDirectory -Recurse -Force
        Copy-Item -LiteralPath $item.FullName -Destination $inspectionBackupDirectory -Recurse -Force
    }
    $inspectionProject = Get-ChildItem -LiteralPath $inspectionProjectDirectory -Recurse -File -Filter '*.ap20' -ErrorAction SilentlyContinue | Select-Object -First 1
    $inspectionBackup = Get-ChildItem -LiteralPath $inspectionBackupDirectory -Recurse -File -Filter '*.ap20' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $inspectionProject -or -not $inspectionBackup) { throw 'Could not create matching isolated scaffold project and backup copies.' }
    & $fixtureManifestScript -FixtureRoot $inspectionFixtureRoot -ProjectPath $inspectionProject.FullName -BackupProjectPath $inspectionBackup.FullName -SourceProjectPath $sourcePath -ConfirmedDisposable | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $inspectionFixtureRoot '.tia-agent-fixture.json') -PathType Leaf)) {
        throw 'Could not create the isolated scaffold fixture manifest.'
    }
    $inspectionProjectFile = $inspectionProject.FullName

    function Invoke-IsolatedInspect([array]$Calls) {
        return & $invoke -TiaMajor 20 -Isolated -FixtureRoot $inspectionFixtureRoot -TimeoutSeconds 900 -ContinueOnError -Calls $Calls
    }
    function Invoke-ProjectInspect([array]$Calls) {
        $callsJson = $Calls | ConvertTo-Json -Depth 20 -Compress
        $reportPath = Join-Path $ReportDirectory 'project-inspect.json'
        $callArgs = @(
            '-NoProfile', '-NonInteractive', '-File', $sequenceScript,
            '-ExecutablePath', $exe,
            '-Arguments', '--tia-major-version 20 --profile full',
            '-CallsJson', $callsJson,
            '-OutputPath', $reportPath,
            '-TimeoutSeconds', '900'
        )
        $null = & $pwsh @callArgs 2>&1
        $sequence = if (Test-Path -LiteralPath $reportPath -PathType Leaf) { Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json } else { $null }
        if (-not $sequence) { throw 'The project inspection sequence did not produce a report.' }
        return @($sequence.calls | ForEach-Object {
            [pscustomobject]@{ Tool = $_.name; Text = $_.text; IsError = (-not $_.success) }
        })
    }
    $post.projectFile = $project.FullName
    $scaffoldResponse = Read-ToolJson $applyResult.report 'ScaffoldProject apply response'
    $post.scaffoldCompile = [ordered]@{
        state = $scaffoldResponse.compileState
        errorCount = $scaffoldResponse.compileErrorCount
        warningCount = $scaffoldResponse.compileWarningCount
        success = ($scaffoldResponse.compileErrorCount -eq 0 -and $scaffoldResponse.compileWarningCount -eq 0)
    }
    if (-not $post.scaffoldCompile.success) { throw "Scaffold compile gate was not clean: $($post.scaffoldCompile.errorCount) error(s), $($post.scaffoldCompile.warningCount) warning(s)." }

    $exportDirectory = Join-Path $ReportDirectory 'export'
    $targetBlockName = [IO.Path]::GetFileNameWithoutExtension($sourcePath)
    $blockExportDirectory = Join-Path $ReportDirectory 'export-blocks'
    New-Item -ItemType Directory -Path $blockExportDirectory -Force | Out-Null
    # La inspeccion y el export se hacen con tia-create en modo NO aislado, sobre la COPIA
    # desechable del proyecto, nunca sobre el original.
    #
    # Por que no tia-inspect --isolated: el modo aislado abre el proyecto en una instancia de
    # Openness privada sin interfaz, y ahi el limite de 143 caracteres de TIA se come la
    # excepcion y solo queda 'Failed to open project' sin detalle. Con tia-create el error
    # llega completo. Las llamadas de aqui (arbol, resumen, bloques, export) no mutan nada, y
    # el session guard de arriba ya ha comprobado que no hay ninguna TIA visible con un
    # proyecto abierto.
    #
    # OpenProject y todas las lecturas y exports deben ir en la MISMA sesion MCP: un proceso
    # nuevo arranca sin proyecto, asi que separar las llamadas haria fallar un GetProjectTree
    # posterior aunque OpenProject hubiera funcionado en otro proceso.
    $inspectionResults = Invoke-ProjectInspect @(
        @{ name = 'Connect' },
        @{ name = 'OpenProject'; args = @{ path = $inspectionProjectFile } },
        @{ name = 'GetState' },
        @{ name = 'GetProjectTree' },
        @{ name = 'GetSoftwareTree'; args = @{ softwarePath = [string]$spec.plcName } },
        @{ name = 'GetSoftwareInfo'; args = @{ softwarePath = [string]$spec.plcName } },
        @{ name = 'GetBlocks'; args = @{ softwarePath = [string]$spec.plcName; regexName = '.*' } },
        @{ name = 'ExportBlocks'; args = @{ softwarePath = [string]$spec.plcName; exportPath = $exportDirectory; regexName = '.*'; preservePath = $true } },
        @{ name = 'ExportBlock'; args = @{ softwarePath = [string]$spec.plcName; blockPath = $targetBlockName; exportPath = $blockExportDirectory; preservePath = $false } },
        @{ name = 'CloseProject' },
        @{ name = 'Disconnect' }
    )
    Assert-Results $inspectionResults 'Post-apply inspection/export'
    $state = Read-ToolJson (Get-ToolResult $inspectionResults 'GetState') 'Post-apply GetState'
    $expectedName = [IO.Path]::GetFileNameWithoutExtension($project.Name)
    if ([string]$state.project -ne $expectedName -and [string]$state.project -ne [IO.Path]::GetFileNameWithoutExtension($spec.projectName)) {
        throw "Post-apply inspection found a different open project: $($state.project)."
    }
    $tree = Read-ToolJson (Get-ToolResult $inspectionResults 'GetProjectTree') 'GetProjectTree'
    $softwareTree = Read-ToolJson (Get-ToolResult $inspectionResults 'GetSoftwareTree') 'GetSoftwareTree'
    if ([string]$softwareTree.tree -notmatch [regex]::Escape($targetBlockName)) { throw "GetSoftwareTree did not confirm the scaffold block path: $targetBlockName" }
    $summary = Read-ToolJson (Get-ToolResult $inspectionResults 'GetSoftwareInfo') 'GetSoftwareInfo'
    $blocksPayload = Read-ToolJson (Get-ToolResult $inspectionResults 'GetBlocks') 'GetBlocks'
    $export = Read-ToolJson (Get-ToolResult $inspectionResults 'ExportBlocks') 'ExportBlocks'
    $blockExport = Read-ToolJson (Get-ToolResult $inspectionResults 'ExportBlock') 'ExportBlock'
    $blockXmlFiles = @(Get-ChildItem -LiteralPath $blockExportDirectory -Recurse -File -Filter '*.xml' -ErrorAction SilentlyContinue)
    $blocks = @($blocksPayload.items | ForEach-Object {
        $block = $_
        $matchingXml = @($blockXmlFiles | Where-Object { $_.BaseName -eq [string]$block.name })
        $commentMetadata = if ($matchingXml.Count -eq 1) {
            Get-TiaBlockCommentMetadata -XmlPath $matchingXml[0].FullName
        } else {
            [pscustomobject]@{ status = 'unverified'; hasComment = $null; encodingStatus = 'unknown' }
        }
        [ordered]@{
            path = [string]$block.path
            name = [string]$block.name
            typeName = [string]$block.typeName
            programmingLanguage = [string]$block.programmingLanguage
            isConsistent = [bool]$block.isConsistent
            isKnowHowProtected = [bool]$block.isKnowHowProtected
            comment = $commentMetadata.hasComment
            commentEvidence = if ($commentMetadata.status -eq 'unverified') { 'not-collected' } else { 'block-export-xml' }
            commentEncodingStatus = $commentMetadata.encodingStatus
        }
    })
    $inventoryPath = Join-Path $ReportDirectory 'inventory.json'
    [ordered]@{
        schemaVersion = 1; readOnly = $true; generatedAt = [DateTimeOffset]::Now.ToString('o'); projectPath = $project.FullName
        projectTree = [string]$tree.tree
        plcs = @([ordered]@{ name = [string]$spec.plcName; softwarePath = [string]$spec.plcName; summary = $summary; softwareTree = [string]$softwareTree.tree; blocks = $blocks; defaultTagCount = 0 })
        blocks = $blocks; defaultTagCount = 0
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8
    $standardsPath = Join-Path $ReportDirectory 'standards.json'
    $standardsOutput = (& $pwsh -NoProfile -NonInteractive -File (Join-Path $WorkspaceRoot '30-tools\scripts\Check-TiaStandards.ps1') -InventoryPath $inventoryPath -ExportPath $exportDirectory -OutputPath $standardsPath 2>&1 | Out-String).Trim()
    $standardsExit = $LASTEXITCODE
    $softwarePathInTree = ([string]$tree.tree -match [regex]::Escape([string]$spec.plcName))
    $post.inspection = [ordered]@{ success = ($blocks.Count -gt 0 -and $softwarePathInTree); blocks = $blocks.Count; tree = $tree.tree }
    $post.blockExport = [ordered]@{ success = ($null -ne $blockExport -and $blockXmlFiles.Count -gt 0); path = $blockExportDirectory; files = @($blockXmlFiles.FullName); response = $blockExport }
    $post.export = [ordered]@{ success = ($standardsExit -eq 0 -and $null -ne $export -and $post.blockExport.success); path = $exportDirectory; response = $export }
    $post.standards = [ordered]@{ success = ($standardsExit -eq 0); path = $standardsPath; output = $standardsOutput }
    $post.success = ($post.inspection.success -and $post.export.success -and $post.standards.success)
    if (-not $post.success) { throw "Post-apply verification failed; see $ReportDirectory." }
    return $post
}

function Invoke-DeliverySteps([string]$Project, [object]$Spec, [string]$ReportDirectory) {
    # Cierra el ciclo de entrega: pantalla HMI, export al src/ del PROYECTO, informe real
    # del compilador en ops/, y copia al espejo versionado. Es lo que convierte "el proyecto
    # existe" en "el proyecto esta entregado".
    $delivery = [ordered]@{
        success = $false
        hmi = $null
        src = $null
        ops = $null
        mirror = $null
        readme = $null
    }
    $projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Project))
    $srcPath = Join-Path $projectRoot 'src'
    $opsPath = Join-Path $projectRoot 'ops'
    if (Test-Path -LiteralPath $srcPath) { Remove-Item -LiteralPath $srcPath -Recurse -Force }
    New-Item -ItemType Directory -Path $srcPath, $opsPath, (Join-Path $srcPath 'Program blocks'), (Join-Path $srcPath 'tags'), (Join-Path $srcPath 'sources') -Force | Out-Null

    # 1. Pantalla HMI y sus bindings.
    if ($HmiScreenPath) {
        $hmiRunner = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-TiaHmiScreenFromJson.ps1'
        $hmiReport = Join-Path $ReportDirectory 'hmi-screen.json'
        $hmiOutput = (& $pwsh -NoProfile -NonInteractive -File $hmiRunner -ScreenJsonPath $HmiScreenPath -ProjectFile $Project 2>&1 | Out-String).Trim()
        $hmiExit = $LASTEXITCODE
        $delivery.hmi = [ordered]@{ success = ($hmiExit -eq 0); screenJsonPath = $HmiScreenPath; output = $hmiOutput }
        if ($hmiExit -ne 0) { return $delivery }
    }

    # 2. Compilacion real con informe, y export al src/ del proyecto.
    $compileCalls = @(
        @{ name = 'Connect'; args = @{} },
        @{ name = 'OpenProject'; args = @{ path = $Project; closeForeignProject = $false } },
        @{ name = 'CompileSoftware'; args = @{ softwarePath = [string]$Spec.plcName; password = '' } },
        @{ name = 'ExportBlocks'; args = @{ softwarePath = [string]$Spec.plcName; exportPath = (Join-Path $srcPath 'Program blocks'); regexName = '.*'; preservePath = $false } }
    )
    # La tabla de tags del spec, exportada a XML: el export textual del proyecto
    # tiene que incluir donde estan las senales, no solo los bloques.
    foreach ($table in @($Spec.tagTable)) {
        if ([string]::IsNullOrWhiteSpace([string]$table.tableName)) { continue }
        $compileCalls += @{ name = 'ExportPlcTagTable'; args = @{ softwarePath = [string]$Spec.plcName; tagTableName = [string]$table.tableName; exportPath = (Join-Path $srcPath ('tags\' + [string]$table.tableName + '.xml')) } }
    }
    $compileCalls += @(
        @{ name = 'SaveProject'; args = @{} },
        @{ name = 'CloseProject'; args = @{} },
        @{ name = 'Disconnect'; args = @{} }
    )
    $compileReport = Join-Path $ReportDirectory 'compile.json'
    $compileArgs = @(
        '-NoProfile', '-NonInteractive', '-File', $sequenceScript,
        '-ExecutablePath', $exe,
        '-Arguments', '--tia-major-version 20 --profile full',
        '-CallsJson', ($compileCalls | ConvertTo-Json -Depth 20 -Compress),
        '-OutputPath', $compileReport,
        '-TimeoutSeconds', '1200'
    )
    $null = & $pwsh @compileArgs 2>&1
    $compileSequence = if (Test-Path -LiteralPath $compileReport -PathType Leaf) { Get-Content -Raw -LiteralPath $compileReport | ConvertFrom-Json } else { $null }
    if (-not $compileSequence) { throw 'The compile/export sequence did not produce a report.' }
    $compileCall = @($compileSequence.calls) | Where-Object name -eq 'CompileSoftware' | Select-Object -First 1
    $compilePayload = if ($compileCall) { $compileCall.text | ConvertFrom-Json } else { $null }
    $compileOk = ($compileCall -and [bool]$compileCall.success -and [string]$compilePayload.state -eq 'Success' -and [int]$compilePayload.errorCount -eq 0 -and [int]$compilePayload.warningCount -eq 0)
    [ordered]@{
        schemaVersion = 1
        generatedAt = [DateTimeOffset]::Now.ToString('o')
        tool = 'CompileSoftware'
        project = [string]$Spec.projectName
        softwarePath = [string]$Spec.plcName
        state = [string]$compilePayload.state
        errorCount = [int]$compilePayload.errorCount
        warningCount = [int]$compilePayload.warningCount
        messages = @($compilePayload.messages)
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $opsPath 'compile-report.json') -Encoding UTF8
    @("CompileSoftware $([string]$Spec.projectName) / $([string]$Spec.plcName)", "state=$([string]$compilePayload.state) errors=$([int]$compilePayload.errorCount) warnings=$([int]$compilePayload.warningCount)", "generado: $([DateTimeOffset]::Now.ToString('o'))", "") + @($compilePayload.messages) | Set-Content -LiteralPath (Join-Path $opsPath 'compile-report.txt') -Encoding UTF8
    $delivery.ops = [ordered]@{ success = $compileOk; state = [string]$compilePayload.state; errorCount = [int]$compilePayload.errorCount; warningCount = [int]$compilePayload.warningCount }

    # 3. Inventario y estandar, con el codigo de salida que PA-1 exige.
    $inventory = Get-ChildItem -LiteralPath $ReportDirectory -Filter 'inventory.json' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $standardsPath = Join-Path $opsPath 'standards.json'
    if ($inventory) {
        $standardsOutput = (& $pwsh -NoProfile -NonInteractive -File (Join-Path $WorkspaceRoot '30-tools\scripts\Check-TiaStandards.ps1') -InventoryPath $inventory.FullName -ExportPath $srcPath -OutputPath $standardsPath 2>&1 | Out-String).Trim()
        $standardsExit = $LASTEXITCODE
        Copy-Item -LiteralPath $inventory.FullName -Destination (Join-Path $srcPath 'inventory.json') -Force
        $delivery.src = [ordered]@{ success = ($standardsExit -eq 0); standardsExitCode = $standardsExit; standards = $standardsOutput; path = $srcPath }
    } else {
        $delivery.src = [ordered]@{ success = $false; error = 'No inventory to run the standards check against.' }
    }

    # 3b. Las fuentes SCL que se importaron y la definicion de la pantalla tambien
    #     son parte del export textual: sin ellas, el src/ no cuenta que hizo el agente.
    foreach ($source in @($Spec.sclSourceFiles)) {
        $sourcePath = [string]$source
        if (-not [string]::IsNullOrWhiteSpace($sourcePath) -and (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $srcPath 'sources') -Force
        }
    }
    if ($HmiScreenPath -and (Test-Path -LiteralPath $HmiScreenPath -PathType Leaf)) {
        Copy-Item -LiteralPath $HmiScreenPath -Destination (Join-Path $srcPath (Split-Path -Leaf $HmiScreenPath)) -Force
    }

    # 4. README del proyecto y espejo versionado.
    if ($ProjectReadmePath -and (Test-Path -LiteralPath $ProjectReadmePath -PathType Leaf)) {
        Copy-Item -LiteralPath $ProjectReadmePath -Destination (Join-Path $projectRoot 'README.md') -Force
        $delivery.readme = [ordered]@{ success = $true; path = (Join-Path $projectRoot 'README.md') }
    }
    if ($MirrorPath) {
        $MirrorPath = [IO.Path]::GetFullPath($MirrorPath)
        if (Test-Path -LiteralPath (Join-Path $MirrorPath 'src')) { Remove-Item -LiteralPath (Join-Path $MirrorPath 'src') -Recurse -Force }
        New-Item -ItemType Directory -Path (Join-Path $MirrorPath 'src') -Force | Out-Null
        Copy-Item -Path (Join-Path $srcPath '*') -Destination (Join-Path $MirrorPath 'src') -Recurse -Force
        if ($delivery.readme.success) { Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination (Join-Path $MirrorPath 'README.md') -Force }
        $delivery.mirror = [ordered]@{ success = $true; path = $MirrorPath }
    }

    $delivery.success = (
        ($null -eq $delivery.hmi -or $delivery.hmi.success) -and
        $delivery.ops.success -and $delivery.src.success
    )
    return $delivery
}

$dryRunResult = Invoke-ScaffoldCall $true (Join-Path $OutputRoot 'dry-run.json')
if ($dryRunResult.exitCode -ne 0 -or -not $dryRunResult.report.success) {
    $final = [ordered]@{ schemaVersion = 1; success = $false; applied = $false; effectiveSpec = $effectiveSpecPath; dryRun = $dryRunResult }
}
elseif (-not $Apply) {
    $final = [ordered]@{ schemaVersion = 1; success = $true; applied = $false; effectiveSpec = $effectiveSpecPath; dryRun = $dryRunResult; message = 'Dry-run passed; use -Apply to create the disposable project.' }
}
else {
    $sessionGuard = Get-SessionGuard $OutputRoot
    if (-not $sessionGuard.allowed) {
        $final = [ordered]@{ schemaVersion = 1; success = $false; applied = $false; effectiveSpec = $effectiveSpecPath; dryRun = $dryRunResult; sessionGuard = $sessionGuard; message = 'Apply blocked: a visible TIA project could not be proven absent.' }
    } else {
          # El proyecto es desechable: para poder repetir la cadena, se borra el anterior.
          if ((Test-Path -LiteralPath $ProjectDirectory) -and $Recreate) {
              Remove-Item -LiteralPath $ProjectDirectory -Recurse -Force
              Write-Output "Previous project removed for a clean run: $ProjectDirectory"
          }
          $applyResult = Invoke-ScaffoldApplySequence (Join-Path $OutputRoot 'apply.json')
          $postApply = $null
          $delivery = $null
          if ($applyResult.exitCode -eq 0 -and $applyResult.report.success) {
              $postApply = Invoke-PostApplyVerification $OutputRoot
              if ($postApply.success) {
                  $delivery = Invoke-DeliverySteps $postApply.projectFile $spec $OutputRoot
              }
          }
          $final = [ordered]@{
              schemaVersion = 1
              success = ($applyResult.exitCode -eq 0 -and $applyResult.report.success -and $null -ne $postApply -and $postApply.success -and $null -ne $delivery -and $delivery.success)
              applied = $true
              effectiveSpec = $effectiveSpecPath
              dryRun = $dryRunResult
              sessionGuard = $sessionGuard
              apply = $applyResult
              postApply = $postApply
              delivery = $delivery
              projectDirectory = $ProjectDirectory
          }
    }
}
$finalPath = Join-Path $OutputRoot 'scaffold-report.json'
$final | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $finalPath -Encoding UTF8
Write-Output ($final | ConvertTo-Json -Depth 10)
Write-Host "Evidence: $finalPath" -ForegroundColor Green
if (-not $final.success) { exit 1 }
exit 0
