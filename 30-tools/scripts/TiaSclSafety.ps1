function Test-TiaSclHasProperty {
    param(
        [Parameter(Mandatory = $true)] [object]$InputObject,
        [Parameter(Mandatory = $true)] [string]$Name
    )

    return $null -ne $InputObject -and $InputObject.PSObject.Properties.Name -contains $Name
}

function Assert-TiaSclBlockWritable {
    param(
        [Parameter(Mandatory = $true)] [object]$Block,
        [Parameter(Mandatory = $true)] [string]$ExpectedName,
        [Parameter(Mandatory = $true)] [string]$ExpectedPath
    )

    foreach ($property in @('name', 'path', 'programmingLanguage', 'isFailsafe', 'isKnowHowProtected', 'isConsistent')) {
        if (-not (Test-TiaSclHasProperty -InputObject $Block -Name $property)) {
            throw "Block safety classification is incomplete: missing '$property'."
        }
    }

    if ([string]$Block.name -ine $ExpectedName) { throw "Live block name '$($Block.name)' differs from '$ExpectedName'." }
    if ([string]$Block.path -cne $ExpectedPath) { throw "Live block path '$($Block.path)' differs from '$ExpectedPath'." }
    if ($Block.programmingLanguage -isnot [string] -or [string]$Block.programmingLanguage -cne 'SCL') {
        throw "Block '$ExpectedName' is not explicitly classified as standard SCL."
    }
    if ($Block.isFailsafe -isnot [bool] -or $Block.isFailsafe -ne $false) {
        throw "Block '$ExpectedName' is F/Safety or its F classification is unknown."
    }
    if ($Block.isKnowHowProtected -isnot [bool] -or $Block.isKnowHowProtected -ne $false) {
        throw "Block '$ExpectedName' is know-how protected or its protection status is unknown."
    }
    if ($Block.isConsistent -isnot [bool] -or $Block.isConsistent -ne $true) {
        throw "Block '$ExpectedName' is inconsistent or its consistency status is unknown."
    }
}

function Assert-TiaSclTagInventoryWritable {
    param([Parameter(Mandatory = $true)] [object]$TagPayload)

    if (-not (Test-TiaSclHasProperty -InputObject $TagPayload -Name 'meta') -or
        -not (Test-TiaSclHasProperty -InputObject $TagPayload.meta -Name 'success') -or
        $TagPayload.meta.success -ne $true) {
        throw 'Live PLC tag inventory did not report a successful complete read.'
    }
    if (-not (Test-TiaSclHasProperty -InputObject $TagPayload.meta -Name 'totalTags') -or
        $TagPayload.meta.totalTags -isnot [ValueType] -or $TagPayload.meta.totalTags -is [bool]) {
        throw 'Live PLC tag inventory is missing its nonnegative totalTags count.'
    }
    $reportedTagCount = 0L
    if (-not [long]::TryParse([string]$TagPayload.meta.totalTags, [ref]$reportedTagCount) -or $reportedTagCount -lt 0) {
        throw 'Live PLC tag inventory has an invalid totalTags count.'
    }
    if (-not (Test-TiaSclHasProperty -InputObject $TagPayload -Name 'items') -or $null -eq $TagPayload.items) {
        throw 'Live PLC tag inventory is missing its items collection.'
    }

    $tags = @($TagPayload.items)
    if ($tags.Count -ne $reportedTagCount) {
        throw "Live PLC tag inventory is incomplete: payload has $($tags.Count), meta.totalTags reports $reportedTagCount."
    }
    foreach ($tag in $tags) {
        if (-not (Test-TiaSclHasProperty -InputObject $tag -Name 'isSafety') -or $tag.isSafety -isnot [bool]) {
            throw "Tag '$([string]$tag.name)' has no explicit Safety classification."
        }
        if ($tag.isSafety) { throw "PLC tag '$([string]$tag.name)' is Safety; proposal apply is blocked." }
    }
}

