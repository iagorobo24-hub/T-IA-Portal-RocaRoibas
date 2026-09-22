[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$modelRoot = Join-Path $WorkspaceRoot '30-tools\mcp\tia-inspect\upstream\src\TiaMcpServer\ModelContextProtocol'
$writeFile = Join-Path $modelRoot 'McpServerWrite.cs'
$saveFile = Join-Path $modelRoot 'McpServerWrite.LegacyMutations.cs'
foreach ($path in @($writeFile, $saveFile)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing MCP save-boundary source: $path"
    }
}

$writeText = [IO.File]::ReadAllText($writeFile)
$saveText = [IO.File]::ReadAllText($saveFile)
$saveMethod = [regex]::Match(
    $saveText,
    '(?s)public static ResponseSaveProject SaveProject\(\).*?(?=\r?\n\s*// Unregistered: SaveAsProject)'
).Value
if ([string]::IsNullOrWhiteSpace($saveMethod)) {
    throw 'Could not isolate the SaveProject method for the boundary check.'
}
if ($saveMethod -match 'return\s+Guarded\(nameof\(SaveProject\)') {
    throw 'SaveProject must not run Project.Save/SaveSession inside Guarded transaction scope.'
}
if ($saveMethod -notmatch 'return\s+SaveGuarded\(nameof\(SaveProject\)') {
    throw 'SaveProject must use the save-specific safety wrapper.'
}

$saveGuarded = [regex]::Match(
    $writeText,
    '(?s)private static T SaveGuarded<T>\(string toolName, Func<T> body\).*?(?=\r?\n\s*private static JsonObject OkMeta)'
).Value
if ([string]::IsNullOrWhiteSpace($saveGuarded)) {
    throw 'SaveGuarded implementation is missing.'
}
if ($saveGuarded -match 'InTransaction') {
    throw 'SaveGuarded must remain outside the Openness transaction boundary.'
}
if ($saveGuarded -notmatch 'EnsureNoSafetyObjectsForWrite\(toolName\)') {
    throw 'SaveGuarded must retain the project-wide F/Safety preflight.'
}

Write-Output 'PASS: SaveProject persists outside the Openness transaction while retaining the F/Safety gate.'
