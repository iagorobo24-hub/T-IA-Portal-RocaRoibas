[CmdletBinding()]
param(
    [string[]]$ManifestPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$capabilityRoot = Join-Path $workspaceRoot '70-runs\tia-capabilities'

if (-not $ManifestPath -or $ManifestPath.Count -eq 0) {
    $ManifestPath = @(
        (Join-Path $capabilityRoot '20260921-04-write-tools-live.json'),
        (Join-Path $capabilityRoot '20260921-05-read-tools-live.json'),
        (Join-Path $capabilityRoot '20260921-06-create-lite-tools-live.json'),
        (Join-Path $capabilityRoot '20260921-07-create-full-tools-live.json')
    )
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $capabilityRoot '20260922-live-tool-matrix.md'
}
if (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $workspaceRoot $OutputPath
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)

function ConvertTo-MdCell {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return '—'
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return '—'
    }

    return ($text -replace '\|', '\\|') -replace '[\r\n]+', ' '
}

function Get-ProfileInfo {
    param([string]$FileName)

    switch -Regex ($FileName) {
        '04-write' { return [pscustomobject]@{ Name = 'tia-inspect / write (aislado)'; Key = 'inspect-write' } }
        '05-read' { return [pscustomobject]@{ Name = 'tia-inspect / read'; Key = 'inspect-read' } }
        '06-create-lite' { return [pscustomobject]@{ Name = 'tia-create / lite'; Key = 'create-lite' } }
        '07-create-full' { return [pscustomobject]@{ Name = 'tia-create / full'; Key = 'create-full' } }
        default { return [pscustomobject]@{ Name = $FileName; Key = $FileName } }
    }
}

function Get-TypeName {
    param([AllowNull()][object]$Schema)

    if ($null -eq $Schema) {
        return '?'
    }

    $typeProperty = $Schema.PSObject.Properties['type']
    if ($typeProperty -and $typeProperty.Value -is [System.Array]) {
        return (($typeProperty.Value | ForEach-Object { [string]$_ }) -join '|')
    }

    if ($typeProperty -and $null -ne $typeProperty.Value) {
        return [string]$typeProperty.Value
    }

    if ($Schema.PSObject.Properties['oneOf']) {
        return 'oneOf'
    }

    return '?'
}

function Get-InputSummary {
    param([AllowNull()][object]$Tool)

    if ($null -eq $Tool -or $null -eq $Tool.inputSchema) {
        return 'req: —; opt: —'
    }

    $required = @()
    if ($Tool.inputSchema.PSObject.Properties['required'] -and $null -ne $Tool.inputSchema.required) {
        $required = @($Tool.inputSchema.required | ForEach-Object { [string]$_ })
    }

    $requiredItems = @()
    $optionalItems = @()
    $properties = @()
    if ($Tool.inputSchema.PSObject.Properties['properties'] -and $null -ne $Tool.inputSchema.properties) {
        $properties = @($Tool.inputSchema.properties.PSObject.Properties)
    }

    foreach ($property in $properties) {
        $schema = $property.Value
        $entry = '{0}:{1}' -f $property.Name, (Get-TypeName $schema)
        if ($schema.PSObject.Properties['default']) {
            $default = $schema.default
            if ($null -eq $default) {
                $entry += '=null'
            } elseif ($default -is [bool]) {
                $entry += '='+$default.ToString().ToLowerInvariant()
            } else {
                $entry += '='+([string]$default)
            }
        }

        if ($required -contains $property.Name) {
            $requiredItems += $entry
        } else {
            $optionalItems += $entry
        }
    }

    $requiredText = if ($requiredItems.Count -gt 0) { $requiredItems -join ', ' } else { '—' }
    $optionalText = if ($optionalItems.Count -gt 0) { $optionalItems -join ', ' } else { '—' }
    return ('req: {0}; opt: {1}' -f $requiredText, $optionalText)
}

function Get-Risk {
    param([AllowNull()][object]$Tool)

    $name = ([string]$Tool.name).ToLowerInvariant()
    $description = ([string]$Tool.description).ToLowerInvariant()
    $annotations = $Tool.annotations

    if ($name -match 'download|goonline|setwatchtablemodifyvalue|force|write.*live|modify.*value' -or
        $description -match 'physical plc|download.*plc|forced value|write plc value|write.*online') {
        return 'R4'
    }

    if ($name -match 'invoke(service|object)|calltool') {
        return 'R4'
    }

    if ($name -match 'read.*live|sample.*live|monitor.*live|probe.*cpu|probe.*monitor|watchtable.*current|trace.*live|compare.*online|online.*state|runstate.*s7|gooffline') {
        return 'R3'
    }

    if (($annotations -and $annotations.destructiveHint -eq $true) -or
        $name -match 'create|delete|import|export|save|add|set|update|rename|move|plug|apply|ensure|scaffold|write|repair|clear.*export|connect.*subnet|attach.*subnet') {
        return 'R2'
    }

    if (($annotations -and $annotations.readOnlyHint -eq $true) -or
        $name -match 'get|list|find|describe|doctor|validate|analy[sz]e|plan|probe|search|resolve|whereused|check|build|compose|dump|compare|trace|bootstrap') {
        if ($description -match 'project|plc|hmi|device|software|requires:\s*connect|openproject') {
            return 'R1'
        }
        return 'R0'
    }

    return 'R1'
}

