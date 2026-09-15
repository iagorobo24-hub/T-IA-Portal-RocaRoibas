[CmdletBinding()]
param(
    [string]$OutputPath,
    [string[]]$SearchRoot
)

$ErrorActionPreference = 'Stop'
if (-not $SearchRoot) {
    $SearchRoot = @(
        (Join-Path $env:USERPROFILE 'Downloads'),
        'D:\', 'E:\', 'F:\'
    )
}
$roots = @($SearchRoot | ForEach-Object {
    try { [IO.Path]::GetFullPath($_) } catch { $null }
} | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique)

$patterns = @('*.iso', '*.zip', '*.msi', '*.exe')
$candidates = [System.Collections.Generic.List[object]]::new()
foreach ($root in $roots) {
    $recurse = $root -match '(?i)Downloads$'
    $files = if ($recurse) {
        Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue -Include $patterns
    } else {
        Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue -Include $patterns
    }
    foreach ($file in $files) {
        if ($file.Name -match '(?i)(tia|wincc|runtime|portal|automation|step.?7|plcsim)') {
            $candidates.Add([ordered]@{ path = $file.FullName; bytes = $file.Length; lastWriteTime = $file.LastWriteTime.ToString('o') })
        }
    }
}

$result = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    readOnly = $true
    roots = @($roots)
    candidateCount = $candidates.Count
    candidates = @($candidates)
    nextStep = if ($candidates.Count -eq 0) { 'Provide official V20 installation media, then rerun before installing.' } else { 'Review candidate manually; installation requires action-time user confirmation.' }
}
$json = $result | ConvertTo-Json -Depth 10
if ($OutputPath) {
    $OutputPath = [IO.Path]::GetFullPath($OutputPath)
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
    $json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
Write-Output $json
