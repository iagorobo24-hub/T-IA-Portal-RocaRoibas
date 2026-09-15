[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'TIA-Claude_Portable\dist'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $OutputRoot) {
    if (-not $Force) { throw "Output already exists; use -Force only for this exact package directory: $OutputRoot" }
    Remove-Item -LiteralPath $OutputRoot -Recurse -Force
}

$coreRoot = Join-Path $OutputRoot 'TIA-Claude_Core'
$examplesRoot = Join-Path $OutputRoot 'TIA-Claude_Examples'
New-Item -ItemType Directory -Path $coreRoot,$examplesRoot -Force | Out-Null

function Copy-WorkspaceItem([string]$RelativePath, [string]$DestinationRoot) {
    $source = Join-Path $WorkspaceRoot ($RelativePath -replace '/', '\')
    if (-not (Test-Path -LiteralPath $source)) { throw "Required package input is missing: $RelativePath" }
    $destination = Join-Path $DestinationRoot ($RelativePath -replace '/', '\')
    $sourceItem = Get-Item -LiteralPath $source
    if ($sourceItem.PSIsContainer) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        # Copy the contents into the already-created destination. Passing the
        # directory itself to Copy-Item would create an accidental nested
        # '<name>\<name>' path and break relative MCP configurations.
        Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
        }
    }
    else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
}

$coreItems = @(
    'AGENTS.md', 'CLAUDE.md', 'README.md', '.gitattributes', '.gitignore',
    '00-meta', '10-kb', '20-standards', '60-library',
    '30-tools/scripts', '30-tools/tests', '30-tools/harnesses', '30-tools/mcp/servers.json',
    '30-tools/mcp/tia-inspect/README.md',
    '30-tools/mcp/tia-inspect/build.ps1', '30-tools/mcp/tia-inspect/patches',
    '30-tools/mcp/tia-inspect/bin/v20'
)
foreach ($item in $coreItems) { Copy-WorkspaceItem $item $coreRoot }

# The split core is self-installing when copied to a USB or another folder.
$coreInstall = Join-Path $coreRoot 'install'
New-Item -ItemType Directory -Path $coreInstall -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\install\Install-CorePackage.ps1') -Destination $coreInstall -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\install\Verify-CorePackage.ps1') -Destination $coreInstall -Force

# Examples are intentionally a separate opt-in payload. They may contain
# .ap20 artifacts, but never enter the core package.
Copy-WorkspaceItem '50-examples' $examplesRoot

function New-PackageManifest([string]$PackageRoot, [string]$Kind, [bool]$ContainsProjects) {
    $manifestDirectory = Join-Path $PackageRoot 'manifests'
    New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
    $manifestName = if ($Kind -eq 'core') { 'package-manifest.json' } else { 'examples-manifest.json' }
    $manifestPath = Join-Path $manifestDirectory $manifestName
    $files = @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File | Where-Object { $_.FullName -ne $manifestPath })
    $entries = foreach ($file in $files) {
        $relative = $file.FullName.Substring($PackageRoot.Length).TrimStart('\','/').Replace('\','/')
        [ordered]@{
            path = $relative
            bytes = $file.Length
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
        }
    }
    [ordered]@{
        schemaVersion = 1
        packageKind = $Kind
        containsProjects = $ContainsProjects
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        fileCount = $entries.Count
        files = @($entries)
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

New-PackageManifest $coreRoot 'core' $false
$containsProjects = @(
    Get-ChildItem -LiteralPath $examplesRoot -Recurse -File -Include '*.ap16','*.ap17','*.ap18','*.ap19','*.ap20','*.ap21'
).Count -gt 0
New-PackageManifest $examplesRoot 'examples' $containsProjects

[ordered]@{
    schemaVersion = 1
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    core = 'TIA-Claude_Core'
    examples = 'TIA-Claude_Examples'
    coreManifest = 'TIA-Claude_Core/manifests/package-manifest.json'
    examplesManifest = 'TIA-Claude_Examples/manifests/examples-manifest.json'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputRoot 'package-set.json') -Encoding UTF8

Write-Output "Portable core written to $coreRoot"
Write-Output "Portable examples written to $examplesRoot"
$global:LASTEXITCODE = 0
exit 0
