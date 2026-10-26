# Catálogo de errores

> Síntoma → causa → arreglo. Es donde un agente pierde más tiempo, así que es lo primero que se
> escribió.
>
> **Obligatorio.** En cuanto aparezca un error —de TIA, de Openness, de PLCSIM, de la HMI o de un
> script— busca el síntoma en esta carpeta **antes de reintentar nada**. Si está, aplica el arreglo
> de aquí. Si no está y lo resuelves, añádelo al final de este fichero con síntoma, causa, arreglo
> y evidencia. No abras otra carpeta de errores.
>
> **Antes de reintentar nada: lee el mensaje de error.** Los tres servidores MCP devuelven
> errores **tipados**. El código dice qué hacer; el texto, por qué.

## Códigos de error de `tia-inspect`

✅ *Verificado en `PortalErrorCode.cs`.*

| Código | Qué significa | Qué hacer |
|---|---|---|
| `NotFound` | La ruta no existe | **No la corrijas a ojo.** Vuelve a `GetSoftwareTree`. El error puede sugerir rutas probables: léelas |
| `InvalidParams` | Parámetros mal, o estado incorrecto del objeto | Lo más común: bloque inconsistente al exportar → **compila primero** |
| `InvalidState` | No hay conexión o no hay proyecto abierto | `Connect` / `OpenProject` |
| `ExportFailed` / `ImportFailed` | Falló la operación de fichero | El mensaje trae la causa concreta del error subyacente |
| `NotSupported` | La API no lo permite, punto | Ver [`10-openness/limites.md`](../10-openness/limites.md). **No reintentes** |
| `WriteDisabled` | El servidor no recibió el conjunto completo de escritura aislada | Las herramientas mutantes requieren `--isolated --fixture-root <run-dir> --allow-write` y un `.tia-agent-fixture.json` válido en la raíz. Usa el runner de fixture; `--allow-write` solo no basta. |
| `CreateFailed` / `DeleteFailed` / `RenameFailed` | Falló la mutación | Mira si el objeto está protegido, es de safety, o es de sistema |

📄 Desde el SDK 2.x, un `McpException` lanzado desde una herramienta llega al cliente como un
`CallToolResult` con `isError: true` y el mensaje como texto — **no** como error JSON-RPC. Es
decir: el modelo **puede leer el motivo y corregirse solo**. Aprovéchalo.

---

## Los errores de arranque

### 🔴 «User in 'Siemens TIA Openness' user group: False»

✅ *Es el bloqueo histórico documentado; en esta máquina el estado actual es True (ver `70-runs/environment/latest.json`).*

**El bloqueo número uno de Openness**, y el que peor avisa: no da un error claro, da fallos de
conexión opacos. Si vuelve a aparecer en otra máquina, aplica este procedimiento.

```powershell
# PowerShell COMO ADMINISTRADOR
net localgroup "Siemens TIA Openness" "$env:USERNAME" /add
```

🔒 **Y después hay que cerrar sesión de Windows y volver a entrar.** El grupo no surte efecto
hasta entonces. Si añades el usuario y pruebas sin reiniciar sesión, sigue fallando y parece que
el comando no funcionó.

Comprobación: `TiaMcpServer.exe --tia-major-version 20 --doctor` debe decir `True`.

### «Installed TIA Portal versions: none found»

Dos causas posibles:

1. El servidor está compilado con un **suelo de versión** más alto que lo que tienes. Upstream de
   `tia-inspect` solo busca **V21 o superior**. ✅ *Verificado: es exactamente lo que pasaba aquí,
   y es uno de los parches de nuestro build (ver ADR-001).*
2. TIA no está instalado, o falta el componente Openness.

### Fallo de compilación con 241 errores `CS0246`

✅ *Verificado — nos pasó.* Al compilar `tia-inspect`, cientos de "no se encontró el tipo
`PlcTag`, `TiaPortal`, `PlcSoftware`…". Parece un problema de `using`. **No lo es.**

**Causa:** el paquete NuGet `Siemens.Collaboration.Net.TiaPortal.Packages.Openness` resuelve los
ensamblados **desde tu instalación local de TIA**, en tiempo de compilación. Si el paquete es
21.0.x y no tienes TIA V21, no resuelve nada **y no avisa**.

**Arreglo:** usar la versión del paquete que corresponde a tu TIA. Ver
`30-tools/mcp/tia-inspect/build.ps1`, que ya tiene el mapa.

---

## Errores al leer

### `NotFound` en una ruta que "existe"

🔴 **La causa casi siempre es el path.** Ver [`10-openness/path-concept.md`](../10-openness/path-concept.md).

| Error típico | Correcto |
|---|---|
| `Program blocks/40_Devices/FB_Motor` | `40_Devices/FB_Motor` — los paths son relativos a la raíz, sin el grupo de sistema |
| `FB_Motor` cuando está en un grupo | `40_Devices/FB_Motor` — ruta completa |
| `PLC` en un proyecto con dos PLCs | `PLC_1` exacto, de `GetProjectTree` |

### La respuesta viene cortada o gigante

Un PLC grande no cabe en una respuesta. Acota:

- `GetSoftwareTree` acepta `sections`: `blocks,types,tags,watch,sources`. Pide solo lo que
  necesitas ✅
- `GetCrossReferences` acepta `maxDepth` (1-3, por defecto 1). **Sube de 1 solo si hace falta**:
  el crecimiento es exponencial ✅

---

## Errores al escribir

### Advertencia: «Inputs or outputs are used that do not exist in the configured hardware»

✅ **Verificado y diagnosticado** en `npatel-traffic-light`.

El programa direcciona E/S que **la configuración hardware no tiene**. Compila —es advertencia,
no error— pero esas señales no llegarían a ningún borne.

**Cómo diagnosticarlo, en dos pasos:**

```
1. GetTags(softwarePath, tagTablePath)   → qué direcciones usa el programa
2. GetProjectTree                        → qué módulos hay configurados
```

En el caso real: el programa usaba `%Q0.0`–`%Q0.5` y `%Q1.0`–`%Q1.5` (12 salidas), y la CPU
S7-1200 solo tenía su E/S integrada `DI 6/DQ 4` — **4 salidas**, `%Q0.0`–`%Q0.3`. Faltaban 8.

