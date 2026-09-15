[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Convert-TiaTagTableExportToInventory.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-tag-export-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <SW.Tags.PlcTagTable>
    <AttributeList><Name>Area</Name></AttributeList>
    <ObjectList>
      <SW.Tags.PlcTag>
        <AttributeList><DataTypeName>Bool</DataTypeName><LogicalAddress>%I0.0</LogicalAddress><Name>DI_Start</Name></AttributeList>
        <ObjectList><MultilingualTextItem><AttributeList><Culture>es-ES</Culture><Text>Arranque</Text></AttributeList></MultilingualTextItem></ObjectList>
      </SW.Tags.PlcTag>
      <SW.Tags.PlcTag>
        <AttributeList><DataTypeName>Int</DataTypeName><LogicalAddress>%QW2</LogicalAddress><Name>Q_Speed</Name></AttributeList>
        <ObjectList><MultilingualTextItem><AttributeList><Culture>en-US</Culture><Text>Speed output</Text></AttributeList></MultilingualTextItem></ObjectList>
      </SW.Tags.PlcTag>
    </ObjectList>
  </SW.Tags.PlcTagTable>
</Document>
'@
    $xmlPath = Join-Path $temp 'tags.xml'
    $outputPath = Join-Path $temp 'inventory.json'
    $xml | Set-Content -LiteralPath $xmlPath -Encoding UTF8
    & $script -ExportPath $xmlPath -OutputPath $outputPath -ProjectPath 'C:\fixture\Demo.ap20' -SoftwarePath 'PLC_1' -Culture 'es-ES'
    if ($LASTEXITCODE -ne 0) { throw 'Converter returned a failure exit code.' }
    $inventory = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if ($inventory.readOnly -ne $true) { throw 'Converted inventory is not read-only.' }
    if ($inventory.summary.tableCount -ne 1 -or $inventory.summary.tagCount -ne 2) { throw 'Unexpected converted counts.' }
    $tags = @($inventory.tagTables[0].tags)
    if ($tags[0].name -ne 'DI_Start' -or $tags[0].logicalAddress -ne '%I0.0' -or $tags[0].comment -ne 'Arranque') { throw 'Preferred culture tag mapping failed.' }
    if ($tags[1].dataType -ne 'Int' -or $tags[1].comment -ne 'Speed output') { throw 'Fallback tag mapping failed.' }
    Write-Output 'PASS: Openness tag-table XML converts to detailed read-only inventory'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
