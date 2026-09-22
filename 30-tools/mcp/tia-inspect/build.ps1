<#
.SYNOPSIS
    Prepara, parchea y compila el servidor MCP tia-inspect (heilingbrunner/tiaportal-mcp)
    contra la version de Openness instalada en esta maquina.

.DESCRIPTION
    Upstream targetea TIA V21. Esta maquina tiene V19 y V20, asi que hace falta:
      - fijar el paquete NuGet de Openness a la version correspondiente
      - parchear PlcWatchTable.Name (solo escribible desde V21)
      - bajar el suelo de deteccion de instalaciones de V21 a V19

    El cambio local completo vive en un único parche canónico, fijado a UPSTREAM-COMMIT.txt.
    Los parches previos están archivados y no se aplican. El script nunca revierte ni elimina
    cambios locales de upstream: valida el commit base y detecta el parche como ya aplicado,
    lo aplica si encaja, o falla preservando los archivos si el estado es ambiguo.

.PARAMETER TiaMajor
    20 (por defecto) o 21. V19 AUN NO esta soportado: la API de documentos
    SIMATIC SD (.s7dcl/.s7res) no existe antes de Openness V20 y habria que
    compilar fuera toda esa funcionalidad. Ver 00-meta/decisiones/ADR-002.

.EXAMPLE
.\build.ps1                 # compila para TIA V20
.\build.ps1 -TiaMajor 21    # compila para TIA V21
.\build.ps1 -Clean          # limpia los artefactos de compilacion; no borra upstream/
#>
[CmdletBinding()]
param(
    [ValidateSet(20, 21)]
    [int]$TiaMajor = 20,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$upstream = Join-Path $root 'upstream'
$repoUrl = 'https://github.com/heilingbrunner/tiaportal-mcp.git'
$patchDir = Join-Path $root 'patches'
$baseCommitFile = Join-Path $patchDir 'UPSTREAM-COMMIT.txt'
$canonicalPatch = Join-Path $patchDir '0001-tia-agent-workspace.patch'

if (-not (Test-Path -LiteralPath $baseCommitFile)) {
    throw "Falta el pin del commit upstream: $baseCommitFile"
}
$expectedCommit = (Get-Content -LiteralPath $baseCommitFile -Raw).Trim()
if ($expectedCommit -notmatch '^[0-9a-fA-F]{40}$') {
    throw "UPSTREAM-COMMIT.txt debe contener un SHA completo de 40 caracteres."
}
if (-not (Test-Path -LiteralPath $canonicalPatch)) {
    throw "Falta el parche canónico: $canonicalPatch"
}

# Version del paquete NuGet Siemens.Collaboration.Net.TiaPortal.Packages.Openness
# por cada major de TIA. Comprobado contra nuget.org el 2026-09-14.
$opennessPackage = @{
    19 = '19.0.1725520202'
    20 = '20.0.1744190253'
    21 = '21.0.1765349347'
}

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }

# PowerShell 5.1 convierte cualquier stderr de un .exe en un error terminante
# cuando ErrorActionPreference es Stop, aunque el exe devuelva 0. git y dotnet
# escriben progreso en stderr, asi que hay que aislarlos.
function Invoke-Native {
    param([string]$What, [scriptblock]$Block)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try   { & $Block 2>&1 | ForEach-Object { "$_" } }
    finally { $ErrorActionPreference = $prev }
    if ($LASTEXITCODE -ne 0) { throw "$What fallo (exit $LASTEXITCODE)" }
}

function Test-GitPatchState {
    param([string[]]$GitArguments)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& git @GitArguments 2>&1 | ForEach-Object { "$_" })
        $exitCode = $LASTEXITCODE
        return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

# --- dotnet ---------------------------------------------------------------
$dotnet = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
if (-not (Test-Path $dotnet)) {
    throw "No se encuentra dotnet en '$dotnet'. Instalalo con: winget install Microsoft.DotNet.SDK.10"
}

# --- clonar o actualizar --------------------------------------------------
if (-not (Test-Path $upstream)) {
    Write-Step "Clonando $repoUrl sin checkout"
    Invoke-Native "git clone" { git clone --no-checkout $repoUrl $upstream }
    Write-Step "Fijando upstream en $expectedCommit"
    Invoke-Native "git checkout del commit fijado" { git -C $upstream checkout --detach $expectedCommit }
} else {
    Write-Step "upstream/ ya existe; se conserva su estado de trabajo"
}

$actualCommit = (git -C $upstream rev-parse HEAD).Trim()
if ($actualCommit -ne $expectedCommit) {
    throw "El upstream está en $actualCommit y el parche se validó contra $expectedCommit. No se cambió el árbol; revisa el upstream manualmente."
}
Write-Ok "commit fijado $actualCommit"

# --- aplicar parche -------------------------------------------------------
$reverseCheck = Test-GitPatchState @('-C', $upstream, 'apply', '--reverse', '--check', '--ignore-whitespace', $canonicalPatch)
if ($reverseCheck.ExitCode -eq 0) {
    Write-Ok "$(Split-Path $canonicalPatch -Leaf) ya aplicado"
} else {
    $check = Test-GitPatchState @('-C', $upstream, 'apply', '--check', '--ignore-whitespace', $canonicalPatch)
    if ($check.ExitCode -ne 0) {
        $detail = @($reverseCheck.Output + $check.Output) -join [Environment]::NewLine
        throw "El parche canónico no está aplicado y tampoco encaja en el commit fijado. No se modificó upstream. $detail"
    }

    Write-Step "Aplicando $(Split-Path $canonicalPatch -Leaf)"
    Invoke-Native "git apply" { git -C $upstream apply --ignore-whitespace $canonicalPatch }
    Write-Ok "parche aplicado"
}

# --- compilar -------------------------------------------------------------
$outDir = Join-Path $root "bin\v$TiaMajor"
$pkg = $opennessPackage[$TiaMajor]
Write-Step "Compilando para TIA V$TiaMajor (paquete Openness $pkg)"

if ($Clean) {
    Write-Step "Limpiando artefactos de compilacion (sin borrar upstream)"
    Invoke-Native "dotnet clean" {
        & $dotnet clean (Join-Path $upstream 'src\TiaMcpServer\TiaMcpServer.csproj') -c Release -p:TiaMajor=$TiaMajor -p:OpennessPackageVersion=$pkg --nologo
    }
}

Invoke-Native "dotnet build" {
    & $dotnet build (Join-Path $upstream 'src\TiaMcpServer\TiaMcpServer.csproj') -c Release -p:TiaMajor=$TiaMajor -p:OpennessPackageVersion=$pkg --nologo
}

# --- publicar el resultado ------------------------------------------------
$built = Join-Path $upstream 'src\TiaMcpServer\bin\Release\net48'
if (-not (Test-Path (Join-Path $built 'TiaMcpServer.exe'))) {
    throw "Compilo pero no encuentro TiaMcpServer.exe en $built"
}
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Copy-Item (Join-Path $built '*') $outDir -Recurse -Force
Write-Ok "binarios en $outDir"

# --- verificar ------------------------------------------------------------
Write-Step "Verificando con --doctor"
& (Join-Path $outDir 'TiaMcpServer.exe') --tia-major-version $TiaMajor --doctor

Write-Host ""
Write-Host "Listo. Registra este comando en tu cliente MCP:" -ForegroundColor Yellow
Write-Host "  $outDir\TiaMcpServer.exe --tia-major-version $TiaMajor" -ForegroundColor Yellow
