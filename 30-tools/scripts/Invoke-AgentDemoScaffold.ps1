<##
.SYNOPSIS
    Valida y, opcionalmente, genera el proyecto AgentDemo en una carpeta desechable.

.DESCRIPTION
    El comportamiento por defecto es SOLO DRY-RUN: no conecta a TIA ni crea nada.
    Con -Apply, y solo después de un dry-run limpio, llama a ScaffoldProject con
    dryRun=false. El destino debe no existir y siempre queda un informe JSON.
##>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ProjectDirectory,
    [string]$OutputRoot,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
if (-not $OutputRoot) { $OutputRoot = Join-Path $WorkspaceRoot ('70-runs\e2e\agent-demo-scaffold-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (-not $ProjectDirectory) { $ProjectDirectory = Join-Path $WorkspaceRoot ('90-tmp\agent-demo-scaffold-v20-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$ProjectDirectory = [IO.Path]::GetFullPath($ProjectDirectory)
if ($Apply -and (Test-Path -LiteralPath $ProjectDirectory)) { throw "Apply destination already exists: $ProjectDirectory" }

$templatePath = Join-Path $WorkspaceRoot '50-examples\agent-demo\specs\scaffold.json'
$sourcePath = Join-Path $WorkspaceRoot '50-examples\agent-demo\sources\FB_AgentDemo.scl'
$exe = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
$callScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolCall.ps1'
foreach ($path in @($templatePath, $sourcePath, $exe, $callScript)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing scaffold input: $path" }
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$spec = Get-Content -Raw -LiteralPath $templatePath | ConvertFrom-Json
$spec.projectName = 'AgentDemo_V20'
$spec.directoryPath = $ProjectDirectory
$spec.sclSourceFiles = @($sourcePath)
$specJson = $spec | ConvertTo-Json -Depth 30 -Compress
$effectiveSpecPath = Join-Path $OutputRoot 'spec-effective.json'
$spec | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $effectiveSpecPath -Encoding UTF8
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }

function Invoke-ScaffoldCall([bool]$DryRun, [string]$ReportPath) {
    $toolArgs = @{ spec = $specJson; dryRun = $DryRun } | ConvertTo-Json -Depth 30 -Compress
    $callArgs = @(
        '-NoProfile', '-NonInteractive', '-File', $callScript,
        '-ExecutablePath', $exe,
        '-Arguments', '--tia-major-version 20 --profile lite --logging 1',
        '-ToolName', 'ScaffoldProject',
        '-ToolArgumentsJson', $toolArgs,
        '-OutputPath', $ReportPath,
        '-TimeoutSeconds', '900'
    )
    $output = (& $pwsh @callArgs 2>&1 | Out-String).Trim()
    $exitCode = $LASTEXITCODE
    $parsed = if (Test-Path -LiteralPath $ReportPath -PathType Leaf) { Get-Content -Raw -LiteralPath $ReportPath | ConvertFrom-Json } else { $null }
    [pscustomobject]@{ dryRun = $DryRun; exitCode = $exitCode; reportPath = $ReportPath; output = $output; report = $parsed }
}

$dryRunResult = Invoke-ScaffoldCall $true (Join-Path $OutputRoot 'dry-run.json')
if ($dryRunResult.exitCode -ne 0 -or -not $dryRunResult.report.success) {
    $final = [ordered]@{ schemaVersion = 1; success = $false; applied = $false; effectiveSpec = $effectiveSpecPath; dryRun = $dryRunResult }
}
elseif (-not $Apply) {
    $final = [ordered]@{ schemaVersion = 1; success = $true; applied = $false; effectiveSpec = $effectiveSpecPath; dryRun = $dryRunResult; message = 'Dry-run passed; use -Apply to create the disposable project.' }
}
else {
    $applyResult = Invoke-ScaffoldCall $false (Join-Path $OutputRoot 'apply.json')
    $final = [ordered]@{ schemaVersion = 1; success = ($applyResult.exitCode -eq 0 -and $applyResult.report.success); applied = $true; effectiveSpec = $effectiveSpecPath; dryRun = $dryRunResult; apply = $applyResult; projectDirectory = $ProjectDirectory }
}
$finalPath = Join-Path $OutputRoot 'scaffold-report.json'
$final | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $finalPath -Encoding UTF8
Write-Output ($final | ConvertTo-Json -Depth 10)
Write-Host "Evidence: $finalPath" -ForegroundColor Green
if (-not $final.success) { exit 1 }
exit 0
