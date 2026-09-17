# Capacidades y alcance por tipo de conexión

> Documento de referencia único: para qué sirve cada forma de conectar un agente de IA a TIA
> Portal en este workspace, qué puede hacer exactamente y qué no. No repite reglas de
> `AGENTS.md` — las traduce en una matriz consultable. Si hay conflicto, `AGENTS.md` manda.

Cualquier harness (Claude Code, Codex, OpenCode, Antigravity, Cursor...) llega a TIA Portal por
el mismo camino: `.mcp.json` (o el fichero equivalente del harness) apunta a uno de los dos
servidores MCP de `30-tools/mcp/`, con un perfil concreto de `30-tools/mcp/servers.json`. El
harness no cambia lo que es posible; solo cambia cómo se genera esa configuración
(`30-tools/scripts/Sync-HarnessConfigs.ps1`, ver `30-tools/harnesses/`).

---

## 1. Los cuatro perfiles MCP

| Perfil | Servidor(es) | Confirmación | Qué es, en una frase |
|---|---|---|---|
| `read` | `tia-inspect` sin `--allow-write` | No — es el perfil por defecto | Mirar y exportar sin tocar nada |
| `write` | `tia-inspect --allow-write` | Sí, explícita para la tarea | Editar bloques y tablas que ya existen |
| `create` | `tia-create --profile lite` | Sí, explícita | Crear proyecto, hardware, red, HMI Unified |
| `full` | ambos servidores a la vez | Sí, explícita | Analizar y crear en la misma sesión |

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
- Cerrar sesión (`CloseProject`, `Disconnect` — esto último no cierra TIA, ver
  [`conexion-y-sesiones.md`](conexion-y-sesiones.md)).

**Qué NO puede hacer (por diseño, no por límite técnico):**
- Ninguna de las ~40 herramientas de escritura existe en el roster cuando el servidor arranca sin
  `--allow-write`. No es que fallen: **no están registradas**, el modelo no puede verlas ni
  llamarlas. Verificado: 59 herramientas en modo lectura.
- No crea, no modifica, no borra bloques, tipos, tags, tablas ni hardware.
- No descarga nada a PLCSIM ni a hardware.

**Cuándo usarlo:** por defecto, siempre que la tarea sea entender, auditar, documentar o preparar
una propuesta. Es el perfil que registra `.mcp.json` en este workspace.

---

## 3. `write` — `tia-inspect --allow-write`

**Qué añade sobre `read`:** las ~40 herramientas de escritura para bloques y tipos **que ya
existen** en el proyecto: modificar interfaz/fuente de un FB/FC/OB/DB, `ImportBlock`,
`ImportFromDocuments`, `ImportType`, operaciones compuestas de copiar/mover bloque o tipo
(exportar→importar→borrar origen, con el número de bloque viajando), `SaveProject` / `SaveSession`.

**Qué sigue sin poder hacer:**
- **No existe un "crear bloque" genérico.** Solo hay `CreateFB` y `CreateInstanceDB` como
  constructores nativos; todo lo demás (OB, FC, DB global, ArrayDB) entra por importación desde
  XML SimaticML o desde fuente externa SCL (`ImportPlcExternalSource` →
  `GenerateBlocksFromExternalSource`) o desde documentos `.s7dcl/.s7res` (V20+).
- No toca bloques con **know-how protection**: se rechazan antes de cualquier edición.
- No edita **bloques F / tags de safety**: casi toda operación se rechaza, a veces pidiendo
  contraseña de safety; el agente no debe reintentar, debe reportar y parar.
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

**Cuándo usarlo:** para modificar lógica, tipos o tablas que ya existen en un proyecto abierto y
confirmado. Requiere reconocimiento explícito del perfil por parte de quien opera el harness.

---

## 4. `create` — `tia-create --profile lite`

**Qué puede hacer:** lo que `tia-inspect` no cubre en absoluto —
- Crear un proyecto nuevo (`ScaffoldProject`, siempre con `dryRun=true` primero).
- Añadir hardware y configurar red.
- Crear pantallas y objetos de **WinCC Unified** por API.
- El roster visible en perfil `lite` es un subconjunto; hay ~224 herramientas en el servidor
  completo. Si falta una capacidad, se busca con `FindTools` en lenguaje natural y se llama con
  `CallTool` y la firma exacta — no se declara "no existe" sin haber hecho esa comprobación.

