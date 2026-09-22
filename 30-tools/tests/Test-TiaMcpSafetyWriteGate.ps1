[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Join-Path $WorkspaceRoot '30-tools\mcp\tia-inspect\upstream\src\TiaMcpServer'
$writePlumbing = Join-Path $sourceRoot 'ModelContextProtocol\McpServerWrite.cs'
$portalSafety = Join-Path $sourceRoot 'Siemens\Portal.Safety.cs'
$modelContext = Join-Path $sourceRoot 'ModelContextProtocol\McpServer.cs'

foreach ($path in @($writePlumbing, $portalSafety, $modelContext)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing safety gate source: $path"
    }
}

$guardText = [IO.File]::ReadAllText($writePlumbing)
if ($guardText -notmatch '(?s)InTransaction\([^;]+EnsureNoSafetyObjectsForWrite\(toolName\);\s*return body\(\);') {
    throw 'McpServerWrite.Guarded must run the project-wide F/Safety preflight inside the exclusive transaction before mutation.'
}
if ($guardText -match 'EnsureNoSafetyObjectsForWrite\(toolName\);\s*//.*?InTransaction') {
    throw 'The F/Safety preflight must not run before exclusive access is acquired.'
}

$transactionText = [IO.File]::ReadAllText((Join-Path $sourceRoot 'Siemens\Portal.Transactions.cs'))
if ($transactionText -match 'return\s+body\s*\(') {
    throw 'A failed transaction preflight must not fall back to executing the write body.'
}

$safetyText = [IO.File]::ReadAllText($portalSafety)
foreach ($required in @('GetFailsafeClassification', 'IsSafety', 'EnsureNoSafetyObjectsForWrite')) {
    if ($safetyText -notmatch [regex]::Escape($required)) {
        throw "The project-wide gate is missing required fail-closed classification: $required"
    }
}
if ($safetyText -notmatch 'classification\s*!=\s*false') {
    throw 'Unknown F-block classification must fail closed.'
}

$modelText = [IO.File]::ReadAllText($modelContext)
if ($modelText -notmatch 'IsDisposableFixtureProject\(path\)') {
    throw 'OpenProject does not validate the exact disposable fixture path against its manifest.'
}
if ($modelText -notmatch 'Engineering\.HasFixtureRoot') {
    throw 'CloseProject is not restricted to a configured isolated fixture root.'
}
if ($transactionText -notmatch '(?s)IsCancellationRequested\).*?throw new OperationCanceledException.*?CommitOnDispose\(\)') {
    throw 'An exclusive-access cancellation must abort before transaction commit.'
}

$mutationFiles = @(Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'ModelContextProtocol') -Filter 'McpServer*.cs' -File)
$unsafeUntilPreflight = @('ImportBlock', 'ImportFromDocuments', 'ImportBlocksFromDocuments', 'ImportSources', 'GenerateBlocksFromSource', 'ImportTagTable', 'ImportTypesFromDocuments')
foreach ($toolName in $unsafeUntilPreflight) {
    $registered = $false
    foreach ($file in $mutationFiles) {
        if ($file.Name -like 'McpServerWrite*' -or $file.Name -eq 'McpServer.cs') {
            $text = [IO.File]::ReadAllText($file.FullName)
            if ($text -match ('\[McpServerTool\(\s*Name\s*=\s*"' + [regex]::Escape($toolName) + '"')) {
                $registered = $true
                break
            }
        }
    }
    if ($registered) {
        throw "Unsafe source-driven mutation '$toolName' must remain unregistered until it has a preflight."
    }
}

$engineeringText = [IO.File]::ReadAllText((Join-Path $sourceRoot 'Siemens\Engineering.cs'))
foreach ($required in @('FixtureRoot', 'IsDisposableFixtureProject', '.tia-agent-fixture.json')) {
    if ($engineeringText -notmatch [regex]::Escape($required)) {
        throw "Fixture authorization is missing: $required"
    }
}
$writePolicyText = [IO.File]::ReadAllText((Join-Path $sourceRoot 'ModelContextProtocol\WritePolicy.cs'))
if ($writePolicyText -notmatch 'AllowWrite\s*&&\s*Engineering\.HasFixtureRoot') {
    throw 'Write tool registration must require allow-write, isolated mode, and an existing fixture root.'
}

$portalSafetyText = [IO.File]::ReadAllText($portalSafety)
if ($portalSafetyText -notmatch 'softwareItems\.Count\s*==\s*0') {
    throw 'The global F/Safety gate must reject an empty PLC software inventory.'
}

Write-Output 'PASS: all write handlers reach a project-wide fail-closed F/Safety scan; unsafe opaque imports are not registered.'
