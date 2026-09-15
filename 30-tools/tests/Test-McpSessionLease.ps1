[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$runner = Join-Path $WorkspaceRoot '30-tools\scripts\Invoke-McpToolSequence.ps1'
$server = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
$leaseName = 'Local\TIA-Claude-TestLease-' + [guid]::NewGuid().ToString('N')
$pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
$holderCode = '$created = $false; $m = [Threading.Mutex]::new($false, "' + $leaseName + '", [ref]$created); if (-not $m.WaitOne(0)) { exit 2 }; [Console]::WriteLine("ready"); [Console]::ReadLine(); $m.ReleaseMutex(); $m.Dispose()'
$holderPsi = [Diagnostics.ProcessStartInfo]::new()
$holderPsi.FileName = $pwsh
$holderPsi.UseShellExecute = $false
$holderPsi.CreateNoWindow = $true
$holderPsi.RedirectStandardInput = $true
$holderPsi.RedirectStandardOutput = $true
$holderPsi.ArgumentList.Add('-NoProfile')
$holderPsi.ArgumentList.Add('-NonInteractive')
$holderPsi.ArgumentList.Add('-Command')
$holderPsi.ArgumentList.Add($holderCode)
$holder = $null
try {
    if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) { throw 'MCP sequence runner is missing.' }
    if (-not (Test-Path -LiteralPath $server -PathType Leaf)) { throw 'tia-create V20 runtime is missing.' }
    $holder = [Diagnostics.Process]::Start($holderPsi)
    $ready = $holder.StandardOutput.ReadLine()
    if ($ready -ne 'ready') { throw 'Lease holder did not acquire its mutex.' }

    $caught = $null
    try {
        & $runner -ExecutablePath $server -Arguments '--tia-major-version 20 --profile lite' `
            -Calls @(@{ name = 'Bootstrap'; args = @{} }) -LeaseName $leaseName -LeaseTimeoutSeconds 1 | Out-Null
    }
    catch {
        $caught = $_
    }
    if ($null -eq $caught -or $caught.Exception.Message -notmatch 'Could not acquire MCP/TIA session lease') {
        throw 'A second MCP sequence was not blocked by the active lease.'
    }
    Write-Output 'PASS: MCP/TIA session lease blocks concurrent sequences and releases deterministically'
}
finally {
    if ($holder) {
        try { $holder.StandardInput.WriteLine('release'); $holder.StandardInput.Flush() } catch { }
        if (-not $holder.WaitForExit(5000)) { try { $holder.Kill() } catch { } }
        $holder.Dispose()
    }
}