function Assert-TiaSclSourceTarget {
    param(
        [Parameter(Mandatory = $true)] [string]$SourceText,
        [Parameter(Mandatory = $true)] [string]$ExpectedName
    )

    $declarationPattern = '(?im)^[\t ]*(?<kind>FUNCTION_BLOCK|ORGANIZATION_BLOCK|DATA_BLOCK|FUNCTION)\s+(?:"(?<quoted>[^"\r\n]+)"|(?<plain>[A-Za-z_][A-Za-z0-9_]*))(?=[\s:]|$)'
    $declarations = [regex]::Matches($SourceText, $declarationPattern)
    if ($declarations.Count -ne 1) { throw "SCL source must declare exactly one block/type; found $($declarations.Count)." }

    $declaration = $declarations[0]
    $declaredName = if ($declaration.Groups['quoted'].Success) { $declaration.Groups['quoted'].Value } else { $declaration.Groups['plain'].Value }
    $kind = $declaration.Groups['kind'].Value.ToUpperInvariant()
    if ($declaredName -ine $ExpectedName) { throw "SCL declaration '$declaredName' does not match target '$ExpectedName'." }

    $terminator = switch ($kind) {
        'FUNCTION_BLOCK' { 'END_FUNCTION_BLOCK' }
        'ORGANIZATION_BLOCK' { 'END_ORGANIZATION_BLOCK' }
        'DATA_BLOCK' { 'END_DATA_BLOCK' }
        'FUNCTION' { 'END_FUNCTION' }
        default { throw "Unsupported SCL declaration '$kind'." }
    }
    $terminators = [regex]::Matches($SourceText, "(?im)^[\t ]*$terminator\b")
    if ($terminators.Count -ne 1) { throw "SCL source must contain exactly one $terminator terminator." }

    return [pscustomobject]@{ kind = $kind; name = $declaredName }
}

function Assert-TiaSclDeclarationMatchesBlock {
    param(
        [Parameter(Mandatory = $true)] [string]$DeclarationKind,
        [Parameter(Mandatory = $true)] [object]$Block
    )

    if (-not (Test-TiaSclHasProperty -InputObject $Block -Name 'typeName') -or
        [string]::IsNullOrWhiteSpace([string]$Block.typeName)) {
        throw 'Live block metadata is missing its exact Openness type name.'
    }
    $expectedType = switch ($DeclarationKind.ToUpperInvariant()) {
        'FUNCTION_BLOCK' { 'PlcFunctionBlock' }
        'ORGANIZATION_BLOCK' { 'PlcOrganizationBlock' }
        'DATA_BLOCK' { 'PlcDataBlock' }
        'FUNCTION' { 'PlcFunction' }
        default { throw "Unsupported SCL block declaration '$DeclarationKind'." }
    }
    if ([string]$Block.typeName -cne $expectedType) {
        throw "SCL declaration '$DeclarationKind' does not match live Openness type '$($Block.typeName)'."
    }
}

function Assert-TiaCreateApplyCapability {
    param(
        [Parameter(Mandatory = $true)] [object]$ToolListPayload,
        [Parameter(Mandatory = $true)] [string[]]$RequiredTools
    )

    foreach ($tool in $RequiredTools) {
        Assert-TiaSclImportCapability -ToolListPayload $ToolListPayload -RequiredTool $tool
    }
}

function Assert-TiaCreateAttachIdentity {
    param(
        [Parameter(Mandatory = $true)] [string]$AttachMessage,
        [Parameter(Mandatory = $true)] [string]$ProjectTreeText,
        [Parameter(Mandatory = $true)] [string]$ExpectedProjectName
    )

    if ([string]::IsNullOrWhiteSpace($ExpectedProjectName)) {
        throw 'Attach route requires an explicit expected open project name.'
    }
    # tia-create serializes with System.Text.Json, which escapes apostrophes as \u0027.
    # Parse the payload when possible so the comparison is against the decoded message.
    $attachText = $AttachMessage
    try {
        $attachPayload = $AttachMessage | ConvertFrom-Json
        if ($attachPayload -and $attachPayload.PSObject.Properties['message']) {
            $attachText = [string]$attachPayload.message
        }
    }
    catch {
        # A non-JSON message cannot confirm the project; the match below rejects it.
    }
    if ($attachText -notmatch [regex]::Escape("Attached to open project '$ExpectedProjectName'")) {
        throw "AttachToOpenProject did not confirm the expected project: '$AttachMessage'."
    }
    # tia-create devuelve el arbol dentro de una valla Markdown (```); la raiz real es
    # la primera linea que no sea valla ni este vacia.
    $firstLine = @(($ProjectTreeText -replace "`r", "").Split("`n") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -notmatch '^```' }) | Select-Object -First 1
    if ([string]$firstLine -cne $ExpectedProjectName) {
        throw "Project tree root '$firstLine' does not match the attached project '$ExpectedProjectName'."
    }
}

