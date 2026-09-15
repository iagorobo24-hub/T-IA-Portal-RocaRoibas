[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $WorkspaceRoot '30-tools\mcp\servers.json'

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Missing server manifest: $manifestPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
foreach ($property in @('schemaVersion', 'servers', 'profiles')) {
    if (-not ($manifest.PSObject.Properties.Name -contains $property)) {
        throw "Server manifest is missing '$property'."
    }
}

$readArgs = @($manifest.profiles.read.servers.'tia-inspect'.extraArgs)
$writeArgs = @($manifest.profiles.write.servers.'tia-inspect'.extraArgs)
if ($readArgs -contains '--allow-write') {
    throw 'Read profile must not contain --allow-write.'
}
if ($writeArgs -notcontains '--allow-write') {
    throw 'Write profile must contain --allow-write.'
}

$relativeCommand = [string]$manifest.servers.'tia-inspect'.commandRelative
$absoluteCommand = Join-Path $WorkspaceRoot ($relativeCommand -replace '/', '\')
if (-not (Test-Path -LiteralPath $absoluteCommand -PathType Leaf)) {
    throw "Manifest command does not exist: $absoluteCommand"
}

Write-Output 'PASS: server manifest contract'