**Las dos causas habituales:**

| Causa | Qué hacer |
|---|---|
| Proyecto pensado para **PLCSIM** | Nada. En simulación las salidas no necesitan existir. Muy común en proyectos didácticos |
| Falta un módulo de verdad | Añadir el módulo de E/S a la configuración hardware |

🔒 **Nunca la descartes como ruido en un proyecto de planta.** Significa que parte del programa
no puede actuar sobre nada. *Compila* no es lo mismo que *desplegable*.

⚠️ **Ojo con recompilar:** si los bloques están al día, TIA responde *"No block was compiled"*
y **puede no volver a emitir** advertencias de bloque. Esta en concreto es de nivel PLC
(*General warnings*) y sí reaparece. Para forzar el resto hay que recompilar todo desde la GUI.

### «Export failed» en un bloque concreto

📄 TIA **nunca exporta un bloque inconsistente**. Compila primero. Si es exportación masiva, el
bloque no falla: **se salta en silencio** y aparece en la lista `Inconsistent` de la respuesta.

⚠️ **Míra esa lista siempre.** Si no, crees que exportaste el PLC entero y te has dejado bloques.

### Colisión de número al importar

📄 El número de bloque **viaja dentro del fichero exportado**. Importar en el mismo PLC un bloque
copiado puede chocar con un número ya ocupado.

Es la razón de la regla de [`20-standards/naming.md`](../../20-standards/naming.md): **no numerar
bloques a mano**, dejar que TIA asigne.

### «an object with the name ... already exists in the plc»

📄 Al importar un **tipo de datos PLC**. El nombre es único en **todo el PLC**, no dentro del
grupo. Aunque uses `importOption: Override`, importarlo en un grupo distinto del que ya lo
contiene falla.

**Arreglo:** apunta `groupPath` al grupo donde el tipo ya vive.

### La importación de LAD desde documentos falla

📄 El `.s7res` tiene que llevar etiquetas **en-US** para todos los elementos. Es un bug conocido
de Openness, no del servidor.

⚠️ Sin confirmar aquí todavía. Si te lo encuentras: usa XML SimaticML para ese bloque, o pásalo
a SCL.

### `NotSupported` al tocar algo del sistema

Es correcto, no es un fallo. Grupos de sistema, tabla de tags por defecto, tabla de forzado y
constantes de sistema **no se tocan**. Ver [`limites.md`](../10-openness/limites.md).

### Un bloque rechaza cualquier edición

Dos sospechosos, en este orden:

1. **Know-how protection** → el usuario tiene que quitarla desde TIA. El agente no puede
2. **Bloque F / safety** → `AGENTS.md` §3.3: **el agente no edita safety.** Reporta y para

---

## Errores de conexión y sesión

### Se abre una segunda instancia de TIA Portal

El agente llamó a `Connect` o `OpenProject` sin verificar si el perfil activo puede adjuntarse a la
instancia visible. Dos instancias sobre el mismo proyecto pueden bloquear el proyecto o perder
trabajo.

🔒 **Attach es condicional.** Primero identifica visualmente la ventana/proyecto y consulta el
roster del servidor/perfil activo. Usa `Attach` solo si esa herramienta está registrada y el
proyecto visible es el objetivo exacto. `tia-inspect read` en este workspace no expone
`AttachToOpenProject`; no sustituyas Attach por `Connect` a ciegas. Si Computer Use no está
disponible o no permite identificar la instancia, detente y pide que el usuario libere o confirme
la ventana. Ver `AGENTS.md` §2 y [R01](../20-recetas/R01-inventariar-proyecto.md).

### `OpenProject` falla en un proyecto que sí existe

✅ **Verificado:** si el proyecto está **abierto en otra instancia de TIA** —típicamente la que
tiene delante la persona, con ventana— una instancia headless de Openness **no puede abrirlo**.
El proyecto está bloqueado por el otro proceso.

Síntoma: `OpenProject` devuelve error en ~2 s (no tarda, no hay timeout) y todo lo que viene
detrás falla con `InvalidState`.

**Cómo distinguirlo de una ruta mal puesta:** comprueba los procesos y mira cuáles tienen ventana.

```powershell
Get-Process 'Siemens.Automation.Portal' | Select-Object Id, MainWindowTitle
```

Si el título menciona tu proyecto, ahí está la causa.

**Arreglo:** cerrar el proyecto en la instancia con ventana, o esperar. **No mates el proceso con
ventana**: es el de la persona y puede tener cambios sin guardar. `Stop-TiaPortal.ps1` los respeta
por defecto justo por esto.

### `OpenProject` falla con *«has already been opened ... only be opened again after a 2 minute delay»*

✅ **Verificado:** es la **fuga de sesión** del propio runner, no un conflicto con la persona. Una
secuencia que **aborta en su primera llamada fallida** nunca llega a ejecutar las entradas
`CloseProject` y `Disconnect` que tenía en cola. El `finally` del runner mataba el servidor MCP
pero **no cerraba la sesión de Openness**: el proceso `Siemens.Automation.Portal` sobrevive **con el
proyecto abierto**, y la siguiente sesión recibe ese mensaje y además espera 2 minutos.

Síntoma: la segunda sesión falla al abrir el mismo `.ap20` con un mensaje que *menciona al usuario
actual*, aunque no haya ninguna ventana de TIA abierta.

**Cómo distinguirlo de un bloqueo real:** si no hay ninguna instancia con ventana pero el mensaje
habla de *«already been opened»*, es una sesión huérfana de la anterior.

```powershell
Get-Process 'Siemens.Automation.Portal' | Select-Object Id, MainWindowTitle
```

**Arreglo:** el runner ya lo hace solo desde el 2026-10-20: en modo aislado (flag `--isolated` de
`tia-inspect` o herramienta `ConnectIsolated` de `tia-create`) cierra la sesión con `CloseProject` y
`Disconnect` sobre el canal todavía vivo y, si aun así queda un `Siemens.Automation.Portal` que no
existía antes de la llamada, lo cierra. El informe incluye un bloque `cleanup` con
`projectClosed`, `sessionDisconnected` y `closedTiaProcessIds`.

**Ojo:** una sesión en modo *attach* pertenece a la persona y el runner **no** cierra su proyecto ni
su ventana. Si ves este mensaje con la TIA de la persona abierta, aplica lo del apartado anterior.

