[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..'))
)

$ErrorActionPreference = 'Stop'
$readme = Join-Path $WorkspaceRoot '30-tools\mcp\tia-inspect\README.md'
$errorCatalog = Join-Path $WorkspaceRoot '10-kb\50-errores\README.md'
$reportPath = Join-Path $WorkspaceRoot '70-runs\environment\latest.json'
$agentPolicy = Join-Path $WorkspaceRoot 'AGENTS.md'
$analogRecipe = Join-Path $WorkspaceRoot '10-kb\20-recetas\R18-medidas-analogicas.md'
$communicationsRecipe = Join-Path $WorkspaceRoot '10-kb\20-recetas\R19-diagnostico-comunicaciones.md'
$hmiRecipe = Join-Path $WorkspaceRoot '10-kb\20-recetas\R20-aceptacion-hmi-por-modelo.md'
$offlineReleaseRecipe = Join-Path $WorkspaceRoot '10-kb\20-recetas\R21-preflight-offline-release.md'
$offlineReleasePreflight = Join-Path $WorkspaceRoot '30-tools\scripts\Test-TiaOfflineReleasePreconditions.ps1'

if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) {
    throw "Missing tia-inspect README: $readme"
}
if (-not (Test-Path -LiteralPath $errorCatalog -PathType Leaf)) {
    throw "Missing error catalog: $errorCatalog"
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Missing environment report: $reportPath"
}
foreach ($path in @($agentPolicy, $analogRecipe, $communicationsRecipe, $hmiRecipe, $offlineReleaseRecipe, $offlineReleasePreflight)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing agent operating instruction or recipe: $path"
    }
}

$offlineText = Get-Content -Raw -LiteralPath $offlineReleaseRecipe
$offlinePreflightText = Get-Content -Raw -LiteralPath $offlineReleasePreflight
if ($offlineText -notmatch 'TMP_EXPORT[/\\]_verify' -or
    $offlineText -notmatch 'TMP_EXPORT[/\\]Source' -or
    $offlinePreflightText -notmatch '\$fixtureRoot .*Source' -or
    $offlineText -notmatch '(?i)Bloqueado' -or
    $offlineText -notmatch 'Test-TiaOfflineReleasePreconditions\.ps1') {
    throw 'R21 must document the offline release fixture preflight and its blocking behavior.'
}

$report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
$readmeText = Get-Content -Raw -LiteralPath $readme
$errorCatalogText = Get-Content -Raw -LiteralPath $errorCatalog
$analogText = Get-Content -Raw -LiteralPath $analogRecipe
$communicationsText = Get-Content -Raw -LiteralPath $communicationsRecipe
$hmiText = Get-Content -Raw -LiteralPath $hmiRecipe
$groupMembership = [bool]$report.opennessGroupMember

foreach ($recipe in @(
    [pscustomobject]@{ name = 'R18 analog'; text = $analogText },
    [pscustomobject]@{ name = 'R19 communications'; text = $communicationsText },
    [pscustomobject]@{ name = 'R20 HMI'; text = $hmiText }
)) {
    $preconditionsMatch = [regex]::Match($recipe.text, '(?is)## Precondiciones(?<section>.*?)(?=\r?\n## |\z)')
    if (-not $preconditionsMatch.Success -or
        $preconditionsMatch.Groups['section'].Value -notmatch '(?is)Doctor.{0,500}Computer Use nativo.{0,500}Connect') {
        throw "$($recipe.name) must identify a visible TIA window with native Computer Use after Doctor and before Connect."
    }
}

if ($analogText -notmatch '(?is)aplicaci[oó]n SCL.{0,200}bloquead[ao] actualmente' -or
    $analogText -notmatch 'ImportSources' -or
    $analogText -notmatch 'ImportFromDocuments') {
    throw 'R18 must report that existing SCL application is currently blocked because the import tools are not registered.'
}

if ($groupMembership -and $readmeText -match "User in 'Siemens TIA Openness' user group: False") {
    throw 'tia-inspect README contradicts the current Doctor report: it says Openness group membership is False.'
}
if ((-not $groupMembership) -and $readmeText -notmatch "User in 'Siemens TIA Openness' user group: False") {
    throw 'tia-inspect README must report the current Openness group membership as False.'
}
if ($groupMembership -and $errorCatalogText -match 'Verificado en esta máquina — es el estado actual') {
    throw 'The error catalog still claims the Openness group is currently False.'
}

Write-Output 'PASS: documentation reflects current environment report'
