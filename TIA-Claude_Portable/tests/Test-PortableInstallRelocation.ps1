[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$tempRoot = Join-Path $env:TEMP ('tia-claude-portable-install-' + [guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $tempRoot 'package'
$installedRoot = Join-Path $tempRoot 'installed'
$builder = Join-Path $WorkspaceRoot 'TIA-Claude_Portable\build\Build-PortablePackage.ps1'
$installerRelative = 'install\Install-CorePackage.ps1'

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    & $builder -WorkspaceRoot $WorkspaceRoot -OutputRoot $packageRoot
    if ($LASTEXITCODE -ne 0) { throw 'Portable package build failed.' }

    $coreSource = Join-Path $packageRoot 'TIA-Claude_Core'
    $installer = Join-Path $coreSource $installerRelative
    $verifier = Join-Path $coreSource 'install\Verify-CorePackage.ps1'
    foreach ($path in @($installer, $verifier)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Portable install artifact is missing: $path" }
    }

    & $verifier
    if ($LASTEXITCODE -ne 0) { throw 'Source core package verification failed.' }
    & $installer -DestinationRoot $installedRoot
    if ($LASTEXITCODE -ne 0) { throw 'Core package installation failed.' }

    $installedVerifier = Join-Path $installedRoot 'install\Verify-CorePackage.ps1'
    if (-not (Test-Path -LiteralPath $installedVerifier -PathType Leaf)) {
        throw 'Installed core does not contain its integrity verifier.'
    }
    & $installedVerifier
    if ($LASTEXITCODE -ne 0) { throw 'Installed core verification failed.' }

    $configPath = Join-Path $installedRoot '.mcp.json'
    $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
    $inspect = $config.mcpServers.'tia-inspect'
    $expectedServer = Join-Path $installedRoot '30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe'
    if ([IO.Path]::GetFullPath([string]$inspect.command) -ne [IO.Path]::GetFullPath($expectedServer)) {
        throw "Relocated MCP command is not rooted at the installation: $($inspect.command)"
    }
    if (@($inspect.args) -contains '--allow-write') { throw 'Relocated default profile is not read-only.' }
    if (([string]$inspect.command) -match [regex]::Escape($coreSource)) {
        throw 'Relocated MCP config retained the source package path.'
    }

    Write-Output 'PASS: portable core installs, relocates MCP paths, and remains verifiable'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
