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
        { "path": "FB_Motor", "name": "FB_Motor", "typeName": "FB", "programmingLanguage": "SCL", "isConsistent": true, "isKnowHowProtected": false, "comment": true }
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
    if ($report.sources.declarations.Count -ne 2) { throw 'Expected two source declarations.' }
    if ($report.sources.xml -ne 1) { throw 'Expected one XML block export.' }
    if ($report.references.calls[0].target -ne 'FB_Motor') { throw 'Expected the Main to reference FB_Motor.' }
    if ($report.summary.blockingFindings -ne 0) { throw 'The clean fixture must have no blocking findings.' }
    if (-not (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($outputPath, '.md')) -PathType Leaf)) { throw 'Analysis Markdown was not created.' }
    Write-Output 'PASS: project analysis creates a read-only dossier, source coverage and call references'

    $blocked = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json
    $blocked.plcs[0].blocks[0].isKnowHowProtected = $true
    $blocked | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $blockedInventoryPath -Encoding UTF8
    & $script -InventoryPath $blockedInventoryPath -SourceRoot $sourceRoot -OutputPath $blockedOutputPath -FailOnBlockingFindings 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 1) { throw "Expected blocking analysis to return exit code 1, got $LASTEXITCODE." }
    $blockedReport = Get-Content -Raw -LiteralPath $blockedOutputPath | ConvertFrom-Json
    if ($blockedReport.summary.blockingFindings -ne 1) { throw 'Expected one know-how protection blocking finding.' }
    Write-Output 'PASS: project analysis blocks protected objects when requested'
}
catch {
    throw
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
