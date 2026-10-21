# R30 · Crear un proyecto TIA completo desde un spec

> Cómo pasar de una frase a un proyecto V20 con CPU, HMI, tags, bloques compilados, pantalla de
> operación y export, sin intervención manual.

## La idea: un spec, y el resto sale

Un proyecto no se "escribe": se **declara**. Todo lo que el runner necesita cabe en un JSON
(`specs/scaffold.json`) y una llamada lo crea:

```json
{
  "projectName": "DEMO-Cinta01",
  "directoryPath": "<ruta donde vive el proyecto>",
  "plcName": "PLC_1",
  "plcFamily": "S7-1500",
  "plcMlfb": "6ES7 513-1AM03-0AB0",
  "hmiName": "HMI_RT_1",
  "hmiFamily": "WinCCUnifiedPC",
  "hmiSoftwarePath": "HMI_RT_1",
  "connectionName": "HMI_Connection_1",
  "tagTable":  [ { "tableName": "Cinta_Signals", "tags": [ { "name": "DI_M01_Start", "dataTypeName": "Bool", "logicalAddress": "%M0.1" } ] } ],
  "sclSourceFiles": [ "<ruta>/sources/FB_Motor.scl", "<ruta>/sources/OB_Main.scl" ],
  "hmiTags": [ { "tagTableName": "HMI_Tags", "tagName": "StartPB", "plcTag": "DI_M01_Start", "address": "%M0.1" } ],
  "compile": true,
  "save": true
}
```

Claves que el spec **no** tiene y se resuelven aparte:

- **La pantalla HMI** va en su propio JSON (`hmi-screen.json`) y la aplica
  `Invoke-TiaHmiScreenFromJson.ps1`. El scaffold sabe crear hardware, conexión y tags de HMI, pero
  no los controles de una pantalla.
- **Los bindings** de botones y lámparas van en ese mismo JSON.

## El flujo completo

```powershell
# 1. Dry-run: valida el spec offline, no conecta con TIA ni crea nada.
.\30-tools\scripts\Invoke-AgentDemoScaffold.ps1 -SpecPath .\specs\scaffold.json

# 2. Crear. Con -Apply exige que el destino no exista y comprueba antes que no haya
#    ninguna TIA visible con un proyecto abierto.
.\30-tools\scripts\Invoke-AgentDemoScaffold.ps1 -SpecPath .\specs\scaffold.json -Apply

# 3. Pantalla HMI y bindings. Idempotente.
.\30-tools\scripts\Invoke-TiaHmiScreenFromJson.ps1 -ScreenJsonPath .\hmi-screen.json -ProjectFile <ap20>

# 4. Export e informe del compilador, y el verificador de estándares.
.\30-tools\scripts\Check-TiaStandards.ps1 -InventoryPath .\inventory.json -ExportPath .\src -OutputPath .\ops\standards.json
```

El post-apply del runner ya hace la inspección, el export y el `Check-TiaStandards` (exit 0).

## Las cuatro trampas, medidas el 2026-10-21

### 1. La carpeta del proyecto no puede pasar de 143 caracteres

```
The specified path '…\project\DEMO-Cinta01' (156 character) is too long.
A maximum of 143 characters is allowed.
```

En modo aislado la excepción se come y solo queda `Failed to open project`, sin decir por qué. El
runner copia el proyecto a una ruta **corta** bajo `%TEMP%` para la inspección, y avisa con el
número si la carpeta original se pasa.

### 2. El OB cíclico lo nombra TIA

Una fuente externa con `ORGANIZATION_BLOCK "OB_Main"` falla al generar:

```
Row 000000: Type conflict: Object "OB_Main" cannot be overwritten.
```

El nombre correcto es **`"Main"`**. El patrón `OB_<Función>` de `20-standards/naming.md` aplica
a los OB de arranque y de error, no al OB1 del sistema.

### 3. El DB de instancia se declara en la fuente SCL

```scl
DATA_BLOCK "iDB_M01"
{ S7_Optimized_Access := 'TRUE' }
VERSION : 0.1
   "FB_Motor"
END_DATA_BLOCK
```

Sin esa declaración, la llamada `"iDB_M01"(...)` se resuelve como un **tag** y la compilación
da 14 errores: *Tag "iDB_M01" not defined* y *The formal parameter 'CmdStart' is invalid* para
cada entrada.

### 4. El modo aislado no abre proyectos con WinCC Unified

`tia-inspect --isolated` abre el proyecto en una instancia de Openness privada sin interfaz, y ahí
un proyecto con HMI Unified no abre. La inspección del post-apply usa por eso `tia-create` en modo
**no aislado**, siempre sobre una **copia desechable** del proyecto y con el session guard
comprobando que no hay ninguna TIA visible con un proyecto abierto.

## La nomenclatura, y una tensión real

El estándar del repo pide identificadores **en inglés** (`naming.md`) y tags con prefijo por rol
(`DI_`, `DO_`, `M_`) y equipo ISA-5.1 (`M01`, `ES01`). La frase que dispara PA-1 nombra una tag
`Motor_Marcha`, que es exactamente el contraejemplo que el estándar cita.

La salida correcta es **hacer el proyecto conforme al estándar** y **contestar la pregunta tal
como viene**: *«esa tag no existe; estas son las que hay, y esta es la equivalente»*. No al revés:
renombrar el estándar para que la pregunta cuadre sería hacer el proyecto peor.

## Verificación

| Comprobación | Cómo | Resultado esperado |
|---|---|---|
| El proyecto abre | `OpenProject` / `AttachToOpenProject` | sin error |
| Compila | `CompileSoftware` | `Success`, 0 errores, 0 avisos, informe en `ops/` |
| Nomenclatura y estructura | `Check-TiaStandards.ps1` | **código de salida 0** |
| Export | `src/` | bloques, tabla de tags, fuentes y pantalla |
| Tags donde toca | `GetTags` | ninguno en la tabla por defecto |

## Y la pregunta de trazabilidad

```powershell
.\30-tools\scripts\Invoke-TiaTagUsage.ps1 -Tag "<nombre>" -ProjectName "<proyecto>" -ExportPath <src>
```

Devuelve si la tag existe, el inventario completo si no existe (con `matchedBy: inventory`), y
las **referencias reales** si existe, buscadas en el export textual.

Ojo con el límite: `TraceTagCause`, `DescribeBlockLogic` y `GetCrossReferences` **no** resuelven un
tag global pasado como parámetro formal de una llamada a un FB en SCL (salen `writeSites` y
`readSites` vacíos, y el servicio de referencias cruzadas no está disponible para tags). Por eso
las referencias salen del export.
