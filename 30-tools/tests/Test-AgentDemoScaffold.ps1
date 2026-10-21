[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$callScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolCall.ps1'
$runner = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-TiaProjectFromSpec.ps1'
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
$sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
if ($sourceBytes.Length -lt 3 -or $sourceBytes[0] -ne 0xEF -or $sourceBytes[1] -ne 0xBB -or $sourceBytes[2] -ne 0xBF) {
    throw 'Agent-demo SCL source must be UTF-8 with BOM so Siemens preserves non-ASCII comments.'
}
$sourceText = [Text.Encoding]::UTF8.GetString($sourceBytes)
if ($sourceText -notmatch 'Bloque mínimo') { throw 'Agent-demo source lost its Spanish block comment.' }
$runnerText = Get-Content -Raw -LiteralPath $runner
if ($runnerText -notmatch 'dryRun') { throw 'Scaffold runner must enforce dry-run first.' }
if ($runnerText -notmatch 'Post-apply inspection/export') { throw 'Scaffold runner must inspect and export after apply.' }
if ($runnerText -notmatch 'ExportBlock' -or $runnerText -notmatch 'export-blocks') { throw 'Scaffold runner must verify a concrete block export.' }
if ($runnerText -notmatch 'Check-TiaStandards') { throw 'Scaffold runner must run the standards checker after apply.' }
if ($runnerText -notmatch 'Get-SessionGuard' -or $runnerText -notmatch 'visible-tia-project-open') { throw 'Scaffold runner must classify visible TIA project state before apply.' }
if ($runnerText -notmatch 'New-TiaFixtureManifest' -or $runnerText -notmatch '-Isolated' -or $runnerText -notmatch '-FixtureRoot') {
    throw 'Scaffold post-apply inspection must use a manifest-backed isolated tia-inspect fixture.'
}
if ($runnerText -match '\$openResults\s*=\s*&\s*\$invoke\s+-TiaMajor') {
    throw 'Scaffold OpenProject verification must use the same isolated inspection helper as GetState.'
}
if ($runnerText -notmatch 'Invoke-ScaffoldApplySequence' -or $runnerText -notmatch 'ScaffoldProject.{0,300}CloseProject') {
    throw 'Scaffold apply must close the tia-create project in the same MCP session before post-apply inspection.'
}
if ($runnerText -notmatch 'backup' -or $runnerText -notmatch 'Copy-Item') {
    throw 'Scaffold post-apply inspection must preserve a matching backup before reading the project.'
}
Write-Output 'PASS: agent-demo scaffold fixture is defined for a disposable PLC-only acceptance run'
