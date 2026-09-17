[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [ValidateSet('read', 'write', 'create', 'full')]
    [string]$Profile = 'read',
    [string]$OutputPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '.mcp.json'),
    [string]$LocalManifestPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '30-tools\mcp\servers.local.json'),
    [switch]$AcknowledgeWriteProfile,
    [ValidateSet(20, 21)]
    [int]$TiaMajorVersion = 20
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$LocalManifestPath = [IO.Path]::GetFullPath($LocalManifestPath)

$manifestPath = Join-Path $WorkspaceRoot '30-tools\mcp\servers.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Missing server manifest: $manifestPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$profileObject = $manifest.profiles.PSObject.Properties[$Profile].Value
if ($null -eq $profileObject) {
    throw "Unknown MCP profile '$Profile'."
}
if ($profileObject.requiresAcknowledgement -eq $true -and -not $AcknowledgeWriteProfile) {
    throw "Generating profile '$Profile' requires -AcknowledgeWriteProfile. It exposes project-mutating MCP tools."
}

$mcpServers = [ordered]@{}
foreach ($serverProperty in $profileObject.servers.PSObject.Properties) {
    $name = $serverProperty.Name
    $serverDefinition = $manifest.servers.PSObject.Properties[$name].Value
    if ($null -eq $serverDefinition) { throw "Profile '$Profile' references undefined server '$name'." }
    if ([string]$serverDefinition.status -eq 'not-installed') { throw "Profile '$Profile' references unavailable server '$name'." }

    $commandRelative = [string]$serverDefinition.commandRelative
    $baseArgs = @($serverDefinition.baseArgs)
    if ($TiaMajorVersion -ne 20) {
        $versionOverride = $serverDefinition.versions.PSObject.Properties["$TiaMajorVersion"].Value
        if ($null -eq $versionOverride) {
            throw "Server '$name' has no '$TiaMajorVersion' entry in servers.json versions."
        }
        if ($versionOverride.verified -ne $true) {
            Write-Warning "TIA V$TiaMajorVersion for '$name' is not verified on this machine yet ($($versionOverride.note)). See ADR-014."
        }
        $commandRelative = [string]$versionOverride.commandRelative
        $baseArgs = @($versionOverride.baseArgs)
    }

    $command = Join-Path $WorkspaceRoot ($commandRelative -replace '/', '\')
    if (-not (Test-Path -LiteralPath $command -PathType Leaf)) {
        throw "Server executable does not exist: $command. Build it first (e.g. 30-tools/mcp/$name/build.ps1 -TiaMajor $TiaMajorVersion)."
    }

    $args = @($baseArgs) + @($serverProperty.Value.extraArgs)
    $mcpServers[$name] = [ordered]@{
        command = $command
        args = $args
    }
}

$config = [ordered]@{ mcpServers = $mcpServers }
$outputDirectory = Split-Path -Parent $OutputPath
$manifestDirectory = Split-Path -Parent $LocalManifestPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
$config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

$local = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    profile = $Profile
    tiaMajorVersion = $TiaMajorVersion
    mcpServers = $mcpServers
}
$local | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $LocalManifestPath -Encoding UTF8

Write-Output "Generated $Profile MCP profile at $OutputPath"
Write-Output "Local manifest written to $LocalManifestPath"
$global:LASTEXITCODE = 0
exit 0
