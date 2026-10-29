[CmdletBinding()]
param()

# Cobertura del arnes por tipo de bloque (FASE 6.2) y de la politica de bloques
# anidados en la ruta adjunta (FASE 2.3).
#
# Estas funciones son el unico punto donde se decide si un bloque puede escribirse:
# - Assert-TiaSclSourceTarget            -> que declara la fuente SCL
# - Assert-TiaSclDeclarationMatchesBlock -> tipo Openness exacto (ruta aislada)
# - Assert-TiaCreateBlockWritable        -> alias de tipo en tia-create (ruta adjunta)
# - Assert-TiaAttachedRouteTopLevelBlock -> groupPath vacio obligatorio en adjunta
#
# No ejecuta TIA Portal ni muta nada: son funciones puras sobre payloads.

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $root '30-tools\scripts\TiaSclSafety.ps1')

$script:checks = 0

function Assert-Throws {
    param(
        [Parameter(Mandatory = $true)] [scriptblock]$Action,
        [Parameter(Mandatory = $true)] [string]$Pattern,
        [Parameter(Mandatory = $true)] [string]$Label
    )
    $script:checks++
    $message = $null
    try { & $Action } catch { $message = [string]$_.Exception.Message }
    if ($null -eq $message) { throw "[$Label] expected a rejection, but the call succeeded." }
    if ($message -notmatch $Pattern) { throw "[$Label] rejection did not match '$Pattern'; got: $message" }
}

function Assert-Passes {
    param(
        [Parameter(Mandatory = $true)] [scriptblock]$Action,
        [Parameter(Mandatory = $true)] [string]$Label
    )
    $script:checks++
    try { & $Action } catch { throw "[$Label] expected success, got: $($_.Exception.Message)" }
}

function New-Block {
    param(
        [string]$Name = 'FB_Valve',
        [string]$TypeName = 'FB',
        [string]$Language = 'SCL',
        [object]$IsFailsafe = $false,
        [object]$IsKnowHowProtected = $false,
        [object]$IsConsistent = $true,
        [bool]$IncludePath = $false,
        [string]$Path = ''
    )
    $block = [ordered]@{
        name = $Name
        typeName = $TypeName
        programmingLanguage = $Language
        isFailsafe = $IsFailsafe
        isKnowHowProtected = $IsKnowHowProtected
        isConsistent = $IsConsistent
    }
    if ($IncludePath) { $block.path = $Path }
    return [pscustomobject]$block
}

function New-BlocksPayload {
    param([object[]]$Items, [bool]$MetaSuccess = $true)
    return [pscustomobject]@{ meta = [pscustomobject]@{ success = $MetaSuccess }; items = @($Items) }
}

