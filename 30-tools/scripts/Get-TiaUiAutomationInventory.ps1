<#
.SYNOPSIS
    Captures a read-only Windows UI Automation inventory for one explicitly identified TIA/PLCSIM window.

.DESCRIPTION
    This is a discovery helper, not a desktop controller. It never activates a window, moves focus,
    clicks, types, invokes a UI pattern, or changes the application. The caller must supply the live
    process ID and a distinctive expected window-title fragment. Ambiguous or stale window identity
    fails closed. The output records semantic properties and supported patterns, but never reads
    ValuePattern contents.
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateRange(1, 2147483647)]
    [int]$ProcessId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ExpectedTitleContains,

    [string]$OutputPath,

    [ValidateRange(0, 12)]
    [int]$MaxDepth = 5,

    [ValidateRange(1, 5000)]
    [int]$MaxNodes = 800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Windows UI Automation is available only on Windows.'
}

try {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
} catch {
    throw "Could not load the Windows UI Automation assemblies in this PowerShell runtime: $($_.Exception.Message)"
}

$process = Get-Process -Id $ProcessId -ErrorAction Stop
$processPath = $null
try { $processPath = $process.Path } catch { }

$topLevel = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
    [System.Windows.Automation.TreeScope]::Children,
    [System.Windows.Automation.Condition]::TrueCondition
)
$matches = [System.Collections.Generic.List[object]]::new()
foreach ($candidate in $topLevel) {
    try {
        $current = $candidate.Current
        if ($current.ProcessId -eq $ProcessId -and
            $current.Name.IndexOf($ExpectedTitleContains, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $matches.Add($candidate)
        }
    } catch {
        # A window can disappear between enumeration and property access. It cannot be selected on stale data.
    }
}

if ($matches.Count -ne 1) {
    throw "Expected exactly one top-level window for PID $ProcessId containing title '$ExpectedTitleContains'; found $($matches.Count). Refresh the window inventory and retry with the current PID/title."
}

$window = $matches[0]
$windowCurrent = $window.Current
$patternSpecs = [ordered]@{
    Invoke        = [System.Windows.Automation.InvokePattern]::Pattern
    SelectionItem = [System.Windows.Automation.SelectionItemPattern]::Pattern
    ExpandCollapse = [System.Windows.Automation.ExpandCollapsePattern]::Pattern
    Value         = [System.Windows.Automation.ValuePattern]::Pattern
    Toggle        = [System.Windows.Automation.TogglePattern]::Pattern
    Window        = [System.Windows.Automation.WindowPattern]::Pattern
}

function Get-SupportedPatternNames([System.Windows.Automation.AutomationElement]$Element) {
    $supported = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $patternSpecs.GetEnumerator()) {
        $pattern = $null
        try {
            if ($Element.TryGetCurrentPattern($entry.Value, [ref]$pattern)) { $supported.Add([string]$entry.Key) }
        } catch { }
    }
    @($supported)
}

$nodes = [System.Collections.Generic.List[object]]::new()
$pending = [System.Collections.Generic.Queue[object]]::new()
$pending.Enqueue([pscustomobject]@{ Element = $window; Depth = 0; ParentIndex = $null })
$truncated = $false

while ($pending.Count -gt 0) {
    if ($nodes.Count -ge $MaxNodes) { $truncated = $true; break }
    $item = $pending.Dequeue()
    try {
        $current = $item.Element.Current
        $bounds = $current.BoundingRectangle
        $index = $nodes.Count
        $nodes.Add([ordered]@{
            index = $index
            parentIndex = $item.ParentIndex
            depth = $item.Depth
            name = [string]$current.Name
            automationId = [string]$current.AutomationId
            controlType = [string]$current.ControlType.ProgrammaticName
            className = [string]$current.ClassName
            isEnabled = [bool]$current.IsEnabled
            isOffscreen = [bool]$current.IsOffscreen
            bounds = [ordered]@{ x = $bounds.X; y = $bounds.Y; width = $bounds.Width; height = $bounds.Height }
            supportedPatterns = @(Get-SupportedPatternNames $item.Element)
        })
    } catch {
        $index = $nodes.Count
        $nodes.Add([ordered]@{ index = $index; parentIndex = $item.ParentIndex; depth = $item.Depth; readError = $_.Exception.Message })
    }

    if ($item.Depth -ge $MaxDepth) { continue }
    try {
        $children = $item.Element.FindAll(
            [System.Windows.Automation.TreeScope]::Children,
            [System.Windows.Automation.Condition]::TrueCondition
        )
        foreach ($child in $children) {
            if ($nodes.Count + $pending.Count -ge $MaxNodes) { $truncated = $true; break }
            $pending.Enqueue([pscustomobject]@{ Element = $child; Depth = $item.Depth + 1; ParentIndex = $index })
        }
    } catch {
        # Some third-party controls do not expose child enumeration; keep the readable parent node.
    }
}

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $stamp = [DateTimeOffset]::Now.ToString('yyyyMMdd-HHmmss')
    $OutputPath = Join-Path $workspaceRoot "70-runs\environment\uia-inventory-$ProcessId-$stamp.json"
}
if (-not [IO.Path]::IsPathRooted($OutputPath)) { $OutputPath = Join-Path $workspaceRoot $OutputPath }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$report = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    readOnly = $true
    application = [ordered]@{ processId = $ProcessId; processName = $process.ProcessName; executablePath = $processPath }
    window = [ordered]@{ title = [string]$windowCurrent.Name; nativeHandle = [int64]$windowCurrent.NativeWindowHandle; isEnabled = [bool]$windowCurrent.IsEnabled }
    query = [ordered]@{ expectedTitleContains = $ExpectedTitleContains; maxDepth = $MaxDepth; maxNodes = $MaxNodes }
    truncated = $truncated
    nodes = @($nodes)
}

$temporaryPath = "$OutputPath.pending"
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
Move-Item -LiteralPath $temporaryPath -Destination $OutputPath -Force
Write-Output "Read-only UIA inventory written: $OutputPath"
Write-Output "Window: $($windowCurrent.Name); controls: $($nodes.Count); truncated: $truncated"