function Assert-TiaCreateBlockWritable {
    param(
        [Parameter(Mandatory = $true)] [object]$BlocksPayload,
        [Parameter(Mandatory = $true)] [string]$BlockName,
        [Parameter(Mandatory = $true)] [string]$DeclarationKind
    )

    if (Test-TiaSclHasProperty -InputObject $BlocksPayload -Name 'meta') {
        if (-not (Test-TiaSclHasProperty -InputObject $BlocksPayload.meta -Name 'success') -or $BlocksPayload.meta.success -ne $true) {
            throw 'tia-create GetBlocks did not report a successful read.'
        }
    }
    if (-not (Test-TiaSclHasProperty -InputObject $BlocksPayload -Name 'items') -or $null -eq $BlocksPayload.items) {
        throw 'tia-create GetBlocks response is missing its items collection.'
    }
    $items = @($BlocksPayload.items)
    $matches = @($items | Where-Object { [string]$_.name -ieq $BlockName })
    if ($matches.Count -ne 1) { throw "Expected exactly one live block named '$BlockName'; found $($matches.Count)." }
    $block = $matches[0]

    foreach ($property in @('name', 'typeName', 'programmingLanguage', 'isFailsafe', 'isKnowHowProtected', 'isConsistent')) {
        if (-not (Test-TiaSclHasProperty -InputObject $block -Name $property)) {
            throw "tia-create block '$BlockName' is missing safety classification '$property'."
        }
    }
    if ([string]$block.name -cne $BlockName) { throw "Live block name '$($block.name)' differs from '$BlockName'." }
    if ($block.programmingLanguage -isnot [string] -or [string]$block.programmingLanguage -cne 'SCL') {
        throw "Block '$BlockName' is not explicitly classified as standard SCL."
    }
    if ($block.isFailsafe -isnot [bool] -or $block.isFailsafe -ne $false) {
        throw "Block '$BlockName' is F/Safety or its F classification is unknown."
    }
    if ($block.isKnowHowProtected -isnot [bool] -or $block.isKnowHowProtected -ne $false) {
        throw "Block '$BlockName' is know-how protected or its protection status is unknown."
    }
    if ($block.isConsistent -isnot [bool] -or $block.isConsistent -ne $true) {
        throw "Block '$BlockName' is inconsistent or its consistency status is unknown."
    }

    # typeName is a short Openness alias on tia-create (real evidence 2026-09-25:
    # 'OB' for an ORGANIZATION_BLOCK and 'FB' for a FUNCTION_BLOCK). Only the
    # evidenced mappings are accepted; anything else fails closed.
    $expectedType = switch ($DeclarationKind.ToUpperInvariant()) {
        'FUNCTION_BLOCK' { 'FB' }
        'ORGANIZATION_BLOCK' { 'OB' }
        default { throw "tia-create typeName mapping is not evidenced for declaration '$DeclarationKind'; block refused." }
    }
    if ([string]$block.typeName -cne $expectedType) {
        throw "SCL declaration '$DeclarationKind' does not match live tia-create type '$($block.typeName)'."
    }
}

