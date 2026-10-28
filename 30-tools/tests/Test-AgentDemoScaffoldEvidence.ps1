[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
function Resolve-RecordedPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $candidate = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    # Archived evidence can retain the machine root it was produced under. Rebase only
    # paths under this workspace's durable 70-runs tree, never arbitrary locations.
    $normalized = $Path.Replace('/', '\')
    $marker = '\' + (Split-Path -Leaf $WorkspaceRoot) + '\70-runs\'
    $index = $normalized.LastIndexOf($marker, [StringComparison]::OrdinalIgnoreCase)
    if ($index -lt 0) { return $null }
    $rebased = Join-Path $WorkspaceRoot ('70-runs\' + $normalized.Substring($index + $marker.Length))
    if (Test-Path -LiteralPath $rebased) { return [IO.Path]::GetFullPath($rebased) }
    return $null
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $WorkspaceRoot '70-runs\e2e\agent-demo-scaffold-dryrun-run\scaffold-report.json'
}
if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) { throw "Scaffold evidence is missing: $ReportPath" }
$report = Get-Content -Raw -LiteralPath $ReportPath | ConvertFrom-Json
if ($report.success -ne $true -or $report.applied -ne $false) { throw 'Scaffold dry-run evidence is not a clean non-applied run.' }
$nestedPath = Resolve-RecordedPath ([string]$report.dryRun.reportPath)
if (-not $nestedPath) { throw "Nested dry-run report is missing or cannot be rebased from its archived root: $($report.dryRun.reportPath)" }
$nested = Get-Content -Raw -LiteralPath $nestedPath | ConvertFrom-Json
if ($nested.toolName -ne 'ScaffoldProject' -or $nested.toolResponseIsError -eq $true) { throw 'ScaffoldProject dry-run MCP call failed.' }
Write-Output 'PASS: agent-demo scaffold dry-run evidence is clean and created nothing'
