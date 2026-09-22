function Get-TiaBlockCommentMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$XmlPath
    )

    $XmlPath = [IO.Path]::GetFullPath($XmlPath)
    if (-not (Test-Path -LiteralPath $XmlPath -PathType Leaf)) {
        throw "Block XML does not exist: $XmlPath"
    }

    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create($XmlPath, $settings)
    try {
        $document = [System.Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.Load($reader)
    }
    finally {
        $reader.Dispose()
    }

    $blockNode = $document.SelectSingleNode('//*[starts-with(local-name(), "SW.Blocks.")][1]')
    if (-not $blockNode) {
        return [pscustomobject]@{
            blockName = $null
            status = 'unverified'
            hasComment = $null
            encodingStatus = 'unknown'
            cultures = @()
        }
    }

    $nameNode = $blockNode.SelectSingleNode('./AttributeList/Name')
    $commentNode = $blockNode.SelectSingleNode('./ObjectList/MultilingualText[@CompositionName="Comment"]')
    if (-not $commentNode) {
        return [pscustomobject]@{
            blockName = if ($nameNode) { [string]$nameNode.InnerText } else { $null }
            status = 'verified-missing'
            hasComment = $false
            encodingStatus = 'not-applicable'
            cultures = @()
        }
    }

    $texts = @($commentNode.SelectNodes('.//*[local-name()="Text"]') | ForEach-Object { [string]$_.InnerText })
    $nonEmptyTexts = @($texts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($nonEmptyTexts.Count -eq 0) {
        return [pscustomobject]@{
            blockName = if ($nameNode) { [string]$nameNode.InnerText } else { $null }
            status = 'verified-missing'
            hasComment = $false
            encodingStatus = 'not-applicable'
            cultures = @($commentNode.SelectNodes('.//*[local-name()="Culture"]') | ForEach-Object { [string]$_.InnerText } | Select-Object -Unique)
        }
    }

    $allCommentText = $nonEmptyTexts -join "`n"
    $suspectMojibake = $allCommentText -match '[\u00C2\u00C3][\u0080-\u00FF]|\uFFFD'
    [pscustomobject]@{
        blockName = if ($nameNode) { [string]$nameNode.InnerText } else { $null }
        status = 'verified-present'
        hasComment = $true
        encodingStatus = if ($suspectMojibake) { 'suspect' } else { 'clean' }
        cultures = @($commentNode.SelectNodes('.//*[local-name()="Culture"]') | ForEach-Object { [string]$_.InnerText } | Select-Object -Unique)
    }
}
