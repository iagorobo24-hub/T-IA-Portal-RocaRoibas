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
