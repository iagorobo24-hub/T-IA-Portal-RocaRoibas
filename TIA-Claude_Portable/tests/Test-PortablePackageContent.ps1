[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$builder = Join-Path $WorkspaceRoot 'TIA-Claude_Portable\build\Build-PortablePackage.ps1'
if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) { throw 'Build-PortablePackage.ps1 is missing.' }

$outputRoot = Join-Path $WorkspaceRoot ('90-tmp\portable-content-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
try {
    & $builder -WorkspaceRoot $WorkspaceRoot -OutputRoot $outputRoot
    if ($LASTEXITCODE -ne 0) { throw 'Portable package builder returned a failure exit code.' }
    $core = Join-Path $outputRoot 'TIA-Claude_Core'
    $examples = Join-Path $outputRoot 'TIA-Claude_Examples'
    $coreManifest = Join-Path $core 'manifests\package-manifest.json'
    $examplesManifest = Join-Path $examples 'manifests\examples-manifest.json'
    foreach ($path in @($core, $examples, $coreManifest, $examplesManifest)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Portable output is missing: $path" }
    }
    if (@(Get-ChildItem -LiteralPath $core -Recurse -File -Include '*.ap16','*.ap17','*.ap18','*.ap19','*.ap20','*.ap21').Count -gt 0) {
        throw 'Core package contains a TIA project artifact.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $core '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe') -PathType Leaf)) {
        throw 'Core package is missing the verified tia-create V20 runtime.'
    }
    $manifest = Get-Content -Raw -LiteralPath $coreManifest | ConvertFrom-Json
    if ($manifest.packageKind -ne 'core' -or $manifest.files.Count -eq 0) { throw 'Core manifest is incomplete.' }
    $exampleManifestObject = Get-Content -Raw -LiteralPath $examplesManifest | ConvertFrom-Json
    if ($exampleManifestObject.packageKind -ne 'examples' -or $exampleManifestObject.containsProjects -ne $true) {
        throw 'Examples manifest must explicitly declare that it contains projects.'
    }
    Write-Output 'PASS: portable core excludes project artifacts and examples are separately manifested'
}
finally {
    if (Test-Path -LiteralPath $outputRoot) { Remove-Item -LiteralPath $outputRoot -Recurse -Force }
}
