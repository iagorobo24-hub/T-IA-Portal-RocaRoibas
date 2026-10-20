[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch]$RunLive
)

$ErrorActionPreference = 'Stop'
$runner = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) { throw 'MCP sequence runner is missing.' }
$runnerText = Get-Content -Raw -LiteralPath $runner

# A sequence that aborts on its first failed call never reaches the CloseProject/Disconnect
# entries queued after it. The runner must therefore close the Openness session itself and
# must never leave a TIA Portal process holding the project open.
foreach ($required in @(
    'CloseProject',
    'Disconnect',
    'ConnectIsolated',
    'Siemens.Automation.Portal',
    'cleanup',
    'closedTiaProcessIds'
)) {
    if ($runnerText -notmatch [regex]::Escape($required)) { throw "Runner cleanup contract is missing: $required" }
}

# Closing a project or a TIA window is only allowed in a session the runner owns. An attach
# session belongs to the user, so the gate must key on the isolated markers, not on every run.
if ($runnerText -notmatch '\$isIsolated') { throw 'The runner must gate its cleanup on the session-ownership flag.' }
if ($runnerText -notmatch '(?s)ConnectIsolated.{0,60}\$isIsolated = \$true') {
    throw 'The runner must treat a ConnectIsolated sequence as owning its Openness session.'
}

if (-not $RunLive) {
    Write-Output 'PASS: MCP sequence runner cleanup contract is present'
    return
}

$server = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
if (-not (Test-Path -LiteralPath $server -PathType Leaf)) { throw 'tia-create V20 runtime is missing.' }
$outputPath = Join-Path $env:TEMP ('tia-claude-cleanup-' + [guid]::NewGuid().ToString('N') + '.json')
$missingProject = Join-Path $env:TEMP ('tia-claude-missing-' + [guid]::NewGuid().ToString('N') + '.ap20')
$before = @(Get-Process -Name 'Siemens.Automation.Portal' -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
try {
    # OpenProject on a missing path fails, so the sequence aborts before any CloseProject
    # entry could run: exactly the shape that used to leak the TIA session.
    $calls = @(
        [ordered]@{ name = 'ConnectIsolated'; args = @{} },
        [ordered]@{ name = 'OpenProject'; args = [ordered]@{ path = $missingProject; closeForeignProject = $false } }
    )
    $callsJson = ConvertTo-Json @($calls) -Depth 10 -Compress
    & $runner -ExecutablePath $server -Arguments '--tia-major-version 20 --profile full' -CallsJson $callsJson -OutputPath $outputPath -TimeoutSeconds 180 | Out-Null
    $report = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json

    if ($report.success -ne $false) { throw 'The failing sequence was expected to report success=false.' }
    if ($report.cleanup.attempted -ne $true) { throw 'The runner did not attempt to close the session it opened.' }
    if ($report.cleanup.sessionDisconnected -ne $true) { throw 'The runner did not disconnect the Openness session.' }
    if ($null -eq $report.cleanup.closedTiaProcessIds) { throw 'The cleanup report does not list the closed TIA processes.' }

    $after = @(Get-Process -Name 'Siemens.Automation.Portal' -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $leaked = @($after | Where-Object { $before -notcontains $_ })
    if ($leaked.Count -gt 0) { throw "The runner left TIA Portal process(es) behind: $($leaked -join ', ')" }

    Write-Output 'PASS: MCP sequence runner closes the session it opened and leaves no TIA process behind'
}
finally {
    Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $missingProject -Force -ErrorAction SilentlyContinue
}
