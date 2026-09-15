[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$forbiddenPatterns = @(
    '^40-projects(?:/|$)',
    '^90-tmp(?:/|$)',
    '^70-runs(?:/|$)',
    '^_ref(?:/|$)'
)
$tracked = @()
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git -and (Test-Path -LiteralPath (Join-Path $WorkspaceRoot '.git') -PathType Container)) {
    $tracked = @(git -C $WorkspaceRoot ls-files)
}
$trackedForbidden = @($tracked | Where-Object {
    $path = $_ -replace '\\', '/'
    ($forbiddenPatterns | Where-Object { $path -match $_ }).Count -gt 0 -or
    ($path -match '\.(ap1[0-9]?|ap2[0-9]?|zap1|zap2)$' -and $path -notmatch '^TIA-Claude_Portable/')
})
$result = [ordered]@{
    schemaVersion = 1
    success = ($trackedForbidden.Count -eq 0)
    gitRepository = (Test-Path -LiteralPath (Join-Path $WorkspaceRoot '.git') -PathType Container)
    trackedFileCount = $tracked.Count
    trackedForbidden = @($trackedForbidden)
    forbiddenAreas = @('40-projects/', '90-tmp/', '70-runs/', '_ref/')
    note = 'Customer projects must live in a separate private repository and are not auto-packaged.'
}
$json = $result | ConvertTo-Json -Depth 8
if ($OutputPath) {
    $OutputPath = [IO.Path]::GetFullPath($OutputPath)
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
    $json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
Write-Output $json
if (-not $result.success) { exit 1 }
$global:LASTEXITCODE = 0
exit 0
