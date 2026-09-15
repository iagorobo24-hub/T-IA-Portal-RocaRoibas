[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$callScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolCall.ps1'
$runner = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-AgentDemoScaffold.ps1'
$specPath = Join-Path $WorkspaceRoot '50-examples\agent-demo\specs\scaffold.json'
$sourcePath = Join-Path $WorkspaceRoot '50-examples\agent-demo\sources\FB_AgentDemo.scl'
foreach ($path in @($callScript, $runner, $specPath, $sourcePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing scaffold input: $path" }
}
$spec = Get-Content -Raw -LiteralPath $specPath | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$spec.projectName)) { throw 'Scaffold spec lacks projectName.' }
if (@($spec.sclSourceFiles).Count -eq 0) { throw 'Scaffold spec lacks SCL source.' }
if (@($spec.tagTable).Count -eq 0) { throw 'Scaffold spec lacks tag table.' }
if ($spec.hmiName) { throw 'The acceptance scaffold must remain PLC-only.' }
$runnerText = Get-Content -Raw -LiteralPath $runner
if ($runnerText -notmatch 'dryRun') { throw 'Scaffold runner must enforce dry-run first.' }
if ($runnerText -notmatch 'Post-apply inspection/export') { throw 'Scaffold runner must inspect and export after apply.' }
if ($runnerText -notmatch 'ExportBlock' -or $runnerText -notmatch 'export-blocks') { throw 'Scaffold runner must verify a concrete block export.' }
if ($runnerText -notmatch 'Check-TiaStandards') { throw 'Scaffold runner must run the standards checker after apply.' }
if ($runnerText -notmatch 'Get-SessionGuard' -or $runnerText -notmatch 'visible-tia-project-open') { throw 'Scaffold runner must classify visible TIA project state before apply.' }
Write-Output 'PASS: agent-demo scaffold fixture is defined for a disposable PLC-only acceptance run'
