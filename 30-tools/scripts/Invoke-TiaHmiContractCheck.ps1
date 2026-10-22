<#
.SYNOPSIS
    Verifica el contrato entre la HMI y el PLC: cada tag de la HMI tiene el binding
    verificado contra el tag del PLC, cada boton escribe en su tag y cada control
    dinamizado apunta al tag que debe.

.DESCRIPTION
    Lee del proyecto, de verdad:
      - el binding de cada tag HMI (con requireVerifiedBinding=true, que obliga a la
        herramienta a releer Address/LogicalAddress del proyecto y a fallar si no cuadra),
      - el script de evento de cada boton,
      - la dinamizacion de cada control con su tag,
    y lo cruza con la tabla de tags del PLC (nombre -> direccion) leida del export XML.

    Que la HMI se VEA funcionando en un runtime no se comprueba aqui: eso exige WinCC
    Unified Runtime instalado y arrancado. Lo que este script responde es si la HMI y el
    PLC estan de acuerdo.

    Con -DryRun solo valida el JSON y lista las comprobaciones; no conecta con TIA.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [Parameter(Mandatory = $true)]
    [string]$ProjectFile,
    [Parameter(Mandatory = $true)]
    [string]$SpecPath,
    [string]$ScreenJsonPath,
    [string]$PlcTagTableXml,
    [string]$HmiSoftwarePath = 'HMI_RT_1',
    [string]$HmiTagTableName = 'HMI_Tags',
    [string]$OutputPath,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$ProjectFile = [IO.Path]::GetFullPath($ProjectFile)
$SpecPath = [IO.Path]::GetFullPath($SpecPath)
if (-not (Test-Path -LiteralPath $ProjectFile -PathType Leaf)) { throw "Project not found: $ProjectFile" }
if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) { throw "Spec not found: $SpecPath" }
$spec = Get-Content -Raw -LiteralPath $SpecPath | ConvertFrom-Json
$screen = if ($ScreenJsonPath -and (Test-Path -LiteralPath $ScreenJsonPath -PathType Leaf)) {
    Get-Content -Raw -LiteralPath $ScreenJsonPath | ConvertFrom-Json
} else { $null }
$plcName = [string]$spec.plcName

# Tabla de tags del PLC: nombre -> direccion. Sale del export XML, que es la fuente de verdad.
$plcTags = @{}
if ($PlcTagTableXml -and (Test-Path -LiteralPath $PlcTagTableXml -PathType Leaf)) {
    $xml = [IO.File]::ReadAllText($PlcTagTableXml, [Text.Encoding]::UTF8)
    foreach ($tag in [regex]::Matches($xml, '(?s)<SW\.Tags\.PlcTag .*?</SW\.Tags\.PlcTag>')) {
        $name = [regex]::Match($tag.Value, '<Name>([^<]+)</Name>').Groups[1].Value
        $address = [regex]::Match($tag.Value, '<LogicalAddress>([^<]+)</LogicalAddress>').Groups[1].Value
        $dataType = [regex]::Match($tag.Value, '<DataTypeName>([^<]+)</DataTypeName>').Groups[1].Value
        if ($name) { $plcTags[$name] = [ordered]@{ name = $name; address = $address; dataType = $dataType } }
    }
}
if ($plcTags.Count -eq 0) { throw "No PLC tags could be read from: $PlcTagTableXml" }

$checks = @()
foreach ($hmiTag in @($spec.hmiTags)) {
    $plcTagName = [string]$hmiTag.plcTag
    $expectedAddress = [string]$hmiTag.address
    $plcTag = if ($plcTags.ContainsKey($plcTagName)) { $plcTags[$plcTagName] } else { $null }
    $checks += [ordered]@{
        kind = 'hmiTag'
        hmiTag = [string]$hmiTag.tagName
        plcTag = $plcTagName
        expectedAddress = $expectedAddress
        plcTagExists = ($null -ne $plcTag)
        plcTagAddress = if ($plcTag) { $plcTag.address } else { $null }
        addressMatches = ($null -ne $plcTag -and $plcTag.address -eq $expectedAddress)
        bindingVerified = $null
        runtimeAddressReadback = $null
        ok = $false
    }
}
foreach ($action in @($screen.buttonActions)) {
    $checks += [ordered]@{
        kind = 'buttonAction'
        button = [string]$action.buttonName
        eventType = [string]$action.eventType
        actionKind = [string]$action.actionKind
        targetTag = [string]$action.targetTag
        script = $null
        ok = $false
    }
}
foreach ($dynamization in @($screen.tagDynamizations)) {
    $checks += [ordered]@{
        kind = 'tagDynamization'
        item = [string]$dynamization.itemName
        property = [string]$dynamization.propertyName
        tag = [string]$dynamization.tagName
        boundTag = $null
        ok = $false
    }
}

if ($DryRun) {
    [ordered]@{ schemaVersion = 1; success = $true; applied = $false; checks = $checks } | ConvertTo-Json -Depth 12
    return
}

$exe = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
$sequenceScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }

