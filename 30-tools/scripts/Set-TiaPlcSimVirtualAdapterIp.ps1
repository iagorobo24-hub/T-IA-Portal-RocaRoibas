[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetIpAddress,
    [Parameter(Mandatory = $true)]
    [string]$VirtualAdapterIpAddress,
    [ValidateRange(1, 30)]
    [int]$PrefixLength = 24,
    [string]$StatePath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path '70-runs\environment\plcsim-virtual-adapter-state.json'),
    [switch]$Apply,
    [switch]$Restore,
    [switch]$AcknowledgeLocalOnly
)

$ErrorActionPreference = 'Stop'
if ($Apply -and $Restore) { throw 'Use -Apply or -Restore, not both.' }
if ($Apply -and -not $AcknowledgeLocalOnly) { throw 'For -Apply, pass -AcknowledgeLocalOnly only after PLCSIM is configured as local-only (<Local>).'}

function ConvertTo-IPv4UInt32([Net.IPAddress]$Address) {
    $bytes = $Address.GetAddressBytes()
    if ($Address.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'Only IPv4 is supported.' }
    [uint64]$value = 0
    foreach ($byte in $bytes) { $value = ($value * 256) + [uint64]$byte }
    return $value
}

function Test-SameSubnet([Net.IPAddress]$A, [Net.IPAddress]$B, [int]$Prefix) {
    $blockSize = [Math]::Pow(2, 32 - $Prefix)
    return [Math]::Floor((ConvertTo-IPv4UInt32 $A) / $blockSize) -eq [Math]::Floor((ConvertTo-IPv4UInt32 $B) / $blockSize)
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SiemensAdapter {
    $matches = @(Get-NetAdapter -IncludeHidden -ErrorAction Stop | Where-Object {
        $_.InterfaceDescription -ceq 'Siemens PLCSIM Virtual Ethernet Adapter'
    })
    if ($matches.Count -ne 1) { throw "Expected exactly one Siemens PLCSIM Virtual Ethernet Adapter; found $($matches.Count)." }
    $matches[0]
}

function Get-IPv4Addresses([int]$InterfaceIndex) {
    @(Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue)
}

$adapter = Get-SiemensAdapter
if ($adapter.Status -ne 'Up') { throw "The Siemens virtual adapter is not Up (status=$($adapter.Status))." }
$stateFullPath = [IO.Path]::GetFullPath($StatePath)

if ($Restore) {
    if (-not (Test-Path -LiteralPath $stateFullPath -PathType Leaf)) { throw "No saved adapter state exists at '$stateFullPath'." }
    if (-not (Test-Administrator)) { throw 'Restore requires an elevated PowerShell session.' }
    $saved = Get-Content -Raw -LiteralPath $stateFullPath | ConvertFrom-Json
    if ($saved.interfaceDescription -cne $adapter.InterfaceDescription -or [int]$saved.ifIndex -ne [int]$adapter.ifIndex) {
        throw 'The saved adapter identity no longer matches the live Siemens adapter; refusing restoration.'
    }
    $assigned = [Net.IPAddress]::Parse([string]$saved.assignedIp)
    if ($PSCmdlet.ShouldProcess($adapter.Name, "Remove $assigned/$($saved.prefixLength) and restore DHCP=$($saved.dhcpEnabled)")) {
        $current = @(Get-IPv4Addresses -InterfaceIndex $adapter.ifIndex | Where-Object IPAddress -eq $assigned.IPAddressToString)
        if ($current.Count -gt 0) { $current | Remove-NetIPAddress -Confirm:$false -ErrorAction Stop }
        Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -Dhcp ([string]$saved.dhcpEnabled) -ErrorAction Stop
        $verifiedDhcp = (Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4).Dhcp
        if ([string]$verifiedDhcp -ne [string]$saved.dhcpEnabled) { throw 'DHCP mode did not read back as its saved value.' }
    }
    [pscustomobject]@{ status = 'restored'; adapter = $adapter.Name; dhcp = [string]$saved.dhcpEnabled; removedAddress = $assigned.IPAddressToString; statePath = $stateFullPath } | ConvertTo-Json -Compress
    return
}

$target = $null
$hostAddress = $null
if (-not [Net.IPAddress]::TryParse($TargetIpAddress, [ref]$target) -or $target.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw "TargetIpAddress is not a valid IPv4 address: '$TargetIpAddress'." }
if (-not [Net.IPAddress]::TryParse($VirtualAdapterIpAddress, [ref]$hostAddress) -or $hostAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw "VirtualAdapterIpAddress is not a valid IPv4 address: '$VirtualAdapterIpAddress'." }
if (-not (Test-SameSubnet $target $hostAddress $PrefixLength)) { throw "The virtual adapter address must be in the target PLC subnet ($TargetIpAddress/$PrefixLength)." }
if ($target.IPAddressToString -eq $hostAddress.IPAddressToString) { throw 'The virtual adapter IP and PLC instance IP must differ.' }

$otherSameSubnetAddresses = @(
    Get-NetAdapter -IncludeHidden -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' -and $_.ifIndex -ne $adapter.ifIndex } |
        ForEach-Object {
            $other = $_
            Get-IPv4Addresses -InterfaceIndex $other.ifIndex | ForEach-Object {
                $parsed = [Net.IPAddress]::Parse([string]$_.IPAddress)
                if (Test-SameSubnet $parsed $target $PrefixLength) {
                    [pscustomobject]@{ interface = $other.Name; description = $other.InterfaceDescription; ip = $parsed.IPAddressToString }
                }
            }
        }
)
if ($otherSameSubnetAddresses.Count -gt 0) {
    throw "Another active Windows adapter is already configured in the simulated PLC subnet; local-only route cannot be proven: $($otherSameSubnetAddresses | ConvertTo-Json -Compress)."
}

$currentAddresses = @(Get-IPv4Addresses -InterfaceIndex $adapter.ifIndex)
$existingTarget = @($currentAddresses | Where-Object IPAddress -eq $hostAddress.IPAddressToString)
$otherManual = @($currentAddresses | Where-Object { $_.PrefixOrigin -eq 'Manual' -and $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne $hostAddress.IPAddressToString })
if ($otherManual.Count -gt 0) { throw 'The Siemens adapter already has a different manual IPv4 address; inspect it before changing anything.' }
$ipInterface = Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4
$savedState = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    interfaceDescription = $adapter.InterfaceDescription
    interfaceAlias = $adapter.Name
    ifIndex = $adapter.ifIndex
    dhcpEnabled = [string]$ipInterface.Dhcp
    previousAddresses = @($currentAddresses | ForEach-Object { [ordered]@{ ip = $_.IPAddress; prefixLength = $_.PrefixLength; prefixOrigin = [string]$_.PrefixOrigin; suffixOrigin = [string]$_.SuffixOrigin } })
    assignedIp = $hostAddress.IPAddressToString
    prefixLength = $PrefixLength
    plcTargetIp = $target.IPAddressToString
    otherSameSubnetAdapters = @()
}

