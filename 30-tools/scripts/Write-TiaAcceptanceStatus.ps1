[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '70-runs\acceptance\status-latest.json'),
    [string]$ChecksPath,
    [string]$EnvironmentPath,
    [string]$ReadinessPath,
    [string]$PortableValidationPath,
    [string]$PortableCoreManifestPath
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $ChecksPath) { $ChecksPath = Join-Path $WorkspaceRoot '70-runs\checks\latest.json' }
if (-not $EnvironmentPath) { $EnvironmentPath = Join-Path $WorkspaceRoot '70-runs\environment\latest.json' }
if (-not $ReadinessPath) { $ReadinessPath = Join-Path $WorkspaceRoot '70-runs\simulation\readiness-latest.json' }
if (-not $PortableCoreManifestPath) { $PortableCoreManifestPath = Join-Path $WorkspaceRoot 'TIA-Claude_Portable\dist\TIA-Claude_Core\manifests\package-manifest.json' }
$ChecksPath = [IO.Path]::GetFullPath($ChecksPath)
$EnvironmentPath = [IO.Path]::GetFullPath($EnvironmentPath)
$ReadinessPath = [IO.Path]::GetFullPath($ReadinessPath)
$PortableCoreManifestPath = [IO.Path]::GetFullPath($PortableCoreManifestPath)

function Read-JsonIfPresent([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } catch { return $null }
}

$verified = [System.Collections.Generic.List[string]]::new()
$notVerified = [System.Collections.Generic.List[string]]::new()
$blocked = [System.Collections.Generic.List[string]]::new()
$assumptions = [System.Collections.Generic.List[string]]::new()

$checks = Read-JsonIfPresent $ChecksPath
function Has-PassingCheck([string]$Name) {
    return [bool]($checks -and @($checks.checks | Where-Object { $_.name -eq $Name -and $_.status -eq 'PASS' }).Count -gt 0)
}

$environment = Read-JsonIfPresent $EnvironmentPath
$activeTiaMajor = if ($environment -and $environment.tiaMajor) {
    [int]$environment.tiaMajor
} elseif ($environment -and $environment.activeTiaMajorVersion) {
    [int]$environment.activeTiaMajorVersion
} elseif ($environment -and $environment.calls -and $environment.calls[0].response.structuredContent.activeTiaMajorVersion) {
    [int]$environment.calls[0].response.structuredContent.activeTiaMajorVersion
} else { $null }
if ($activeTiaMajor -eq 20) { $verified.Add('TIA Portal/Openness V20 baseline') }
else { $notVerified.Add('TIA Portal/Openness V20 baseline') }

$createSmoke = Read-JsonIfPresent (Join-Path $WorkspaceRoot '70-runs\environment\tia-create-smoke.json')
if ($createSmoke -and $createSmoke.success -eq $true) { $verified.Add('tia-create MCP startup and lite tool roster') }
else { $notVerified.Add('tia-create MCP startup and lite tool roster') }

$portableValidation = if ($PortableValidationPath) { Read-JsonIfPresent ([IO.Path]::GetFullPath($PortableValidationPath)) } else { $null }
$portableChecks = if ($portableValidation -and $portableValidation.checks) { @($portableValidation.checks.PSObject.Properties | ForEach-Object { $_.Value.status }) } else { @() }
$portableOk = $portableValidation -and $portableChecks.Count -gt 0 -and (@($portableChecks | Where-Object { $_ -ne 'PASS' }).Count -eq 0)
if ($portableOk -or (-not $portableValidation -and (Has-PassingCheck 'portable-install-relocation'))) { $verified.Add('portable core installation and relocation') }
else { $notVerified.Add('portable core installation and relocation') }

if (Has-PassingCheck 'harness-adapters') { $verified.Add('deterministic cross-harness MCP adapters') }
else { $notVerified.Add('deterministic cross-harness MCP adapters') }

$sweep = Read-JsonIfPresent (Join-Path $WorkspaceRoot '70-runs\standards\sweep-20260915-all\sweep-report.json')
if ($sweep -and $sweep.success -eq $true -and $sweep.collectionErrorCount -eq 0) { $verified.Add('read-only inventory of all seven examples') }
else { $notVerified.Add('read-only inventory of all seven examples') }

$writeReports = @(Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'report.json' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending)
$writeReport = $null
foreach ($candidate in $writeReports) {
    $parsed = Read-JsonIfPresent $candidate.FullName
    if ($parsed -and $parsed.compile -and $parsed.save -and $parsed.export) { $writeReport = $parsed; break }
}
if ($writeReport -and $writeReport.compile.success -eq $true -and $writeReport.save.success -eq $true -and $writeReport.export.success -eq $true) { $verified.Add('reversible write loop with compile/save/export evidence') }
else { $notVerified.Add('reversible write loop with compile/save/export evidence') }

