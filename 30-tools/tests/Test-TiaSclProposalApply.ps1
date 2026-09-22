[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Invoke-TiaSclProposalApply.ps1'
$workflowScript = Join-Path $root '30-tools\scripts\Invoke-TiaWorkflow.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-apply-test-' + [guid]::NewGuid().ToString('N'))
$projectFile = Join-Path $temp 'Target_V20.ap20'
$proposalPath = Join-Path $temp 'proposal.json'
$sourcePath = Join-Path $temp 'FB_Motor.s7dcl'
$sclSourcePath = Join-Path $temp 'FB_Valve.scl'
$reportRoot = Join-Path $temp 'reports'
$previewReportRoot = Join-Path $temp 'preview-reports'
$sclPreviewReportRoot = Join-Path $temp 'scl-preview-reports'
$staleReportRoot = Join-Path $temp 'stale-reports'
$unsafePathReportRoot = Join-Path $temp 'unsafe-path-reports'
$writeProfileReportRoot = Join-Path $temp 'write-profile-reports'
$writeAckReportRoot = Join-Path $temp 'write-ack-reports'

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

    $documentApplyReportRoot = Join-Path $temp 'document-apply-reports'
    $documentApplyFailed = $false
    try {
        & $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot $documentApplyReportRoot `
            -Profile write -AcknowledgeWriteProfile -Apply
    }
    catch { $documentApplyFailed = $true }
    if (-not $documentApplyFailed) { throw 'Applying .s7dcl must remain blocked until its exact import result contract is verified.' }
    $documentApplyReports = @(Get-ChildItem -LiteralPath $documentApplyReportRoot -Recurse -File -Filter 'apply-report.json')
    if ($documentApplyReports.Count -ne 1) { throw 'Blocked .s7dcl apply must leave one machine-readable report.' }
    $documentApplyReport = Get-Content -Raw -LiteralPath $documentApplyReports[0].FullName | ConvertFrom-Json
    if ($documentApplyReport.status -ne 'BLOCKED' -or $documentApplyReport.tiaMutation -ne $false -or
        $documentApplyReport.readOnly -ne $true -or $documentApplyReport.import.requiredTool -ne 'ImportFromDocuments' -or
        $documentApplyReport.errors[0] -notmatch 'result counts and exact object readback contract') {
        throw '.s7dcl apply must be blocked with an explicit no-mutation explanation.'
    }
    Write-Output 'PASS: .s7dcl remains preview-only until its import result/readback contract is verified'

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

    $nestedReportRoot = Join-Path $temp 'nested-group-reports'
    $nestedProposalPath = Join-Path $temp 'nested-group-proposal.json'
    $nestedProposal = Get-Content -Raw -LiteralPath $sclProposalPath | ConvertFrom-Json
    $nestedProposal.block.path = 'Area/Subgroup/FB_Valve'
    $nestedProposal | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $nestedProposalPath -Encoding UTF8
    & $script -ProposalPath $nestedProposalPath -ProjectFile $projectFile -ReportRoot $nestedReportRoot
    if ($LASTEXITCODE -ne 0) { throw "A valid nested block group was rejected with exit code $LASTEXITCODE." }
    $nestedReports = @(Get-ChildItem -LiteralPath $nestedReportRoot -Recurse -File -Filter 'apply-report.json')
    if ($nestedReports.Count -ne 1) { throw 'A valid nested group preview must leave one report.' }
    $nestedReport = Get-Content -Raw -LiteralPath $nestedReports[0].FullName | ConvertFrom-Json
    $nestedStage = [IO.Path]::GetFullPath([string]$nestedReport.localValidation.stagedDocument)
    $nestedBoundary = [IO.Path]::GetFullPath((Join-Path $nestedReports[0].Directory.FullName 'documents')).TrimEnd('\') + '\'
    if ($nestedReport.status -ne 'PREVIEW' -or -not $nestedStage.StartsWith($nestedBoundary, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'A valid nested group must preview successfully and remain under the run documents directory.'
    }
    Write-Output 'PASS: ordinary nested block groups remain inside the per-run staging root'

    # Untrusted proposal paths must not escape the per-run documents staging root, even during
    # the local preview path that does not connect to TIA.
    $unsafePathCases = @(
        [pscustomobject]@{ name = 'slash-traversal'; path = '../../../../escaped-staging/FB_Valve' },
        [pscustomobject]@{ name = 'backslash-traversal'; path = '..\..\..\..\escaped-staging\FB_Valve' },
        [pscustomobject]@{ name = 'mixed-separator-traversal'; path = '..\../..\..\escaped-staging/FB_Valve' },
        [pscustomobject]@{ name = 'rooted-path'; path = 'C:\escaped-staging\FB_Valve' },
        [pscustomobject]@{ name = 'empty-segment'; path = 'Area//FB_Valve' }
    )
    foreach ($unsafePathCase in $unsafePathCases) {
        $caseProposalPath = Join-Path $temp ($unsafePathCase.name + '-proposal.json')
        $caseReportRoot = Join-Path $temp ($unsafePathCase.name + '-reports')
        $caseProposal = Get-Content -Raw -LiteralPath $sclProposalPath | ConvertFrom-Json
        $caseProposal.block.path = $unsafePathCase.path
        $caseProposal | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $caseProposalPath -Encoding UTF8
        $caseFailed = $false
        try {
            & $script -ProposalPath $caseProposalPath -ProjectFile $projectFile -ReportRoot $caseReportRoot 2>&1 | Out-Null
        }
        catch { $caseFailed = $true }
        $escapedStageFile = Join-Path $temp 'escaped-staging\FB_Valve.scl'
        if (-not $caseFailed -or (Test-Path -LiteralPath $escapedStageFile -PathType Leaf)) {
            throw "Unsafe block path '$($unsafePathCase.name)' must be blocked before escaping staging."
        }
        $caseReports = @(Get-ChildItem -LiteralPath $caseReportRoot -Recurse -File -Filter 'apply-report.json' -ErrorAction SilentlyContinue)
        if ($caseReports.Count -ne 1) { throw "Unsafe block path '$($unsafePathCase.name)' must leave one machine-readable report." }
        $caseReport = Get-Content -Raw -LiteralPath $caseReports[0].FullName | ConvertFrom-Json
        if ($caseReport.status -ne 'BLOCKED' -or $caseReport.tiaMutation -ne $false) {
            throw "Unsafe block path '$($unsafePathCase.name)' must be BLOCKED without TIA mutation."
        }
    }
    Write-Output 'PASS: slash, backslash, mixed, rooted, and empty-segment block paths are rejected before staging'

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

    $profileFailed = $false
    try {
        & $script -ProposalPath $sclProposalPath -ProjectFile $projectFile -ReportRoot $writeProfileReportRoot -Apply -Profile read -AcknowledgeWriteProfile 2>&1 | Out-Null
    }
    catch { $profileFailed = $true }
    if (-not $profileFailed) { throw 'Direct apply must reject a non-write profile.' }
    $profileReports = @(Get-ChildItem -LiteralPath $writeProfileReportRoot -Recurse -File -Filter 'apply-report.json' -ErrorAction SilentlyContinue)
    if ($profileReports.Count -ne 1) { throw 'Direct profile rejection must leave one machine-readable report.' }
    $profileReport = Get-Content -Raw -LiteralPath $profileReports[0].FullName | ConvertFrom-Json
    if ($profileReport.status -ne 'BLOCKED' -or $profileReport.tiaMutation -ne $false -or $profileReport.readOnly -ne $true) { throw 'Non-write profile rejection must be BLOCKED, read-only, and without TIA mutation.' }
    if ($profileReport.errors[0] -notmatch 'Profile write') { throw 'Profile rejection did not identify the required write profile.' }
    Write-Output 'PASS: direct apply requires the write profile and records a no-mutation BLOCKED report'

    $ackFailed = $false
    try {
        & $script -ProposalPath $sclProposalPath -ProjectFile $projectFile -ReportRoot $writeAckReportRoot -Apply -Profile write 2>&1 | Out-Null
    }
    catch { $ackFailed = $true }
    if (-not $ackFailed) { throw 'Direct apply must reject an unacknowledged write profile.' }
    $ackReports = @(Get-ChildItem -LiteralPath $writeAckReportRoot -Recurse -File -Filter 'apply-report.json' -ErrorAction SilentlyContinue)
    if ($ackReports.Count -ne 1) { throw 'Missing write acknowledgement must leave one machine-readable report.' }
    $ackReport = Get-Content -Raw -LiteralPath $ackReports[0].FullName | ConvertFrom-Json
    if ($ackReport.status -ne 'BLOCKED' -or $ackReport.tiaMutation -ne $false -or $ackReport.readOnly -ne $true) { throw 'Missing acknowledgement must be BLOCKED, read-only, and without TIA mutation.' }
    if ($ackReport.errors[0] -notmatch 'AcknowledgeWriteProfile') { throw 'Acknowledgement rejection did not identify the required confirmation flag.' }
    Write-Output 'PASS: direct apply requires explicit write-profile acknowledgement'

    $missingFixtureReportRoot = Join-Path $temp 'missing-fixture-root-reports'
    $missingFixtureFailed = $false
    try {
        & $script -ProposalPath $sclProposalPath -ProjectFile $projectFile -ReportRoot $missingFixtureReportRoot `
            -Profile write -AcknowledgeWriteProfile -Apply 2>&1 | Out-Null
    }
    catch { $missingFixtureFailed = $true }
    if (-not $missingFixtureFailed) { throw 'A write request without FixtureRoot must be rejected.' }
    $missingFixtureReports = @(Get-ChildItem -LiteralPath $missingFixtureReportRoot -Recurse -File -Filter 'apply-report.json' -ErrorAction SilentlyContinue)
    if ($missingFixtureReports.Count -ne 1) { throw 'Missing FixtureRoot rejection must leave a report before TIA access.' }
    $missingFixtureReport = Get-Content -Raw -LiteralPath $missingFixtureReports[0].FullName | ConvertFrom-Json
    if ($missingFixtureReport.status -ne 'BLOCKED' -or $missingFixtureReport.tiaMutation -ne $false -or
        $missingFixtureReport.errors[0] -notmatch 'FixtureRoot') {
        throw 'Missing FixtureRoot must produce a no-mutation BLOCKED report naming the required fixture root.'
    }
    Write-Output 'PASS: direct apply requires FixtureRoot before any write-profile/TIA work'

    # The write runner must bind its target to a disposable fixture manifest, pass the same
    # root to tia-inspect, and refuse a changed snapshot before it starts any MCP/TIA session.
    $fixtureManifestScript = Join-Path $root '30-tools\scripts\New-TiaFixtureManifest.ps1'
    $fixtureRoot = Join-Path $temp 'isolated-fixture-run'
    $fixtureProjectDirectory = Join-Path $fixtureRoot 'fixture\Demo'
    $fixtureBackupDirectory = Join-Path $fixtureRoot 'backup\Demo'
    $fixtureProjectFile = Join-Path $fixtureProjectDirectory 'Demo_V20.ap20'
    $fixtureBackupFile = Join-Path $fixtureBackupDirectory 'Demo_V20.ap20'
    $fixtureSourceFile = Join-Path $temp 'source-Demo_V20.ap20'
    New-Item -ItemType Directory -Path $fixtureProjectDirectory, $fixtureBackupDirectory -Force | Out-Null
    'disposable source project' | Set-Content -LiteralPath $fixtureSourceFile -Encoding UTF8
    'disposable fixture project' | Set-Content -LiteralPath $fixtureProjectFile -Encoding UTF8
    Copy-Item -LiteralPath $fixtureProjectFile -Destination $fixtureBackupFile
    & $fixtureManifestScript -FixtureRoot $fixtureRoot -ProjectPath $fixtureProjectFile -BackupProjectPath $fixtureBackupFile -SourceProjectPath $fixtureSourceFile -ConfirmedDisposable | Out-Null

    $isolatedProposal = Get-Content -Raw -LiteralPath $sclProposalPath | ConvertFrom-Json
    $isolatedProposal.projectPath = $fixtureProjectFile
    # This claim is intentionally false; it must never substitute for live safety gates.
    $isolatedProposal.checks.noBlockingFindings = $false
    $isolatedProposal.findings = @([ordered]@{ severity = 'BLOCKING'; code = 'TEST_ONLY' })
    $isolatedProposal | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $sclProposalPath -Encoding UTF8

    $isolatedReportRoot = Join-Path $temp 'isolated-reports'
    function global:Get-Process {
        return @([pscustomobject]@{ ProcessName = 'Siemens.Automation.Portal'; MainWindowHandle = [IntPtr]::Zero; Id = 999999 })
    }
    $isolatedFailed = $false
    try {
        & $workflowScript -Workflow apply -ProposalPath $sclProposalPath -ProjectFile $fixtureProjectFile -OutputDirectory $isolatedReportRoot `
            -Profile write -AcknowledgeWriteProfile -Apply -FixtureRoot $fixtureRoot 2>&1 | Out-Null
    }
    catch { $isolatedFailed = $true }
    finally { Remove-Item Function:\global:Get-Process -ErrorAction SilentlyContinue }
    if (-not $isolatedFailed) { throw 'The fixture preflight test must stop at the simulated existing TIA process.' }
    $isolatedReports = @(Get-ChildItem -LiteralPath $isolatedReportRoot -Recurse -File -Filter 'apply-report.json' -ErrorAction SilentlyContinue)
    if ($isolatedReports.Count -ne 1) { throw 'Fixture-gated apply must leave one report before it can reach MCP/TIA.' }
    $isolatedReport = Get-Content -Raw -LiteralPath $isolatedReports[0].FullName | ConvertFrom-Json
    if ($isolatedReport.status -ne 'BLOCKED' -or $isolatedReport.tiaMutation -ne $false) { throw 'The simulated running TIA process must block before mutation.' }
    if ($isolatedReport.fixture.snapshotVerified -ne $true) { throw 'Apply did not verify the exact fixture and backup directory snapshots.' }
    if ($isolatedReport.fixture.projectPath -ne [IO.Path]::GetFullPath($fixtureProjectFile) -or
        $isolatedReport.fixture.backupProjectPath -ne [IO.Path]::GetFullPath($fixtureBackupFile)) {
        throw 'Apply report did not retain the exact project and backup manifest paths.'
    }
    if ($isolatedReport.mcp.isolated -ne $true -or $isolatedReport.mcp.writeEnabled -ne $true -or
        $isolatedReport.mcp.fixtureRoot -ne [IO.Path]::GetFullPath($fixtureRoot) -or
        $isolatedReport.mcp.arguments -notmatch '--isolated' -or
        $isolatedReport.mcp.arguments -notmatch '--fixture-root' -or
        $isolatedReport.mcp.arguments -notmatch '--allow-write') {
        throw 'Write server configuration must include isolated mode, the exact fixture root, and allow-write.'
    }
    if ($isolatedReport.proposalClaims.noBlockingFindings -ne $false -or $isolatedReport.proposalClaims.findingCount -ne 1) {
        throw 'The proposal claim must be recorded as untrusted evidence, not rewritten as authorization.'
    }
    Write-Output 'PASS: proposal apply binds write access to a manifested, unchanged disposable fixture and isolated MCP arguments'

    $otherFixtureProjectFile = Join-Path $fixtureRoot 'other\Demo_V20.ap20'
    New-Item -ItemType Directory -Path (Split-Path -Parent $otherFixtureProjectFile) -Force | Out-Null
    Copy-Item -LiteralPath $fixtureProjectFile -Destination $otherFixtureProjectFile
    $otherProjectProposalPath = Join-Path $temp 'other-project-proposal.json'
    $otherProjectProposal = Get-Content -Raw -LiteralPath $sclProposalPath | ConvertFrom-Json
    $otherProjectProposal.projectPath = $otherFixtureProjectFile
    $otherProjectProposal | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $otherProjectProposalPath -Encoding UTF8
    $wrongProjectReportRoot = Join-Path $temp 'wrong-manifest-project-reports'
    $wrongProjectFailed = $false
    try {
        & $script -ProposalPath $otherProjectProposalPath -ProjectFile $otherFixtureProjectFile -ReportRoot $wrongProjectReportRoot `
            -Profile write -AcknowledgeWriteProfile -Apply -FixtureRoot $fixtureRoot 2>&1 | Out-Null
    }
    catch { $wrongProjectFailed = $true }
    if (-not $wrongProjectFailed) { throw 'A different project path inside FixtureRoot must not pass the exact manifest check.' }
    $wrongProjectReports = @(Get-ChildItem -LiteralPath $wrongProjectReportRoot -Recurse -File -Filter 'apply-report.json' -ErrorAction SilentlyContinue)
    if ($wrongProjectReports.Count -ne 1) { throw 'Manifest project mismatch must leave one report.' }
    $wrongProjectReport = Get-Content -Raw -LiteralPath $wrongProjectReports[0].FullName | ConvertFrom-Json
    if ($wrongProjectReport.status -ne 'BLOCKED' -or $wrongProjectReport.tiaMutation -ne $false -or
        $wrongProjectReport.errors[0] -notmatch 'does not exactly match ProjectFile') {
        throw 'Manifest project mismatch must block before TIA and identify the exact path mismatch.'
    }
    Write-Output 'PASS: proposal apply rejects an alternate project path even when it is inside the manifested fixture root'

    $changedBackupReportRoot = Join-Path $temp 'changed-fixture-backup-reports'
    'backup tampered after manifest creation' | Set-Content -LiteralPath (Join-Path $fixtureBackupDirectory 'sidecar.txt') -Encoding UTF8
    $changedBackupFailed = $false
    try {
        & $script -ProposalPath $sclProposalPath -ProjectFile $fixtureProjectFile -ReportRoot $changedBackupReportRoot `
            -Profile write -AcknowledgeWriteProfile -Apply -FixtureRoot $fixtureRoot 2>&1 | Out-Null
    }
    catch { $changedBackupFailed = $true }
    if (-not $changedBackupFailed) { throw 'A backup changed after manifest creation must be rejected.' }
    $changedBackupReports = @(Get-ChildItem -LiteralPath $changedBackupReportRoot -Recurse -File -Filter 'apply-report.json' -ErrorAction SilentlyContinue)
    if ($changedBackupReports.Count -ne 1) { throw 'Changed backup rejection must leave one report.' }
    $changedBackupReport = Get-Content -Raw -LiteralPath $changedBackupReports[0].FullName | ConvertFrom-Json
    if ($changedBackupReport.status -ne 'BLOCKED' -or $changedBackupReport.tiaMutation -ne $false -or
        $changedBackupReport.errors[0] -notmatch 'backup directory snapshot') {
        throw 'Changed backup must be rejected before TIA access and identify its snapshot mismatch.'
    }
    Remove-Item -LiteralPath (Join-Path $fixtureBackupDirectory 'sidecar.txt') -Force
    Write-Output 'PASS: proposal apply verifies the backup directory snapshot independently'

    $changedProjectReportRoot = Join-Path $temp 'changed-fixture-reports'
    'tampered after manifest creation' | Add-Content -LiteralPath (Join-Path $fixtureProjectDirectory 'sidecar.txt') -Encoding UTF8
    $changedFailed = $false
    try {
        & $script -ProposalPath $sclProposalPath -ProjectFile $fixtureProjectFile -ReportRoot $changedProjectReportRoot `
            -Profile write -AcknowledgeWriteProfile -Apply -FixtureRoot $fixtureRoot 2>&1 | Out-Null
    }
    catch { $changedFailed = $true }
    if (-not $changedFailed) { throw 'A fixture changed after manifest creation must be rejected.' }
    $changedReports = @(Get-ChildItem -LiteralPath $changedProjectReportRoot -Recurse -File -Filter 'apply-report.json' -ErrorAction SilentlyContinue)
    if ($changedReports.Count -ne 1) { throw 'Changed fixture rejection must leave one report.' }
    $changedReport = Get-Content -Raw -LiteralPath $changedReports[0].FullName | ConvertFrom-Json
    if ($changedReport.status -ne 'BLOCKED' -or $changedReport.tiaMutation -ne $false) { throw 'Changed fixture rejection must be BLOCKED before mutation.' }
    if ($changedReport.errors[0] -notmatch 'snapshot') { throw 'Changed fixture rejection did not identify the snapshot mismatch.' }
    Write-Output 'PASS: proposal apply rejects fixture or backup contents that differ from the manifest snapshot'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
