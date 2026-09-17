<#
.SYNOPSIS
    Clona y compila el servidor MCP tia-create (bulaofen0036-coder/TIA_Portal_Openness_MCP)
    contra la version de Openness instalada en esta maquina.

.DESCRIPTION
    El upstream trae dos proyectos separados, no intercambiables (README del repo, seccion
    "Dual-version support"):
      - TiaMcpServer.csproj      -> TIA V21 (paquete Openness 21.0.x), salida en bin\Release\net48
      - TiaMcpServer.V20.csproj  -> TIA V20 (paquete Openness 20.0.x), salida en bin-v20\Release\net48

    El binario V20 instalado en este workspace (30-tools/mcp/tia-create/bin/v20) se genero a mano
    desde el ZIP de release 2.7.2, no con este script. Este script reproduce el mismo resultado
    desde fuente y añade la rama V21 sin haberla podido verificar en esta maquina: aqui solo hay
    V19/V20 instalados. Un companero con TIA V21 debe ejecutar `-TiaMajor 21` y contrastar contra
    `--doctor` antes de dar la rama V21 por buena. Ver
    00-meta/decisiones/ADR-014-version-v21.md.

.PARAMETER TiaMajor
    20 (por defecto, verificado en esta maquina) o 21 (documentado desde el README upstream,
    sin verificar aqui).

.EXAMPLE
    .\build.ps1                 # compila para TIA V20
    .\build.ps1 -TiaMajor 21    # compila para TIA V21 -- solo en una maquina con V21 instalado
    .\build.ps1 -Clean          # borra upstream/ y vuelve a empezar
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
$repoUrl = 'https://github.com/bulaofen0036-coder/TIA_Portal_Openness_MCP.git'
# Commit fijado en TIA-Claude_Portable/manifests/repositories.json (name: tia-create-reference).
# Si lo actualizas aqui, actualiza tambien ese manifest.
$pinnedCommit = '218e829df3f056b653d7831c60a6297818db72fd'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }

function Invoke-Native {
    param([string]$What, [scriptblock]$Block)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try   { & $Block 2>&1 | ForEach-Object { "$_" } }
    finally { $ErrorActionPreference = $prev }
    if ($LASTEXITCODE -ne 0) { throw "$What fallo (exit $LASTEXITCODE)" }
}

$dotnet = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
if (-not (Test-Path $dotnet)) {
    throw "No se encuentra dotnet en '$dotnet'. Instalalo con: winget install Microsoft.DotNet.SDK.10"
}

if ($Clean -and (Test-Path $upstream)) {
    Write-Step "Borrando upstream/"
    Remove-Item $upstream -Recurse -Force
}

if (-not (Test-Path $upstream)) {
    Write-Step "Clonando $repoUrl"
    Invoke-Native "git clone" { git clone $repoUrl $upstream }
    Write-Step "Fijando commit $pinnedCommit"
    Invoke-Native "git checkout" { git -C $upstream checkout $pinnedCommit }
} else {
    Write-Step "upstream/ ya existe, revirtiendo cambios locales"
    Invoke-Native "git checkout" { git -C $upstream checkout -- . }
}
$actualCommit = (git -C $upstream rev-parse HEAD)
if ($actualCommit -ne $pinnedCommit) {
    Write-Host "AVISO: upstream esta en $actualCommit, no en el commit fijado $pinnedCommit." -ForegroundColor Yellow
    Write-Host "       Ejecuta con -Clean para volver a clonar el commit exacto." -ForegroundColor Yellow
}
Write-Ok ("commit " + $actualCommit.Substring(0, 7))

$srcDir = Join-Path $upstream 'tools\tiaportal-mcp\src\TiaMcpServer'
if ($TiaMajor -eq 20) {
    $csproj = Join-Path $srcDir 'TiaMcpServer.V20.csproj'
    $built = Join-Path $srcDir 'bin-v20\Release\net48'
} else {
    $csproj = Join-Path $srcDir 'TiaMcpServer.csproj'
    $built = Join-Path $srcDir 'bin\Release\net48'
}
if (-not (Test-Path -LiteralPath $csproj)) {
    throw "No encuentro $csproj. El upstream ha podido reestructurarse; revisa tools/tiaportal-mcp/src/TiaMcpServer en $upstream."
}

$outDir = Join-Path $root "bin\v$TiaMajor"
Write-Step "Compilando para TIA V$TiaMajor ($(Split-Path $csproj -Leaf))"
Invoke-Native "dotnet build" {
    & $dotnet build $csproj -c Release --nologo
}

if (-not (Test-Path (Join-Path $built 'TiaMcpServer.exe'))) {
    throw "Compilo pero no encuentro TiaMcpServer.exe en $built"
}
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Copy-Item (Join-Path $built '*') $outDir -Recurse -Force
Write-Ok "binarios en $outDir"

Write-Step "Verificando con --doctor"
& (Join-Path $outDir 'TiaMcpServer.exe') --tia-major-version $TiaMajor --doctor

Write-Host ""
Write-Host "Listo. Registra este comando en tu cliente MCP (perfil create/full):" -ForegroundColor Yellow
Write-Host "  $outDir\TiaMcpServer.exe --tia-major-version $TiaMajor --profile lite" -ForegroundColor Yellow
if ($TiaMajor -eq 21) {
    Write-Host ""
    Write-Host "Rama V21 sin verificar contra un proyecto real todavia. Antes de fiarte:" -ForegroundColor Yellow
    Write-Host "  1. Confirma que --doctor de arriba dio V21 Engineering/Portal OK." -ForegroundColor Yellow
    Write-Host "  2. Corre un scaffold desechable (ver 30-tools/scripts/Invoke-AgentDemoScaffold.ps1)." -ForegroundColor Yellow
    Write-Host "  3. Actualiza 00-meta/decisiones/ADR-014-version-v21.md con la evidencia real." -ForegroundColor Yellow
}
