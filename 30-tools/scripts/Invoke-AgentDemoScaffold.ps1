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
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
if (-not $OutputRoot) { $OutputRoot = Join-Path $WorkspaceRoot ('70-runs\e2e\agent-demo-scaffold-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (-not $ProjectDirectory) { $ProjectDirectory = Join-Path $WorkspaceRoot ('90-tmp\agent-demo-scaffold-v20-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$ProjectDirectory = [IO.Path]::GetFullPath($ProjectDirectory)
if ($Apply -and (Test-Path -LiteralPath $ProjectDirectory)) { throw "Apply destination already exists: $ProjectDirectory" }

$templatePath = Join-Path $WorkspaceRoot '50-examples\agent-demo\specs\scaffold.json'
$sourcePath = Join-Path $WorkspaceRoot '50-examples\agent-demo\sources\FB_AgentDemo.scl'
$exe = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
$callScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolCall.ps1'
$sequenceScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
$invoke = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-TiaMcp.ps1'
foreach ($path in @($templatePath, $sourcePath, $exe, $callScript, $sequenceScript, $invoke)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing scaffold input: $path" }
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$spec = Get-Content -Raw -LiteralPath $templatePath | ConvertFrom-Json
$spec.projectName = 'AgentDemo_V20'
$spec.directoryPath = $ProjectDirectory
$spec.sclSourceFiles = @($sourcePath)
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
    $post.projectFile = $project.FullName
    $scaffoldResponse = Read-ToolJson $applyResult.report 'ScaffoldProject apply response'
    $post.scaffoldCompile = [ordered]@{
        state = $scaffoldResponse.compileState
        errorCount = $scaffoldResponse.compileErrorCount
        warningCount = $scaffoldResponse.compileWarningCount
        success = ($scaffoldResponse.compileErrorCount -eq 0 -and $scaffoldResponse.compileWarningCount -eq 0)
    }
    if (-not $post.scaffoldCompile.success) { throw "Scaffold compile gate was not clean: $($post.scaffoldCompile.errorCount) error(s), $($post.scaffoldCompile.warningCount) warning(s)." }

    $inspect = & $invoke -TiaMajor 20 -TimeoutSeconds 900 -ContinueOnError -Calls @(
        @{ name = 'Connect' },
        @{ name = 'GetState' }
    )
    Assert-Results $inspect 'Post-apply preflight'
    $state = Read-ToolJson (Get-ToolResult $inspect 'GetState') 'Post-apply GetState'
    $expectedName = [IO.Path]::GetFileNameWithoutExtension($project.Name)
    if ([string]$state.project -eq '-') {
        $openResults = & $invoke -TiaMajor 20 -TimeoutSeconds 900 -ContinueOnError -Calls @(
            @{ name = 'Connect' },
            @{ name = 'OpenProject'; args = @{ path = $project.FullName } }
        )
        Assert-Results $openResults 'Post-apply OpenProject'
    }
    elseif ([string]$state.project -ne $expectedName -and [string]$state.project -ne [IO.Path]::GetFileNameWithoutExtension($spec.projectName)) {
        throw "Post-apply inspection found a different open project: $($state.project)."
    }

    $exportDirectory = Join-Path $ReportDirectory 'export'
    $targetBlockName = [IO.Path]::GetFileNameWithoutExtension($sourcePath)
    $blockExportDirectory = Join-Path $ReportDirectory 'export-blocks'
    New-Item -ItemType Directory -Path $blockExportDirectory -Force | Out-Null
    $inspectionResults = & $invoke -TiaMajor 20 -TimeoutSeconds 900 -ContinueOnError -Calls @(
        @{ name = 'Connect' },
        @{ name = 'GetProjectTree' },
        @{ name = 'GetSoftwareTree'; args = @{ softwarePath = [string]$spec.plcName; sections = 'blocks,tags,types,sources' } },
        @{ name = 'GetPlcSummary'; args = @{ softwarePath = [string]$spec.plcName } },
        @{ name = 'GetBlocks'; args = @{ softwarePath = [string]$spec.plcName; regexName = 'AgentDemo' } },
        @{ name = 'ExportPlcAsSourceTree'; args = @{ softwarePath = [string]$spec.plcName; exportPath = $exportDirectory } },
        @{ name = 'ExportBlock'; args = @{ softwarePath = [string]$spec.plcName; blockPath = $targetBlockName; exportPath = $blockExportDirectory; preservePath = $false } },
        @{ name = 'CloseProject' },
        @{ name = 'Disconnect' }
    )
    Assert-Results $inspectionResults 'Post-apply inspection/export'
    $tree = Read-ToolJson (Get-ToolResult $inspectionResults 'GetProjectTree') 'GetProjectTree'
    $softwareTree = Read-ToolJson (Get-ToolResult $inspectionResults 'GetSoftwareTree') 'GetSoftwareTree'
    if ([string]$softwareTree.tree -notmatch [regex]::Escape($targetBlockName)) { throw "GetSoftwareTree did not confirm the scaffold block path: $targetBlockName" }
    $summary = Read-ToolJson (Get-ToolResult $inspectionResults 'GetPlcSummary') 'GetPlcSummary'
    $blocksPayload = Read-ToolJson (Get-ToolResult $inspectionResults 'GetBlocks') 'GetBlocks'
    $export = Read-ToolJson (Get-ToolResult $inspectionResults 'ExportPlcAsSourceTree') 'ExportPlcAsSourceTree'
    $blockExport = Read-ToolJson (Get-ToolResult $inspectionResults 'ExportBlock') 'ExportBlock'
    $blockXmlFiles = @(Get-ChildItem -LiteralPath $blockExportDirectory -Recurse -File -Filter '*.xml' -ErrorAction SilentlyContinue)
    $blocks = @($blocksPayload.items | ForEach-Object {
        [ordered]@{ path = [string]$_.path; name = [string]$_.name; typeName = [string]$_.typeName; programmingLanguage = [string]$_.programmingLanguage; isConsistent = [bool]$_.isConsistent; isKnowHowProtected = [bool]$_.isKnowHowProtected; comment = [bool](-not [string]::IsNullOrWhiteSpace([string]$_.headerName)) }
    })
    $inventoryPath = Join-Path $ReportDirectory 'inventory.json'
    [ordered]@{
        schemaVersion = 1; readOnly = $true; generatedAt = [DateTimeOffset]::Now.ToString('o'); projectPath = $project.FullName
        projectTree = [string]$tree.tree
        plcs = @([ordered]@{ name = [string]$summary.name; softwarePath = [string]$spec.plcName; summary = $summary; softwareTree = [string]$softwareTree.tree; blocks = $blocks; defaultTagCount = 0 })
        blocks = $blocks; defaultTagCount = 0
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8
    $standardsPath = Join-Path $ReportDirectory 'standards.json'
    $standardsOutput = (& $pwsh -NoProfile -NonInteractive -File (Join-Path $WorkspaceRoot '30-tools\scripts\Check-TiaStandards.ps1') -InventoryPath $inventoryPath -ExportPath $exportDirectory -OutputPath $standardsPath 2>&1 | Out-String).Trim()
    $standardsExit = $LASTEXITCODE
    $post.inspection = [ordered]@{ success = ($blocks.Count -gt 0 -and [string]$summary.name -eq [string]$spec.plcName); blocks = $blocks.Count; tree = $tree.tree }
    $post.blockExport = [ordered]@{ success = ($null -ne $blockExport -and $blockXmlFiles.Count -gt 0); path = $blockExportDirectory; files = @($blockXmlFiles.FullName); response = $blockExport }
    $post.export = [ordered]@{ success = ($standardsExit -eq 0 -and $null -ne $export -and $post.blockExport.success); path = $exportDirectory; response = $export }
    $post.standards = [ordered]@{ success = ($standardsExit -eq 0); path = $standardsPath; output = $standardsOutput }
    $post.success = ($post.inspection.success -and $post.export.success -and $post.standards.success)
    if (-not $post.success) { throw "Post-apply verification failed; see $ReportDirectory." }
    return $post
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
        $applyResult = Invoke-ScaffoldCall $false (Join-Path $OutputRoot 'apply.json')
        $postApply = $null
        if ($applyResult.exitCode -eq 0 -and $applyResult.report.success) {
            $postApply = Invoke-PostApplyVerification $OutputRoot
        }
        $final = [ordered]@{ schemaVersion = 1; success = ($applyResult.exitCode -eq 0 -and $applyResult.report.success -and $null -ne $postApply -and $postApply.success); applied = $true; effectiveSpec = $effectiveSpecPath; dryRun = $dryRunResult; sessionGuard = $sessionGuard; apply = $applyResult; postApply = $postApply; projectDirectory = $ProjectDirectory }
    }
}
$finalPath = Join-Path $OutputRoot 'scaffold-report.json'
$final | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $finalPath -Encoding UTF8
Write-Output ($final | ConvertTo-Json -Depth 10)
Write-Host "Evidence: $finalPath" -ForegroundColor Green
if (-not $final.success) { exit 1 }
exit 0
