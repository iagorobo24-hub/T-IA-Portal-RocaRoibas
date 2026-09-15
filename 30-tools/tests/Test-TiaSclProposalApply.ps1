[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Invoke-TiaSclProposalApply.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-apply-test-' + [guid]::NewGuid().ToString('N'))
$projectFile = Join-Path $temp 'Target_V20.ap20'
$proposalPath = Join-Path $temp 'proposal.json'
$sourcePath = Join-Path $temp 'FB_Motor.s7dcl'
$sclSourcePath = Join-Path $temp 'FB_Valve.scl'
$reportRoot = Join-Path $temp 'reports'
$previewReportRoot = Join-Path $temp 'preview-reports'
$sclPreviewReportRoot = Join-Path $temp 'scl-preview-reports'
$staleReportRoot = Join-Path $temp 'stale-reports'

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    'fixture project marker' | Set-Content -LiteralPath $projectFile -Encoding UTF8
    @'
FUNCTION_BLOCK "FB_Motor"
VERSION : 0.1
BEGIN
   #Run := TRUE;
END_FUNCTION_BLOCK
'@ | Set-Content -LiteralPath $sourcePath -Encoding UTF8
    @'
FUNCTION_BLOCK "FB_Valve"
BEGIN
   #Open := TRUE;
END_FUNCTION_BLOCK
'@ | Set-Content -LiteralPath $sclSourcePath -Encoding UTF8
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash.ToLowerInvariant()
    [ordered]@{
        schemaVersion = 1; status = 'PROPOSED'; readOnly = $true; applied = $false; tiaMutation = $false
        projectPath = 'C:\fixture\DifferentProject_V20.ap20'; sourceRoot = $temp
        plc = 'PLC_1'
        block = [ordered]@{ name = 'FB_Motor'; path = '01_Devices/FB_Motor'; language = 'SCL' }
        source = [ordered]@{ originalPath = $sourcePath; proposedPath = $sourcePath; proposedSha256 = $hash; originalSha256 = $hash; matchCount = 1 }
        checks = [ordered]@{ exactBlockMatch = $true; sclOnly = $true; noBlockingFindings = $true; uniqueReplacement = $true; originalUntouched = $true }
        findings = @()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $proposalPath -Encoding UTF8

    $applyFailed = $false
    try {
        & $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot $reportRoot
    }
    catch {
        $applyFailed = $true
    }
    if (-not $applyFailed -and $LASTEXITCODE -eq 0) { throw 'Mismatched proposal/project should have been rejected.' }
    if (Test-Path -LiteralPath $reportRoot) {
        $reports = @(Get-ChildItem -LiteralPath $reportRoot -Recurse -File -Filter 'apply-report.json')
        if ($reports.Count -ne 1) { throw 'A rejected apply must still leave one machine-readable report.' }
        $report = Get-Content -Raw -LiteralPath $reports[0].FullName | ConvertFrom-Json
        if ($report.status -ne 'BLOCKED') { throw 'Mismatched proposal must be reported as BLOCKED.' }
        if ($report.tiaMutation -ne $false) { throw 'Blocked local validation must record no TIA mutation.' }
    }
    else { throw 'Blocked apply did not create its evidence directory.' }
    Write-Output 'PASS: proposal apply rejects project mismatch before connecting to TIA'

    $matching = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $matching.projectPath = $projectFile
    $matching | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $proposalPath -Encoding UTF8
    & $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot $previewReportRoot
    if ($LASTEXITCODE -ne 0) { throw "Local preview failed with exit code $LASTEXITCODE." }
    $previewReports = @(Get-ChildItem -LiteralPath $previewReportRoot -Recurse -File -Filter 'apply-report.json')
    if ($previewReports.Count -ne 1) { throw 'Local preview must leave one report.' }
    $preview = Get-Content -Raw -LiteralPath $previewReports[0].FullName | ConvertFrom-Json
    if ($preview.status -ne 'PREVIEW' -or $preview.tiaMutation -ne $false) { throw 'Local preview must be PREVIEW with no TIA mutation.' }
    if ($preview.preflight.success -ne $false) { throw 'Local preview must not run TIA preflight.' }
    Write-Output 'PASS: proposal apply performs a local preview without connecting to TIA'

    $sclHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sclSourcePath).Hash.ToLowerInvariant()
    $sclProposalPath = Join-Path $temp 'scl-proposal.json'
    [ordered]@{
        schemaVersion = 1; status = 'PROPOSED'; readOnly = $true; applied = $false; tiaMutation = $false
        projectPath = $projectFile; sourceRoot = $temp; plc = 'PLC_1'
        block = [ordered]@{ name = 'FB_Valve'; path = 'FB_Valve'; language = 'SCL' }
        source = [ordered]@{ originalPath = $sclSourcePath; proposedPath = $sclSourcePath; proposedSha256 = $sclHash; originalSha256 = $sclHash; matchCount = 1; extension = '.scl' }
        checks = [ordered]@{ exactBlockMatch = $true; sclOnly = $true; noBlockingFindings = $true; uniqueReplacement = $true; originalUntouched = $true }
        findings = @()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $sclProposalPath -Encoding UTF8
    & $script -ProposalPath $sclProposalPath -ProjectFile $projectFile -ReportRoot $sclPreviewReportRoot
    if ($LASTEXITCODE -ne 0) { throw "SCL local preview failed with exit code $LASTEXITCODE." }
    $sclPreviewReports = @(Get-ChildItem -LiteralPath $sclPreviewReportRoot -Recurse -File -Filter 'apply-report.json')
    if ($sclPreviewReports.Count -ne 1) { throw 'SCL local preview must leave one report.' }
    $sclPreview = Get-Content -Raw -LiteralPath $sclPreviewReports[0].FullName | ConvertFrom-Json
    if ($sclPreview.localValidation.importMode -ne 'external-source') { throw 'SCL preview must select external-source import mode.' }
    if ($sclPreview.preview.kind -ne 'external-source') { throw 'SCL preview must record the external-source preview kind.' }
    Write-Output 'PASS: SCL proposal apply stages ImportSources mode during local preview'

    $staleOriginalPath = Join-Path $temp 'FB_Stale.original.scl'
    $staleProposedPath = Join-Path $temp 'FB_Stale.proposed.scl'
    $staleText = 'FUNCTION_BLOCK "FB_Stale"`r`nBEGIN`r`n   #Run := TRUE;`r`nEND_FUNCTION_BLOCK`r`n'
    [IO.File]::WriteAllText($staleOriginalPath, $staleText, [Text.UTF8Encoding]::new($true))
    [IO.File]::WriteAllText($staleProposedPath, $staleText.Replace('#Run := TRUE;', '#Run := FALSE;'), [Text.UTF8Encoding]::new($true))
    $staleOriginalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $staleOriginalPath).Hash.ToLowerInvariant()
    $staleProposedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $staleProposedPath).Hash.ToLowerInvariant()
    [IO.File]::AppendAllText($staleOriginalPath, '// changed after proposal`r`n', [Text.UTF8Encoding]::new($true))
    $staleProposalPath = Join-Path $temp 'stale-proposal.json'
    [ordered]@{
        schemaVersion = 1; status = 'PROPOSED'; readOnly = $true; applied = $false; tiaMutation = $false
        projectPath = $projectFile; sourceRoot = $temp; plc = 'PLC_1'
        block = [ordered]@{ name = 'FB_Stale'; path = 'FB_Stale'; language = 'SCL' }
        source = [ordered]@{ originalPath = $staleOriginalPath; proposedPath = $staleProposedPath; proposedSha256 = $staleProposedHash; originalSha256 = $staleOriginalHash; matchCount = 1; extension = '.scl' }
        checks = [ordered]@{ exactBlockMatch = $true; sclOnly = $true; noBlockingFindings = $true; uniqueReplacement = $true; originalUntouched = $true }
        findings = @()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $staleProposalPath -Encoding UTF8
    $staleFailed = $false
    try { & $script -ProposalPath $staleProposalPath -ProjectFile $projectFile -ReportRoot $staleReportRoot 2>&1 | Out-Null } catch { $staleFailed = $true }
    if (-not $staleFailed) { throw 'A stale original source should have been rejected.' }
    $staleReports = @(Get-ChildItem -LiteralPath $staleReportRoot -Recurse -File -Filter 'apply-report.json')
    if ($staleReports.Count -ne 1) { throw 'A stale source rejection must leave one report.' }
    $staleReport = Get-Content -Raw -LiteralPath $staleReports[0].FullName | ConvertFrom-Json
    if ($staleReport.status -ne 'BLOCKED' -or $staleReport.tiaMutation -ne $false) { throw 'Stale source rejection must be BLOCKED without TIA mutation.' }
    if ($staleReport.errors[0] -notmatch 'original source hash') { throw 'Stale source rejection did not identify the original hash mismatch.' }
    Write-Output 'PASS: proposal apply rejects a stale original source before staging or TIA access'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
