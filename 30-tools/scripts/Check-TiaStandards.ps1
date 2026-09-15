[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InventoryPath,
    [Parameter(Mandatory = $true)]
    [string]$ExportPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$InventoryPath = [IO.Path]::GetFullPath($InventoryPath)
$ExportPath = [IO.Path]::GetFullPath($ExportPath)
if (-not (Test-Path -LiteralPath $InventoryPath -PathType Leaf)) { throw "Inventory does not exist: $InventoryPath" }
if (-not (Test-Path -LiteralPath $ExportPath -PathType Container)) { throw "Export directory does not exist: $ExportPath" }

$inventory = Get-Content -Raw -LiteralPath $InventoryPath | ConvertFrom-Json
$findings = [System.Collections.Generic.List[object]]::new()

function Add-Finding([string]$Code, [string]$Severity, [string]$Message, [string]$Path = '') {
    $findings.Add([ordered]@{
        code = $Code
        severity = $Severity
        message = $Message
        path = $Path
    })
}

$blocks = @($inventory.blocks)
foreach ($block in $blocks) {
    if ($block.isConsistent -ne $true) {
        Add-Finding 'INCONSISTENT_BLOCK' 'error' "Block '$($block.name)' is inconsistent; compile before accepting the project." ([string]$block.path)
    }
    if ($block.isKnowHowProtected -eq $true) {
        Add-Finding 'PROTECTED_BLOCK' 'blocked' "Block '$($block.name)' is know-how protected and must not be edited by the agent." ([string]$block.path)
    }
}

$defaultTagCount = 0
if ($null -ne $inventory.defaultTagCount) { $defaultTagCount = [int]$inventory.defaultTagCount }
if ($defaultTagCount -gt 0) {
    Add-Finding 'DEFAULT_TAG_TABLE' 'error' "$defaultTagCount tag(s) are in the Default tag table; classify them in an intentional table."
}

$exportFiles = @(Get-ChildItem -LiteralPath $ExportPath -Recurse -File -ErrorAction SilentlyContinue)
$blockExportFiles = @($exportFiles | Where-Object {
    $_.FullName -match '[\\/]Program blocks[\\/]' -and $_.Extension -in @('.s7dcl', '.s7res', '.scl', '.awl', '.xml')
})
if ($blocks.Count -gt 0 -and $blockExportFiles.Count -eq 0) {
    Add-Finding 'MISSING_EXPORT' 'error' 'The export contains no reviewable Program blocks source files.' $ExportPath
}

$commentless = @($blocks | Where-Object { $null -ne $_.comment -and $_.comment -eq $false })
foreach ($block in $commentless) {
    Add-Finding 'MISSING_BLOCK_COMMENT' 'warning' "Block '$($block.name)' has no recorded header comment." ([string]$block.path)
}

$errors = @($findings | Where-Object { $_.severity -in @('error', 'blocked') })
$result = [ordered]@{
    schemaVersion = 1
    success = ($errors.Count -eq 0)
    inventoryPath = $InventoryPath
    exportPath = $ExportPath
    summary = [ordered]@{
        blocks = $blocks.Count
        exportFiles = $exportFiles.Count
        findings = $findings.Count
        blockingFindings = $errors.Count
    }
    findings = @($findings)
}
$json = $result | ConvertTo-Json -Depth 10
if ($OutputPath) {
    $OutputPath = [IO.Path]::GetFullPath($OutputPath)
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
    $json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
Write-Output $json
if (-not $result.success) { exit 1 }
exit 0
