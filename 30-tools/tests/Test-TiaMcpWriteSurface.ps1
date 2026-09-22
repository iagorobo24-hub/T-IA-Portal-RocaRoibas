[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$modelDirectory = Join-Path $WorkspaceRoot '30-tools\mcp\tia-inspect\upstream\src\TiaMcpServer\ModelContextProtocol'
if (-not (Test-Path -LiteralPath $modelDirectory -PathType Container)) {
    throw "MCP source directory is missing: $modelDirectory"
}

$readFiles = @(Get-ChildItem -LiteralPath $modelDirectory -Filter 'McpServer*.cs' -File | Where-Object {
    $_.Name -notlike 'McpServerWrite*'
})
$writeFiles = @(Get-ChildItem -LiteralPath $modelDirectory -Filter 'McpServerWrite*.cs' -File)
$toolNamePattern = '\[McpServerTool\(\s*Name\s*=\s*"([^"]+)"'
$readToolNames = @($readFiles | ForEach-Object {
    [regex]::Matches([IO.File]::ReadAllText($_.FullName), $toolNamePattern) | ForEach-Object { $_.Groups[1].Value }
})
$writeToolNames = @($writeFiles | ForEach-Object {
    [regex]::Matches([IO.File]::ReadAllText($_.FullName), $toolNamePattern) | ForEach-Object { $_.Groups[1].Value }
})

$projectMutationTools = @(
    'SaveProject'
)
foreach ($toolName in $projectMutationTools) {
    if ($readToolNames -contains $toolName) {
        throw "Project-mutating tool '$toolName' is declared on the always-registered read tool type."
    }
    if ($writeToolNames -notcontains $toolName) {
        throw "Project-mutating tool '$toolName' is not declared on the --allow-write tool type."
    }
}

$unsafeUntilPreflight = @(
    'ImportBlock',
    'ImportFromDocuments',
    'ImportBlocksFromDocuments',
    'ImportSources',
    'GenerateBlocksFromSource',
    'ImportTagTable',
    'ImportTypesFromDocuments',
    'ImportType',
    'ImportTypeFromDocuments',
    'DeleteTypeGroup',
    'DeleteType',
    'RenameType',
    'CopyType',
    'MoveType',
    'SaveAsProject'
)
foreach ($toolName in $unsafeUntilPreflight) {
    if ($readToolNames -contains $toolName -or $writeToolNames -contains $toolName) {
        throw "Opaque source-driven mutation '$toolName' must not be registered until it can preflight every input and overwrite target."
    }
}

Write-Output 'PASS: project persistence is write-only; type and opaque source mutations remain unregistered.'
