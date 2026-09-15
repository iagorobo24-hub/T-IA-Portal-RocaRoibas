[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Inspect-McpToolSchemas.ps1'
$exe = Join-Path $WorkspaceRoot '30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe'
$outputPath = Join-Path $WorkspaceRoot ('90-tmp\mcp-schema-test-' + [guid]::NewGuid().ToString('N') + '.json')
foreach ($path in @($scriptPath, $exe)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing schema inspection input: $path" }
}

try {
    & $scriptPath `
        -ExecutablePath $exe `
        -Arguments '--tia-major-version 20 --profile full' `
        -ToolName CheckDownloadReadiness,DownloadToPlc,GetDeviceIpAddress,GetOnlineState,GetPlcTagTables,ExportPlcTagTable `
        -OutputPath $outputPath | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'MCP schema inspector failed.' }
    $report = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if ($report.readOnly -ne $true) { throw 'Schema report must be read-only.' }
    if ([int]$report.listedToolCount -lt 200) { throw "Expected full roster, got $($report.listedToolCount)." }
    if (@($report.missingRequestedTools).Count -ne 0) {
        throw "Required tools missing from full roster: $($report.missingRequestedTools -join ', ')"
    }
    $download = @($report.tools | Where-Object name -eq 'DownloadToPlc')[0]
    if (@($download.inputSchema.required) -notcontains 'softwarePath') { throw 'DownloadToPlc lost softwarePath requirement.' }
    if ($download.inputSchema.properties.keepActualValues.default -ne $true) { throw 'DownloadToPlc safe keepActualValues default changed.' }
    $readiness = @($report.tools | Where-Object name -eq 'CheckDownloadReadiness')[0]
    if (@($readiness.inputSchema.required) -notcontains 'softwarePath') { throw 'CheckDownloadReadiness lost softwarePath requirement.' }
    Write-Output "PASS: full MCP schema roster ($($report.listedToolCount) tools) and download safety contract"
}
finally {
    if (Test-Path -LiteralPath $outputPath) { Remove-Item -LiteralPath $outputPath -Force }
}