Ver `30-tools/tests/Test-McpToolSequenceCleanup.ps1`.

### Se acumulan instancias de TIA Portal comiendo RAM

✅ **Verificado:** `Disconnect` **no cierra TIA Portal**. Suelta la conexión y deja el proceso
`Siemens.Automation.Portal` vivo con ~1,3 GB. Terminar el proceso del servidor MCP tampoco lo
cierra.

No es un fallo: una instancia caliente hace que el siguiente `Connect` tarde **0,3 s en vez de
28 s**. Pero hay que limpiarla a propósito:

```powershell
30-tools\scripts\Stop-TiaPortal.ps1
```

Comprueba antes por MCP si hay un proyecto abierto y se niega si lo hay.
Detalle completo en [`10-openness/conexion-y-sesiones.md`](../10-openness/conexion-y-sesiones.md).

### `Connect` tarda casi 30 segundos

✅ Normal en frío: está arrancando una instancia headless de TIA. **Medido: 27,7 s.**
La siguiente conexión, con la instancia ya viva, tarda **0,3 s**. No lo interpretes como un
cuelgue ni reintentes: dale al menos 2 minutos de margen.

### Los cambios "se pierden"

📄 Las operaciones de escritura cambian el proyecto **solo en memoria**. Hay que persistir
explícitamente:

| Situación | Herramienta |
|---|---|
| Proyecto normal | `SaveProject` |
| Sesión local de Multiuser abierta | **`SaveSession`** |

Cada respuesta de escritura de `tia-inspect` dice cuál toca ✅.

### Resultados raros o a medias con varias llamadas a la vez

🔴 **Openness no es thread-safe.** No paralelices. `tia-inspect` serializa con un lock global
precisamente por esto.

---

## Errores de PLCSIM y de la aceptación (2026-10-21)

Recogidos al cerrar la aceptación de bloques en CPU virtual. Todos están explicados con detalle
en [R28](../20-recetas/R28-aceptacion-plcsim.md) y en
[ADR-015](../../00-meta/decisiones/ADR-015-estado-real-2026-10-21.md).

### `Connect to module PLC_1 failed` / `NotReachable` en la descarga

**Causa:** la sesión Openness no va **adjunta** al TIA abierto. Con `ConnectIsolated` (headless)
el mismo proyecto falla aunque la CPU virtual esté viva y respondiendo por S7.

**Arreglo:** `AttachToOpenProject(projectName)` y descargar desde esa sesión. Es la diferencia
entre `DownloadToPlc` con `state=Success` y `Connect to module ... failed`.

### `This function is not supported in online mode`

**Causa:** la vista live del proyecto abierto está en modo online, y TIA no permite escribir
(importar fuentes, generar bloques) en ese estado.

**Arreglo:** `GoOffline(softwarePath)` antes de escribir, y `SaveProject` después.

### `The operation is not permitted in online mode` (al guardar)

**Causa:** la misma. `SaveProject` también exige estar offline.

**Arreglo:** `GoOffline` → escribir → `SaveProject`.

### `Failed to attach to open project '<proyecto>'`

**Causa:** **no** es un problema de adjuntar. Suele haber un **diálogo modal abierto en TIA**
—típicamente el de "el proyecto se ha modificado, ¿guardar?"— y con un modal la sesión live no es
accesible.

**Arreglo:** primero observar la ventana de TIA y resolver el diálogo; después adjuntar.

### `CloseMainWindow()` devuelve `True` pero TIA no se cierra

**Causa:** hay un modal de cambios sin guardar. El diálogo es el que retiene el cierre, no la
ventana principal.

**Arreglo:** `GoOffline` → `SaveProject` → `CloseProject`, que deja TIA en la pantalla de inicio
sin diálogo y libera el `.ap20`.

### `The specified value "VAR_INPUT" is invalid` al generar un FC

**Causa:** **no** es la interfaz. Un `FUNCTION` de TIA V20 exige el **tipo de retorno en la
cabecera** (`FUNCTION "X" : Void`). Sin él el parser se descuadra y señala la línea siguiente.

**Arreglo:** `FUNCTION "X" : Void` y el resultado por `VAR_OUTPUT`.

### `The specified value "VERSION" is invalid` (o `AUTHOR`, o `FAMILY`)

**Causa:** un `FUNCTION` de TIA V20 **no admite** `VERSION`, `AUTHOR` ni `FAMILY`. Solo en bloques
con memoria.

**Arreglo:** quitarlos. En un `FUNCTION_BLOCK` sí valen.

### `ExternalSourceGroup not found`

**Causa:** el `groupPath` de `ImportPlcExternalSource` no es el path del árbol de bloques.

**Arreglo:** `groupPath` es la **cadena vacía**. Los paths tipo `PLC_1/Program blocks` fallan.

### `-47` / `0xffffffd1` (`SREC_NOT_UP_TO_DATE`) al leer un tag

**Causa:** la lista de etiquetas vive en memoria compartida y la puebla
`IInstance::UpdateTagList()`, que lee los tags del VPLC. Sin esa llamada, la resolución simbólica
no funciona **aunque la CPU ejecute el programa descargado**.

**Arreglo:** llamar a `UpdateTagList()` tras adjuntarse a la instancia, antes de la primera
lectura simbólica.

### `-4` / `0xfffffffc` (`SREC_DOES_NOT_EXIST`) al leer un tag

**Causa:** la API resuelve por el **nombre simple** del tag (`Active`, `Latched`), no por el
nombre cualificado que muestra TIA (`Agent_Signals.Active`).

**Arreglo:** usar el nombre simple. El prefijo de tabla no existe para la API.

### `initialization-failed` con `initializeCode: 0xFFFFFFFF`

**Causa:** la API de PLCSIM Advanced **no inicializa sin privilegios**.

**Arreglo:** correr el adaptador y el runner del plan **elevados** (administrador).

### `el índice de la matriz está elevado a NULL` en el runner del plan

**Causa:** un paso del plan **sin `expect`**. La colección de propiedades de un `expect` nulo no es
una colección vacía, e indexarla con un nombre nulo revienta.

