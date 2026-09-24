[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FixtureRoot,
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,
    [Parameter(Mandatory = $true)]
    [string]$BackupProjectPath,
    [Parameter(Mandatory = $true)]
    [string]$SourceProjectPath,
    [Parameter(Mandatory = $true)]
    [switch]$ConfirmedDisposable
)

$ErrorActionPreference = 'Stop'
if (-not $ConfirmedDisposable) { throw 'Pass -ConfirmedDisposable only for a throwaway copy, never for a client or production project.' }

$rootFull = [IO.Path]::GetFullPath($FixtureRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$projectFull = [IO.Path]::GetFullPath($ProjectPath)
$backupFull = [IO.Path]::GetFullPath($BackupProjectPath)
$sourceFull = [IO.Path]::GetFullPath($SourceProjectPath)
if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) { throw "Fixture root does not exist: $rootFull" }
if (-not (Test-Path -LiteralPath $projectFull -PathType Leaf)) { throw "Fixture project file does not exist: $projectFull" }
# .ap18 admitido para EQUIPOTECNICO, que no tiene ninguna TIA >= V19 y usa el servidor
# tia-inspect compilado contra Openness V18. La lista es explicita a proposito: cada version
# aceptada aqui debe tener un binario verificado. Ver 00-meta/07-viabilidad-openness-v15-v18.md.
$allowedFixtureExtensions = @('.ap18', '.ap20')
$projectExtension = [IO.Path]::GetExtension($projectFull).ToLowerInvariant()
if ($projectExtension -notin $allowedFixtureExtensions) {
    throw "Only $($allowedFixtureExtensions -join ' or ') fixtures are accepted by this manifest generator; got '$projectExtension'."
}
if ([IO.Path]::GetExtension($backupFull).ToLowerInvariant() -ne $projectExtension) {
    throw 'The fixture and its backup must be the same TIA Portal version.'
}
if (-not (Test-Path -LiteralPath $backupFull -PathType Leaf)) { throw "Backup project file does not exist: $backupFull" }
if (-not (Test-Path -LiteralPath $sourceFull -PathType Leaf)) { throw "Source project file does not exist: $sourceFull" }

$rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
if (-not $projectFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'The project path must be below FixtureRoot.' }
if (-not $backupFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'The backup project path must be below FixtureRoot.' }
if ($sourceFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'The source project must remain outside FixtureRoot.' }
if ($projectFull -eq $backupFull -or $projectFull -eq $sourceFull) { throw 'Fixture, backup, and source project paths must be distinct.' }

function Get-DirectoryFingerprint([string]$Directory) {
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

$projectDirectory = Split-Path -Parent $projectFull
$backupDirectory = Split-Path -Parent $backupFull
$projectFingerprint = Get-DirectoryFingerprint $projectDirectory
$backupFingerprint = Get-DirectoryFingerprint $backupDirectory
if ($projectFingerprint -ne $backupFingerprint) { throw 'The fixture clone and pre-write backup do not match; refusing to authorize the project.' }

$manifestPath = Join-Path $rootFull '.tia-agent-fixture.json'
if (Test-Path -LiteralPath $manifestPath) { throw "Fixture manifest already exists: $manifestPath" }
$manifest = [ordered]@{
    schemaVersion = 1
    disposable = $true
    createdAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    projectPath = $projectFull
    backupProjectPath = $backupFull
    sourceProjectPath = $sourceFull
    projectSnapshotSha256 = $projectFingerprint
    purpose = 'TIA-Claude disposable Openness acceptance fixture'
}
$json = $manifest | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($manifestPath, $json, [Text.UTF8Encoding]::new($false))
Write-Output ([pscustomobject]@{ ManifestPath = $manifestPath; ProjectPath = $projectFull; ProjectSnapshotSha256 = $projectFingerprint })