function Get-Precondition {
    param(
        [AllowNull()][object]$Tool,
        [string]$Risk
    )

    $name = [string]$Tool.name
    $description = [string]$Tool.description
    $lowerName = $name.ToLowerInvariant()

    $match = [regex]::Match($description, '(?i)\[PreCondition:([^\]]+)\]')
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    $match = [regex]::Match($description, '(?i)Requires:\s*([^\.]+)')
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    if ($lowerName -eq 'doctor' -or $lowerName -match 'selftest|acceptancereport|generateerrorreport') {
        return 'Local/read-only; no project connection unless the description explicitly requests it'
    }

    if ($lowerName -eq 'bootstrap') {
        return 'Fresh MCP session; acquire the single-session lease'
    }

    if ($lowerName -match '^connect(isolated)?$') {
        return 'Doctor; verify no foreign TIA project; choose attach/isolate deliberately'
    }

    if ($lowerName -eq 'openproject' -or $lowerName -eq 'opentia project') {
        return 'Connect; exact .ap20/.als20 path; refuse foreign project unless explicitly authorized'
    }

    if ($lowerName -eq 'createproject') {
        return 'Connect; target directory/name; no foreign project; dryRun where offered'
    }

    if ($lowerName -match 'calltool|findtools|invokeservice|invokeobject') {
        return 'Discover exact name/signature first; apply profile, fixture, safety and backup gates before mutation'
    }

    if ($lowerName -match 'download') {
        return 'Doctor + Connect + OpenProject; identify target as disposable PLCSIM or obtain fresh physical confirmation; readiness gate'
    }

    if ($lowerName -match 'read.*live|sample.*live|monitor.*live|probe.*cpu|goonline|gooffline|watchtable.*current|trace.*live') {
        return 'Connect + OpenProject; identify PLC/adapter/rack/slot; read-only online gate and explicit target evidence'
    }

    if ($Risk -eq 'R2' -or $Risk -eq 'R4') {
        return 'Connected exact target; path from GetProjectTree/GetSoftwareTree; backup + preview/dryRun when offered + safety/protection preflight; compile/readback before save'
    }

    if ($description -match '(?i)project|plc|hmi|device|software') {
        return 'Connect + OpenProject if project data is required; paths from GetProjectTree/GetSoftwareTree'
    }

    return 'No project precondition stated; verify the schema and tool description before use'
}

function Get-EvidenceStatus {
    param([string]$ProfileKey, [string]$ToolName)

    switch ($ProfileKey) {
        'inspect-read' {
            if ($ToolName -in @('Doctor','Connect','OpenProject','GetProjectTree','GetSoftwareTree','GetBlocks','GetTags','GetBlockSource','CompileSoftware')) {
                return 'Fixture: ejecutado en clon; ver secuencia de fixture'
            }
        }
        'create-lite' {
            if ($ToolName -in @('FindTools','CallTool')) {
                return 'Fixture: descubrimiento dinámico ejecutado'
            }
            if ($ToolName -eq 'PlcBuildAndImport') {
                return 'Preview aprobado; apply bloqueado por cultura, sin importación'
            }
            if ($ToolName -in @('CompileSoftware','SaveProject')) {
                return 'Fixture: compile 0/0 y guardado en ruta SCL alternativa'
            }
            if ($ToolName -eq 'ExportAsDocuments') {
                return 'Fixture: error tipado EngineeringNotSupportedException'
            }
        }
    }

    return 'Esquema: tools/list; llamada no probada en esta captura'
}

$manifestRows = @()
foreach ($path in $ManifestPath) {
    $resolved = (Resolve-Path $path).Path
    $manifest = Get-Content -Raw $resolved | ConvertFrom-Json
    $profile = Get-ProfileInfo ([IO.Path]::GetFileName($resolved))
    $toolsList = @($manifest.calls | Where-Object { $_.name -eq 'tools/list' } | ForEach-Object { $_.response.tools })
    if (-not $manifest.success -or $toolsList.Count -eq 0) {
        throw "Manifesto inválido o sin tools/list: $resolved"
    }

    $manifestRows += [pscustomobject]@{
        Path = $resolved
        FileName = [IO.Path]::GetFileName($resolved)
        Manifest = $manifest
        Profile = $profile
        Tools = $toolsList
        Hash = (Get-FileHash -Algorithm SHA256 $resolved).Hash
    }
}

