[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$required = @(
    '10-kb\40-hmi\README.md',
    '10-kb\40-hmi\runtime-version-matrix.md',
    '10-kb\40-hmi\comfort-advanced.md',
    '10-kb\40-hmi\unified.md',
    '10-kb\20-recetas\R13-pantalla-hmi.md',
    '10-kb\20-recetas\R14-binding-hmi-plc.md'
)
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $WorkspaceRoot $relative) -PathType Leaf)) {
        throw "Missing HMI knowledge file: $relative"
    }
}
$matrix = Get-Content -Raw -LiteralPath (Join-Path $WorkspaceRoot '10-kb\40-hmi\runtime-version-matrix.md')
if ($matrix -notmatch 'V20' -or $matrix -notmatch 'V17' -or $matrix -notmatch 'incompatible|no compatible|no se puede') {
    throw 'HMI runtime matrix must document the current V20/V17 mismatch.'
}
Write-Output 'PASS: HMI knowledge distinguishes runtime families and records the current mismatch'
