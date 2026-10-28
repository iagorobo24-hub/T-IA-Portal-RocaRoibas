[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Invoke-TiaProjectAnalysis.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-analysis-test-' + [guid]::NewGuid().ToString('N'))
$sourceRoot = Join-Path $temp 'src'
$inventoryPath = Join-Path $temp 'inventory.json'
$blockedInventoryPath = Join-Path $temp 'blocked-inventory.json'
$outputPath = Join-Path $temp 'analysis.json'
$blockedOutputPath = Join-Path $temp 'blocked-analysis.json'

try {
    New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Program blocks') -Force | Out-Null
    @'
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <SW.Blocks.FB>
    <AttributeList>
      <Name>FB_Motor</Name>
      <ProgrammingLanguage>SCL</ProgrammingLanguage>
    </AttributeList>
    <ObjectList>
      <MultilingualText CompositionName="Comment"><ObjectList><MultilingualTextItem><AttributeList><Culture>en-US</Culture><Text>Verified block comment</Text></AttributeList></MultilingualTextItem></ObjectList></MultilingualText>
    </ObjectList>
  </SW.Blocks.FB>
</Document>
'@ | Set-Content -LiteralPath (Join-Path $sourceRoot 'Program blocks\FB_Motor.xml') -Encoding UTF8
    @'
ORGANIZATION_BLOCK "Main"
BEGIN
   "FB_Motor"();
END_ORGANIZATION_BLOCK
'@ | Set-Content -LiteralPath (Join-Path $sourceRoot 'Program blocks\Main.s7dcl') -Encoding UTF8
    @'
FUNCTION_BLOCK "FB_Valve"
BEGIN
   #Open := #Command;
END_FUNCTION_BLOCK
'@ | Set-Content -LiteralPath (Join-Path $sourceRoot 'Program blocks\FB_Valve.scl') -Encoding UTF8
    @'
{
  "schemaVersion": 1,
  "readOnly": true,
  "projectPath": "C:\\fixture\\Demo_V20.ap20",
  "projectTree": "PLC_1 [PLC]\n  PlcSoftware: PLC_1 [Software]",
  "plcs": [
    {
      "name": "Demo PLC",
      "softwarePath": "PLC_1",
      "summary": { "name": "Demo PLC", "blockCount": 2, "tagCount": 0 },
      "softwareTree": "Program blocks [Group]\n  Main [OB]\n  FB_Motor [FB]",
      "blocks": [
        { "path": "Main", "name": "Main", "typeName": "OB", "programmingLanguage": "SCL", "isConsistent": true, "isKnowHowProtected": false, "comment": true },
        { "path": "FB_Motor", "name": "FB_Motor", "typeName": "FB", "programmingLanguage": "SCL", "isConsistent": true, "isKnowHowProtected": false, "comment": false }
      ],
      "defaultTagCount": 0
    }
  ],
  "blocks": [],
  "defaultTagCount": 0
}
'@ | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    & $script -InventoryPath $inventoryPath -SourceRoot $sourceRoot -OutputPath $outputPath
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { throw 'Analysis JSON was not created.' }
    $report = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if ($report.readOnly -ne $true) { throw 'Analysis must be marked readOnly.' }
    if ($report.project.plcCount -ne 1) { throw 'Expected one PLC in the dossier.' }
    if ($report.project.blockCount -ne 2) { throw 'Expected two blocks in the dossier.' }
    if ($report.project.languages.SCL -ne 2) { throw 'Expected two SCL blocks in the dossier.' }
    if ($report.sources.declarations.Count -ne 3) { throw 'Expected three source declarations across exported and external SCL sources.' }
    if ($report.sources.xml -ne 1) { throw 'Expected one XML block export.' }
    if ($report.sources.scl -ne 2) { throw 'Expected two SCL source files.' }
    if ($report.references.calls[0].target -ne 'FB_Motor') { throw 'Expected the Main to reference FB_Motor.' }
    if ($report.summary.blockingFindings -ne 0) { throw 'The clean fixture must have no blocking findings.' }
    $motorReport = @($report.blocks | Where-Object name -eq 'FB_Motor' | Select-Object -First 1)
    if ($motorReport.Count -ne 1 -or $motorReport[0].hasComment -ne $true -or $motorReport[0].commentStatus -ne 'verified-present') {
        throw 'Exported block XML must override the unreliable GetBlocks.headerName-derived false value.'
    }
    if (@($report.findings | Where-Object { $_.block -eq 'FB_Motor' -and $_.code -eq 'MISSING_BLOCK_COMMENT' }).Count -ne 0) {
        throw 'A present XML block comment must not be reported as missing.'
    }
    if (@($report.findings | Where-Object { $_.block -eq 'Main' -and $_.code -eq 'BLOCK_COMMENT_UNVERIFIED' }).Count -ne 1) {
        throw 'A comment without XML evidence must be reported as unverified, not treated as present.'
    }
    if (-not (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($outputPath, '.md')) -PathType Leaf)) { throw 'Analysis Markdown was not created.' }
    Write-Output 'PASS: project analysis creates a read-only dossier, source coverage and call references'

    # Un inventario antiguo/plano deja path='' en bloques top-level. El analisis debe
    # normalizarlo a path=name, deduplicar el mismo bloque presente en plcs[] y blocks[],
    # y permitir que New-TiaSclProposal genere una propuesta aplicable.
    $emptyPathInventoryPath = Join-Path $temp 'empty-path-inventory.json'
    $emptyPathOutputPath = Join-Path $temp 'empty-path-analysis.json'
    $emptyPath = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json
    $emptyPath.plcs[0].blocks[1].path = ''
    $emptyPath.plcs[0].blocks += [pscustomobject]@{
        path = ''; name = 'FB_Valve'; typeName = 'FB'; programmingLanguage = 'SCL'
        isConsistent = $true; isKnowHowProtected = $false; comment = $null
    }
    $emptyPath.blocks = @($emptyPath.plcs[0].blocks[1], $emptyPath.plcs[0].blocks[2])
    $emptyPath | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $emptyPathInventoryPath -Encoding UTF8
    & $script -InventoryPath $emptyPathInventoryPath -SourceRoot $sourceRoot -OutputPath $emptyPathOutputPath | Out-Null
    $emptyPathReport = Get-Content -Raw -LiteralPath $emptyPathOutputPath | ConvertFrom-Json
    $normalizedMotor = @($emptyPathReport.blocks | Where-Object name -eq 'FB_Motor')
    $normalizedValve = @($emptyPathReport.blocks | Where-Object name -eq 'FB_Valve')
    if ($normalizedMotor.Count -ne 1 -or $normalizedMotor[0].path -ne 'FB_Motor') {
        throw "Empty path must normalize to the block name; got '$($normalizedMotor[0].path)'."
    }
    if ($normalizedValve.Count -ne 1 -or $normalizedValve[0].path -ne 'FB_Valve') {
        throw 'A root-level duplicate with empty path must dedupe against the normalized PLC row.'
    }
    $normalizedMain = @($emptyPathReport.blocks | Where-Object name -eq 'Main')[0]
    if ($normalizedMain.path -ne 'Main') { throw 'A non-empty block path must be preserved verbatim.' }

    $normalizedProposal = Join-Path $temp 'normalized-proposal'
    & (Join-Path $root '30-tools\scripts\New-TiaSclProposal.ps1') `
        -AnalysisPath $emptyPathOutputPath -BlockName FB_Valve `
        -FindText '#Open := #Command;' -ReplaceText '#Open := #Command; // normalized' `
        -OutputDirectory $normalizedProposal | Out-Null
    $normalizedProposalJson = Get-Content -Raw -LiteralPath (Join-Path $normalizedProposal 'proposal.json') | ConvertFrom-Json
    if ($normalizedProposalJson.block.path -ne 'FB_Valve' -or $normalizedProposalJson.block.language -ne 'SCL') {
        throw 'A normalized analysis must produce a proposal with a top-level SCL block path.'
    }
    Write-Output 'PASS: empty top-level paths normalize to the block name and remain proposal-ready'

    $blocked = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json
    $blocked.plcs[0].blocks[0].isKnowHowProtected = $true
    $blocked | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $blockedInventoryPath -Encoding UTF8
    & $script -InventoryPath $blockedInventoryPath -SourceRoot $sourceRoot -OutputPath $blockedOutputPath -FailOnBlockingFindings 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 1) { throw "Expected blocking analysis to return exit code 1, got $LASTEXITCODE." }
    $blockedReport = Get-Content -Raw -LiteralPath $blockedOutputPath | ConvertFrom-Json
    if ($blockedReport.summary.blockingFindings -ne 1) { throw 'Expected one know-how protection blocking finding.' }
    Write-Output 'PASS: project analysis blocks protected objects when requested'
    $global:LASTEXITCODE = 0
}
catch {
    throw
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
