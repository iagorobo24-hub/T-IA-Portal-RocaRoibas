[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$guardPath = Join-Path $root '30-tools\scripts\TiaSclSafety.ps1'
if (-not (Test-Path -LiteralPath $guardPath -PathType Leaf)) { throw "Missing safety guard: $guardPath" }
. $guardPath

function Assert-Throws([scriptblock]$Action, [string]$Label) {
    $thrown = $false
    try { & $Action } catch { $thrown = $true }
    if (-not $thrown) { throw "Expected safety guard to reject: $Label" }
}

$block = [pscustomobject]@{
    name = 'FB_ProcessInterlock'
    path = '20_Permissives/FB_ProcessInterlock'
    typeName = 'PlcFunctionBlock'
    programmingLanguage = 'SCL'
    isFailsafe = $false
    isKnowHowProtected = $false
    isConsistent = $true
}
Assert-TiaSclBlockWritable -Block $block -ExpectedName 'FB_ProcessInterlock' -ExpectedPath $block.path

$unsafeBlock = $block | Select-Object *
$unsafeBlock.isFailsafe = $true
Assert-Throws { Assert-TiaSclBlockWritable -Block $unsafeBlock -ExpectedName $block.name -ExpectedPath $block.path } 'explicit F-block'

$unclassifiedBlock = $block | Select-Object name,path,programmingLanguage,isKnowHowProtected,isConsistent
Assert-Throws { Assert-TiaSclBlockWritable -Block $unclassifiedBlock -ExpectedName $block.name -ExpectedPath $block.path } 'missing F classification'

$unknownBlock = $block | Select-Object *
$unknownBlock.isFailsafe = $null
Assert-Throws { Assert-TiaSclBlockWritable -Block $unknownBlock -ExpectedName $block.name -ExpectedPath $block.path } 'unknown F classification'

$protectedBlock = $block | Select-Object *
$protectedBlock.isKnowHowProtected = $true
Assert-Throws { Assert-TiaSclBlockWritable -Block $protectedBlock -ExpectedName $block.name -ExpectedPath $block.path } 'know-how protection'

$inconsistentBlock = $block | Select-Object *
$inconsistentBlock.isConsistent = $false
Assert-Throws { Assert-TiaSclBlockWritable -Block $inconsistentBlock -ExpectedName $block.name -ExpectedPath $block.path } 'inconsistent block'

$programmingLanguageF = $block | Select-Object *
$programmingLanguageF.programmingLanguage = 'F_LAD'
Assert-Throws { Assert-TiaSclBlockWritable -Block $programmingLanguageF -ExpectedName $block.name -ExpectedPath $block.path } 'F programming language despite false flag'

$tags = [pscustomobject]@{
    meta = [pscustomobject]@{ success = $true; totalTags = [long]1 }
    items = @([pscustomobject]@{ name = 'ProcessEnable'; isSafety = $false })
}
Assert-TiaSclTagInventoryWritable -TagPayload $tags

$safetyTags = [pscustomobject]@{
    meta = [pscustomobject]@{ success = $true; totalTags = [long]1 }
    items = @([pscustomobject]@{ name = 'EStopChannel'; isSafety = $true })
}
Assert-Throws { Assert-TiaSclTagInventoryWritable -TagPayload $safetyTags } 'Safety tag in PLC inventory'

$unclassifiedTags = [pscustomobject]@{
    meta = [pscustomobject]@{ success = $true; totalTags = [long]1 }
    items = @([pscustomobject]@{ name = 'ProcessEnable' })
}
Assert-Throws { Assert-TiaSclTagInventoryWritable -TagPayload $unclassifiedTags } 'missing IsSafety tag metadata'

$partialTags = [pscustomobject]@{
    meta = [pscustomobject]@{ success = $true; totalTags = [long]2 }
    items = @([pscustomobject]@{ name = 'ProcessEnable'; isSafety = $false })
}
Assert-Throws { Assert-TiaSclTagInventoryWritable -TagPayload $partialTags } 'tag inventory count mismatch'

$source = @'
FUNCTION_BLOCK "FB_ProcessInterlock"
BEGIN
    #FaultState := FALSE;
END_FUNCTION_BLOCK
'@
$sourceDeclaration = Assert-TiaSclSourceTarget -SourceText $source -ExpectedName 'FB_ProcessInterlock'
Assert-TiaSclDeclarationMatchesBlock -DeclarationKind $sourceDeclaration.kind -Block $block

Assert-Throws { Assert-TiaSclDeclarationMatchesBlock -DeclarationKind 'FUNCTION' -Block $block } 'declaration kind does not match existing block type'

$udtSource = @'
TYPE "UDT_Extra"
END_TYPE
'@
Assert-Throws { Assert-TiaSclSourceTarget -SourceText $udtSource -ExpectedName 'UDT_Extra' } 'SCL source attempting to generate a PLC type'

if ((ConvertTo-TiaComparableSource "A`r`nB`r`n") -cne (ConvertTo-TiaComparableSource "A`nB`n")) { throw 'Comparable source should normalize line endings only.' }
if ((ConvertTo-TiaComparableSource "A `r`nB") -ceq (ConvertTo-TiaComparableSource "A`r`nB")) { throw 'Comparable source must preserve meaningful whitespace.' }

$wrongSource = $source.Replace('FB_ProcessInterlock', 'FB_Other')
Assert-Throws { Assert-TiaSclSourceTarget -SourceText $wrongSource -ExpectedName 'FB_ProcessInterlock' } 'source declaration name mismatch'

$multipleSource = $source + @'
FUNCTION "FC_Extra" : VOID
BEGIN
END_FUNCTION
'@
Assert-Throws { Assert-TiaSclSourceTarget -SourceText $multipleSource -ExpectedName 'FB_ProcessInterlock' } 'multiple generated declarations'

$registeredTools = [pscustomobject]@{ tools = @([pscustomobject]@{ name = 'ImportSources' }, [pscustomobject]@{ name = 'GetBlocks' }) }
Assert-TiaSclImportCapability -ToolListPayload $registeredTools -RequiredTool 'ImportSources'
Assert-Throws { Assert-TiaSclImportCapability -ToolListPayload $registeredTools -RequiredTool 'ImportFromDocuments' } 'required import tool absent from active profile'
Assert-Throws { Assert-TiaSclImportCapability -ToolListPayload ([pscustomobject]@{}) -RequiredTool 'ImportSources' } 'MCP roster unavailable'

$importResult = [pscustomobject]@{
    meta = [pscustomobject]@{ success = $true }
    items = @([pscustomobject]@{ name = 'FB_ProcessInterlock'; path = $block.path; kind = 'block' })
    failures = @()
    written = [pscustomobject]@{ blocks = 1; types = 0 }
}
Assert-TiaSclImportResult -ImportPayload $importResult -ExpectedName $block.name -ExpectedPath $block.path

$missingCounts = [pscustomobject]@{ meta = $importResult.meta; items = $importResult.items; failures = @() }
Assert-Throws { Assert-TiaSclImportResult -ImportPayload $missingCounts -ExpectedName $block.name -ExpectedPath $block.path } 'import response omits written-object counts'

$partialCounts = [pscustomobject]@{
    meta = $importResult.meta; items = $importResult.items; failures = @()
    written = [pscustomobject]@{ blocks = 1 }
}
Assert-Throws { Assert-TiaSclImportResult -ImportPayload $partialCounts -ExpectedName $block.name -ExpectedPath $block.path } 'import response omits written type count'

$partialImport = $importResult | Select-Object *
$partialImport.failures = @('FB_ProcessInterlock.scl: rejected by compiler')
Assert-Throws { Assert-TiaSclImportResult -ImportPayload $partialImport -ExpectedName $block.name -ExpectedPath $block.path } 'ImportSources per-file failure with meta.success true'

$extraImport = $importResult | Select-Object *
$extraImport.items = @($importResult.items) + @([pscustomobject]@{ name = 'FB_Unexpected'; path = '20_Permissives/FB_Unexpected'; kind = 'block' })
$extraImport.written = [pscustomobject]@{ blocks = 2; types = 0 }
Assert-Throws { Assert-TiaSclImportResult -ImportPayload $extraImport -ExpectedName $block.name -ExpectedPath $block.path } 'unexpected generated block'

Write-Output 'PASS: TIA SCL safety guard rejects F/Safety, ambiguous metadata, partial import, and extra declarations while allowing a classified standard SCL block in 20_Permissives.'
