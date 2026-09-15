<#
.SYNOPSIS
    Clona, parchea y compila el servidor MCP tia-inspect (heilingbrunner/tiaportal-mcp)
    contra la version de Openness instalada en esta maquina.

.DESCRIPTION
    Upstream targetea TIA V21. Esta maquina tiene V19 y V20, asi que hace falta:
      - fijar el paquete NuGet de Openness a la version correspondiente
      - parchear PlcWatchTable.Name (solo escribible desde V21)
      - bajar el suelo de deteccion de instalaciones de V21 a V19

    Los cambios viven en patches/0001-tia-v19-v20-compat.patch, no en un fork,
    para poder seguir haciendo `git pull` del upstream.

.PARAMETER TiaMajor
    20 (por defecto) o 21. V19 AUN NO esta soportado: la API de documentos
    SIMATIC SD (.s7dcl/.s7res) no existe antes de Openness V20 y habria que
    compilar fuera toda esa funcionalidad. Ver 00-meta/decisiones/ADR-002.

.EXAMPLE
    .\build.ps1                 # compila para TIA V20
    .\build.ps1 -TiaMajor 21    # compila para TIA V21
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
$repoUrl = 'https://github.com/heilingbrunner/tiaportal-mcp.git'

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

# --- dotnet ---------------------------------------------------------------
$dotnet = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
if (-not (Test-Path $dotnet)) {
    throw "No se encuentra dotnet en '$dotnet'. Instalalo con: winget install Microsoft.DotNet.SDK.10"
}

if ($Clean -and (Test-Path $upstream)) {
    Write-Step "Borrando upstream/"
    Remove-Item $upstream -Recurse -Force
}

# --- clonar o actualizar --------------------------------------------------
if (-not (Test-Path $upstream)) {
    Write-Step "Clonando $repoUrl"
    Invoke-Native "git clone" { git clone --depth 1 $repoUrl $upstream }
} else {
    Write-Step "upstream/ ya existe, revirtiendo cambios locales"
    Invoke-Native "git checkout" { git -C $upstream checkout -- . }
}
Write-Ok ("commit " + (git -C $upstream rev-parse --short HEAD))

# --- aplicar parche -------------------------------------------------------
$patch = Join-Path $root 'patches\0001-tia-v19-v20-compat.patch'
Write-Step "Aplicando $(Split-Path $patch -Leaf)"
try { Invoke-Native "git apply" { git -C $upstream apply --ignore-whitespace $patch } }
catch { throw "El parche no aplica limpio. Upstream ha cambiado: regeneralo contra el commit actual." }
Write-Ok "parche aplicado"

# --- compilar -------------------------------------------------------------
$outDir = Join-Path $root "bin\v$TiaMajor"
$pkg = $opennessPackage[$TiaMajor]
Write-Step "Compilando para TIA V$TiaMajor (paquete Openness $pkg)"

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
