[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [ValidateSet('claude-code', 'codex', 'opencode')]
    [string]$Harness,
    [ValidateSet('read', 'write', 'create', 'full')]
    [string]$Profile = 'read',
    [Parameter(Mandatory)]
    [string]$OutputPath,
    [switch]$AcknowledgeWriteProfile
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$manifestPath = Join-Path $WorkspaceRoot '30-tools\mcp\servers.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Missing server manifest: $manifestPath" }

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$profileObject = $manifest.profiles.PSObject.Properties[$Profile].Value
if ($null -eq $profileObject) { throw "Unknown MCP profile '$Profile'." }
if ($profileObject.requiresAcknowledgement -eq $true -and -not $AcknowledgeWriteProfile) {
    throw "Generating profile '$Profile' requires -AcknowledgeWriteProfile."
}

$entries = [System.Collections.Generic.List[object]]::new()
foreach ($serverProperty in $profileObject.servers.PSObject.Properties) {
    $name = $serverProperty.Name
    $serverDefinition = $manifest.servers.PSObject.Properties[$name].Value
    if ($null -eq $serverDefinition) { throw "Profile '$Profile' references undefined server '$name'." }
    if ([string]$serverDefinition.status -eq 'not-installed') { throw "Profile '$Profile' references unavailable server '$name'." }
    $command = Join-Path $WorkspaceRoot ($serverDefinition.commandRelative -replace '/', '\')
    if (-not (Test-Path -LiteralPath $command -PathType Leaf)) { throw "Server executable does not exist: $command" }
    $args = @($serverDefinition.baseArgs) + @($serverProperty.Value.extraArgs)
    $entries.Add([pscustomobject]@{ name = $name; command = $command; args = @($args) })
}

function ConvertTo-TomlString([string]$Value) {
    return '"' + ($Value -replace '\\', '\\' -replace '"', '\"') + '"'
}

function ConvertTo-JsonObject {
    $servers = [ordered]@{}
    foreach ($entry in $entries) {
        $servers[$entry.name] = [ordered]@{ command = $entry.command; args = $entry.args }
    }
    return [ordered]@{ mcpServers = $servers }
}

function ConvertTo-OpenCodeObject {
    $servers = [ordered]@{}
    foreach ($entry in $entries) {
        $servers[$entry.name] = [ordered]@{
            type = 'local'
            command = @($entry.command) + @($entry.args)
            enabled = $true
            timeout = 120000
        }
    }
    return [ordered]@{ '$schema' = 'https://opencode.ai/config.json'; mcp = $servers }
}

function ConvertTo-CodexToml {
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $entries) {
        $safeName = $entry.name -replace '[^A-Za-z0-9_-]', '_'
        $lines.Add("[mcp_servers.$safeName]")
        $lines.Add("command = $(ConvertTo-TomlString $entry.command)")
        $quotedArgs = @($entry.args | ForEach-Object { ConvertTo-TomlString ([string]$_) }) -join ', '
        $lines.Add("args = [$quotedArgs]")
        $lines.Add('startup_timeout_sec = 120')
        $lines.Add('')
    }
    return ($lines -join [Environment]::NewLine).TrimEnd() + [Environment]::NewLine
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
switch ($Harness) {
    'claude-code' { (ConvertTo-JsonObject | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $OutputPath -Encoding UTF8 }
    'opencode' { (ConvertTo-OpenCodeObject | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $OutputPath -Encoding UTF8 }
    'codex' { ConvertTo-CodexToml | Set-Content -LiteralPath $OutputPath -Encoding UTF8 }
}

Write-Output "Exported $Harness $Profile adapter to $OutputPath"
