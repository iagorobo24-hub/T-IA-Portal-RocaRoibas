[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $WorkspaceRoot '30-tools\scripts\Export-HarnessAdapter.ps1'
$tempRoot = Join-Path $env:TEMP ('tia-claude-adapter-test-' + [guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "Adapter exporter missing: $scriptPath" }

    $claudePath = Join-Path $tempRoot 'claude.json'
    & $scriptPath -WorkspaceRoot $WorkspaceRoot -Harness claude-code -Profile read -OutputPath $claudePath
    $claude = Get-Content -Raw -LiteralPath $claudePath | ConvertFrom-Json
    if ($null -eq $claude.mcpServers.'tia-inspect') { throw 'Claude adapter lacks tia-inspect.' }
    if (@($claude.mcpServers.'tia-inspect'.args) -contains '--allow-write') { throw 'Claude read adapter is writable.' }

    $codexPath = Join-Path $tempRoot 'codex.toml'
    & $scriptPath -WorkspaceRoot $WorkspaceRoot -Harness codex -Profile read -OutputPath $codexPath
    $codex = Get-Content -Raw -LiteralPath $codexPath
    if ($codex -notmatch '\[mcp_servers\.tia-inspect\]') { throw 'Codex adapter section missing.' }
    if ($codex -notmatch 'startup_timeout_sec\s*=\s*120') { throw 'Codex startup timeout missing.' }
    if ($codex -match '--allow-write') { throw 'Codex read adapter is writable.' }

    $openCodePath = Join-Path $tempRoot 'opencode.json'
    & $scriptPath -WorkspaceRoot $WorkspaceRoot -Harness opencode -Profile create -AcknowledgeWriteProfile -OutputPath $openCodePath
    $openCode = Get-Content -Raw -LiteralPath $openCodePath | ConvertFrom-Json
    if ($null -eq $openCode.mcp.'tia-create') { throw 'OpenCode create adapter lacks tia-create.' }
    if ($openCode.mcp.'tia-create'.type -ne 'local') { throw 'OpenCode adapter must use local MCP.' }
    if (@($openCode.mcp.'tia-create'.command) -notcontains '--profile') { throw 'OpenCode command must pin lite profile.' }

    $genericPath = Join-Path $tempRoot 'generic.json'
    & $scriptPath -WorkspaceRoot $WorkspaceRoot -Harness generic -Profile read -OutputPath $genericPath
    $generic = Get-Content -Raw -LiteralPath $genericPath | ConvertFrom-Json
    if ($null -eq $generic.mcpServers.'tia-inspect') { throw 'Generic MCP adapter lacks tia-inspect.' }
    if (@($generic.mcpServers.'tia-inspect'.args) -contains '--allow-write') { throw 'Generic read adapter is writable.' }

    $writePath = Join-Path $tempRoot 'write.json'
    & pwsh -NoProfile -NonInteractive -File $scriptPath -WorkspaceRoot $WorkspaceRoot -Harness claude-code -Profile write -OutputPath $writePath 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Write adapter was generated without acknowledgement.' }

    Write-Output 'PASS: Claude Code, Codex, OpenCode and generic MCP adapter formats are deterministic'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
