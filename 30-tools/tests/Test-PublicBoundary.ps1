[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$audit = Join-Path $WorkspaceRoot '30-tools\scripts\Audit-PublicBoundary.ps1'
foreach ($path in @('SECURITY.md', 'CONTRIBUTING.md', '40-projects\.gitignore', $audit)) {
    $resolved = if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $WorkspaceRoot $path }
    if (-not (Test-Path -LiteralPath $resolved)) { throw "Boundary file is missing: $path" }
}
$outputPath = Join-Path $WorkspaceRoot ('90-tmp\public-boundary-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.json')
try {
    $out = (& $audit -WorkspaceRoot $WorkspaceRoot -OutputPath $outputPath | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Public boundary audit failed: $out" }
    $report = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if (-not $report.success -or @($report.trackedForbidden).Count -ne 0) { throw 'Forbidden files are tracked.' }
    Write-Output 'PASS: public boundary audit has no forbidden tracked files'
}
finally {
    if (Test-Path -LiteralPath $outputPath) { Remove-Item -LiteralPath $outputPath -Force }
}
