[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$builder = Join-Path $WorkspaceRoot 'TIA-Claude_Portable\build\Build-PortablePackage.ps1'
if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) { throw 'Build-PortablePackage.ps1 is missing.' }

$outputRoot = Join-Path $WorkspaceRoot ('90-tmp\portable-content-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
try {
    & $builder -WorkspaceRoot $WorkspaceRoot -OutputRoot $outputRoot
    if ($LASTEXITCODE -ne 0) { throw 'Portable package builder returned a failure exit code.' }
    $core = Join-Path $outputRoot 'TIA-Claude_Core'
    $examples = Join-Path $outputRoot 'TIA-Claude_Examples'
    $coreManifest = Join-Path $core 'manifests\package-manifest.json'
    $examplesManifest = Join-Path $examples 'manifests\examples-manifest.json'
    foreach ($path in @($core, $examples, $coreManifest, $examplesManifest)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Portable output is missing: $path" }
    }
    if (@(Get-ChildItem -LiteralPath $core -Recurse -File -Include '*.ap16','*.ap17','*.ap18','*.ap19','*.ap20','*.ap21').Count -gt 0) {
        throw 'Core package contains a TIA project artifact.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $core '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe') -PathType Leaf)) {
        throw 'Core package is missing the verified tia-create V20 runtime.'
    }
    foreach ($tool in @('Invoke-TiaProjectAnalysis.ps1', 'New-TiaSclProposal.ps1', 'Invoke-TiaWorkflow.ps1', 'Invoke-TiaSclProposalApply.ps1', 'New-TiaIoList.ps1', 'New-TiaFunctionalDescription.ps1', 'Convert-TiaTagTableExportToInventory.ps1', 'Merge-TiaTagEvidenceIntoInventory.ps1', 'Inspect-McpToolSchemas.ps1', 'Invoke-TiaSimulationAcceptance.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $core "30-tools\scripts\$tool") -PathType Leaf)) { throw "Core package is missing semantic tool: $tool" }
    }
    foreach ($test in @('Test-TiaProjectAnalysis.ps1', 'Test-TiaSclProposal.ps1', 'Test-TiaSclProposalApply.ps1', 'Test-TiaIoList.ps1', 'Test-TiaFunctionalDescription.ps1', 'Test-TiaWorkflow.ps1', 'Test-ConvertTiaTagTableExport.ps1', 'Test-MergeTiaTagEvidence.ps1', 'Test-TiaCreationRecipes.ps1', 'Test-InspectMcpToolSchemas.ps1', 'Test-InvokeTiaSimulationAcceptance.ps1', 'Test-PlcSimCommandProtocol.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $core "30-tools\tests\$test") -PathType Leaf)) { throw "Core package is missing semantic test: $test" }
    }
    foreach ($guide in @('README-INSTALL.md', 'docs\arquitectura.md', 'docs\funcionamiento.md', 'docs\harnesses.md', 'docs\prompt-claude-code.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $core $guide) -PathType Leaf)) { throw "Core package is missing operational guide: $guide" }
    }
    $prompt = Get-Content -Raw -LiteralPath (Join-Path $core 'docs\prompt-claude-code.md')
    if ($prompt -match 'Pega este prompt en `workspace/`') { throw 'Portable Claude prompt still targets the legacy monolithic workspace.' }
    foreach ($requiredPromptText in @('AGENTS.md', 'Doctor', 'GetProjectTree', 'Profile read', 'AcknowledgeWriteProfile')) {
        if ($prompt -notmatch [regex]::Escape($requiredPromptText)) { throw "Portable Claude prompt is missing: $requiredPromptText" }
    }
    $manifest = Get-Content -Raw -LiteralPath $coreManifest | ConvertFrom-Json
    if ($manifest.packageKind -ne 'core' -or $manifest.files.Count -eq 0) { throw 'Core manifest is incomplete.' }
    $exampleManifestObject = Get-Content -Raw -LiteralPath $examplesManifest | ConvertFrom-Json
    if ($exampleManifestObject.packageKind -ne 'examples' -or $exampleManifestObject.containsProjects -ne $true) {
        throw 'Examples manifest must explicitly declare that it contains projects.'
    }
    Write-Output 'PASS: portable core excludes project artifacts and examples are separately manifested'
}
finally {
    if (Test-Path -LiteralPath $outputRoot) { Remove-Item -LiteralPath $outputRoot -Recurse -Force }
}
