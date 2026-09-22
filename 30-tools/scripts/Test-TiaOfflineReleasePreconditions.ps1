<##
.SYNOPSIS
    Checks the file fixtures required by RunOfflineReleaseValidationSuite.

.DESCRIPTION
    This is a local, offline preflight. It does not connect to TIA Portal, open a
    project, import an object, or create a fixture. The MCP release suite was
    written for a release workspace containing TMP_EXPORT/_verify golden XML
    samples and Unified HMI templates. Calling it against this engineering
    workspace without that bundle produces an opaque missing-file exception.

    Exit codes:
      0 = READY
      2 = BLOCKED (one or more hard preconditions are missing or invalid)
      1 = fatal parameter/reporting error
##>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $WorkspaceRoot '70-runs\tia-capabilities\offline-release-preflight-latest.json'
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)

function New-Check {
    param(
        [string]$Id,
        [string]$Path,
        [string]$Kind,
        [bool]$Hard,
        [string]$Reason,
        [string[]]$Markers = @(),
        [string[]]$Alternatives = @(),
        [string]$AlternativeRoot = ''
    )

    $exists = if ($Kind -eq 'directory') {
        Test-Path -LiteralPath $Path -PathType Container
    } else {
        Test-Path -LiteralPath $Path -PathType Leaf
    }
    $parseable = $null
    $detectedMarkers = @()
    $errorText = $null

    if ($exists -and $Kind -eq 'xml') {
        try {
            $raw = Get-Content -Raw -LiteralPath $Path
            $null = [xml]$raw
            $parseable = $true
            foreach ($marker in $Markers) {
                if ($raw.IndexOf($marker, [StringComparison]::Ordinal) -ge 0) {
                    $detectedMarkers += $marker
                }
            }
        } catch {
            $parseable = $false
            $errorText = $_.Exception.Message
        }
    }

    if ($exists -and $Kind -eq 'json') {
        try {
            $null = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
            $parseable = $true
        } catch {
            $parseable = $false
            $errorText = $_.Exception.Message
        }
    }

    $alternativeUsed = $false
    $resolvedPath = $Path
    if (-not $exists -and $Alternatives.Count -gt 0) {
        foreach ($alternative in $Alternatives) {
            $root = if ([string]::IsNullOrWhiteSpace($AlternativeRoot)) { Split-Path -Parent $Path } else { $AlternativeRoot }
            $candidate = [IO.Path]::GetFullPath((Join-Path $root $alternative))
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $alternativeUsed = $true
                $resolvedPath = $candidate
                $exists = $true
                if ($Kind -eq 'xml') {
                    try {
                        $raw = Get-Content -Raw -LiteralPath $candidate
                        $null = [xml]$raw
                        $parseable = $true
                        foreach ($marker in $Markers) {
                            if ($raw.IndexOf($marker, [StringComparison]::Ordinal) -ge 0) {
                                $detectedMarkers += $marker
                            }
                        }
                    } catch {
                        $parseable = $false
                        $errorText = $_.Exception.Message
                    }
                }
                if ($Kind -eq 'json') {
                    try {
                        $null = Get-Content -Raw -LiteralPath $candidate | ConvertFrom-Json
                        $parseable = $true
                    } catch {
                        $parseable = $false
                        $errorText = $_.Exception.Message
                    }
                }
                break
            }
        }
    }

    $markerOk = ($Markers.Count -eq 0) -or ($detectedMarkers.Count -eq $Markers.Count)
    $ok = $exists -and
        (($Kind -ne 'xml') -or (($parseable -eq $true) -and $markerOk)) -and
        (($Kind -ne 'json') -or ($parseable -eq $true))
    $status = if ($ok) { 'PASS' } elseif ($Hard) { 'BLOCKED' } else { 'WARNING' }
    [ordered]@{
        id = $Id
        kind = $Kind
        hard = $Hard
        path = $Path
        resolvedPath = if ($alternativeUsed) { $resolvedPath } else { $null }
        exists = $exists
        parseable = $parseable
        requiredMarkers = @($Markers)
        detectedMarkers = @($detectedMarkers | Select-Object -Unique)
        alternativeUsed = $alternativeUsed
        alternatives = @($Alternatives)
        status = $status
        reason = $Reason
        error = $errorText
    }
}

