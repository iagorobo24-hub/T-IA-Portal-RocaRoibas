# Capacidades y alcance por tipo de conexión

> Documento de referencia único: para qué sirve cada forma de conectar un agente de IA a TIA
> Portal en este workspace, qué puede hacer exactamente y qué no. No repite reglas de
> `AGENTS.md` — las traduce en una matriz consultable. Si hay conflicto, `AGENTS.md` manda.

En el **camino MCP**, cada harness puede apuntar mediante `.mcp.json` (o su fichero equivalente) a
uno de los servidores de `30-tools/mcp/` con un perfil de `30-tools/mcp/servers.json`; la
configuración común se genera con `30-tools/scripts/Sync-HarnessConfigs.ps1` (ver
`30-tools/harnesses/`). Esto describe solo MCP: las políticas, plugins, Computer Use nativo y
permisos de aplicaciones dependen de cada host/sesión y no se heredan automáticamente entre
Codex, Claude Code, OpenCode u otros agentes.

| Ruta | Depende de | Puede aportar | Límite de esta sesión |
|---|---|---|---|
| Siemens Openness API | TIA/Openness de versión compatible y una integración .NET/cliente autorizada | Leer, crear, modificar, borrar, compilar, importar/exportar o diagnosticar los objetos soportados por esa versión/modelo | La API documentada no demuestra que este host la invoque directamente; las llamadas locales fueron mediante MCP |
| Servidores MCP locales | Binario instalado, perfil actual, herramientas y esquema expuestos | Acciones concretas listadas por `tools/list` o `FindTools`, sujetas a guardas del servidor y contrato de `AGENTS.md` | Hay inventario por nombre/schema y evidencia solo para las llamadas enumeradas en el plan maestro; schema no equivale a ejecución |
| Computer Use nativo | Integración y permiso habilitado en la aplicación Codex/host y sesión Windows activa | Inspeccionar y operar la UI visible cuando Openness no muestra renderizado, diálogos o runtime | Verificado en Codex por `node_repl` + `@oai/sky`; el acceso debe redescubrirse por sesión y no se hereda a otros hosts |
| Windows UI Automation (UIA) | Controles de TIA que publiquen propiedades/patrones accesibles; script .NET/PowerShell | Automatizar controles estables por selector semántico, con comprobaciones de estado | Candidato para flujos gráficos repetibles; todavía sin inspección/aceptación live de controles TIA V20. No usar coordenadas fijas para mutaciones |
| Playwright | Página web abierta en un navegador compatible | Automatizar navegación y pruebas de aplicaciones web | No controla TIA Portal Desktop. Reservar para runtimes/paneles HMI que se ejecuten realmente en navegador; compatibilidad pendiente por modelo/runtime |

El registro accionable del perfil MCP está en el apéndice del [plan maestro](../../../docs/superpowers/plans/2026-09-21-tia-agent-operating-model.md).

---

## 1. Los cuatro perfiles MCP

| Perfil | Servidor(es) | Confirmación | Qué es, en una frase |
|---|---|---|---|
| `read` | `tia-inspect` sin `--allow-write` | Perfil por defecto | Inspeccionar y exportar; no registra mutaciones |
| `write` | Invocación puntual: `tia-inspect --isolated --fixture-root <run-dir> --allow-write` | Reconocimiento explícito y manifiesto de copia desechable | Cambiar elementos estándar autorizados dentro de un fixture |
| `create` | `tia-create --profile lite` | Reconocimiento explícito y `dryRun` | Crear proyecto, hardware, red y HMI Unified según tools expuestos |
| `full` | `tia-inspect` aislado con fixture + `tia-create --profile lite` | Reconocimiento explícito y raíz manifiesta requerida para `tia-inspect` | Escritura limitada al fixture; acciones online/físicas siguen sujetas a gates y política |

Fuente: `30-tools/mcp/servers.json` y [ADR-011](../../00-meta/decisiones/ADR-011-perfiles-y-proyectos-abiertos.md).

---

## 2. `read` — `tia-inspect` de solo lectura

**Qué puede hacer:**
- Conectar/reengancharse a una instancia de TIA (`Connect`, `GetState`, `Doctor`).
- Recorrer el árbol real del proyecto y del software (`GetProjectTree`, `GetSoftwareTree`,
  `GetDevices`, `GetBlocks…`, `GetTypes…`, `GetTagTables…`, `GetWatchTables…`, `GetForceTables`).
- Leer código y metadatos (`GetBlockSource`, `GetBlockInfo`, `GetBlockInterface`,
  `GetTypeSource`, `GetTagInfo`, `GetConstants`).