$outDirectory = Split-Path -Parent $OutputPath
if ($outDirectory -and -not (Test-Path $outDirectory)) {
    New-Item -ItemType Directory -Path $outDirectory -Force | Out-Null
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Matriz live de capacidades MCP de TIA-Claude')
$lines.Add('')
$lines.Add('**Generada:** 2026-09-22 a partir de cuatro capturas `tools/list` live del 2026-09-21.')
$lines.Add('**Estado de la matriz:** inventario actual de schemas. Una fila `Esquema` demuestra presencia y firma en `tools/list`; no demuestra que la llamada funcione en un proyecto ni autoriza su uso.')
$lines.Add('')
$lines.Add('Esta matriz es un artefacto de descubrimiento. Toda mutación sigue el contrato de [AGENTS.md](../../AGENTS.md): Doctor, identificación del proyecto, rutas obtenidas del árbol, backup, preview/dryRun cuando se ofrezca, preflight de protección y Safety, cambio mínimo, compilación y lectura posterior.')
$lines.Add('')
$lines.Add('## Escala')
$lines.Add('')
$lines.Add('| Riesgo | Lectura operativa |')
$lines.Add('|---|---|')
$lines.Add('| R0 | Diagnóstico, planificación o comprobación local de solo lectura. |')
$lines.Add('| R1 | Lectura de proyecto/objeto; exige rutas y contexto exactos. |')
$lines.Add('| R2 | Mutación de proyecto o escritura de archivos; exige backup, preview/dryRun cuando se ofrezca y compile/readback. |')
$lines.Add('| R3 | Estado online, monitorización o interacción con un target; exige identidad del target y sesión segura. |')
$lines.Add('| R4 | Descarga, escritura online, valores forzados o bridge dinámico; requiere una barrera específica y autorización aplicable. |')
$lines.Add('')
$lines.Add('## Resumen de capturas')
$lines.Add('')
$lines.Add('| Perfil | Herramientas | SHA-256 | Argumentos de la captura | Evidencia |')
$lines.Add('|---|---:|---|---|---|')

foreach ($row in $manifestRows) {
    $relativeJson = [IO.Path]::GetFileName($row.Path)
    $profileName = $row.Profile.Name
    $evidence = if ($row.Profile.Key -eq 'create-lite') { 'Schema + algunas llamadas de fixture separadas' } else { 'Schema-only en esta captura' }
    $args = ConvertTo-MdCell $row.Manifest.arguments
    $lines.Add([string]::Format('| {0} | {1} | `{2}` | `{3}` | {4} ([JSON](./{5})) |', $profileName, $row.Tools.Count, $row.Hash, $args, $evidence, $relativeJson))
}

$lines.Add('')
$lines.Add('**Mapeo Siemens Openness:** no probado de forma independiente; estas filas describen la capa MCP y no asignan automáticamente una herramienta a un miembro de `Siemens.Engineering`.')
$lines.Add('')
$lines.Add('**Computer Use:** no forma parte de estos manifests. La disponibilidad nativa y la identidad de la ventana TIA se verifican en la fase gráfica final mediante el harness nativo; `mcp__cua_repl` solo cubre navegador.')
$lines.Add('')
$lines.Add('## Herramientas por perfil')

foreach ($row in $manifestRows) {
    $lines.Add('')
    $lines.Add('### {0}' -f $row.Profile.Name)
    $lines.Add('')
    $lines.Add('Fuente: [{0}](./{0})' -f $row.FileName)
    $lines.Add('')
    $lines.Add('| Herramienta | Parámetros del schema | Riesgo | Precondición operativa | Estado local |')
    $lines.Add('|---|---|---|---|---|')

    foreach ($tool in ($row.Tools | Sort-Object name)) {
        $toolName = ConvertTo-MdCell $tool.name
        $inputs = ConvertTo-MdCell (Get-InputSummary $tool)
        $risk = Get-Risk $tool
        $precondition = ConvertTo-MdCell (Get-Precondition $tool $risk)
        $status = ConvertTo-MdCell (Get-EvidenceStatus $row.Profile.Key ([string]$tool.name))
        $lines.Add([string]::Format('| `{0}` | {1} | {2} | {3} | {4} |', $toolName, $inputs, $risk, $precondition, $status))
    }
}

$lines.Add('')
$lines.Add('## Lectura de la matriz')
$lines.Add('')
$lines.Add('- El roster write aislado contiene 84 herramientas y el read contiene 53; ninguno publica `ImportSources` ni `ImportFromDocuments` en la captura live.')
$lines.Add('- `tia-create / lite` contiene 55 herramientas y `tia-create / full` contiene 222. La presencia de importadores, hardware, HMI u online en `full` es schema-only y no se transfiere a `lite`.')
$lines.Add('- `CallTool`, `InvokeService` e `InvokeObject` son bridges dinámicos. Su fila no convierte un nombre descubierto en capacidad aprobada: primero hay que obtener la firma exacta y aplicar el gate del perfil y del objeto.')
$lines.Add('- Las filas con evidencia de fixture remiten a una operación concreta; no elevan el resto del perfil ni prueban PLCSIM, Runtime, hardware físico o una llamada Openness directa.')

[IO.File]::WriteAllLines($OutputPath, $lines, [Text.UTF8Encoding]::new($false))
Write-Output ([pscustomobject]@{
    outputPath = $OutputPath
    profiles = @($manifestRows | ForEach-Object { [pscustomobject]@{ name=$_.Profile.Name; tools=$_.Tools.Count; hash=$_.Hash } })
    totalRows = ($manifestRows | ForEach-Object { $_.Tools.Count } | Measure-Object -Sum).Sum
})
