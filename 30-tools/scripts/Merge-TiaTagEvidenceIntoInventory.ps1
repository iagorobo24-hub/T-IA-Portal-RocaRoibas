<##
.SYNOPSIS
    Añade evidencia detallada de tags a un inventario MCP readOnly existente.

.DESCRIPTION
    Une un inventario de bloques/árbol generado por tia-inspect con el inventario
    de tags generado por Convert-TiaTagTableExportToInventory. No conecta ni escribe
    en TIA y rechaza una combinación ambigua de PLCs.
##>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseInventoryPath,
    [Parameter(Mandatory = $true)]
    [string]$TagInventoryPath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
function Resolve-Input([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "$Label does not exist: $full" }
    return $full
}
$BaseInventoryPath = Resolve-Input $BaseInventoryPath 'Base inventory'
$TagInventoryPath = Resolve-Input $TagInventoryPath 'Tag inventory'
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null

$base = Get-Content -Raw -LiteralPath $BaseInventoryPath | ConvertFrom-Json
$tags = Get-Content -Raw -LiteralPath $TagInventoryPath | ConvertFrom-Json
if ($base.readOnly -ne $true -or $tags.readOnly -ne $true) { throw 'Both inventories must be read-only.' }
if (-not $tags.tagTables -or @($tags.tagTables).Count -eq 0) { throw 'Tag inventory contains no detailed tag tables.' }
if (-not $base.plcs -or @($base.plcs).Count -eq 0) { throw 'Base inventory contains no PLC collection.' }

$candidates = @($base.plcs)
if ($tags.softwarePath) {
    $candidates = @($base.plcs | Where-Object { [string]$_.softwarePath -eq [string]$tags.softwarePath })
}
if ($candidates.Count -ne 1) {
    $available = @($base.plcs | ForEach-Object { [string]$_.softwarePath }) -join ', '
    throw "Tag evidence does not resolve to exactly one PLC. Available software paths: $available"
}
$target = $candidates[0]
$target | Add-Member -NotePropertyName tagTables -NotePropertyValue @($tags.tagTables) -Force
$target | Add-Member -NotePropertyName detailedTagEvidence -NotePropertyValue ([ordered]@{
    source = $tags.source
    inventoryPath = $TagInventoryPath
    generatedAt = $tags.generatedAt
}) -Force
$base | Add-Member -NotePropertyName tagTables -NotePropertyValue @($tags.tagTables) -Force
$base | Add-Member -NotePropertyName detailedTagEvidence -NotePropertyValue ([ordered]@{
    source = $tags.source
    inventoryPath = $TagInventoryPath
    generatedAt = $tags.generatedAt
}) -Force
$base | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output "PASS: merged detailed tag evidence into $([string]$target.softwarePath)"
Write-Host "Evidence: $OutputPath" -ForegroundColor Green
exit 0
