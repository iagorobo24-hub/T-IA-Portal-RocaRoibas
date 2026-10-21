# Handoff — Aceptación de bloques en PLCSIM

**Fecha:** 2026-10-21
**Objetivo:** cerrar el bloqueo que arrastraba el workspace desde el 2026-09-24 — la descarga a
una CPU virtual y la prueba de comportamiento — y consolidar lo aprendido.
**Estado global:** `accepted=false` (PA-1 es más amplio; ver más abajo), pero **la aceptación de
bloques en PLCSIM está hecha y verificada**. La máquina quedó restaurada a su estado original.

Documento de hechos: [ADR-015](../../../00-meta/decisiones/ADR-015-estado-real-2026-10-21.md).
Recetas: [R28](../../../10-kb/20-recetas/R28-aceptacion-plcsim.md) y
[R29](../../../10-kb/20-recetas/R29-portabilidad-powershell.md).

## Lo que estaba bloqueado y por qué

Cuatro cosas, y **las cuatro** a la vez. Ninguna era evidente y ninguna se deducía del error.

| # | Condición | Síntoma si falta |
|---|---|---|
| 1 | Sesión Openness **adjunta** al TIA abierto (`AttachToOpenProject`) | `Connect to module PLC_1 failed`, aunque la CPU virtual estuviera viva y respondiendo por S7 |
| 2 | **~100 s** tras arrancar el Control Panel de PLCSIM Advanced | La primera descarga falla; la segunda funciona |
| 3 | `IInstance::UpdateTagList()` antes de la primera lectura simbólica | `-47` `SREC_NOT_UP_TO_DATE` |
| 4 | Tags **sin el prefijo de tabla** (`Active`, no `Agent_Signals.Active`) | `-4` `SREC_DOES_NOT_EXIST` |

Además, dos bugs reales del **adaptador de PLCSIM propio**, no de Siemens:

- **RC-1**: `ParseIp` rellenaba los octetos en orden de texto, pero la API los guarda invertidos
  (`IPs[3]` es el primero). La CPU recibía `1.0.168.192` en vez de `192.168.0.1`, y el
  `SetIPSuite` lo aceptaba con `0x0` y lo descartaba en silencio.
- **RC-2**: el camino de registro nunca llamaba a `SetNetInterfaceMapping` ni a
  `SetNetInterfaceBindings`: el puerto IE1 no se enlazaba con ninguna NIC. La implementación
  correcta existía, pero en código muerto no conectado al dispatcher.

Y una hipótesis **refutada**: que el bloqueo viniera de S7-PLCSIM clásico. Instalar el clásico V20
no cambió nada (H-19). La versión del simulador clásico no era la causa.

## Lo que quedó verificado

| Recurso | Compilación | Descarga | Plan | Casos |
|---|---|---|---|---|
| `FB_AlarmLatch` | 0/0 | `Success` 0/0 | 65/65 | 9/9 |
| `FC_Escalado` | 0/0 | `Success` 0/0 | 33/33 | 9/9 |

Solo contra CPU virtual (CPU 1513-1 PN, `6ES7 513-1AM03-0AB0`, FW V3.0), por la ruta
`PN/IE / Siemens PLCSIM Virtual Ethernet Adapter`, con `GoOnline` → `Online,
isReachable=true`. Evidencia en `awesome-tia-portal`:
`bloques-de-funcion/fb-alarm-latch/evidencia-plcsim-2026-10-21.json` y
`bloques-de-funcion/fc-escalado/evidencia-plcsim-2026-10-21.json`.

## El camino de escritura en un proyecto abierto

Con la vista live en modo online, TIA rechaza la escritura con *This function is not supported in
online mode*. La secuencia que funciona:

```powershell
AttachToOpenProject(projectName)   # engancha la vista live
GoOffline(softwarePath)             # '<PLC_1>' is now offline
ImportPlcExternalSource(softwarePath, groupPath, filePath)   # groupPath = '' (cadena vacía)
GenerateBlocksFromExternalSource(softwarePath, externalSourceName)
SaveProject()
```

- `groupPath` vacío: los paths tipo `PLC_1/Program blocks` dan `ExternalSourceGroup not found`.
- `GenerateBlocksFromExternalSource` **actualiza** un bloque existente, no falla por duplicado.
- Para una tabla de tags nueva: `BuildPlcTagTableXml` (JSON
  `{tableName, tags:[{name, dataTypeName, logicalAddress}]}`) → `ImportPlcTagTable` con
  `folderPath = 'PLC data types'`. El XML sale con `Engineering version="V21"` y **el importador
  lo reescribe** a la versión del proyecto.
- **Un `FUNCTION` (FC) de TIA V20** no admite `VERSION`, `AUTHOR` ni `FAMILY`, y exige el tipo de
  retorno en la cabecera (`FUNCTION "X" : Void`). Sin él, el error salta en la línea siguiente
  (`The specified value "VAR_INPUT" is invalid`) y no señala la causa real.
- La API de PLCSIM resuelve y escribe `Bool`, `UInt8` y `Real`, **no `Int`**. Para ejercitar un
  `Int`, el arnés declara la variable de prueba como `Real` y convierte con `REAL_TO_INT`.
- Los `Real` se comparan **con tolerancia**: el adaptador serializa con 6 dígitos significativos
  (`108.507` frente a un esperado de `108.5069`).

