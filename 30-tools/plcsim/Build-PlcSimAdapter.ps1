[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '30-tools\plcsim\bin\v6\tia-claude-plcsim-adapter.exe'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$source = Join-Path $WorkspaceRoot '30-tools\plcsim\tia_claude_plcsim_adapter.cpp'
$apiRoot = 'C:\Program Files (x86)\Common Files\Siemens\PLCSIMADV\API\6.0'
$compiler = (Get-Command clang-cl.exe -ErrorAction SilentlyContinue).Source
if (-not $compiler) { $compiler = 'C:\Program Files\LLVM\bin\clang-cl.exe' }
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Adapter source is missing: $source" }
if (-not (Test-Path -LiteralPath (Join-Path $apiRoot 'SimulationRuntimeApi.h') -PathType Leaf)) { throw 'PLCSIM Advanced V6 API header is not installed.' }
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'clang-cl is required to build the native PLCSIM adapter.' }
if ((Test-Path -LiteralPath $OutputPath -PathType Leaf) -and -not $Force) { throw "Output exists; use -Force for this exact adapter: $OutputPath" }

New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$arguments = @('/nologo', '/std:c++17', '/EHsc', '/W4', '/DUNICODE', '/D_UNICODE', "/I$apiRoot", "/Fe:$OutputPath", $source, '/link', 'Advapi32.lib')
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw "clang-cl failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) { throw "Adapter output was not produced: $OutputPath" }
Write-Output "Built native PLCSIM adapter: $OutputPath"
