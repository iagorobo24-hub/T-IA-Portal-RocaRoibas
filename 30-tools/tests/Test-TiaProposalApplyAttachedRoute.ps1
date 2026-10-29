[CmdletBinding()]
param()

# Prueba de la -Route attached de Invoke-TiaSclProposalApply.ps1 con un servidor MCP simulado.
# Verifica el orden de la mutacion, los gates F/Safety y el comportamiento fail-closed.
# No ejecuta TIA Portal ni muta nada real: el mock solo devuelve respuestas JSON.

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Invoke-TiaSclProposalApply.ps1'
. (Join-Path $root '30-tools\scripts\TiaSclSafety.ps1')
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-apply-attached-test-' + [guid]::NewGuid().ToString('N'))
$projectFile = Join-Path $temp 'Target_V20.ap20'
$mockProjectName = 'Mock Project'
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell -ErrorAction Stop).Source }

# Cada caso: modo de bloqueo del mock y asercion de informe BLOCKED sin mutacion.
$blockedCases = @(
    [pscustomobject]@{ name = 'block-duplicate';       mode = 'block-duplicate' },
    [pscustomobject]@{ name = 'block-failsafe';        mode = 'f-block' },
    [pscustomobject]@{ name = 'block-knowhow';         mode = 'knowhow' },
    [pscustomobject]@{ name = 'block-inconsistent';    mode = 'inconsistent' },
    [pscustomobject]@{ name = 'block-language';        mode = 'language' },
    [pscustomobject]@{ name = 'tag-safety';            mode = 'tag-safety' },
    [pscustomobject]@{ name = 'tag-unclassified';      mode = 'tag-unclassified' },
    [pscustomobject]@{ name = 'tag-incomplete';        mode = 'tag-incomplete' },
    [pscustomobject]@{ name = 'tag-count-mismatch';    mode = 'tag-count-mismatch' },
    [pscustomobject]@{ name = 'blocks-meta-fail';      mode = 'blocks-meta-fail' }
)
$expectedFullOrder = @(
    'Bootstrap', 'Connect', 'AttachToOpenProject', 'GetProjectTree',
    'Connect', 'GetBlocks', 'GetTags',
    'Connect', 'GoOffline', 'ImportPlcExternalSource', 'GenerateBlocksFromExternalSource',
    'DeletePlcExternalSource', 'CompileSoftware',
    'Connect', 'GetBlocks', 'SaveProject', 'Disconnect'
)

# Puerta de delta de contenido (ADR-018): orden del readback de tia-inspect adjuntado.
$expectedReadbackOrder = @('Connect', 'GetState', 'GetBlockSource')
# Direccion y orden de los mocks:
# - mock principal (tia-create): Bootstrap..SaveProject (mutacion + persist);
# - mock de readback (tia-inspect): Connect/GetState/GetBlockSource ANTES del SaveProject del mock principal.

function Get-PowerShellScriptArguments([string]$Path) {
    $command = "& '" + $Path.Replace("'", "''") + "'"
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    return " -NoProfile -NonInteractive -EncodedCommand $encodedCommand"
}

function Read-LatestReport([string]$ReportRoot) {
    $reports = @(Get-ChildItem -LiteralPath ([IO.Path]::GetFullPath($ReportRoot)) -Recurse -File -Filter 'apply-report.json' -ErrorAction SilentlyContinue)
    if ($reports.Count -eq 0) { throw "No apply-report.json was produced under $ReportRoot." }
    return (Get-Content -Raw -LiteralPath $reports[$reports.Count - 1].FullName | ConvertFrom-Json)
}

