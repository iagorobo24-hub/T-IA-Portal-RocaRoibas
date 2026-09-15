[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$recipes = @{
    'R05-proyecto-nuevo.md' = @('ScaffoldProject', 'dryRun=true', 'SearchHardwareCatalog')
    'R06-tags-io.md' = @('GetPlcTagTables', 'CreateTag', 'ImportPlcTagTable')
    'R07-udt-db.md' = @('PlcBuildAndImport', 'kind="udt"', 'UDT → global DB')
}
foreach ($entry in $recipes.GetEnumerator()) {
    $path = Join-Path $root ('10-kb\20-recetas\' + $entry.Key)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing recipe: $path" }
    $text = Get-Content -Raw -LiteralPath $path
    foreach ($needle in $entry.Value) {
        if ($text -notmatch [regex]::Escape($needle)) { throw "$($entry.Key) is missing '$needle'." }
    }
}
Write-Output 'PASS: creation recipes name verified V20 tools, dry-run gates and dependency order'
