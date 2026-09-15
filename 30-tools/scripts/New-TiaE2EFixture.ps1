[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [Parameter(Mandatory = $true)]
    [string]$SourceProjectDirectory,
    [Parameter(Mandatory = $true)]
    [string]$DestinationDirectory,
    [switch]$SkipMcp
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$SourceProjectDirectory = [IO.Path]::GetFullPath($SourceProjectDirectory)
$DestinationDirectory = [IO.Path]::GetFullPath($DestinationDirectory)

if (-not (Test-Path -LiteralPath $SourceProjectDirectory -PathType Container)) {
    throw "Source project directory does not exist: $SourceProjectDirectory"
}
$projectFiles = @(Get-ChildItem -LiteralPath $SourceProjectDirectory -File -Filter '*.ap20')
if ($projectFiles.Count -eq 0) {
    throw "Source directory does not contain an .ap20 project: $SourceProjectDirectory"
}
if (Test-Path -LiteralPath $DestinationDirectory) {
    throw "Destination already exists; refusing to overwrite: $DestinationDirectory"
}

New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
Get-ChildItem -LiteralPath $SourceProjectDirectory -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $DestinationDirectory -Recurse -Force
}

$projectFile = Get-ChildItem -LiteralPath $DestinationDirectory -File -Filter '*.ap20' | Select-Object -First 1
$mcp = [ordered]@{ skipped = [bool]$SkipMcp; results = @() }

if (-not $SkipMcp) {
    $invoke = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-TiaMcp.ps1'
    $calls = @(
        @{ name = 'Doctor' },
        @{ name = 'Connect' },
        @{ name = 'OpenProject'; args = @{ path = $projectFile.FullName } },
        @{ name = 'GetProjectTree' },
        @{ name = 'GetSoftwareTree'; args = @{ softwarePath = 'PLC_1'; sections = 'blocks,tags,types,sources' } },
        @{ name = 'GetPlcSummary'; args = @{ softwarePath = 'PLC_1' } },
        @{ name = 'GetBlocks'; args = @{ softwarePath = 'PLC_1'; regexName = '' } }
    )
    $results = & $invoke -Calls $calls -TiaMajor 20 -TimeoutSeconds 300
    $mcp.results = @($results | ForEach-Object {
        [ordered]@{
            tool = $_.Tool
            isError = [bool]$_.IsError
            seconds = $_.Seconds
            text = $_.Text
        }
    })
    $failed = @($results | Where-Object IsError)
    if ($failed.Count -gt 0) { throw "MCP inventory failed on $($failed[0].Tool): $($failed[0].Text)" }
}

$baseline = [ordered]@{
    schemaVersion = 1
    sourceProjectDirectory = $SourceProjectDirectory
    fixtureDirectory = $DestinationDirectory
    projectFile = $projectFile.FullName
    createdAt = [DateTimeOffset]::Now.ToString('o')
    mcp = $mcp
}
$baseline | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $DestinationDirectory 'baseline.json') -Encoding UTF8
Write-Output "E2E fixture created at $DestinationDirectory"
