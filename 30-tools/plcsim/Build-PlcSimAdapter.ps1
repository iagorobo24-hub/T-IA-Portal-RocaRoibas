[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ApiVersion,
    [string]$OutputPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$resolverPath = Join-Path $PSScriptRoot 'Resolve-PlcSimApi.ps1'
if (-not (Test-Path -LiteralPath $resolverPath -PathType Leaf)) { throw "PLCSIM API resolver is missing: $resolverPath" }
. $resolverPath
$api = Get-TiaPlcSimApiInstallation -ApiVersion $ApiVersion
if (-not $api) {
    $versionText = if ($ApiVersion) { "API $ApiVersion" } else { 'a supported PLCSIM Advanced API' }
    throw "Could not find $versionText with both the Siemens header and runtime DLL installed."
}
$apiRoot = $api.ApiRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $WorkspaceRoot "30-tools\plcsim\bin\v$($api.Major)\tia-claude-plcsim-adapter.exe"
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$source = Join-Path $WorkspaceRoot '30-tools\plcsim\tia_claude_plcsim_adapter.cpp'
$compiler = (Get-Command clang-cl.exe -ErrorAction SilentlyContinue).Source
if (-not $compiler) { $compiler = 'C:\Program Files\LLVM\bin\clang-cl.exe' }
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Adapter source is missing: $source" }
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'clang-cl is required to build the native PLCSIM adapter.' }
if ((Test-Path -LiteralPath $OutputPath -PathType Leaf) -and -not $Force) { throw "Output exists; use -Force for this exact adapter: $OutputPath" }

New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$arguments = @('/nologo', '/std:c++17', '/EHsc', '/W4', '/DUNICODE', '/D_UNICODE', "/I$apiRoot", "/Fe:$OutputPath", $source, '/link', 'Advapi32.lib')
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw "clang-cl failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) { throw "Adapter output was not produced: $OutputPath" }
Write-Output "Built native PLCSIM adapter: $OutputPath"
Write-Output "Siemens API: $($api.Version) ($($api.InterfaceVersionHex))"