- Buscar y trazar (`FindInCode`, `WhereUsed`, `GetCrossReferences`, `ResolveObjectPath`).
- Exportar a texto para git (`ExportBlock(s)`, `ExportBlocksAsDocuments`, `ExportType(s)`,
  `ExportTagTable`, `ExportWatchTable`, `ExportPlcAsSourceTree`, `GenerateSources`).
- Compilar (`CompileSoftware`) — compilar **no** modifica el `.ap20` guardado en disco, solo el
  estado en memoria/consistencia de bloques.
- Desconectar (`Disconnect` no cierra TIA, ver [`conexion-y-sesiones.md`](conexion-y-sesiones.md)).
- `OpenProject` y `CloseProject` sólo operan en una sesión aislada con manifiesto de fixture; no
  sustituyen un proyecto de una ventana visible.

**Qué NO puede hacer (por diseño, no por límite técnico):**
- Ninguna herramienta de escritura se registra si falta cualquiera de `--allow-write`,
  `--isolated`, `--fixture-root` o el manifiesto válido. Los generadores de perfil `write/full`
  exigen ahora la raíz de fixture y la insertan en los argumentos del servidor.
- `Invoke-TiaSclProposalApply.ps1` acepta reemplazos de bloques existentes, no crea bloques nuevos.
  No autorizar imports de destinos nuevos mientras falte el flujo de creación/clasificación previo
  descrito en [`AGENTS.md`](../../AGENTS.md#33-bloques-protegidos-y-seguridad).
- **Estado observado del apply SCL (2026-09-21):** el roster vivo del perfil V20 aislado `write`
  tiene 84 herramientas y no registra `ImportSources` ni `ImportFromDocuments`;
  `Invoke-TiaSclProposalApply.ps1 -Apply` consulta el roster y se bloquea antes de mutar si falta el
  importador requerido. El preview local valida/estaciona el archivo, pero no prueba una importación
  en TIA. Los documentos `.s7dcl` permanecen solo-preview hasta verificar conteos exactos y readback
  de su importador. No se permite llamar al importador genérico como atajo. Evidencia local:
  `70-runs/tia-capabilities/20260921-04-write-tools-live.json`.
- No crea, no modifica, no borra bloques, tipos, tags, tablas ni hardware.
- No descarga nada a PLCSIM ni a hardware.

**Cuándo usarlo:** por defecto, siempre que la tarea sea entender, auditar, documentar o preparar
una propuesta. Es el perfil que registra `.mcp.json` en este workspace.

---

## 3. `write` — `tia-inspect` en un fixture explícito

**Activación:** `--isolated --fixture-root <run-dir> --allow-write`. La raíz debe contener
`.tia-agent-fixture.json` con la ruta exacta del `.ap20`, `disposable=true` y una copia de backup
existente. El servidor abre sólo ese proyecto en una instancia headless propia; no se conecta a una
ventana visible. `New-TiaFixtureManifest.ps1` compara el fixture con su backup antes de autorizarlo.

**Qué permite:** sólo operaciones presentes en el schema vigente, tras el preflight global de
F/Safety/know-how. Las mutaciones de fuente genérica quedan temporalmente desregistradas.
La escritura de propuestas SCL permanece bloqueada mientras el roster no ofrezca el importador
requerido; el runner comprueba la disponibilidad antes de intentar la mutación.

**Qué sigue sin poder hacer:**
- **No existe un "crear bloque" genérico.** Solo hay `CreateFB` y `CreateInstanceDB` como
  constructores nativos; todo lo demás (OB, FC, DB global, ArrayDB) entra por importación desde
  XML SimaticML o desde fuente externa SCL (`ImportPlcExternalSource` →
  `GenerateBlocksFromExternalSource`) o desde documentos `.s7dcl/.s7res` (V20+).
- No toca bloques con **know-how protection**: se rechazan antes de cualquier edición.
- No modifica ningún proyecto que contenga un bloque F, una tag Safety, un bloque/tipo protegido o
  un bloque cuya clasificación sea desconocida. El preflight corre bajo acceso exclusivo antes de
  cada escritura. Es global y conservador: puede impedir cambios estándar en proyectos mixtos.
- No importa, renombra, copia, mueve ni borra PLC data types. Los UDT F-compliant requieren
  protección Safety y el API V20 usado aquí no expone un clasificador independiente suficiente.
- No crea ni borra hardware, red ni pantallas HMI — eso es terreno de `tia-create`.
- No renombra la tabla de observación (`PlcWatchTable.Name` de solo lectura antes de V21).
- No añade una fila real a una tabla de observación (solo hay creador de filas de comentario) ni
  crea/borra la tabla de forzado (una por PLC, la gestiona el sistema).
- No descarga nada a un PLC — escribir el proyecto en TIA y descargarlo a una CPU son operaciones
  distintas; ver §5 y §6.

**Puertas obligatorias antes de guardar** (contrato en `AGENTS.md` §3.2, no negociable): backup
del `.ap20`, leer el bloque entero antes de tocarlo, `dryRun`/preview cuando la herramienta lo
ofrezca, un bloque por vez, compilar con 0 errores antes de `SaveProject`/`SaveSession`. Si no
compila limpio, no se guarda.

**Cuándo usarlo:** aceptación en copias desechables. La escritura en proyectos de cliente queda
deshabilitada hasta que exista un procedimiento adicional aprobado.

---

## 4. `create` — `tia-create --profile lite`

**Estado observado:** la captura de `lite` del 21-09 tenía 55 tools visibles, incluidos `FindTools`
y `CallTool`. El schema no enumera necesariamente las capacidades dinámicas.

**Qué puede hacer:** lo que `tia-inspect` no cubre en absoluto —
- Crear un proyecto nuevo (`ScaffoldProject`, siempre con `dryRun=true` primero).
- Añadir hardware y configurar red.
- Crear pantallas y objetos de **WinCC Unified** por API.
- El roster visible en perfil `lite` es un subconjunto; la captura `full` guardada el 21-09 tenía
  222 tools. Esa captura demuestra schema, no configuración activa ni ejecución. Si falta una
  capacidad, se busca con `FindTools` en lenguaje natural y se llama con
  `CallTool` y la firma exacta — no se declara "no existe" sin haber hecho esa comprobación.
- El build local V20 añade `GetTags.isSafety` y `GetBlocks.isFailsafe`; el propio
  `DownloadToPlc` vuelve a enumerar todos los bloques y tags, bloquea F/Safety, protección o
  clasificación desconocida y hace esa barrera en la sesión que descarga. Esto evita depender del
  juicio del agente o de un JSON de propuesta.

**Qué NO puede hacer:**
- No sustituye a `tia-inspect` para inspección fina, `WhereUsed`, `FindInCode` ni export textual
  diffeable: eso lo cubre mejor `tia-inspect`.
- La API Openness V20 sí documenta `Projects.OpenWithUpgrade`: abre y actualiza un proyecto de la
  versión inmediatamente anterior. Siemens advierte que un proyecto más antiguo puede devolver
  una excepción. En este workspace hay una prueba local de un proyecto V16 concreto, pero no
  demuestra compatibilidad universal ni sustituye backup, compilación y lectura del log. Consultar
  [R01](../20-recetas/R01-inventariar-proyecto.md) y
  [la nota de migración](../../50-examples/MIGRACION-V16-a-V20.md).
- No descarga nada por sí solo a hardware ni a PLCSIM sin pasar por las puertas de §5/§6.

**Cuándo usarlo:** proyectos nuevos, hardware/red desde cero, HMI Unified. Requiere
reconocimiento explícito y `dryRun` antes de aplicar cualquier plan real.

---

## 5. `full` — perfil ampliado de `tia-create`

El nombre `full` identifica el perfil ampliado de `tia-create`; no implica que la configuración local
use ambos servidores ni que todas las acciones estén autorizadas. El schema guardado contiene
`GoOnline`, `DownloadToPlc`, importaciones masivas y cambios de Safety/hardware. La presencia en
tools/list no permite ejecutar esas operaciones. Toda sesión que combine servidores debe usar el
mutex `Local\TIA-Claude-McpSession`; nunca se paralelizan llamadas Openness.

**Estado V20 del build local (2026-09-25):** el roster `full` ahora incluye `GetTags`, y
`GetBlocks` devuelve `isFailsafe` nullable. La evidencia de solo lectura en una sesión MCP
adjuntada al proyecto de prueba confirmó dos bloques estándar y dos tags no Safety:
[`20260925-tia-create-safety-live-read.json`](../../70-runs/tia-capabilities/20260925-tia-create-safety-live-read.json).
La propia ruta `DownloadToPlc` ejecuta un veto F/Safety y protección independiente. La descarga
sigue pendiente: falta completar integridad/restauración del manifiesto de la fixture, compilar
para simulación, confirmar destino simulado en el diálogo y ejecutar el plan funcional de R17.

---

## 6. El eje que cruza a los cuatro perfiles: destino de una descarga

Ningún perfil MCP, por sí mismo, autoriza una descarga (`Download`) a una CPU. La autorización
depende de **a qué target apunta la ruta PG/PC**, y ese eje es ortogonal a los perfiles de arriba:

| Destino | Autorización | Detalle |
|---|---|---|
| **PLCSIM / PLCSIM Advanced** | Libre, sin pedir permiso cada vez | Preferir instancia virtual desechable por Softbus local (`PLCSIM` como PG/PC y `networkMode=SOFTBUS`). TCP/IP local es alternativo y exige `<Local>`, adaptador Siemens con IP en la misma subred y ruta inequívoca. La instancia debe ser identificada como simulada antes de descargar; tener PLCSIM Advanced instalado o poder hacer `PowerOn/PowerOff` no autoriza la descarga por sí solo. |
| **Hardware físico** | **NUNCA sin confirmación explícita del usuario en ese mismo momento** | Una autorización de hace diez mensajes no vale. Una autorización para otro PLC no vale. Antes de proponerlo hay que decir qué PLC, qué bloques y qué pasa si la máquina está en marcha. **Si no se puede distinguir con certeza si el target es simulado o real, se asume real.** |

Esta regla está en `AGENTS.md` §3.1 y es la única de todo el documento que no admite
interpretación local ni excepción de perfil: aplica igual en `write`, `create` o `full`.

---

## 7. Versión de TIA Portal: V20 por defecto, V21 como receta sin verificar

Todo lo de arriba se ha verificado contra **V20**, la versión operativa de este workspace
([ADR-002](../../00-meta/decisiones/ADR-002-version-tia.md)). Hay una rama **V21 preparada pero
no probada en esta máquina** (no hay V21 instalado aquí):

```powershell
30-tools\mcp\tia-inspect\build.ps1 -TiaMajor 21    # ya estaba preparado en el upstream
30-tools\mcp\tia-create\build.ps1 -TiaMajor 21     # build.ps1 nuevo, mismo patrón que tia-inspect
```

Antes de tratar una sesión V21 como equivalente a V20, hay que repetir `Doctor` y confirmar que
Engineering/Portal V21 dan `OK` en **esa** máquina, y correr al menos un scaffold desechable de
aceptación. El detalle completo, incluidos los dos `.csproj` distintos de `tia-create` y qué
diferencias locales siguen pendientes de comprobar (por ejemplo `PlcWatchTable.Name` escribible y
Version Control Interface — ver [`limites.md`](limites.md) §Versiones), está en
[ADR-014](../../00-meta/decisiones/ADR-014-version-v21.md). No se presenta el soporte de tipos PLC
en documentos SIMATIC SD como novedad exclusiva de V21: la documentación base V20 ya los incluye.
Los cuatro perfiles del §1 no
cambian de significado en V21; lo que cambia es qué binario y qué ruta usan.

---

## 8. Lo que ningún servidor cubre hoy

| Falta | Alternativa |
|---|---|
| Abrir/actualizar versiones previas | Openness V20 documenta `OpenWithUpgrade` para la versión inmediatamente anterior. Para una versión más antigua, comprobar la ruta compatible y no generalizar la única prueba local V16. |
| Cerrar TIA Portal desde MCP (`ExitAndCloseTiaPortal` no está expuesta) | `30-tools/scripts/Stop-TiaPortal.ps1` |
| `Attach` a una ventana de TIA ya abierta con interfaz | No existe en el `tia-inspect` instalado; si hay una ventana visible y el proyecto objetivo no está confirmado, la sesión de escritura se bloquea (ver [ADR-012](../../00-meta/decisiones/ADR-012-connect-no-es-attach.md)) |
| Control nativo de la ventana TIA Portal | En Codex, comprobar el plugin nativo `computer-use` con `node_repl` + `@oai/sky`, listar ventanas y leer el título/estado antes de actuar. `mcp__cua_repl` solo expone navegador; su `apps=[]` no mide aplicaciones Windows. En la sesión 2026-09-21 se abrió visualmente el clon IOT2050 desechable y se navegó hasta `PLC_1 > Program blocks`; no se editó por GUI. Esta capacidad pertenece a la sesión de Codex y no se hereda automáticamente por otros agentes. |
| Validación visual de una pantalla HMI o comportamiento real de un programa | El MCP no sustituye al Runtime ni a mirar la pantalla; compilar y hacer `PowerOn/PowerOff` no demuestra comportamiento |

Detalle ampliado de límites de la API (no de los servidores): [`limites.md`](limites.md).
Ciclo de vida de la conexión, tiempos medidos y gestión de instancias:
[`conexion-y-sesiones.md`](conexion-y-sesiones.md).

---

## 9. Resumen para decidir en 10 segundos

```
¿Solo quiero entender / documentar / exportar?          → read
¿Voy a tocar lógica estándar para acceptance en fixture? → write (manifiesto + backup + preflight + compilación)
¿Voy a crear proyecto / hardware / red / HMI Unified?    → create lite (dryRun primero; acciones autorizadas)
¿Tengo sólo un schema full guardado?                     → no asumir que está configurado o probado
¿Voy a descargar algo a una CPU?
    target = PLCSIM virtual desechable                    → libre
    target = PLC real / no puedo asegurar que es virtual   → PARA y pide confirmación explícita ahora
```
