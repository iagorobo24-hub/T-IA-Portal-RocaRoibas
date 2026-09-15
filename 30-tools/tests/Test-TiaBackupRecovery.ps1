[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$restore = Join-Path $WorkspaceRoot '30-tools\scripts\Restore-TiaBackup.ps1'
if (-not (Test-Path -LiteralPath $restore -PathType Leaf)) {
    throw 'Restore-TiaBackup.ps1 is missing.'
}
$restoreText = Get-Content -Raw -LiteralPath $restore
if ($restoreText -notmatch 'ForceActiveProject' -or $restoreText -notmatch 'open in TIA') {
    throw 'Restore script must contain an explicit active-project refusal and force escape hatch.'
}

$latestReport = Get-ChildItem (Join-Path $WorkspaceRoot '70-runs\e2e') -Recurse -Filter report.json -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $latestReport) { throw 'Run the write E2E first; no report.json is available.' }
$report = Get-Content -Raw -LiteralPath $latestReport.FullName | ConvertFrom-Json
$knownBackup = [string]$report.backup.path
$knownProject = Get-ChildItem -LiteralPath $knownBackup -Filter '*.ap20' -File | Select-Object -First 1
if ($null -eq $knownProject) { throw "No .ap20 exists in $knownBackup" }

$testRoot = Join-Path $WorkspaceRoot ('90-tmp\recovery-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
try {
    $missingBackup = Join-Path $testRoot 'missing-backup'
    $missingDestination = Join-Path $testRoot 'missing-destination'
    $missingFailed = $false
    try {
        & $restore -BackupDirectory $missingBackup -DestinationDirectory $missingDestination | Out-Null
        throw 'Missing backup was unexpectedly accepted.'
    } catch {
        $missingFailed = $true
    }
    if (-not $missingFailed) { throw 'Missing backup guard did not fail.' }

    # The active-project guard is verified structurally above. A runtime test
    # requires opening a disposable project and must not displace a user's TIA
    # UI session, so it is intentionally not forced by this offline recovery test.

    # Use a different project filename for the positive copy so any active
    # project guard cannot turn a safe offline restore into a false negative.
    $portableBackup = Join-Path $testRoot 'portable-backup'
    New-Item -ItemType Directory -Path $portableBackup -Force | Out-Null
    $positiveProject = Join-Path $portableBackup 'RecoveryFixture.ap20'
    Copy-Item -LiteralPath $knownProject.FullName -Destination $positiveProject
    $positiveDestination = Join-Path $testRoot 'restored'
    $restoreOutput = & $restore -BackupDirectory $portableBackup -DestinationDirectory $positiveDestination -SkipActiveProjectCheck
    $restoreResult = ($restoreOutput -join "`n") | ConvertFrom-Json
    if (-not $restoreResult.success) { throw 'Positive restore did not report success.' }
    $restoredProject = Join-Path $positiveDestination 'RecoveryFixture.ap20'
    if (-not (Test-Path -LiteralPath $restoredProject -PathType Leaf)) { throw 'Restored .ap20 is missing.' }
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $positiveProject).Hash
    $restoredHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $restoredProject).Hash
    if ($sourceHash -ne $restoredHash) { throw 'Restored project hash differs from backup hash.' }
    Write-Output "PASS: backup recovery (source and restored hash $sourceHash; active-project guard present)"
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