$scaffoldFiles = @(Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'scaffold-report.json' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending)
$scaffold = if ($scaffoldFiles) { Read-JsonIfPresent $scaffoldFiles[0].FullName } else { $null }
$dryRunOk = $scaffold -and $scaffold.dryRun -and $scaffold.dryRun.exitCode -eq 0
# A historical scaffold report with compile 0/0 is not enough. The current
# runner must prove that creation, CloseProject, and Disconnect happened in the
# same MCP sequence before its isolated post-readback is accepted.
$applySequence = if ($scaffold -and $scaffold.apply -and $scaffold.apply.report) { $scaffold.apply.report.sequence } else { $null }
$closeInSequence = if ($applySequence -and $applySequence.calls) { @($applySequence.calls | Where-Object { $_.name -eq 'CloseProject' -and $_.success -eq $true }).Count -gt 0 } else { $false }
$disconnectInSequence = if ($applySequence -and $applySequence.calls) { @($applySequence.calls | Where-Object { $_.name -eq 'Disconnect' -and $_.success -eq $true }).Count -gt 0 } else { $false }
$applyOk = $scaffold -and $scaffold.applied -eq $true -and $scaffold.apply -and $scaffold.apply.exitCode -eq 0 -and $scaffold.postApply -and $scaffold.postApply.success -eq $true -and $closeInSequence -and $disconnectInSequence
if ($dryRunOk) { $verified.Add('agent-demo ScaffoldProject dry-run') } else { $notVerified.Add('agent-demo ScaffoldProject dry-run') }
if ($applyOk) { $verified.Add('agent-demo real scaffold/apply') } else { $notVerified.Add('agent-demo real scaffold/apply') }

$tiaProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -like 'Siemens.Automation.Portal*' -and $_.MainWindowTitle
})
# The session guard is authoritative for the current scaffold run: a visible
# TIA start window with no project is allowed, while an unidentified/open
# project remains a blocker.
$visibleTiaAllowed = $scaffold -and $scaffold.sessionGuard -and $scaffold.sessionGuard.allowed -eq $true
if (-not $applyOk -and $tiaProcesses.Count -gt 0 -and -not $visibleTiaAllowed) {
    $blocked.Add('TIA Portal tiene una instancia de usuario abierta; no se sustituye ni se cierra automáticamente')
}

$readiness = Read-JsonIfPresent $ReadinessPath
$runtimeDoc = Join-Path $WorkspaceRoot '70-runs\simulation\runtime-advanced-v20.md'
$runtimeVerified = $readiness -and $readiness.gates -and $readiness.gates.hmiRuntimeAdvancedV20Ready -eq $true
if ((Test-Path -LiteralPath $runtimeDoc -PathType Leaf) -and $runtimeVerified) {
    $verified.Add('HMI Runtime Advanced V20 compatible y probado')
} else {
    $notVerified.Add('HMI Runtime Advanced V20 compatible y probado')
}
if ($readiness -and $readiness.readOnly -eq $true -and $readiness.gates) {
    $verified.Add('preflight determinista de preparación para simulación')
} else {
    $notVerified.Add('preflight determinista de preparación para simulación')
}
if ($readiness -and $readiness.gates -and $readiness.gates.plcsimVirtualAdapterReady -ne $true) {
    $blocked.Add('El adaptador virtual Siemens PLCSIM no está operativo')
}
if ($readiness -and $readiness.gates -and $readiness.gates.hmiRuntimeAdvancedV20Ready -ne $true) {
    $blocked.Add('WinCC Runtime Advanced V20 compatible no está verificado')
}
$notVerified.Add('comportamiento funcional PLC probado en PLCSIM')
$notVerified.Add('PA-1 ejecutada dos veces desde sesión fría en dos harnesses')
$assumptions.Add('La compilación y el smoke MCP no demuestran comportamiento de runtime')

$result = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    accepted = ($applyOk -and (($tiaProcesses.Count -eq 0) -or $visibleTiaAllowed) -and $notVerified.Count -eq 0 -and $blocked.Count -eq 0)
    verified = @($verified)
    notVerified = @($notVerified)
    blocked = @($blocked)
    assumptions = @($assumptions)
    checks = if ($checks) {
        [ordered]@{
            success = $checks.success
            summary = $checks.summary
            generatedAt = $checks.generatedAt
        }
    } else { $null }
    evidence = [ordered]@{
        checks = $ChecksPath
        environment = $EnvironmentPath
        simulationReadiness = if (Test-Path -LiteralPath $ReadinessPath -PathType Leaf) { $ReadinessPath } else { $null }
        scaffold = if ($scaffoldFiles) { $scaffoldFiles[0].FullName } else { $null }
        portableValidation = if ($PortableValidationPath) { [IO.Path]::GetFullPath($PortableValidationPath) } else { $null }
        portableCoreManifest = $PortableCoreManifestPath
    }
}
$json = $result | ConvertTo-Json -Depth 10
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output $json