# --- 1. Declaracion SCL: los cuatro tipos que el parser reconoce -----------------
$sources = @{
    FUNCTION_BLOCK      = @{ kind = 'FUNCTION_BLOCK';      text = "FUNCTION_BLOCK `"FB_Valve`"`nBEGIN`nEND_FUNCTION_BLOCK" }
    FUNCTION            = @{ kind = 'FUNCTION';            text = "FUNCTION `"FC_Scale`" : Void`nBEGIN`nEND_FUNCTION" }
    ORGANIZATION_BLOCK  = @{ kind = 'ORGANIZATION_BLOCK';  text = "ORGANIZATION_BLOCK `"Main`"`nBEGIN`nEND_ORGANIZATION_BLOCK" }
    DATA_BLOCK          = @{ kind = 'DATA_BLOCK';          text = "DATA_BLOCK `"DB_Config`"`nBEGIN`nEND_DATA_BLOCK" }
}
foreach ($entry in $sources.GetEnumerator()) {
    $expectedName = switch ($entry.Key) {
        'FUNCTION_BLOCK' { 'FB_Valve' }
        'FUNCTION' { 'FC_Scale' }
        'ORGANIZATION_BLOCK' { 'Main' }
        'DATA_BLOCK' { 'DB_Config' }
    }
    $script:checks++
    $parsed = Assert-TiaSclSourceTarget -SourceText $entry.Value.text -ExpectedName $expectedName
    if ($parsed.kind -ne $entry.Value.kind) { throw "Source parser mapped $($entry.Key) to '$($parsed.kind)'." }
    if ($parsed.name -ne $expectedName) { throw "Source parser read name '$($parsed.name)' instead of '$expectedName'." }
}
Write-Output 'PASS: SCL source parser recognizes FUNCTION_BLOCK, FUNCTION, ORGANIZATION_BLOCK and DATA_BLOCK'

Assert-Throws -Label 'source-empty' -Pattern 'exactly one block/type' -Action {
    Assert-TiaSclSourceTarget -SourceText '// nothing here' -ExpectedName 'FB_Valve'
}
Assert-Throws -Label 'source-two' -Pattern 'exactly one block/type' -Action {
    Assert-TiaSclSourceTarget -SourceText "FUNCTION_BLOCK `"FB_A`"`nEND_FUNCTION_BLOCK`nFUNCTION_BLOCK `"FB_B`"`nEND_FUNCTION_BLOCK" -ExpectedName 'FB_A'
}
Assert-Throws -Label 'source-name' -Pattern 'does not match target' -Action {
    Assert-TiaSclSourceTarget -SourceText "FUNCTION_BLOCK `"FB_Other`"`nEND_FUNCTION_BLOCK" -ExpectedName 'FB_Valve'
}
Assert-Throws -Label 'source-terminator' -Pattern 'exactly one END_FUNCTION_BLOCK' -Action {
    Assert-TiaSclSourceTarget -SourceText "FUNCTION_BLOCK `"FB_Valve`"`nBEGIN" -ExpectedName 'FB_Valve'
}
Write-Output 'PASS: SCL source parser is fail-closed on missing, duplicated, mismatched and unterminated declarations'

# --- 2. Tipo Openness exacto (ruta aislada) --------------------------------------
$opennessTypes = @{
    FUNCTION_BLOCK     = 'PlcFunctionBlock'
    FUNCTION           = 'PlcFunction'
    ORGANIZATION_BLOCK = 'PlcOrganizationBlock'
    DATA_BLOCK         = 'PlcDataBlock'
}
foreach ($entry in $opennessTypes.GetEnumerator()) {
    Assert-Passes -Label "openness-$($entry.Key)" -Action {
        Assert-TiaSclDeclarationMatchesBlock -DeclarationKind $entry.Key -Block ([pscustomobject]@{ typeName = $entry.Value })
    }
}
Write-Output 'PASS: Openness type mapping accepts PlcFunctionBlock, PlcFunction, PlcOrganizationBlock and PlcDataBlock'

Assert-Throws -Label 'openness-mismatch' -Pattern 'does not match live Openness type' -Action {
    Assert-TiaSclDeclarationMatchesBlock -DeclarationKind 'FUNCTION' -Block ([pscustomobject]@{ typeName = 'PlcFunctionBlock' })
}
Assert-Throws -Label 'openness-missing' -Pattern 'missing its exact Openness type' -Action {
    Assert-TiaSclDeclarationMatchesBlock -DeclarationKind 'FUNCTION' -Block ([pscustomobject]@{ name = 'FC_X' })
}
Assert-Throws -Label 'openness-unknown' -Pattern 'Unsupported SCL block declaration' -Action {
    Assert-TiaSclDeclarationMatchesBlock -DeclarationKind 'TYPE' -Block ([pscustomobject]@{ typeName = 'PlcType' })
}
Write-Output 'PASS: Openness type mapping is fail-closed on mismatch, missing type and unknown declaration'

# --- 3. Alias de tipo en tia-create (ruta adjunta) -------------------------------
$createAliases = @{
    FUNCTION_BLOCK     = 'FB'
    FUNCTION           = 'FC'
    ORGANIZATION_BLOCK = 'OB'
}
foreach ($entry in $createAliases.GetEnumerator()) {
    Assert-Passes -Label "create-$($entry.Key)" -Action {
        Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block -TypeName $entry.Value)) `
            -BlockName 'FB_Valve' -DeclarationKind $entry.Key
    }
}
Write-Output 'PASS: tia-create alias mapping accepts FB, FC and OB'

# DATA_BLOCK sigue fail-closed: no hay evidencia live de generar un DB por esta ruta.
Assert-Throws -Label 'create-datablock' -Pattern 'not evidenced for declaration' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block -TypeName 'DB')) `
        -BlockName 'FB_Valve' -DeclarationKind 'DATA_BLOCK'
}
Write-Output 'PASS: tia-create refuses DATA_BLOCK until its generation path is evidenced'

Assert-Throws -Label 'create-mismatch' -Pattern 'does not match live tia-create type' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block -TypeName 'FB')) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION'
}
Assert-Throws -Label 'create-duplicate' -Pattern 'found 2' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @((New-Block), (New-Block))) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK'
}
Assert-Throws -Label 'create-none' -Pattern 'found 0' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @()) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK'
}
Assert-Throws -Label 'create-meta' -Pattern 'did not report a successful read' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block) -MetaSuccess $false) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK'
}
Assert-Throws -Label 'create-no-items' -Pattern 'missing its items collection' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload ([pscustomobject]@{ meta = [pscustomobject]@{ success = $true } }) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK'
}
Write-Output 'PASS: tia-create block gate is fail-closed on type mismatch, duplicates, missing blocks and failed metadata'

# --- 3b. Identidad por path cuando el payload la expone (hardening FASE 6.3) -----
Assert-Passes -Label 'path-match' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block -IncludePath $true -Path 'FB_Valve')) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK' -BlockPath 'FB_Valve'
}
Assert-Passes -Label 'path-absent' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block)) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK' -BlockPath 'FB_Valve'
}
Assert-Throws -Label 'path-mismatch' -Pattern 'differs from proposal path' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block -IncludePath $true -Path 'Group/FB_Valve')) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK' -BlockPath 'FB_Valve'
}
Write-Output 'PASS: block path is verified when present, absent path stays backward-compatible, mismatch is rejected'

# --- 4. Gates de seguridad por tipo ---------------------------------------------
Assert-Throws -Label 'gate-language' -Pattern 'not explicitly classified as standard SCL' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block -Language 'LAD')) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK'
}
Assert-Throws -Label 'gate-failsafe' -Pattern 'F/Safety or its F classification is unknown' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block -IsFailsafe $true)) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK'
}
Assert-Throws -Label 'gate-failsafe-null' -Pattern 'F/Safety or its F classification is unknown' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block -IsFailsafe $null)) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK'
}
Assert-Throws -Label 'gate-knowhow' -Pattern 'know-how protected' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block -IsKnowHowProtected $true)) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK'
}
Assert-Throws -Label 'gate-inconsistent' -Pattern 'inconsistent or its consistency status is unknown' -Action {
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @(New-Block -IsConsistent $false)) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK'
}
Assert-Throws -Label 'gate-missing-property' -Pattern "missing safety classification 'isConsistent'" -Action {
    $block = New-Block
    $block.PSObject.Properties.Remove('isConsistent')
    Assert-TiaCreateBlockWritable -BlocksPayload (New-BlocksPayload -Items @($block)) `
        -BlockName 'FB_Valve' -DeclarationKind 'FUNCTION_BLOCK'
}
Write-Output 'PASS: language, F/Safety, know-how, consistency and missing-metadata gates hold for every type'