**Qué NO puede hacer:**
- No sustituye a `tia-inspect` para inspección fina, `WhereUsed`, `FindInCode` ni export textual
  diffeable: eso lo cubre mejor `tia-inspect`.
- No migra un proyecto de versión (V16→V20, por ejemplo). Openness no expone "migrar" en ningún
  servidor; se hace a mano desde TIA Portal, una vez por proyecto
  (ver [`50-examples/MIGRACION-V16-a-V20.md`](../../50-examples/MIGRACION-V16-a-V20.md)).
- No descarga nada por sí solo a hardware ni a PLCSIM sin pasar por las puertas de §5/§6.

**Cuándo usarlo:** proyectos nuevos, hardware/red desde cero, HMI Unified. Requiere
reconocimiento explícito y `dryRun` antes de aplicar cualquier plan real.

---

## 5. `full` — ambos servidores a la vez

Combina `write` y `create` en la misma sesión: analizar con `tia-inspect` y crear/ampliar con
`tia-create` sin cambiar de configuración a mitad de tarea. No añade capacidades nuevas más allá
de la suma de §3 y §4; añade el riesgo de que ambos servidores compitan por el mismo proyecto
abierto. Openness **no es thread-safe** (`Operation.Run` serializa con un lock global) — nunca se
paralelizan llamadas, y con dos servidores activos hay que serializar también entre ellos.
Requiere el mismo reconocimiento explícito que `create`.

---

## 6. El eje que cruza a los cuatro perfiles: destino de una descarga

Ningún perfil MCP, por sí mismo, autoriza una descarga (`Download`) a una CPU. La autorización
depende de **a qué target apunta la ruta PG/PC**, y ese eje es ortogonal a los perfiles de arriba:

| Destino | Autorización | Detalle |
|---|---|---|
| **PLCSIM / PLCSIM Advanced** | Libre, sin pedir permiso cada vez | Debe ser una instancia **virtual desechable**: la ruta PG/PC tiene que identificar explícitamente el `Siemens PLCSIM Virtual Ethernet Adapter` (gate `plcsimVirtualAdapterReady=true` en `Write-TiaSimulationReadiness.ps1`). Tener PLCSIM Advanced instalado o poder hacer `PowerOn/PowerOff` de una CPU temporal **no** autoriza la descarga por sí solo. |
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
gana realmente V21 (tipos de datos PLC como documento, `PlcWatchTable.Name` escribible, Version
Control Interface completo — ver [`limites.md`](limites.md) §Versiones), está en
[ADR-014](../../00-meta/decisiones/ADR-014-version-v21.md). Los cuatro perfiles del §1 no
cambian de significado en V21; lo que cambia es qué binario y qué ruta usan.

---

## 8. Lo que ningún servidor cubre hoy

| Falta | Alternativa |
|---|---|
| Migrar un proyecto de versión | Manual desde TIA Portal, una vez por proyecto |
| Cerrar TIA Portal desde MCP (`ExitAndCloseTiaPortal` no está expuesta) | `30-tools/scripts/Stop-TiaPortal.ps1` |
| `Attach` a una ventana de TIA ya abierta con interfaz | No existe en el `tia-inspect` instalado; si hay una ventana visible y el proyecto objetivo no está confirmado, la sesión de escritura se bloquea (ver [ADR-012](../../00-meta/decisiones/ADR-012-connect-no-es-attach.md)) |
| Validación visual de una pantalla HMI o comportamiento real de un programa | El MCP no sustituye al Runtime ni a mirar la pantalla; compilar y hacer `PowerOn/PowerOff` no demuestra comportamiento |

Detalle ampliado de límites de la API (no de los servidores): [`limites.md`](limites.md).
Ciclo de vida de la conexión, tiempos medidos y gestión de instancias:
[`conexion-y-sesiones.md`](conexion-y-sesiones.md).

---

## 9. Resumen para decidir en 10 segundos

```
¿Solo quiero entender / documentar / exportar?          → read
¿Voy a tocar un bloque o tipo que YA existe?             → write   (backup + dryRun + compilar 0 errores)
¿Voy a crear proyecto / hardware / red / HMI Unified?    → create  (dryRun primero)
¿Necesito las dos cosas en la misma sesión?               → full    (ojo con la concurrencia)
¿Voy a descargar algo a una CPU?
    target = PLCSIM virtual desechable                    → libre
    target = PLC real / no puedo asegurar que es virtual   → PARA y pide confirmación explícita ahora
```
