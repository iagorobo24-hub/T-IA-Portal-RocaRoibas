[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$metadataScript = Join-Path $root '30-tools\scripts\TiaBlockMetadata.ps1'
$checker = Join-Path $root '30-tools\scripts\Check-TiaStandards.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-block-metadata-' + [guid]::NewGuid().ToString('N'))

try {
    if (-not (Test-Path -LiteralPath $metadataScript -PathType Leaf)) { throw 'Missing block metadata helper.' }
    . $metadataScript
    New-Item -ItemType Directory -Path $temp -Force | Out-Null

    $presentPath = Join-Path $temp 'present.xml'
    @'
<Document><SW.Blocks.FB><ObjectList>
  <MultilingualText CompositionName="Comment"><ObjectList><MultilingualTextItem><AttributeList><Culture>en-US</Culture><Text>Bloque mínimo de prueba</Text></AttributeList></MultilingualTextItem></ObjectList></MultilingualText>
  <SW.Blocks.CompileUnit><ObjectList><MultilingualText CompositionName="Comment"><ObjectList><MultilingualTextItem><AttributeList><Text /></AttributeList></MultilingualTextItem></ObjectList></MultilingualText></ObjectList></SW.Blocks.CompileUnit>
</ObjectList></SW.Blocks.FB></Document>
'@ | Set-Content -LiteralPath $presentPath -Encoding UTF8
    $present = Get-TiaBlockCommentMetadata -XmlPath $presentPath
    if ($present.status -ne 'verified-present' -or $present.encodingStatus -ne 'clean') { throw 'Block-level multilingual comment was not recognized as present and clean.' }
    if ($present.PSObject.Properties['text']) { throw 'Block comment helper must not return comment text.' }

    $missingPath = Join-Path $temp 'missing.xml'
    '<Document><SW.Blocks.FB><ObjectList /></SW.Blocks.FB></Document>' | Set-Content -LiteralPath $missingPath -Encoding UTF8
    $missing = Get-TiaBlockCommentMetadata -XmlPath $missingPath
    if ($missing.status -ne 'verified-missing' -or $missing.hasComment -ne $false) { throw 'An explicitly absent block comment was not classified as missing.' }

    $badEncodingPath = Join-Path $temp 'encoding.xml'
    '<Document><SW.Blocks.FB><ObjectList><MultilingualText CompositionName="Comment"><ObjectList><MultilingualTextItem><AttributeList><Text>Bloque mÃ­nimo</Text></AttributeList></MultilingualTextItem></ObjectList></MultilingualText></ObjectList></SW.Blocks.FB></Document>' | Set-Content -LiteralPath $badEncodingPath -Encoding UTF8
    $badEncoding = Get-TiaBlockCommentMetadata -XmlPath $badEncodingPath
    if ($badEncoding.status -ne 'verified-present' -or $badEncoding.encodingStatus -ne 'suspect') { throw 'Mojibake in a present comment was not detected.' }

    $unknownRoot = Join-Path $temp 'inventory'
    $exportRoot = Join-Path $temp 'export'
    $inventoryPath = Join-Path $temp 'inventory.json'
    $outputPath = Join-Path $temp 'standards.json'
    New-Item -ItemType Directory -Path (Join-Path $exportRoot 'Program blocks') -Force | Out-Null
    '<Document />' | Set-Content -LiteralPath (Join-Path $exportRoot 'Program blocks\FB_Unknown.xml') -Encoding UTF8
    [ordered]@{
        blocks = @([ordered]@{ name = 'FB_Unknown'; path = 'FB_Unknown'; isConsistent = $true; isKnowHowProtected = $false; comment = $null })
        defaultTagCount = 0
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8
    & $checker -InventoryPath $inventoryPath -ExportPath $exportRoot -OutputPath $outputPath | Out-Null
    $standards = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if (@($standards.findings | Where-Object code -eq 'BLOCK_COMMENT_UNVERIFIED').Count -ne 1) { throw 'Unknown comment metadata must be reported as unverified.' }
    if (@($standards.findings | Where-Object code -eq 'MISSING_BLOCK_COMMENT').Count -ne 0) { throw 'Unknown comment metadata must not be mislabeled as missing.' }

    Write-Output 'PASS: block comments are read from XML, encoding damage is distinguished, and unknown metadata is not called missing'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
