[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\New-TiaSclProposal.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-proposal-test-' + [guid]::NewGuid().ToString('N'))
$sourceRoot = Join-Path $temp 'src'
$sourcePath = Join-Path $sourceRoot 'Program blocks\FB_Motor.s7dcl'
$analysisPath = Join-Path $temp 'analysis.json'
$blockedAnalysisPath = Join-Path $temp 'blocked-analysis.json'
$outputDirectory = Join-Path $temp 'proposal'
$blockedOutputDirectory = Join-Path $temp 'blocked-proposal'

try {
    New-Item -ItemType Directory -Path (Split-Path -Parent $sourcePath) -Force | Out-Null
    @'
FUNCTION_BLOCK "FB_Motor"
VERSION : 0.1
AUTHOR : TIA_Claude
FAMILY : Drives
BEGIN
   #Run := #CmdStart AND #Interlock;
END_FUNCTION_BLOCK
'@ | Set-Content -LiteralPath $sourcePath -Encoding UTF8
    $analysis = [ordered]@{
        schemaVersion = 1
        readOnly = $true
        projectPath = 'C:\fixture\Demo_V20.ap20'
        sourceRoot = $sourceRoot
        blocks = @([ordered]@{
            name = 'FB_Motor'; path = '01_Devices/FB_Motor'; plc = 'PLC_1'; type = 'FB'; language = 'SCL'
            consistent = $true; knowHowProtected = $false; source = 'Program blocks\FB_Motor.s7dcl'; sourcePresent = $true
        })
        findings = @()
    }
    $analysis | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $analysisPath -Encoding UTF8

    & $script -AnalysisPath $analysisPath -BlockName 'FB_Motor' -FindText '#Run := #CmdStart AND #Interlock;' -ReplaceText '#Run := #CmdStart AND #Interlock AND #Ready;' -OutputDirectory $outputDirectory
    if ($LASTEXITCODE -ne 0) { throw "Proposal command failed with exit code $LASTEXITCODE." }
    $proposalPath = Join-Path $outputDirectory 'proposal.json'
    $proposedSourcePath = Join-Path $outputDirectory 'FB_Motor.s7dcl'
    $diffPath = Join-Path $outputDirectory 'proposal.diff'
    if (-not (Test-Path -LiteralPath $proposalPath -PathType Leaf)) { throw 'Proposal JSON was not created.' }
    if (-not (Test-Path -LiteralPath $proposedSourcePath -PathType Leaf)) { throw 'Proposed source was not created.' }
    if (-not (Test-Path -LiteralPath $diffPath -PathType Leaf)) { throw 'Proposal diff was not created.' }
    $proposal = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    if ($proposal.readOnly -ne $true -or $proposal.applied -ne $false) { throw 'Proposal must be read-only and unapplied.' }
    if ($proposal.status -ne 'PROPOSED') { throw 'Proposal status must be PROPOSED.' }
    if ((Get-Content -Raw -LiteralPath $sourcePath) -notmatch [regex]::Escape('#Run := #CmdStart AND #Interlock;')) { throw 'Original source was modified.' }
    if ((Get-Content -Raw -LiteralPath $proposedSourcePath) -notmatch [regex]::Escape('#Run := #CmdStart AND #Interlock AND #Ready;')) { throw 'Replacement is missing from proposed source.' }
    Write-Output 'PASS: SCL proposal writes only a copy, JSON trace and diff'

    $blocked = Get-Content -Raw -LiteralPath $analysisPath | ConvertFrom-Json
    $blocked.blocks[0].knowHowProtected = $true
    $blocked.findings = @([ordered]@{ severity = 'BLOCKING'; code = 'KNOW_HOW_PROTECTED'; block = 'FB_Motor' })
    $blocked | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $blockedAnalysisPath -Encoding UTF8
    $blockedFailed = $false
    try {
        & $script -AnalysisPath $blockedAnalysisPath -BlockName 'FB_Motor' -FindText '#Run := #CmdStart AND #Interlock;' -ReplaceText '#Run := #CmdStart AND #Interlock AND #Ready;' -OutputDirectory $blockedOutputDirectory 2>&1 | Out-Null
    }
    catch {
        $blockedFailed = $true
    }
    if (-not $blockedFailed -and $LASTEXITCODE -eq 0) { throw 'Protected block proposal should have been refused.' }
    if (Test-Path -LiteralPath (Join-Path $blockedOutputDirectory 'proposal.json')) { throw 'Protected block produced a proposal unexpectedly.' }
    Write-Output 'PASS: SCL proposal refuses protected blocks before writing artifacts'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
