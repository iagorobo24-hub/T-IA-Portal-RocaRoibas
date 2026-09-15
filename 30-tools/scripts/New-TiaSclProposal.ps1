<##
.SYNOPSIS
    Genera una propuesta SCL revisable sin modificar TIA ni el fichero original.

.DESCRIPTION
    Consume un dossier producido por Invoke-TiaProjectAnalysis y aplica un unico reemplazo textual
    que el agente o el usuario ha especificado. Valida que el bloque sea SCL, que su fuente exista,
    que el reemplazo sea univoco y que no haya bloqueos de proteccion o consistencia.

    La salida es una copia propuesta, un diff y proposal.json. No importa, compila, guarda ni
    descarga nada. La aplicacion en TIA es una operacion posterior y separada.
##>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AnalysisPath,

    [Parameter(Mandatory = $true)]
    [string]$BlockName,

    [Parameter(Mandatory = $true)]
    [string]$FindText,

    [Parameter(Mandatory = $true)]
    [string]$ReplaceText,

    [string]$OutputDirectory,
    [string]$Objective = '',
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output @'
New-TiaSclProposal.ps1: propuesta SCL de un solo reemplazo, sin efectos en TIA.
Entrada: analysis.json, nombre exacto del bloque, texto unico a buscar y reemplazo.
Salida: proposal.json, copia SCL y proposal.diff.
'@
    exit 0
}

$AnalysisPath = [IO.Path]::GetFullPath($AnalysisPath)
if (-not (Test-Path -LiteralPath $AnalysisPath -PathType Leaf)) { throw "Analysis does not exist: $AnalysisPath" }
if ([string]::IsNullOrWhiteSpace($FindText)) { throw 'FindText cannot be empty.' }

$analysis = Get-Content -Raw -LiteralPath $AnalysisPath | ConvertFrom-Json
if ($analysis.readOnly -ne $true) { throw 'The proposal input must be a read-only analysis dossier.' }
if (-not $analysis.sourceRoot) { throw 'Analysis has no sourceRoot.' }

$matches = @($analysis.blocks | Where-Object { [string]$_.name -ceq $BlockName })
if ($matches.Count -ne 1) { throw "Expected exactly one block named '$BlockName' in the analysis; found $($matches.Count)." }
$block = $matches[0]
if (-not $block.sourcePresent -or [string]::IsNullOrWhiteSpace([string]$block.source)) { throw "Block '$BlockName' has no exported source." }
if ([string]$block.language -ne 'SCL') { throw "Block '$BlockName' is not SCL; proposal generation refuses LAD/XML editing." }

$blocking = @($analysis.findings | Where-Object {
    [string]$_.severity -eq 'BLOCKING' -and ([string]::IsNullOrWhiteSpace([string]$_.block) -or [string]$_.block -eq $BlockName)
})
if ($blocking.Count -gt 0) { throw "Block '$BlockName' has blocking findings; proposal refused." }

$sourceRoot = [IO.Path]::GetFullPath([string]$analysis.sourceRoot)
$sourcePath = [IO.Path]::GetFullPath((Join-Path $sourceRoot ([string]$block.source)))
$rootWithSeparator = $sourceRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $sourcePath.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) { throw 'Source path escapes the analysis sourceRoot.' }
$sourceExtension = [IO.Path]::GetExtension($sourcePath).ToLowerInvariant()
if ($sourceExtension -notin @('.s7dcl', '.scl')) { throw 'Only .s7dcl or .scl sources are eligible for proposal generation.' }
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Source does not exist: $sourcePath" }

$original = [IO.File]::ReadAllText($sourcePath)
$occurrences = 0
$cursor = 0
while ($cursor -lt $original.Length) {
    $found = $original.IndexOf($FindText, $cursor, [StringComparison]::Ordinal)
    if ($found -lt 0) { break }
    $occurrences++
    $cursor = $found + $FindText.Length
}
if ($occurrences -ne 1) { throw "FindText must occur exactly once in '$BlockName'; found $occurrences." }
if ($ReplaceText.Contains("`t")) { throw 'ReplaceText contains tabs; use the repository SCL indentation standard.' }

