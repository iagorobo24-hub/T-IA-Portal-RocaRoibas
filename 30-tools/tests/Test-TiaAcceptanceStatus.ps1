[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Write-TiaAcceptanceStatus.ps1'
$tempPath = Join-Path $env:TEMP ('tia-claude-acceptance-' + [guid]::NewGuid().ToString('N') + '.json')
$negativeEvidencePath = Join-Path $env:TEMP ('tia-claude-acceptance-negative-' + [guid]::NewGuid().ToString('N') + '.json')
$negativeOutputPath = Join-Path $env:TEMP ('tia-claude-acceptance-negative-result-' + [guid]::NewGuid().ToString('N') + '.json')
$portableValidationPath = Join-Path $env:TEMP ('tia-claude-portable-validation-' + [guid]::NewGuid().ToString('N') + '.json')
try {
    [ordered]@{ schemaVersion = 1; checks = [ordered]@{
        package = [ordered]@{ status = 'PASS' }
        contents = [ordered]@{ status = 'PASS' }
        relocation = [ordered]@{ status = 'PASS' }
    } } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $portableValidationPath -Encoding UTF8
    & $scriptPath -WorkspaceRoot $WorkspaceRoot -OutputPath $tempPath -PortableValidationPath $portableValidationPath | Out-Null
    $report = Get-Content -Raw -LiteralPath $tempPath | ConvertFrom-Json
    if ($null -eq $report.verified -or $report.verified.Count -lt 3) { throw 'Acceptance status did not record verified evidence.' }
    if ($report.notVerified.Count -lt 2) { throw 'Acceptance status must preserve incomplete runtime claims.' }
    if ($report.accepted -eq $true) { throw 'Acceptance must remain false before live scaffold/simulation evidence.' }
    if (-not $report.evidence.simulationReadiness) { throw 'Acceptance status must reference the simulation readiness preflight.' }
    if ($report.simulation.plcsimCompatibleWithTia -ne $true -or
        $report.simulation.tiaMajor -ne 20 -or $report.simulation.plcsimAdvanced -ne '7.0.0.0') {
        throw 'Acceptance status must report the installed TIA V20 / PLCSIM Advanced V7 pairing.'
    }
    if (@($report.blocked | Where-Object { $_ -match 'PLCSIM Advanced .* no está en la matriz admitida para TIA Portal 20' }).Count -gt 0) {
        throw 'Acceptance status must not retain the resolved Siemens V6 compatibility blocker.'
    }
    if ($report.verified -notcontains 'portable core installation and relocation') {
        throw 'Acceptance status must include the portable installation evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.portableValidation) -or
        [IO.Path]::GetFullPath([string]$report.evidence.portableValidation) -ne [IO.Path]::GetFullPath($portableValidationPath)) {
        throw "Acceptance status must identify the explicit portable validation evidence used by this test. Expected '$portableValidationPath'; got '$($report.evidence.portableValidation)'."
    }
    if ($report.verified -notcontains 'tia-create MCP startup and lite tool roster') {
        throw 'Acceptance status must include the tia-create smoke evidence.'
    }
    if ($report.notVerified -notcontains 'comportamiento funcional PLC probado en PLCSIM') {
        throw 'Acceptance status must preserve the missing PLCSIM behavior evidence.'
    }
    if ($null -eq $report.computerUse -or $report.computerUse.status -eq 'not_verified') {
        throw 'Acceptance status must expose native Computer Use evidence separately.'
    }
    if ($report.computerUse.safetyBoundary.status -ne 'verified') {
        throw 'Computer Use safety boundary must remain verified in acceptance output.'
    }
    if ($null -eq $report.evidence.computerUse -or $report.evidence.computerUse.Count -lt 1) {
        throw 'Acceptance status must reference the Computer Use evidence files.'
    }
    $tagLifecycleFinding = 'MCP tag lifecycle: create/update/export/compile/save/delete + independent readback'
    if ($report.verified -notcontains $tagLifecycleFinding) {
        throw 'Acceptance status must include the verified MCP tag lifecycle finding.'
    }
    if ($null -eq $report.evidence.tagLifecycle -or $report.evidence.tagLifecycle.status -ne 'verified') {
        throw 'Acceptance status must expose verified MCP tag lifecycle evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.tagLifecycle.path) -or
        [string]$report.evidence.tagLifecycle.path -notmatch '(?i)mcp-tag-lifecycle-.*\.json$') {
        throw 'Acceptance status must reference the mcp-tag-lifecycle evidence file.'
    }
    $watchLifecycleFinding = 'MCP watch table lifecycle: create/export/compile/save/delete + independent readback'
    if ($report.verified -notcontains $watchLifecycleFinding) {
        throw 'Acceptance status must include the verified MCP watch-table lifecycle finding.'
    }
    if ($null -eq $report.evidence.watchLifecycle -or $report.evidence.watchLifecycle.status -ne 'verified') {
        throw 'Acceptance status must expose verified MCP watch-table lifecycle evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.watchLifecycle.path) -or
        [string]$report.evidence.watchLifecycle.path -notmatch '(?i)mcp-watch-acceptance-.*\.json$') {
        throw 'Acceptance status must reference the mcp-watch-acceptance evidence file.'
    }

    $instanceDbLifecycleFinding = 'MCP Instance DB lifecycle: create/compile/export/save/references/delete + independent readback'
    if ($report.verified -notcontains $instanceDbLifecycleFinding) {
        throw 'Acceptance status must include the verified MCP Instance DB lifecycle finding.'
    }
    if ($null -eq $report.evidence.instanceDbLifecycle -or $report.evidence.instanceDbLifecycle.status -ne 'verified') {
        throw 'Acceptance status must expose verified MCP Instance DB lifecycle evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.instanceDbLifecycle.path) -or
        $report.evidence.instanceDbLifecycle.path -notmatch '(?i)mcp-instancedb-acceptance-.*\.json$') {
        throw 'Acceptance status must reference the mcp-instancedb-acceptance evidence file.'
    }
    $tagTableLifecycleFinding = 'MCP PLC tag table lifecycle: create/export/compile/save/delete + independent readback'
    if ($report.verified -notcontains $tagTableLifecycleFinding) {
        throw 'Acceptance status must include the verified MCP PLC tag-table lifecycle finding.'
    }
    if ($null -eq $report.evidence.tagTableLifecycle -or $report.evidence.tagTableLifecycle.status -ne 'verified') {
        throw 'Acceptance status must expose verified MCP PLC tag-table lifecycle evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.tagTableLifecycle.path) -or
        $report.evidence.tagTableLifecycle.path -notmatch '(?i)mcp-tagtable-acceptance-.*\.json$') {
        throw 'Acceptance status must reference the mcp-tagtable-acceptance evidence file.'
    }
    $tagTableImportLifecycleFinding = 'MCP PLC tag table import: import/compile/save + independent readback and directory restore'
    if ($report.verified -notcontains $tagTableImportLifecycleFinding) {
        throw 'Acceptance status must include the verified PLC tag-table import lifecycle finding.'
    }
    if ($null -eq $report.evidence.tagTableImportLifecycle -or $report.evidence.tagTableImportLifecycle.status -ne 'verified') {
        throw 'Acceptance status must expose verified PLC tag-table import evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.tagTableImportLifecycle.path) -or
        $report.evidence.tagTableImportLifecycle.path -notmatch '(?i)mcp-import-tagtable-acceptance-.*\.json$') {
        throw 'Acceptance status must reference the mcp-import-tagtable-acceptance evidence file.'
    }
    $tagTableMemberImportFinding = 'MCP PLC tag table import with two standard tags: compile/save/readback/restore'
    if ($report.verified -notcontains $tagTableMemberImportFinding) {
        throw 'Acceptance status must include the verified non-empty PLC tag-table import finding.'
    }
    if ($null -eq $report.evidence.tagTableMemberImportLifecycle -or $report.evidence.tagTableMemberImportLifecycle.status -ne 'verified') {
        throw 'Acceptance status must expose verified non-empty PLC tag-table import evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.tagTableMemberImportLifecycle.path) -or
        $report.evidence.tagTableMemberImportLifecycle.path -notmatch '(?i)mcp-import-tagtable-member-acceptance-.*\.json$') {
        throw 'Acceptance status must reference the mcp-import-tagtable-member-acceptance evidence file.'
    }
    $blockGroupLifecycleFinding = 'MCP block-group lifecycle: create/delete/compile/save + independent readback'
    if ($report.verified -notcontains $blockGroupLifecycleFinding) {
        throw 'Acceptance status must include the verified MCP block-group lifecycle finding.'
    }
    if ($null -eq $report.evidence.blockGroupLifecycle -or $report.evidence.blockGroupLifecycle.status -ne 'verified') {
        throw 'Acceptance status must expose verified MCP block-group lifecycle evidence.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.evidence.blockGroupLifecycle.path) -or
        $report.evidence.blockGroupLifecycle.path -notmatch '(?i)mcp-blockgroup-acceptance-.*\.json$') {
        throw 'Acceptance status must reference the mcp-blockgroup-acceptance evidence file.'
    }

    # A window id and version alone cannot establish a native target or the
    # physical/Safety boundary. Keep this regression probe deliberately sparse
    # so a future parser change cannot turn metadata into a false PASS.
    '{"harness":"native @oai/sky Computer Use","tiaMajorVersion":20,"windowId":123,"windowSelection":"yes","safetyAndHardware":{}}' |
        Set-Content -LiteralPath $negativeEvidencePath -Encoding UTF8
    & $scriptPath -WorkspaceRoot $WorkspaceRoot -OutputPath $negativeOutputPath -ComputerUseEvidencePaths $negativeEvidencePath | Out-Null
    $negative = Get-Content -Raw -LiteralPath $negativeOutputPath | ConvertFrom-Json
    if ($negative.computerUse.nativeWindowInventory.status -eq 'verified') {
        throw 'Sparse Computer Use evidence must not verify a native TIA window.'
    }
    if ($negative.computerUse.safetyBoundary.status -eq 'verified') {
        throw 'An empty safety declaration must not verify the safety boundary.'
    }
    if ($null -eq $report.checks) { throw 'Acceptance status must expose the aggregate check summary.' }

    # The three import/block-group lifecycles trust recorded fields and referenced
    # reports under 70-runs. Keep one corrupted-evidence case per reworked condition
    # so a future edit cannot silently re-loosen these gates. Each case tampers a
    # durable file in place, then restores the original bytes and verifies the
    # SHA-256, so the evidence tree stays bit-identical.
    $emptyTableAcceptancePath = Join-Path $WorkspaceRoot '70-runs\e2e\mcp-import-tagtable-acceptance-20260923.json'
    $memberAcceptancePath = Join-Path $WorkspaceRoot '70-runs\e2e\mcp-import-tagtable-member-acceptance-20260923.json'
    $blockGroupAcceptancePath = Join-Path $WorkspaceRoot '70-runs\e2e\mcp-blockgroup-acceptance-20260923.json'
    foreach ($requiredEvidence in @($emptyTableAcceptancePath, $memberAcceptancePath, $blockGroupAcceptancePath)) {
        if (-not (Test-Path -LiteralPath $requiredEvidence -PathType Leaf)) {
            throw "Corrupted-evidence regression cases require the durable acceptance evidence file: $requiredEvidence"
        }
    }

    function Invoke-CorruptedEvidenceCase {
        param(
            [string]$Name,
            [string]$EvidencePath,
            [scriptblock]$Tamper,
            [string]$BlockName,
            [string]$ExpectedStatus,
            [string]$ExpectedReason
        )
        # Latin-1 round-trips every byte, so untouched regions stay byte-identical
        # and only the ASCII tamper target changes.
        $evidenceEncoding = [Text.Encoding]::GetEncoding(28591)
        $originalBytes = [IO.File]::ReadAllBytes($EvidencePath)
        $originalHash = (Get-FileHash -LiteralPath $EvidencePath -Algorithm SHA256).Hash
        $originalWriteTime = (Get-Item -LiteralPath $EvidencePath).LastWriteTimeUtc
        $caseOutputPath = Join-Path $env:TEMP ('tia-claude-acceptance-corrupt-' + [guid]::NewGuid().ToString('N') + '.json')
        $caseFailure = $null
        try {
            $tamperedText = & $Tamper ($evidenceEncoding.GetString($originalBytes))
            [IO.File]::WriteAllBytes($EvidencePath, $evidenceEncoding.GetBytes([string]$tamperedText))
            & $scriptPath -WorkspaceRoot $WorkspaceRoot -OutputPath $caseOutputPath -PortableValidationPath $portableValidationPath | Out-Null
            $caseReport = Get-Content -Raw -LiteralPath $caseOutputPath | ConvertFrom-Json
            $caseBlock = $caseReport.evidence.$BlockName
            if ($null -eq $caseBlock) {
                throw "[$Name] acceptance status did not expose the $BlockName evidence block."
            }
            if ($caseBlock.status -ne $ExpectedStatus) {
                throw "[$Name] corrupted evidence must reject $BlockName as '$ExpectedStatus'; got '$($caseBlock.status)'."
            }
            if (@($caseBlock.failureReasons) -notcontains $ExpectedReason) {
                throw "[$Name] $BlockName did not report the expected reason. Expected '$ExpectedReason'; got '$(@($caseBlock.failureReasons) -join ' | ')'."
            }
            foreach ($siblingBlock in @('tagTableImportLifecycle', 'tagTableMemberImportLifecycle', 'blockGroupLifecycle')) {
                if ($siblingBlock -ne $BlockName -and $caseReport.evidence.$siblingBlock.status -ne 'verified') {
                    throw "[$Name] corrupting $BlockName evidence also rejected the unaffected $siblingBlock block."
                }
            }
        } catch {
            $caseFailure = $_
        } finally {
            [IO.File]::WriteAllBytes($EvidencePath, $originalBytes)
            (Get-Item -LiteralPath $EvidencePath).LastWriteTimeUtc = $originalWriteTime
            $restoredHash = (Get-FileHash -LiteralPath $EvidencePath -Algorithm SHA256).Hash
            if ($restoredHash -ne $originalHash) {
                throw "[$Name] failed to restore $EvidencePath byte-for-byte; expected $originalHash, got $restoredHash."
            }
            if (Test-Path -LiteralPath $caseOutputPath) { Remove-Item -LiteralPath $caseOutputPath -Force }
        }
        if ($caseFailure) { throw $caseFailure }
        Write-Output "PASS: corrupted evidence rejected - $Name"
    }

    $corruptedEvidenceCases = @(
        [ordered]@{
            Name = 'truncated import acceptance JSON'
            EvidencePath = $emptyTableAcceptancePath
            Tamper = { param([string]$text) $text.Substring(0, 40) }
            BlockName = 'tagTableImportLifecycle'
            ExpectedStatus = 'invalid'
            ExpectedReason = 'The newest mcp-import-tagtable-acceptance evidence is not valid JSON.'
        },
        [ordered]@{
            Name = 'mismatched restored project hash'
            EvidencePath = $emptyTableAcceptancePath
            Tamper = {
                param([string]$text)
                $key = '"projectSha256AfterRestore"'
                $keyIndex = $text.IndexOf($key)
                if ($keyIndex -lt 0) { throw 'projectSha256AfterRestore was not found in the import evidence.' }
                $valueStart = $text.IndexOf('"', $keyIndex + $key.Length)
                if ($valueStart -lt 0) { throw 'projectSha256AfterRestore has no string value.' }
                $valueStart = $valueStart + 1
                if ($text.Substring($valueStart, 64) -notmatch '^[0-9A-Fa-f]{64}$') { throw 'projectSha256AfterRestore is not a 64-character hex hash.' }
                $text.Remove($valueStart, 64).Insert($valueStart, ('0' * 64))
            }
            BlockName = 'tagTableImportLifecycle'
            ExpectedStatus = 'not_verified'
            ExpectedReason = 'fixture must restore the complete project directory, preserve the source, and match all baseline hashes.'
        },
        [ordered]@{
            Name = 'directory file count mismatch'
            EvidencePath = $emptyTableAcceptancePath
            Tamper = {
                param([string]$text)
                $key = '"directoryFileCount"'
                $keyIndex = $text.IndexOf($key)
                if ($keyIndex -lt 0) { throw 'directoryFileCount was not found in the import evidence.' }
                $colonIndex = $text.IndexOf(':', $keyIndex + $key.Length)
                if ($colonIndex -lt 0) { throw 'directoryFileCount has no value.' }
                $valueStart = -1
                for ($index = $colonIndex + 1; $index -lt $text.Length; $index++) {
                    if ([char]::IsDigit($text[$index])) { $valueStart = $index; break }
                    if ($text[$index] -ne ' ') { break }
                }
                if ($valueStart -lt 0 -or $text.Substring($valueStart, 1) -ne '9') { throw 'directoryFileCount is not the expected 9-file inventory.' }
                $text.Remove($valueStart, 1).Insert($valueStart, '1')
            }
            BlockName = 'tagTableImportLifecycle'
            ExpectedStatus = 'not_verified'
            ExpectedReason = 'fixture must restore the complete project directory, preserve the source, and match all baseline hashes.'
        },
        [ordered]@{
            Name = 'member restored readback without probe evidence'
            EvidencePath = $memberAcceptancePath
            Tamper = {
                param([string]$text)
                $anchor = $text.IndexOf('"restoredReadback"')
                if ($anchor -lt 0) { throw 'restoredReadback was not found in the member evidence.' }
                $leaf = 'mcp-import-tagtable-nonempty-restored-read-20260923.json'
                $leafIndex = $text.IndexOf($leaf, $anchor)
                if ($leafIndex -lt 0) { throw 'the member restored readback report was not found.' }
                $text.Remove($leafIndex, $leaf.Length).Insert($leafIndex, 'mcp-import-tagtable-nonempty-readback-20260923.json')
            }
            BlockName = 'tagTableMemberImportLifecycle'
            ExpectedStatus = 'not_verified'
            ExpectedReason = 'independent reports must read back both non-Safety members, then show no probe tags/table after restoring the directory.'
        },
        [ordered]@{
            Name = 'block-group readback that did not probe the group'
            EvidencePath = $blockGroupAcceptancePath
            Tamper = {
                param([string]$text)
                $anchor = $text.IndexOf('"independentReadback"')
                if ($anchor -lt 0) { throw 'independentReadback was not found in the block-group evidence.' }
                $leaf = 'mcp-blockgroup-independent-read-20260923-1700.json'
                $leafIndex = $text.IndexOf($leaf, $anchor)
                if ($leafIndex -lt 0) { throw 'the block-group independent readback report was not found.' }
                $text.Remove($leafIndex, $leaf.Length).Insert($leafIndex, 'mcp-import-tagtable-restored-read-20260923-1730.json')
            }
            BlockName = 'blockGroupLifecycle'
            ExpectedStatus = 'not_verified'
            ExpectedReason = 'independentReadback.report must be a read-only session whose probe query shows the created group is absent.'
        }
    )
    foreach ($corruptedEvidenceCase in $corruptedEvidenceCases) {
        Invoke-CorruptedEvidenceCase @corruptedEvidenceCase
    }

    Write-Output 'PASS: acceptance status distinguishes verified, incomplete and blocked work'
}
finally {
    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
    if (Test-Path -LiteralPath $negativeEvidencePath) { Remove-Item -LiteralPath $negativeEvidencePath -Force }
    if (Test-Path -LiteralPath $negativeOutputPath) { Remove-Item -LiteralPath $negativeOutputPath -Force }
    if (Test-Path -LiteralPath $portableValidationPath) { Remove-Item -LiteralPath $portableValidationPath -Force }
}
