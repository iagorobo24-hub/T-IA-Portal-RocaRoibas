[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$source = Join-Path $root '30-tools\plcsim\tia_claude_plcsim_adapter.cpp'
$readme = Join-Path $root '30-tools\plcsim\README.md'
foreach ($path in @($source, $readme)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing PLCSIM command protocol artifact: $path" }
}
$sourceText = Get-Content -Raw -LiteralPath $source
$readmeText = Get-Content -Raw -LiteralPath $readme
foreach ($command in @('read-bit', 'write-bit', 'read-byte', 'write-byte', 'read-area-size', 'read-bool-tag', 'write-bool-tag', 'read-uint8-tag', 'read-float-tag')) {
    if ($sourceText -notmatch [regex]::Escape($command)) { throw "Native adapter does not implement '$command'." }
    if ($readmeText -notmatch [regex]::Escape($command)) { throw "PLCSIM README does not document '$command'." }
}
Write-Output 'PASS: PLCSIM stdin command protocol is present and documented'
