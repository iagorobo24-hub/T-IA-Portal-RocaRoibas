function Get-TiaPlcSimApiInstallation {
    [CmdletBinding()]
    param(
        [string]$ApiRoot = (Join-Path ${env:CommonProgramFiles(x86)} 'Siemens\PLCSIMADV\API'),
        [string]$ApiVersion
    )

    if (-not (Test-Path -LiteralPath $ApiRoot -PathType Container)) { return $null }

    $candidates = foreach ($directory in Get-ChildItem -LiteralPath $ApiRoot -Directory) {
        $version = $null
        if (-not [version]::TryParse($directory.Name, [ref]$version)) { continue }
        if ($ApiVersion -and $directory.Name -ne $ApiVersion) { continue }

        $header = Join-Path $directory.FullName 'SimulationRuntimeApi.h'
        $dll = Join-Path $directory.FullName 'Siemens.Simatic.Simulation.Runtime.Api.x64.dll'
        if (-not (Test-Path -LiteralPath $header -PathType Leaf) -or -not (Test-Path -LiteralPath $dll -PathType Leaf)) { continue }

        $headerText = Get-Content -Raw -LiteralPath $header
        $match = [regex]::Match($headerText, '(?m)^\s*#define\s+DAPI_DLL_INTERFACE_VERSION\s+0x([0-9A-Fa-f]{8})\b')
        if (-not $match.Success) { continue }

        [pscustomobject]@{
            Version = $directory.Name
            VersionObject = $version
            Major = $version.Major
            ApiRoot = $directory.FullName
            HeaderPath = $header
            DllPath = $dll
            InterfaceVersion = [Convert]::ToUInt32($match.Groups[1].Value, 16)
            InterfaceVersionHex = '0x' + $match.Groups[1].Value.ToUpperInvariant()
        }
    }

    if (-not $candidates) { return $null }
    $candidates | Sort-Object VersionObject -Descending | Select-Object -First 1
}