$index = $original.IndexOf($FindText, [StringComparison]::Ordinal)
$proposed = $original.Substring(0, $index) + $ReplaceText + $original.Substring($index + $FindText.Length)
$sourceFileName = Split-Path -Leaf $sourcePath
if (-not $OutputDirectory) { $OutputDirectory = Join-Path (Split-Path -Parent $AnalysisPath) ('proposal-' + ($BlockName -replace '[^A-Za-z0-9_.-]', '_')) }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory -PathType Leaf) { throw "OutputDirectory is a file: $OutputDirectory" }
if ((Test-Path -LiteralPath $OutputDirectory -PathType Container) -and -not $Force -and @(Get-ChildItem -LiteralPath $OutputDirectory -Force).Count -gt 0) {
    throw "OutputDirectory is not empty; use -Force only for this exact proposal directory: $OutputDirectory"
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$proposedSourcePath = Join-Path $OutputDirectory $sourceFileName
$proposalPath = Join-Path $OutputDirectory 'proposal.json'
$diffPath = Join-Path $OutputDirectory 'proposal.diff'
$markdownPath = Join-Path $OutputDirectory 'proposal.md'
$encoding = [Text.UTF8Encoding]::new($true)
[IO.File]::WriteAllText($proposedSourcePath, $proposed, $encoding)

function Prefix-DiffLines([string]$Text, [string]$Prefix) {
    return (($Text -split "`r?`n") | ForEach-Object { $Prefix + $_ }) -join "`r`n"
}
$diff = "--- $sourceFileName`r`n+++ $sourceFileName (proposal)`r`n@@`r`n"
$diff += (Prefix-DiffLines $FindText '-') + "`r`n"
$diff += (Prefix-DiffLines $ReplaceText '+') + "`r`n"
[IO.File]::WriteAllText($diffPath, $diff, $encoding)

$companionSourcePath = [IO.Path]::ChangeExtension($sourcePath, '.s7res')
$companionProposedPath = $null
if (Test-Path -LiteralPath $companionSourcePath -PathType Leaf) {
    $companionProposedPath = Join-Path $OutputDirectory ([IO.Path]::GetFileName($companionSourcePath))
    Copy-Item -LiteralPath $companionSourcePath -Destination $companionProposedPath -Force
}

$proposal = [ordered]@{
    schemaVersion = 1
    status = 'PROPOSED'
    readOnly = $true
    applied = $false
    tiaMutation = $false
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    objective = $Objective
    analysisPath = $AnalysisPath
    projectPath = [string]$analysis.projectPath
    plc = [string]$block.plc
    block = [ordered]@{ name = $BlockName; path = [string]$block.path; language = [string]$block.language }
    source = [ordered]@{
        originalPath = $sourcePath
        proposedPath = $proposedSourcePath
        originalSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash.ToLowerInvariant()
        proposedSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $proposedSourcePath).Hash.ToLowerInvariant()
        matchCount = $occurrences
        extension = $sourceExtension
        companionOriginalPath = if ($companionProposedPath) { $companionSourcePath } else { $null }
        companionProposedPath = $companionProposedPath
    }
    artifacts = [ordered]@{ diff = $diffPath; markdown = $markdownPath }
    checks = [ordered]@{
        exactBlockMatch = $true
        sclOnly = $true
        noBlockingFindings = $true
        uniqueReplacement = $true
        originalUntouched = $true
    }
}
$proposal | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $proposalPath -Encoding UTF8

$markdown = @"
# Propuesta SCL

> Estado: **PROPOSED**. Este artefacto no se ha importado ni aplicado en TIA Portal.

- Proyecto: ``$($analysis.projectPath)``
- PLC: ``$($block.plc)``
- Bloque: ``$BlockName``
- Fuente original: ``$sourcePath``
- Objetivo: $Objective

## Cambio

```scl
$ReplaceText
```

El texto original aparece exactamente una vez. La copia propuesta, el diff y los hashes quedan
registrados en ``proposal.json``. Para aplicar el cambio hace falta una operación posterior con
perfil de escritura, backup, preview, compilación y guardado según ``AGENTS.md``.
"@
$markdown | Set-Content -LiteralPath $markdownPath -Encoding UTF8

Write-Output ($proposal | ConvertTo-Json -Depth 8)
Write-Host "Proposal: $proposalPath" -ForegroundColor Green
Write-Host "Source copy: $proposedSourcePath" -ForegroundColor Green
Write-Host "Diff: $diffPath" -ForegroundColor Green
exit 0
