<##
.SYNOPSIS
    Convierte una exportación Openness PlcTagTable XML en un inventario readOnly.

.DESCRIPTION
    No conecta con TIA ni modifica el proyecto. Normaliza las tags detalladas que
    devuelve ExportPlcTagTable para que New-TiaIoList pueda generar documentación
    sin depender de una herramienta GetTags concreta del servidor MCP.
##>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExportPath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [string]$ProjectPath = '',
    [string]$SoftwarePath = '',
    [string]$Culture = 'en-US'
)

$ErrorActionPreference = 'Stop'
$ExportPath = [IO.Path]::GetFullPath($ExportPath)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if (-not (Test-Path -LiteralPath $ExportPath -PathType Leaf)) { throw "Export does not exist: $ExportPath" }
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null

function Get-NodeText([System.Xml.XmlNode]$Parent, [string]$LocalName) {
    $node = $Parent.SelectSingleNode("*[local-name()='AttributeList']/*[local-name()='$LocalName']")
    if ($node) { return [string]$node.InnerText }
    return ''
}

function Get-Comment([System.Xml.XmlNode]$Tag, [string]$PreferredCulture) {
    $items = @($Tag.SelectNodes(".//*[local-name()='MultilingualTextItem']"))
    if ($items.Count -eq 0) { return '' }
    $preferred = $items | Where-Object { (Get-NodeText $_ 'Culture') -eq $PreferredCulture } | Select-Object -First 1
    if ($preferred) { return Get-NodeText $preferred 'Text' }
    return Get-NodeText ($items | Select-Object -First 1) 'Text'
}

$xml = [xml](Get-Content -Raw -LiteralPath $ExportPath)
$tables = @($xml.SelectNodes("//*[local-name()='SW.Tags.PlcTagTable']"))
if ($tables.Count -eq 0) { throw 'The XML contains no SW.Tags.PlcTagTable elements.' }

$normalizedTables = foreach ($table in $tables) {
    $tableName = Get-NodeText $table 'Name'
    if ([string]::IsNullOrWhiteSpace($tableName)) { throw 'A tag table has no Name element.' }
    $tags = foreach ($tag in @($table.SelectNodes(".//*[local-name()='SW.Tags.PlcTag']"))) {
        [ordered]@{
            name = Get-NodeText $tag 'Name'
            dataType = Get-NodeText $tag 'DataTypeName'
            logicalAddress = Get-NodeText $tag 'LogicalAddress'
            comment = Get-Comment $tag $Culture
        }
    }
    [ordered]@{
        name = $tableName
        path = $tableName
        source = $ExportPath
        tags = @($tags)
    }
}

$normalizedTables = @($normalizedTables)
$allTags = @($normalizedTables | ForEach-Object { $_.tags })
$inventory = [ordered]@{
    schemaVersion = 1
    readOnly = $true
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    projectPath = $ProjectPath
    softwarePath = $SoftwarePath
    source = [ordered]@{
        format = 'Siemens Openness PlcTagTable XML'
        exportPath = $ExportPath
        culture = $Culture
    }
    tagTables = @($normalizedTables)
    summary = [ordered]@{ tableCount = $normalizedTables.Count; tagCount = $allTags.Count }
}
$inventory | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output ($inventory | ConvertTo-Json -Depth 8)
Write-Host "Evidence: $OutputPath" -ForegroundColor Green
exit 0
