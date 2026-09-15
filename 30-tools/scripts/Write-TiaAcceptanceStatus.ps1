[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '70-runs\acceptance\status-latest.json')
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)

function Read-JsonIfPresent([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } catch { return $null }
}

$verified = [System.Collections.Generic.List[string]]::new()
$notVerified = [System.Collections.Generic.List[string]]::new()
$blocked = [System.Collections.Generic.List[string]]::new()
$assumptions = [System.Collections.Generic.List[string]]::new()

$environment = Read-JsonIfPresent (Join-Path $WorkspaceRoot '70-runs\environment\latest.json')
if ($environment -and $environment.tiaMajor -eq 20) { $verified.Add('TIA Portal/Openness V20 baseline') }
else { $notVerified.Add('TIA Portal/Openness V20 baseline') }

$createSmoke = Read-JsonIfPresent (Join-Path $WorkspaceRoot '70-runs\environment\tia-create-smoke.json')
if ($createSmoke -and $createSmoke.success -eq $true) { $verified.Add('tia-create MCP startup and lite tool roster') }
else { $notVerified.Add('tia-create MCP startup and lite tool roster') }

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
$applyOk = $scaffold -and $scaffold.applied -eq $true -and $scaffold.apply -and $scaffold.apply.exitCode -eq 0
if ($dryRunOk) { $verified.Add('agent-demo ScaffoldProject dry-run') } else { $notVerified.Add('agent-demo ScaffoldProject dry-run') }
if ($applyOk) { $verified.Add('agent-demo real scaffold/apply') } else { $notVerified.Add('agent-demo real scaffold/apply') }

$tiaProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -like 'Siemens.Automation.Portal*' -and $_.MainWindowTitle
})
if (-not $applyOk -and $tiaProcesses.Count -gt 0) {
    $blocked.Add('TIA Portal tiene una instancia de usuario abierta; no se sustituye ni se cierra automáticamente')
}

$runtimeDoc = Join-Path $WorkspaceRoot '70-runs\simulation\runtime-advanced-v20.md'
if (Test-Path -LiteralPath $runtimeDoc -PathType Leaf) { $notVerified.Add('HMI Runtime Advanced V20 compatible y probado') }
else { $notVerified.Add('HMI Runtime Advanced V20 compatible y probado') }
$notVerified.Add('comportamiento funcional PLC probado en PLCSIM')
$notVerified.Add('PA-1 ejecutada dos veces desde sesión fría en dos harnesses')
$assumptions.Add('La compilación y el smoke MCP no demuestran comportamiento de runtime')

$result = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    accepted = ($applyOk -and $tiaProcesses.Count -eq 0 -and $notVerified.Count -eq 0 -and $blocked.Count -eq 0)
    verified = @($verified)
    notVerified = @($notVerified)
    blocked = @($blocked)
    assumptions = @($assumptions)
    evidence = [ordered]@{
        checks = Join-Path $WorkspaceRoot '70-runs\checks\latest.json'
        environment = Join-Path $WorkspaceRoot '70-runs\environment\latest.json'
        scaffold = if ($scaffoldFiles) { $scaffoldFiles[0].FullName } else { $null }
    }
}
$json = $result | ConvertTo-Json -Depth 10
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output $json
