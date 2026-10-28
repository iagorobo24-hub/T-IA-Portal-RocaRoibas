<#
.SYNOPSIS
    Preflight de SOLO LECTURA para -Route attached de Invoke-TiaSclProposalApply.

.DESCRIPTION
    Comprueba, sin abrir MCP ni tocar TIA, lo que puede verificarse antes de la sesion live:
    proceso TIA con ventana visible, binario tia-create, copia desechable del proyecto,
    backup opcional y contrato local de la propuesta (estado, bloque, fuentes y hashes).

    No comprueba el roster live ni la identidad real del proyecto abierto: eso exige la
    sesion MCP y lo decide el runner. Este script solo evita llegar a TIA con un preflight
    roto. Devuelve un informe JSON con status READY o BLOCKED; exit 0 para READY y 1 para
    BLOCKED.

.PARAMETER ProposalPath
    proposal.json generado por New-TiaSclProposal.

.PARAMETER ProjectFile
    .ap20 de la COPIA desechable que se abrira en TIA (nunca el original del repositorio).

.PARAMETER AttachProjectName
    Nombre exacto del proyecto que se pasara a AttachToOpenProject.

.PARAMETER WorkspaceRoot
    Raiz del workspace; por defecto, dos niveles por encima de este script.

.PARAMETER TiaCreateExecutable
    Binario tia-create full; por defecto 30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe.

.PARAMETER BackupProjectFile
    Opcional. Copia pristina contra la que se comprueba el hash de la copia de trabajo.

.PARAMETER OutputPath
    Opcional. Ruta donde escribir el mismo JSON que se imprime.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProposalPath,

    [Parameter(Mandatory = $true)]
    [string]$ProjectFile,

    [Parameter(Mandatory = $true)]
    [string]$AttachProjectName,

    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$TiaCreateExecutable,
    [string]$BackupProjectFile,
    [string]$OutputPath,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output @'
Test-TiaAttachedRoutePreflight.ps1: preflight de solo lectura para -Route attached.
Uso:
  .\Test-TiaAttachedRoutePreflight.ps1 -ProposalPath ...\proposal.json `
      -ProjectFile ...\Demo_Copy\DEMO-Cinta01.ap20 -AttachProjectName 'DEMO-Cinta01' `
      [-BackupProjectFile ...\pristine\DEMO-Cinta01.ap20] [-OutputPath ...\preflight.json]

Devuelve JSON con status READY (exit 0) o BLOCKED (exit 1). No abre MCP ni modifica TIA.
'@
    exit 0
}

$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
if (-not $TiaCreateExecutable) {
    $TiaCreateExecutable = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
}

function Resolve-InputPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $Path))
}

$checks = [System.Collections.Generic.List[object]]::new()
function Add-PreflightCheck([string]$Name, [string]$Status, [string]$Message, $Details = $null) {
    $entry = [ordered]@{ name = $Name; status = $Status; message = $Message }
    if ($null -ne $Details) { $entry.details = $Details }
    $script:checks.Add($entry)
}

$ProposalPath = Resolve-InputPath $ProposalPath
$ProjectFile = Resolve-InputPath $ProjectFile
$TiaCreateExecutable = Resolve-InputPath $TiaCreateExecutable
if ($BackupProjectFile) { $BackupProjectFile = Resolve-InputPath $BackupProjectFile }

