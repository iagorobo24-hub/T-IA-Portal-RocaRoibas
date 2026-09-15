[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DestinationRoot = 'C:\TIA-Claude',
    [Parameter(Mandatory = $false)]
    [ValidateSet(20)]
    [int]$TiaMajor = 20,
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $packageRoot 'workspace'
$destinationRoot = [IO.Path]::GetFullPath($DestinationRoot)

if (-not (Test-Path -LiteralPath $sourceRoot)) {
    throw "No existe el workspace del paquete: $sourceRoot"
}

 $destinationHasContent = (Test-Path -LiteralPath $destinationRoot) -and @((Get-ChildItem -LiteralPath $destinationRoot -Force -ErrorAction SilentlyContinue)).Count -gt 0
if ($destinationHasContent -and -not $Update) {
    throw "La carpeta destino ya existe. Usa -Update explícitamente para actualizarla: $destinationRoot"
}

New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null
& robocopy $sourceRoot $destinationRoot /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NP | Out-Null
if ($LASTEXITCODE -gt 7) {
    throw "Robocopy terminó con código $LASTEXITCODE"
}

$serverPath = Join-Path $destinationRoot "30-tools\mcp\tia-inspect\bin\v$tiaMajor\TiaMcpServer.exe"
if (-not (Test-Path -LiteralPath $serverPath)) {
    throw "No existe el binario tia-inspect para V${tiaMajor}: $serverPath"
}

$config = [ordered]@{
    mcpServers = [ordered]@{
        'tia-inspect' = [ordered]@{
            command = $serverPath
            args = @('--tia-major-version', [string]$TiaMajor)
        }
    }
}
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $destinationRoot '.mcp.json') -Encoding UTF8
$localManifest = [ordered]@{
    schemaVersion = 1
    profile = 'read'
    tiaMajor = $TiaMajor
    servers = [ordered]@{
        'tia-inspect' = [ordered]@{
            command = $serverPath
            args = @('--tia-major-version', [string]$TiaMajor)
        }
    }
}
$localManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $destinationRoot '30-tools\mcp\servers.local.json') -Encoding UTF8

Write-Output "Workspace instalado en $destinationRoot"
Write-Output "MCP read-only generado para TIA V$tiaMajor"
Write-Output "Siguiente paso: .\Verify-TIA-Claude.ps1 -WorkspaceRoot '$destinationRoot' -RunDoctor"
$global:LASTEXITCODE = 0
