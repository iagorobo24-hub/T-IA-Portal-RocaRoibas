[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$build = Join-Path $WorkspaceRoot '30-tools\plcsim\Build-PlcSimAdapter.ps1'
$adapter = Join-Path $WorkspaceRoot '30-tools\plcsim\bin\v6\tia-claude-plcsim-adapter.exe'
if (-not (Test-Path -LiteralPath $build -PathType Leaf)) { throw 'Native PLCSIM adapter build script is missing.' }
& $build -Force | Out-Null
if (-not (Test-Path -LiteralPath $adapter -PathType Leaf)) { throw 'Native PLCSIM adapter was not built.' }

$inspectOutput = & $adapter --inspect 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "Native PLCSIM adapter inspect failed: $inspectOutput" }
$inspect = $inspectOutput | ConvertFrom-Json
if ($inspect.status -ne 'ready' -or [int64]$inspect.registeredBefore -lt 0) { throw "Native PLCSIM adapter inspect was not ready: $inspectOutput" }

$lifecycleOutput = & $adapter --register-disposable 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "Native PLCSIM adapter lifecycle failed: $lifecycleOutput" }
$lifecycle = $lifecycleOutput | ConvertFrom-Json
if ($lifecycle.status -ne 'ready' -or $lifecycle.registerDisposable -ne $true -or
    $lifecycle.registeredAfter -ne $lifecycle.registeredBefore) {
    throw "Disposable PLCSIM lifecycle was not clean: $lifecycleOutput"
}
Write-Output 'PASS: native PLCSIM adapter inspects and unregisters a disposable CPU without powering on'
