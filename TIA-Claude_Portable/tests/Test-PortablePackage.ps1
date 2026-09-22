[CmdletBinding()]
param(
    [string]$PackageRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'dist')
)

$ErrorActionPreference = 'Stop'
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot)
$core = Join-Path $PackageRoot 'TIA-Claude_Core'
$examples = Join-Path $PackageRoot 'TIA-Claude_Examples'
$coreManifestPath = Join-Path $core 'manifests\package-manifest.json'
$examplesManifestPath = Join-Path $examples 'manifests\examples-manifest.json'
$packageInfoPath = Join-Path $PackageRoot 'package-info.json'

$requiredPaths = @(
    (Join-Path $PackageRoot 'package-set.json'),
    $packageInfoPath,
    (Join-Path $core 'AGENTS.md'),
    (Join-Path $core '30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe'),
    (Join-Path $core 'install\Install-CorePackage.ps1'),
    (Join-Path $core 'install\Verify-CorePackage.ps1'),
    $coreManifestPath,
    $examplesManifestPath
)

$missing = @($requiredPaths | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
if ($missing.Count -gt 0) {
    throw "Portable split package is incomplete. Missing: $($missing -join ', ')"
}

$packageInfo = Get-Content -Raw -LiteralPath $packageInfoPath | ConvertFrom-Json
if ($packageInfo.metadataRole -ne 'generated-build-summary') {
    throw 'Portable package-info.json is not marked as a generated build summary.'
}
if ($packageInfo.PSObject.Properties['legacyMonolithicWorkspace']) {
    throw 'Portable package-info.json still advertises the obsolete monolithic workspace layout.'
}
$manifestChecks = @(
    @{ Kind = 'core'; Root = $core; Path = $coreManifestPath; Summary = $packageInfo.distribution.core },
    @{ Kind = 'examples'; Root = $examples; Path = $examplesManifestPath; Summary = $packageInfo.distribution.examples }
)
foreach ($check in $manifestChecks) {
    $manifest = Get-Content -Raw -LiteralPath $check.Path | ConvertFrom-Json
    $manifestCount = @($manifest.files).Count
    $actualFiles = @(Get-ChildItem -LiteralPath $check.Root -Recurse -File | Where-Object { $_.FullName -ne $check.Path })
    if ($manifest.packageKind -ne $check.Kind -or $manifest.fileCount -ne $manifestCount) {
        throw "Portable $($check.Kind) manifest metadata is inconsistent."
    }
    if ($actualFiles.Count -ne $manifestCount -or $check.Summary.files -ne $manifestCount) {
        throw "Portable $($check.Kind) file count does not match its generated manifest."
    }
    $manifestBytes = [long](($manifest.files | Measure-Object -Property bytes -Sum).Sum)
    $totalBytes = [long]((Get-ChildItem -LiteralPath $check.Root -Recurse -File | Measure-Object -Property Length -Sum).Sum)
    if ($check.Summary.bytes -ne $manifestBytes -or $check.Summary.totalBytesIncludingManifest -ne $totalBytes) {
        throw "Portable $($check.Kind) byte totals do not match its generated files."
    }
}

$inspectExe = Join-Path $core '30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe'
if ($packageInfo.tiaInspect.sha256 -ne (Get-FileHash -Algorithm SHA256 -LiteralPath $inspectExe).Hash.ToLowerInvariant() -or
    $packageInfo.tiaInspect.bytes -ne (Get-Item -LiteralPath $inspectExe).Length) {
    throw 'Portable tia-inspect metadata does not match the packaged executable.'
}

Write-Output 'PASS: current split portable package, manifests, and file counts are consistent'