**Arreglo:** el runner ahora trata un paso sin `expect` como "nada que comparar". Si te pasa con
otro runner, mira primero si el plan tiene todos los pasos con `expect`.

### Error de sintaxis en un `.ps1` que no señala la causa

**Causa:** en **Windows PowerShell 5.1**, un `.ps1` sin BOM se lee como ANSI. Los glifos de caja
(`└──`) se convierten en `â””â”€â”€`, que contiene **comillas tipográficas U+201D**, y el parser las
acepta como delimitadores de cadena.

**Arreglo:** en scripts que se escriben a disco y luego se ejecutan, usar **ASCII puro**
(`|--` en vez de `└──`). O ejecutar con pwsh 7, que lee UTF-8 siempre.

### `Join-Path: ... porque es una cadena vacía` en la línea 3 de un script

**Causa:** `$PSScriptRoot` **no está disponible en el bloque `param`** en 5.1.

**Arreglo:** resolver el valor por defecto en el cuerpo del script, no en el `param`.

### `No se encuentra ningún parámetro que coincida con el nombre del parámetro 'AsHashtable'`

**Causa:** `ConvertFrom-Json -AsHashtable` es **PowerShell 6+**.

**Arreglo:** usar el objeto plano y `PSObject.Properties.Remove(...)` para quitar una propiedad.

### `Failed to open project '<ruta>'` sin más detalle

**Causa:** una de dos, y el mensaje no dice cuál:

1. **La carpeta del proyecto supera los 143 caracteres.** TIA responde *The specified path '…'
   (156 character) is too long. A maximum of 143 characters is allowed*, pero en modo aislado la
   excepción se come y solo queda `Failed to open project`.
2. **La ruta del proyecto supera los 143 caracteres**, que es lo que TIA dice, pero el modo
   aislado se come la excepción. Y un apunte que **desmiente un diagnóstico anterior**: el modo
   aislado **sí** abre proyectos con WinCC Unified, medido el 2026-10-22 con la copia en
   ruta corta.
   privada sin interfaz) no lo abre.

**Arreglo:** medir la longitud de la carpeta del proyecto (límite 143) y poner la copia de
inspección en una ruta corta bajo `%TEMP%`. Si el proyecto tiene HMI, inspeccionarlo con
`tia-create` en modo no aislado, sobre una copia desechable y con el session guard comprobando
que no hay ninguna TIA visible con un proyecto abierto. Detalle en
[R30](../20-recetas/R30-crear-proyecto-desde-spec.md).

### `Type conflict: Object "OB_Main" cannot be overwritten`

**Causa:** una fuente externa con `ORGANIZATION_BLOCK "OB_Main"`. TIA nombra el OB cíclico del
sistema y no admite otro nombre para él.

**Arreglo:** declarar el OB cíclico como `ORGANIZATION_BLOCK "Main"`. El patrón `OB_<Función>` del
estándar aplica a los OB de arranque y de error, no al OB1 del sistema.

### `Tag "iDB_M01" not defined` y `The formal parameter 'CmdStart' is invalid` (×13)

**Causa:** el DB de instancia no existe, así que la llamada `"iDB_M01"(...)` se resuelve como un
**tag** y todos los parámetros formales quedan inválidos. En SCL, el DB de instancia se declara
en la propia fuente.

**Arreglo:** declarar el DB en la fuente, antes del OB:

```scl
DATA_BLOCK "iDB_M01"
{ S7_Optimized_Access := 'TRUE' }
VERSION : 0.1
   "FB_Motor"
END_DATA_BLOCK
```

### `No block writes 'X'` cuando sí se usa (y `readSites` vacío)

**Causa:** límite del analizador estático. `TraceTagCause`, `DescribeBlockLogic` y
`GetCrossReferences` **no resuelven un tag global pasado como parámetro formal de una llamada a
un FB en SCL**: salen `writeSites` y `readSites` vacíos, `DescribeBlockLogic` no decodifica el SCL
del OB, y `GetCrossReferences` responde *Cross reference service not available for tag*.

**Arreglo:** la referencia cruzada se saca del **export textual** (el `.scl` que se importó y el
XML del bloque, donde aparece como `<Component Name="…" UId="…">`). `Invoke-TiaTagUsage.ps1` lo
hace así y lo dice en su salida.

---

### `Connect to module PLC_1 failed` en un proyecto recien creado

**Causa:** un proyecto que TIA acaba de crear **no tiene destino de descarga configurado**. TIA no
sabe a quien descargar, asi que la descarga por API falla aunque todo lo demas este bien: la CPU
virtual en RUN, la IP del proyecto coincidiendo con la de la CPU, la proteccion de datos de
configuracion desactivada y el hardware compilado con 0 errores y 0 avisos.

Medido el 2026-10-22 con `DEMO-Cinta01`. En la GUI, TIA lo dice en la barra de estado:
*"Action cancelled before download"*.

**Arreglo:** hacer **una descarga por la GUI** la primera vez, para que TIA aprenda el destino y lo
guarde en el proyecto: clic derecho en el dispositivo del arbol -> "Descargar en el dispositivo" ->
"Hardware y software" -> elegir la CPU virtual. A partir de ahi la descarga por API funciona.

**Ojo con el diagnostico**: el nombre interno de la entrada es
`LoadService.LoadCommandsUI:MenuItemDownload`, y su submenu tiene `MenuItemDownloadHwSw`
(hardware y software), `MenuItemDownloadHw` y `MenuItemDownloadSw`.

---

### `Online connection to HM_RT_1 failed` al simular una HMI Unified

**Causa:** la simulación de una HMI Unified **usa el WinCC Unified Runtime instalado**, y ese runtime
tiene que ser **de la misma versión que el TIA Portal del proyecto**. Con runtime V19 y un proyecto
V20, TIA intenta la conexión online con el dispositivo HMI `HM_RT_1`, espera **26 segundos** y
cancela: `Start downloading to device` → `HM_RT_1` → `Online connection to HM_RT_1 failed.` →
`Action cancelled before download.`

**El síntoma no menciona la versión**, y parece un problema de PLC. Es la causa más cara
registrada aquí: se puede perder una hora sospechando del PLC cuando el PLC está perfecto.

Medido el 2026-10-22 con `DEMO-Cinta01` (TIA V20, runtime Unified V19 instalado). Comprobación:

