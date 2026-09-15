[CmdletBinding()]
param(
    [string]$EvidencePath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '70-runs\simulation\sorting-plant-acceptance.json')
)

$ErrorActionPreference = 'Stop'
$EvidencePath = [IO.Path]::GetFullPath($EvidencePath)
if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
    [ordered]@{
        status = 'blocked'
        reason = 'No PLCSIM behavioral evidence exists yet; compilation alone is insufficient.'
        requiredEvidence = $EvidencePath
    } | ConvertTo-Json -Depth 5
    exit 1
}
$evidence = Get-Content -Raw -LiteralPath $EvidencePath | ConvertFrom-Json
if ([string]$evidence.status -ne 'verified') {
    [ordered]@{ status = 'blocked'; reason = "Evidence status is '$($evidence.status)', not verified." } | ConvertTo-Json
    exit 1
}
foreach ($property in @('date', 'plcsimVersion', 'virtualPlc', 'cases')) {
    if (-not ($evidence.PSObject.Properties.Name -contains $property)) { throw "Simulation evidence is missing '$property'." }
}
if (@($evidence.cases).Count -eq 0) { throw 'Simulation evidence contains no executed cases.' }
Write-Output 'PASS: Sorting Plant behavioral simulation evidence is verified'
exit 0
