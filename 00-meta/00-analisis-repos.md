# Análisis de repositorios de referencia

> Estado: **verificado** contra los repos clonados en `_ref/` el 2026-09-14.
> Todo lo que aquí se afirma sale de leer el código/README real, no de suposiciones.

## Resumen ejecutivo

De los 5 repos que pasaste, **solo uno es un producto conectable a una IA** (`heilingbrunner/tiaportal-mcp`).
Los otros cuatro son: documentación de la API (Siemens), un índice de otros MCPs
(`Dego-Dantas`) y dos colecciones de proyectos terminados que sirven como material de
ejemplo (`npatel221`, `RobertOrsin`).

Siguiendo el hilo de `Dego-Dantas/tia-integration-ai` aparecieron **2 repos más** que son
los que realmente cierran el hueco (crear proyectos desde cero, hardware, HMI). Los he
clonado también.

**Conclusión operativa:** no hay que escribir un servidor MCP desde cero. Hay que
**seleccionar, instalar y envolver** los que ya existen, y poner encima la capa que de
verdad falta: la base de conocimiento y tus estándares.

---

## 1. `heilingbrunner/tiaportal-mcp` — el motor de lectura/análisis

| | |
|---|---|
| Qué es | Servidor MCP en C# (.NET Framework 4.8) sobre Openness |
| Herramientas | **59 de lectura** + **40 de escritura** (tras `--allow-write`) |
| Versiones TIA | V21 por defecto, otras vía `--tia-major-version <n>` |
| Binario listo | ❌ No hay release binario. Se distribuye como extensión de VS Code, o se compila |
| Licencia | MIT |
| Calidad | **La más alta de las tres.** Modelo de errores tipado, lock global sobre Openness (no es thread-safe), `--doctor`, anotaciones `readOnlyHint`/`destructiveHint`, `outputSchema` |

### Lo que aporta y nadie más tiene
- **Export/import como documentos SIMATIC SD** (`.s7dcl` + `.s7res`) en vez de XML. Esto es
  *la* pieza para meter un proyecto TIA en git con diffs legibles. Requiere TIA **V20+**.
- `WhereUsed`, `FindInCode`, `GetCrossReferences`, `GetPlcSummary`, `ExportPlcAsSourceTree`:
  herramientas de *comprensión* de un proyecto existente.
- Modo lectura por defecto: las 40 herramientas destructivas **ni siquiera se registran**
  sin `--allow-write`. Es la postura correcta para trabajar sobre proyectos de cliente.

### Lo que NO puede hacer (limitaciones de la propia API Openness, documentadas por el autor)
- No crea proyectos. No añade hardware. No toca la red.
- No existe "crear bloque" genérico: solo `CreateFB` y `CreateInstanceDB`. Todo lo demás
  entra por `ImportBlock`.
- Copiar/mover bloques se emula con export+import+delete (el número de bloque viaja con él).
- Sin entradas en tablas de observación, sin cross-references para watch/force/sources.

---

## 2. `bulaofen0036-coder/TIA_Portal_Openness_MCP` — el motor de creación

| | |
|---|---|
| Qué es | Servidor MCP + CLI declarativa (`tia gen spec.yaml`), bundle offline |
| Herramientas | **224** en el roster estático (perfil `lite` ≈ 43) |
| Versiones TIA | **V20 y V21** |
| Binario listo | ✅ `runtime/v21/` viene en el clon; **el runtime V20 solo está en el ZIP de release** (`TIA_MCP_Delivery_v2.7.2`, 11,8 MB) |
| Licencia | MIT |

### Lo que aporta y es decisivo para nosotros
- **`ScaffoldProject`**: un solo JSON → proyecto completo (PLC + HMI Unified + UDTs + DBs +
  tablas de tags + bloques SCL/LAD + compilar + guardar). Esto es lo que convierte "hazme un
  proyecto" en una sola llamada en vez de veinte.
- **Hardware y red**: añadir PLC/HMI, catálogo, subredes.
- **WinCC Unified**: pantallas por `designJson`, eventos, binding de tags. Trae 7 plantillas
  de pantalla listas.
- **Version Control Interface (V21)**: mapea el proyecto a una carpeta de texto, un fichero
  por bloque, para git.
- Trae ya `.claude-plugin/plugin.json` + `.mcp.json` + una `SKILL.md` de 63 KB.

### Lo que hay que vigilar
- **Documentación mayoritariamente en chino.** La `SKILL.md` mezcla inglés y chino en la
  misma tabla. No es usable tal cual como tu base de conocimiento.
