<##
.SYNOPSIS
    Punto de entrada para workflows semanticos seguros de TIA-Claude.

.DESCRIPTION
    Coordina operaciones sobre snapshots sin mezclar analisis, propuesta y aplicacion.
    `analyze` consume un inventario MCP readOnly y fuentes exportadas. `propose` consume un
    dossier y produce una propuesta SCL. `apply` se rechaza expresamente hasta que exista un
    runner de escritura que implemente todos los gates de AGENTS.md.
##>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('analyze', 'propose', 'apply')]
    [string]$Workflow,

    [string]$InventoryPath,
    [string]$SourceRoot,
    [string]$AnalysisPath,
    [string]$BlockName,
    [string]$FindText,
    [string]$ReplaceText,
    [string]$OutputDirectory,
    [ValidateSet('read', 'write', 'create', 'full')]
    [string]$Profile = 'read',
    [string]$Objective = '',
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

if ($Help) {
    Write-Output @'
Invoke-TiaWorkflow.ps1: workflows snapshot-only de TIA-Claude.
  analyze: inventory MCP readOnly + fuentes -> analysis.json/md
  propose: analysis + reemplazo SCL -> proposal.json/copia/diff
  apply: rechazado hasta disponer de un runner de escritura con todos los gates
'@
    exit 0
}

if ($Profile -ne 'read') { throw "Workflow '$Workflow' currently only accepts profile 'read'." }
if ($Workflow -eq 'apply') { throw 'Workflow apply is intentionally unavailable: use the explicit backup/preview/compile/save/export write loop first.' }

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
$artifacts = [ordered]@{}

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

$report = [ordered]@{
    schemaVersion = 1
    workflow = $Workflow
    status = 'COMPLETED'
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    profile = $Profile
    readOnly = $true
    tiaMutation = $false
    leaseRequired = $false
    leaseAcquired = $false
    outputDirectory = $OutputDirectory
    objective = $Objective
    artifacts = $artifacts
    nextStep = 'Revisar los artefactos y, si procede, iniciar una operacion separada con el ciclo de escritura de AGENTS.md.'
}
$workflowPath = Join-Path $OutputDirectory 'workflow.json'
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $workflowPath -Encoding UTF8
Write-Output ($report | ConvertTo-Json -Depth 8)
Write-Host "Workflow report: $workflowPath" -ForegroundColor Green
exit 0
