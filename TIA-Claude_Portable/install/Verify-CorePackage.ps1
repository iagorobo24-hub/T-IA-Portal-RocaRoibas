[CmdletBinding()]
param(
    [string]$PackageRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot)
$manifestPath = Join-Path $PackageRoot 'manifests\package-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Core manifest is missing: $manifestPath" }
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()
foreach ($entry in @($manifest.files)) {
    $file = Join-Path $PackageRoot ($entry.path -replace '/', '\')
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        $failures.Add("Missing: $($entry.path)")
        continue
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLowerInvariant()
    if ($actual -ne [string]$entry.sha256) { $failures.Add("Hash mismatch: $($entry.path)") }
}
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Core package verification failed with $($failures.Count) issue(s)."
}
Write-Output "PASS: core package hashes ($($manifest.files.Count) files)"
$global:LASTEXITCODE = 0
exit 0
