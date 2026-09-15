<#
.SYNOPSIS
    Writes a read-only, version-gated PLC/HMI simulation readiness report.

.DESCRIPTION
    This is a preflight report, not a simulation runner. It never opens, edits,
    downloads or closes TIA Portal. It deliberately separates PLC toolchain
    readiness from HMI Runtime Advanced compatibility and from behavioral proof.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '70-runs\simulation\readiness-latest.json'),
    [switch]$SkipLiveProcessCheck
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)

function Read-Json([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } catch { return $null }
}

function Get-InstalledPlcSim([object]$Environment) {
    if ($Environment -and $Environment.plcsim) { return $Environment.plcsim }

    $classic = 'C:\Program Files\Siemens\Automation\PLCSIM_V19\S7PLCSIMV19.exe'
    $advanced = 'C:\Program Files (x86)\Siemens\Automation\PLCSIMADV\bin\Siemens.Simatic.PlcSim.Advanced.UserInterface.exe'
    $advancedFile = if (Test-Path -LiteralPath $advanced -PathType Leaf) { Get-Item -LiteralPath $advanced } else { $null }
    [ordered]@{
        classicInstalled = Test-Path -LiteralPath $classic -PathType Leaf
        classicPath = if (Test-Path -LiteralPath $classic -PathType Leaf) { $classic } else { $null }
        advancedInstalled = ($null -ne $advancedFile)
        advancedPath = if ($advancedFile) { $advancedFile.FullName } else { $null }
        advancedVersion = if ($advancedFile) { $advancedFile.VersionInfo.ProductVersion } else { $null }
    }
}

function Get-VisibleTiaProcesses {
    @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'Siemens.Automation.Portal*' -and $_.MainWindowTitle
    } | ForEach-Object {
        [ordered]@{ id = $_.Id; title = $_.MainWindowTitle; responding = $_.Responding }
    })
}

function Get-TiaSessionSafety([object[]]$VisibleTia) {
    if ($VisibleTia.Count -eq 0) {
        return [ordered]@{ safe = $true; status = 'no-visible-tia'; visiblePids = @(); probe = $null }
    }

    $sequenceScript = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
    $createExe = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction SilentlyContinue).Source }
    if (-not (Test-Path -LiteralPath $sequenceScript -PathType Leaf) -or
        -not (Test-Path -LiteralPath $createExe -PathType Leaf) -or -not $pwsh) {
        return [ordered]@{
            safe = $false; status = 'visible-tia-session-probe-unavailable'
            visiblePids = @($VisibleTia.id); probe = $null
        }
    }

    $probePath = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-readiness-' + [guid]::NewGuid().ToString('N') + '.json')
    $calls = @(
        @{ name = 'Bootstrap' },
        @{ name = 'Connect' },
        @{ name = 'ListPortalProcessProjects' },
        @{ name = 'GetState' },
        @{ name = 'Disconnect' }
    )
    try {
        $callsJson = $calls | ConvertTo-Json -Depth 10 -Compress
        & $pwsh -NoProfile -NonInteractive -File $sequenceScript `
            -ExecutablePath $createExe `
            -Arguments '--tia-major-version 20 --profile lite' `
            -CallsJson $callsJson `
            -OutputPath $probePath `
            -TimeoutSeconds 120 | Out-Null
        $probe = if (Test-Path -LiteralPath $probePath -PathType Leaf) { Read-Json $probePath } else { $null }
        $listCall = if ($probe) { @($probe.calls | Where-Object name -eq 'ListPortalProcessProjects') | Select-Object -Last 1 } else { $null }
        $listText = if ($listCall) { [string]$listCall.text } else { '' }
        $listPayload = try { $listText | ConvertFrom-Json } catch { $null }
        $listLines = if ($listPayload -and $listPayload.items) { @($listPayload.items) -join "`n" } else { $listText }
        $unknown = @($VisibleTia | Where-Object { $listLines -notmatch "PID=$($_.id) attach: OK" })
        $projectsOpen = @($VisibleTia | Where-Object {
            $listLines -match "PID=$($_.id) attach: OK" -and $listLines -notmatch "PID=$($_.id) projects=<empty>"
        })
        $safe = ($probe -and $probe.success -and $unknown.Count -eq 0 -and $projectsOpen.Count -eq 0)
        return [ordered]@{
            safe = $safe
            status = if ($safe) { 'visible-tia-without-open-project' } elseif ($projectsOpen.Count -gt 0) { 'visible-tia-project-open' } else { 'visible-tia-project-unknown' }
            visiblePids = @($VisibleTia.id)
            projectPids = @($projectsOpen | ForEach-Object { $_.id })
            unknownPids = @($unknown | ForEach-Object { $_.id })
            probe = $probe
        }
    }
    catch {
        return [ordered]@{
            safe = $false; status = 'visible-tia-session-probe-failed'
            visiblePids = @($VisibleTia.id); probe = $null; error = $_.Exception.Message
        }
    }
    finally {
        if (Test-Path -LiteralPath $probePath) { Remove-Item -LiteralPath $probePath -Force }
    }
}

