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

    $fixtureServer = Join-Path $temp 'mcp-fixture.ps1'
    @'
$ErrorActionPreference = 'Stop'
while ($line = [Console]::In.ReadLine()) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $request = $line | ConvertFrom-Json
    if ($request.method -eq 'notifications/initialized') { continue }
    if ($request.method -eq 'initialize') {
        $result = [ordered]@{ protocolVersion = '2025-06-18'; capabilities = @{}; serverInfo = @{ name = 'tia-claude-fixture'; version = '1.0' } }
    }
    elseif ($request.method -eq 'tools/call') {
        $name = [string]$request.params.name
        switch ($name) {
            'GetProjectTree' { $payload = [ordered]@{ tree = "Fixture Project`n└── Fixture PLC [PLC Program]"; message = 'Project tree retrieved' } }
            'CheckDownloadReadiness' { $payload = [ordered]@{ Ready = $true; IsConsistent = $true; Message = 'ready'; Meta = @{ downloadRoutes = @(@{ pgPcInterface = 'Siemens PLCSIM Virtual Ethernet Adapter'; preferred = $true; targetInterface = '1 X1' }) } } }
            'DownloadToPlc' { $payload = [ordered]@{ State = 'Success'; Message = 'downloaded to virtual target' } }
            'GetOnlineState' { $payload = [ordered]@{ State = 'Online'; Message = 'online' } }
            default { $payload = [ordered]@{ success = $true; message = $name } }
        }
        $result = [ordered]@{ content = @(@{ type = 'text'; text = ($payload | ConvertTo-Json -Depth 20 -Compress) }) }
    }
    else { $result = [ordered]@{ content = @(@{ type = 'text'; text = '{"success":true}' }) } }
    [ordered]@{ jsonrpc = '2.0'; id = $request.id; result = $result } | ConvertTo-Json -Depth 30 -Compress
}
'@ | Set-Content -LiteralPath $fixtureServer -Encoding UTF8

    $readyPath = Join-Path $temp 'ready.json'
    [ordered]@{
        schemaVersion = 1
        status = 'READY_WITH_BLOCKERS'
        gates = [ordered]@{
            plcToolchainReady = $true
            plcsimVirtualAdapterReady = $true
            hmiRuntimeAdvancedV20Ready = $false
            plcBehaviorVerified = $false
            tiaInstanceSafeForApply = $true
        }
        blockers = @()
        nextActions = @()
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $readyPath -Encoding UTF8
    $projectFile = Join-Path $temp 'Fixture.ap20'
    'fixture project' | Set-Content -LiteralPath $projectFile -Encoding UTF8
    $positiveReportPath = Join-Path $temp 'positive.json'
    $fixtureArguments = ' -NoProfile -NonInteractive -File "' + $fixtureServer + '"'
    $fixtureOutput = & $pwsh -NoProfile -NonInteractive -File $script `
        -ReadinessPath $readyPath -OutputPath $positiveReportPath -ProjectFile $projectFile `
        -ProjectName 'Fixture Project' -SoftwarePath 'Fixture PLC' -TargetIpAddress '192.168.0.1' `
        -McpExecutablePath $pwsh -McpArguments $fixtureArguments -AcknowledgeVirtualTarget -Run 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Fixture acceptance run failed with exit code $LASTEXITCODE. Output: $fixtureOutput" }
    $positive = Get-Content -Raw -LiteralPath $positiveReportPath | ConvertFrom-Json
    if ($positive.status -ne 'VERIFIED' -or $positive.mutationAttempted -ne $true) { throw 'Fixture acceptance did not reach verified download state.' }
    $downloadCall = @($positive.calls | Where-Object name -eq 'DownloadToPlc')
    if ($downloadCall.Count -ne 1) { throw 'Fixture acceptance did not execute exactly one DownloadToPlc call.' }
    if (@($positive.preflight.selectedRoutes).Count -ne 1) { throw 'Fixture acceptance did not record the selected PLCSIM route.' }
    $global:LASTEXITCODE = 0
    Write-Output 'PASS: simulation acceptance validates the virtual route before one guarded download'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
