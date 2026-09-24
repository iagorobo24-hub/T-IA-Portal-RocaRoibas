[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FixtureRoot
)

$ErrorActionPreference = 'Stop'
$rootFull = [IO.Path]::GetFullPath($FixtureRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) { throw "FixtureRoot does not exist: $rootFull" }
$manifestPath = Join-Path $rootFull '.tia-agent-fixture.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "FixtureRoot has no .tia-agent-fixture.json: $rootFull" }
try { $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json }
catch { throw "Fixture manifest is not valid JSON: $manifestPath" }
if ($manifest.schemaVersion -ne 1 -or $manifest.disposable -ne $true) { throw 'Fixture manifest must use schemaVersion 1 and disposable=true.' }

foreach ($field in @('projectPath', 'backupProjectPath', 'sourceProjectPath')) {
    if ([string]::IsNullOrWhiteSpace([string]$manifest.$field) -or -not [IO.Path]::IsPathRooted([string]$manifest.$field)) {
        throw "Fixture manifest field '$field' must contain an absolute path."
    }
}
$projectPath = [IO.Path]::GetFullPath([string]$manifest.projectPath)
$backupPath = [IO.Path]::GetFullPath([string]$manifest.backupProjectPath)
$sourcePath = [IO.Path]::GetFullPath([string]$manifest.sourceProjectPath)
if ([IO.Path]::GetExtension($projectPath) -ine '.ap20' -or [IO.Path]::GetExtension($backupPath) -ine '.ap20') {
    throw 'Fixture and backup must be V20 .ap20 files.'
}
foreach ($path in @($projectPath, $backupPath, $sourcePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Manifest file does not exist: $path" }
}
$rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
foreach ($path in @($projectPath, $backupPath)) {
    if (-not $path.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Fixture manifest path escapes FixtureRoot: $path" }
}
if ($sourcePath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Source project must remain outside FixtureRoot.' }
if ([string]::Equals($projectPath, $backupPath, [StringComparison]::OrdinalIgnoreCase) -or
    [string]::Equals($projectPath, $sourcePath, [StringComparison]::OrdinalIgnoreCase) -or
    [string]::Equals($backupPath, $sourcePath, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Fixture, backup, and source project paths must be distinct.'
}
$projectDirectory = Split-Path -Parent $projectPath
$backupDirectory = Split-Path -Parent $backupPath
if ([string]::Equals($projectDirectory, $backupDirectory, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Fixture project and backup must be stored in separate directories.'
}

function Get-TiaDirectoryFingerprint([string]$Directory) {
    $directoryFull = [IO.Path]::GetFullPath($Directory).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $lines = @(Get-ChildItem -LiteralPath $directoryFull -File -Recurse -Force | Sort-Object { $_.FullName.Substring($directoryFull.Length) } | ForEach-Object {
        $relative = $_.FullName.Substring($directoryFull.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$relative`t$hash"
    })
    $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

$expectedSnapshot = [string]$manifest.projectSnapshotSha256
if ($expectedSnapshot -notmatch '^[a-fA-F0-9]{64}$') { throw 'Fixture manifest projectSnapshotSha256 is missing or malformed.' }
$projectSnapshot = Get-TiaDirectoryFingerprint $projectDirectory
$backupSnapshot = Get-TiaDirectoryFingerprint $backupDirectory
if ($projectSnapshot -ne $expectedSnapshot.ToLowerInvariant() -or $backupSnapshot -ne $expectedSnapshot.ToLowerInvariant()) {
    throw 'Fixture and backup directories must both match the exact snapshot recorded in the manifest.'
}

[pscustomobject]@{
    fixtureRoot = $rootFull
    manifestPath = $manifestPath
    projectPath = $projectPath
    backupProjectPath = $backupPath
    sourceProjectPath = $sourcePath
    projectSnapshotSha256 = $projectSnapshot
    backupSnapshotSha256 = $backupSnapshot
}