```powershell
# version del runtime instalado -> 500.30.8901.3 = V19
Get-ChildItem 'C:\Program Files\Siemens\Automation\WinCCUnified' -Recurse -Filter 'GfxRTS.exe' |
  ForEach-Object { $_.VersionInfo.ProductVersion }
# formato de runtime que pide el proyecto -> ..._Rdf_20.0.0.0
Get-ChildItem '<proyecto>\tia\<proyecto>\IM\HMI' -Recurse -Directory |
  Where-Object Name -match 'Rdf' | Select-Object -ExpandProperty Name
```

**Arreglo:** instalar el runtime de la misma versión (`SIMATIC WinCC Unified PC V20`). Lo descarga
el usuario; el agente no. **No es un bloqueo de licencia**: sin licencia el runtime funciona en modo
no licenciado (aviso cada 10 min) y la simulación dura 1 hora.
Ver [ADR-017](../../00-meta/decisiones/ADR-017-runtime-unified-igual-version.md) y
[R31](../20-recetas/R31-simulacion-plcsim-unified.md).

---

### `The blocks contained in this project cannot be simulated with S7-PLCSIM` (0626:000013)

**Causa:** la propiedad del proyecto **"Support simulation during block compilation"** está
desactivada. **V20 la deja desactivada por defecto**, así que el botón de simulación no hace nada
visible y la instancia de PLCSIM se queda en `PLC sin configurar`.

**Arreglo:** `OK` en el diálogo; la propiedad queda activada en las propiedades del proyecto
(protección). Sin esto, la simulación del PLC no arranca aunque PLCSIM esté instalado.

---

### `Establish connection to device` / `"PLC_1" might not be a trustworthy device`

**Causa:** el PLC virtual usa un **certificado autofirmado** y TIA pide confirmación.

**Arreglo:** botón **`Connect`**.

**Ojo, este es un bloqueo silencioso**: si nadie responde al diálogo, la descarga **se cancela sola
a los ~70 segundos** y el panel de salida solo dice `Action cancelled before download`, sin mencionar
el certificado. Cuando ese aviso aparezca sin explicación, **mira primero si hay un diálogo de
certificado abierto**.

---

### `The target PLC_1 in the offline project is different from the target in the online project`

**Causa:** el proyecto guarda un **destino de descarga** (una CPU virtual de una sesión anterior,
con otra dirección) que ya no corresponde al simulador actual. La IP del proyecto puede ser
correcta: con `GetDeviceIpAddress` se lee la del proyecto, y con `GetOnlineState` sale
`State: Incompatible` / *"online but firmware/config mismatch. Download required."*

**Arreglo:** rehacer la descarga por la GUI con el simulador activo, para que TIA reescriba el
destino; o limpiar el destino guardado en `Online access`.

**Además:** `CheckDownloadReadiness` sobre un PLC en S7-PLCSIM (Softbus) devuelve
`downloadRouteCount: 0` y `HasDownloadProvider: false`: **el Softbus no es una ruta de red que vea
el `DownloadProvider` de Openness**. Con PLCSIM Advanced (que publica TCP/IP) sí hay rutas.

---

### `Permission denied` al escribir `30-tools/tia-ui/Invoke-TiaUi.ps1`

**Causa:** en esta máquina hay una **reserva a nivel de sistema sobre ese path exacto**. Medido el
2026-10-22:

```
30-tools/tia-ui\Invoke-TiaUi.ps1    -> Acceso denegado   (tambien con otra caja: Invoke-TiaUI.ps1)
30-tools/tia-ui\Invoke-TiaUi2.ps1   -> OK
30-tools\tia-ui\Invoke-TiaUi .ps1   -> OK
30-tools\scripts\Invoke-TiaUi.ps1   -> OK                (mismo nombre, otra ruta)
```

No es la extensión, ni los permisos del directorio (`prueba.ps1` se escribe bien en el mismo sitio),
ni el antivirus (Defender tiene `RealTimeProtection` desactivado). Borrar y recrear el directorio
no lo libera.

**Arreglo:** usar otro nombre de fichero. El motor vive ahora en
`30-tools/tia-ui/Invoke-TiaUiEngine.ps1` (contenido idéntico). Si el bloqueo se levanta, se puede
volver al nombre original.

### El MCP recibe un JSON corrupto cuando la secuencia pasa por PowerShell 5.1

**Síntoma:** el runner `Invoke-McpToolSequence.ps1` falla al parsear las llamadas y la sesión ni
llega a arrancar. Reproducido el 2026-10-22:

```
JSON real : {"name":"Bootstrap"}
via 5.1   : {name:Bootstrap}   <- sin comillas
```

**Causa:** pasar el JSON por **parámetro de línea de comandos** (`-CallsJson $callsJson`) a un
**proceso externo** (`& $pwsh -File ...`). Al construir la línea de comandos de un proceso nativo,
Windows PowerShell 5.1 elimina las comillas dobles del argumento. No pasa nada si el destino es
otro script PowerShell invocado en el propio proceso, ni si el host falla a PowerShell 7.

**Arreglo:** escribir el JSON a un fichero temporal UTF-8 sin BOM y usar `-CallsJsonPath`, que lee
por disco. Se corrigieron los tres scripts que invocaban un proceso externo
(`Write-TiaSimulationReadiness.ps1`, `Invoke-TiaSclProposalApply.ps1`,
`Invoke-TiaHmiScreenFromJson.ps1`) y el paquete portable se regeneró con
`Build-PortablePackage.ps1 -Force`. Efecto práctico importante: este bug dejaba el gate
`tiaInstanceSafeForApply` en `false` aunque la sesión estuviera sana, porque la sonda de
`ListPortalProcessProjects` nunca ejecutaba su secuencia.

### El fondo de la pantalla se queda en negro tras cambiar de escritorio virtual

**Síntoma:** tras saltar de escritorio virtual con `Win+Ctrl+Flecha` (buscando la ventana de TIA),
el fondo de **todos** los monitores se ve negro aunque las ventanas y la barra de tareas funcionen
normal. Visto 2026-10-23.

**Diagnóstico verificado:** el registro mantiene el fichero original
(`HKCU:\Control Panel\Desktop` → `Wallpaper`, `WallpaperStyle=10`), así que no es un cambio de
preferencia sino de render. Re-aplicar `SystemParametersInfo(SPI_SETDESKWALLPAPER)` y alternar el
fondo a otro fichero y de vuelta **no arregla nada**.