- Superficie enorme (224 tools). Con el perfil `full` revientas el límite de 128 herramientas
  de VS Code y confundes a cualquier modelo. **Hay que usar `TIA_MCP_PROFILE=lite`.**
- Escrituras sin preview obligatorio en muchas tools (tiene `dryRun`, pero es opt-in).

---

## 3. `Czarnak/tia-portal-mcp` — descartado para tu máquina

| | |
|---|---|
| Herramientas | 14 en lectura-escritura, 4 en solo-lectura, con batching |
| Versiones TIA | **V21 y solo V21** |
| Binario listo | ✅ `dotnet tool install -g TiaMcpServer` o ZIP win-x64 |

Arquitectónicamente es el más elegante de los tres: proceso host .NET 10 + worker .NET 4.8
separado, tokens de seguridad `preview → apply` de un solo uso con expiración a 10 min,
auditoría JSONL, `failureCategory` tipado, y una política *fail-closed* al resolver targets
(si un selector casa con 0 o >1 candidatos, falla en vez de adivinar).

**Pero es V21-only y tú tienes V19 y V20.** Queda anotado como candidato para cuando
actualices a V21, no como opción hoy.

---

## 4. `siemens/tia-portal-openness-code-snippets` — la fuente de verdad

No es un producto: son **91 snippets ejecutables** de Siemens sobre la API Openness V20,
organizados por área. Esta es la materia prima de la base de conocimiento.

Áreas cubiertas (ficheros reales en `src/`):

| Área | Ejemplos de snippets |
|---|---|
| Proceso TIA | `GetAllInstalledTiaVersions`, `GetTiaPortalProcesses`, `ExitAndCloseTiaPortal`, `ExclusiveAccess` |
| Catálogo HW | `HardwareCatalog_AllEntries`, `ChangeTypeIdentifier_*` |
| Red | `ProfinetConfigurations`, `PLC_Et200Connection`, `IpAddressAndOnlineConfig` |
| Online | `GoOnline`, `GoOfflineAllDevices`, `Download`, `OnlineProvider_CurrentOnlineState` |
| Bloques | `ExportProgramBlock`, `ImportProgramBlockComposition`, `SclExportTest`, `ProtectPlcBlock` |
| Tags | `GetAllPlcTags`, `EditExistingTags`, `EditExistingTagsViaExportImport` |
| DBs | `GetDbInterfaceMembers`, `GetCrossReferencesForDb` |
| Seguridad | `CreateProjectRoles`, `SetPasswordProtectionTest`, `IsProjectProtected` |
| Safety | `ReadoutSafetyAdministration`, `SafetyIntegrated*_ActivateSTO` |
| Tech. Objects | `CreateTechnologyObject`, `SetTechnologyObjectHwLimits` |
| Librerías | `CreateGlobalLibrary`, `CreateMasterCopy` |
| Startdrive/DCC | S120, G115D, S210, telegramas, DriveCliq |

> **Concepto clave que sale de aquí y que el agente debe interiorizar:**
> `PathConcept_FirstIntroduction` y `PathConcept_GetEngineeringObjectWithIdentifier`.
> Openness no navega por nombres bonitos: navega por *paths* de objetos de ingeniería.
> Es el error nº1 de cualquier modelo que inventa rutas.

---

## 5. `Dego-Dantas/tia-integration-ai` — un índice, no un producto

Tres scripts `.cmd`, un `proxy.js` y documentación en portugués. Su valor real fue
**señalar los dos MCPs anteriores** y demostrar un patrón que vamos a copiar:
**dos agentes especializados** (`@tiav21` de lectura fina, `@tiaolder` de generación masiva)
en vez de un único agente con 250 herramientas.

Su `opencode.json` es además la plantilla de cómo se declara todo esto en un harness que no
sea Claude Code.

---

## 6. `npatel221/PLC_Projects` — 4 proyectos terminados

| Proyecto | Contenido | Formato |
|---|---|---|
| **BasementLightControl** | Control de luces, GIF demo, PDF con capturas de TIA | `.zap16` |
| **TrafficLightControl** | Semáforo | `.zap16` |
| **SortingPlant** | Planta clasificadora + gemelo digital NX MCD + doc SCE de Siemens | `.zap16` + `NX_MCD.zip` |
| **IotProject** | Get Time, comunicación S7, OPC-UA, MQTT, Node-RED, script Python, app C++, MindSphere | proyecto TIA + `Code/` + `NodeRedFlows/` |

