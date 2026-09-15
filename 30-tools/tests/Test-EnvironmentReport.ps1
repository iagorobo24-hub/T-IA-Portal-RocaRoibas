[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Write-TiaEnvironmentReport.ps1'
$tempRoot = Join-Path $env:TEMP ('tia-claude-test-' + [guid]::NewGuid().ToString('N'))
$outputPath = Join-Path $tempRoot 'environment.json'

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Expected script does not exist: $scriptPath"
    }

    & $scriptPath -WorkspaceRoot $WorkspaceRoot -OutputPath $outputPath -SkipDoctor

    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "Environment report was not created: $outputPath"
    }

    $report = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    foreach ($property in @('generatedAt', 'workspaceRoot', 'tiaMajor', 'installedTia', 'mcpServers', 'runtimeAdvanced')) {
        if (-not ($report.PSObject.Properties.Name -contains $property)) {
            throw "Environment report is missing property '$property'."
        }
    }

    Write-Output 'PASS: environment report contract'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