**Causa:** bug de DWM de Windows 11 al cambiar de escritorio virtual: el wallpaper deja de
repintarse hasta que el escritorio se reconstruye de verdad.

**Arreglo verificado:** reiniciar `explorer.exe`. El escritorio se reconstruye y el wallpaper
vuelve. Efectos colaterales medidos: la barra de tareas desaparece unos segundos y **las ventanas
del Explorador de archivos se cierran**; antes de matar el proceso conviene capturar sus rutas para
reabrirlas:

```powershell
(New-Object -ComObject Shell.Application).Windows() | ForEach-Object { $_.LocationURL }
```

El resto de aplicaciones (instaladores, TIA, Excel...) no se ven afectadas. Reiniciar `dwm.exe`
primero no es posible sin permisos de administrador (protegido por el sistema, *Acceso denegado*):
no lo fuerces.

**Prevención:** [`10-kb/00-fundamentos/playbook-gui-tia.md`](../00-fundamentos/playbook-gui-tia.md)
regla 2: no cambiar de escritorio virtual para buscar ventanas; si la ventana objetivo no está en
el escritorio activo, parar y avisar al usuario.

---

## Cuando el error no está aquí

1. Lee el mensaje entero, incluido el `InnerException` si lo trae
2. Comprueba si es un [límite de la API](../10-openness/limites.md) y no un fallo
3. Si es nuevo y te costó averiguarlo: **añádelo a este fichero.** Eso es lo que hace que la
   base de conocimiento valga con el tiempo

---

## Errores del 2026-10-22 (simulación unificada V20)

### DownloadToPlc: No download route reaches target IP '192.168.0.1' / Connect to module PLC_1 failed con ruta PLCSIM [no IP]

**Síntoma:** CheckDownloadReadiness y DownloadToPlc ven ruta PLCSIM [no IP] → 1 X1. El adaptador Windows Ethernet 2 (Siemens PLCSIM Virtual Ethernet Adapter) tiene IP 192.168.0.100/24 asignada y visible en 
etsh/Get-NetIPAddress, pero el registro NDIS HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\0001 muestra IPAddress: vacío.

**Causa:** el driver NDIS del adaptador virtual **no propagó la IP al stack Softbus**. Provocado por la reconfiguración MSI del mediodía (11:57-12:08: WinCC Unified PC V20 + AWB Host plugins; Event 1038 "requiere reinicio" a las 11:57; reboot ~12:20). El bindeo NDIS quedó pendiente.

**Arreglo:** **reiniciar la máquina** (fuerza rebind del driver). Tras reboot, CheckDownloadReadiness muestra pgPcAddresses: 192.168.0.100 y DownloadToPlc conecta.

