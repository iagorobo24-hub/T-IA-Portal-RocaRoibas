<##
.SYNOPSIS
    Punto de entrada para workflows semanticos seguros de TIA-Claude.

.DESCRIPTION
    Coordina operaciones sobre snapshots sin mezclar analisis, propuesta y aplicacion.
    `analyze` consume un inventario MCP readOnly y fuentes exportadas. `propose` consume un
    dossier y produce una propuesta SCL. `apply` delega en el runner de escritura con preview
    local por defecto y mutacion solo con perfil write, -Apply y confirmacion de perfil.
##>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('analyze', 'propose', 'apply')]
    [string]$Workflow,

    [string]$InventoryPath,
    [string]$SourceRoot,
    [string]$AnalysisPath,
    [string]$ProposalPath,
    [string]$ProjectFile,
    [string]$BlockName,
    [string]$FindText,
    [string]$ReplaceText,
    [string]$OutputDirectory,
    [ValidateSet('read', 'write', 'create', 'full')]
    [string]$Profile = 'read',
    [string]$Objective = '',
    [switch]$Force,
    [switch]$Apply,
    [switch]$AcknowledgeWriteProfile,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

if ($Help) {
    Write-Output @'
Invoke-TiaWorkflow.ps1: workflows semanticos de TIA-Claude.
  analyze: inventory MCP readOnly + fuentes -> analysis.json/md
  propose: analysis + reemplazo SCL -> proposal.json/copia/diff
  apply: proposal.json + .ap20 -> preview o aplicacion con gates completos
'@
    exit 0
}

if ($Workflow -ne 'apply' -and $Profile -ne 'read') { throw "Workflow '$Workflow' only accepts profile 'read'." }
if ($Workflow -eq 'apply' -and $Apply) {
    if ($Profile -ne 'write') { throw 'Applying a workflow requires -Profile write.' }
    if (-not $AcknowledgeWriteProfile) { throw 'Applying a workflow requires -AcknowledgeWriteProfile.' }
}

if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root ('70-runs\workflows\' + $Workflow + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory -PathType Leaf) { throw "OutputDirectory is a file: $OutputDirectory" }
if ((Test-Path -LiteralPath $OutputDirectory -PathType Container) -and @(Get-ChildItem -LiteralPath $OutputDirectory -Force).Count -gt 0) {
    if (-not $Force) { throw "OutputDirectory is not empty; use -Force only for this exact workflow directory: $OutputDirectory" }
    Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$analysisScript = Join-Path $PSScriptRoot 'Invoke-TiaProjectAnalysis.ps1'
$proposalScript = Join-Path $PSScriptRoot 'New-TiaSclProposal.ps1'
$applyScript = Join-Path $PSScriptRoot 'Invoke-TiaSclProposalApply.ps1'
$artifacts = [ordered]@{}
$workflowReadOnly = $true
$workflowMutation = $false
$leaseRequired = $false
$leaseAcquired = $false

if ($Workflow -eq 'analyze') {
    if (-not $InventoryPath -or -not $SourceRoot) { throw 'Analyze requires InventoryPath and SourceRoot.' }
    $analysisPathOut = Join-Path $OutputDirectory 'analysis.json'
    & $analysisScript -InventoryPath $InventoryPath -SourceRoot $SourceRoot -OutputPath $analysisPathOut -Objective $Objective
    if ($LASTEXITCODE -ne 0) { throw "Analyze workflow failed with exit code $LASTEXITCODE." }
    $artifacts.analysis = $analysisPathOut
    $artifacts.markdown = [IO.Path]::ChangeExtension($analysisPathOut, '.md')
}
elseif ($Workflow -eq 'propose') {
    if (-not $AnalysisPath -or -not $BlockName -or $null -eq $FindText -or $null -eq $ReplaceText) {
        throw 'Propose requires AnalysisPath, BlockName, FindText and ReplaceText.'
    }
    & $proposalScript -AnalysisPath $AnalysisPath -BlockName $BlockName -FindText $FindText -ReplaceText $ReplaceText -OutputDirectory $OutputDirectory -Objective $Objective
    if ($LASTEXITCODE -ne 0) { throw "Propose workflow failed with exit code $LASTEXITCODE." }
    $artifacts.proposal = Join-Path $OutputDirectory 'proposal.json'
    $artifacts.diff = Join-Path $OutputDirectory 'proposal.diff'
    $artifacts.markdown = Join-Path $OutputDirectory 'proposal.md'
}
elseif ($Workflow -eq 'apply') {
    if (-not $ProposalPath -or -not $ProjectFile) { throw 'Apply requires ProposalPath and ProjectFile.' }
    if (-not (Test-Path -LiteralPath $applyScript -PathType Leaf)) { throw "Apply runner is missing: $applyScript" }
    $applyReportRoot = Join-Path $OutputDirectory 'apply'
    $applyArguments = @{
        ProposalPath = $ProposalPath
        ProjectFile = $ProjectFile
        ReportRoot = $applyReportRoot
    }
    if ($Apply) { $applyArguments.Apply = $true }
    & $applyScript @applyArguments
    if ($LASTEXITCODE -ne 0) { throw "Apply workflow failed with exit code $LASTEXITCODE." }
    $applyReport = Get-ChildItem -LiteralPath $applyReportRoot -Recurse -File -Filter 'apply-report.json' -ErrorAction Stop |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $applyReport) { throw 'Apply workflow did not create apply-report.json.' }
    $applyObject = Get-Content -Raw -LiteralPath $applyReport.FullName | ConvertFrom-Json
    $artifacts.applyReport = $applyReport.FullName
    $workflowReadOnly = [bool]$applyObject.readOnly
    $workflowMutation = [bool]$applyObject.tiaMutation
    $leaseRequired = [bool]$Apply
    $leaseAcquired = ($Apply -and $applyObject.tiaMutation -eq $true)
}

$report = [ordered]@{
    schemaVersion = 1
    workflow = $Workflow
    status = 'COMPLETED'
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    profile = $Profile
    readOnly = $workflowReadOnly
    tiaMutation = $workflowMutation
    leaseRequired = $leaseRequired
    leaseAcquired = $leaseAcquired
    outputDirectory = $OutputDirectory
    objective = $Objective
    artifacts = $artifacts
    nextStep = if ($Workflow -eq 'apply' -and -not $Apply) { 'Revisar apply-report.json y, si procede, repetir con -Profile write -Apply -AcknowledgeWriteProfile.' } else { 'Revisar los artefactos y la evidencia registrada.' }
}
$workflowPath = Join-Path $OutputDirectory 'workflow.json'
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $workflowPath -Encoding UTF8
Write-Output ($report | ConvertTo-Json -Depth 8)
Write-Host "Workflow report: $workflowPath" -ForegroundColor Green
exit 0