# --- 1. Proceso TIA con ventana visible ---------------------------------------
$tiaProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -like 'Siemens.Automation.Portal*'
})
$visibleProcesses = @($tiaProcesses | Where-Object { $_.MainWindowHandle -ne 0 })
if ($tiaProcesses.Count -eq 0) {
    Add-PreflightCheck 'tia-process' 'BLOCKED' 'No hay ningun proceso TIA Portal: abre la copia desechable antes de aplicar.' @{
        status = 'no-tia-process'; processCount = 0
    }
}
elseif ($visibleProcesses.Count -eq 0) {
    Add-PreflightCheck 'tia-process' 'BLOCKED' 'Hay proceso TIA pero ninguna ventana visible; restaura la ventana y repite.' @{
        status = 'no-visible-tia-window'; processIds = @($tiaProcesses.Id)
    }
}
elseif ($visibleProcesses.Count -gt 1) {
    Add-PreflightCheck 'tia-process' 'BLOCKED' 'Hay mas de una ventana TIA visible; deja solo la instancia de la copia desechable.' @{
        status = 'multiple-visible-tia-windows'; visiblePids = @($visibleProcesses.Id)
    }
}
else {
    Add-PreflightCheck 'tia-process' 'PASS' 'Hay una unica ventana TIA visible para adjuntar.' @{
        status = 'open-tia-window'; visiblePids = @($visibleProcesses.Id); processIds = @($tiaProcesses.Id)
    }
}

# --- 2. Binario tia-create -----------------------------------------------------
if (-not (Test-Path -LiteralPath $TiaCreateExecutable -PathType Leaf)) {
    Add-PreflightCheck 'tia-create-binary' 'BLOCKED' "No existe el binario tia-create: $TiaCreateExecutable" @{
        requiredPath = $TiaCreateExecutable
    }
}
else {
    $binaryItem = Get-Item -LiteralPath $TiaCreateExecutable
    Add-PreflightCheck 'tia-create-binary' 'PASS' 'Binario tia-create presente (no se ejecuta en el preflight).' @{
        path = $binaryItem.FullName; bytes = $binaryItem.Length; version = [string]$binaryItem.VersionInfo.ProductVersion
    }
}

# --- 3. Nombre de proyecto a adjuntar -----------------------------------------
if ([string]::IsNullOrWhiteSpace($AttachProjectName)) {
    Add-PreflightCheck 'attach-project-name' 'BLOCKED' 'AttachProjectName esta vacio.' @{}
}
elseif ($AttachProjectName -match '[\\/]') {
    Add-PreflightCheck 'attach-project-name' 'BLOCKED' 'AttachProjectName no puede contener separadores de ruta.' @{
        value = $AttachProjectName
    }
}
else {
    Add-PreflightCheck 'attach-project-name' 'PASS' 'AttachProjectName declarado; el humano debe confirmarlo contra el titulo de TIA.' @{
        value = $AttachProjectName
    }
}

# --- 4. Proyecto: existe y es una copia desechable -----------------------------
$projectHash = $null
if (-not (Test-Path -LiteralPath $ProjectFile -PathType Leaf)) {
    Add-PreflightCheck 'project-file' 'BLOCKED' "No existe el .ap20 indicado: $ProjectFile" @{}
}
else {
    $projectItem = Get-Item -LiteralPath $ProjectFile
    $projectHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $projectFile).Hash.ToLowerInvariant()
    $insideOriginalRoot = $false
    foreach ($originalRootName in @('40-projects', '50-examples')) {
        $guard = [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $originalRootName)).TrimEnd('\')
        if ($ProjectFile.StartsWith($guard + '\', [StringComparison]::OrdinalIgnoreCase)) { $insideOriginalRoot = $true }
    }
    if ($insideOriginalRoot) {
        Add-PreflightCheck 'project-file' 'BLOCKED' 'El .ap20 esta bajo 40-projects/50-examples: abre una copia desechable, no el original.' @{
            projectFile = $projectFile; projectSha256 = $projectHash
        }
    }
    else {
        Add-PreflightCheck 'project-file' 'PASS' 'Proyecto copia presente y fuera de los arboles originales.' @{
            projectFile = $projectFile; bytes = $projectItem.Length; projectSha256 = $projectHash
        }
    }
}

# --- 5. Backup pristino opcional ----------------------------------------------
if (-not $BackupProjectFile) {
    Add-PreflightCheck 'backup-copy' 'WARN' 'No se declaro -BackupProjectFile; el checklist humano exige una copia pristina para restaurar.' @{}
}
elseif (-not (Test-Path -LiteralPath $BackupProjectFile -PathType Leaf)) {
    Add-PreflightCheck 'backup-copy' 'BLOCKED' "No existe el backup indicado: $BackupProjectFile" @{}
}
elseif (-not $projectHash) {
    Add-PreflightCheck 'backup-copy' 'BLOCKED' 'No se pudo calcular el hash del proyecto; no se puede validar el backup.' @{}
}
else {
    $backupHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $BackupProjectFile).Hash.ToLowerInvariant()
    if ($backupHash -ne $projectHash) {
        Add-PreflightCheck 'backup-copy' 'BLOCKED' 'El hash del backup no coincide con la copia de trabajo; el backup no es pristino.' @{
            backupSha256 = $backupHash; projectSha256 = $projectHash
        }
    }
    else {
        Add-PreflightCheck 'backup-copy' 'PASS' 'Backup pristino coincide byte a byte con la copia de trabajo.' @{
            backupSha256 = $backupHash
        }
    }
}

