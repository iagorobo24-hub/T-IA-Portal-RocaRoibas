[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupDirectory,
    [Parameter(Mandatory = $true)]
    [string]$DestinationDirectory,
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch]$ForceActiveProject,
    [switch]$SkipActiveProjectCheck
)

$ErrorActionPreference = 'Stop'
$BackupDirectory = [IO.Path]::GetFullPath($BackupDirectory)
$DestinationDirectory = [IO.Path]::GetFullPath($DestinationDirectory)
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)

if (-not (Test-Path -LiteralPath $BackupDirectory -PathType Container)) {
    throw "Backup directory does not exist: $BackupDirectory"
}
if (Test-Path -LiteralPath $DestinationDirectory) {
    throw "Destination already exists; restore only creates a new directory: $DestinationDirectory"
}

$backupProjectFiles = @(Get-ChildItem -LiteralPath $BackupDirectory -Filter '*.ap20' -File)
if ($backupProjectFiles.Count -ne 1) {
    throw "Backup must contain exactly one .ap20 project file; found $($backupProjectFiles.Count)."
}
$backupProjectFile = $backupProjectFiles[0]

if (-not $SkipActiveProjectCheck) {
    $invoke = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-TiaMcp.ps1'
    if (-not (Test-Path -LiteralPath $invoke -PathType Leaf)) {
        throw "Cannot check for an active TIA project because $invoke is missing."
    }
    $stateResults = & $invoke -Calls @(
        @{ name = 'Connect' },
        @{ name = 'GetState' }
    ) -TiaMajor 20 -TimeoutSeconds 180
    $stateResult = @($stateResults | Where-Object { $_.Tool -eq 'GetState' } | Select-Object -Last 1)
    if ($stateResult.Count -ne 1 -or $stateResult[0].IsError) {
        throw 'Could not verify the active TIA project; restore refused.'
    }
    $state = $stateResult[0].Text | ConvertFrom-Json
    $activeProjectName = [string]$state.project
    $backupProjectName = [IO.Path]::GetFileNameWithoutExtension($backupProjectFile.Name)
    if ($activeProjectName -ne '-' -and $activeProjectName -eq $backupProjectName -and -not $ForceActiveProject) {
        throw "Project '$backupProjectName' is open in TIA; close it or use -ForceActiveProject explicitly."
    }
}

New-Item -ItemType Directory -Path (Split-Path -Parent $DestinationDirectory) -Force | Out-Null
Copy-Item -LiteralPath $BackupDirectory -Destination $DestinationDirectory -Recurse -Force

$restoredProjectFile = Join-Path $DestinationDirectory $backupProjectFile.Name
if (-not (Test-Path -LiteralPath $restoredProjectFile -PathType Leaf)) {
    throw "Restore completed without the expected project file: $restoredProjectFile"
}
$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backupProjectFile.FullName).Hash
$restoredHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $restoredProjectFile).Hash
if ($sourceHash -ne $restoredHash) {
    throw "Restore verification failed: source hash $sourceHash differs from restored hash $restoredHash."
}

[ordered]@{
    success = $true
    backupDirectory = $BackupDirectory
    destinationDirectory = $DestinationDirectory
    projectFile = $restoredProjectFile
    sha256 = $restoredHash
} | ConvertTo-Json -Depth 5