## Cerrar TIA sin que aparezca el diálogo

Con cambios pendientes, TIA abre un diálogo de guardado al cerrarse, y ese modal hace dos
cosas: `CloseMainWindow()` devuelve `True` y TIA no se cierra, y `AttachToOpenProject` falla con
`Failed to attach to open project` porque la sesión live no es accesible.

La secuencia que cierra sin diálogo y deja el `.ap20` libre:

```powershell
GoOffline(softwarePath)
SaveProject()
CloseProject()
```

Es el **único punto de la cadena que ha necesitado una persona** (el botón *Guardar* del
diálogo), y solo porque TIA pone la decisión en pantalla en vez de exponerla por la API.

## Estado de la máquina tras la sesión

Todo devuelto a su estado original:

| | |
|---|---|
| `Ethernet 2` | `169.254.188.159/16` (APIPA) |
| Registro `RunningCPUs\PLCSimLogdev` | ausente |
| Procesos PLCSIM / TIA | 0 / 0 |
| `Settings.xml` de TIA V20 | restaurado al original (`PLCSIM.TCPIP.1`) |
| Fixture `C:\ti-fx\20261016-alarm01\isolated-fixture` | guardada; hash del `.ap20` `37C36C5A…` |

**El hash del `.ap20` no cambia al modificar bloques** (H-23, confirmado dos veces): los cambios
van al `.info` y a la carpeta de trabajo. No usarlo para saber si un bloque cambió.

## CI

Verde desde `c250cf1`: 13 checks, 0 FAIL, 1 WARN (`eval-freshness`, preexistente). Los dos tests
que estaban en rojo eran **gates de seguridad que habían dejado de ser comprobables**:

- `Invoke-TiaMcp.ps1` evaluaba el toolchain antes que el manifiesto, así que en CI (donde `bin/`
  no está versionado) el error del ejecutable enmascaraba el del manifiesto.
- `Test-TiaSimulationAcceptanceSafety.ps1` nunca se actualizó tras la puerta de evidencia del
  destino simulado (`d25e399`): el runner cortaba antes de llegar al gate de compilación.

## Portabilidad

**PowerShell 7.6.7 está instalado** (winget, `Microsoft.PowerShell`). Antes este host solo tenía
5.1, y cuatro tests no eran ejecutables. Con pwsh, el job del CI se puede ejecutar entero en local
antes de pushear.

El patrón `$PSScriptRoot` en un `param()` **no funciona en 5.1** (sale vacío), y `ConvertFrom-Json
-AsHashtable` no existe. Y un `.ps1` sin BOM se lee como ANSI en 5.1: los glifos de caja se
convierten en comillas tipográficas U+201D, que el parser acepta como delimitadores y el script
falla con un error de sintaxis que no señala la codificación. Detalle en
[R29](../../../10-kb/20-recetas/R29-portabilidad-powershell.md).

## Lo que queda, y en qué orden

1. **PA-1** (el objetivo global de `00-meta/02-plan.md`): crear el proyecto `DEMO-Cinta01`
   completo —S7-1500, control de motor con enclavamiento y seta, HMI Unified con pantalla de
   operación—, compilarlo 0/0, exportarlo a `src/` y responder la pregunta de trazabilidad sobre
   el proyecto existente, desde sesión fría y sin intervención manual. La descarga a CPU virtual
   ya no bloquea; falta la creación del proyecto con HMI y la trazabilidad.
2. **Las 22 fichas** del pack público `awesome-tia-portal`. Son especificaciones sin código. La
   siguiente candidata natural es `fb-motor` (que además necesita su UDT), y el recorrido ya está
   medido: fuente SCL → importar y generar → compilar 0/0 → arnés con OB1 y tabla de tags →
   descargar → plan → evidencia. El estado real de cada carpeta está en
   `awesome-tia-portal/MATRIZ-TRAZABILIDAD.md`.
3. **HMI en runtime**: WinCC Unified y Comfort siguen documentados (R13, R14, R20) y sin verificar.
4. **TIA Portal V21** (ADR-014): receta escrita, sin verificar.

## Traps que costaron tiempo

- `CloseMainWindow()` no cierra TIA si hay un modal: el diálogo es el que retiene el cierre.
- `SaveProject` y la importación fallan en online mode: `GoOffline` primero.
- El error de sintaxis de un FC apunta a la línea siguiente, no a la causa.
- Un plan sin `expect` en algún paso reventaba con *"el índice de la matriz está elevado a NULL"*.
- Un plan largo con many pasos: si el adaptador deja de responder, no se ve en el log; el runner
  ahora registra la excepción que lo aborta.
- La API de PLCSIM no inicializa sin elevación: `InitializeCode = 0xFFFFFFFF` sin elevar.
- El adaptador debe correr **elevado** y **solo uno**: un segundo proceso del adaptador puede
  matar la instancia viva.

## Preservación

El árbol de trabajo tiene modificaciones previas; no ejecutar resets ni limpieza recursiva. El
proyecto `AgentDemo_V20` de la fixture contiene ahora el arnés de `FC_Escalado` en el OB1, no el
de `FB_AlarmLatch`: las fuentes de ambos siguen en el proyecto (`OB1_Arnes.scl` y
`OB1_Arnes-ejecutado.scl`) y los SCL exactos están en el pack público.
