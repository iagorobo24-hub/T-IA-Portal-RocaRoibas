[CmdletBinding()]
param()

# Prueba de Test-TiaAttachedRoutePreflight.ps1 con un proceso TIA simulado.
# No ejecuta TIA ni MCP: comprueba el contrato READY/BLOCKED y cada gate del preflight.

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Test-TiaAttachedRoutePreflight.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-preflight-test-' + [guid]::NewGuid().ToString('N'))

function Get-PreflightCheck($Report, [string]$Name) {
    return @($Report.checks | Where-Object { $_.name -eq $Name })[0]
}

function Invoke-Preflight {
    param(
        [string]$Proposal = $script:proposalPath,
        [string]$Project = $script:projectFile,
        [string]$Attach = 'Mock Project',
        [string]$Binary = $script:dummyBinary,
        [string]$Backup = $script:backupFile
    )
    $raw = (& $script -ProposalPath $Proposal -ProjectFile $Project -AttachProjectName $Attach `
        -TiaCreateExecutable $Binary -BackupProjectFile $Backup -WorkspaceRoot $root 2>&1 | Out-String)
    $code = $LASTEXITCODE
    $json = $null
    try { $json = $raw | ConvertFrom-Json } catch { throw "Preflight did not return JSON: $raw" }
    return [pscustomobject]@{ code = $code; raw = $raw; json = $json }
}

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $projectFile = Join-Path $temp 'Target_V20.ap20'
    'marker: copia desechable del proyecto' | Set-Content -LiteralPath $projectFile -Encoding UTF8
    $sourcePath = Join-Path $temp 'FB_Motor.scl'
    @'
FUNCTION_BLOCK "FB_Motor"
VERSION : 0.2
BEGIN
END_FUNCTION_BLOCK
'@ | Set-Content -LiteralPath $sourcePath -Encoding UTF8
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash.ToLowerInvariant()
    $dummyBinary = Join-Path $temp 'TiaMcpServer.exe'
    'mock binary' | Set-Content -LiteralPath $dummyBinary -Encoding ASCII
    $backupFile = Join-Path $temp 'pristine.ap20'
    Copy-Item -LiteralPath $projectFile -Destination $backupFile -Force

    $proposalPath = Join-Path $temp 'proposal.json'
    [ordered]@{
        schemaVersion = 1
        status = 'PROPOSED'
        readOnly = $true
        applied = $false
        tiaMutation = $false
        projectPath = $projectFile
        plc = 'PLC_1'
        block = [ordered]@{ name = 'FB_Motor'; path = 'FB_Motor'; language = 'SCL' }
        source = [ordered]@{
            originalPath = $sourcePath; proposedPath = $sourcePath
            originalSha256 = $sourceHash; proposedSha256 = $sourceHash
            matchCount = 1; extension = '.scl'
        }
        checks = [ordered]@{ exactBlockMatch = $true; sclOnly = $true; noBlockingFindings = $true; uniqueReplacement = $true; originalUntouched = $true }
        findings = @()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $proposalPath -Encoding UTF8

    function global:Get-Process { return $global:mockTiaProcesses }
    $global:mockTiaProcesses = @([pscustomobject]@{ Id = 101; ProcessName = 'Siemens.Automation.Portal'; MainWindowHandle = [IntPtr]1 })

    # 1. Caso READY completo.
    $ready = Invoke-Preflight
    if ($ready.code -ne 0 -or $ready.json.status -ne 'READY') { throw "Expected READY/0, got $($ready.json.status)/$($ready.code): $($ready.raw)" }
    foreach ($name in @('tia-process', 'tia-create-binary', 'attach-project-name', 'project-file', 'backup-copy', 'proposal-file', 'proposal-block', 'proposal-sources')) {
        if ((Get-PreflightCheck $ready.json $name).status -ne 'PASS') { throw "Expected PASS for $name in READY case." }
    }
    if ((Get-PreflightCheck $ready.json 'tia-process').details.visiblePids.Count -ne 1) { throw 'READY must record exactly one visible TIA pid.' }
    Write-Output 'PASS: preflight returns READY with a visible TIA, copy, backup and valid proposal'

    # 2. Sin proceso TIA.
    $global:mockTiaProcesses = @()
    $noTia = Invoke-Preflight
    if ($noTia.code -ne 1 -or $noTia.json.status -ne 'BLOCKED') { throw 'Expected BLOCKED/1 without a TIA process.' }
    if ((Get-PreflightCheck $noTia.json 'tia-process').details.status -ne 'no-tia-process') { throw 'Missing no-tia-process detail.' }
    Write-Output 'PASS: preflight blocks when no TIA process exists'

    # 3. Proceso sin ventana visible.
    $global:mockTiaProcesses = @([pscustomobject]@{ Id = 102; ProcessName = 'Siemens.Automation.Portal'; MainWindowHandle = [IntPtr]0 })
    $hidden = Invoke-Preflight
    if ($hidden.json.status -ne 'BLOCKED' -or (Get-PreflightCheck $hidden.json 'tia-process').details.status -ne 'no-visible-tia-window') {
        throw 'Expected BLOCKED no-visible-tia-window.'
    }
    Write-Output 'PASS: preflight blocks a TIA process without a visible window'

    # 4. Dos ventanas visibles.
    $global:mockTiaProcesses = @(
        [pscustomobject]@{ Id = 103; ProcessName = 'Siemens.Automation.Portal'; MainWindowHandle = [IntPtr]1 },
        [pscustomobject]@{ Id = 104; ProcessName = 'Siemens.Automation.Portal'; MainWindowHandle = [IntPtr]2 }
    )
    $multiple = Invoke-Preflight
    if ($multiple.json.status -ne 'BLOCKED' -or (Get-PreflightCheck $multiple.json 'tia-process').details.status -ne 'multiple-visible-tia-windows') {
        throw 'Expected BLOCKED multiple-visible-tia-windows.'
    }
    $global:mockTiaProcesses = @([pscustomobject]@{ Id = 101; ProcessName = 'Siemens.Automation.Portal'; MainWindowHandle = [IntPtr]1 })
    Write-Output 'PASS: preflight blocks more than one visible TIA window'

    # 5. Proyecto original del repositorio: nunca es copia desechable.
    $originalProject = Join-Path $root '40-projects\DEMO-Cinta01\tia\DEMO-Cinta01\DEMO-Cinta01.ap20'
    if (Test-Path -LiteralPath $originalProject -PathType Leaf) {
        $originalProposal = Join-Path $temp 'proposal-original.json'
        $originalObject = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
        $originalObject.projectPath = $originalProject
        $originalObject | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $originalProposal -Encoding UTF8
        $notDisposable = Invoke-Preflight -Proposal $originalProposal -Project $originalProject
        if ($notDisposable.json.status -ne 'BLOCKED' -or (Get-PreflightCheck $notDisposable.json 'project-file').status -ne 'BLOCKED') {
            throw 'Expected the repository original project to be blocked as non-disposable.'
        }
        Write-Output 'PASS: preflight refuses a .ap20 under the repository original trees'
    }
    else {
        Write-Output 'WARN: demo project not present; non-disposable case skipped'
    }

    # 6. Hash de fuente manipulado.
    $tamperedProposal = Join-Path $temp 'proposal-tampered.json'
    $tampered = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $tampered.source.proposedSha256 = ('0' * 64)
    $tampered | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tamperedProposal -Encoding UTF8
    $hashFail = Invoke-Preflight -Proposal $tamperedProposal
    if ($hashFail.json.status -ne 'BLOCKED' -or (Get-PreflightCheck $hashFail.json 'proposal-sources').status -ne 'BLOCKED') {
        throw 'Expected a tampered proposedSha256 to block proposal-sources.'
    }
    Write-Output 'PASS: preflight blocks a proposal whose source hash no longer matches'

    # 7. Binario tia-create ausente.
    $missingBinary = Invoke-Preflight -Binary (Join-Path $temp 'missing-TiaMcpServer.exe')
    if ($missingBinary.json.status -ne 'BLOCKED' -or (Get-PreflightCheck $missingBinary.json 'tia-create-binary').status -ne 'BLOCKED') {
        throw 'Expected a missing tia-create binary to block.'
    }
    Write-Output 'PASS: preflight blocks when the tia-create binary is missing'

    # 8. Backup no pristino.
    Add-Content -LiteralPath $backupFile -Value 'drift' -Encoding ASCII
    $badBackup = Invoke-Preflight
    if ($badBackup.json.status -ne 'BLOCKED' -or (Get-PreflightCheck $badBackup.json 'backup-copy').status -ne 'BLOCKED') {
        throw 'Expected a drifted backup to block.'
    }
    Write-Output 'PASS: preflight blocks a backup that does not match the working copy'

    # 9. Sin backup declarado: WARN, no bloquea.
    $noBackup = Invoke-Preflight -Backup ''
    if ($noBackup.json.status -ne 'READY' -or (Get-PreflightCheck $noBackup.json 'backup-copy').status -ne 'WARN') {
        throw 'Expected a missing backup declaration to WARN without blocking READY.'
    }
    Write-Output 'PASS: preflight warns (not blocks) when no backup is declared'
}
finally {
    Remove-Item Function:\global:Get-Process -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