function Assert-TiaCreateTagInventoryWritable {
    param([Parameter(Mandatory = $true)] [object]$TagPayload)

    if (-not (Test-TiaSclHasProperty -InputObject $TagPayload -Name 'meta') -or
        -not (Test-TiaSclHasProperty -InputObject $TagPayload.meta -Name 'success') -or
        $TagPayload.meta.success -ne $true) {
        throw 'tia-create GetTags did not report a successful read.'
    }
    if (-not (Test-TiaSclHasProperty -InputObject $TagPayload.meta -Name 'complete') -or
        $TagPayload.meta.complete -isnot [bool] -or $TagPayload.meta.complete -ne $true) {
        throw 'tia-create GetTags did not explicitly report a complete read.'
    }
    if (-not (Test-TiaSclHasProperty -InputObject $TagPayload -Name 'items') -or $null -eq $TagPayload.items) {
        throw 'tia-create GetTags response is missing its items collection.'
    }
    $tags = @($TagPayload.items)
    $reportedCount = 0L
    if (-not (Test-TiaSclHasProperty -InputObject $TagPayload.meta -Name 'count') -or
        -not [long]::TryParse([string]$TagPayload.meta.count, [ref]$reportedCount) -or
        $reportedCount -ne $tags.Count) {
        throw "tia-create GetTags count mismatch: meta.count reports $([string]$TagPayload.meta.count), payload has $($tags.Count)."
    }
    foreach ($tag in $tags) {
        if (-not (Test-TiaSclHasProperty -InputObject $tag -Name 'isSafety') -or $tag.isSafety -isnot [bool]) {
            throw "Tag '$([string]$tag.name)' has no explicit Safety classification."
        }
        if ($tag.isSafety) { throw "PLC tag '$([string]$tag.name)' is Safety; attached-route apply is blocked." }
    }
}

function Get-TiaSourceLineDelta {
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string]$OriginalText,
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string]$ProposedText
    )

    # Delta simetrico por linea (trim final, saltos normalizados). Con conteo por
    # linea: duplicar una linea y borrar otra distinta es un cambio real, no ruido.
    $originalCounts = @{}
    foreach ($line in @((ConvertTo-TiaComparableSource $OriginalText).Split("`n"))) {
        $key = $line.TrimEnd()
        $originalCounts[$key] = 1 + [int](Get-TiaSourceLineDeltaDictionaryValue $originalCounts $key)
    }
    $proposedCounts = @{}
    foreach ($line in @((ConvertTo-TiaComparableSource $ProposedText).Split("`n"))) {
        $key = $line.TrimEnd()
        $proposedCounts[$key] = 1 + [int](Get-TiaSourceLineDeltaDictionaryValue $proposedCounts $key)
    }
    $keys = @($originalCounts.Keys + $proposedCounts.Keys | Sort-Object -Unique)
    $added = @(); $removed = @()
    foreach ($key in $keys) {
        $originalCount = [int](Get-TiaSourceLineDeltaDictionaryValue $originalCounts $key)
        $proposedCount = [int](Get-TiaSourceLineDeltaDictionaryValue $proposedCounts $key)
        if ($proposedCount -gt $originalCount) { $added += $key }
        elseif ($originalCount -gt $proposedCount) { $removed += $key }
    }
    return [pscustomobject]@{
        added = $added
        removed = $removed
        changedCount = ($added.Count + $removed.Count)
    }
}

function Get-TiaSourceLineDeltaDictionaryValue($Hashtable, $Key) {
    if ($Hashtable.ContainsKey($Key)) { return $Hashtable[$Key] }
    return 0
}

function Assert-TiaProposalNotHeaderOnly {
    param(
        [Parameter(Mandatory = $true)] [object]$SourceDelta,
        [Parameter(Mandatory = $true)] [string]$BlockName
    )

    # Evidencia en vivo 2026-10-28 (runbook paso 8): Openness V20 ignora la cabecera
    # VERSION de la fuente estagiada en GenerateBlocksFromExternalSource; el proyecto
    # regenera 'VERSION : 0.1' aunque el import recibiera 'VERSION : 0.2'. Una propuesta
    # cuyo delta completo sean atributos VERSION no produce efecto observable y antes de
    # la puerta de readback declaraba exito igual. Se veto en la validacion local, antes
    # de abrir cualquier sesion MCP. Solo VERSION esta demostrado; otros atributos no se
    # vetan por falta de evidencia (falsos positivos).
    $sourceDelta = $SourceDelta
    if (-not $sourceDelta -or (Test-TiaSclHasProperty -InputObject $sourceDelta -Name 'added') -eq $false) {
        throw 'Header-only veto requires a Get-TiaSourceLineDelta result.'
    }
    if ($sourceDelta.changedCount -eq 0) { return }
    $versionPattern = '(?i)^\s*VERSION\s*:'
    $nonVersionLines = @(@($sourceDelta.added) + @($sourceDelta.removed) | Where-Object { $_ -notmatch $versionPattern })
    if ($nonVersionLines.Count -eq 0) {
        throw "Proposal '$BlockName' changes only VERSION header attributes; Openness V20 ignores them on block regeneration (evidence 2026-10-28). Refuse this proposal: version the block via TIA Portal or propose a real code/interface change."
    }
}

