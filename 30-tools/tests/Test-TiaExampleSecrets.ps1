[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\TiaExampleSecrets.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-example-secret-test-' + [guid]::NewGuid().ToString('N'))

try {
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw 'Secret scan helper is missing.' }
    . $script
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $fixture = Join-Path $temp 'fake-flow.json'
    $placeholder = Join-Path $temp 'safe-flow.json'
    $fakeJwt = 'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiJub25zZW5zZSJ9.signaturesegment0123456789'
    [ordered]@{ token = $fakeJwt } | ConvertTo-Json -Compress | Set-Content -LiteralPath $fixture -Encoding UTF8
    [ordered]@{ agentconfig = 'CONFIGURE_MINDCONNECT_AGENT_LOCALLY' } | ConvertTo-Json -Compress | Set-Content -LiteralPath $placeholder -Encoding UTF8

    $findings = @(Find-TiaExampleJwtLikeSecret -RootPath $temp)
    if ($findings.Count -ne 1) { throw "Expected one fake JWT finding, got $($findings.Count)." }
    if ([string]$findings[0].path -ne $fixture -or [string]$findings[0].finding -ne 'JWT-like credential') {
        throw 'Secret scanner returned the wrong path or finding type.'
    }
    if (($findings | ConvertTo-Json -Depth 5) -match [regex]::Escape($fakeJwt)) {
        throw 'Secret scanner included the token value in its report.'
    }

    Write-Output 'PASS: secret scanner detects a fake JWT and reports no credential value.'
}
finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedTemp = [IO.Path]::GetFullPath($temp)
    if ($resolvedTemp.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTemp)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
