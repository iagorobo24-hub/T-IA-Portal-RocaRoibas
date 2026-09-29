[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$EvidencePath
)

$ErrorActionPreference = 'Stop'
$build = Join-Path $WorkspaceRoot '30-tools\plcsim\Build-PlcSimAdapter.ps1'
$apiResolver = Join-Path $WorkspaceRoot '30-tools\plcsim\Resolve-PlcSimApi.ps1'
if (-not (Test-Path -LiteralPath $build -PathType Leaf)) { throw 'Native PLCSIM adapter build script is missing.' }
if (-not (Test-Path -LiteralPath $apiResolver -PathType Leaf)) { throw 'PLCSIM API resolver is missing.' }
. $apiResolver
$api = Get-TiaPlcSimApiInstallation
if (-not $api) { throw 'No Siemens PLCSIM Advanced API installation with a matching header and DLL was found.' }
$adapter = Join-Path $WorkspaceRoot "30-tools\plcsim\bin\v$($api.Major)\tia-claude-plcsim-adapter.exe"
& $build -ApiVersion $api.Version -Force | Out-Null
if (-not (Test-Path -LiteralPath $adapter -PathType Leaf)) { throw 'Native PLCSIM adapter was not built.' }

$inspectOutput = & $adapter --inspect 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "Native PLCSIM adapter inspect failed: $inspectOutput" }
$inspect = $inspectOutput | ConvertFrom-Json
if ($inspect.status -ne 'ready' -or [int64]$inspect.registeredBefore -lt 0) { throw "Native PLCSIM adapter inspect was not ready: $inspectOutput" }

$registrationOutput = & $adapter --register-inspect 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "Native PLCSIM adapter registration inspection failed: $registrationOutput" }
$registration = $registrationOutput | ConvertFrom-Json
if ($registration.status -ne 'ready' -or [int32]$registration.inspectedId -lt 0 -or
    [string]::IsNullOrWhiteSpace($registration.inspectedName) -or
    $registration.inspectedCommunicationInterface -ne 1 -or
    $registration.inspectedControllerIpCount -ne 0 -or
    $registration.registeredAfter -ne $registration.registeredBefore) {
    throw "Disposable PLCSIM registration inspection was not clean: $registrationOutput"
}

$lifecycleOutput = & $adapter --register-disposable 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "Native PLCSIM adapter lifecycle failed: $lifecycleOutput" }
$lifecycle = $lifecycleOutput | ConvertFrom-Json
if ($lifecycle.status -ne 'ready' -or $lifecycle.registerDisposable -ne $true -or
    $lifecycle.registeredAfter -ne $lifecycle.registeredBefore) {
    throw "Disposable PLCSIM lifecycle was not clean: $lifecycleOutput"
}

$runtimeOutput = & $adapter --power-on-disposable 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "Native PLCSIM disposable runtime failed: $runtimeOutput" }
$runtime = $runtimeOutput | ConvertFrom-Json
if ($runtime.status -ne 'ready' -or $runtime.powerOnDisposable -ne $true -or
    $runtime.powerOnCode -ne '0x0' -or $runtime.powerOffCode -ne '0x0' -or
    $runtime.registeredAfter -ne $runtime.registeredBefore) {
    throw "Disposable PLCSIM power cycle was not clean: $runtimeOutput"
}

# Probe the persistent acceptance path with an impossible adapter name. It must
# refuse before registration/power-on and return the available adapter list;
# this remains safe on machines where the real Siemens adapter is configured.
$acceptanceOutput = & $adapter --register-acceptance --transport softbus --interface '__TIA_CLAUDE_TEST_NO_SUCH_ADAPTER__' 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) { throw "Acceptance probe unexpectedly started a CPU: $acceptanceOutput" }
$acceptanceJsonLine = @($acceptanceOutput -split "`r?`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1)
if ($acceptanceJsonLine.Count -ne 1) { throw "Acceptance path returned no JSON diagnostics: $acceptanceOutput" }
$acceptance = $acceptanceJsonLine | ConvertFrom-Json
if ($acceptance.status -ne 'failed' -or $acceptance.stage -ne 'unsupported-interface-argument') {
    throw "Acceptance path did not reject the unsupported adapter override before starting a PLC: $acceptanceOutput"
}
$evidence = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString('o')
    status = 'PASS'
    api = [ordered]@{ version = $api.Version; interfaceVersion = $api.InterfaceVersionHex; dllPath = $api.DllPath }
    adapterPath = $adapter
    inspect = $inspect
    registrationInspection = $registration
    disposableLifecycle = $lifecycle
    disposablePowerCycle = $runtime
    invalidInterfaceGuard = $acceptance
    tiaProjectOpened = $false
    projectDownloadAttempted = $false
}
if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
    $EvidencePath = [IO.Path]::GetFullPath($EvidencePath)
    New-Item -ItemType Directory -Path (Split-Path -Parent $EvidencePath) -Force | Out-Null
    $evidence | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $EvidencePath -Encoding UTF8
}
Write-Output 'PASS: native PLCSIM adapter inspects, powers on/off, cleans up, and gates persistent acceptance'
