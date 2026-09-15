[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$quiz = Join-Path $WorkspaceRoot '00-meta\eval\kb-quiz.md'
$answers = Join-Path $WorkspaceRoot '00-meta\eval\kb-answer-key.md'
if (-not (Test-Path -LiteralPath $quiz -PathType Leaf)) { throw 'Knowledge quiz is missing.' }
if (-not (Test-Path -LiteralPath $answers -PathType Leaf)) { throw 'Knowledge answer key is missing.' }

$quizQuestions = @(Select-String -LiteralPath $quiz -Pattern '^## Q[0-9]{2}\b')
if ($quizQuestions.Count -ne 10) { throw "Expected 10 knowledge questions; found $($quizQuestions.Count)." }

$answerLines = @(Get-Content -LiteralPath $answers | Where-Object { $_ -match '^Q[0-9]{2}\b' })
if ($answerLines.Count -ne 10) { throw "Expected 10 answer entries; found $($answerLines.Count)." }
$references = foreach ($line in $answerLines) {
    if ($line -notmatch '`([^`]+)`') { throw "Answer has no file reference: $line" }
    $matches[1]
}
foreach ($reference in $references) {
    $path = Join-Path $WorkspaceRoot $reference
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing knowledge reference: $reference" }
}
Write-Output "PASS: knowledge index (10 questions, $($references.Count) valid references)"
