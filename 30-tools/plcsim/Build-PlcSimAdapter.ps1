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
if (Test-Path -LiteralPath $compiler -PathType Leaf) {
    # A native compiler writes warnings to stderr; with $ErrorActionPreference = 'Stop' that
    # stderr becomes a terminating NativeCommandError and a successful build looks failed.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $compiler @arguments 2>&1 | ForEach-Object { Write-Output $_ } }
    finally { $ErrorActionPreference = $previousPreference }
    if ($LASTEXITCODE -ne 0) { throw "clang-cl failed with exit code $LASTEXITCODE" }
}
else {
    # Fallback for hosts without LLVM: the Visual Studio Build Tools ship MSVC, which compiles
    # this translation unit unchanged (it has no clang-only constructs). vcvars64.bat has to
    # set INCLUDE/LIB, so the compile runs inside a cmd shell.
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $buildTools = if (Test-Path -LiteralPath $vswhere) {
        & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    } else { $null }
    if (-not $buildTools) { throw 'clang-cl is required to build the native PLCSIM adapter and no Visual Studio Build Tools were found.' }
    $vcvars = Join-Path $buildTools 'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path -LiteralPath $vcvars -PathType Leaf)) { throw "vcvars64.bat is missing: $vcvars" }
    $quoted = @($arguments | ForEach-Object { "`"$_`"" }) -join ' '
    $buildOutput = cmd /c "`"$vcvars`" >nul 2>&1 && cl $quoted" 2>&1
    $buildOutput | ForEach-Object { Write-Output $_ }
    if ($LASTEXITCODE -ne 0) { throw "MSVC cl.exe failed with exit code $LASTEXITCODE" }
}
if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) { throw "Adapter output was not produced: $OutputPath" }
Write-Output "Built native PLCSIM adapter: $OutputPath"
Write-Output "Siemens API: $($api.Version) ($($api.InterfaceVersionHex))"