$fixtureRoot = Join-Path $WorkspaceRoot 'TMP_EXPORT\_verify'
$checks = New-Object System.Collections.Generic.List[object]
$checks.Add((New-Check 'workspace-root' $WorkspaceRoot 'directory' $true 'La raíz debe ser el workspace de release entregado al helper.'))
$checks.Add((New-Check 'docs-root' (Join-Path $WorkspaceRoot 'docs') 'directory' $true 'El helper resuelve plantillas y mapping bajo docs/.'))
# The published MCP description names tools/; this workspace uses 30-tools/. Keep
# this as a warning because the current binary does not inspect it before failing.
$checks.Add((New-Check 'release-tools-root' (Join-Path $WorkspaceRoot 'tools') 'directory' $false 'La descripción del helper espera tools/. Este workspace usa 30-tools/; no se debe afirmar compatibilidad de release sin revisar el paquete de origen.'))
$checks.Add((New-Check 'plc-fixture-root' $fixtureRoot 'directory' $true 'La suite PLC abre directamente TMP_EXPORT/_verify y no crea los golden samples.'))
$checks.Add((New-Check 'udt' (Join-Path $fixtureRoot 'UDT_Fault.xml') 'xml' $true 'Golden UDT con marcador SW.Types.PlcStruct.' @('SW.Types.PlcStruct')))
$checks.Add((New-Check 'tag-table' (Join-Path $fixtureRoot 'TagTable_StartStop.xml') 'xml' $true 'Golden PLC tag table con marcadores SW.Tags.PlcTagTable y SW.Tags.PlcTag.' @('SW.Tags.PlcTagTable', 'SW.Tags.PlcTag')))
$checks.Add((New-Check 'scl-fc' (Join-Path $fixtureRoot 'FC_StartStop.xml') 'xml' $true 'Golden FC SCL con SW.Blocks.FC y StructuredText.' @('SW.Blocks.FC', 'StructuredText')))
# The upstream FixtureRule resolves this primary path relative to the parent of
# TMP_EXPORT/_verify (fixtureDirectory/..\Source), while FlgNetCallXmlBuilder
# later resolves it from workspaceRoot/TMP_EXPORT/Source. Keep both checks on
# the path the release suite actually reads; do not silently accept a copy
# under _verify/Source, which the suite would never consume.
$ladPrimaryPath = [IO.Path]::GetFullPath((Join-Path $fixtureRoot '..\Source\5T车\Blocks\01_手动控制\FC控制\05-故障保护.xml'))
$checks.Add((New-Check 'lad-flgnet' $ladPrimaryPath 'xml' $true 'Golden LAD/FlgNet; acepta las alternativas Limit_Protect_roundtrip.xml/Limit_Protect.xml.' @('SW.Blocks.FC', 'FlgNet') @('Limit_Protect_roundtrip.xml\Limit_Protect.xml', 'Limit_Protect.xml') $fixtureRoot))
$checks.Add((New-Check 'global-db' (Join-Path $fixtureRoot 'Sim_Data_roundtrip.xml\Sim_Data.xml') 'xml' $true 'Golden global DB con marcador SW.Blocks.GlobalDB.' @('SW.Blocks.GlobalDB')))
$templateRoot = Join-Path $WorkspaceRoot 'docs\hmi_templates'
$checks.Add((New-Check 'unified-hmi-template-root' $templateRoot 'directory' $true 'La suite necesita al menos una plantilla unified_*.json para layout, acciones y sincronización.'))
$templateFiles = if (Test-Path -LiteralPath $templateRoot -PathType Container) {
    @(Get-ChildItem -LiteralPath $templateRoot -Filter 'unified_*.json' -File -ErrorAction SilentlyContinue)
} else { @() }
$templateCheck = [ordered]@{
    id = 'unified-hmi-template-files'
    kind = 'file-set'
    hard = $true
    path = (Join-Path $templateRoot 'unified_*.json')
    exists = $templateFiles.Count -gt 0
    count = $templateFiles.Count
    status = if ($templateFiles.Count -gt 0) { 'PASS' } else { 'BLOCKED' }
    reason = 'La suite debe analizar una plantilla Unified real; un directorio vacío produce un precheck inválido.'
}
$checks.Add($templateCheck)
# The mapping loader treats this file as optional, but its absence must remain
# visible because a release package normally supplies it.
$checks.Add((New-Check 'hmi-plc-mapping' (Join-Path $WorkspaceRoot 'docs\hmi_template_mappings\tia-hmi-template-plc-mapping.release.json') 'json' $false 'El loader admite mapping vacío, pero el paquete de release debe incluirlo para trazabilidad de bindings.'))

$hardFailures = @($checks | Where-Object { $_.hard -and $_.status -ne 'PASS' })
$warnings = @($checks | Where-Object { -not $_.hard -and $_.status -ne 'PASS' })
$status = if ($hardFailures.Count -eq 0) { 'READY' } else { 'BLOCKED' }
$firstBlockingCheck = $null
if ($hardFailures.Count -gt 0) {
    $firstBlockingCheck = [string]$hardFailures[0].id
}
$checksArray = @($checks | ForEach-Object { $_ })
$report = [ordered]@{
    timestamp = [DateTimeOffset]::Now.ToString('o')
    mode = 'tia-mcp-offline-release-preflight'
    tool = 'RunOfflineReleaseValidationSuite'
    offlineOnly = $true
    workspaceRoot = $WorkspaceRoot
    status = $status
    readyForCall = ($status -eq 'READY')
    hardFailureCount = $hardFailures.Count
    warningCount = $warnings.Count
    firstBlockingCheck = $firstBlockingCheck
    checks = $checksArray
    safetyPolicy = [ordered]@{
        tia = 'No conecta TIA Portal, no abre proyectos y no importa objetos.'
        write = 'Solo escribe el informe solicitado; nunca crea TMP_EXPORT ni copia XML desde ejemplos.'
        fixtures = 'Los golden samples deben proceder del paquete de release autorizado y conservar hash/origen.'
    }
}

$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output ("{0}: RunOfflineReleaseValidationSuite preflight ({1}) -> {2}" -f $status, $WorkspaceRoot, $OutputPath)
if ($hardFailures.Count -gt 0) {
    Write-Output ('Blocking checks: ' + (($hardFailures | ForEach-Object { $_.id }) -join ', '))
    exit 2
}
if ($warnings.Count -gt 0) {
    Write-Output ('Warnings: ' + (($warnings | ForEach-Object { $_.id }) -join ', '))
}
exit 0