# --- 5. Politica de bloques anidados en la ruta adjunta (FASE 2.3) --------------
Assert-Passes -Label 'top-level-empty' -Action {
    Assert-TiaAttachedRouteTopLevelBlock -GroupPath '' -BlockPath 'FB_Valve'
}
Assert-Passes -Label 'top-level-whitespace' -Action {
    Assert-TiaAttachedRouteTopLevelBlock -GroupPath '   ' -BlockPath 'FB_Valve'
}
Assert-Throws -Label 'nested-one' -Pattern 'top-level blocks' -Action {
    Assert-TiaAttachedRouteTopLevelBlock -GroupPath '01_Devices' -BlockPath '01_Devices/FB_Valve'
}
Assert-Throws -Label 'nested-deep' -Pattern 'top-level blocks' -Action {
    Assert-TiaAttachedRouteTopLevelBlock -GroupPath '40_Devices/PLC_1/Program blocks' -BlockPath '40_Devices/PLC_1/Program blocks/FB_Valve'
}
$nestedMessage = $null
try { Assert-TiaAttachedRouteTopLevelBlock -GroupPath 'G1/G2' -BlockPath 'G1/G2/FB_Valve' } catch { $nestedMessage = [string]$_.Exception.Message }
if ($nestedMessage -notmatch "G1/G2/FB_Valve" -or $nestedMessage -notmatch "groupPath 'G1/G2'" -or $nestedMessage -notmatch 'R28') {
    throw "Nested-path rejection must name the block path, the resolved groupPath and R28; got: $nestedMessage"
}
$script:checks++
Write-Output 'PASS: attached route top-level gate accepts root blocks and rejects any nested groupPath with an actionable message'

# --- 6. Gates de inventario de tags (base de FASE 4) ----------------------------
$safeTagPayload = [pscustomobject]@{
    meta = [pscustomobject]@{ success = $true; complete = $true; count = 1 }
    items = @([pscustomobject]@{ name = 'Cmd_Enable'; isSafety = $false })
}
Assert-Passes -Label 'tags-safe' -Action { Assert-TiaCreateTagInventoryWritable -TagPayload $safeTagPayload }
Assert-Throws -Label 'tags-safety' -Pattern 'is Safety' -Action {
    Assert-TiaCreateTagInventoryWritable -TagPayload ([pscustomobject]@{
        meta = [pscustomobject]@{ success = $true; complete = $true; count = 1 }
        items = @([pscustomobject]@{ name = 'EStop'; isSafety = $true })
    })
}
Assert-Throws -Label 'tags-unclassified' -Pattern 'no explicit Safety classification' -Action {
    Assert-TiaCreateTagInventoryWritable -TagPayload ([pscustomobject]@{
        meta = [pscustomobject]@{ success = $true; complete = $true; count = 1 }
        items = @([pscustomobject]@{ name = 'Cmd_Enable' })
    })
}
Assert-Throws -Label 'tags-incomplete' -Pattern 'complete read' -Action {
    Assert-TiaCreateTagInventoryWritable -TagPayload ([pscustomobject]@{
        meta = [pscustomobject]@{ success = $true; complete = $false; count = 1 }
        items = @([pscustomobject]@{ name = 'Cmd_Enable'; isSafety = $false })
    })
}
Assert-Throws -Label 'tags-count' -Pattern 'count mismatch' -Action {
    Assert-TiaCreateTagInventoryWritable -TagPayload ([pscustomobject]@{
        meta = [pscustomobject]@{ success = $true; complete = $true; count = 99 }
        items = @([pscustomobject]@{ name = 'Cmd_Enable'; isSafety = $false })
    })
}
Write-Output 'PASS: tag inventory gate blocks Safety, unclassified, incomplete and miscounted inventories'

Write-Output "All $($script:checks) block-type and nested-path assertions passed."