$environmentPath = Join-Path $WorkspaceRoot '70-runs\environment\latest.json'
$environment = Read-Json $environmentPath
$tia20 = $environment -and $environment.tiaMajor -eq 20 -and @($environment.installedTia | Where-Object {
    $_.majorVersion -eq 20 -and $_.engineeringExists -eq $true -and $_.portalExists -eq $true
}).Count -gt 0
$inspect = @($environment.mcpServers | Where-Object name -eq 'tia-inspect').Count -gt 0
$create = @($environment.mcpServers | Where-Object name -eq 'tia-create').Count -gt 0
$plcsim = Get-InstalledPlcSim $environment

$runtimeEntries = @($environment.runtimeAdvanced.installedEntries)
$runtimeV20 = @($runtimeEntries | Where-Object {
    $_.displayName -and
    $_.displayName -notmatch '(?i)driver|simulator|tagging' -and
    $_.displayName -match '(?i)Runtime Advanced|WinCC Runtime Advanced' -and
    (($_.displayVersion -match '(?i)(^|[^0-9])V?20(\.|\s|$)') -or ($_.displayVersion -match '^20\.'))
})
$hmiV20Ready = $runtimeV20.Count -gt 0

$scaffoldEvidence = @(Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter 'scaffold-report.json' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending)
$scaffold = if ($scaffoldEvidence) { Read-Json $scaffoldEvidence[0].FullName } else { $null }
$plcBehaviorEvidence = Join-Path $WorkspaceRoot '70-runs\simulation\sorting-plant-acceptance.json'
$plcBehaviorVerified = $false
if (Test-Path -LiteralPath $plcBehaviorEvidence -PathType Leaf) {
    $behavior = Read-Json $plcBehaviorEvidence
    $plcBehaviorVerified = $behavior -and $behavior.status -eq 'verified'
}

$visibleTia = if ($SkipLiveProcessCheck) { @() } else { Get-VisibleTiaProcesses }
$tiaSessionSafety = Get-TiaSessionSafety $visibleTia
$blockers = [System.Collections.Generic.List[string]]::new()
$nextActions = [System.Collections.Generic.List[string]]::new()
if (-not $tia20) { $blockers.Add('TIA Portal/Openness V20 no está verificado') }
if (-not $inspect) { $blockers.Add('tia-inspect no está disponible') }
if (-not $plcsim.advancedInstalled) { $blockers.Add('PLCSIM Advanced no está instalado') }
if (-not $hmiV20Ready) {
    $blockers.Add('WinCC Runtime Advanced V20 compatible no está verificado')
    $nextActions.Add('Instalar o localizar el medio oficial compatible con V20 y repetir la verificación')
}
if (-not $plcBehaviorVerified) {
    $blockers.Add('El comportamiento PLC en runtime no está demostrado')
    $nextActions.Add('Ejecutar la aceptación Sorting Plant con una instancia virtual y registrar una transición observable')
}
if (-not $tiaSessionSafety.safe) {
    if ($tiaSessionSafety.status -eq 'visible-tia-project-open') {
        $blockers.Add('Hay un proyecto abierto en una instancia visible de TIA Portal; el flujo de aplicación debe esperar')
        $nextActions.Add('Cerrar el proyecto visible o confirmar que es el proyecto objetivo antes de continuar')
    } else {
        $blockers.Add('No se pudo demostrar que las instancias visibles de TIA Portal están sin proyecto')
        $nextActions.Add('Repetir la consulta de sesión o cerrar la instancia visible antes de continuar')
    }
}
if ($scaffold -and $scaffold.applied -eq $true -and $scaffold.postApply) {
    $nextActions.Add('Usar la evidencia postApply del scaffold como proyecto PLC mínimo de referencia')
} else {
    $nextActions.Add('Aplicar el scaffold de agente en una carpeta desechable cuando TIA esté libre')
}

$plcReady = $tia20 -and $inspect -and [bool]$plcsim.advancedInstalled
$result = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    workspaceRoot = $WorkspaceRoot
    readOnly = $true
    status = if ($plcReady -and $hmiV20Ready -and $plcBehaviorVerified -and $blockers.Count -eq 0) { 'READY' } elseif ($plcReady) { 'READY_WITH_BLOCKERS' } else { 'NOT_READY' }
    versions = [ordered]@{
        tiaMajor = if ($environment) { $environment.tiaMajor } else { $null }
        plcsimAdvanced = $plcsim.advancedVersion
        runtimeAdvancedV20 = @($runtimeV20 | ForEach-Object { $_.displayVersion })
    }
    gates = [ordered]@{
        plcToolchainReady = $plcReady
        hmiRuntimeAdvancedV20Ready = $hmiV20Ready
        plcBehaviorVerified = $plcBehaviorVerified
        tiaInstanceSafeForApply = [bool]$tiaSessionSafety.safe
    }
    installed = [ordered]@{
        tiaV20 = $tia20
        tiaInspect = $inspect
        tiaCreate = $create
        plcsim = $plcsim
    }
    blockers = @($blockers | Select-Object -Unique)
    nextActions = @($nextActions | Select-Object -Unique)
    evidence = [ordered]@{
        environment = $environmentPath
        scaffold = if ($scaffoldEvidence) { $scaffoldEvidence[0].FullName } else { $null }
        sortingPlantBehavior = if (Test-Path -LiteralPath $plcBehaviorEvidence -PathType Leaf) { $plcBehaviorEvidence } else { $null }
        tiaSessionSafety = $tiaSessionSafety
    }
}

$json = $result | ConvertTo-Json -Depth 12
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output $json
