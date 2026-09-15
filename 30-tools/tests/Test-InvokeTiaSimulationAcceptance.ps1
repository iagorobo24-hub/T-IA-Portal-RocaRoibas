[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Invoke-TiaSimulationAcceptance.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-simulation-acceptance-test-' + [guid]::NewGuid().ToString('N'))
$readinessPath = Join-Path $temp 'readiness.json'
$reportPath = Join-Path $temp 'acceptance.json'

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    [ordered]@{
        schemaVersion = 1
        status = 'READY_WITH_BLOCKERS'
        gates = [ordered]@{
            plcToolchainReady = $true
            plcsimVirtualAdapterReady = $false
            hmiRuntimeAdvancedV20Ready = $false
            plcBehaviorVerified = $false
            tiaInstanceSafeForApply = $false
        }
        blockers = @('El adaptador virtual Siemens PLCSIM no está operativo')
        nextActions = @('Activar el adaptador virtual')
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $readinessPath -Encoding UTF8

    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }
    & $pwsh -NoProfile -NonInteractive -File $script -ReadinessPath $readinessPath -OutputPath $reportPath -Run 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 2) { throw "Blocked preflight must exit 2, got $LASTEXITCODE." }
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'Acceptance report was not created.' }

    $report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
    if ($report.status -ne 'BLOCKED' -or $report.phase -ne 'PREFLIGHT') {
        throw 'Acceptance runner did not record a blocked preflight.'
    }
    if ($report.mutationAttempted -ne $false) { throw 'Blocked preflight must not attempt mutation.' }
    if (@($report.blockers) -notcontains 'El adaptador virtual Siemens PLCSIM no está operativo') {
        throw 'Readiness blocker was not propagated to the acceptance report.'
    }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance refuses to run before all readiness gates are true'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
