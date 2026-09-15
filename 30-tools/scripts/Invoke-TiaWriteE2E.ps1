[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [Parameter(Mandatory = $true)]
    [string]$ProjectFile,
    [string]$SourceFile = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '90-tmp\e2e\import\FB_AgentWorkflowProbe.scl'),
    [string]$SoftwarePath = 'PLC_1',
    [string]$TargetGroupPath = '01_S7',
    [string]$BlockName = 'FB_AgentWorkflowProbe',
    [string]$ReportRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '70-runs\e2e')
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
$ProjectFile = [IO.Path]::GetFullPath($ProjectFile)
$SourceFile = [IO.Path]::GetFullPath($SourceFile)
$ReportRoot = [IO.Path]::GetFullPath($ReportRoot)

if (-not (Test-Path -LiteralPath $ProjectFile -PathType Leaf)) { throw "Project file does not exist: $ProjectFile" }
if (-not (Test-Path -LiteralPath $SourceFile -PathType Leaf)) { throw "Source file does not exist: $SourceFile" }

$projectDirectory = Split-Path -Parent $ProjectFile
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDirectory = Join-Path $ReportRoot $timestamp
$backupDirectory = Join-Path $runDirectory 'backup-project'
$exportDirectory = Join-Path $runDirectory 'export'
$stagedSourceFile = Join-Path $runDirectory ([IO.Path]::GetFileName($SourceFile))
$reportPath = Join-Path $runDirectory 'report.json'
$invoke = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-TiaMcp.ps1'
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null

$report = [ordered]@{
    schemaVersion = 1
    startedAt = [DateTimeOffset]::Now.ToString('o')
    projectFile = $ProjectFile
    softwarePath = $SoftwarePath
    targetGroupPath = $TargetGroupPath
    blockName = $BlockName
    backup = [ordered]@{ success = $false; path = $backupDirectory }
    preview = [ordered]@{ success = $false }
    import = [ordered]@{ success = $false }
    compile = [ordered]@{ success = $false; errorCount = $null; warningCount = $null }
    save = [ordered]@{ success = $false }
    export = [ordered]@{ success = $false; path = $exportDirectory }
    verification = [ordered]@{ success = $false }
    errors = @()
}

function Get-ToolResult([object[]]$Results, [string]$ToolName, [switch]$Last) {
    $matches = @($Results | Where-Object { $_.Tool -eq $ToolName })
    if ($matches.Count -eq 0) { return $null }
    if ($Last) { return $matches[-1] }
    return $matches[0]
}

function Read-ToolJson([object]$Result) {
    if ($null -eq $Result -or $Result.IsError) { return $null }
    try { return ($Result.Text | ConvertFrom-Json) } catch { return $null }
}

function Assert-Results([object[]]$Results, [string]$Stage) {
    $failed = @($Results | Where-Object { $_.IsError })
    if ($failed.Count -gt 0) {
        $first = $failed[0]
        throw "$Stage failed at $($first.Tool): $($first.Text)"
    }
}