$calls = @(
    [ordered]@{ name = 'Connect'; args = @{} },
    [ordered]@{ name = 'OpenProject'; args = [ordered]@{ path = $ProjectFile; closeForeignProject = $false } }
)
foreach ($hmiTag in @($spec.hmiTags)) {
    $calls += [ordered]@{ name = 'EnsureUnifiedHmiTag'; args = [ordered]@{
        hmiSoftwarePath = $HmiSoftwarePath
        tagTableName = [string]$hmiTag.tagTableName
        tagName = [string]$hmiTag.tagName
        hmiDataType = [string]$(if ($hmiTag.hmiDataType) { $hmiTag.hmiDataType } else { 'Bool' })
        plcName = $plcName
        plcTag = [string]$hmiTag.plcTag
        address = [string]$hmiTag.address
        requireVerifiedBinding = $true
    } }
}
foreach ($action in @($screen.buttonActions)) {
    $calls += [ordered]@{ name = 'EnsureUnifiedHmiButtonAction'; args = [ordered]@{
        hmiSoftwarePath = $HmiSoftwarePath
        screenName = [string]$screen.screenName
        buttonName = [string]$action.buttonName
        eventType = [string]$action.eventType
        actionKind = [string]$action.actionKind
        targetTag = [string]$action.targetTag
        syntaxCheck = $false
    } }
}
foreach ($dynamization in @($screen.tagDynamizations)) {
    $calls += [ordered]@{ name = 'BindUnifiedHmiTagDynamization'; args = [ordered]@{
        hmiSoftwarePath = $HmiSoftwarePath
        screenName = [string]$screen.screenName
        itemName = [string]$dynamization.itemName
        propertyName = [string]$dynamization.propertyName
        tagName = [string]$dynamization.tagName
        dataType = [string]$(if ($dynamization.dataType) { $dynamization.dataType } else { 'Bool' })
    } }
}
$calls += @(
    [ordered]@{ name = 'CloseProject'; args = @{} },
    [ordered]@{ name = 'Disconnect'; args = @{} }
)

$reportPath = Join-Path ([IO.Path]::GetTempPath()) ('tia-hmi-contract-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
$callArgs = @(
    '-NoProfile', '-NonInteractive', '-File', $sequenceScript,
    '-ExecutablePath', $exe,
    '-Arguments', '--tia-major-version 20 --profile full',
    '-CallsJson', ($calls | ConvertTo-Json -Depth 20 -Compress),
    '-OutputPath', $reportPath,
    '-TimeoutSeconds', '1800'
)
$null = & $pwsh @callArgs 2>&1
$report = if (Test-Path -LiteralPath $reportPath -PathType Leaf) { Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json } else { $null }
if (-not $report) { throw 'The HMI contract sequence did not produce a report.' }

$byTool = @{}
foreach ($call in $report.calls) {
    if ($call.name -in @('EnsureUnifiedHmiTag', 'EnsureUnifiedHmiButtonAction', 'BindUnifiedHmiTagDynamization')) {
        $payload = $null
        try { $payload = $call.text | ConvertFrom-Json } catch { }
        if (-not $payload) { continue }
        $message = [string]$payload.message
        $key = if ($call.name -eq 'EnsureUnifiedHmiTag') { 'tag:' + [string]$payload.meta.requestedPlcTag }
        elseif ($call.name -eq 'EnsureUnifiedHmiButtonAction') { 'button:' + [string]$payload.meta.targetTags[0] }
        else { 'dyn:' + [regex]::Match($message, "bound to '([^']+)'").Groups[1].Value }
        $byTool[$key] = [ordered]@{ call = $call; payload = $payload; message = $message }
    }
}

foreach ($check in $checks) {
    if ($check.kind -eq 'hmiTag') {
        $found = $byTool['tag:' + $check.plcTag]
        if ($found) {
            $check.bindingVerified = [bool]$found.payload.meta.bindingVerified
            $check.runtimeAddressReadback = [string]$found.payload.meta.RuntimeAddressReadback
            $check.bindingStatus = [string]$found.payload.meta.bindingStatus
            $check.ok = $check.plcTagExists -and $check.addressMatches -and ($check.bindingVerified -eq $true)
        }
    }
    elseif ($check.kind -eq 'buttonAction') {
        $found = $byTool['button:' + $check.targetTag]
        if ($found) {
            $check.script = [string]$found.payload.meta.script
            $check.ok = ($found.call.success -and -not [string]::IsNullOrWhiteSpace($check.script) -and $check.script -like ('*' + $check.targetTag + '*'))
        }
    }
    else {
        $found = $byTool['dyn:' + $check.tag]
        if ($found) {
            # El tag al que queda ligado el control no viene en un campo del meta, sino en
            # el mensaje: "Tag dynamization for 'X.BackColor' bound to 'Y'."
            $message = [string]$found.payload.message
            $bound = [regex]::Match($message, "bound to '([^']+)'").Groups[1].Value
            $check.boundTag = $bound
            $check.message = $message
            $check.ok = ($found.call.success -and $bound -eq $check.tag)
        }
    }
}

$result = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    project = $ProjectFile
    hmiSoftwarePath = $HmiSoftwarePath
    plcName = $plcName
    plcTagCount = $plcTags.Count
    success = (@($checks | Where-Object { -not $_.ok }).Count -eq 0)
    checks = $checks
    scope = 'Verifica el contrato HMI-PLC leyendo el proyecto. NO comprueba la HMI en runtime: eso exige WinCC Unified Runtime instalado y arrancado.'
    reportPath = $reportPath
}
$json = $result | ConvertTo-Json -Depth 15
if ($OutputPath) {
    $OutputPath = [IO.Path]::GetFullPath($OutputPath)
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
    $json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
Write-Output $json
if (-not $result.success) { exit 1 }