if ($Apply) {
    if (-not (Test-Administrator)) { throw 'Apply requires an elevated PowerShell session. No adapter settings were changed.' }
    $hasUnexpectedManualAddress = @($currentAddresses | Where-Object { $_.PrefixOrigin -eq 'Manual' -and $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne $hostAddress.IPAddressToString }).Count -gt 0
    if ($hasUnexpectedManualAddress) { throw 'The adapter has a manual address not created by this procedure; refusing to replace it.' }
    if ($PSCmdlet.ShouldProcess($adapter.Name, "Assign $($hostAddress.IPAddressToString)/$PrefixLength for local PLCSIM target $($target.IPAddressToString)")) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $stateFullPath) -Force | Out-Null
        $savedState | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $stateFullPath -Encoding UTF8
        Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -Dhcp Disabled -ErrorAction Stop
        if ($existingTarget.Count -eq 0) {
            New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $hostAddress.IPAddressToString -PrefixLength $PrefixLength -AddressFamily IPv4 -ErrorAction Stop | Out-Null
        }
        $readback = @(Get-IPv4Addresses -InterfaceIndex $adapter.ifIndex | Where-Object { $_.IPAddress -eq $hostAddress.IPAddressToString -and $_.PrefixLength -eq $PrefixLength })
        if ($readback.Count -ne 1) { throw 'Static Siemens adapter IPv4 address failed readback. Saved state is available for -Restore.' }
    }
}

$currentAddresses = @(Get-IPv4Addresses -InterfaceIndex $adapter.ifIndex)
$hasAddress = @($currentAddresses | Where-Object { $_.IPAddress -eq $hostAddress.IPAddressToString -and $_.PrefixLength -eq $PrefixLength }).Count -eq 1
$status = if ($hasAddress) { 'ready' } else { 'preview-blocked-address-not-configured' }
[pscustomobject]@{
    status = $status
    mode = if ($Apply) { 'apply' } else { 'preview' }
    adapter = [ordered]@{ name = $adapter.Name; description = $adapter.InterfaceDescription; status = [string]$adapter.Status; ifIndex = $adapter.ifIndex; ipv4 = @($currentAddresses | ForEach-Object { "$($_.IPAddress)/$($_.PrefixLength)" }) }
    targetIpAddress = $target.IPAddressToString
    requiredAdapterAddress = "$($hostAddress.IPAddressToString)/$PrefixLength"
    localOnlyRoute = ($otherSameSubnetAddresses.Count -eq 0)
    otherSameSubnetAdapters = $otherSameSubnetAddresses
    administratorRequired = -not (Test-Administrator)
    statePath = if ($Apply -or $Restore) { $stateFullPath } else { $null }
} | ConvertTo-Json -Depth 10 -Compress
