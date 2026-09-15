[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '70-runs\checks\latest.json')
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }

$definitions = @(
    @{ name = 'environment'; path = '30-tools/tests/Test-EnvironmentReport.ps1' },
    @{ name = 'documentation'; path = '30-tools/tests/Test-DocumentationState.ps1' },
    @{ name = 'knowledge'; path = '30-tools/tests/Test-KnowledgeIndex.ps1' },
    @{ name = 'hmi-knowledge'; path = '30-tools/tests/Test-HmiKnowledgeState.ps1' },
    @{ name = 'server-manifest'; path = '30-tools/tests/Test-ServerManifest.ps1' },
    @{ name = 'harness-config'; path = '30-tools/tests/Test-HarnessConfigDocs.ps1' },
    @{ name = 'harness-adapters'; path = '30-tools/tests/Test-ExportHarnessAdapter.ps1' },
    @{ name = 'public-boundary'; path = '30-tools/tests/Test-PublicBoundary.ps1' },
    @{ name = 'tia-create-availability'; path = '30-tools/tests/Test-TiaCreateAvailability.ps1' },
    @{ name = 'tia-create-runtime'; path = '30-tools/tests/Test-TiaCreateRuntime.ps1' },
    @{ name = 'mcp-tool-sequence'; path = '30-tools/tests/Test-McpToolSequence.ps1' },
    @{ name = 'plcsim-api-probe'; path = '30-tools/tests/Test-PlcSimRuntimeApiProbe.ps1' },
    @{ name = 'agent-demo-scaffold'; path = '30-tools/tests/Test-AgentDemoScaffoldEvidence.ps1' },
    @{ name = 'write-e2e-evidence'; path = '30-tools/tests/Test-TiaWriteE2E.ps1' },
    @{ name = 'backup-recovery'; path = '30-tools/tests/Test-TiaBackupRecovery.ps1' },
    @{ name = 'standards-sweep-evidence'; path = '30-tools/tests/Test-StandardsSweepEvidence.ps1' },
    @{ name = 'acceptance-status'; path = '30-tools/tests/Test-TiaAcceptanceStatus.ps1' },
    @{ name = 'runtime-media-discovery'; path = '30-tools/tests/Test-FindTiaRuntimeMedia.ps1' },
    @{ name = 'simulation-readiness'; path = '30-tools/tests/Test-SimulationReadiness.ps1' }
)

$checks = [System.Collections.Generic.List[object]]::new()
foreach ($definition in $definitions) {
    $path = Join-Path $WorkspaceRoot ($definition.path -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $checks.Add([ordered]@{ name = $definition.name; status = 'BLOCKED'; message = "Missing check: $($definition.path)" })
        continue
    }
    $output = (& $pwsh -NoProfile -NonInteractive -File $path 2>&1 | Out-String).Trim()
    $exitCode = $LASTEXITCODE
    $status = if ($exitCode -eq 0) { 'PASS' } else { 'BLOCKED' }
    $checks.Add([ordered]@{
        name = $definition.name
        status = $status
        exitCode = $exitCode
        message = if ($output.Length -gt 1000) { $output.Substring(0, 1000) } else { $output }
    })
}

$standardsInventory = Join-Path $WorkspaceRoot '70-runs\standards\iot-baseline-inventory.json'
$latestE2EReport = Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'report.json' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
$standardsExport = $null
if ($latestE2EReport) {
    try {
        $latestE2E = Get-Content -LiteralPath $latestE2EReport.FullName -Raw | ConvertFrom-Json
        if ($latestE2E.export.success -eq $true -and $latestE2E.export.path) {
            $standardsExport = [IO.Path]::GetFullPath([string]$latestE2E.export.path)
        }
    }
    catch {
        $standardsExport = $null
    }
}
$standardsChecker = Join-Path $WorkspaceRoot '30-tools\scripts\Check-TiaStandards.ps1'
if ((Test-Path -LiteralPath $standardsInventory -PathType Leaf) -and
    $standardsExport -and
    (Test-Path -LiteralPath $standardsExport -PathType Container) -and
    (Test-Path -LiteralPath $standardsChecker -PathType Leaf)) {
    $standardsOutput = (& $pwsh -NoProfile -NonInteractive -File $standardsChecker -InventoryPath $standardsInventory -ExportPath $standardsExport 2>&1 | Out-String).Trim()
    $standardsExit = $LASTEXITCODE
    $checks.Add([ordered]@{ name = 'standards'; status = $(if ($standardsExit -eq 0) { 'PASS' } else { 'BLOCKED' }); exitCode = $standardsExit; message = if ($standardsOutput.Length -gt 1000) { $standardsOutput.Substring(0, 1000) } else { $standardsOutput } })
}
else {
    $checks.Add([ordered]@{ name = 'standards'; status = 'WARN'; message = 'No live standards inventory/export pair is available.' })
}

$coreVerifier = Join-Path $WorkspaceRoot 'TIA-Claude_Portable\dist\TIA-Claude_Core\install\Verify-CorePackage.ps1'
if (Test-Path -LiteralPath $coreVerifier -PathType Leaf) {
    $packageOutput = (& $pwsh -NoProfile -NonInteractive -File $coreVerifier 2>&1 | Out-String).Trim()
    $packageExit = $LASTEXITCODE
    $checks.Add([ordered]@{ name = 'portable-core'; status = $(if ($packageExit -eq 0) { 'PASS' } else { 'BLOCKED' }); exitCode = $packageExit; message = $packageOutput })
}
else {
    $checks.Add([ordered]@{ name = 'portable-core'; status = 'WARN'; message = 'Portable core distribution has not been built.' })
}

$gitStatus = if (Test-Path -LiteralPath (Join-Path $WorkspaceRoot '.git') -PathType Container) { 'present' } else { 'not-initialized' }
$checks.Add([ordered]@{ name = 'git'; status = $(if ($gitStatus -eq 'present') { 'PASS' } else { 'WARN' }); message = "Git repository: $gitStatus. No automatic initialization is performed." })

$blocked = @($checks | Where-Object { $_.status -eq 'BLOCKED' })
$warnings = @($checks | Where-Object { $_.status -eq 'WARN' })
$report = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    workspaceRoot = $WorkspaceRoot
    success = ($blocked.Count -eq 0)
    summary = [ordered]@{ pass = @($checks | Where-Object status -eq 'PASS').Count; warn = $warnings.Count; blocked = $blocked.Count }
    checks = @($checks)
}
$json = $report | ConvertTo-Json -Depth 10
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output $json
if ($blocked.Count -gt 0) { exit 1 }
$global:LASTEXITCODE = 0
exit 0
