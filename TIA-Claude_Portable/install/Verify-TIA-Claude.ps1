[CmdletBinding()]
param(
    [string]$PackageRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot,
    [switch]$RunDoctor
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $PackageRoot 'manifests\sha256.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "No existe el manifiesto de hashes: $manifestPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$failures = @()
foreach ($entry in $manifest.files) {
    $target = Join-Path $WorkspaceRoot $entry.path
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        $failures += "Falta: $($entry.path)"
        continue
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLowerInvariant()
    if ($actual -ne $entry.sha256) {
        $failures += "Hash distinto: $($entry.path)"
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Verificación de hashes fallida: $($failures.Count) incidencias"
}

Write-Output "PASS: hashes del workspace correctos ($($manifest.files.Count) ficheros)"

if ($RunDoctor) {
    $major = [int]$manifest.tiaMajor
    $exe = Join-Path $WorkspaceRoot "30-tools\mcp\tia-inspect\bin\v$major\TiaMcpServer.exe"
    if (-not (Test-Path -LiteralPath $exe)) { throw "No existe el servidor para Doctor: $exe" }
    & $exe --tia-major-version $major --doctor
    if ($LASTEXITCODE -ne 0) { throw "Doctor terminó con código $LASTEXITCODE" }
}