function Invoke-ApplyCase([string]$CaseName) {
    $reportRoot = Join-Path $temp ($CaseName + '-reports')
    $failed = $false
    try {
        & $script -ProposalPath $script:attachedProposalPath -ProjectFile $projectFile -ReportRoot $reportRoot `
            -Route attached -Profile write -AcknowledgeWriteProfile -Apply -AttachProjectName $script:mockProjectName `
            -McpExecutablePath $script:pwsh -McpArguments $script:mockArguments `
            -ReadbackExecutablePath $script:pwsh -ReadbackMcpArguments $script:readbackMockArguments 2>&1 | Out-Null
    }
    catch { $failed = $true }
    if (-not $failed -and $LASTEXITCODE -eq 0) { throw "Case '$CaseName' must fail with the fixture mode applied." }
    $global:LASTEXITCODE = 0
    $report = Read-LatestReport $reportRoot
    if ($report.status -ne 'BLOCKED' -or $report.tiaMutation -ne $false -or $report.readOnly -ne $true) {
        throw "Case '$CaseName' must be BLOCKED, read-only and without TIA mutation; got status=$($report.status) mutated=$($report.tiaMutation)."
    }
    return $report
}

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    'marker: el proyecto abierto real queda fuera de las mutaciones del mock' | Set-Content -LiteralPath $projectFile -Encoding UTF8

    # --- Servidor MCP simulado ---------------------------------------------------
    $mockServer = Join-Path $temp 'mock-tia-create.ps1'
    @'
$ErrorActionPreference = 'Stop'
$orderPath = $env:TIA_ATTACH_FIXTURE_ORDER
$blockMode = $env:TIA_ATTACH_FIXTURE_BLOCK_MODE
$tagMode = $env:TIA_ATTACH_FIXTURE_TAG_MODE
$rosterMode = $env:TIA_ATTACH_FIXTURE_ROSTER
$attachMode = $env:TIA_ATTACH_FIXTURE_ATTACH
$compileMode = $env:TIA_ATTACH_FIXTURE_COMPILE
$attachName = if ($attachMode -eq 'mismatch') { 'Other Project' } else { 'Mock Project' }
$requiredTools = @('AttachToOpenProject','GetProjectTree','GetBlocks','GetTags','GoOffline','ImportPlcExternalSource','GenerateBlocksFromExternalSource','DeletePlcExternalSource','CompileSoftware','SaveProject')
function New-Block([bool]$isConsistent, [bool]$isFailsafe, [bool]$isKnowHowProtected, [string]$language) {
    [ordered]@{ typeName = 'FB'; name = 'FB_Valve'; programmingLanguage = $language; isConsistent = $isConsistent; isFailsafe = $isFailsafe; isKnowHowProtected = $isKnowHowProtected; description = 'fixture' }
}
while ($line = [Console]::In.ReadLine()) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $request = $line | ConvertFrom-Json
    if ($request.method -eq 'notifications/initialized') { continue }
    if ($request.method -eq 'initialize') {
        $result = [ordered]@{ protocolVersion = '2025-06-18'; capabilities = @{}; serverInfo = @{ name = 'tia-claude-attached-fixture'; version = '1.0' } }
    }
    elseif ($request.method -eq 'tools/list') {
        $roster = @($requiredTools + @('Bootstrap','Connect','Disconnect'))
        if ($rosterMode -eq 'missing-delete') { $roster = @($roster | Where-Object { $_ -ne 'DeletePlcExternalSource' }) }
        $result = [ordered]@{ tools = @($roster | ForEach-Object { @{ name = $_ } }) }
    }
    elseif ($request.method -eq 'tools/call') {
        $name = [string]$request.params.name
        if ($orderPath) { Add-Content -LiteralPath $orderPath -Value $name -Encoding ASCII }
        switch ($name) {
            'Bootstrap' { $payload = [ordered]@{ ready = $true; meta = @{ success = $true } } }
            'Connect' { $payload = [ordered]@{ message = 'Connected to TIA-Portal'; meta = @{ success = $true } } }
            'Disconnect' { $payload = [ordered]@{ message = 'Disconnected from TIA-Portal'; meta = @{ success = $true } } }
            'AttachToOpenProject' { $payload = [ordered]@{ message = "Attached to open project '$attachName'"; meta = @{ success = $true } } }
            'GetProjectTree' { $payload = [ordered]@{ tree = "$attachName`r`n+-- PLC_1 [PLC Program]"; message = 'Project tree retrieved'; meta = @{ success = $true } } }
            'GetBlocks' {
                $meta = [ordered]@{ success = $true }
                $items = @(New-Block $true $false $false 'SCL')
                if ($blockMode -eq 'block-duplicate') { $items = @(New-Block $true $false $false 'SCL') + @(New-Block $true $false $false 'SCL') }
                if ($blockMode -eq 'f-block') { $items = @(New-Block $true $true $false 'SCL') }
                if ($blockMode -eq 'knowhow') { $items = @(New-Block $true $false $true 'SCL') }
                if ($blockMode -eq 'inconsistent') { $items = @(New-Block $false $false $false 'SCL') }
                if ($blockMode -eq 'language') { $items = @(New-Block $true $false $false 'LAD') }
                if ($blockMode -eq 'no-match') { $items = @() }
                if ($blockMode -eq 'blocks-meta-fail') { $meta.success = $false }
                $payload = [ordered]@{ meta = $meta; items = $items; message = 'Blocks retrieved'; }
            }
            'GetTags' {
                $tag = [ordered]@{ path = 'Signals/Cmd_Enable'; name = 'Cmd_Enable'; isSafety = $false }
                $complete = $true; $count = 1; $metaSuccess = $true
                if ($tagMode -eq 'tag-safety') { $tag.isSafety = $true }
                if ($tagMode -eq 'tag-unclassified') { $tag.Remove('isSafety') }
                if ($tagMode -eq 'tag-incomplete') { $complete = $false }
                if ($tagMode -eq 'tag-count-mismatch') { $count = 99 }
                if ($tagMode -eq 'tag-success-false') { $metaSuccess = $false }
                $payload = [ordered]@{ meta = [ordered]@{ success = $metaSuccess; complete = $complete; count = $count }; items = @($tag); message = 'PLC tags retrieved' }
            }
            'GoOffline' { $payload = [ordered]@{ message = 'went offline'; meta = @{ success = $true } } }
            'ImportPlcExternalSource' { $payload = [ordered]@{ message = 'external source imported'; meta = @{ success = $true } } }
            'GenerateBlocksFromExternalSource' { $payload = [ordered]@{ message = 'blocks generated'; meta = @{ success = $true } } }
            'DeletePlcExternalSource' { $payload = [ordered]@{ message = 'external source deleted'; meta = @{ success = $true } } }
            'CompileSoftware' {
                $errorCount = 0; $warningCount = 0
                if ($compileMode -eq 'compile-error') { $errorCount = 1 }
                $payload = [ordered]@{ state = 'Success'; errorCount = $errorCount; warningCount = $warningCount; message = 'compiled'; meta = @{ success = $true } }
            }
            'SaveProject' { $payload = [ordered]@{ message = 'saved'; meta = @{ success = $true } } }
            default { $payload = [ordered]@{ success = $true; message = $name } }
        }
        $result = [ordered]@{ content = @(@{ type = 'text'; text = ($payload | ConvertTo-Json -Depth 20 -Compress) }) }
    }
    else { $result = [ordered]@{} }
    [ordered]@{ jsonrpc = '2.0'; id = $request.id; result = $result } | ConvertTo-Json -Depth 30 -Compress | Write-Output
}
'@ | Set-Content -LiteralPath $mockServer -Encoding UTF8
    $script:mockArguments = Get-PowerShellScriptArguments $mockServer

    # --- Servidor MCP simulado de READBACK (tia-inspect adjuntado, solo lectura) ---
    $readbackServer = Join-Path $temp 'mock-tia-inspect-readback.ps1'
    @'
$ErrorActionPreference = 'Stop'
$readbackOrderPath = $env:TIA_READBACK_FIXTURE_ORDER
$readbackMode = if ($env:TIA_READBACK_FIXTURE_MODE) { $env:TIA_READBACK_FIXTURE_MODE } else { 'happy' }
while ($line = [Console]::In.ReadLine()) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $request = $line | ConvertFrom-Json
    if ($request.method -eq 'notifications/initialized') { continue }
    if ($request.method -eq 'initialize') {
        $result = [ordered]@{ protocolVersion = '2025-06-18'; capabilities = @{}; serverInfo = @{ name = 'tia-claude-readback-fixture'; version = '1.0' } }
    }
    elseif ($request.method -eq 'tools/list') {
        $result = [ordered]@{ tools = @(@{ name = 'Connect' }, @{ name = 'GetState' }, @{ name = 'GetBlockSource' }) }
    }
    elseif ($request.method -eq 'tools/call') {
        $name = [string]$request.params.name
        if ($readbackOrderPath) { Add-Content -LiteralPath $readbackOrderPath -Value $name -Encoding ASCII }
        switch ($name) {
            'Connect' { $payload = [ordered]@{ message = 'Connected to TIA-Portal'; meta = @{ success = $true } } }
            'GetState' {
                $stateProject = if ($readbackMode -eq 'wrong-project') { 'Other Project' } else { 'Mock Project' }
                $payload = [ordered]@{ project = $stateProject; session = '-'; message = 'state'; meta = @{ success = $true } }
            }
            'GetBlockSource' {
                if ($readbackMode -eq 'crash') {
                    $payload = [ordered]@{ meta = @{ success = $false }; message = 'readback unavailable' }
                }
                elseif ($readbackMode -eq 'truncated') {
                    $payload = [ordered]@{ path = 'FB_Valve'; text = "FUNCTION_BLOCK ""FB_Valve"""; truncated = $true; meta = @{ success = $true } }
                }
                elseif ($readbackMode -eq 'mismatch') {
                    $payload = [ordered]@{ path = 'FB_Valve'; text = "FUNCTION_BLOCK ""FB_Valve""`r`n`r`nBEGIN`r`n   #Changed := TRUE;`r`nEND_FUNCTION_BLOCK"; truncated = $false; meta = @{ success = $true } }
                }
                else {
                    # El texto vivo debe ser EXACTAMENTE el de la propuesta: la comparacion de
                    # la puerta de delta es estricta por design.
                    # El texto vivo debe ser IDENTICO al de la propuesta, incluido el CRLF final
                    # con el que TIA devuelve la fuente (evidencia E2E 2026-10-28).
                    $payload = [ordered]@{ path = 'FB_Valve'; text = "FUNCTION_BLOCK ""FB_Valve""`r`nBEGIN`r`n   #Open := TRUE;`r`nEND_FUNCTION_BLOCK`r`n"; truncated = $false; meta = @{ success = $true } }
                }
            }
            default { $payload = [ordered]@{ success = $true; message = $name } }
        }
        $result = [ordered]@{ content = @(@{ type = 'text'; text = ($payload | ConvertTo-Json -Depth 20 -Compress) }) }
    }
    else { $result = [ordered]@{} }
    [ordered]@{ jsonrpc = '2.0'; id = $request.id; result = $result } | ConvertTo-Json -Depth 30 -Compress | Write-Output
}
'@ | Set-Content -LiteralPath $readbackServer -Encoding UTF8
    $script:readbackMockArguments = Get-PowerShellScriptArguments $readbackServer
    $env:TIA_READBACK_FIXTURE_MODE = 'happy'

    # --- Propuesta .scl de bloque top-level ---------------------------------------
    $sourcePath = Join-Path $temp 'FB_Valve.scl'
    @'
FUNCTION_BLOCK "FB_Valve"
BEGIN
   #Open := TRUE;
END_FUNCTION_BLOCK
'@ | Set-Content -LiteralPath $sourcePath -Encoding UTF8
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash.ToLowerInvariant()
    $proposalPath = Join-Path $temp 'attached-proposal.json'
    [ordered]@{
        schemaVersion = 1; status = 'PROPOSED'; readOnly = $true; applied = $false; tiaMutation = $false
        projectPath = $projectFile; sourceRoot = $temp; plc = 'PLC_1'
        block = [ordered]@{ name = 'FB_Valve'; path = 'FB_Valve'; language = 'SCL' }
        source = [ordered]@{ originalPath = $sourcePath; proposedPath = $sourcePath; proposedSha256 = $hash; originalSha256 = $hash; matchCount = 1; extension = '.scl' }
        checks = [ordered]@{ exactBlockMatch = $true; sclOnly = $true; noBlockingFindings = $true; uniqueReplacement = $true; originalUntouched = $true }
        findings = @()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $proposalPath -Encoding UTF8
    $script:attachedProposalPath = $proposalPath

    # 1. La inyeccion de ejecutable no esta permitida fuera de la ruta adjunta.
    $overrideReportRoot = Join-Path $temp 'override-reports'
    $overrideFailed = $false
    try {
        & $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot $overrideReportRoot`
            -Route isolated -McpExecutablePath $pwsh -McpArguments $mockArguments 2>&1 | Out-Null
        & $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot $overrideReportRoot`
            -Profile write -AcknowledgeWriteProfile -Apply -Route isolated -McpExecutablePath $pwsh 2>&1 | Out-Null
    }
    catch { $overrideFailed = $true }
    if (-not $overrideFailed) { throw 'Executable injection outside the attached route must be rejected.' }
    Write-Output 'PASS: executable/argument overrides are rejected outside -Route attached'

    # 2. Sin -AttachProjectName no hay ruta adjunta.
    $noAttachFailed = $false
    try {
        & $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot (Join-Path $temp 'no-attach-reports')`
            -Route attached -Profile write -AcknowledgeWriteProfile -Apply 2>&1 | Out-Null
    }
    catch { $noAttachFailed = $true }
    if (-not $noAttachFailed) { throw 'Attached route requires -AttachProjectName.' }
    $noAttachReport = Read-LatestReport (Join-Path $temp 'no-attach-reports')
    if ($noAttachReport.status -ne 'BLOCKED' -or $noAttachReport.tiaMutation -ne $false) { throw 'Missing attach project must be BLOCKED before mutation.' }
    Write-Output 'PASS: attached route requires -AttachProjectName before any MCP call'

    # 3. groupPath no vacio bloquea antes de MCP: ImportPlcExternalSource con grupo no esta verificado.
    $groupedProposalPath = Join-Path $temp 'attached-grouped-proposal.json'
    $groupedProposal = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $groupedProposal.block.path = '01_Devices/FB_Valve'
    $groupedProposal | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $groupedProposalPath -Encoding UTF8
    $groupedFailed = $false
    $script:attachedProposalPath = $groupedProposalPath
    try {
        & $script -ProposalPath $groupedProposalPath -ProjectFile $projectFile -ReportRoot (Join-Path $temp 'grouped-reports')`
            -Route attached -Profile write -AcknowledgeWriteProfile -Apply -AttachProjectName $mockProjectName 2>&1 | Out-Null
    }
    catch { $groupedFailed = $true }
    $script:attachedProposalPath = $proposalPath
    $groupedReport = Read-LatestReport (Join-Path $temp 'grouped-reports')
    if (-not $groupedFailed -or $groupedReport.status -ne 'BLOCKED' -or $groupedReport.tiaMutation -ne $false -or
        $groupedReport.errors[0] -notmatch 'top-level blocks') {
        throw 'Non-empty groupPath must block before MCP/TIA on the attached route.'
    }
    Write-Output 'PASS: attached route refuses non-top-level blocks before MCP access'

    # 4. Sin proceso TIA (o sin ventana visible) se bloquea sin lanzar instancias.
    function global:Get-Process { return @() }
    $noTiaFailed = $false
    try {
        & $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot (Join-Path $temp 'no-tia-reports')`
            -Route attached -Profile write -AcknowledgeWriteProfile -Apply -AttachProjectName $mockProjectName 2>&1 | Out-Null
    }
    catch { $noTiaFailed = $true }
    finally { Remove-Item Function:\global:Get-Process -ErrorAction SilentlyContinue }
    $noTiaReport = Read-LatestReport (Join-Path $temp 'no-tia-reports')
    if (-not $noTiaFailed -or $noTiaReport.status -ne 'BLOCKED' -or $noTiaReport.sessionGuard.status -ne 'no-tia-process') {
        throw 'Attached route must refuse to run when no TIA process exists.'
    }
    function global:Get-Process { return @([pscustomobject]@{ ProcessName = 'Siemens.Automation.Portal'; MainWindowHandle = [IntPtr]::Zero; Id = 555000 }) }
    $hiddenFailed = $false
    try {
        & $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot (Join-Path $temp 'hidden-tia-reports')`
            -Route attached -Profile write -AcknowledgeWriteProfile -Apply -AttachProjectName $mockProjectName 2>&1 | Out-Null
    }
    catch { $hiddenFailed = $true }
    finally { Remove-Item Function:\global:Get-Process -ErrorAction SilentlyContinue }
    $hiddenReport = Read-LatestReport (Join-Path $temp 'hidden-tia-reports')
    if (-not $hiddenFailed -or $hiddenReport.sessionGuard.status -ne 'no-visible-tia-window') {
        throw 'Attached route must refuse to attach without a visible TIA window.'
    }
    Write-Output 'PASS: session guard requires an open and visible TIA process'

    # 5..9 Los casos con MCP insertan un proceso TIA falso y visible para que la
    # guardia de sesión de el paso de forma determinista en cualquier host.
    function global:Get-Process { return @([pscustomobject]@{ ProcessName = 'Siemens.Automation.Portal'; MainWindowHandle = [IntPtr]::new(1); Id = 555000 }) }

    # 5. Identidad del proyecto adjunto: mensaje y raiz del arbol.
    $env:TIA_ATTACH_FIXTURE_ATTACH = 'mismatch'
    try { Invoke-ApplyCase 'attach-mismatch' | Out-Null } finally { Remove-Item Env:\TIA_ATTACH_FIXTURE_ATTACH -ErrorAction SilentlyContinue }
    # System.Text.Json (tia-create) escapa los apostrofos como \u0027; el mensaje JSON
    # debe decodificarse antes de comparar. Un mock de PowerShell no lo reproduce.
    $escapedIdentity = '{"message":"Attached to open project \u0027Mock Project\u0027","meta":{"success":true}}'
    Assert-TiaCreateAttachIdentity -AttachMessage $escapedIdentity -ProjectTreeText "Mock Project`r`n+-- PLC_1" -ExpectedProjectName 'Mock Project'
    $fence = [string]::new([char]0x60, 3)
    $fencedTree = $fence + "text`r`nMock Project`r`n+-- PLC_1`r`n" + $fence
    Assert-TiaCreateAttachIdentity -AttachMessage $escapedIdentity -ProjectTreeText $fencedTree -ExpectedProjectName 'Mock Project'
    Write-Output 'PASS: attached project identity is verified against the attach message and the tree root'
    Write-Output 'PASS: identity accepts System.Text.Json-escaped apostrophes'

    # 6. Roster incompleto: falta DeletePlcExternalSource y se bloquea antes de mutar.
    $env:TIA_ATTACH_FIXTURE_ROSTER = 'missing-delete'
    try {
        $missingToolReport = Invoke-ApplyCase 'roster-missing-tool'
        if ($missingToolReport.errors[0] -notmatch 'DeletePlcExternalSource') {
            throw "The missing tool must be named in the blocking error; got: $($missingToolReport.errors -join ' | ')"
        }
    }
    finally { Remove-Item Env:\TIA_ATTACH_FIXTURE_ROSTER -ErrorAction SilentlyContinue }
    Write-Output 'PASS: all required tools must be registered before mutation'

    # 7. Gates F/Safety/proteccion/consistencia/etiquetas: conflic involuntario.
    foreach ($blockedCase in $blockedCases) {
        if ($blockedCase.mode -like 'tag-*' -or $blockedCase.mode -like 'tag-incomplete') {
            $env:TIA_ATTACH_FIXTURE_TAG_MODE = $blockedCase.mode
            $env:TIA_ATTACH_FIXTURE_BLOCK_MODE = $null
        }
        else {
            $env:TIA_ATTACH_FIXTURE_BLOCK_MODE = $blockedCase.mode
            $env:TIA_ATTACH_FIXTURE_TAG_MODE = $null
        }
        try { Invoke-ApplyCase $blockedCase.name | Out-Null } finally {
            Remove-Item Env:\TIA_ATTACH_FIXTURE_BLOCK_MODE -ErrorAction SilentlyContinue
            Remove-Item Env:\TIA_ATTACH_FIXTURE_TAG_MODE -ErrorAction SilentlyContinue
        }
    }
    Write-Output 'PASS: F/Safety, protection, consistency and tag gates block before any mutation'

    # 8. Compile fallido: FAILED, sin Save, con instruccion de no guardar.
    $env:TIA_ATTACH_FIXTURE_COMPILE = 'compile-error'
    $compileOrderPath = Join-Path $temp 'compile-failed-order.txt'
    $env:TIA_ATTACH_FIXTURE_ORDER = $compileOrderPath
    $compileFailed = $false
    $compileReportRoot = Join-Path $temp 'compile-failed-reports'
    $compileRunnerOutput = ''
    try {
        $compileRunnerOutput = (& $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot $compileReportRoot -Route attached -Profile write -AcknowledgeWriteProfile -Apply -AttachProjectName $mockProjectName -McpExecutablePath $pwsh -McpArguments $mockArguments -ReadbackExecutablePath $pwsh -ReadbackMcpArguments $readbackMockArguments 2>&1 | Out-String)
    }
    catch { $compileFailed = $true }
    finally {
        Remove-Item Env:\TIA_ATTACH_FIXTURE_COMPILE -ErrorAction SilentlyContinue
        Remove-Item Env:\TIA_ATTACH_FIXTURE_ORDER -ErrorAction SilentlyContinue
    }
    $global:LASTEXITCODE = 0
    if ($compileRunnerOutput) { Write-Output "runner-output: $($compileRunnerOutput | Out-String)" }
    $compileReport = Read-LatestReport $compileReportRoot
    if (-not $compileFailed -or $compileReport.status -ne 'FAILED' -or $compileReport.tiaMutation -ne $true) {
        throw 'A failed compile gate must end FAILED with recorded mutation.'
    }
    if ($compileReport.save.reason -ne 'compile-gate' -or -not $compileReport.postFailureInstruction) {
        throw 'A failed compile must explain the no-save instruction on the attached route.'
    }
    Write-Output 'PASS: failed compile gate refuses SaveProject and instructs no-save'

    # 9. Camino feliz: orden de llamada exacto y estado APPLIED_AND_VERIFIED.
    $happyOrderPath = Join-Path $temp 'happy-order.txt'
    $happyReadbackOrderPath = Join-Path $temp 'happy-readback-order.txt'
    $env:TIA_ATTACH_FIXTURE_ORDER = $happyOrderPath
    $env:TIA_READBACK_FIXTURE_ORDER = $happyReadbackOrderPath
    $happyReportRoot = Join-Path $temp 'happy-reports'
    $happyFailed = $false
    try {
        & $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot $happyReportRoot -Route attached -Profile write -AcknowledgeWriteProfile -Apply -AttachProjectName $mockProjectName -McpExecutablePath $pwsh -McpArguments $mockArguments -ReadbackExecutablePath $pwsh -ReadbackMcpArguments $readbackMockArguments
    }
    catch { $happyFailed = $true }
    finally {
        Remove-Item Env:\TIA_ATTACH_FIXTURE_ORDER -ErrorAction SilentlyContinue
        Remove-Item Env:\TIA_READBACK_FIXTURE_ORDER -ErrorAction SilentlyContinue
    }
    if ($happyFailed -or $LASTEXITCODE -ne 0) { throw "Happy path apply failed: exit=$LASTEXITCODE." }
    $global:LASTEXITCODE = 0
    $happyReport = Read-LatestReport $happyReportRoot
    if ($happyReport.status -ne 'APPLIED_AND_VERIFIED' -or $happyReport.applied -ne $true -or
        $happyReport.tiaMutation -ne $true -or $happyReport.compile.errorCount -ne 0) {
        throw 'Happy path must be APPLIED_AND_VERIFIED with a clean compile.'
    }
    if ($happyReport.readback.success -ne $true -or $happyReport.readback.server -ne 'tia-inspect' -or $happyReport.readback.mode -ne 'attach') {
        throw 'Happy path must record a successful attach readback (content delta gate).'
    }
    if ($happyReport.verification.sourceCompared -ne $true) {
        throw 'Happy path verification must prove the source text was compared against the proposal.'
    }
    if ($happyReport.mcp.server -ne 'tia-create' -or $happyReport.mcp.profile -ne 'full' -or $happyReport.mcp.isolated -ne $false) {
        throw 'Happy path must record the attached tia-create full session.'
    }
    if ($happyReport.sessionGuard.success -ne $true -or $happyReport.attach.projectName -ne $mockProjectName) {
        throw 'Happy path must record the verified session guard and attached project.'
    }
    $recordedOrder = @(Get-Content -LiteralPath $happyOrderPath -ErrorAction SilentlyContinue | Where-Object { $_ })
    if (($recordedOrder -join '|') -ne ($expectedFullOrder -join '|')) {
        throw "Call order mismatch:`n recorded: $($recordedOrder -join ', ')`n expected: $($expectedFullOrder -join ', ')"
    }

    # 10. Readback: el orden Connect/GetState/GetBlockSource quedo registrado y la
    # propuesta falsa se comparo contra el texto si el modo no impone un mismatch.
    $happyReadbackOrderPath = Join-Path $temp 'happy-readback-order.txt'
    $recordedReadbackOrder = @(Get-Content -LiteralPath $happyReadbackOrderPath -ErrorAction SilentlyContinue | Where-Object { $_ })
    if (($recordedReadbackOrder -join '|') -ne ($expectedReadbackOrder -join '|')) {
        throw "Readback call order mismatch:`n recorded: $($recordedReadbackOrder -join ', ')`
 expected: $($expectedReadbackOrder -join ', ')"
    }
    Write-Output 'PASS: happy path applied with the exact verified call order and the content delta readback'

    # 11. Mismatch de contenido: el SaveProject NO se intenta y el estado es explicito.
    # Ordem que debe respetarse: la mutacion ocurre (tiaMutation=true) pero no se guarda y
    # no se declara exito.
    $env:TIA_READBACK_FIXTURE_MODE = 'mismatch'
    $mismatchReportRoot = Join-Path $temp 'readback-mismatch-reports'
    $ismatchFailed = $false
    try {
        & $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot $mismatchReportRoot -Route attached -Profile write -AcknowledgeWriteProfile -Apply -AttachProjectName $mockProjectName -McpExecutablePath $pwsh -McpArguments $mockArguments -ReadbackExecutablePath $pwsh -ReadbackMcpArguments $readbackMockArguments 2>&1 | Out-Null
    }
    catch { $mismatchFailed = $true }
    finally { $env:TIA_READBACK_FIXTURE_MODE = 'happy' }
    $global:LASTEXITCODE = 0
    if (-not $mismatchFailed) { throw 'A readback mismatch must fail the runner with exit 1.' }
    $mismatchReport = Read-LatestReport $mismatchReportRoot
    if ($mismatchReport.status -ne 'APPLIED_CONTENT_MISMATCH' -or $mismatchReport.tiaMutation -ne $true -or
        $mismatchReport.save.attempted -ne $false -or $mismatchReport.save.reason -ne 'readback-content-gate' -or
        -not $mismatchReport.postFailureInstruction) {
        throw "A readback mismatch must be APPLIED_CONTENT_MISMATCH, mutated, with SaveProject blocked by the content gate; got status=$($mismatchReport.status) save=(attempted=$($mismatchReport.save.attempted), reason=$($mismatchReport.save.reason))."
    }
    Write-Output 'PASS: content mismatch blocks SaveProject and reports APPLIED_CONTENT_MISMATCH'

    # 12. Readback degradado (fallo de infraestructura): no se guarda y el estado es explicito.
    foreach ($readbackFailureCase in @('crash', 'truncated', 'wrong-project')) {
        $env:TIA_READBACK_FIXTURE_MODE = $readbackFailureCase
        $failureReportRoot = Join-Path $temp ("readback-$readbackFailureCase-reports")
        $failureFailed = $false
        try {
            & $script -ProposalPath $proposalPath -ProjectFile $projectFile -ReportRoot $failureReportRoot -Route attached -Profile write -AcknowledgeWriteProfile -Apply -AttachProjectName $mockProjectName -McpExecutablePath $pwsh -McpArguments $mockArguments -ReadbackExecutablePath $pwsh -ReadbackMcpArguments $readbackMockArguments 2>&1 | Out-Null
        }
        catch { $failureFailed = $true }
        finally { $env:TIA_READBACK_FIXTURE_MODE = 'happy' }
        $global:LASTEXITCODE = 0
        if (-not $failureFailed) { throw "A readback infrastructure failure (mode '$readbackFailureCase') must fail the runner with exit 1." }
        $failureReport = Read-LatestReport $failureReportRoot
        if ($failureReport.status -ne 'APPLIED_READBACK_FAILED' -or $failureReport.tiaMutation -ne $true -or
            $failureReport.save.attempted -ne $false -or $failureReport.save.reason -ne 'readback-content-gate') {
            throw "Readback failure mode '$readbackFailureCase' must be APPLIED_READBACK_FAILED with SaveProject blocked; got status=$($failureReport.status)."
        }
    }
    Write-Output 'PASS: failed or unverifiable readback blocks SaveProject and reports APPLIED_READBACK_FAILED'

    # 13. Veto solo-cabecera (ADR-018, evidencia 2026-10-28): una propuesta cuyo unico
    # delta sean atributos VERSION se rechaza antes de abrir cualquier sesion MCP.
    $originalOnlyPath = Join-Path $temp 'FB_Valve_original.scl'
    @'
FUNCTION_BLOCK "FB_Valve"
VERSION : 0.1
BEGIN
   #Open := TRUE;
END_FUNCTION_BLOCK
'@ | Set-Content -LiteralPath $originalOnlyPath -Encoding UTF8
    $proposedOnlyPath = Join-Path $temp 'FB_Valve_version02.scl'
    @'
FUNCTION_BLOCK "FB_Valve"
VERSION : 0.2
BEGIN
   #Open := TRUE;
END_FUNCTION_BLOCK
'@ | Set-Content -LiteralPath $proposedOnlyPath -Encoding UTF8
    $vetoProposalPath = Join-Path $temp 'veto-proposal.json'
    $vetoProposalOriginalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $originalOnlyPath).Hash.ToLowerInvariant()
    $vetoProposalProposedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $proposedOnlyPath).Hash.ToLowerInvariant()
    [ordered]@{
        schemaVersion = 1; status = 'PROPOSED'; readOnly = $true; applied = $false; tiaMutation = $false
        projectPath = $projectFile; sourceRoot = $temp; plc = 'PLC_1'
        block = [ordered]@{ name = 'FB_Valve'; path = 'FB_Valve'; language = 'SCL' }
        source = [ordered]@{ originalPath = $originalOnlyPath; proposedPath = $proposedOnlyPath; proposedSha256 = $vetoProposalProposedHash; originalSha256 = $vetoProposalOriginalHash; matchCount = 1; extension = '.scl' }
        checks = [ordered]@{ exactBlockMatch = $true; sclOnly = $true; noBlockingFindings = $true; uniqueReplacement = $true; originalUntouched = $true }
        findings = @()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $vetoProposalPath -Encoding UTF8
    $vetoReportRoot = Join-Path $temp 'veto-reports'
    $vetoFailed = $false
    try {
        & $script -ProposalPath $vetoProposalPath -ProjectFile $projectFile -ReportRoot $vetoReportRoot -Route attached -Profile write -AcknowledgeWriteProfile -Apply -AttachProjectName $mockProjectName -McpExecutablePath $pwsh -McpArguments $mockArguments -ReadbackExecutablePath $pwsh -ReadbackMcpArguments $readbackMockArguments 2>&1 | Out-Null
    }
    catch { $vetoFailed = $true }
    $global:LASTEXITCODE = 0
    if (-not $vetoFailed) { throw 'A header-only proposal (VERSION-only delta) must be refused.' }
    $vetoReport = Read-LatestReport $vetoReportRoot
    if ($vetoReport.status -ne 'BLOCKED' -or $vetoReport.tiaMutation -ne $false -or
        $vetoReport.errors[0] -notmatch 'VERSION header') {
        throw "The header-only veto must block before MCP with a VERSION reason; got status=$($vetoReport.status) errors=$($vetoReport.errors -join ' | ')."
    }
    Write-Output 'PASS: header-only (VERSION-only) proposals are vetoed before any MCP access'
    if (Test-Path -LiteralPath $projectFile -PathType Leaf) {
        $fileHash = (Get-FileHash -LiteralPath $projectFile -Algorithm SHA256).Hash
        if ($fileHash -eq [string]::Empty) { throw 'Marker integrity check failed.' }
    }
    Write-Output 'PASS: happy path applies with the exact verified call order and records the attached session'
}
finally {
    Remove-Item Function:\global:Get-Process -ErrorAction SilentlyContinue
    Remove-Item Env:\TIA_ATTACH_FIXTURE_BLOCK_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:\TIA_ATTACH_FIXTURE_TAG_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:\TIA_ATTACH_FIXTURE_ROSTER -ErrorAction SilentlyContinue
    Remove-Item Env:\TIA_ATTACH_FIXTURE_ATTACH -ErrorAction SilentlyContinue
    Remove-Item Env:\TIA_ATTACH_FIXTURE_COMPILE -ErrorAction SilentlyContinue
    Remove-Item Env:\TIA_ATTACH_FIXTURE_ORDER -ErrorAction SilentlyContinue
    Remove-Item Env:\TIA_READBACK_FIXTURE_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:\TIA_READBACK_FIXTURE_ORDER -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
