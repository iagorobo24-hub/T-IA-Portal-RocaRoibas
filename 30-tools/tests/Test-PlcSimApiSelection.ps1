[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$resolver = Join-Path $WorkspaceRoot '30-tools\plcsim\Resolve-PlcSimApi.ps1'
if (-not (Test-Path -LiteralPath $resolver -PathType Leaf)) { throw 'PLCSIM API resolver is missing.' }

$tempRoot = Join-Path $env:TEMP ('tia-claude-plcsim-api-selection-' + [guid]::NewGuid().ToString('N'))
$apiRoot = Join-Path $tempRoot 'API'
try {
    foreach ($item in @(@{ version='6.0'; interface='00060000' }, @{ version='7.0'; interface='00070000' })) {
        $directory = Join-Path $apiRoot $item.version
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $directory 'SimulationRuntimeApi.h') -Value "#define DAPI_DLL_INTERFACE_VERSION 0x$($item.interface)" -Encoding ASCII
        Set-Content -LiteralPath (Join-Path $directory 'Siemens.Simatic.Simulation.Runtime.Api.x64.dll') -Value 'fixture' -Encoding ASCII
    }

    . $resolver
    $latest = Get-TiaPlcSimApiInstallation -ApiRoot $apiRoot
    if (-not $latest -or $latest.Version -ne '7.0' -or $latest.InterfaceVersionHex -ne '0x00070000') {
        throw 'Default API selection did not choose the highest complete API and its declared interface version.'
    }
    $exact = Get-TiaPlcSimApiInstallation -ApiRoot $apiRoot -ApiVersion '6.0'
    if (-not $exact -or $exact.Version -ne '6.0' -or $exact.InterfaceVersionHex -ne '0x00060000') {
        throw 'Explicit API selection did not return the requested version/interface.'
    }
    if (Get-TiaPlcSimApiInstallation -ApiRoot $apiRoot -ApiVersion '9.0') {
        throw 'Missing explicit API version should return no selection.'
    }
    Write-Output 'PASS: PLCSIM API selection chooses latest matching header/DLL and honors explicit versions'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
