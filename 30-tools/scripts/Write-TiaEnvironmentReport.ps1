<#!
.SYNOPSIS
    Writes a machine-readable, read-only report of the TIA-Claude environment.

.DESCRIPTION
    This script does not start TIA, open a project, install software or change any
    project. It inventories installed TIA/PLCSIM/WinCC Runtime entries and the
    workspace MCP binaries. The optional Doctor call is also diagnostic only.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '70-runs\environment\latest.json'),
    [switch]$SkipDoctor
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)

function Get-InstalledTia {
    $roots = @(
        'C:\Program Files\Siemens\Automation',
        'C:\Program Files (x86)\Siemens\Automation'
    )

    $items = foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^Portal V(?<major>\d+)$' } |
            ForEach-Object {
                $major = [int]$Matches.major
                [pscustomobject]@{
                    majorVersion = $major
                    installPath = $_.FullName
                    engineeringExists = Test-Path (Join-Path $_.FullName ("PublicAPI\V{0}\Siemens.Engineering.dll" -f $major))
                    portalExists = Test-Path (Join-Path $_.FullName 'bin\Siemens.Automation.Portal.exe')
                }
            }
    }

    @($items | Sort-Object majorVersion -Unique)
}

function Get-OpennessGroupMembership {
    try {
        $current = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $members = @(Get-LocalGroupMember -Group 'Siemens TIA Openness' -ErrorAction Stop)
        return [bool]($members | Where-Object { $_.Name -ieq $current -or $_.Name -ieq ($current -replace '^.*\\', '') })
    }
    catch {
        try {
            $text = (& net localgroup 'Siemens TIA Openness' 2>$null | Out-String)
            $current = [Security.Principal.WindowsIdentity]::GetCurrent().Name
            return ($text -match [regex]::Escape($current)) -or ($text -match [regex]::Escape(($current -replace '^.*\\', '')))
        }
        catch {
            return $null
        }
    }
}

function Get-McpServers {
    $mcpRoot = Join-Path $WorkspaceRoot '30-tools\mcp'
    if (-not (Test-Path -LiteralPath $mcpRoot -PathType Container)) { return @() }

    $items = Get-ChildItem -LiteralPath $mcpRoot -Recurse -File -Filter '*.exe' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'TiaMcpServer.exe' } |
        ForEach-Object {
            $relative = $_.FullName.Substring($WorkspaceRoot.Length).TrimStart('\').Replace('\', '/')
            [pscustomobject]@{
                name = Split-Path (Split-Path $_.DirectoryName -Parent) -Leaf
                path = $relative
                absolutePath = $_.FullName
                bytes = $_.Length
                version = $_.VersionInfo.FileVersion
            }
        }
    @($items | Sort-Object path -Unique)
}

function Get-RuntimeAdvanced {
    $entries = @()
    $registryRoots = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($root in $registryRoots) {
        $entries += Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match 'Runtime Advanced|HMIRTM|WinCC Runtime Advanced' } |
            ForEach-Object {
                [pscustomobject]@{
                    displayName = $_.DisplayName
                    displayVersion = $_.DisplayVersion
                    installLocation = $_.InstallLocation
                    installSource = $_.InstallSource
                }
            }
    }

    $runtimeExe = 'C:\Program Files (x86)\Siemens\Automation\WinCC RT Advanced\HmiRTm.exe'
    $file = $null
    if (Test-Path -LiteralPath $runtimeExe -PathType Leaf) {
        $info = Get-Item -LiteralPath $runtimeExe
        $file = [pscustomobject]@{
            path = $runtimeExe
            fileVersion = $info.VersionInfo.FileVersion
            productVersion = $info.VersionInfo.ProductVersion
        }
    }

    [pscustomobject]@{
        installedEntries = @($entries | Sort-Object displayName, displayVersion -Unique)
        executable = $file
    }
}

function Invoke-Doctor {
    if ($SkipDoctor) {
        return [pscustomobject]@{ skipped = $true; exitCode = $null; output = $null }
    }

    $server = Get-McpServers | Where-Object { $_.path -match '/v20/' } | Select-Object -First 1
    if ($null -eq $server) {
        return [pscustomobject]@{ skipped = $true; reason = 'No V20 TiaMcpServer.exe found'; exitCode = $null; output = $null }
    }

    $output = & $server.absolutePath '--tia-major-version' '20' '--doctor' 2>&1 | Out-String
    [pscustomobject]@{
        skipped = $false
        exitCode = $LASTEXITCODE
        output = $output.Trim()
    }
}

$tia = Get-InstalledTia
$report = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    workspaceRoot = $WorkspaceRoot
    tiaMajor = if ($tia | Where-Object majorVersion -eq 20) { 20 } else { $null }
    installedTia = @($tia)
    opennessGroupMember = Get-OpennessGroupMembership
    mcpServers = @(Get-McpServers)
    runtimeAdvanced = Get-RuntimeAdvanced
    doctor = Invoke-Doctor
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output "Environment report written to $OutputPath"
