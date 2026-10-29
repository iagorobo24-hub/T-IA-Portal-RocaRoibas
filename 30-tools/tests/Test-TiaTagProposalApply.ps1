[CmdletBinding()]
param()

# Prueba de Invoke-TiaTagProposalApply.ps1 con un servidor MCP simulado.
# Verifica el contrato de ADR-019: fixture, inventario completo, tabla/tag exactos, backup,
# mutacion unica, readback, compile 0/0, guardado, export y verificacion post-guardado.
# No ejecuta TIA Portal ni muta nada real: el mock solo devuelve JSON y escribe XML de prueba.

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Invoke-TiaTagProposalApply.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-tag-apply-test-' + [guid]::NewGuid().ToString('N'))
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }
$script:assertions = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERT FAILED: $Message" }
    $script:assertions++
}

function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ([string]$Expected -ne [string]$Actual) {
        throw "ASSERT FAILED: $Message (expected '$Expected', got '$Actual')"
    }
    $script:assertions++
}

function Get-TiaDirectoryFingerprint([string]$Directory) {
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

function Get-PowerShellScriptArguments([string]$Path) {
    $command = "& '" + $Path.Replace("'", "''") + "'"
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    return " -NoProfile -NonInteractive -EncodedCommand $encodedCommand"
}

function Read-LatestReport([string]$ReportRoot) {
    $reports = @(Get-ChildItem -LiteralPath ([IO.Path]::GetFullPath($ReportRoot)) -Recurse -File -Filter 'tag-apply-report.json' -ErrorAction SilentlyContinue)
    if ($reports.Count -eq 0) { throw "No tag-apply-report.json was produced under $ReportRoot." }
    $sorted = @($reports | Sort-Object FullName)
    return (Get-Content -Raw -LiteralPath $sorted[$sorted.Count - 1].FullName | ConvertFrom-Json)
}

function Test-OrderContains([array]$Order, [string[]]$Expected) {
    for ($i = 0; $i -le ($Order.Count - $Expected.Count); $i++) {
        $match = $true
        for ($j = 0; $j -lt $Expected.Count; $j++) {
            if ([string]$Order[$i + $j] -ne $Expected[$j]) { $match = $false; break }
        }
        if ($match) { return $true }
    }
    return $false
}

function Get-InitialTags {
    return @(
        [ordered]@{
            path = 'Signals/Cmd_Enable'; name = 'Cmd_Enable'; tableName = 'Signals'
            dataTypeName = 'Bool'; logicalAddress = '%M0.0'; isSafety = $false
        }
    )
}

function Write-MockState([string]$Path, [object[]]$Tags, [bool]$Saved) {
    [ordered]@{ tags = @($Tags); saved = $Saved } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-ProposalObject {
    param(
        [string]$Operation,
        [string]$TagName,
        [object]$Before,
        [object]$After,
        [string]$Table = 'Signals'
    )
    return [ordered]@{
        schemaVersion = 1
        status = 'PROPOSED'
        readOnly = $true
        applied = $false
        tiaMutation = $false
        projectPath = $script:projectFile
        plc = 'PLC_1'
        tagTable = [ordered]@{ path = $Table; name = $Table }
        operation = $Operation
        target = [ordered]@{ path = ($Table + '/' + $TagName); name = $TagName; before = $Before }
        after = $After
        checks = [ordered]@{ exactTable = $true; exactTag = $true; noBlockingFindings = $true }
        findings = @()
    }
}

function Reset-Fixture {
    $content = [Text.Encoding]::UTF8.GetBytes('fixture-project-v1')
    [IO.File]::WriteAllBytes($script:fixtureProject, $content)
    [IO.File]::WriteAllBytes($script:fixtureBackup, $content)
    $hash = Get-TiaDirectoryFingerprint (Split-Path -Parent $script:fixtureProject)
    [ordered]@{
        schemaVersion = 1
        disposable = $true
        projectPath = $script:fixtureProject
        backupProjectPath = $script:fixtureBackup
        sourceProjectPath = $script:sourceProject
        projectSnapshotSha256 = $hash
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:manifestPath -Encoding UTF8
}

function Invoke-Case {
    param(
        [string]$Name,
        [object]$Proposal,
        [string]$Mode = 'happy',
        [switch]$TamperFixture
    )
    Reset-Fixture
    if ($TamperFixture) {
        [IO.File]::AppendAllText($script:fixtureProject, 'tampered', (New-Object Text.UTF8Encoding($false)))
    }
    $reportRoot = Join-Path $temp ($Name + '-reports')
    $statePath = Join-Path $temp ($Name + '-state.json')
    $orderPath = Join-Path $temp ($Name + '-order.txt')
    Write-MockState -Path $statePath -Tags (Get-InitialTags) -Saved $false
    if (Test-Path -LiteralPath $orderPath) { Remove-Item -LiteralPath $orderPath -Force }
    $proposalPath = Join-Path $temp ($Name + '-proposal.json')
    $Proposal | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $proposalPath -Encoding UTF8
    $env:TIA_TAG_MODE = $Mode
    $env:TIA_TAG_STATE = $statePath
    $env:TIA_TAG_ORDER = $orderPath
    $failed = $false
    try {
        & $script -ProposalPath $proposalPath -ProjectFile $script:projectFile -FixtureRoot $script:fixtureRoot `
            -ReportRoot $reportRoot -Profile write -AcknowledgeWriteProfile -Apply `
            -McpExecutablePath $script:pwsh -McpArguments $script:mockArguments 2>&1 | Out-Null
    }
    catch { $failed = $true }
    $global:LASTEXITCODE = 0
    $report = Read-LatestReport $reportRoot
    $order = if (Test-Path -LiteralPath $orderPath) { @(Get-Content -LiteralPath $orderPath) } else { @() }
    return [pscustomobject]@{ name = $Name; failed = $failed; report = $report; order = $order; statePath = $statePath }
}

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $script:fixtureRoot = Join-Path $temp 'fixture'
    $script:fixtureProject = Join-Path $script:fixtureRoot 'project\Target_V20.ap20'
    $script:fixtureBackup = Join-Path $script:fixtureRoot 'backup\Target_V20.ap20'
    $script:sourceProject = Join-Path $temp 'source\Source_V20.ap20'
    $script:manifestPath = Join-Path $script:fixtureRoot '.tia-agent-fixture.json'
    $script:projectFile = $script:fixtureProject
    New-Item -ItemType Directory -Path (Split-Path -Parent $script:fixtureProject) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $script:fixtureBackup) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $script:sourceProject) -Force | Out-Null
    [IO.File]::WriteAllText($script:sourceProject, 'source-project', (New-Object Text.UTF8Encoding($false)))
    Reset-Fixture

    # --- Servidor MCP simulado ---------------------------------------------------
    $mockServer = Join-Path $temp 'mock-tia-tags.ps1'
    @'
$ErrorActionPreference = 'Stop'
$mode = if ($env:TIA_TAG_MODE) { $env:TIA_TAG_MODE } else { 'happy' }
$statePath = $env:TIA_TAG_STATE
$orderPath = $env:TIA_TAG_ORDER
$openedProjectName = $null
$openedProjectPath = $null
$mutated = $false

function Read-State {
    if (-not $statePath -or -not (Test-Path -LiteralPath $statePath)) {
        return [pscustomobject]@{ tags = @(); saved = $false }
    }
    $state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
    $state.tags = @($state.tags)
    return $state
}

function Write-State([object]$State) {
    [ordered]@{ tags = @($State.tags); saved = [bool]$State.saved } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $statePath -Encoding UTF8
}

function New-TextResult([object]$Payload) {
    return [ordered]@{ content = @(@{ type = 'text'; text = ($Payload | ConvertTo-Json -Depth 20 -Compress) }) }
}

function New-ErrorResult([string]$Message) {
    return [ordered]@{ isError = $true; content = @(@{ type = 'text'; text = $Message }) }
}

function Find-Tag([object]$State, [string]$Path) {
    return @($State.tags | Where-Object { [string]$_.path -ceq $Path }) | Select-Object -First 1
}

while ($line = [Console]::In.ReadLine()) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $request = $line | ConvertFrom-Json
    if ($request.method -eq 'notifications/initialized') { continue }
    if ($request.method -eq 'initialize') {
        $result = [ordered]@{ protocolVersion = '2025-06-18'; capabilities = @{}; serverInfo = @{ name = 'tia-claude-tag-fixture'; version = '1.0' } }
    }
    elseif ($request.method -eq 'tools/list') {
        $tools = @('Doctor', 'Connect', 'Disconnect', 'OpenProject', 'GetState', 'GetTags', 'GetTagTables',
            'GetTagTableInfo', 'GetTagInfo', 'ExportTagTable', 'CreateTag', 'UpdateTag', 'DeleteTag',
            'CompileSoftware', 'SaveProject')
        if ($mode -eq 'missing-tool') { $tools = @($tools | Where-Object { $_ -ne 'UpdateTag' }) }
        $result = [ordered]@{ tools = @($tools | ForEach-Object { @{ name = $_ } }) }
    }
    elseif ($request.method -eq 'tools/call') {
        $name = [string]$request.params.name
        $callArgs = $request.params.arguments
        if ($orderPath) { Add-Content -LiteralPath $orderPath -Value $name -Encoding ASCII }
        $state = Read-State
        switch ($name) {
            'Doctor' { $result = New-TextResult ([ordered]@{ report = 'mock doctor'; meta = @{ success = $true } }) }
            'Connect' { $result = New-TextResult ([ordered]@{ message = 'Connected to TIA-Portal'; meta = @{ success = $true } }) }
            'Disconnect' { $result = New-TextResult ([ordered]@{ message = 'Disconnected from TIA-Portal'; meta = @{ success = $true } }) }
            'OpenProject' {
                $openedProjectPath = [string]$callArgs.path
                $openedProjectName = [IO.Path]::GetFileNameWithoutExtension($openedProjectPath)
                $result = New-TextResult ([ordered]@{ message = "Project '$openedProjectPath' opened"; meta = @{ success = $true } })
            }
            'GetState' {
                $result = New-TextResult ([ordered]@{ isConnected = $true; project = $openedProjectName; session = '-'; allowWrite = $true; meta = @{ success = $true } })
            }
            'GetTags' {
                $tags = @($state.tags)
                if ($mode -eq 'tag-safety') { foreach ($t in $tags) { $t.isSafety = $true } }
                if ($mode -eq 'tag-unclassified') { foreach ($t in $tags) { $t.PSObject.Properties.Remove('isSafety') } }
                $tablePath = [string]$callArgs.tagTablePath
                if ($tablePath) {
                    $leaf = $tablePath.Split('/')[-1]
                    $tags = @($tags | Where-Object { [string]$_.tableName -ceq $leaf })
                }
                $regex = [string]$callArgs.regexName
                if ($regex) { $tags = @($tags | Where-Object { [string]$_.name -match $regex }) }
                $total = $tags.Count
                if ($mode -eq 'tag-count-mismatch') { $total = 99 }
                $items = @($tags | ForEach-Object {
                    $item = [ordered]@{
                        path = $_.path; name = $_.name; tableName = $_.tableName
                        dataTypeName = $_.dataTypeName; logicalAddress = $_.logicalAddress
                        comment = ''; externalAccessible = $true; externalVisible = $true; externalWritable = $true
                    }
                    if ($_.PSObject.Properties.Name -contains 'isSafety') { $item['isSafety'] = [bool]$_.isSafety }
                    $item
                })
                $result = New-TextResult ([ordered]@{ items = $items; message = "$total tag(s) retrieved"; meta = [ordered]@{ success = $true; totalTags = $total } })
            }
            'GetTagTables' {
                $tableCount = 1
                $items = @([ordered]@{ path = 'Signals'; name = 'Signals'; isDefault = $false; tagCount = @($state.tags).Count })
                if ($mode -eq 'table-enumeration-empty') { $items = @(); $tableCount = 0 }
                $result = New-TextResult ([ordered]@{ items = $items; message = "$tableCount tag table(s) retrieved"; meta = [ordered]@{ success = $true; totalTagTables = $tableCount } })
            }
            'GetTagTableInfo' {
                if ($mode -eq 'table-missing') {
                    $result = New-ErrorResult "Tag table not found at 'Signals' in 'PLC_1'. Use 'GetTagTables' to list the available tables."
                }
                else {
                    $result = New-TextResult ([ordered]@{ path = 'Signals'; name = 'Signals'; isDefault = $false; tagCount = @($state.tags).Count; attributes = @(); message = 'info'; meta = @{ success = $true } })
                }
            }
            'GetTagInfo' {
                $tagPath = [string]$callArgs.tagPath
                if ($mode -eq 'unexpected-probe-error') {
                    $result = New-ErrorResult "Database locked while reading '$tagPath'."
                    break
                }
                $tag = Find-Tag $state $tagPath
                if (-not $tag) {
                    $result = New-ErrorResult "Tag not found at '$tagPath' in 'PLC_1'. Use 'GetTags' to list the available tags."
                }
                else {
                    $address = [string]$tag.logicalAddress
                    if ($mode -eq 'before-mismatch') { $address = '%M9.9' }
                    if ($mode -eq 'readback-mismatch' -and $mutated) { $address = '%M8.8' }
                    if ($mode -eq 'verify-mismatch' -and $state.saved -eq $true) { $address = '%M7.7' }
                    $result = New-TextResult ([ordered]@{
                        path = $tag.path; name = $tag.name; tableName = $tag.tableName
                        dataTypeName = $tag.dataTypeName; logicalAddress = $address
                        comment = ''; externalAccessible = $true; externalVisible = $true; externalWritable = $true
                        isSafety = [bool]$tag.isSafety; message = 'Tag info retrieved'; meta = @{ success = $true }
                    })
                }
            }
            'ExportTagTable' {
                if ($mode -eq 'export-fail' -and $state.saved -eq $true) {
                    $result = New-ErrorResult 'Export failed.'
                }
                else {
                    $exportPath = [string]$callArgs.exportPath
                    New-Item -ItemType Directory -Path $exportPath -Force | Out-Null
                    $xmlPath = Join-Path $exportPath 'Signals.xml'
                    $tagsXml = (@($state.tags) | ForEach-Object { "<Tag Name=""$($_.name)"" Address=""$($_.logicalAddress)"" />" }) -join "`n"
                    [IO.File]::WriteAllText($xmlPath, "<TagTable Name=""Signals"">`n$tagsXml`n</TagTable>", (New-Object Text.UTF8Encoding($false)))
                    $result = New-TextResult ([ordered]@{ name = 'Signals'; path = 'Signals'; message = "Tag table exported to '$exportPath'"; meta = @{ success = $true } })
                }
            }
            'CompileSoftware' {
                $errorCount = 0
                $warningCount = 0
                $messages = @()
                if ($mode -eq 'compile-error' -and $mutated) { $errorCount = 1 }
                if ($mode -eq 'baseline-error') { $errorCount = 1 }
                if ($mode -eq 'baseline-warning') {
                    $warningCount = 1
                    $messages = @([ordered]@{ state = 'Warning'; description = 'Pre-existing hardware warning.' })
                }
                if ($mode -eq 'new-warning' -and $mutated) {
                    $warningCount = 1
                    $messages = @([ordered]@{ state = 'Warning'; description = 'Warning introduced by the change.' })
                }
                $stateText = if ($errorCount -eq 0) { 'Success' } else { 'Error' }
                $result = New-TextResult ([ordered]@{ state = $stateText; errorCount = $errorCount; warningCount = $warningCount; messages = $messages; meta = @{ success = $true } })
            }
            'SaveProject' {
                if ($mode -eq 'save-fail') {
                    $result = New-ErrorResult 'Save failed.'
                }
                else {
                    $state.saved = $true
                    Write-State $state
                    if ($openedProjectPath -and (Test-Path -LiteralPath $openedProjectPath)) {
                        [IO.File]::AppendAllText($openedProjectPath, "`n# saved", (New-Object Text.UTF8Encoding($false)))
                    }
                    $result = New-TextResult ([ordered]@{ message = 'Local project saved'; meta = @{ success = $true; pendingSave = $true } })
                }
            }
            'CreateTag' {
                if ($mode -eq 'mutation-fail') {
                    $result = New-ErrorResult 'CreateTag failed.'
                }
                else {
                    $tablePath = [string]$callArgs.tagTablePath
                    $tagName = [string]$callArgs.name
                    $newPath = $tablePath + '/' + $tagName
                    if (Find-Tag $state $newPath) {
                        $result = New-ErrorResult "Tag '$newPath' already exists."
                    }
                    else {
                        $state.tags = @($state.tags) + [pscustomobject]@{
                            path = $newPath; name = $tagName; tableName = $tablePath.Split('/')[-1]
                            dataTypeName = [string]$callArgs.dataTypeName; logicalAddress = [string]$callArgs.logicalAddress
                            isSafety = $false
                        }
                        Write-State $state
                        $mutated = $true
                        $result = New-TextResult ([ordered]@{ kind = 'Tag'; name = $tagName; path = $newPath; message = 'Tag created'; meta = @{ success = $true; pendingSave = $true } })
                    }
                }
            }
            'UpdateTag' {
                if ($mode -eq 'mutation-fail') {
                    $result = New-ErrorResult 'UpdateTag failed.'
                }
                else {
                    $tagPath = [string]$callArgs.tagPath
                    $tag = Find-Tag $state $tagPath
                    if (-not $tag) {
                        $result = New-ErrorResult "Tag not found at '$tagPath'."
                    }
                    else {
                        foreach ($field in @('newName', 'dataTypeName', 'logicalAddress', 'externalAccessible', 'externalVisible', 'externalWritable')) {
                            if ($callArgs.PSObject.Properties.Name -contains $field -and $null -ne $callArgs.$field) {
                                if ($field -eq 'newName') {
                                    $tag.name = [string]$callArgs.newName
                                    $tag.path = $tagPath.Substring(0, $tagPath.LastIndexOf('/') + 1) + $tag.name
                                }
                                else {
                                    $tag.$field = $callArgs.$field
                                }
                            }
                        }
                        Write-State $state
                        $mutated = $true
                        $result = New-TextResult ([ordered]@{ kind = 'Tag'; oldPath = $tagPath; newName = $callArgs.newName; newPath = $tag.path; message = 'Tag updated'; meta = @{ success = $true; pendingSave = $true } })
                    }
                }
            }
            'DeleteTag' {
                if ($mode -eq 'mutation-fail') {
                    $result = New-ErrorResult 'DeleteTag failed.'
                }
                else {
                    $tagPath = [string]$callArgs.tagPath
                    $beforeCount = @($state.tags).Count
                    $state.tags = @($state.tags | Where-Object { [string]$_.path -cne $tagPath })
                    if (@($state.tags).Count -eq $beforeCount) {
                        $result = New-ErrorResult "Tag not found at '$tagPath'."
                    }
                    else {
                        Write-State $state
                        $mutated = $true
                        $result = New-TextResult ([ordered]@{ kind = 'Tag'; path = $tagPath; message = 'Tag deleted'; meta = @{ success = $true; pendingSave = $true } })
                    }
                }
            }
            default { $result = New-TextResult ([ordered]@{ success = $true; message = $name }) }
        }
    }
    else { $result = [ordered]@{} }
    [ordered]@{ jsonrpc = '2.0'; id = $request.id; result = $result } | ConvertTo-Json -Depth 30 -Compress | Write-Output
}
'@ | Set-Content -LiteralPath $mockServer -Encoding UTF8
    $script:mockArguments = Get-PowerShellScriptArguments $mockServer

    $createProposal = New-ProposalObject -Operation 'create' -TagName 'Status_Active' -Before $null -After ([ordered]@{ dataTypeName = 'Bool'; logicalAddress = '%M0.1' })
    $updateProposal = New-ProposalObject -Operation 'update' -TagName 'Cmd_Enable' -Before ([ordered]@{ dataTypeName = 'Bool'; logicalAddress = '%M0.0' }) -After ([ordered]@{ logicalAddress = '%M0.1' })
    $deleteProposal = New-ProposalObject -Operation 'delete' -TagName 'Cmd_Enable' -Before ([ordered]@{ dataTypeName = 'Bool'; logicalAddress = '%M0.0' }) -After $null
    $noopProposal = New-ProposalObject -Operation 'update' -TagName 'Cmd_Enable' -Before ([ordered]@{ dataTypeName = 'Bool'; logicalAddress = '%M0.0' }) -After ([ordered]@{ logicalAddress = '%M0.0' })

    # --- Caso 0: preview local, sin TIA ------------------------------------------
    $previewRoot = Join-Path $temp 'preview-reports'
    $previewProposalPath = Join-Path $temp 'preview-proposal.json'
    $updateProposal | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $previewProposalPath -Encoding UTF8
    & $script -ProposalPath $previewProposalPath -ProjectFile $script:projectFile -ReportRoot $previewRoot | Out-Null
    $previewReport = Read-LatestReport $previewRoot
    Assert-Equal 'PREVIEW' $previewReport.status 'preview status'
    Assert-Equal 'False' $previewReport.applied 'preview must not apply'
    Assert-Equal 'False' $previewReport.tiaMutation 'preview must not mutate'
    Assert-Equal 'True' $previewReport.readOnly 'preview must be read-only'
    Assert-Equal '0' @($previewReport.errors).Count 'preview must not record errors'

    # --- Caso 1: create aplicado y verificado -----------------------------------
    $case = Invoke-Case -Name 'create-happy' -Proposal $createProposal
    Assert-Equal 'False' $case.failed 'create-happy must not throw'
    Assert-Equal 'APPLIED_AND_VERIFIED' $case.report.status 'create-happy status'
    Assert-Equal 'True' $case.report.applied 'create-happy applied'
    Assert-Equal 'True' $case.report.tiaMutation 'create-happy mutation'
    Assert-Equal 'True' $case.report.save.success 'create-happy save'
    Assert-Equal 'True' $case.report.export.success 'create-happy export'
    Assert-Equal 'True' $case.report.verification.success 'create-happy post-save verification'
    Assert-True (Test-OrderContains $case.order @('Connect', 'OpenProject', 'CompileSoftware', 'CreateTag', 'GetTagInfo', 'CompileSoftware', 'SaveProject', 'ExportTagTable')) 'create-happy mutation order'
    Assert-True (-not ($case.order -contains 'ImportPlcTagTable')) 'create-happy must never use ImportPlcTagTable'
    Assert-True (Test-Path -LiteralPath $case.report.backupExport.path) 'create-happy backup XML exists'
    Assert-True (Test-Path -LiteralPath $case.report.export.path) 'create-happy src XML exists'

    # --- Caso 2: update aplicado y verificado -----------------------------------
    $case = Invoke-Case -Name 'update-happy' -Proposal $updateProposal
    Assert-Equal 'False' $case.failed 'update-happy must not throw'
    Assert-Equal 'APPLIED_AND_VERIFIED' $case.report.status 'update-happy status'
    Assert-True (Test-OrderContains $case.order @('Connect', 'OpenProject', 'CompileSoftware', 'UpdateTag', 'GetTagInfo', 'CompileSoftware', 'SaveProject', 'ExportTagTable')) 'update-happy mutation order'
    Assert-Equal 'True' $case.report.readback.success 'update-happy readback'

    # --- Caso 3: delete aplicado y verificado -----------------------------------
    $case = Invoke-Case -Name 'delete-happy' -Proposal $deleteProposal
    Assert-Equal 'False' $case.failed 'delete-happy must not throw'
    Assert-Equal 'APPLIED_AND_VERIFIED' $case.report.status 'delete-happy status'
    Assert-True (Test-OrderContains $case.order @('Connect', 'OpenProject', 'CompileSoftware', 'DeleteTag', 'GetTags', 'CompileSoftware', 'SaveProject', 'ExportTagTable')) 'delete-happy mutation order'
    Assert-Equal 'absence' $case.report.verification.mode 'delete-happy verification mode'
    Assert-Equal '0' $case.report.verification.totalTags 'delete-happy post-save absence'

    # --- Caso 4: inventario con tag Safety -> BLOCKED ---------------------------
    $case = Invoke-Case -Name 'tag-safety' -Proposal $updateProposal -Mode 'tag-safety'
    Assert-Equal 'True' $case.failed 'tag-safety must throw'
    Assert-Equal 'BLOCKED' $case.report.status 'tag-safety status'
    Assert-Equal 'False' $case.report.tiaMutation 'tag-safety must not mutate'
    Assert-True (-not ($case.order -contains 'UpdateTag')) 'tag-safety must not reach the mutation'

    # --- Caso 5: tag sin clasificacion Safety -> BLOCKED ------------------------
    $case = Invoke-Case -Name 'tag-unclassified' -Proposal $updateProposal -Mode 'tag-unclassified'
    Assert-Equal 'BLOCKED' $case.report.status 'tag-unclassified status'
    Assert-Equal 'False' $case.report.tiaMutation 'tag-unclassified must not mutate'

    # --- Caso 6: recuento de inventario incoherente -> BLOCKED ------------------
    $case = Invoke-Case -Name 'tag-count-mismatch' -Proposal $updateProposal -Mode 'tag-count-mismatch'
    Assert-Equal 'BLOCKED' $case.report.status 'tag-count-mismatch status'
    Assert-Equal 'False' $case.report.tiaMutation 'tag-count-mismatch must not mutate'

    # --- Caso 7: tabla inexistente -> BLOCKED -----------------------------------
    $case = Invoke-Case -Name 'table-missing' -Proposal $updateProposal -Mode 'table-missing'
    Assert-Equal 'BLOCKED' $case.report.status 'table-missing status'
    Assert-Equal 'False' $case.report.tiaMutation 'table-missing must not mutate'

    # --- Caso 8: GetTagTables vacio pero GetTagTableInfo exacto -> APPLIED ------
    $case = Invoke-Case -Name 'table-enumeration-empty' -Proposal $updateProposal -Mode 'table-enumeration-empty'
    Assert-Equal 'APPLIED_AND_VERIFIED' $case.report.status 'table-enumeration-empty status'
    Assert-Equal 'False' $case.report.table.listedInGetTagTables 'table-enumeration-empty records the anomaly'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$case.report.table.note)) 'table-enumeration-empty note'

    # --- Caso 9: before no coincide -> BLOCKED ----------------------------------
    $case = Invoke-Case -Name 'before-mismatch' -Proposal $updateProposal -Mode 'before-mismatch'
    Assert-Equal 'BLOCKED' $case.report.status 'before-mismatch status'
    Assert-True (-not ($case.order -contains 'UpdateTag')) 'before-mismatch must not mutate'

    # --- Caso 10: create sobre tag existente -> BLOCKED -------------------------
    $existingCreate = New-ProposalObject -Operation 'create' -TagName 'Cmd_Enable' -Before $null -After ([ordered]@{ dataTypeName = 'Bool'; logicalAddress = '%M0.2' })
    $case = Invoke-Case -Name 'create-exists' -Proposal $existingCreate
    Assert-Equal 'BLOCKED' $case.report.status 'create-exists status'
    Assert-True (-not ($case.order -contains 'CreateTag')) 'create-exists must not mutate'

    # --- Caso 11: falta una herramienta del roster -> BLOCKED -------------------
    $case = Invoke-Case -Name 'missing-tool' -Proposal $updateProposal -Mode 'missing-tool'
    Assert-Equal 'BLOCKED' $case.report.status 'missing-tool status'
    Assert-Equal 'False' $case.report.tiaMutation 'missing-tool must not mutate'

    # --- Caso 12: fallo inesperado del probe de ausencia -> BLOCKED -------------
    $case = Invoke-Case -Name 'unexpected-probe-error' -Proposal $createProposal -Mode 'unexpected-probe-error'
    Assert-Equal 'BLOCKED' $case.report.status 'unexpected-probe-error status'
    Assert-True (-not ($case.order -contains 'CreateTag')) 'unexpected-probe-error must not mutate'

    # --- Caso 13: readback distinto -> APPLIED_CONTENT_MISMATCH sin guardar -----
    $case = Invoke-Case -Name 'readback-mismatch' -Proposal $updateProposal -Mode 'readback-mismatch'
    Assert-Equal 'True' $case.failed 'readback-mismatch must throw'
    Assert-Equal 'APPLIED_CONTENT_MISMATCH' $case.report.status 'readback-mismatch status'
    Assert-Equal 'True' $case.report.tiaMutation 'readback-mismatch mutated in memory'
    Assert-Equal 'False' $case.report.save.attempted 'readback-mismatch must not save'

    # --- Caso 14: compile roto -> FAILED sin guardar ----------------------------
    $case = Invoke-Case -Name 'compile-error' -Proposal $updateProposal -Mode 'compile-error'
    Assert-Equal 'FAILED' $case.report.status 'compile-error status'
    Assert-Equal 'True' $case.report.compile.attempted 'compile-error attempted'
    Assert-Equal 'False' $case.report.compile.success 'compile-error failed'
    Assert-Equal 'False' $case.report.save.attempted 'compile-error must not save'
    # --- Caso 14b: error en la compilacion base -> BLOCKED sin mutar -----------
    $case = Invoke-Case -Name 'baseline-error' -Proposal $updateProposal -Mode 'baseline-error'
    Assert-Equal 'BLOCKED' $case.report.status 'baseline-error status'
    Assert-Equal 'False' $case.report.tiaMutation 'baseline-error must not mutate'
    Assert-Equal 'False' $case.report.baselineCompile.success 'baseline-error compile blocked'

    # --- Caso 14c: warning preexistente identico -> APPLIED --------------------
    $case = Invoke-Case -Name 'baseline-warning' -Proposal $updateProposal -Mode 'baseline-warning'
    Assert-Equal 'APPLIED_AND_VERIFIED' $case.report.status 'baseline-warning status'
    Assert-Equal '1' $case.report.compile.baselineWarningCount 'baseline-warning baseline count'
    Assert-Equal '0' @($case.report.compile.newDiagnostics).Count 'baseline-warning has no new diagnostics'

    # --- Caso 14d: warning nuevo tras el cambio -> FAILED sin guardar ----------
    $case = Invoke-Case -Name 'new-warning' -Proposal $updateProposal -Mode 'new-warning'
    Assert-Equal 'FAILED' $case.report.status 'new-warning status'
    Assert-Equal 'False' $case.report.compile.success 'new-warning compile gate failed'
    Assert-Equal '1' @($case.report.compile.newDiagnostics).Count 'new-warning records the new diagnostic'
    Assert-Equal 'False' $case.report.save.attempted 'new-warning must not save'

    # --- Caso 15: fallo al guardar -> FAILED ------------------------------------
    $case = Invoke-Case -Name 'save-fail' -Proposal $updateProposal -Mode 'save-fail'
    Assert-Equal 'FAILED' $case.report.status 'save-fail status'
    Assert-Equal 'True' $case.report.mutation.success 'save-fail mutation succeeded'
    Assert-Equal 'False' $case.report.save.success 'save-fail save failed'

    # --- Caso 16: fallo del export posterior -> APPLIED_EXPORT_FAILED -----------
    $case = Invoke-Case -Name 'export-fail' -Proposal $updateProposal -Mode 'export-fail'
    Assert-Equal 'APPLIED_EXPORT_FAILED' $case.report.status 'export-fail status'
    Assert-Equal 'True' $case.report.save.success 'export-fail save succeeded'
    Assert-Equal 'False' $case.report.export.success 'export-fail export failed'

    # --- Caso 17: verificacion post-guardado distinta -> APPLIED_VERIFICATION_FAILED
    $case = Invoke-Case -Name 'verify-mismatch' -Proposal $updateProposal -Mode 'verify-mismatch'
    Assert-Equal 'APPLIED_VERIFICATION_FAILED' $case.report.status 'verify-mismatch status'
    Assert-Equal 'True' $case.report.save.success 'verify-mismatch save succeeded'
    Assert-Equal 'False' $case.report.verification.success 'verify-mismatch verification failed'

    # --- Caso 18: update sin cambio -> BLOCKED (validacion local) ---------------
    $case = Invoke-Case -Name 'noop-update' -Proposal $noopProposal
    Assert-Equal 'BLOCKED' $case.report.status 'noop-update status'
    Assert-Equal '0' @($case.order).Count 'noop-update must not open TIA'

    # --- Caso 19: fixture manipulado -> BLOCKED --------------------------------
    $case = Invoke-Case -Name 'fixture-tampered' -Proposal $updateProposal -TamperFixture
    Assert-Equal 'BLOCKED' $case.report.status 'fixture-tampered status'
    Assert-Equal 'False' $case.report.tiaMutation 'fixture-tampered must not mutate'

    Write-Output "PASS: $script:assertions assertions"
}
catch {
    Write-Output "FAIL: $($_.Exception.Message)"
    exit 1
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