try {
    # The backup is made before connecting in write mode. The fixture itself is disposable,
    # but the same invariant must hold for a real project.
    New-Item -ItemType Directory -Path (Split-Path -Parent $backupDirectory) -Force | Out-Null
    Copy-Item -LiteralPath $projectDirectory -Destination $backupDirectory -Recurse -Force
    $report.backup.success = $true
    # TIA may keep the live .ap20 exclusively locked while the project is open.
    # Hash the copied artifact, which is the recoverable backup we actually control.
    $backupProjectFile = Join-Path $backupDirectory ([IO.Path]::GetFileName($ProjectFile))
    $report.backup.projectHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backupProjectFile).Hash
    $report.backup.projectFile = $backupProjectFile

    # TIA's external-source importer expects UTF-8 with BOM. Normalize the
    # caller's source into the run directory so the input contract is explicit
    # and reproducible for every harness.
    $sourceText = [IO.File]::ReadAllText($SourceFile)
    [IO.File]::WriteAllText($stagedSourceFile, $sourceText, [Text.UTF8Encoding]::new($true))
    $sourceName = [IO.Path]::GetFileName($stagedSourceFile)
    $report.source = [ordered]@{
        input = $SourceFile
        staged = $stagedSourceFile
        name = $sourceName
        encoding = 'UTF-8 BOM'
    }

    $preflight = & $invoke -Calls @(
        @{ name = 'Connect' },
        @{ name = 'GetState' }
    ) -TiaMajor 20 -TimeoutSeconds 180
    Assert-Results $preflight 'Preflight'
    $stateResult = Get-ToolResult $preflight 'GetState'
    $state = Read-ToolJson $stateResult
    if ($null -eq $state) { throw 'Preflight GetState did not return JSON.' }

    $expectedProjectName = [IO.Path]::GetFileNameWithoutExtension($ProjectFile)
    $currentProjectName = [string]$state.project
    if ($currentProjectName -ne '-' -and $currentProjectName -ne $expectedProjectName) {
        throw "A different TIA project is already open ('$currentProjectName'); refusing to open '$expectedProjectName'."
    }

    $openCall = if ($currentProjectName -eq '-') {
        @{ name = 'OpenProject'; args = @{ path = $ProjectFile } }
    } else { $null }

    $mutationCalls = @(
        @{ name = 'Connect' }
    )
    if ($null -ne $openCall) { $mutationCalls += $openCall }
    $mutationCalls += @(
        @{ name = 'GetProjectTree' },
        @{ name = 'GetSoftwareTree'; args = @{ softwarePath = $SoftwarePath; sections = 'blocks,tags,types,sources' } },
        @{ name = 'GetBlocks'; args = @{ softwarePath = $SoftwarePath; regexName = $BlockName } }
    )

    $inspection = & $invoke -AllowWrite -Calls $mutationCalls -TiaMajor 20 -TimeoutSeconds 300
    Assert-Results $inspection 'Inspection'
    $existing = Read-ToolJson (Get-ToolResult $inspection 'GetBlocks' -Last)
    $existingItems = if ($null -eq $existing) { @() } else { @($existing.items) }
    if (@($existingItems | Where-Object { $_.name -ieq $BlockName }).Count -gt 0) {
        throw "Preview refused: block '$BlockName' already exists."
    }
    $report.preview = [ordered]@{
        success = $true
        blockName = $BlockName
        effect = 'create'
        targetPath = "$TargetGroupPath/$BlockName"
        existingMatches = 0
    }

    $writeResults = & $invoke -AllowWrite -Calls @(
        @{ name = 'Connect' },
        @{ name = 'CreateExternalSourceFromFile'; args = @{ softwarePath = $SoftwarePath; groupPath = ''; name = $sourceName; filePath = $stagedSourceFile } },
        @{ name = 'GenerateBlocksFromSource'; args = @{ softwarePath = $SoftwarePath; sourcePath = $sourceName; targetGroupPath = $TargetGroupPath; keepOnError = $false } },
        @{ name = 'GetBlocks'; args = @{ softwarePath = $SoftwarePath; regexName = $BlockName } },
        @{ name = 'CompileSoftware'; args = @{ softwarePath = $SoftwarePath; password = '' } }
    ) -TiaMajor 20 -TimeoutSeconds 300
    Assert-Results $writeResults 'Write/import'
    $report.import = [ordered]@{
        success = $true
        sourceFile = $stagedSourceFile
        sourceName = $sourceName
        blockPath = "$TargetGroupPath/$BlockName"
        generated = (Read-ToolJson (Get-ToolResult $writeResults 'GenerateBlocksFromSource'))
    }

    $compile = Read-ToolJson (Get-ToolResult $writeResults 'CompileSoftware')
    if ($null -eq $compile) { throw 'CompileSoftware did not return JSON.' }
    $report.compile = [ordered]@{
        success = ($compile.errorCount -eq 0)
        state = $compile.state
        errorCount = [int]$compile.errorCount
        warningCount = [int]$compile.warningCount
        messages = @($compile.messages)
    }
    if ([int]$compile.errorCount -ne 0 -or [int]$compile.warningCount -ne 0) {
        throw "Compile gate failed: $($compile.errorCount) error(s), $($compile.warningCount) warning(s). Save was not attempted."
    }

    $persist = & $invoke -AllowWrite -Calls @(
        @{ name = 'Connect' },
        @{ name = 'SaveProject' },
        @{ name = 'ExportPlcAsSourceTree'; args = @{ softwarePath = $SoftwarePath; exportPath = $exportDirectory } },
        @{ name = 'GetBlockSource'; args = @{ softwarePath = $SoftwarePath; blockPath = "$TargetGroupPath/$BlockName"; format = 'document'; maxChars = 20000 } }
    ) -TiaMajor 20 -TimeoutSeconds 300
    Assert-Results $persist 'Persist/export'
    $save = Read-ToolJson (Get-ToolResult $persist 'SaveProject')
    $export = Read-ToolJson (Get-ToolResult $persist 'ExportPlcAsSourceTree')
    $source = Read-ToolJson (Get-ToolResult $persist 'GetBlockSource')
    $report.save = [ordered]@{ success = $true; response = $save }
    $report.export = [ordered]@{ success = $true; path = $exportDirectory; response = $export }
    $report.verification = [ordered]@{
        success = ($null -ne $source)
        blockPath = "$TargetGroupPath/$BlockName"
        source = $source
    }
    if ($null -eq $source) { throw 'Saved block could not be read back with GetBlockSource.' }
}
catch {
    $report.errors = @($report.errors + $_.Exception.Message)
    throw
}
finally {
    $report.completedAt = [DateTimeOffset]::Now.ToString('o')
    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "E2E report written to $reportPath"
}
