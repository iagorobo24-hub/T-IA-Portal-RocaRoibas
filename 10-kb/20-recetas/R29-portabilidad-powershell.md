# R29 · Portabilidad de los scripts de PowerShell y de los arneses de prueba

> Lo que hay que respetar para que un script de este workspace funcione igual con
> PowerShell 7 (pwsh) y con Windows PowerShell 5.1, y para que un arnes de pruebas
> no se quede viejo cuando el runner endurece una puerta.

## Por que importa

El CI ejecuta `Run-WorkspaceChecks.ps1 -CiSafe` con **pwsh 7**. Un host de trabajo puede
tener solo Windows PowerShell 5.1. Las diferencias no son academicas: rompen el codigo de
forma opaca y, en el peor caso, **desactivan un gate de seguridad sin que nadie lo note**.

Medido el 2026-10-21 al arreglar dos tests que tenian el CI en rojo.

## Las cuatro diferencias que muerden

### 1. `$PSScriptRoot` en el bloque `param` esta vacio en 5.1

```powershell
# NO: en Windows PowerShell 5.1 $PSScriptRoot todavia no esta definido aqui.
param([string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)

# SI: el valor por defecto se resuelve en el cuerpo.
param([string]$WorkspaceRoot)
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    $WorkspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}
```

El sintoma es `Join-Path : no se puede enlazar el argumento con el parametro 'Path' porque es
una cadena vacia`, en la linea 3, antes de que el script haga nada.

### 2. Un `.ps1` sin BOM se lee como ANSI en 5.1, y el mojibake rompe el parser

Windows PowerShell 5.1 lee un `.ps1` **sin BOM** como Windows-1252. PowerShell 7 lo lee como
UTF-8. La diferencia solo importa si el fichero tiene caracteres no ASCII, y entonces el
script **no falla de forma visible**:

```
'GetSoftwareTree' { ... tree = "Fixture PLC`n└── Main [OB]" ... }
```

leido como ANSI, `└──` (U+2514 U+2500) se convierte en `â””â”€â”€`, que contiene **comillas
tipograficas U+201D**. El parser de PowerShell acepta esas comillas como delimitadores de
cadena, asi que la cadena termina antes de tiempo y el error que sale es:

```
Token 'â”€ Main [OB]"' inesperado en la expresion o la instruccion.
El literal de hash estaba incompleto.
```

Es el fallo mas peligroso de los cuatro: el sintoma apunta al codigo y no a la codificacion,
y en pwsh 7 **no aparece**.

**Regla**: un script que se escribe a disco y luego se ejecuta (fixture MCP, adaptador,
servidor) debe ser **ASCII puro**. Si hace falta un arbol, usa `|--` en vez de glifos de caja.
Los `.md` y los `.json` no tienen ese problema.

### 3. `ConvertFrom-Json -AsHashtable` no existe en 5.1

Es PowerShell 6+. Si un test declara un fallback a `powershell.exe`, ese fallback esta roto
mientras el test use `-AsHashtable`. El equivalente que funciona en ambos:

```powershell
$json = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
$json.gates.PSObject.Properties.Remove('tiaInstanceSafeForApply')   # en vez de $json.gates.Remove(...)
$json.gates.tiaInstanceSafeForApply = $false
```

El JSON resultante es identico en los dos casos.

### 4. No supongas que `pwsh.exe` esta en `$PSHOME`

`Join-Path $PSHOME 'pwsh.exe'` solo es cierto bajo PowerShell 7. Para lanzar **el** PowerShell
que esta ejecutando el script:

```powershell
$hostExe = (Get-Process -Id $PID).Path
```

## Reglas de puerta: el gate va antes del toolchain

Un gate de seguridad tiene que evaluarse **antes** de comprobar si el binario existe. Si el
orden es el contrario, el error del toolchain enmascara el del gate y **el gate deja de ser
comprobable**: en el CI, donde `bin/` no esta versionado, el test veia "No existe TiaMcpServer.exe"
en vez de "manifiesto invalido", y el test de seguridad fallaba por un motivo que no era el suyo.

```powershell
# Primero: entradas y permisos.
if ($Isolated) { $null = & $manifestValidator -FixtureRoot $FixtureRoot }
# Despues: toolchain.
if (-not (Test-Path $exe)) { throw "No existe $exe..." }
```

## Cuando el runner endurece una puerta, el arnes se queda viejo

`Invoke-TiaSimulationAcceptance.ps1` exige, desde `d25e399`, que la descarga vaya precedida de
`-SimulationTargetEvidencePath`: evidencia de que el destino es una CPU simulada, con
`schemaVersion=1`, `source=native-computer-use`, `confirmed=true`, el `projectFile`,
`projectName` y `devicePath` **exactos** de esa ejecucion, `tiaMajorVersion` coherente con el
readiness, la `pgPcInterface` de ese transporte, `targetDisplayName=CPU-1500 Simulation`,
`windowState=maximized`, `stage=before-download`, el aviso de CPU simulada, la misma
`targetIpAddress` y un `observedAt` de **menos de 30 minutos**.

Un arnes que llama al runner **tiene que proporcionar esa evidencia**. Si el destino del
arnes es un fixture MCP simulado, la evidencia tambien es de fixture, pero con las mismas
claves y la misma caducidad. Si no, el runner corta antes de la puerta que el test quiere
ejercitar y el test falla mirando un motivo equivocado.

Este caso se dio entero: el test fallaba en el caso de "error de compilacion" pero el motivo
real era `Falta -SimulationTargetEvidencePath`. La asercion del test no era incorrecta; le
faltaba una precondicion al arnes.

## Como comprobarlo sin CI

```powershell
# El job completo del CI, en local.
pwsh -NoProfile -NonInteractive -File .\30-tools\scripts\Run-WorkspaceChecks.ps1 `
    -CiSafe -OutputPath .\70-runs\checks\ci-latest.json
```

Con `-CiSafe` el runner se salta los checks que necesitan PLCSIM elevado, artefactos locales
y rutas de otra maquina. Sin el, aparecen BLOCKED que **no** son fallos de este workspace
(`plcsim-api-probe` y `plcsim-native-adapter` necesitan sesion elevada: la API de PLCSIM
Advanced no inicializa sin privilegios).

## PowerShell 7 en un host que solo tiene 5.1

```powershell
winget install --id Microsoft.PowerShell --exact --silent
```

Deja `pwsh` en el PATH (alias en `WindowsApps`). Con el, se ejecutan tambien los tests que
antes no eran ejecutables en el host: `Test-WorkspaceChecks.ps1`,
`Test-McpSessionLease.ps1`, `Test-McpToolSequenceStderrCapture.ps1` y
`Test-StandardsSweep.ps1`.
