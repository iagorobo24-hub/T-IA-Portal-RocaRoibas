<#
.SYNOPSIS
    Aplica una pantalla HMI Unified y sus bindings a partir de un JSON, sobre un proyecto ya
    abierto en TIA.

.DESCRIPTION
    Recibe un JSON con la forma de 50-examples/demo-cinta01/hmi-screen.json:
      hmiSoftwarePath, screenName, width, height
      items[]             {name, type, left, top, width, height, text?}
      buttonActions[]     {buttonName, eventType, actionKind, targetTag}
      tagDynamizations[]  {itemName, propertyName, tagName, dataType?}

    Crea la pantalla, anade los controles y liga botones y elementos a sus tags HMI. Todas
    las herramientas son idempotentes, asi que se puede repetir sin miedo. Guarda el proyecto
    al final y cierra la sesion.

    Con -DryRun solo valida el JSON y lista las llamadas que haria, sin conectar con TIA.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [Parameter(Mandatory = $true)]
    [string]$ScreenJsonPath,
    [string]$ProjectFile,
    [string]$ProjectName,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$ScreenJsonPath = [IO.Path]::GetFullPath($ScreenJsonPath)
if (-not (Test-Path -LiteralPath $ScreenJsonPath -PathType Leaf)) { throw "Screen JSON not found: $ScreenJsonPath" }
$spec = Get-Content -Raw -LiteralPath $ScreenJsonPath | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$spec.screenName)) { throw 'The screen JSON needs a screenName.' }
if (-not $spec.hmiSoftwarePath) { $spec.hmiSoftwarePath = 'HMI_RT_1' }

$calls = @()
$calls += [ordered]@{ name = 'EnsureUnifiedHmiScreen'; args = [ordered]@{
    hmiSoftwarePath = [string]$spec.hmiSoftwarePath
    screenName = [string]$spec.screenName
    width = [int]$(if ($spec.width) { $spec.width } else { 0 })
    height = [int]$(if ($spec.height) { $spec.height } else { 0 })
} }
foreach ($item in @($spec.items)) {
    $args = [ordered]@{
        hmiSoftwarePath = [string]$spec.hmiSoftwarePath
        screenName = [string]$spec.screenName
        itemName = [string]$item.name
        itemType = [string]$item.type
        left = [int]$item.left
        top = [int]$item.top
        width = [int]$item.width
        height = [int]$item.height
    }
    if ($item.text) { $args.text = [string]$item.text }
    $calls += [ordered]@{ name = 'EnsureUnifiedHmiScreenItem'; args = $args }
}
foreach ($action in @($spec.buttonActions)) {
    $calls += [ordered]@{ name = 'EnsureUnifiedHmiButtonAction'; args = [ordered]@{
        hmiSoftwarePath = [string]$spec.hmiSoftwarePath
        screenName = [string]$spec.screenName
        buttonName = [string]$action.buttonName
        eventType = [string]$action.eventType
        actionKind = [string]$action.actionKind
        targetTag = [string]$action.targetTag
        syntaxCheck = $false
    } }
}
foreach ($dynamization in @($spec.tagDynamizations)) {
    $args = [ordered]@{
        hmiSoftwarePath = [string]$spec.hmiSoftwarePath
        screenName = [string]$spec.screenName
        itemName = [string]$dynamization.itemName
        propertyName = [string]$dynamization.propertyName
        tagName = [string]$dynamization.tagName
    }
    if ($dynamization.dataType) { $args.dataType = [string]$dynamization.dataType }
    $calls += [ordered]@{ name = 'BindUnifiedHmiTagDynamization'; args = $args }
}

if ($DryRun) {
    $summary = [ordered]@{
        schemaVersion = 1
        success = $true
        applied = $false
        screenJsonPath = $ScreenJsonPath
        screenName = [string]$spec.screenName
        calls = @($calls | ForEach-Object { $_.name })
    }
    $summary | ConvertTo-Json -Depth 10
    return
}

$exe = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
$sequenceScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "MCP server not found: $exe" }
if ($ProjectFile) { $ProjectFile = [IO.Path]::GetFullPath($ProjectFile) }
if ($ProjectName) { $ProjectName = [string]$ProjectName }

$sequence = @()
if ($ProjectFile) {
    $sequence += [ordered]@{ name = 'Connect'; args = @{} }
    $sequence += [ordered]@{ name = 'OpenProject'; args = [ordered]@{ path = $ProjectFile; closeForeignProject = $false } }
} elseif ($ProjectName) {
    $sequence += [ordered]@{ name = 'Connect'; args = @{} }
    $sequence += [ordered]@{ name = 'AttachToOpenProject'; args = [ordered]@{ projectName = $ProjectName } }
} else {
    throw 'Give -ProjectFile or -ProjectName.'
}
$sequence += $calls
$sequence += [ordered]@{ name = 'SaveProject'; args = @{} }
$sequence += [ordered]@{ name = 'CloseProject'; args = @{} }
$sequence += [ordered]@{ name = 'Disconnect'; args = @{} }

$callsJson = $sequence | ConvertTo-Json -Depth 20 -Compress
$reportPath = Join-Path ([IO.Path]::GetTempPath()) ('tia-hmi-screen-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }
$callArgs = @(
    '-NoProfile', '-NonInteractive', '-File', $sequenceScript,
    '-ExecutablePath', $exe,
    '-Arguments', '--tia-major-version 20 --profile full',
    '-CallsJson', $callsJson,
    '-OutputPath', $reportPath,
    '-TimeoutSeconds', '1200'
)
$null = & $pwsh @callArgs 2>&1
$report = if (Test-Path -LiteralPath $reportPath -PathType Leaf) { Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json } else { $null }
if (-not $report) { throw 'The HMI screen sequence did not produce a report.' }
$failed = @($report.calls | Where-Object { -not $_.success })
$summary = [ordered]@{
    schemaVersion = 1
    success = ($failed.Count -eq 0)
    applied = $true
    screenJsonPath = $ScreenJsonPath
    screenName = [string]$spec.screenName
    calls = @($report.calls | ForEach-Object { [ordered]@{ name = $_.name; success = $_.success } })
    failures = @($failed | ForEach-Object { [ordered]@{ name = $_.name; text = [string]$_.text } })
    reportPath = $reportPath
}
$summary | ConvertTo-Json -Depth 10
if (-not $summary.success) { exit 1 }