# --- 6. Propuesta: contrato local completo ------------------------------------
$proposal = $null
if (-not (Test-Path -LiteralPath $ProposalPath -PathType Leaf)) {
    Add-PreflightCheck 'proposal-file' 'BLOCKED' "No existe la propuesta: $ProposalPath" @{}
}
else {
    try {
        $proposal = Get-Content -Raw -LiteralPath $ProposalPath | ConvertFrom-Json
    }
    catch {
        Add-PreflightCheck 'proposal-file' 'BLOCKED' "La propuesta no es JSON valido: $($_.Exception.Message)" @{}
    }
}

if ($proposal) {
    $contractErrors = [System.Collections.Generic.List[string]]::new()
    if ([string]$proposal.status -ne 'PROPOSED') { $contractErrors.Add("status debe ser PROPOSED, no '$($proposal.status)'") }
    if ($proposal.readOnly -ne $true) { $contractErrors.Add('readOnly debe ser true') }
    if ($proposal.applied -ne $false) { $contractErrors.Add('applied debe ser false') }
    if ($proposal.tiaMutation -ne $false) { $contractErrors.Add('tiaMutation debe ser false') }
    $proposalProject = if ($proposal.projectPath) { [IO.Path]::GetFullPath([string]$proposal.projectPath) } else { '' }
    if ($proposalProject -ne $ProjectFile) {
        $contractErrors.Add("projectPath '$proposalProject' no es el ProjectFile '$ProjectFile'")
    }
    if ($contractErrors.Count -eq 0) {
        Add-PreflightCheck 'proposal-file' 'PASS' 'Propuesta PROPOSED ligada exactamente al .ap20 indicado.' @{
            proposalPath = $ProposalPath; projectPath = $proposalProject
        }
    }
    else {
        Add-PreflightCheck 'proposal-file' 'BLOCKED' ('Contrato de propuesta invalido: ' + ($contractErrors -join '; ')) @{
            errors = @($contractErrors)
        }
    }

    $blockErrors = [System.Collections.Generic.List[string]]::new()
    $blockName = [string]$proposal.block.name
    $blockPath = [string]$proposal.block.path
    if ([string]$proposal.block.language -ne 'SCL') { $blockErrors.Add("language debe ser SCL, no '$($proposal.block.language)'") }
    if ($blockName -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { $blockErrors.Add("nombre de bloque no simbolico: '$blockName'") }
    if ([string]::IsNullOrWhiteSpace($blockPath)) { $blockErrors.Add('block.path esta vacio') }
    elseif ($blockPath -match '[\\/]') { $blockErrors.Add("block.path '$blockPath' no es top-level (la ruta adjunta solo admite groupPath vacio)") }
    elseif ($blockPath -ne $blockName) { $blockErrors.Add("block.path '$blockPath' no coincide con el nombre '$blockName'") }
    if ($proposal.checks.uniqueReplacement -ne $true) { $blockErrors.Add('checks.uniqueReplacement debe ser true') }
    if ($blockErrors.Count -eq 0) {
        Add-PreflightCheck 'proposal-block' 'PASS' 'Bloque SCL, top-level y reemplazo unico declarado.' @{
            block = $blockName; blockPath = $blockPath
        }
    }
    else {
        Add-PreflightCheck 'proposal-block' 'BLOCKED' ('Bloque no elegible para -Route attached: ' + ($blockErrors -join '; ')) @{
            errors = @($blockErrors)
        }
    }

    $sourceErrors = [System.Collections.Generic.List[string]]::new()
    $proposedSource = [string]$proposal.source.proposedPath
    $originalSource = [string]$proposal.source.originalPath
    if ($proposedSource) { $proposedSource = [IO.Path]::GetFullPath($proposedSource) }
    if ($originalSource) { $originalSource = [IO.Path]::GetFullPath($originalSource) }
    $extension = if ($proposedSource) { [IO.Path]::GetExtension($proposedSource).ToLowerInvariant() } else { '' }
    if ($extension -ne '.scl') {
        $sourceErrors.Add("la ruta adjunta solo aplica .scl; la fuente es '$extension'")
    }
    if (-not $proposedSource -or -not (Test-Path -LiteralPath $proposedSource -PathType Leaf)) {
        $sourceErrors.Add("proposedPath no existe: '$proposedSource'")
    }
    if (-not $originalSource -or -not (Test-Path -LiteralPath $originalSource -PathType Leaf)) {
        $sourceErrors.Add("originalPath no existe: '$originalSource'")
    }
    if ($sourceErrors.Count -eq 0) {
        $proposedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $proposedSource).Hash.ToLowerInvariant()
        $originalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $originalSource).Hash.ToLowerInvariant()
        if ($proposedHash -ne ([string]$proposal.source.proposedSha256).ToLowerInvariant()) {
            $sourceErrors.Add('proposedSha256 no coincide con la fuente propuesta')
        }
        if ($originalHash -ne ([string]$proposal.source.originalSha256).ToLowerInvariant()) {
            $sourceErrors.Add('originalSha256 no coincide con la fuente original')
        }
        if ($sourceErrors.Count -eq 0) {
            Add-PreflightCheck 'proposal-sources' 'PASS' 'Fuentes .scl presentes y hashes coincidentes.' @{
                proposedSource = $proposedSource; proposedSha256 = $proposedHash; originalSource = $originalSource; originalSha256 = $originalHash
            }
        }
        else {
            Add-PreflightCheck 'proposal-sources' 'BLOCKED' ('Hashes de fuente invalidos: ' + ($sourceErrors -join '; ')) @{
                errors = @($sourceErrors)
            }
        }
    }
    else {
        Add-PreflightCheck 'proposal-sources' 'BLOCKED' ('Fuentes no elegibles: ' + ($sourceErrors -join '; ')) @{
            errors = @($sourceErrors)
        }
    }
}

$blocked = @($checks | Where-Object { $_.status -eq 'BLOCKED' })
$warnings = @($checks | Where-Object { $_.status -eq 'WARN' })
$report = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    status = if ($blocked.Count -eq 0) { 'READY' } else { 'BLOCKED' }
    summary = [ordered]@{ pass = @($checks | Where-Object { $_.status -eq 'PASS' }).Count; warn = $warnings.Count; blocked = $blocked.Count }
    inputs = [ordered]@{
        workspaceRoot = $WorkspaceRoot
        proposalPath = $ProposalPath
        projectFile = $ProjectFile
        attachProjectName = $AttachProjectName
        backupProjectFile = $BackupProjectFile
        tiaCreateExecutable = $TiaCreateExecutable
    }
    note = 'Solo lectura: no abre MCP ni modifica TIA ni el proyecto. No verifica roster ni identidad real; eso lo decide el runner en la sesion live.'
    checks = @($checks)
}
$json = $report | ConvertTo-Json -Depth 10
if ($OutputPath) {
    $OutputPath = Resolve-InputPath $OutputPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
    $json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
Write-Output $json
if ($blocked.Count -gt 0) { exit 1 }
exit 0
