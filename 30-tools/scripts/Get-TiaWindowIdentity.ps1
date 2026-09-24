<#
.SYNOPSIS
    Identifica las ventanas de TIA Portal abiertas y qué proyecto muestra cada una, por
    UIAutomation de Windows. Solo lectura: no hace clic, no escribe y no cierra nada.

.DESCRIPTION
    AGENTS.md 3.5 exige identificar el proyecto y la versión de una ventana TIA visible antes de
    conectar por Openness. En Codex eso se hacía con el plugin nativo `computer-use`. Este script
    cubre la misma necesidad sin ese plugin y sin captura de pantalla: UIAutomation es la API de
    accesibilidad de Windows y expone el título y el árbol de controles de cualquier ventana.

    El título de TIA Portal contiene el nombre del proyecto abierto, así que basta para decidir si
    una instancia es la esperada, es ajena, o no tiene proyecto.

    Limitaciones conocidas, por diseño:
      - No sustituye a una inspección visual: no ve LAD, ni el aspecto de una pantalla HMI.
      - No distingue la versión de TIA por el título; para eso usa Doctor o el proceso.
      - Una instancia headless (WithoutUserInterface) NO tiene ventana y no aparece aquí. Eso es
        correcto: las instancias aisladas del agente son precisamente las que no deben confundirse
        con una ventana del usuario.

.PARAMETER Detailed
    Además del título, vuelca los primeros niveles del árbol de controles de cada ventana TIA.

.PARAMETER OutputPath
    Guarda el resultado como JSON.

.EXAMPLE
    .\Get-TiaWindowIdentity.ps1
    .\Get-TiaWindowIdentity.ps1 -Detailed -OutputPath 70-runs\tia-windows.json
#>
[CmdletBinding()]
param(
    [switch]$Detailed,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

# Los procesos que pueden tener una ventana de TIA Portal con proyecto.
$tiaProcessNames = @('Siemens.Automation.Portal', 'Siemens.Automation.ObjectFrame')

$root = [Windows.Automation.AutomationElement]::RootElement
$windowCondition = New-Object Windows.Automation.PropertyCondition(
    [Windows.Automation.AutomationElement]::ControlTypeProperty,
    [Windows.Automation.ControlType]::Window)
$windows = $root.FindAll([Windows.Automation.TreeScope]::Children, $windowCondition)

$found = @()
foreach ($window in $windows) {
    $processId = $window.Current.ProcessId
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if (-not $process) { continue }
    if ($tiaProcessNames -notcontains $process.ProcessName) { continue }

    $title = $window.Current.Name
    # TIA titula "<Proyecto> - Siemens - <ruta>" o solo "Siemens" cuando no hay proyecto abierto.
    $hasProject = $title -and ($title -notmatch '^\s*Siemens\s*$')
    $projectName = if ($hasProject -and $title -match '^(.+?)\s+-\s+Siemens') { $Matches[1].Trim() } else { $null }

    $entry = [ordered]@{
        processName  = $process.ProcessName
        processId    = $processId
        windowTitle  = $title
        hasProject   = [bool]$hasProject
        projectName  = $projectName
        className    = $window.Current.ClassName
        isEnabled    = $window.Current.IsEnabled
        boundingRect = "$($window.Current.BoundingRectangle)"
    }

    if ($Detailed) {
        $descendants = $window.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition)
        $names = @()
        foreach ($element in $descendants) {
            $name = $element.Current.Name
            if ($name -and $name.Trim()) {
                $names += [ordered]@{
                    controlType = $element.Current.ControlType.ProgrammaticName.Replace('ControlType.', '')
                    name        = $name
                }
            }
            if ($names.Count -ge 200) { break }
        }
        $entry.elementCount = $descendants.Count
        $entry.elements = $names
    }

    $found += [pscustomobject]$entry
}

$report = [ordered]@{
    schemaVersion   = 1
    generatedAt     = [DateTimeOffset]::Now.ToString('o')
    hostname        = $env:COMPUTERNAME
    method          = 'UIAutomation (System.Windows.Automation); read-only, sin captura de pantalla'
    tiaWindowCount  = $found.Count
    windows         = $found
    interpretation  = if ($found.Count -eq 0) {
        'No hay ninguna ventana de TIA Portal visible. Una instancia headless del agente no aparece aqui por diseño.'
    } elseif (($found | Where-Object { $_.hasProject }).Count -eq 0) {
        'Hay TIA Portal abierto sin proyecto. Confirmar con el usuario antes de conectar.'
    } else {
        'Hay al menos una ventana de TIA con proyecto abierto. NO conectar ni abrir otra instancia sin confirmar que es el objetivo (AGENTS.md 3.5).'
    }
}

if ($OutputPath) {
    $directory = Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath))
    if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-Output "Informe escrito en $OutputPath"
}

$report | ConvertTo-Json -Depth 4