function ConvertTo-TiaComparableSource {
    param([Parameter(Mandatory = $true)] [AllowEmptyString()] [string]$Text)
    if ($Text.Length -gt 0 -and $Text[0] -eq [char]0xFEFF) { $Text = $Text.Substring(1) }
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Assert-TiaSclImportCapability {
    param(
        [Parameter(Mandatory = $true)] [object]$ToolListPayload,
        [Parameter(Mandatory = $true)] [string]$RequiredTool
    )

    if (-not (Test-TiaSclHasProperty -InputObject $ToolListPayload -Name 'tools') -or $null -eq $ToolListPayload.tools) {
        throw 'The active MCP server did not return a tools collection; import capability is unknown.'
    }
    $toolNames = @($ToolListPayload.tools | ForEach-Object {
        if (Test-TiaSclHasProperty -InputObject $_ -Name 'name') { [string]$_.name }
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($toolNames -notcontains $RequiredTool) {
        throw "Required import tool '$RequiredTool' is not registered in the active MCP profile. No TIA mutation was attempted."
    }
}

function Assert-TiaSclImportResult {
    param(
        [Parameter(Mandatory = $true)] [object]$ImportPayload,
        [Parameter(Mandatory = $true)] [string]$ExpectedName,
        [Parameter(Mandatory = $true)] [string]$ExpectedPath
    )

    if (-not (Test-TiaSclHasProperty -InputObject $ImportPayload -Name 'meta') -or
        -not (Test-TiaSclHasProperty -InputObject $ImportPayload.meta -Name 'success') -or
        $ImportPayload.meta.success -ne $true) {
        throw 'ImportSources did not report a successful response.'
    }
    if (-not (Test-TiaSclHasProperty -InputObject $ImportPayload -Name 'failures') -or $null -eq $ImportPayload.failures) {
        throw 'ImportSources response is missing its per-file failures collection.'
    }
    if (@($ImportPayload.failures).Count -ne 0) { throw "ImportSources reported $(@($ImportPayload.failures).Count) per-file failure(s)." }
    if (-not (Test-TiaSclHasProperty -InputObject $ImportPayload -Name 'items') -or $null -eq $ImportPayload.items) {
        throw 'ImportSources response is missing its generated objects collection.'
    }

    $items = @($ImportPayload.items)
    if ($items.Count -ne 1) { throw "ImportSources must generate exactly one object; found $($items.Count)." }
    $item = $items[0]
    foreach ($property in @('name', 'path', 'kind')) {
        if (-not (Test-TiaSclHasProperty -InputObject $item -Name $property)) { throw "ImportSources item is missing '$property'." }
    }
    if ([string]$item.name -ine $ExpectedName -or [string]$item.path -cne $ExpectedPath -or [string]$item.kind -cne 'block') {
        throw 'ImportSources generated an object that does not exactly match the requested block.'
    }

    if (-not (Test-TiaSclHasProperty -InputObject $ImportPayload -Name 'written') -or $null -eq $ImportPayload.written) {
        throw 'ImportSources response is missing exact written-object counts.'
    }
    $written = $ImportPayload.written
    $writtenCounts = @{}
    foreach ($property in @('blocks', 'types')) {
        if (-not (Test-TiaSclHasProperty -InputObject $written -Name $property) -or
            $written.$property -isnot [ValueType] -or $written.$property -is [bool]) {
            throw "ImportSources written counts are incomplete: missing numeric '$property'."
        }
        $parsedCount = 0L
        if (-not [long]::TryParse([string]$written.$property, [ref]$parsedCount)) {
            throw "ImportSources written count '$property' is not an integer."
        }
        $writtenCounts[$property] = $parsedCount
    }
    if ($writtenCounts.blocks -ne 1) {
        throw 'ImportSources must report exactly one written block.'
    }
    if ($writtenCounts.types -ne 0) {
        throw 'ImportSources must report zero written PLC types.'
    }
}
