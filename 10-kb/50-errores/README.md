# Catálogo de errores

> Síntoma → causa → arreglo. Es donde un agente pierde más tiempo, así que es lo primero que se
> escribió.
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
| `WriteDisabled` | El servidor arrancó sin `--allow-write` | Las 40 herramientas de escritura ni se registran. Hay que relanzarlo con la bandera |
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

El agente llamó a `Connect` cuando debía llamar a `Attach`. Dos instancias sobre el mismo
proyecto es una forma excelente de perder trabajo.

🔒 **Si TIA ya está abierto, se hace attach.** Está en `AGENTS.md` §2.

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

## Cuando el error no está aquí

1. Lee el mensaje entero, incluido el `InnerException` si lo trae
2. Comprueba si es un [límite de la API](../10-openness/limites.md) y no un fallo
3. Si es nuevo y te costó averiguarlo: **añádelo a este fichero.** Eso es lo que hace que la
   base de conocimiento valga con el tiempo