**Evidencia**: 70-runs/2026-10-22-simulacion-unified-v20/19-check-readiness-result.json (solo 1 ruta, pgPcAddresses=\"\"), 20-download-auto-result.json, 21-download-relaunch2-result.json.

---

### PLCSIM V20: botón + (crear instancia) no hace nada con args --projectname/--mlfb

**Síntoma:** arrancar S7PLCSIMV20.exe --family=S71500 --projectname=\"DEMO-Cinta01\" --mlfb=\"6ES7 513-1AM03-0AB0\" carga la app con cabecera \"DEMO-Cinta01\", catálogo S7-1500 visible, pero clic en + (o Ctrl+1) no crea instancia. Workspace Documents\PLCSIM\DEMO-Cinta01 no existe en disco.

**Causa:** los argumentos de CLI fuerzan un workspace con nombre de proyecto que no existe en el filesystem. El adaptador Softbus no se vincula a ese workspace fantasma.

**Arreglo:** arrancar **PLCSIM sin argumentos** → cabecera \"Unsaved workspace\" → Ctrl+1 (atajo Create1500 de SettingsData.JSON) → crea Instance_1 en workspace por defecto.

**Evidencia**: capturas 22-plcsim-instance-created.png, 29-plcsim-relaunch2-inst.png.

---

### TIA V20: toolbar NO tiene icono \"Start simulation\"

**Síntoma:** se clicaba en (2610,71) creyendo que era \"Start simulation\". Tooltip tras activación + dwell 3.5 s dice **\"Start CPU\"**. (2586,71) = \"Accessible devices\". (2632,71) = \"Stop CPU\".

**Vía correcta**: menú Online → Simulation ▶ → Start (Ctrl+Shift+X).

**Regla validada**: con PLC_1 seleccionado en árbol → item \"Start\" del submenú Online está **NEGRO** (habilitado); si se pierde selección → **GRIS**. Siempre re-clic en árbol tras activaciones.

**Evidencia**: capturas 26-icono-2597.png, 27-icono-2584.png, 31-ctx-start-sim.png (menú contextual con \"Start simulation Ctrl+Shift+X\" en negro).

---

### TIA shell muere tras attach/detach MCP reiterados

**Síntoma**: TIA PID 28328 tenía menús/toolbar/F10/atajos muertos (canvas sí respondía). Causa probable: arranque manual + attach/detach MCP repetidos en la sesión anterior.

**Arreglo**: reiniciar TIA limpio (Stop-TiaPortal.ps1 + nuevo Connect). PID 30048 tiene shell viva (tiles, árbol, menú Online abren).

**Evidencia**: diario de arranque en 70-runs/2026-10-22-simulacion-unified-v20/.

---

### OpenProject exige arg path (no projectPath)

**Síntoma:** llamada MCP OpenProject(projectPath=\"...\") falla silenciosamente / no abre. El parámetro correcto es path.

**Evidencia**: secuencia MCP exitosa en 70-runs/2026-10-22-simulacion-unified-v20/01-bootstrap.json... con OpenProject(path=...).

---

### HMI Unified: simulación no arranca con runtime de versión distinta (V19 vs TIA V20)

**Síntoma**: Online → HMI → Start runtime sube procesos Siemens.Runtime.HmiUnified.Client + ControlCenter, pero **no hay ventana ni puerto web expuesto**; la pantalla Main no se muestra.

**Causa**: runtime instalado SIMATIC WinCC Unified PC V19 (GfxRTS.exe 500.30.8901.3), proyecto TIA V20 → formato runtime  _Chrom_20.0.0.0_Rdf_20.0.0.0. **La simulación exige runtime de la misma versión que TIA** (ADR-017).

**Arreglo**: instalar SIMATIC WinCC Unified PC V20. Sin licencia funciona en modo trial (aviso cada 10 min, 1 hora).

**Evidencia**: 4960, 4970, 4980 en 50-errores/README.md (ya documentado arriba) + capturas 31-tia-hmi-menu.png, 32-tia-hmi-started.png, 33-hmi-runtime-fullscreen.png.

---

## Errores del 2026-10-23 (PLCSIM Advanced y descarga por API)

### `-48` / `0xffffffd0` (`SREC_COMMUNICATION_INTERFACE_NOT_AVAILABLE`) en `set-network-mode`

**Síntoma:** el adaptador `tia-claude-plcsim-adapter.exe --transport tcpip-local` registra la instancia pero falla al fijar el modo:
`{"status":"failed","stage":"set-network-mode","modeReadCode":"0x0","modeSetCode":"0xffffffd0","modeVerifyCode":"0x0"}`.
`GetNetworkMode` responde `0x0`, así que el runtime está vivo; lo que no existe es la **interfaz de comunicación TCP/IP**.

**Lo que se descartó con evidencia (2026-10-23):**

| Hipótesis | Comprobación | Resultado |
|---|---|---|
| Falta de permisos | misma sonda con `RunAs` | `-48` idéntico (`50-elevated-probe.log`) |
| IP del adaptador no publicada | `IPAddress=192.168.0.100` escrito en la clave de clase del driver + `Restart-NetAdapter` | sigue `-48` |
| Driver o binding ausentes | `sc query plcsimlwf` = RUNNING (v102, 2024); `Get-NetAdapterBinding` = enabled en `Ethernet 2` | correctos |
| Componente de red no registrado | `netcfg -l oem100.inf -c s -i plcsim_ndislwf` → exit 0; `netcfg -q` → "está instalado" | correcto (`55-netcfg-repair.log`) |

**Causa raíz (aislada):** `Siemens.Simatic.PlcSim.Advanced.AdapterConfigurator.exe` (la herramienta que escribe `CommAdapter` y activa el switch) **aborta con `-999999`** incluso lanzada normal y elevada, sin ventana y sin salida (`54-adapter-configurator-probe.log`). Es decir: la configuración del conmutador virtual no se puede regenerar, y por eso el runtime no encuentra interfaz de comunicación. `CommAdapter` sigue vacío en `HKLM\SYSTEM\CurrentControlSet\Services\plcsimlwf\Parameters`.

**La reparación por MSI no es viable:** `msiexec /fa C:\WINDOWS\Installer\60f89.msi` (Driver64, en caché) **se cuelga indefinidamente en la acción `ADSStartup`** (log congelado, CPU 0; `52-msi-driver64.log`). Abortarla no deja daño: Driver64 sigue registrado, `plcsimlwf.sys` intacto y sin reinicio pendiente. `netcfg -i` con la sintaxis equivocada devuelve el texto de ayuda y exit `-1` (la clase correcta para un `NetService` es `-c s`, no `-c net`).

**Arreglo:** reinstalar **PLCSIM Advanced V7 desde su instalador original** (no está en el equipo: en Descargas solo hay el ISO de WinCC Unified RT V20). Los MSI cacheados no sirven para reparar.

**Evidencia:** `70-runs/2026-10-23-simulacion-advanced/` → `50-elevated-probe.log`, `51-adapter-elevated.jsonl`, `52-repair-advanced.log`, `52-msi-driver64.log`, `53-adapter-configurator.log`, `54-adapter-configurator-probe.log`, `55-netcfg-repair.log`, `55-adapter-after-netcfg.jsonl`.

---

### `Connect to module PLC_1 failed` con ruta `PLCSIM [no IP]`: no es un fallo de la instancia

**Síntoma:** idéntico error con **tres** orígenes distintos de instancia:

1. Instancia clásica creada por CDP (`Instance_1`).
2. Instancia clásica tras **reiniciar TIA** (guardar, cerrar, reabrir) y `CheckDownloadReadiness.ready=true`.
3. Instancia **PLCSIM Advanced creada desde su Panel de Control por UI Automation** (como exige el manual), encendida y con `192.168.0.1`.

`CheckDownloadReadiness` devuelve siempre `downloadRouteCount: 1` con `pgPcInterface: "PLCSIM"`, `pgPcAddresses: ""`, `targetAddresses: ""`. Forzar la IP destino tampoco sirve: `DownloadToPlc(..., targetIpAddress="192.168.0.1")` → **`No download route reaches target IP '192.168.0.1'`**.

**Causa:** el Softbus **no es una ruta de red para el `DownloadProvider` de Openness**. Es una limitación de diseño, no un estado roto: la descarga por API solo es posible con **PLCSIM Advanced en TCP/IP**, que es justo lo que devuelve `-48`.

**Corrección a la entrada del 2026-10-22:** aquella decía que reiniciar la máquina arreglaba el `[no IP]`. **Hoy no se cumple**: tras el reinicio de las 07:09:34 la clave de clase sigue publicando la IP, pero `CheckDownloadReadiness` continúa devolviendo `pgPcAddresses: ""` (`46-download-panel-instance-result.json`). El reinicio no es un arreglo fiable.

**Evidencia:** `45-download-ui-result.json`, `46-download-panel-instance-result.json`, `47-download-with-targetip-result.json`.

---

### Receta: crear y encender una instancia de PLCSIM Advanced por UI Automation (sin ratón)

El Panel de Control es **WPF y sí expone UIA** (TIA no: su shell WinForms devuelve 0 botones). Identificadores verificados:

| Elemento | AutomationId | Patrón |
|---|---|---|
| Desplegar "Start Simulated PLC Instance" | `HeaderSite` | **Toggle** (no Invoke) |
| Nombre de instancia | `UIAutPLCSIMAdv_InstanceInfoName` | Value |
| Familia PLC | `UIAutPLCSIMAdv_InstanceInfoPLCTypeComboBox` | ExpandCollapse (queda **deshabilitado** hasta fijar nombre) |
| Crear | `UIAutPLCSIMAdv_InstanceInfoStartButton` | Invoke (se habilita al escribir el nombre) |
| Encender/apagar | `UIAutPLCSIMAdv_RunningInstancesPowerOnOffButton` | **Toggle** |
| Desregistrar | `UIAutPLCSIMAdv_RunningInstancesUnregisterButton` | Invoke |

**Trampa:** la instancia recién creada ya nace con `ToggleState = On`. Si se hace `Toggle()` "para encenderla" se **apaga**. Comprobar el estado antes de togglear.

**Efecto:** instancia `PLC_1` registrada, `192.168.0.1`, `Runtime.Instance.x64` vivo. No arregla la descarga por sí sola (ver arriba), pero sirve para cualquier prueba que necesite instancia sin tocar el ratón.

**Evidencia:** `46-download-panel-instance.json` (secuencia MCP posterior).

---

### LogDevice `PLCSIM.Local.xml` apunta a `plcsimscp64.dll`, que no existe en disco

**Síntoma:** el LogDevice de OAM en `C:\ProgramData\Siemens\Automation\Simatic OAM\data\LogDevices\PLCSIM.Local.xml` declara `<Unit>plcsimscp64.dll</Unit>`, y ese DLL **no está en ningún directorio** (ni System32, ni SysWOW64, ni Siemens).

**Causa:** es el LogDevice **legado de S7-PLCSIM V5.4** (también instalado: `SIMATIC S7-PLCSIM V5.4 + SP8 + Upd3`), no el transporte de PLCSIM V20 ni de Advanced.

**Conclusión:** **no es la causa** del fallo de descarga. El runtime V20 usa `plcsimscputil64.dll` + `VplcHost64`, y Advanced usa su propio driver LWF. No perseguir este DLL.

**Evidencia:** `Get-ChildItem` sobre `Program Files*`, `System32`, `SysWOW64` → 0 resultados; entrada de desinstalación de PLCSIM V5.4 presente.

---

## Errores del 2026-10-26 (compilación de hardware en rojo, DEMO-Cinta01)

### `PLC_1` en rojo, Description vacía, y el aviso de la pantalla de la CPU

**Síntoma.** `CompileSoftware` termina en `Success`, 0 errores y 0 avisos
(«No block was compiled. All blocks are up-to-date.»), pero **Compile → Hardware
(rebuild all)** deja `Rail_0` y `PLC_1` en rojo con 1 error y 1 aviso. La columna
Description de esas dos filas está vacía. El único texto de la rejilla es el aviso
hijo `The S7-1500 CPU display does not contain any password protection.` en
`CPU display_1`, y esa fila marca **0 errores** y 1 aviso. El Load preview dice
`Compile before downloading to device` y `Loading will not be executed.` Refresh
no lo quita. Volver a compilar el hardware, sin cambiar la CPU, repite el mismo
resultado. `Rail_0` solo suma lo que ya cuenta `PLC_1`: no es un segundo error.

**No es el aviso de la pantalla.** Siemens lo documenta como aviso. No bloquea la
descarga y no se quita poniéndole contraseña al display.

**No es la protección de datos confidenciales.** Ese otro fallo tiene texto propio:
`The PLC communication certificate cannot be configured without the password for
confidential PLC configuration data. Enter the password.` Corresponde a
`MasterSecretConfiguration=WithoutPassword` (la casilla «Protect confidential PLC
configuration data» marcada y sin contraseña). El arreglo es `Unprotect()` sin
argumentos, solo en copia aislada, y está en
[R17](../20-recetas/R17-aceptacion-plcsim.md). No se inventa contraseña y no se
llama `Reset()`. En DEMO-Cinta01, el 2026-10-26, esa casilla ya estaba quitada y
el hardware seguía en rojo.

**Causa.** El nivel de acceso de la CPU no era `Full access (no protection)`. En
una S7-1500 el valor por defecto es `No access (complete protection)`. Si el nivel
es cualquier otro distinto de `Full access (no protection)` —o de `Full access
including fail-safe` en una F-CPU— y no hay contraseña de acceso completo, la
compilación de hardware falla. Openness lo enuncia como `Password must not be
empty`. En la rejilla de TIA esa frase puede no salir: la fila del PLC cuenta 1
error y deja Description vacía.

**Arreglo.** CPU estándar, no F, firmware hasta V3.0:

1. `PLC_1` → Device configuration. Clic en la CPU, no en el display.
2. Properties → Protection & Security → **Access control**.
3. En la primera columna de la tabla, marcar **Full access (no protection)**.
4. Dejar las contraseñas vacías. No inventar una.
5. Compile → Hardware (rebuild all). La fila de `PLC_1` tiene que quedar con 0
   errores. El aviso de la pantalla, si reaparece, no vuelve a ponerla en rojo.

**Verificado** el 2026-10-26 en `DEMO-Cinta01` (CPU 1513-1 PN, TIA V20). A las
15:07 la rejilla pasó a `Compiling finished (errors: 0; warnings: 0)`, con `PLC_1`
en 0 errores y 0 avisos. Evidencia:
`70-runs/2026-10-26-hmi-runtime/ui/tia-20261026-150750.png`. La frase `Password
must not be empty` no llegó a leerse en la rejilla; lo que se verificó es que
cambiar el nivel de acceso quitó el error.

**Firmware posterior a V3.0.** No existe esa tabla: el nivel vive en la
administración local de usuarios y roles. Parar y leer esa página. No rellenar
contraseñas a ciegas.

**No hacer.** Activar «Protect confidential PLC configuration data», poner
contraseña al display, llamar `Reset()` en `PlcMasterSecretConfigurator`, ni
pulsar Load mientras la fila Compile del Load preview siga en rojo.

Fuentes: [niveles de acceso S7-1500, STEP 7 V20](https://docs.tia.siemens.cloud/r/en-us/v20/functional-description-of-s7-1500-cpus-s7-1500/setting-the-operating-behavior-s7-1500/protection-security-s7-1500/settings-for-access-levels-s7-1500/configuring-access-levels-s7-1500)
y [Access level setting, Openness V20](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/tia-portal-openness-api/functions-for-accessing-the-data-of-a-plc-device/functions-for-accessing-plc-service/access-level-setting).

