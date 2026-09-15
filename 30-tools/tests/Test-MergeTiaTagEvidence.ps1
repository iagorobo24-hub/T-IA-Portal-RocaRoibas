[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root '30-tools\scripts\Merge-TiaTagEvidenceIntoInventory.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tia-claude-tag-merge-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    $basePath = Join-Path $temp 'base.json'
    $tagsPath = Join-Path $temp 'tags.json'
    $outputPath = Join-Path $temp 'merged.json'
    [ordered]@{
        schemaVersion = 1; readOnly = $true; projectPath = 'C:\fixture\Demo.ap20'
        plcs = @([ordered]@{ softwarePath = 'PLC_1'; name = 'PLC'; blocks = @(); summary = [ordered]@{ tagCount = 0 } })
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $basePath -Encoding UTF8
    [ordered]@{
        schemaVersion = 1; readOnly = $true; softwarePath = 'PLC_1'; generatedAt = 'now'
        source = [ordered]@{ format = 'fixture' }
        tagTables = @([ordered]@{ name = 'Area'; tags = @([ordered]@{ name = 'Start'; logicalAddress = '%I0.0' }) })
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tagsPath -Encoding UTF8
    & $script -BaseInventoryPath $basePath -TagInventoryPath $tagsPath -OutputPath $outputPath
    if ($LASTEXITCODE -ne 0) { throw 'Merge returned a failure exit code.' }
    $merged = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json
    if (@($merged.tagTables).Count -ne 1 -or @($merged.plcs[0].tagTables[0].tags).Count -ne 1) { throw 'Merged tag evidence is missing.' }
    Write-Output 'PASS: detailed tag evidence merges only into the exact PLC path'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
