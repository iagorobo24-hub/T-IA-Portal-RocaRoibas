[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath($WorkspaceRoot)
$script = Join-Path $workspace '30-tools\scripts\New-TiaFixtureManifest.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('tia-fixture-manifest-test-' + [guid]::NewGuid().ToString('N'))
$fixtureDirectory = Join-Path $testRoot 'fixture'
$backupDirectory = Join-Path $testRoot 'backup'
$sourceDirectory = Join-Path ([IO.Path]::GetTempPath()) ('tia-fixture-manifest-source-' + [guid]::NewGuid().ToString('N'))
$fixtureProject = Join-Path $fixtureDirectory 'Demo.ap20'
$backupProject = Join-Path $backupDirectory 'Demo.ap20'
$sourceProject = Join-Path $sourceDirectory 'Demo.ap20'

try {
    foreach ($directory in @($fixtureDirectory, $backupDirectory, $sourceDirectory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    [IO.File]::WriteAllText($fixtureProject, 'fixture-project')
    [IO.File]::WriteAllText($backupProject, 'fixture-project')
    New-Item -ItemType Directory -Path $sourceDirectory -Force | Out-Null
    [IO.File]::WriteAllText($sourceProject, 'original-source')
    [IO.File]::WriteAllText((Join-Path $fixtureDirectory 'sidecar.txt'), 'sidecar')
    [IO.File]::WriteAllText((Join-Path $backupDirectory 'sidecar.txt'), 'sidecar')

    & $script -FixtureRoot $testRoot -ProjectPath $fixtureProject -BackupProjectPath $backupProject -SourceProjectPath $sourceProject -ConfirmedDisposable | Out-Null
    $manifestPath = Join-Path $testRoot '.tia-agent-fixture.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Manifest was not created.' }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if ($manifest.disposable -ne $true -or [IO.Path]::GetFullPath($manifest.projectPath) -ne [IO.Path]::GetFullPath($fixtureProject)) {
        throw 'Manifest does not identify the expected disposable project.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.projectSnapshotSha256)) { throw 'Manifest lacks the pre-write snapshot hash.' }

    $mismatchRoot = Join-Path $testRoot 'mismatch'
    $mismatchFixture = Join-Path $mismatchRoot 'fixture'
    $mismatchBackup = Join-Path $mismatchRoot 'backup'
    foreach ($directory in @($mismatchFixture, $mismatchBackup)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    [IO.File]::WriteAllText((Join-Path $mismatchFixture 'Demo.ap20'), 'changed-project')
    [IO.File]::WriteAllText((Join-Path $mismatchBackup 'Demo.ap20'), 'original-project')
    $rejected = $false
    try {
        & $script -FixtureRoot $mismatchRoot -ProjectPath (Join-Path $mismatchFixture 'Demo.ap20') -BackupProjectPath (Join-Path $mismatchBackup 'Demo.ap20') -SourceProjectPath $sourceProject -ConfirmedDisposable | Out-Null
    }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'A mismatched fixture and backup were incorrectly authorized.' }
    Write-Output 'PASS: exact disposable path is recorded only after fixture and backup hashes match.'
}
finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($resolvedTestRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
    $resolvedSourceDirectory = [IO.Path]::GetFullPath($sourceDirectory)
    if ($resolvedSourceDirectory.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedSourceDirectory)) {
        Remove-Item -LiteralPath $resolvedSourceDirectory -Recurse -Force
    }
}