**Valor:** `IotProject` es el más interesante con diferencia — es el único que muestra el PLC
como parte de un sistema (OPC-UA, MQTT, cloud), no como isla.
`SortingPlant` trae la documentación oficial SCE de Siemens sobre gemelo digital.

**Problema:** todos son **V16**. Tu TIA es V19/V20 → requieren migración (soportada, pero es
un paso de un solo sentido, hay que hacerlo sobre copia).

**Cómo se usarán:** como *referencia de cómo debe quedar un proyecto terminado*
(estructura + documentación + capturas), no como código a reutilizar.

---

## 7. `RobertOrsin/TIAPortalGames` — caso límite de WinCC

Juegos (Snake, TicTacToe, 4-en-raya, RPG estilo Gameboy, Tetris) escritos en **VBScript sobre
WinCC Advanced**, TIA V16, un único `.ap16`.

**Valor:** es el mejor material que existe para aprender **hasta dónde llega WinCC** — scripting,
listas gráficas, animación, gestión de estado, límites de rendimiento en HMI real vs simulación.
El propio autor documenta los `Sleep` distintos para PC y para HMI física.

**No es** material de producción. Es material de exploración de límites y, honestamente, buena
demo. Va a `50-examples/` con una ficha clara de "esto es exploración, no estándar".

---

## Tabla de decisión: qué motor para qué

| Necesidad | Motor | Por qué |
|---|---|---|
| Leer/entender un proyecto existente | **heilingbrunner** | `WhereUsed`, `FindInCode`, cross-refs, resumen PLC |
| Meter un proyecto en git con diffs | **heilingbrunner** | Export `.s7dcl`/`.s7res` (V20+) |
| Crear proyecto desde cero | **bulaofen** | `ScaffoldProject` |
| Hardware, red, subredes | **bulaofen** | heilingbrunner no lo cubre |
| HMI WinCC Unified | **bulaofen** | Único que lo cubre |
| Editar bloques con red de seguridad | **heilingbrunner** `--allow-write` | Modo lectura por defecto, errores tipados |
| Cuando migres a V21 | reevaluar **Czarnak** | preview/apply con token, auditoría |

---

## Bloqueos encontrados en esta máquina

Verificados hoy, con su solución. Ver `02-plan.md` M0.

| # | Bloqueo | Evidencia | Impacto |
|---|---|---|---|
| **B1** | El usuario **no está** en el grupo `Siemens TIA Openness` | `Get-LocalGroupMember "Siemens TIA Openness"` devuelve vacío | 🔴 Openness no funciona en absoluto |
| **B2** | No hay .NET SDK ni Visual Studio | `dotnet` no existe; `C:\Program Files\Microsoft Visual Studio` no existe | 🟠 No se puede compilar heilingbrunner |
| **B3** | TIA instalado es **V19 + V20**, no V21 | `Portal V19`, `Portal V20` en disco; Openness 19.0 y 20.0 en registro | 🟠 Czarnak queda fuera; el runtime V20 de bulaofen hay que bajarlo del ZIP de release |
| **B4** | Ejemplos en V16 | `.zap16`, `.ap16` | 🟡 Migración necesaria, sobre copia |
| ~~B5~~ | ~~PLCSIM Advanced no instalado~~ | **CORREGIDO** — sí está: `PLCSIM Advanced V6.0` en `C:\Program Files (x86)\Siemens\Automation\PLCSIMADV`. Me equivoqué al mirar solo `C:\Program Files\Siemens\Automation` | ✅ sin impacto |
| **B6** | TIA **V20 solo tiene interfaz en inglés** (V19 tiene inglés y español) | `Portal V20\Bin\{en,fo}` frente a `Portal V19\Bin\{en,es,fo}` | 🟢 En realidad **es bueno**: los nombres de carpeta de sistema que devuelve Openness (`Program blocks`, `PLC data types`, `PLC tags`) dependen del idioma de la interfaz. En inglés coinciden con toda la documentación y con los valores por defecto de los servidores MCP |

**Lo bueno:** tu cuenta sí pertenece a `Siemens TIA Engineer` y es administrador local
(token filtrado por UAC), así que B1 se arregla con un comando elevado y un cierre de sesión.

**Assembly de Openness V20 confirmado presente:**
`C:\Program Files\Siemens\Automation\Portal V20\PublicAPI\V20\Siemens.Engineering.dll`
(+ `Siemens.Engineering.Hmi.dll`, y carpetas V17/V18/V19 para compatibilidad hacia atrás).
