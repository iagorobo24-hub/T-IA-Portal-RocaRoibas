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
if ($Apply) {
    $guiTia = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'Siemens.Automation.Portal*' -and $_.MainWindowHandle -ne 0
    })
    if ($guiTia.Count -gt 0) {
        throw "Apply blocked: TIA Portal has a visible user instance open (PID(s): $($guiTia.Id -join ', ')). Close it or use the target project through Attach; this new-project runner will not replace it."
    }
}

$templatePath = Join-Path $WorkspaceRoot '50-examples\agent-demo\specs\scaffold.json'
$sourcePath = Join-Path $WorkspaceRoot '50-examples\agent-demo\sources\FB_AgentDemo.scl'
$exe = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
$callScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolCall.ps1'
foreach ($path in @($templatePath, $sourcePath, $exe, $callScript)) {
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
    $inspectionResults = & $invoke -TiaMajor 20 -TimeoutSeconds 900 -ContinueOnError -Calls @(
        @{ name = 'Connect' },
        @{ name = 'GetProjectTree' },
        @{ name = 'GetSoftwareTree'; args = @{ softwarePath = [string]$spec.plcName; sections = 'blocks,tags,types,sources' } },
        @{ name = 'GetPlcSummary'; args = @{ softwarePath = [string]$spec.plcName } },
        @{ name = 'GetBlocks'; args = @{ softwarePath = [string]$spec.plcName; regexName = 'AgentDemo' } },
        @{ name = 'ExportPlcAsSourceTree'; args = @{ softwarePath = [string]$spec.plcName; exportPath = $exportDirectory } },
        @{ name = 'CloseProject' },
        @{ name = 'Disconnect' }
    )
    Assert-Results $inspectionResults 'Post-apply inspection/export'
    $tree = Read-ToolJson (Get-ToolResult $inspectionResults 'GetProjectTree') 'GetProjectTree'
    $softwareTree = Read-ToolJson (Get-ToolResult $inspectionResults 'GetSoftwareTree') 'GetSoftwareTree'
    $summary = Read-ToolJson (Get-ToolResult $inspectionResults 'GetPlcSummary') 'GetPlcSummary'
    $blocksPayload = Read-ToolJson (Get-ToolResult $inspectionResults 'GetBlocks') 'GetBlocks'
    $export = Read-ToolJson (Get-ToolResult $inspectionResults 'ExportPlcAsSourceTree') 'ExportPlcAsSourceTree'
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
    $post.export = [ordered]@{ success = ($standardsExit -eq 0 -and $null -ne $export); path = $exportDirectory; response = $export }
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
    $applyResult = Invoke-ScaffoldCall $false (Join-Path $OutputRoot 'apply.json')
    $postApply = $null
    if ($applyResult.exitCode -eq 0 -and $applyResult.report.success) {
        $postApply = Invoke-PostApplyVerification $OutputRoot
    }
    $final = [ordered]@{ schemaVersion = 1; success = ($applyResult.exitCode -eq 0 -and $applyResult.report.success -and $null -ne $postApply -and $postApply.success); applied = $true; effectiveSpec = $effectiveSpecPath; dryRun = $dryRunResult; apply = $applyResult; postApply = $postApply; projectDirectory = $ProjectDirectory }
}
$finalPath = Join-Path $OutputRoot 'scaffold-report.json'
$final | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $finalPath -Encoding UTF8
Write-Output ($final | ConvertTo-Json -Depth 10)
Write-Host "Evidence: $finalPath" -ForegroundColor Green
if (-not $final.success) { exit 1 }
exit 0
