[CmdletBinding()]
param(
    [string]$PackageRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory = $true)]
    [string]$DestinationRoot,
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot)
$DestinationRoot = [IO.Path]::GetFullPath($DestinationRoot)
if (-not (Test-Path -LiteralPath (Join-Path $PackageRoot 'AGENTS.md') -PathType Leaf)) {
    throw "The package root is not a TIA-Claude core package: $PackageRoot"
}
$hasContent = (Test-Path -LiteralPath $DestinationRoot) -and @(
    Get-ChildItem -LiteralPath $DestinationRoot -Force -ErrorAction SilentlyContinue
).Count -gt 0
if ($hasContent -and -not $Update) {
    throw "Destination already has content; use -Update explicitly: $DestinationRoot"
}
New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
& robocopy $PackageRoot $DestinationRoot /E /XD (Join-Path $PackageRoot 'install') /R:2 /W:1 /NFL /NDL /NP | Out-Null
if ($LASTEXITCODE -gt 7) { throw "Robocopy failed with code $LASTEXITCODE" }

$sync = Join-Path $DestinationRoot '30-tools\scripts\Sync-HarnessConfigs.ps1'
if (-not (Test-Path -LiteralPath $sync -PathType Leaf)) { throw "Installed core is missing the config synchronizer: $sync" }
& $sync -WorkspaceRoot $DestinationRoot -Profile read
if ($LASTEXITCODE -gt 0) { throw "MCP read profile generation failed with code $LASTEXITCODE" }
Write-Output "TIA-Claude core installed at $DestinationRoot"
$global:LASTEXITCODE = 0
exit 0
