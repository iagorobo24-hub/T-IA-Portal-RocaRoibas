[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Invoke-TiaWorkflow.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-workflow-test-' + [guid]::NewGuid().ToString('N'))
$sourceRoot = Join-Path $temp 'src'
$inventoryPath = Join-Path $temp 'inventory.json'
$outputDirectory = Join-Path $temp 'workflow'
$proposalOutputDirectory = Join-Path $temp 'proposal-workflow'

try {
    New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Program blocks') -Force | Out-Null
    @'
FUNCTION_BLOCK "FB_Motor"
VERSION : 0.1
AUTHOR : TIA_Claude
FAMILY : Drives
BEGIN
   #Run := #CmdStart AND #Interlock;
END_FUNCTION_BLOCK
'@ | Set-Content -LiteralPath (Join-Path $sourceRoot 'Program blocks\FB_Motor.s7dcl') -Encoding UTF8
    $inventory = [ordered]@{
        schemaVersion = 1; readOnly = $true; projectPath = 'C:\fixture\Demo_V20.ap20'; defaultTagCount = 0
        plcs = @([ordered]@{ name = 'Demo PLC'; softwarePath = 'PLC_1'; defaultTagCount = 0; blocks = @([ordered]@{
            path = 'FB_Motor'; name = 'FB_Motor'; typeName = 'FB'; programmingLanguage = 'SCL'; isConsistent = $true; isKnowHowProtected = $false; comment = $true
        }) })
        blocks = @()
    }
    $inventory | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    & $script -Workflow analyze -InventoryPath $inventoryPath -SourceRoot $sourceRoot -OutputDirectory $outputDirectory -Objective 'Smoke workflow'
    if ($LASTEXITCODE -ne 0) { throw "Analyze workflow failed with exit code $LASTEXITCODE." }
    $workflowPath = Join-Path $outputDirectory 'workflow.json'
    $analysisPath = Join-Path $outputDirectory 'analysis.json'
    if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) { throw 'Workflow report was not created.' }
    if (-not (Test-Path -LiteralPath $analysisPath -PathType Leaf)) { throw 'Workflow analysis was not created.' }
    $workflow = Get-Content -Raw -LiteralPath $workflowPath | ConvertFrom-Json
    if ($workflow.status -ne 'COMPLETED' -or $workflow.tiaMutation -ne $false) { throw 'Analyze workflow must complete without TIA mutation.' }
    if ($workflow.workflow -ne 'analyze') { throw 'Workflow name was not recorded.' }
    Write-Output 'PASS: semantic workflow runs analyze and records a no-mutation trace'

    & $script -Workflow propose -AnalysisPath $analysisPath -BlockName 'FB_Motor' -FindText '#Run := #CmdStart AND #Interlock;' -ReplaceText '#Run := #CmdStart AND #Interlock AND #Ready;' -OutputDirectory $proposalOutputDirectory -Objective 'Añadir permiso de seguridad'
    if ($LASTEXITCODE -ne 0) { throw "Propose workflow failed with exit code $LASTEXITCODE." }
    $proposalWorkflow = Get-Content -Raw -LiteralPath (Join-Path $proposalOutputDirectory 'workflow.json') | ConvertFrom-Json
    if ($proposalWorkflow.workflow -ne 'propose' -or $proposalWorkflow.tiaMutation -ne $false) { throw 'Propose workflow must remain no-mutation.' }
    if (-not (Test-Path -LiteralPath (Join-Path $proposalOutputDirectory 'proposal.json') -PathType Leaf)) { throw 'Propose workflow did not create proposal.json.' }
    Write-Output 'PASS: semantic workflow runs propose without importing the change'

    $applyFailed = $false
    try {
        & $script -Workflow apply -OutputDirectory (Join-Path $temp 'apply-workflow') 2>&1 | Out-Null
    }
    catch {
        $applyFailed = $true
    }
    if (-not $applyFailed) { throw 'Apply workflow must remain explicitly unavailable.' }
    Write-Output 'PASS: semantic workflow refuses apply until the write-gated runner exists'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
