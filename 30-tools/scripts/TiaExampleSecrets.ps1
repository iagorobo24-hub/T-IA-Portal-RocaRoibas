function Find-TiaExampleJwtLikeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$RootPath
    )

    $ErrorActionPreference = 'Stop'
    $extensions = @('.json', '.xml', '.md', '.txt', '.yaml', '.yml', '.js', '.py', '.scl', '.s7dcl', '.csv')
    $jwtPattern = '(?i)(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}(?![A-Za-z0-9_-])'

    foreach ($inputPath in $RootPath) {
        $resolved = [IO.Path]::GetFullPath($inputPath)
        if (-not (Test-Path -LiteralPath $resolved)) { throw "Secret scan path does not exist: $resolved" }
        $files = if (Test-Path -LiteralPath $resolved -PathType Leaf) {
            @(Get-Item -LiteralPath $resolved)
        }
        else {
            @(Get-ChildItem -LiteralPath $resolved -File -Recurse -Force | Where-Object {
                $_.Length -le 20MB -and $_.Extension.ToLowerInvariant() -in $extensions
            })
        }

        foreach ($file in $files) {
            if ($file.Length -gt 20MB -or $file.Extension.ToLowerInvariant() -notin $extensions) { continue }
            $text = [IO.File]::ReadAllText($file.FullName)
            $matches = [regex]::Matches($text, $jwtPattern)
            if ($matches.Count -gt 0) {
                [pscustomobject]@{
                    path = $file.FullName
                    finding = 'JWT-like credential'
                    count = $matches.Count
                }
            }
        }
    }
}
