# TIA-Claude: ruta de trabajo profesional para agentes

> Documento maestro de planificación, ejecución e inventario. Actualizar casillas y estados según
> la evidencia obtenida. Una herramienta en un esquema no demuestra que funcione en esta instalación.

**Fecha de inicio:** 2026-09-21  
**Estado:** en ejecución; aceptación global abierta  
**Contrato normativo:** [AGENTS.md](../../../AGENTS.md)  
**Plan base relacionado:** [2026-09-15-tia-claude-system.md](2026-09-15-tia-claude-system.md)

## Objetivo

Habilitar a Codex y a cualquier agente que opere en este ordenador para inspeccionar, modificar,
crear, borrar, compilar, exportar y validar proyectos TIA Portal V20 de forma trazable y profesional.
La ruta distinguirá entre capacidad documentada por Siemens, herramientas que expone cada perfil,
acción realmente ejecutada en un fixture, compilación, comportamiento simulado y validación visual.
Todo lo planeado y sus resultados vivirán aquí, con enlaces a los logs y artefactos reproducibles.

## Criterios para completar

- [ ] Cerrar todos los hallazgos urgentes de seguridad, documentación, credenciales y distribución.
  Seguridad/documentación y el paquete reproducible están remediados; la revocación de la credencial
  histórica sigue pendiente de confirmación del propietario.
- [ ] Crear procedimientos aceptados para analógicas/medición, comunicaciones, hardware/E/S,
  HMI por modelo/runtime, simulación y diagnóstico.
- [x] Capturar schemas completos de cada perfil MCP presente en este ordenador.
- [x] Añadir inventario por herramienta y acción, con nombre, perfil, inputs, categoría, precondición,
  riesgo, estado de prueba y vínculo a evidencia. La matriz live normalizada mantiene separadas las
  filas de schema de las acciones ejecutadas.
- [ ] Probar las operaciones permitidas en una copia desechable: inspección, importación/cambio,
  compilación, guardado, exportación, lectura posterior, creación/borrado de probe y restauración.
- [ ] Validar comportamiento en PLCSIM y HMI Runtime cuando las precondiciones estén disponibles.
- [x] Registrar el acceso observado desde Codex y separar Computer Use nativo de la superficie browser-only.
- [x] Mantener explícitos los bloqueos que dependan de hardware/software externos.

**Guardas permanentes, no tareas pendientes:** no descargar a PLC físico, no editar F-blocks/tags
Safety y no tocar originales de ejemplos o proyectos de cliente. Estas reglas se aplican incluso
cuando una herramienta las publique en su schema.

## Escala de evidencia

| Estado | Evidencia que requiere |
|---|---|
| Documentado | Guía Siemens o local; no prueba ejecución. |
| Esquema | Presente en tools/list/schema; no prueba que una llamada funcione. |
| Smoke | Ejecutable inicia, responde a Doctor o enumera tools. |
| Fixture | Llamada ejecutada sobre copia desechable y resultado releído. |
| Compilado | TIA compila el objeto/proyecto; registrar errores y warnings. |
| Simulado | Comportamiento observado en PLC virtual/runtime y casos esperados. |
| Gráfico | UI/runtime inspeccionado; guardar evidencia visual o registro de pasos. |
| Bloqueado | Falta precondición o la política excluye la acción; indicar desbloqueo. |

No elevar el estado de una herramienta por analogía con otra herramienta del mismo grupo.

## Línea base recopilada

La comprobación inicial de esta sesión no abrió ni conectó un proyecto. Doctor respondió a las
09:25:43 +02:00: V19/V20 instalados, usuario en grupo Siemens Openness, versión activa V20, perfil de
escritura desactivado, ningún proyecto MCP conectado y ningún proceso TIA Portal detectado en esa
comprobación. Se ejecutó otra lectura de Doctor a las 16:53:25 +02:00, también sin `Connect` ni
`OpenProject`: V20 activo, grupo Openness=true, V19/V20 Engineering y Portal presentes, desconectado,
sin proyecto MCP abierto y `allowWrite=false`; la evidencia está en [Doctor read](../../../70-runs/tia-capabilities/20260921-08-doctor-read.json).
Doctor no identifica ni modifica la ventana visible de TIA Portal; esa comprobación de identidad
requiere Computer Use nativo. La llamada posterior a `mcp__cua_repl` devolvió
`apps: []`, pero esa superficie estaba limitada al navegador y no inventariaba aplicaciones Windows.
La disponibilidad nativa se comprobó por separado con `node_repl` + `@oai/sky`; ver la tabla y la
evidencia de apertura gráfica más abajo. Volver a ejecutar Doctor antes de cada fase que use TIA.

| Superficie | Estado y evidencia | No demuestra |
|---|---|---|
| Doctor read-only más reciente | [doctor-20260922-final.json](../../../70-runs/environment/doctor-20260922-final.json): V20 activo, grupo Openness=true, V19/V20 Engineering y Portal instalados, `isConnected=false`, sin proyecto MCP, `allowWrite=false`. | No identifica ni modifica la ventana visible de TIA; no hubo Connect/OpenProject ni conexión a un proyecto. |
| tia-inspect read | `70-runs/tia-capabilities/20260921-01-baseline/tia-inspect-read.json`: 59 tools, SHA-256 `140E979837B6ADFDF7DC1CDC05A783E0952797C733704E5649540E4D9003EB25`. | No se conectó proyecto ni se probó cada método. |
| tia-inspect write | `.../tia-inspect-write.json`: 99 tools, `--allow-write`, SHA-256 `D52747D6D74FE8C1F9B073A6DAB62D9E0A0280E2E5DB51A338E91204141C9D79`. | Enumerar schemas no ejecuta las acciones. |
| tia-inspect read/write actuales | Capturas live sin proyecto: read **53** y write aislado **84**, hashes y links en el apéndice. `ImportSources` y `ImportFromDocuments` no aparecen en estos perfiles. | Son solo tools/list y schemas; no se ejecutó ninguna acción de esos perfiles en esta captura. Write sigue limitado a fixture/manifiesto. |
| tia-create lite actual | Captura live **55** tools; incluye `FindTools` y `CallTool`. [JSON](../../../70-runs/tia-capabilities/20260921-06-create-lite-tools-live.json). | Roster/schema sin proyecto; enumera herramientas, no acredita que cada acción se haya ejecutado ni que sea segura en cualquier target. |
| tia-create full actual | Captura live **222** tools; incluye `DownloadToPlc` y los self-tests `RunHmiActionScriptRecipeSafetySelfTest` y `RunOnlineMonitoringSafetySelfTest`. [JSON](../../../70-runs/tia-capabilities/20260921-07-create-full-tools-live.json). | Roster/schema solamente para `DownloadToPlc`; los dos self-tests sí se ejecutaron después en el lote offline, sin proyecto conectado ni mutación ([evidencia](../../../70-runs/tia-capabilities/20260922-offline-safe-tools-batch.md)). La presencia del resto no autoriza su uso. |
| Openness Siemens V20 | Base de automatización que usan TIA y las herramientas locales; el probe independiente [direct-openness-20260922-final.json](../../../70-runs/environment/direct-openness-20260922-final.json) inicializó el resolver V20 desde un proyecto .NET Framework separado, comprobó el grupo y ejecutó `TiaPortal.GetProcesses()` en solo lectura. | El probe no adjuntó ni abrió proyecto y no valida todavía cada acción del API ni las operaciones de proyecto. |
| Computer Use/UI | Nativo disponible en esta sesión por `node_repl` + `@oai/sky`; `mcp__cua_repl` solo expone navegador y su `apps: []` no mide Windows. TIA V20 se abrió con los clones exactos de los fixtures, se mantuvo maximizado (1920×1040) y se navegó visualmente al PLC y al HMI. | La edición PLC y la edición visual HMI quedan verificadas solo en clones; el compile HMI y el runtime siguen sin evidencia. El acceso depende de la sesión, el permiso de la app y políticas de workspace. |
| PLC fixture | En un clon IOT2050 aislado, el preview de `PlcBuildAndImport` pasó pero su apply falló por cultura, sin importación y con integridad confirmada. En una secuencia separada, el import de fuente SCL generó un bloque probe, compiló 0/0, guardó, exportó, se releyó y luego se borró/restauró el clon. Evidencia bajo `90-tmp/e2e/20260921-iot2050-agent-probe-clean/`. | La ruta de fuente externa no demuestra `Invoke-TiaSclProposalApply`; tampoco valida acciones ajenas a la secuencia ni comportamiento PLCSIM/HMI. La instancia original no se modificó. |
 | Runtime | [status-20260922-final11.json](../../../70-runs/acceptance/status-20260922-final11.json) mantiene `accepted=false`; el scaffold live y la fase gráfica de clones están verificados, mientras PLCSIM y Runtime Advanced V20 siguen pendientes/bloqueados. | El informe de aceptación separa compilación/mocks de comportamiento real; no autoriza descarga ni runtime. |

### Estado actualizado antes de la fase gráfica final — 2026-09-22

- **Doctor read-only actual:** [doctor-20260922-final.json](../../../70-runs/environment/doctor-20260922-final.json)
  pasó con V20 activo, grupo `Siemens TIA Openness=true`, V19/V20 instalados, `isConnected=false`,
  sin proyecto MCP y `allowWrite=false`. Esta evidencia no identifica la ventana TIA visible; esa
  identidad se hará con Computer Use nativo justo antes de la fase gráfica.
- **Checks no gráficos:** [ci-safe-20260922-final6.json](../../../70-runs/checks/ci-safe-20260922-final6.json)
  terminó con 14 PASS, 0 WARN y 0 BLOCKED. Las pruebas de simulación incluidas son mocks de guards;
  no acreditan PLCSIM ni Runtime.
- **Aislamiento headless:** [isolated-20260922-connect-disconnect.json](../../../70-runs/environment/isolated-20260922-connect-disconnect.json)
  ejecutó `Connect → GetState → Disconnect` con `tia-inspect --isolated`, sin proyecto y con
  `allowWrite=false`. Esta excepción no identifica ni modifica la ventana gráfica visible.
- **Identidad y cierre de la ventana visible:** [computer-use-20260922-tia-window.json](../../../70-runs/environment/computer-use-20260922-tia-window.json)
  conserva el título exacto del proyecto desechable, la acción `Close project` y el título posterior
  sin proyecto. No se cerró ni sustituyó ninguna instancia de cliente.
- **Runner `agent-demo`:** la prueba estática [Test-AgentDemoScaffold.ps1](../../../30-tools/tests/Test-AgentDemoScaffold.ps1)
  exige manifest/backup aislado, `-Isolated -FixtureRoot` y cierre en la misma sesión MCP. Tras
  identificar/cerrar la ventana desechable con Computer Use, la ejecución live
  [083500-002](../../../70-runs/e2e/agent-demo-scaffold-20260922-083500-002/scaffold-report.json)
  terminó con compilación 0/0, readback, exportación, comentario limpio y standards sin findings.

## Guardas que gobiernan toda prueba

1. Doctor primero. Si el entorno está mal, parar y explicar.
2. Confirmar la instancia/proyecto objetivo. No abrir segunda instancia, cerrar proyecto ajeno ni
   confundir Connect con Attach. Attach sólo si el servidor y perfil concretos lo exponen.
3. Obtener rutas reales de GetProjectTree/GetSoftwareTree; no inventar paths.
4. Probar en copia completa nueva dentro de 90-tmp/. Guardar backup íntegro y hashes antes de
   cualquier escritura. Mantener originales intactos.
5. Leer íntegramente el objeto, revisar 60-library/ y recetas, preview antes de cambiar, una
   mutación cada vez, compilar sin errores antes de guardar, exportar y releer.
6. Toda secuencia MCP pasa por 30-tools/scripts/Invoke-McpToolSequence.ps1 y su mutex.
7. No editar F-blocks, tags Safety ni bloques know-how protegidos. Si la clase no se puede identificar
   con certeza, no escribir.
8. No descargar ni escribir valores a PLC físico. Requiere confirmación actual y explícita para un
   target/acción concretos. PLCSIM sólo cuando el target y adaptador virtual estén identificados y
   Write-TiaSimulationReadiness.ps1 reporte plcsimVirtualAdapterReady=true.
9. No generar LAD manualmente; usar receta o bloque probado.
10. No copiar datos de 40-projects a contenido versionado público. Anonimizar cualquier bloque que se
    extraiga con permiso.
11. DryRun/preview no es aplicación. Compile no demuestra comportamiento físico ni runtime.
12. Siemens describe acciones Openness que este contrato no permite (por ejemplo, import/export de
    F-blocks); anotar “API documentada / ejecución local prohibida”.

## Matriz de capacidades por familia

Este resumen queda complementado por una tabla individual de cada tool del roster real. Indicar API
para la capacidad de Siemens, MCP para la herramienta de cada servidor y UI para inspección gráfica.

| Familia | Acciones MCP a inventariar | Openness/API y Computer Use | Evidencia/bloqueo actual |
|---|---|---|---|
| Sesión y proyecto | Doctor, Connect, GetState, GetOpenProjects, OpenProject, AttachToOpenProject, CloseProject, SaveProject/SaveSession, SaveAs | Openness abre/cierra/guarda, conecta instancias con/sin UI y puede acceder a procesos activos. Attach depende del servidor; UI identifica ventana si el objetivo es ambiguo. | Doctor verificado; Attach documentado en esquema full guardado, no en tia-inspect read. |
| Árbol y lectura | GetProjectTree, GetSoftwareTree, GetBlocks, GetTypes, GetBlockSource, FindInCode, WhereUsed, ResolvePath | Lectura/navegación del modelo de objetos. UI ayuda a ver editores, no sustituye paths exactos. | El roster live de inspect está catalogado; no se ha ejecutado cada método del roster ni se debe elevar su presencia a capacidad probada. |
| PLC blocks y tipos | ImportBlock/ImportFromDocuments, CreateFB/CreateInstanceDB, DeletePlcBlock/DeletePlcType, export, compile, readback | Siemens V20 documenta import/export y creación/borrado de objetos de proyecto. Revisar diferencias por tipo/versión. | En clon: FB SCL generado/importado/compilado/guardado/exportado/leído y luego borrado con preview, recompilación y readback independiente; restauración exacta. No se probó cada tool ni tipo. |
| Tags, UDT, DB, tablas y watch | GetPlcTagTables/GetTags, import/export de tags/UDT/DB, watch/force discovery y SetWatchTableModifyValue | Tags PLC, constantes y objetos HMI import/export según modelo. Force/write online implica riesgo físico. UI para tabla/force sólo lectura en este plan. | El scaffold `AgentDemo_V20` creó `Agent_Signals` con dos tags y la inspección posterior exportó la tabla. La exportación se normalizó con `Convert-TiaTagTableExportToInventory.ps1` y se unió al inventario con evidencia detallada (`agent-signals-tag-inventory.json`, `inventory-with-tags.json`). No se probó `CreateTag`/`ImportPlcTagTable` independiente, UDT/DB ni operaciones online. El apply bloquea tags Safety o clasificación incompleta. |
| Hardware e IO | SearchHardwareCatalog, AddDevice/PlugDeviceItem, direcciones IO, CPU settings, compilación | Openness documenta dispositivos, CAx, subredes e IO con requisitos por objeto/modelo. UI revisa Devices & Networks y modelo exacto. | Esquemas catalogados; mutaciones en copia pendientes; no hay descarga física. |
| Redes y comunicaciones | PROFINET/subnet/node, OPC UA, MQTT, HMI connections, diagnostics; usar FindTools si falta nombre en lite | La presencia de un objeto connection no demuestra tráfico ni autenticación. Runtime requiere endpoint de test; certificados/detalles pueden requerir UI. | Receta R19 documentada tras auditoría; no hubo mutación de comunicación ni handshake/tráfico real. |
| HMI | Classic/Basic/Comfort/RT Advanced/Unified: screens, templates, tags, bindings, alarms, actions, scripts, dynamizations, compile | Openness soporta conjuntos de objetos según el modelo; los exports son internos y dependientes de versión. Siemens indica que Openness con UI no puede usar el editor HMI. Computer Use/runtime prueba apariencia e interacción. | Receta R20 separa las familias/modelos; no se ejecutó ni aceptó runtime HMI. Computer Use nativo disponible; falta runtime HMI compatible. |
| Analógicas y medidas | AI/AO hardware, tags, escala/diagnóstico SCL, PLC virtual | Ajuste depende de MLFB, rango/cableado y unidad física; escalado puede probarse con vectores, medida eléctrica no. UI para comparar runtime/trends. | Receta R18 documentada; no hay aceptación local hardware/runtime. |
| Compilación/diagnóstico/export/recuperación | CompileSoftware, CompileAndDiagnosePLC/HMI, diagnostics, import/export, backup/restore | Siemens describe interfaces de diagnóstico e intercambio; import/export format es interno y específico por versión. UI para warnings completos truncados. | Compile fixture histórico; hace falta evidencia actual por versión/modelo. |
| Librería y versionado | master copies, library, VCI workspace/sync | Openness modela library/project objects; verificar referencias. UI para estado de librería cuando aplique. | Schemas; no prueba local. |
| Online y simulación | GetOnlineState, GoOnline/Offline, live read, watch, CheckDownloadReadiness, DownloadToPlc | Readiness sólo verifica; Download y SetWatchTableModifyValue escriben target. UI debe demostrar instancia simulada antes de actuar. | No ejecutado. Exigir `plcsimVirtualAdapterReady=true`, instancia virtual desechable, conexión/IP hacia ella y aislamiento de rutas antes de cualquier escritura online. Target ambiguo se considera físico. |
| Computer Use | No es herramienta TIA MCP: cada sesión debe comprobar el plugin nativo `computer-use` mediante `node_repl` + `@oai/sky`, enumerar ventanas y leer estado/título antes de interactuar. `mcp__cua_repl` es solo navegador. | Útil para ventana TIA, LAD visual, editor/runtime HMI, diálogos y errores visuales. | Nativo disponible en esta sesión; TIA V20 mostró el clon del fixture y el árbol PLC. No se editó desde GUI. `apps: []` de la superficie browser no es evidencia de indisponibilidad nativa. |

### Riesgo permitido

| Nivel | Acción |
|---|---|
| R0 | Inspección de archivos/schemas, dryRun, preview y pruebas offline. |
| R1 | Lectura, export, compilación y diagnósticos offline de copia. |
| R2 | Mutaciones reversibles de PLC, HMI, hardware o red en clon, con backup/readback/restore. |
| R3 | Runtime y medición con simulador virtual desechable positivamente identificado. |
| R4 | F/safety/protección, target ambiguo y PLC físico: excluido. Física requiere confirmación en el momento. |

## Plan de trabajo por orden

### Fase 0 — Línea base viva y acceso

- [x] Preservar git status y cambios previos del usuario; no ejecutar el build original porque hacía
  `git checkout -- .` sobre un upstream con cambios previos. Se corrigió para no revertir ni borrar.
- [x] Ejecutar Doctor read-only y guardar timestamp, versiones, modo, proyecto y procesos en
  `70-runs/tia-capabilities/20260921-01-baseline/`.
- [x] Enumerar procesos TIA sin abrir, cerrar ni sustituir instancias.
- [x] Ejecutar Inspect-McpToolSchemas.ps1 con tools/list sin proyecto para tia-inspect read,
  tia-inspect write, tia-create lite y full sólo si está realmente configurado. Guardar schemas,
  versión, executable path y hash por perfil.
- [x] Leer las instrucciones nativas Computer Use y consultar `node_repl` + `@oai/sky`.
  Distinguir el inventario Windows de `mcp__cua_repl`, que solo expone navegador.
- [x] Identificar visualmente en TIA V20 el `.ap20` exacto del fixture restaurado y navegar al árbol
  `PLC_1 > Program blocks`. No se realizó edición GUI.
- [x] Clasificar datos nuevos frente a pruebas de 15/09.

Salida: `70-runs/tia-capabilities/20260921-01-baseline/` con baseline y cuatro schemas completos.
La captura inicial de Doctor/schemas y la navegación gráfica no modificaron el proyecto. Las
capturas live posteriores 04–07 actualizaron los cuatro rosters por `tools/list` sin conexión a
proyecto; registran esquemas, no llamadas de esas acciones. El Doctor histórico [20260921-08](../../../70-runs/tia-capabilities/20260921-08-doctor-read.json)
y el [Doctor actual 20260922](../../../70-runs/environment/doctor-20260922-final.json) son comprobaciones
separadas sin conexión a un proyecto y no identifican la ventana visible. La secuencia MCP
separada sí hizo una mutación temporal en la copia y la restauró; se documenta en Fase 7.

**Registro duradero de Computer Use — 2026-09-21 (hora no preservada):** en Codex/Windows,
`node_repl` + `@oai/sky` identificó la ventana TIA V20 y permitió verificar visualmente que mostraba
el `.ap20` del clon `90-tmp/e2e/20260921-iot2050-agent-probe-clean/fixture/IOT2050_S7_CompleteProject_V20/IOT2050_S7_CompleteProject_V20.ap20`;
se navegó hasta `PLC_1 > Program blocks`. Ese registro inicial no incluyó edición, compilación ni
prueba de Runtime desde GUI. La fase gráfica posterior sí verificó la edición/compilación del PLC y
la edición visual HMI en clones; el compile HMI y el runtime siguen sin evidencia.

### Fase 1 — Fail closed del apply SCL (P0, primera remediación)

**Archivos:** runner, helper `TiaSclSafety.ps1`, `ResponseBlockInfo` de tia-inspect, build script
y pruebas dirigidas.

Hallazgos verificados en la revisión inicial: el DTO no exponía clasificación F; `GetTags` sí expone
`IsSafety`; `ImportSources` puede devolver `success=true` con `Failures`; el runner no repetía esos
controles. La API documenta intercambio de F-blocks, así que el posible rechazo de una importación F
no es defensa suficiente.

1. [x] Revisar DTO, schema, callers, `ImportSources` y `GetTags`.
2. [x] Añadir regresiones F/Safety explícito y desconocido, protección, tags sin marcar o incompletas,
   import parcial/extras, tipo de declaración incorrecto y FB normal en `20_Permissives`; exigir perfil
   write y reconocimiento en el runner directo.
3. [x] Ejecutar pruebas rojas antes de implementar: faltaba el helper y el runner directo aceptaba
   apply sin perfil/reconocimiento.
4. [x] Añadir `IsFailsafe` nullable; comparar bloque live/fuente original, tipo de declaración,
   fuente propuesta/readback; comprobar `Items`/`Failures`, preview y cantidad de tags; bloquear
   metadatos ausentes. Sin resolvedor SCL, bloquear PLC con cualquier tag Safety.
5. [x] Confirmar preview SCL local sin conexión TIA. No hubo importación live.
6. [x] Correr tests dirigidos y parseo PowerShell; compilar V20 con 0 errores y 2 warnings nullable;
    un snapshot intermedio `20260921-02-safety-runner` mostró 99 tools. Los snapshots live más recientes
    `20260921-05-read-tools-live` y `20260921-04-write-tools-live`
    muestran 53 herramientas read y 84 write aislado; ninguno registra `ImportSources` o
    `ImportFromDocuments` en `tia-inspect`. Son capturas tools/list sin conexión ni llamadas a esas
    herramientas. La [comprobación del gate](../../../70-runs/tia-capabilities/20260921-09-scl-import-capability-gate.json)
    confirma ambos ausentes, el bloqueo fail-closed del helper y los tres tests locales PASS; `liveTiaConnected=false`
    y `liveImportAttempted=false`. No se sustituyó el binario de producción. El resultado
    persistente más reciente de checks del workspace es
    [14 PASS, 0 WARN, 0 BLOCKED](../../../70-runs/checks/ci-safe-20260922-final6.json).
    La validación del [candidato portable actual](../../../70-runs/portable-package/final-20260922-093500-000/validation.json)
   registra el hash de su `tia-inspect` empaquetado, pero no reemplaza un log de compilación. La salida
   detallada del compilador y los warnings no se conservaron en `90-tmp`.
7. [x] Probar el circuito permitido con clasificación live `isFailsafe=false`, `programmingLanguage=SCL`
   en una fixture por la ruta de importación de fuente externa de `tia-create`; obtener readback
   independiente del bloque con la misma clasificación. La prueba separada `PlcBuildAndImport` falló
   antes de importar por cultura (`en-US` frente a `zh-CN`); [integridad posterior](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/10-failed-import-integrity.json)
   confirmó que no mutó. La ruta aceptada de fuente SCL externa es otra secuencia: [escritura del fuente](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/11-write-scl-source.json),
   [importación](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/16-import-external-source-root.json),
   [compile/save](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/17-generate-compile-save.json)
   y [readback independiente](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/18-independent-readback.json).
   Los tests negativos demuestran bloqueo ante `isFailsafe=true`, null/desconocido y tags
    Safety/incompletas; el check integrado persistente está en [ci-safe-20260922-final5](../../../70-runs/checks/ci-safe-20260922-final6.json).

Aceptación estática: gates locales, tests y compile/schema pasan. La ruta de importación de fuente
externa de `tia-create` compiló y releyó el probe, pero eso no demuestra integración del runner de
propuestas SCL. Aceptación live del runner sigue bloqueada hasta registrar una importación segura y
probar el bloqueo previo a import/save más el roundtrip exacto.

**Límites restantes:** no existe una fixture F autorizada y no se intentó escribir un F-block. El veto
de cualquier tag Safety es más conservador que revisar referencias individuales. Las llamadas MCP
directas de importación no pasan por este runner. Además, en los rosters live de `tia-inspect` read/write,
`ImportSources` e `ImportFromDocuments` no están registrados hasta poder clasificar cada fuente y destino
de overwrite; el parche lo deja explícito en
[`0001-tia-agent-workspace.patch`](../../../30-tools/mcp/tia-inspect/patches/0001-tia-agent-workspace.patch).
Las capturas actuales confirman la ausencia en esos dos perfiles: [read, 53 tools](../../../70-runs/tia-capabilities/20260921-05-read-tools-live.json)
y [write aislado, 84 tools](../../../70-runs/tia-capabilities/20260921-04-write-tools-live.json). `ImportFromDocuments`
sí aparece en el roster de `tia-create` lite/full, pero ese camino MCP distinto no acredita ni integra
el runner de propuestas SCL ni sus barreras; la ruta de aplicación de ese runner sigue bloqueada.
Por ello `Invoke-TiaWorkflow.ps1 -Workflow apply` no tiene aún un endpoint seguro probado para completar
la aplicación live. **Seguimiento seguro:** implementar una herramienta acotada para un único bloque
SCL estándar y un destino exacto, con clasificación live no F, chequeos de protección/Safety, validación
de una sola declaración y resultado íntegro; mantener desregistrada la importación genérica de carpetas.
Después, compilar y reconciliar `tools/list`, probar negativos y hacer roundtrip en clon. No se ha probado
en runtime `SafetySignatureProvider` con una F-CPU, y esa prueba no forma parte del alcance permitido.

### Fase 2 — Credencial del Node-RED (P0)

**Fuente:** 50-examples/npatel-iot/node-red/07_MindSphereflow.json; revisar copias de paquete y
dist con búsquedas que sólo revelen rutas, nunca valores.

1. [x] Comprobar tracking/copia/hash sin imprimir ni poner el secreto en logs. La fuente y Portable
   dist eran idénticas; la configuración estaba anidada en `agentconfig.content`.
2. [x] Reemplazar la configuración por placeholder no secreto; documentar setup local en `FICHA.md`.
3. [x] Regenerar `TIA-Claude_Portable/dist` desde fuente canónica después de limpiar el ejemplo y
   actualizar herramientas/documentación. Fuente y paquete generado quedaron con cero hallazgos;
   artefactos viejos no se volvieron a distribuir.
4. [x] Añadir secret scan que detecta el patrón sin volcar el valor; `Test-TiaExampleSecrets.ps1`
   cubre la cadena falsa y pasó sobre fuente y distribución generada.
5. [ ] Rotar/revocar en el proveedor. El agente no tiene evidencia de acceso al tenant; dejar esto como
   bloqueado hasta que lo confirme el propietario.

Aceptación: JSON parseable, valor ausente de git y paquete, secret scan limpio, revocación registrada.
El valor se tratará comprometido hasta confirmación.

### Fase 3 — Alinear instrucciones técnicas (P1)

**Archivos:** 10-kb/20-recetas/R01-inventariar-proyecto.md,
10-kb/30-lenguajes/scl.md, 10-kb/30-lenguajes/patrones-por-bloque.md,
20-standards/estructura-proyecto.md y referencias encontradas.

- [x] R01: Doctor antes de Connect. Diferenciar tia-inspect read sin Attach, Attach disponible sólo
  cuando el server/profile exacto lo expone, y parada si la ventana visible es ambigua.
- [x] SCL: cambiar memoria interna de `#Fault` a `#statFault` y publicar salidas al final; no se hizo
  reemplazo ciego en recetas ni diagramas LAD.
- [x] Estructura: distinguir permissives/interlocks de proceso (p. ej. EmergencyOk si esa es su
  semántica) de safety funcional certificada/SIL/PL/F-block/circuito de emergencia. No dejar que
  nombres de grupo/tag sugieran certificación.
- [x] Buscar referencias contradictorias, renombrar el grupo de proceso `20_Safety` a
  `20_Permissives`, advertir que nombres no clasifican Safety, y corregir la memoria `#Fault` en
  ejemplos ejecutables. Las menciones restantes de `#Fault` son anti-patrones etiquetados.
- [x] Corregir R01 para que Attach solo se use cuando el servidor/perfil real lo expone; completar
  checks locales de safety/nombres con `Test-TiaSclSafetyGate.ps1`; el [informe de checks](../../../70-runs/checks/ci-safe-20260922-final6.json)
  conserva el resultado de la barrera SCL y estándares.

Aceptación: recetas consistentes con AGENTS; ningún ejemplo lee una salida como memoria ni sugiere
que un interlock estándar sea safety certificada.

### Fase 4 — Distribución y fixtures (P1)

**Archivos:** TIA-Claude_Portable/manifests/package-info.json, scripts de build/manifest,
TIA-Claude_Portable/tests/Test-PortablePackage.ps1, 50-examples/README.md y agent-demo.

- [x] Generar en una carpeta aislada el candidato final de esta sesión: 314 archivos core y 658 de
  ejemplos. La validación completa (build, paquete, contenido, relocalización y secreto) está en
  [validation.json](../../../70-runs/portable-package/final-20260922-093500-000/validation.json).
  Ese candidato incorpora el `AGENTS.md` y los runners actualizados y es el artefacto distribuible
  de referencia de esta sesión.
- [x] Mantener identificada la distribución `TIA-Claude_Portable/dist` como salida antigua no
  distribuible: declara 307/658 y contiene un `AGENTS.md` anterior. No se sobrescribe automáticamente;
  si se publica, hay que promover explícitamente el candidato final y repetir la validación.
- [x] Actualizar `Test-PortablePackage.ps1` al layout actual y añadir regresión contra
  `legacyMonolithicWorkspace`. La evidencia histórica 304/658 se conserva como auditoría anterior y
  no se usa para afirmar el estado del candidato final.
- [x] Eliminar la afirmación de que los tipos PLC requieren V21 y documentar que `agent-demo` es un
  fixture de scaffold. La comprobación CI segura del 22/09/2026 registra 14 PASS, 0 WARN y 0 BLOCKED:
  [ci-safe-20260922-final6.json](../../../70-runs/checks/ci-safe-20260922-final6.json). Incluye guards y mocks, no
  equivale a PLCSIM real ni a Runtime HMI.
- [x] Corregir el falso `MISSING_BLOCK_COMMENT`: `HeaderName` es un ID de usuario, no el comentario
  del bloque. `TiaBlockMetadata.ps1` lee el comentario del XML de exportación; sin XML marca el dato
  como no verificado. El SCL de ejemplo se guardó con BOM para evitar corrupción de caracteres.
- [x] Ejecutar de nuevo el scaffold de `FB_AgentDemo` después de la corrección del runner. La evidencia
  [scaffold-report.json](../../../70-runs/e2e/agent-demo-scaffold-20260922-083500-002/scaffold-report.json)
  demuestra `dryRun`, `Bootstrap → ScaffoldProject → CloseProject → Disconnect` en una sola sesión,
  compilación V20 `0` errores/`0` avisos, lectura del árbol y del bloque, exportación PLC y del bloque,
  comentario con codificación limpia, estándares sin findings y fixture aislado con backup.

Aceptación parcial: el paquete final 314/658 está validado, la comprobación CI segura está verde y el
roundtrip live de `FB_AgentDemo` ya está verificado. Siguen abiertas las familias no ejecutadas, la
aplicación del runner de propuestas SCL (importador ausente), PLCSIM/Runtime y la revocación histórica.

### Fase 5 — Recetas profesionales (P2)

Cada receta debe declarar TIA/device/runtime version, entradas, herramienta/profile, pasos con
readback, expected result, STOP, recuperación y evidencia.

| Receta | Casos de aceptación |
|---|---|
| Analógicas/medidas | Separar AI y AO, modelo/rango del módulo, raw/EU, límites y diagnóstico específico. Cada caso conserva expected/tolerancia; cableado/medida eléctrica queda separado de simulación algorítmica. |
| Comunicaciones/diagnóstico | PROFINET identity/IP/subnet/topology; OPC UA endpoint/certificado/namespace; MQTT broker/topic. Diagnosis online queda separada de writes de fixture; compile + configuración exportada + handshake/tráfico en endpoint aislado. |
| HMI por modelo | Basic, Comfort/Mobile, RT Advanced, Unified por modelo/runtime separados; resolución, pantallas, tags, eventos, dinamización, alarmas, compile y sesión runtime. La matriz de versiones y simulación específica gobierna cada caso. |
| Hardware/E/S | MLFB/version exacta, catálogo/GSD, módulos/canales/direcciones, roundtrip y diagnóstico. |
| Compilación/recuperación | Errores/warnings, backup, restore/hash, source export, códigos de error y acción ante cada código. |
| Simulación/commissioning | Compilación offline, PLC virtual, HMI Runtime, mediciones y commissioning se reportan como capas diferentes. |

No generalizar compatibilidad de un modelo a otro. Si runtime/producto no existe, receta Bloqueada con requisito exacto.

Estado de esta fase: R18/R19/R20 fueron redactadas y endurecidas tras revisión técnica independiente.
Son procedimientos documentales; hasta que se ejecuten contra fixtures compatibles, quedan en
estado Documentado y no en Fixture/Simulado.

### Fase 6 — Inventario exhaustivo por tool (P1)

1. Capturar tools/list de cada perfil, sin abrir proyecto, con Inspect-McpToolSchemas.ps1.
2. Comparar schemas completos: tia-inspect read/write, tia-create lite/full. Confirmar qué perfil
   está configurado; no llamar tia-create full sólo porque exista un schema guardado.
3. Para cada herramienta, registrar nombre exacto, descripción/inputs, servidor/versión/perfil,
   familia, offline/read/write/online, precondición, riesgo R0–R4, superficie Openness/helper/UI,
   estado de cada nivel de evidencia y enlace a run.
4. Reconciliar herramientas omitidas de lite con FindTools y CallTool cuando corresponda.
5. Relacionar método/clase de Openness cuando fuente local o Siemens lo permitan. Diferenciar
   helper MCP, wrapper API, API directa y acción UI. No afirmar que API directa está probada por
   un wrapper.
6. Insertar tabla individual o apéndice dentro de este mismo documento, con timestamp/schema hash/count.
7. La disponibilidad nativa y la identidad del fixture ya se registraron en Fase 0. No hacer más
   interacción gráfica durante esta fase; agrupar las comprobaciones visuales pendientes en Fase 8.
8. Reconciliar los rosters live `20260921-04` a `-07` (tia-inspect write/read y tia-create lite/full)
   con el inventario histórico; reemplazar o etiquetar cada fila para que el apéndice no sugiera que
   las herramientas del baseline `01` siguen disponibles. Estas cuatro capturas son tools/list sin
   conexión de proyecto ni ejecución de las acciones, incluso las de `DownloadToPlc` y Safety.

Se hizo además una encuesta `FindTools` sin conectar proyecto para HMI/pantallas, hardware/módulos,
watch/force, OPC UA, diagnóstico y analógicas. La respuesta confirma el roster dinámico completo
de 222 herramientas y devuelve nombres y firmas para cada familia; esta encuesta descubre capacidad,
 pero no eleva ninguna fila a Fixture. Ver [dynamic-findtools-survey.json](../../../70-runs/tia-capabilities/20260922-dynamic-findtools-survey.json).

El lote offline adicional [20260922-offline-safe-tools-batch.md](../../../70-runs/tia-capabilities/20260922-offline-safe-tools-batch.md)
ejecutó 14 llamadas en `tia-create/full` sin `Connect`, `OpenProject` ni mutación. Dejó verificadas
las barreras de seguridad online/HMI, los planificadores de forma y varios builders XML/JSON. Los
builders observados declaran `Engineering V21`, por lo que no se eleva su importación V20. El QA HMI
con ruta absoluta encontró 7 plantillas, 7 fallos y 17 advertencias; quedan bloqueadas para aplicación.
La búsqueda de las 222 herramientas no encontró una herramienta dedicada de medidas analógicas.
Evidencia de detalle en la [encuesta JSON](../../../70-runs/tia-capabilities/20260922-offline-safe-tools-survey.json).

La prueba específica de [familias no gráficas](../../../70-runs/tia-capabilities/20260922-noncu-family-offline-builders.md)
ejecutó, también sin `Connect` ni proyecto, builders de UDT, DB global, tabla de tags, FC/FB SCL,
paquete HMI Classic y manifiesto de símbolos. Los XML fueron parseables y las validaciones offline
pasaron; sus respuestas declaran Engineering V21 para PLC y V18 para la pantalla Classic, por lo que
siguen siendo **builders verificados offline**, no importaciones V20 aceptadas. El UDT corregido y su
lectura de resultado están en [20260922-noncu-family-udt-rerun.json](../../../70-runs/tia-capabilities/20260922-noncu-family-udt-rerun.json).

La auditoría final [20260922-final-noncu-hardware-comms-analog-audit.md](../../../70-runs/tia-capabilities/20260922-final-noncu-hardware-comms-analog-audit.md)
cerró la parte que podía comprobarse sin Computer Use de hardware/redes, comunicaciones/diagnóstico
y analógicas. Sin conectar un proyecto, `PlanHardwareNetworkConfiguration` rechazó tres entradas
inválidas y confirmó sus guardas offline; `RunOnlineMonitoringSafetySelfTest` pasó con 6
verificaciones y `checkedTools=222`; `PlanOnlineReadOnlyMonitoring` y
`PlanOnlineReadOnlyDataProvider` aceptaron únicamente planes read-only y rechazaron entradas
inseguras o proveedores no soportados. No se abrió una CPU, endpoint, watch table o runtime. La
búsqueda específica de analógicas no encontró una herramienta dedicada: el escalado, calibración,
diagnóstico de canal y medida física quedan **no verificados**. Hardware/E/S real, catálogo,
direcciones, redes y diagnóstico live siguen bloqueados hasta disponer de un proyecto identificado
y paths leídos del árbol. El JSON primario es
[20260922-final-noncu-hardware-comms-analog-audit.json](../../../70-runs/tia-capabilities/20260922-final-noncu-hardware-comms-analog-audit.json).

Aceptación de catálogo: las tablas reflejan los perfiles actuales configurados, cada conteo/hash
coincide con tools/list y los snapshots históricos se distinguen como tales. La evidencia de acción
probada se conserva separada y no se propaga a otras herramientas parecidas.

### Fase 7 — Acción sobre clon desechable (R2)

**Fixture ejecutada:** `90-tmp/e2e/20260921-iot2050-agent-probe-clean/`. Se clonó el ejemplo
IOT2050 V20, se guardó una copia íntegra en `backup/` y el manifiesto enlazó exclusivamente el
proyecto clonado y su backup. Hash del `.ap20` original/backup: `D5FA9E103B16E357CDBCE9DF13E0CC03E96BA36900670EF9857F69CC234E071E`.

**Acciones verificadas en esta sesión:**

1. `tia-inspect`: Doctor, Connect/OpenProject, GetProjectTree, GetSoftwareTree, GetBlocks, GetTags,
   CompileSoftware, GetBlockSource y readback independiente. Preflight: los 8 bloques estándar del
   PLC estaban `isFailsafe=false`, SCL según clasificación live donde aplica, sin protección,
   consistentes; cero tags; compilación inicial 0 errores/0 avisos.
2. `tia-create lite`: `PlcBuildAndImport` dryRun aceptado. El apply falló por intentar usar la
   cultura `zh-CN` ausente en el proyecto `en-US`; no importó ningún bloque. No se reintentó esa
   ruta sin corregirla.
3. Ruta experimental SCL: `WritePlcSclSourceFile`, `ImportPlcExternalSource` y
   `GenerateBlocksFromExternalSource` crearon el probe estándar `FB_AgentProbe_20260921`; un intento
   en grupo no existente fue rechazado `NotFound` sin mutar y se continuó desde la raíz exacta
   obtenida del árbol. Luego CompileSoftware dio 0/0, SaveProject pasó y GetBlocks/GetBlockSource
   confirmaron readback, `isFailsafe=false`, SCL, consistente y sin protección. Esta evidencia
   demuestra una ruta de fuente externa en un clon; no autoriza una creación general de bloques bajo
   el contrato vigente. Antes de aceptarla hay que implementar y probar el flujo de dos fases exigido
   por `AGENTS.md`: crear un FB vacío estándar, releer `isFailsafe=false`, `programmingLanguage=SCL`
   e `isKnowHowProtected=false`, e importar la lógica solo después de esa clasificación.
4. `ExportBlock` produjo XML de inspección. `ExportAsDocuments` fue descubierto en `tia-create`,
   pero TIA devolvió `EngineeringNotSupportedException` para el bloque SCL (nivel Update local no
   capturado); no se repitió sin cambio. El rechazo y su XML fallback quedaron registrados.
5. `DeletePlcBlock` preview identificó la ruta exacta, ningún caller externo y `deleted=false`.
   Se borró únicamente el probe; compile posterior 0/0, SaveProject y lectura independiente
   confirmaron ausencia. La restauración comparó los 31 archivos con el backup: ningún faltante,
   extra o hash distinto. No quedó servidor TIA-MCP ejecutándose.
6. `tia-create lite`: `FindTools` encontró `GetDeviceIpAddress`; `CallTool` leyó en el clon
   `PLC_1` y devolvió una IP de proyecto `192.168.200.20` junto con ocho nodos Ethernet. La sesión
   se desconectó sin mutación. Evidencia: `artifacts/32-device-ip-read.json`.

Los artefactos completos están en `90-tmp/e2e/20260921-iot2050-agent-probe-clean/`, en especial
`artifacts/01-prewrite-preflight.json`, `06-create-compile-save.json`, `16-import-external-source-root.json`,
`17-generate-compile-save.json`, `18-independent-readback.json`, `19-read-source-and-export-schema.json`,
`23-create-export-delete-preview.json`,
`24-create-export-xml-delete-preview.json`, `26-create-delete-compile-save.json`,
`27-independent-delete-readback.json` y `28-restore-report.json`.

**No probado por acción:** escritura independiente de tags/UDT/DB, modificación de hardware,
módulos, redes, HMI, medición física, comunicación con una CPU, online/watch, descarga y runtime.
Las guardas offline de hardware/red y los planes read-only de monitorización/OPC UA sí quedaron
verificados en la auditoría final; no elevan ninguna de esas acciones a nivel Fixture.
No se actuó sobre originales de ejemplos, `40-projects/` ni PLC físico.

**Regla de creación:** la ruta experimental anterior queda etiquetada como `experimental`, no como
capacidad profesional aceptada. La creación de un bloque nuevo permanece bloqueada hasta que exista
un flujo de dos fases con creación vacía, preflight global de F-blocks/tags Safety/protección,
clasificación live y descarte/restauración si alguna metadata falta.

### Fase 8 — PLCSIM, comunicaciones y HMI Runtime (R3)

- [x] Refrescar el informe a solo lectura en `90-tmp/e2e/20260921-iot2050-agent-probe-clean/artifacts/30-current-simulation-readiness.json`.
  Dio `READY_WITH_BLOCKERS`, `plcsimVirtualAdapterReady=true`, `tiaInstanceSafeForApply=true`,
  `hmiRuntimeAdvancedV20Ready=false` y `plcBehaviorVerified=false`.
  La comprobación más reciente, [readiness-20260922-final.json](../../../70-runs/simulation/readiness-20260922-final.json),
  conserva esos gates, confirma el adaptador virtual Siemens en estado `Up` y deja Runtime Advanced V20
  y el comportamiento PLC como bloqueadores/no verificados.
- [x] Corregir el runner para que use solo gates PLC booleanos estrictos, exija `DevicePath`,
  `SoftwarePath`, IP configurada leída por `GetDeviceIpAddress`, plan conductual con observación,
  instancia gestionada y una ruta virtual única; `DownloadToPlc` recibe el nombre completo y la IP
  cotejada. Mocks de regresión prueban las barreras; no equivalen a ejecución PLCSIM.
- [ ] Antes de descargar, confirmar que la CPU del proyecto coincide con el tipo de instancia
  virtual que registra el adaptador. `GetDeviceIpAddress` verificó que este clon IOT2050 usa
  `192.168.200.20`; el adaptador de aceptación está configurado para Sorting Plant/1516F. El readiness
  solo demuestra que el adaptador Windows está `Up`, no que se haya registrado una instancia.
- [ ] Descargar únicamente en esa instancia PLCSIM; ejecutar entradas/estados nominales y de borde;
  guardar trace, instance id, adapter/version, target/IP y build hash.
- [ ] Confirmar preflight del Runtime por familia/modelo/version; no usar el reporte Runtime Advanced
  como prueba de Unified ni de Runtime Professional. Computer Use abrió `SIMATIC Runtime Manager`
  y observó una lista de proyectos vacía con `General error during processing`; es Unified y no
  desbloquea WinCC Runtime Advanced V20.
- [x] Confirmar Computer Use nativo en esta sesión y registrar apertura/navegación visual de TIA.
- [x] Completar una primera inspección visual del editor y de una pantalla HMI en clones desechables;
  la edición SCL, compilación, guardado y lectura posterior del PLC están verificadas en el clon
  `AgentDemo_V20`, y `HMI_1 [TP1200 Comfort]`/`Screens/Grundbild`, `Connections` y `HMI tags` se
  inspeccionaron en el clon GamesCollection. En `Grundbild` también se creó, guardó y leyó de nuevo
  un objeto de texto `Computer Use HMI probe 2026-09-22`; el compile HMI y el runtime por modelo
  siguen pendientes.
- [ ] Probar por modelo binding, alarmas, acknowledgement/reset, acciones, navegación e interacción;
  usar valores/tolerancias/timeout especificados en R20 y capturar pantallas o dejar explícito quién
  aporta esa evidencia.
- [ ] Validar tráfico PLC↔HMI/protocolo en endpoint aislado; registrar alcance de diagnosis, puesto que
  una conexión con solo un extremo online puede exponer datos parciales.

No se ejecutó descarga ni runtime. Computer Use sí abrió PLCSIM Advanced V6.0 Update 1 en modo de
inspección: el acceso `PLCSIM` estaba seleccionado, no había instancia activa y el formulario de
instancia S7-1500 permaneció sin nombre; no se creó instancia ni se descargó nada. El registro
persistente de la instancia PLCSIM Advanced sigue
bloqueado por los códigos `mappingCode=0xffffffed`, `ipCode=0xfffffff2` y
`bindingCode=0xffffffed` anotados en `70-runs/acceptance/plcsim-ip-binding-20260917.json`; ese error
no se reintentó a ciegas. Además, el preflight y el inventario nativo solo identifican que Runtime
Advanced V20 compatible no está instalado/verificado. La evidencia gráfica queda en
[computer-use TIA](../../../70-runs/environment/computer-use-20260922-tia-gui-edit.json) y
[computer-use nativo/HMI](../../../70-runs/environment/computer-use-20260922-native-runtime-hmi.json).
Esto no desbloquea PLCSIM ni runtime HMI; no se sustituye por PLC físico ni se infiere runtime a
partir del compile offline.

### Fase 9 — Integración y acceso continuado

- [x] Incorporar el inventario schema por acción/perfil como apéndice dentro de este documento;
  mantenerlo separado de la tabla de acciones que sí se ejecutaron.
- [x] Registrar que Computer Use nativo está disponible en esta sesión y probar apertura, edición,
  compilación, guardado, lectura posterior y cierre en un clon PLC, además de inspección de un clon
  HMI y de las aplicaciones PLCSIM/Runtime instaladas. Reconsultar el inventario nativo y el título
  de TIA antes de cada tarea UI; el resultado `apps: []` de `cua_repl` solo describe la superficie
  browser. Evidencias: [PLC](../../../70-runs/environment/computer-use-20260922-tia-gui-edit.json),
  [HMI/runtimes](../../../70-runs/environment/computer-use-20260922-native-runtime-hmi.json).
- [ ] Verificar el perfil read y una sesión MCP nueva: adaptadores Claude/Codex/OpenCode/genérico,
  manifest, sincronización y `tia-inspect --isolated` pasan; la sesión fresca ejecutó
  `Connect → GetState → Disconnect` con el mutex. El reinicio de un harness externo concreto queda
  pendiente de ejecutarse en ese host, pero el contrato local de arranque y el binario V20 están
  verificados en [doctor-20260922-final.json](../../../70-runs/environment/doctor-20260922-final.json)
  y [Test-TiaIsolatedMode](../../../30-tools/tests/Test-TiaIsolatedMode.ps1).
- [x] Ejecutar la suite final de guards, el runner de propuesta SCL en modo negativo y
  `Write-TiaAcceptanceStatus.ps1`; el informe fechado [status-20260922-final11.json](../../../70-runs/acceptance/status-20260922-final11.json)
  mantiene correctamente `accepted=false` hasta completar runtime y recetas.
- [ ] Completar acciones permitidas por familia en fixture y actualizar los niveles de evidencia de
  cada fila. No se elevan tools de un schema por semejanza.
- [ ] Cerrar la ruta de planificación/ejecución cuando las tareas realizables con los perfiles,
  permisos y software actuales estén completadas; las limitaciones externas deben quedar **Bloqueadas**
  con evidencia, responsable y paso siguiente. La aceptación de ingeniería se informa por separado.

`accepted=false` en `Write-TiaAcceptanceStatus.ps1` significa que la aceptación funcional global aún no
se logró; no impide cerrar las tareas ejecutables de esta ruta si lo restante está explícitamente
bloqueado y no se presenta como aceptación aprobada. Mantener ese estado hasta que PLCSIM/Runtime y los
casos requeridos produzcan evidencia válida.

## Fuentes Siemens y del workspace

- Siemens, [Openness V20: tareas](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/basics/openness-tasks/introduction): crear, modificar, borrar, leer y exportar datos.
- Siemens, [conexión a TIA V20](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/tia-portal-openness-api/general-functions/connecting-to-the-tia-portal): instancias con/sin UI, conexión a procesos y límite del editor HMI al controlar UI.
- Siemens, [objetos HMI soportados](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/tia-portal-openness-api/tia-portal-openness-object/object-list): soporte varía por Basic/Comfort/Mobile/RT Advanced.
- Siemens, [principios import/export](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/overview/basic-principles-of-importing/exporting): objetos PLC/HMI, open references y formato interno/versionado.
- Siemens, [importar pantallas](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/importing/exporting-data-of-an-hmi-device/screens/importing-screens-to-an-hmi-device): pantalla y tipo de dispositivo compatibles.
- Siemens, [formato SIMATIC SD V20](https://docs.tia.siemens.cloud/r/en-us/v20/creating-and-managing-blocks/exporting-and-importing-blocks-in-simatic-sd-format-s7-1200-s7-1500/exporting-and-importing-blocks-in-simatic-sd-format-s7-1200-s7-1500) y [ampliaciones V20 Update 4](https://docs.tia.siemens.cloud/r/en-us/v20-updates/tia-portal-updates-readme/improvements-in-step-7/improvements-in-update-4): diferenciar baseline V20 de Update 4 para SCL/FBD/redes mixtas.
- Siemens, [OpenWithUpgrade V20](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/tia-portal-openness-api/functions-for-projects-and-project-data/opening-a-project): apertura de la versión anterior y límites para versiones más antiguas.
- Siemens, [escritura de F-blocks V20](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/importing/exporting-data-of-a-plc-device/blocks/exporting-failsafe-blocks) y [NORM_X](https://docs.tia.siemens.cloud/r/en-us/v20/scl-s7-1200-s7-1500/conversion-operations-s7-1200-s7-1500/norm_x-normalize-s7-1200-s7-1500): capacidades API no sustituyen la barrera local; la normalización está sujeta a tipos y límites documentados.
- Siemens, [diagnóstico de conexiones](https://docs.tia.siemens.cloud/r/en-us/v20/device-and-network-diagnostics/connection-diagnostics/overview-of-connection-diagnostics), [restricciones de simulación Basic](https://docs.tia.siemens.cloud/r/en-us/v20/compiling-and-loading-basic-panels-panels-comfort-panels-rt-advanced-rt-professional/basic-panels-basic-panels/simulating-projects-basic-panels/simulation-restrictions-basic-panels), [simulación Unified](https://docs.tia.siemens.cloud/r/en-us/v20/simulate-runtime-rt-unified/simulate-unified-comfort-panel-rt-unified/basics-of-simulation-rt-unified) y [simulación Runtime Advanced](https://docs.tia.siemens.cloud/r/en-us/v20/compiling-and-loading-basic-panels-panels-comfort-panels-rt-advanced-rt-professional/runtime-advanced-and-panels-panels-comfort-panels-rt-advanced/simulating-projects-panels-comfort-panels-rt-advanced/wincc-runtime-advanced-simulation-panels-comfort-panels-rt-advanced): restricciones por familia y alcance real de la evidencia visual/runtime.
- Siemens, [comentarios de bloque en STEP 7](https://docs.tia.siemens.cloud/r/en-us/v20/creating-and-managing-blocks/creating-blocks/entering-a-block-comment) y [lectura/escritura de atributos Openness V21](https://docs.tia.siemens.cloud/r/en-us/v21/tia-portal-openness-api-for-automation-of-engineering-workflows/tia-portal-openness-api/functions-for-accessing-the-data-of-a-plc-device/blocks/accessing-attributes-of-all-blocks): el comentario es metadata del bloque; el acceso API de V21 no prueba que la ruta V20 local esté disponible.
- Local: 10-kb/10-openness/capacidades-y-alcance-por-conexion.md, 10-kb/10-openness/limites.md,
  10-kb/00-fundamentos/tia-interfaz-y-computer-use.md, 30-tools/scripts/README.md,
  70-runs/acceptance/status-latest.json y schemas MCP en 70-runs/.

## Registro inicial

| Fecha | Decisión | Evidencia |
|---|---|---|
| 2026-09-21 | IOT2050 es el fixture primario, pero sólo mediante clon nuevo en 90-tmp/e2e. | 70-runs/e2e/20260915-082218/report.json y encuesta de fixture. |
| 2026-09-21 | Schema guardado sólo cataloga; no se presenta como ejecución. Capturar roster vivo por perfil y verificar acción a acción. | 70-runs/simulation/mcp-tool-schemas-all.json; 70-runs/mcp/acceptance-schemas.json. |
| 2026-09-21 | Política excluye F/safety y PLC físico aunque API describa soporte técnico. | AGENTS.md §§3.1–3.3; investigación local de DTOs/GetTags/ImportSources. |

---

## Apéndice: inventario de capacidades TIA por acción y perfil

Apéndice enlazado al [plan operativo TIA-Claude](2026-09-21-tia-agent-operating-model.md). Las tablas
detalladas siguientes representan los cuatro snapshots históricos de [20260921-01-baseline](../../../70-runs/tia-capabilities/20260921-01-baseline/).

### Matriz live normalizada — 2026-09-22

La tabla actual y reproducible por perfil está en
[20260922-live-tool-matrix.md](../../../70-runs/tia-capabilities/20260922-live-tool-matrix.md).
Incluye las 84 herramientas de `tia-inspect / write` aislado, 53 de `tia-inspect / read`, 55 de
`tia-create / lite` y 222 de `tia-create / full`, con parámetros del schema, riesgo operativo,
precondiciones y estado local. `Esquema` significa únicamente presencia en `tools/list`; las filas
con `Fixture` remiten a una llamada concreta. El script reproducible es
[Export-TiaCapabilityMatrix.ps1](../../../30-tools/scripts/Export-TiaCapabilityMatrix.ps1).

La matriz no asigna todavía cada herramienta MCP a un miembro de `Siemens.Engineering`: ese mapeo
acción a acción sigue **no probado**. El probe independiente
[direct-openness-20260922-final.json](../../../70-runs/environment/direct-openness-20260922-final.json)
sí verifica la inicialización V20, la carga de `Siemens.Engineering` 20.0.0.0 y la enumeración de
procesos sin Attach/OpenProject. Tampoco incluye Computer Use; la identidad de una ventana TIA y
la disponibilidad nativa se verifican en la fase gráfica final.

Los rosters live más recientes están en `20260921-04` a `-07`; son capturas schema-only sin proyecto
conectado ni ejecución de las acciones, y no están reconciliados fila por fila con las tablas
históricas. No usar las tablas `01-baseline` como allowlist actual.

### Alcance y lectura

- Filas: **435** exposiciones de schema en cuatro perfiles; **289** nombres distintos en la unión. Los nombres repetidos se mantienen en cada sección: schemas y disponibilidad son independientes.
- Cada tabla refleja solo el snapshot indicado. No se deduce que una herramienta esté disponible en otro perfil ni que un nombre parecido sea equivalente.
- **Inputs** enumera tipos y valores default declarados por el schema; req son exactamente los campos de required, opt los demás. Los campos JSON internos siguen siendo strings si el schema solo declara string. array[?] y object[?] indican que el schema no expone su estructura interna.
- **Evidencia**: Solo schema significa presencia en tools/list; no acredita que la llamada funcione. Solo se asciende a ejecución cuando un informe guarda el nombre exacto del tool y el resultado.
- **Riesgo** es clasificación conservadora por acción descrita, no por ejecución ni contexto del target. R3 cubre conexión/lectura online o runtime; requiere identificar el target. R4 cubre descargas, escrituras online, bridges genéricos de ejecución con efectos no acotados, safety o efecto físico directo.
- **MCP / Openness** se aplica a cada fila: MCP conocido = nombre e inputs exactos publicados por el perfil; Openness desconocido = no se mapea cada tool a una llamada/miembro Openness concreto. El plan documenta integración general, pero no catálogo validado por acción.
- Los snapshots se capturaron con una operación de enumeración marcada readOnly=true; eso describe la captura, no convierte las herramientas enumeradas en solo lectura.

#### Snapshots live más recientes por perfil (solo tools/list; sin proyecto)

| Perfil | Captura +02:00 | Tools | SHA-256 | Args capturados | Snapshot / alcance |
|---|---|---:|---|---|---|
| tia-inspect / write aislado | 16:44:12 | 84 | A291937DF7582F27FBCA6825D8A939B1DFCD48BB9BD170FA2550ED51CAFEEF63 | --tia-major-version 20 --isolated --fixture-root `<run>` --allow-write | [JSON](../../../70-runs/tia-capabilities/20260921-04-write-tools-live.json) |
| tia-inspect / read | 16:52:26 | 53 | 5844D0CBA7A95E6A69885AB767909D48C95BDB0BE3158ACD72DB3D9B02B05EFE | --tia-major-version 20 | [JSON](../../../70-runs/tia-capabilities/20260921-05-read-tools-live.json) |
| tia-create / lite | 16:52:35 | 55 | 63EF0ECED5F86E70C37CB78A0024A15A21A60A9E4DB05EAEA18174E7C81F3D55 | --tia-major-version 20 --profile lite | [JSON](../../../70-runs/tia-capabilities/20260921-06-create-lite-tools-live.json) |
| tia-create / full | 16:52:48 | 222 | EE691C7D33D1587FB55384BA307F0DFD8620B3B864650EAA4E23BD1973EDFA05 | --tia-major-version 20 --profile full | [JSON](../../../70-runs/tia-capabilities/20260921-07-create-full-tools-live.json) |

Los rosters de `tia-inspect` omiten `ImportSources` y `ImportFromDocuments`; `ImportFromDocuments` sí
aparece en `tia-create` lite/full. `FindTools` y `CallTool` aparecen en lite/full. Full incluye
`DownloadToPlc` y dos self-tests con `Safety` en el nombre. Todo lo anterior es solo schema: ninguna
de esas acciones se ejecutó en la captura, no hubo conexión a proyecto y su presencia no autoriza la
llamada. El Doctor read-only separado está en [20260921-08-doctor-read.json](../../../70-runs/tia-capabilities/20260921-08-doctor-read.json):
V20 activo, grupo Openness=true, V19/V20 Engineering y Portal presentes, `isConnected=false`, sin
proyecto MCP y `allowWrite=false`; no identifica ni modifica la ventana TIA visible.

Los snapshots intermedios `20260921-03-safe-write` registraban también 53/84 tools y los mismos imports
ausentes; se conservan como evidencia anterior, no como el roster live más reciente. Los bloques de inventario extensos que
siguen se conservan como baseline histórica de 59/99/55/222 tools; las sumas 435/289 y el desglose de
riesgo corresponden a esos cuatro snapshots históricos, no al roster seguro más reciente.

#### Evidencia resumida

| Perfil | Tools | SHA-256 | Args capturados | Snapshot |
|---|---:|---|---|---|
| tia-inspect / read | 59 | 140E979837B6ADFDF7DC1CDC05A783E0952797C733704E5649540E4D9003EB25 | --tia-major-version 20 | [JSON](../../../70-runs/tia-capabilities/20260921-01-baseline/tia-inspect-read.json) |
| tia-inspect / write | 99 | D52747D6D74FE8C1F9B073A6DAB62D9E0A0280E2E5DB51A338E91204141C9D79 | --tia-major-version 20 --allow-write | [JSON](../../../70-runs/tia-capabilities/20260921-01-baseline/tia-inspect-write.json) |
| tia-create / lite | 55 | 1DC631095BC70D826EE67F60FE56B5E65260DFA994001DFDE067FCDF5CF5EAC6 | --tia-major-version 20 --profile lite | [JSON](../../../70-runs/tia-capabilities/20260921-01-baseline/tia-create-lite.json) |
| tia-create / full | 222 | C0185FC85687CDD38DD73645D4C077C54BEA393E9F20E6D77F1D40239587E378 | --tia-major-version 20 --profile full | [JSON](../../../70-runs/tia-capabilities/20260921-01-baseline/tia-create-full.json) |

El recuento tools[].Count coincide con listedToolCount en los cuatro archivos. Los hashes se recalcularon sobre los bytes de los snapshots.

#### Escala de riesgo

| Nivel | Lectura de esta tabla |
|---|---|
| R0 | Helper, preview o validación offline sin conexión ni cambio de proyecto. |
| R1 | Lectura, exportación, diagnóstico o compilación sin efecto de control live identificado. |
| R2 | Cambia el proyecto/archivos de ingeniería o configura hardware/HMI/red. Algunos cambios solo afectan a la CPU tras una descarga aparte, que es R4. |
| R2* | Puede cambiar la pertenencia del usuario al grupo de Windows Siemens TIA Openness; no se ejecutó. |
| R3 | Conexión, inspección o lectura online/runtime, o control limitado a simulador; identificar el target antes de usarlo. |
| R4 | Descarga a PLC, escritura online, bridge genérico con efectos no acotados, safety o efecto físico directo. Bloqueado bajo el contrato actual. |

#### Conteo de clasificación por perfil

| Perfil | R0 | R1 | R2 | R2* | R3 | R4 |
|---|---:|---:|---:|---:|---:|---:|
| tia-inspect / read | 1 | 51 | 7 | 0 | 0 | 0 |
| tia-inspect / write | 1 | 54 | 44 | 0 | 0 | 0 |
| tia-create / lite | 4 | 32 | 16 | 2 | 0 | 1 |
| tia-create / full | 52 | 95 | 60 | 2 | 8 | 5 |

### tia-inspect / read

Roster de lectura; se mantiene separado de tia-inspect / write. Snapshot: [tia-inspect-read.json](../../../70-runs/tia-capabilities/20260921-01-baseline/tia-inspect-read.json).

**Nota de política:** este snapshot sin --allow-write contiene schemas con nombres como ImportBlock, ImportType, ImportFromDocuments, SaveProject, SaveAsProject y CloseProject. Se marcan por el riesgo que describen, pero permanecen en evidencia Solo schema; el contrato mantiene el perfil read como lectura y este inventario no autoriza invocarlas.

| Tool | Familia | Inputs (req; opt) | Evidencia | Riesgo | MCP / Openness |
|---|---|---|---|---:|---|
| CloseProject | Project / session | req: —; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CompileSoftware | Diagnostics / compilation | req: softwarePath:string; opt: password:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| Connect | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| Disconnect | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| Doctor | Diagnostics / compilation | req: —; opt: — | [Doctor ejecutado; smoke OK](../../../70-runs/tia-capabilities/20260921-01-baseline/doctor.json) | R1 | MCP conocido / Openness desconocido |
| ExportAsDocuments | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlocks | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlocksAsDocuments | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportPlcAsSourceTree | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTagTable | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportType | PLC tags / DB / types | req: softwarePath:string, exportPath:string, typePath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypeAsDocuments | PLC tags / DB / types | req: softwarePath:string, typePath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypes | PLC tags / DB / types | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypesAsDocuments | PLC tags / DB / types | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportWatchTable | PLC online / watch / monitor | req: softwarePath:string, watchTablePath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| FindInCode | Other / utility | req: softwarePath:string, pattern:string; opt: nameFilter:string="", maxResults:integer=200 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateBlockSource | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: withDependencies:boolean=false, preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateSources | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", withDependencies:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateTypeSource | PLC tags / DB / types | req: softwarePath:string, typePath:string, exportPath:string; opt: withDependencies:boolean=false, preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockInfo | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockInterface | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlocks | PLC blocks / sources / import-export | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockSource | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: format:string="document", maxChars:integer=40000 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlocksWithHierarchy | PLC blocks / sources / import-export | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetConstants | PLC tags / DB / types | req: softwarePath:string; opt: tagTablePath:string="", kind:string="all", regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetCrossReferences | Other / utility | req: softwarePath:string; opt: objectPath:string="", objectKind:string="auto", filter:string="AllObjects", maxDepth:integer=1 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDeviceInfo | Hardware / IO / network | req: devicePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDeviceItemInfo | Hardware / IO / network | req: deviceItemPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDevices | Hardware / IO / network | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetExternalSourceInfo | PLC blocks / sources / import-export | req: softwarePath:string, sourcePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetExternalSources | PLC blocks / sources / import-export | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetForceTables | PLC online / watch / monitor | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetPlcSummary | Other / utility | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetProject | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetProjectTree | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetSoftwareInfo | Other / utility | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetSoftwareTree | Other / utility | req: softwarePath:string; opt: sections:string="all" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetState | Other / utility | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTagInfo | PLC tags / DB / types | req: softwarePath:string, tagPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTags | PLC tags / DB / types | req: softwarePath:string; opt: tagTablePath:string="", regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTagTableInfo | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTagTables | PLC tags / DB / types | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTypeInfo | PLC tags / DB / types | req: softwarePath:string, typePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTypes | PLC tags / DB / types | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTypeSource | PLC tags / DB / types | req: softwarePath:string, typePath:string; opt: format:string="document", maxChars:integer=40000 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetWatchTableInfo | PLC online / watch / monitor | req: softwarePath:string, watchTablePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetWatchTables | PLC online / watch / monitor | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| ImportBlock | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportBlocksFromDocuments | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string; opt: regexName:string="", importOption:string="Override" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportFromDocuments | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string, fileNameWithoutExtension:string; opt: importOption:string="Override" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportType | PLC tags / DB / types | req: softwarePath:string, groupPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| OpenProject | Project / session | req: path:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| OpenTiaProject | Project / session | req: path:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| PreviewImport | PLC blocks / sources / import-export | req: softwarePath:string, importPath:string, kind:string; opt: groupPath:string="" | Solo schema | R0 | MCP conocido / Openness desconocido |
| ResolveObjectPath | Other / utility | req: softwarePath:string, name:string; opt: kind:string="any" | Solo schema | R1 | MCP conocido / Openness desconocido |
| SaveAsProject | Project / session | req: newProjectPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| SaveProject | Project / session | req: —; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| WhereUsed | Other / utility | req: softwarePath:string, name:string; opt: kind:string="any" | Solo schema | R1 | MCP conocido / Openness desconocido |

### tia-inspect / write

Snapshot con --allow-write. El roster por sí solo no implica Attach. Snapshot: [tia-inspect-write.json](../../../70-runs/tia-capabilities/20260921-01-baseline/tia-inspect-write.json).

| Tool | Familia | Inputs (req; opt) | Evidencia | Riesgo | MCP / Openness |
|---|---|---|---|---:|---|
| CloseProject | Project / session | req: —; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CompileSoftware | Diagnostics / compilation | req: softwarePath:string; opt: password:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| Connect | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| CopyBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, targetGroupPath:string; opt: overwrite:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| CopyType | PLC tags / DB / types | req: softwarePath:string, typePath:string, targetGroupPath:string; opt: overwrite:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateBlockGroup | PLC blocks / sources / import-export | req: softwarePath:string, parentGroupPath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateExternalSourceFromFile | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, name:string, filePath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateExternalSourceGroup | PLC blocks / sources / import-export | req: softwarePath:string, parentGroupPath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateFB | Other / utility | req: softwarePath:string, groupPath:string, name:string; opt: language:string="LAD", autoNumber:boolean=true, number:integer=0 | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateInstanceDB | Other / utility | req: softwarePath:string, groupPath:string, name:string, instanceOfName:string; opt: autoNumber:boolean=true, number:integer=0 | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateTag | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, name:string; opt: dataTypeName:string="", logicalAddress:string="" | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateTagTable | PLC tags / DB / types | req: softwarePath:string, groupPath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateTagTableGroup | PLC tags / DB / types | req: softwarePath:string, parentGroupPath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateTypeGroup | PLC tags / DB / types | req: softwarePath:string, parentGroupPath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateUserConstant | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, name:string; opt: dataTypeName:string="", value:string="" | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateWatchTable | PLC online / watch / monitor | req: softwarePath:string, groupPath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateWatchTableGroup | PLC online / watch / monitor | req: softwarePath:string, parentGroupPath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteBlockGroup | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteExternalSource | PLC blocks / sources / import-export | req: softwarePath:string, sourcePath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteExternalSourceGroup | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteTag | PLC tags / DB / types | req: softwarePath:string, tagPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteTagTable | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteTagTableGroup | PLC tags / DB / types | req: softwarePath:string, groupPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteType | PLC tags / DB / types | req: softwarePath:string, typePath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteTypeGroup | PLC tags / DB / types | req: softwarePath:string, groupPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteUserConstant | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteWatchTable | PLC online / watch / monitor | req: softwarePath:string, watchTablePath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteWatchTableGroup | PLC online / watch / monitor | req: softwarePath:string, groupPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| Disconnect | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| Doctor | Diagnostics / compilation | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportAsDocuments | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlocks | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlocksAsDocuments | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportPlcAsSourceTree | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTagTable | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportType | PLC tags / DB / types | req: softwarePath:string, exportPath:string, typePath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypeAsDocuments | PLC tags / DB / types | req: softwarePath:string, typePath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypes | PLC tags / DB / types | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypesAsDocuments | PLC tags / DB / types | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportWatchTable | PLC online / watch / monitor | req: softwarePath:string, watchTablePath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| FindInCode | Other / utility | req: softwarePath:string, pattern:string; opt: nameFilter:string="", maxResults:integer=200 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateBlocksFromSource | PLC blocks / sources / import-export | req: softwarePath:string, sourcePath:string; opt: targetGroupPath:string="", keepOnError:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateBlockSource | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: withDependencies:boolean=false, preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateSources | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", withDependencies:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateTypeSource | PLC tags / DB / types | req: softwarePath:string, typePath:string, exportPath:string; opt: withDependencies:boolean=false, preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockInfo | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockInterface | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlocks | PLC blocks / sources / import-export | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockSource | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: format:string="document", maxChars:integer=40000 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlocksWithHierarchy | PLC blocks / sources / import-export | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetConstants | PLC tags / DB / types | req: softwarePath:string; opt: tagTablePath:string="", kind:string="all", regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetCrossReferences | Other / utility | req: softwarePath:string; opt: objectPath:string="", objectKind:string="auto", filter:string="AllObjects", maxDepth:integer=1 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDeviceInfo | Hardware / IO / network | req: devicePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDeviceItemInfo | Hardware / IO / network | req: deviceItemPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDevices | Hardware / IO / network | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetExternalSourceInfo | PLC blocks / sources / import-export | req: softwarePath:string, sourcePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetExternalSources | PLC blocks / sources / import-export | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetForceTables | PLC online / watch / monitor | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetPlcSummary | Other / utility | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetProject | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetProjectTree | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetSoftwareInfo | Other / utility | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetSoftwareTree | Other / utility | req: softwarePath:string; opt: sections:string="all" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetState | Other / utility | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTagInfo | PLC tags / DB / types | req: softwarePath:string, tagPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTags | PLC tags / DB / types | req: softwarePath:string; opt: tagTablePath:string="", regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTagTableInfo | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTagTables | PLC tags / DB / types | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTypeInfo | PLC tags / DB / types | req: softwarePath:string, typePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTypes | PLC tags / DB / types | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTypeSource | PLC tags / DB / types | req: softwarePath:string, typePath:string; opt: format:string="document", maxChars:integer=40000 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetWatchTableInfo | PLC online / watch / monitor | req: softwarePath:string, watchTablePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetWatchTables | PLC online / watch / monitor | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| ImportBlock | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportBlocksFromDocuments | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string; opt: regexName:string="", importOption:string="Override" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportFromDocuments | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string, fileNameWithoutExtension:string; opt: importOption:string="Override" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportSources | PLC blocks / sources / import-export | req: softwarePath:string, importPath:string; opt: regexName:string="", keepOnError:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportTagTable | PLC tags / DB / types | req: softwarePath:string, groupPath:string, importPath:string; opt: overwrite:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportType | PLC tags / DB / types | req: softwarePath:string, groupPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportTypeFromDocuments | PLC tags / DB / types | req: softwarePath:string, groupPath:string, importPath:string, fileNameWithoutExtension:string; opt: importOption:string="Override" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportTypesFromDocuments | PLC tags / DB / types | req: softwarePath:string, groupPath:string, importPath:string; opt: regexName:string="", importOption:string="Override" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportWatchTable | PLC online / watch / monitor | req: softwarePath:string, groupPath:string, importPath:string; opt: overwrite:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| MoveBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, targetGroupPath:string; opt: overwrite:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| MoveType | PLC tags / DB / types | req: softwarePath:string, typePath:string, targetGroupPath:string; opt: overwrite:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| OpenProject | Project / session | req: path:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| OpenTiaProject | Project / session | req: path:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| PreviewImport | PLC blocks / sources / import-export | req: softwarePath:string, importPath:string, kind:string; opt: groupPath:string="" | Solo schema | R0 | MCP conocido / Openness desconocido |
| RenameBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, newName:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| RenameTagTable | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, newName:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| RenameType | PLC tags / DB / types | req: softwarePath:string, typePath:string, newName:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| RenameWatchTable | PLC online / watch / monitor | req: softwarePath:string, watchTablePath:string, newName:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ResolveObjectPath | Other / utility | req: softwarePath:string, name:string; opt: kind:string="any" | Solo schema | R1 | MCP conocido / Openness desconocido |
| SaveAsProject | Project / session | req: newProjectPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| SaveProject | Project / session | req: —; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| UpdateTag | PLC tags / DB / types | req: softwarePath:string, tagPath:string; opt: newName:string\|null=null, dataTypeName:string\|null=null, logicalAddress:string\|null=null, externalAccessible:boolean\|null=null, externalVisible:boolean\|null=null, externalWritable:boolean\|null=null | Solo schema | R2 | MCP conocido / Openness desconocido |
| UpdateUserConstant | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, name:string; opt: newName:string\|null=null, dataTypeName:string\|null=null, value:string\|null=null | Solo schema | R2 | MCP conocido / Openness desconocido |
| WhereUsed | Other / utility | req: softwarePath:string, name:string; opt: kind:string="any" | Solo schema | R1 | MCP conocido / Openness desconocido |

### tia-create / lite

El plan registra un ensayo anterior de ScaffoldProject en fixture; solo esa acción se marca con evidencia exacta. Snapshot: [tia-create-lite.json](../../../70-runs/tia-capabilities/20260921-01-baseline/tia-create-lite.json).

| Tool | Familia | Inputs (req; opt) | Evidencia | Riesgo | MCP / Openness |
|---|---|---|---|---:|---|
| AddDeviceWithFallback | Hardware / IO / network | req: preferredMlfb:string, preferredVersion:string, deviceName:string; opt: family:string="S7-1500" | Solo schema | R2 | MCP conocido / Openness desconocido |
| AttachToOpenProject | Project / session | req: projectName:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| Bootstrap | MCP meta / discovery | req: —; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| CallTool | MCP meta / discovery | req: name:string; opt: argumentsJson:string="" | Solo schema | R4 | MCP conocido / Openness desconocido |
| ClearExports | PLC blocks / sources / import-export | req: —; opt: olderThanHours:integer=24 | Solo schema | R1 | MCP conocido / Openness desconocido |
| CloseProject | Project / session | req: —; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CompileAndDiagnoseHmi | HMI | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| CompileAndDiagnosePlc | PLC software objects | req: softwarePath:string; opt: password:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| CompileSoftware | PLC software objects | req: softwarePath:string; opt: password:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| Connect | Portal / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ConnectDeviceNodesToProfinetSubnet | Hardware / IO / network | req: firstRootPath:string, secondRootPath:string; opt: subnetName:string="PN_IE_1" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ConnectIsolated | Portal / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| CreateProject | Project / session | req: directoryPath:string, projectName:string; opt: closeForeignProject:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteExport | PLC blocks / sources / import-export | req: exportId:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DescribeBlockLogic | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| Disconnect | Portal / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| Doctor | Diagnostics / preflight | req: —; opt: fix:boolean=true | Solo schema | R2* | MCP conocido / Openness desconocido |
| EnsureOpennessUserGroup | Portal / session | req: —; opt: — | Solo schema | R2* | MCP conocido / Openness desconocido |
| ExportAsDocuments | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlocksAsDocuments | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| FindTools | MCP meta / discovery | req: —; opt: query:string="", limit:integer=12 | Solo schema | R0 | MCP conocido / Openness desconocido |
| GenerateAcceptanceReport | Reports / release metadata | req: —; opt: outputDirectory:string="", connectIfNeeded:boolean=false, includeProjectTree:boolean=false, inspectPortalProcesses:boolean=false, title:string="TIA MCP Acceptance Report" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateBlocksFromExternalSource | PLC blocks / sources / import-export | req: softwarePath:string, externalSourceName:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| GenerateErrorReport | Reports / release metadata | req: errorCode:string, summary:string; opt: detail:string="", recommendedNextActions:string="", severity:string="error", outputDirectory:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetAuthoringGuide | Other / utility | req: topic:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockInfo | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlocks | PLC blocks / sources / import-export | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlocksWithHierarchy | PLC blocks / sources / import-export | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetCrossReferences | PLC software objects | req: softwarePath:string, objectPath:string; opt: objectKind:string="Block", filter:string="AllObjects" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDevices | Hardware / IO / network | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetExport | PLC blocks / sources / import-export | req: exportId:string; opt: offset:integer=0, length:integer=0 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetPlcTagTables | PLC tags / DB / types | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetProject | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetProjectTree | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetSoftwareInfo | PLC software objects | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetSoftwareTree | PLC software objects | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetState | Portal / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GoOffline | PLC online / watch / monitor | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ImportBlock | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportBlocksFromDocuments | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string; opt: regexName:string="", importOption:string="Override" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportFromDocuments | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string, fileNameWithoutExtension:string; opt: importOption:string="Override" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportPlcTagTable | PLC tags / DB / types | req: softwarePath:string, folderPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportType | PLC tags / DB / types | req: softwarePath:string, groupPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ListExports | PLC blocks / sources / import-export | req: —; opt: tool:string=null, limit:integer=20 | Solo schema | R1 | MCP conocido / Openness desconocido |
| ListPortalProcessProjects | Portal / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| OpenProject | Project / session | req: path:string; opt: closeForeignProject:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| PlcBuildAndImport | PLC blocks / sources / import-export | req: softwarePath:string, kind:string, json:string; opt: typeGroupPath:string="", tagFolderPath:string="", blockGroupPath:string="", compileAfter:boolean=true, dryRun:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| RunCapabilitySelfTest | Diagnostics / preflight | req: —; opt: connectIfNeeded:boolean=false, includeProjectTree:boolean=false, inspectPortalProcesses:boolean=false, expectedPlcSoftwarePath:string="PLC_1", expectedHmiSoftwarePath:string="HMI_RT_1" | Solo schema | R1 | MCP conocido / Openness desconocido |
| RunOnlineMonitoringSafetySelfTest | Diagnostics / preflight | req: —; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| SaveExport | PLC blocks / sources / import-export | req: exportId:string, outputPath:string; opt: raw:boolean=false, overwrite:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| SaveProject | Project / session | req: —; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ScaffoldProject | Project / session | req: spec:string; opt: dryRun:boolean=true | [Fixture exacto: dry-run + apply, compile 0/0, readback/export y cierre de sesión](../../../70-runs/e2e/agent-demo-scaffold-20260922-083500-002/scaffold-report.json) | R2 | MCP conocido / Openness desconocido |
| SearchHardwareCatalog | Hardware / IO / network | req: keyword:string; opt: limit:integer=50 | Solo schema | R1 | MCP conocido / Openness desconocido |
| ValidateAutomationContext | Diagnostics / preflight | req: —; opt: expectedPlcSoftwarePath:string="PLC_1", expectedHmiSoftwarePath:string="HMI_RT_1" | Solo schema | R1 | MCP conocido / Openness desconocido |
| WritePlcSclSourceFile | PLC blocks / sources / import-export | req: sclContent:string; opt: outputPath:string="" | Solo schema | R2 | MCP conocido / Openness desconocido |

**Bridge de perfil:** CallTool declara que puede invocar cualquier nombre del roster completo aunque no figure en la lista visible. La fila CallTool es R4 por alcance dinámico; no se agregan herramientas ocultas a este inventario ni se infiere su disponibilidad desde otro perfil. FindTools debe proporcionar el nombre y firma antes de considerar una llamada.

### tia-create / full

Solo enumeración tools/list según el plan; no se usó para modificar un proyecto. Este roster no habilita acciones en lite. Snapshot: [tia-create-full.json](../../../70-runs/tia-capabilities/20260921-01-baseline/tia-create-full.json).

| Tool | Familia | Inputs (req; opt) | Evidencia | Riesgo | MCP / Openness |
|---|---|---|---|---:|---|
| AddDevice | Hardware / IO / network | req: orderNumber:string, version:string, deviceName:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| AddDeviceWithFallback | Hardware / IO / network | req: preferredMlfb:string, preferredVersion:string, deviceName:string; opt: family:string="S7-1500" | Solo schema | R2 | MCP conocido / Openness desconocido |
| AddGsdDeviceWithProbe | Hardware / IO / network | req: keyword:string, deviceName:string; opt: preferredDap:string="" | Solo schema | R2 | MCP conocido / Openness desconocido |
| AddHardwareCatalogDeviceWithProbe | Hardware / IO / network | req: keyword:string, deviceName:string; opt: preferredText:string="" | Solo schema | R2 | MCP conocido / Openness desconocido |
| AnalyzeGlobalLibraryPackage | HMI | req: libraryPath:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| AnalyzeHmiTemplateReference | HMI | req: templateDirectory:string, referenceProjectPath:string, referenceGlobalLibraryPath:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| AnalyzeUnifiedHmiTemplateLayout | HMI | req: templateDirectory:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| ApplyUnifiedHmiLayout | HMI | req: hmiSoftwarePath:string, screenName:string, layoutJson:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ApplyUnifiedHmiScreenDesignJson | HMI | req: hmiSoftwarePath:string, screenName:string, designJson:string; opt: strict:boolean=true | Solo schema | R1 | MCP conocido / Openness desconocido |
| ApplyUnifiedHmiTheme | HMI | req: hmiSoftwarePath:string, screenName:string, themeJson:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| AttachDeviceNodeToSubnet | Hardware / IO / network | req: deviceItemPath:string, interfaceIndex:integer, subnetName:string; opt: anchorDeviceItemPath:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| AttachToOpenProject | Project / session | req: projectName:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| BindUnifiedHmiButtonPressedTag | HMI | req: hmiSoftwarePath:string, screenName:string, buttonName:string, tagName:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| BindUnifiedHmiTagDynamization | HMI | req: hmiSoftwarePath:string, screenName:string, itemName:string, propertyName:string, tagName:string; opt: dataType:string="Bool", plcTag:string="", address:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| Bootstrap | MCP meta / discovery | req: —; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildClassicHmiMinimalPackage | HMI | req: packageJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildClassicHmiScreenXml | HMI | req: designJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildClassicHmiTagTableXml | HMI | req: tableJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildFlgNetCallXml | Offline PLC builders | req: flgNetJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildPlcGlobalDbXml | Offline PLC builders | req: globalDbJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildPlcSymbolManifestFromXmlPath | Offline PLC builders | req: path:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildPlcTagTableXml | Offline PLC builders | req: tagTableJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildPlcUdtXml | Offline PLC builders | req: udtJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildReleaseDiagnosticReport | Reports / release metadata | req: offlineReleaseSuiteJsonPath:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildReleaseManifest | Reports / release metadata | req: offlineReleaseSuiteJsonPath:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildReleaseRunbook | Reports / release metadata | req: offlineReleaseSuiteJsonPath:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildStructuredTextXml | Offline PLC builders | req: structuredTextJson:string; opt: innerOnly:boolean=false | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildUnifiedHmiButtonActionScript | HMI | req: actionKind:string, eventType:string; opt: targetTag:string="", targetScreen:string="", targetPopup:string="" | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildUnifiedHmiLayoutDesignJson | HMI | req: layoutJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildUnifiedHmiTemplateApplyDesignJson | HMI | req: templateFile:string; opt: fallbackWidth:integer=800, fallbackHeight:integer=480 | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildUnifiedHmiTemplateApplyDesignManifest | HMI | req: templateDirectory:string; opt: fallbackWidth:integer=800, fallbackHeight:integer=480 | Solo schema | R0 | MCP conocido / Openness desconocido |
| BuildUnifiedHmiThemeDesignJson | HMI | req: themeJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| CallTool | MCP meta / discovery | req: name:string; opt: argumentsJson:string="" | Solo schema | R4 | MCP conocido / Openness desconocido |
| CheckDownloadReadiness | PLC online / watch / monitor | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ClearExports | PLC blocks / sources / import-export | req: —; opt: olderThanHours:integer=24 | Solo schema | R1 | MCP conocido / Openness desconocido |
| CloseProject | Project / session | req: —; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CompareSoftwareToOnline | PLC online / watch / monitor | req: softwarePath:string; opt: maxDepth:integer=4, maxEntries:integer=200 | Solo schema | R3 | MCP conocido / Openness desconocido |
| CompileAndDiagnoseHmi | HMI | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| CompileAndDiagnosePlc | PLC software objects | req: softwarePath:string; opt: password:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| CompileSoftware | PLC software objects | req: softwarePath:string; opt: password:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| ComposePlcFbBlockXml | Offline PLC builders | req: fbBlockJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| ComposePlcFcBlockXml | Offline PLC builders | req: fcBlockJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| ComposePlcLadFcBlockXml | Offline PLC builders | req: ladFcBlockJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| Connect | Portal / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ConnectDeviceNodesToProfinetSubnet | Hardware / IO / network | req: firstRootPath:string, secondRootPath:string; opt: subnetName:string="PN_IE_1" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ConnectIsolated | Portal / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ConnectProjectToWorkspace | Project / session | req: —; opt: workspaceName:string="", dryRun:boolean=true, deviceFilter:string="", maxObjects:integer=3000, walkTrace:boolean=false | Solo schema | R0 | MCP conocido / Openness desconocido |
| CreatePlcBlockGroup | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateProject | Project / session | req: directoryPath:string, projectName:string; opt: closeForeignProject:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateVersionControlWorkspace | Library / version control | req: workspaceName:string, folderPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteExport | PLC blocks / sources / import-export | req: exportId:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeletePlcBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: dryRun:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeletePlcExternalSource | PLC blocks / sources / import-export | req: softwarePath:string, externalSourceName:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeletePlcTagTable | PLC tags / DB / types | req: softwarePath:string, tagTableName:string; opt: dryRun:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeletePlcType | PLC tags / DB / types | req: softwarePath:string, typePath:string; opt: dryRun:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| DescribeBlockLogic | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| DescribeHmiScreen | HMI | req: softwarePath:string, screenName:string; opt: maxMembers:integer=200 | Solo schema | R0 | MCP conocido / Openness desconocido |
| DescribeHmiScreenItem | HMI | req: softwarePath:string, screenName:string, itemName:string; opt: maxMembers:integer=200 | Solo schema | R0 | MCP conocido / Openness desconocido |
| DescribeHmiSoftware | HMI | req: softwarePath:string; opt: maxMembers:integer=200 | Solo schema | R0 | MCP conocido / Openness desconocido |
| DescribeHmiTag | HMI | req: softwarePath:string, tagTableName:string, tagName:string; opt: maxMembers:integer=200 | Solo schema | R0 | MCP conocido / Openness desconocido |
| DescribeHmiTagTable | HMI | req: softwarePath:string, tagTableName:string; opt: maxMembers:integer=200 | Solo schema | R0 | MCP conocido / Openness desconocido |
| DescribeObject | TIA object reflection | req: objectKind:string, objectPath:string; opt: softwarePath:string="", maxMembers:integer=200 | Solo schema | R0 | MCP conocido / Openness desconocido |
| DescribeObjectProperty | TIA object reflection | req: objectKind:string, objectPath:string, propertyPath:string; opt: softwarePath:string="", maxMembers:integer=200 | Solo schema | R0 | MCP conocido / Openness desconocido |
| DescribeService | TIA object reflection | req: objectKind:string, objectPath:string, serviceTypeSuffix:string; opt: softwarePath:string="", maxMembers:integer=200 | Solo schema | R0 | MCP conocido / Openness desconocido |
| DescribeUnifiedHmiButtonEventScript | HMI | req: hmiSoftwarePath:string, screenName:string, buttonName:string, eventType:string; opt: maxMembers:integer=200 | Solo schema | R0 | MCP conocido / Openness desconocido |
| Disconnect | Portal / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| Doctor | Diagnostics / preflight | req: —; opt: fix:boolean=true | Solo schema | R2* | MCP conocido / Openness desconocido |
| DownloadToPlc | PLC online / watch / monitor | req: softwarePath:string; opt: consistentBlocksOnly:boolean=true, keepActualValues:boolean=true, startAfterDownload:boolean=true, stopBeforeDownload:boolean=true, password:string="", pgPcInterface:string="", targetIpAddress:string="" | Solo schema | R4 | MCP conocido / Openness desconocido |
| DumpDeviceAttributes | Hardware / IO / network | req: devicePath:string; opt: nameFilter:string=null | Solo schema | R1 | MCP conocido / Openness desconocido |
| EnsureOpennessUserGroup | Portal / session | req: —; opt: — | Solo schema | R2* | MCP conocido / Openness desconocido |
| EnsureStartStopUnifiedHmi | HMI | req: hmiSoftwarePath:string; opt: screenName:string="Main", tagTableName:string="默认变量表", plcName:string="PLC_1", connectionName:string="HMI_Connection_1" | Solo schema | R2 | MCP conocido / Openness desconocido |
| EnsureSubnet | Hardware / IO / network | req: anchorDeviceItemPath:string, subnetType:string, subnetName:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| EnsureUnifiedHmiButtonAction | HMI | req: hmiSoftwarePath:string, screenName:string, buttonName:string, eventType:string, actionKind:string, targetTag:string; opt: syntaxCheck:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| EnsureUnifiedHmiButtonEventHandler | HMI | req: hmiSoftwarePath:string, screenName:string, buttonName:string, eventType:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| EnsureUnifiedHmiConnection | HMI | req: hmiSoftwarePath:string; opt: connectionName:string="HMI_Connection_1", plcName:string="PLC_1" | Solo schema | R2 | MCP conocido / Openness desconocido |
| EnsureUnifiedHmiDynamization | HMI | req: hmiSoftwarePath:string, screenName:string, itemName:string, propertyName:string; opt: dynamizationType:string="" | Solo schema | R2 | MCP conocido / Openness desconocido |
| EnsureUnifiedHmiScreen | HMI | req: hmiSoftwarePath:string, screenName:string; opt: width:integer=0, height:integer=0 | Solo schema | R2 | MCP conocido / Openness desconocido |
| EnsureUnifiedHmiScreenItem | HMI | req: hmiSoftwarePath:string, screenName:string, itemName:string; opt: itemType:string="Button", left:integer=0, top:integer=0, width:integer=120, height:integer=40, text:string="" | Solo schema | R2 | MCP conocido / Openness desconocido |
| EnsureUnifiedHmiTag | HMI | req: hmiSoftwarePath:string, tagTableName:string, tagName:string; opt: hmiDataType:string="Bool", plcName:string="PLC_1", plcTag:string="", connectionName:string="", address:string="", requireVerifiedBinding:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| EnsureUnifiedHmiTagTable | HMI | req: hmiSoftwarePath:string, tagTableName:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ExportAlarmClasses | PLC alarms / messages | req: softwarePath:string, exportPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportAlarmInstanceTexts | PLC alarms / messages | req: softwarePath:string, exportPath:string; opt: includeInfoText:boolean=true, includeAdditionalTexts:boolean=true, includeAlarmClass:boolean=true | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportAlarmTextLists | PLC alarms / messages | req: softwarePath:string, exportPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportAsDocuments | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlocks | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlocksAsDocuments | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportDeviceAml | Hardware / IO / network | req: devicePath:string, exportPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportHmiConnection | HMI | req: softwarePath:string, connectionName:string, exportPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportHmiProgram | HMI | req: softwarePath:string, exportDir:string; opt: exportScreens:boolean=true, exportTagTables:boolean=true | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportHmiScreen | HMI | req: softwarePath:string, screenName:string, exportPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportHmiTagTable | HMI | req: softwarePath:string, tagTableName:string, exportPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportOpcUaInterface | PLC communications / OPC UA | req: softwarePath:string, interfaceName:string, exportPath:string; opt: interfaceType:string="ServerInterface" | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportPlcTagTable | PLC tags / DB / types | req: softwarePath:string, tagTableName:string, exportPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportPlcWatchTable | PLC blocks / sources / import-export | req: softwarePath:string, watchTableName:string, exportPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportPlcWatchTablesToDirectory | PLC blocks / sources / import-export | req: softwarePath:string, dir:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTechnologyObject | PLC technology objects | req: softwarePath:string, toName:string, exportPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTechnologyObjectsToDirectory | PLC technology objects | req: softwarePath:string, exportDir:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportType | PLC tags / DB / types | req: softwarePath:string, exportPath:string, typePath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypes | PLC tags / DB / types | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| FindTools | MCP meta / discovery | req: —; opt: query:string="", limit:integer=12 | Solo schema | R0 | MCP conocido / Openness desconocido |
| GenerateAcceptanceReport | Reports / release metadata | req: —; opt: outputDirectory:string="", connectIfNeeded:boolean=false, includeProjectTree:boolean=false, inspectPortalProcesses:boolean=false, title:string="TIA MCP Acceptance Report" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateBlocksFromExternalSource | PLC blocks / sources / import-export | req: softwarePath:string, externalSourceName:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| GenerateErrorReport | Reports / release metadata | req: errorCode:string, summary:string; opt: detail:string="", recommendedNextActions:string="", severity:string="error", outputDirectory:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetAuthoringGuide | Other / utility | req: topic:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockInfo | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlocks | PLC blocks / sources / import-export | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlocksWithHierarchy | PLC blocks / sources / import-export | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetCrossReferences | PLC software objects | req: softwarePath:string, objectPath:string; opt: objectKind:string="Block", filter:string="AllObjects" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDeviceInfo | Hardware / IO / network | req: devicePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDeviceIpAddress | Hardware / IO / network | req: devicePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDeviceItemInfo | Hardware / IO / network | req: deviceItemPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDeviceItemIoAddresses | Hardware / IO / network | req: deviceItemPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDeviceItemNetworkInfo | Hardware / IO / network | req: deviceItemPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDeviceItemTree | Hardware / IO / network | req: deviceItemPath:string; opt: maxDepth:integer=4 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDevicePlugLocations | Hardware / IO / network | req: deviceItemPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetDevices | Hardware / IO / network | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetExport | PLC blocks / sources / import-export | req: exportId:string; opt: offset:integer=0, length:integer=0 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetHmiConnections | HMI | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetHmiProgramInfo | HMI | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetHmiScreens | HMI | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetHmiTags | HMI | req: softwarePath:string; opt: tagTableName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetHmiTagTables | HMI | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetObjectProperty | TIA object reflection | req: objectKind:string, objectPath:string, propertyPath:string; opt: softwarePath:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetOnlineState | PLC online / watch / monitor | req: softwarePath:string; opt: — | Solo schema | R3 | MCP conocido / Openness desconocido |
| GetOpcUaConfig | PLC communications / OPC UA | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetPlcExternalSources | PLC blocks / sources / import-export | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetPlcForceTables | PLC online / watch / monitor | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetPlcRunStateS7 | PLC online / watch / monitor | req: ip:string; opt: rack:integer=0, slot:integer=1, maxDiagEntries:integer=20, expectModuleContains:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetPlcTagTables | PLC tags / DB / types | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetPlcWatchTables | PLC software objects | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetProject | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetProjectTopology | Hardware / IO / network | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetProjectTree | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetPutGetAccess | Hardware / IO / network | req: devicePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetSoftwareInfo | PLC software objects | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetSoftwareTree | PLC software objects | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetState | Portal / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTechnologyObjects | PLC technology objects | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTypeInfo | PLC tags / DB / types | req: softwarePath:string, typePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetTypes | PLC tags / DB / types | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetVersionControlStatus | Library / version control | req: —; opt: workspaceName:string="", changedOnly:boolean=true | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetVersionControlWorkspaces | Library / version control | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GoOffline | PLC online / watch / monitor | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GoOfflineAll | PLC online / watch / monitor | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GoOnline | PLC online / watch / monitor | req: softwarePath:string; opt: ipAddress:string="", password:string="" | Solo schema | R3 | MCP conocido / Openness desconocido |
| ImportAlarmClasses | PLC alarms / messages | req: softwarePath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportAlarmTextLists | PLC alarms / messages | req: softwarePath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportBlock | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportBlocksFromDirectory | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, dir:string; opt: regexName:string="", overwrite:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportBlocksFromDocuments | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string; opt: regexName:string="", importOption:string="Override" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportFromDocuments | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, importPath:string, fileNameWithoutExtension:string; opt: importOption:string="Override" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportHmiConnection | HMI | req: softwarePath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportHmiScreen | HMI | req: softwarePath:string, folderPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportHmiScreensFromDirectory | HMI | req: softwarePath:string, folderPath:string, dir:string; opt: regexName:string="", overwrite:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportHmiTagTable | HMI | req: softwarePath:string, folderPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportHmiTagTablesFromDirectory | HMI | req: softwarePath:string, folderPath:string, dir:string; opt: regexName:string="", overwrite:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportMasterCopyFromGlobalLibrary | HMI | req: libraryPath:string, masterCopyName:string, hmiSoftwarePath:string, screenName:string; opt: importedItemName:string="", left:integer=0, top:integer=0 | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportOpcUaInterface | PLC communications / OPC UA | req: softwarePath:string, importPath:string; opt: interfaceType:string="ServerInterface" | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportPlcExternalSource | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, filePath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportPlcProgramFromDirectory | PLC blocks / sources / import-export | req: softwarePath:string, sourceDir:string; opt: typeGroupPath:string="", tagFolderPath:string="", technologyFolderPath:string="", blockGroupPath:string="", regexName:string="", compileAfter:boolean=true, stopOnImportFailure:boolean=false, dryRun:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportPlcTagTable | PLC tags / DB / types | req: softwarePath:string, folderPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportPlcTagTablesFromDirectory | PLC tags / DB / types | req: softwarePath:string, folderPath:string, dir:string; opt: regexName:string="", overwrite:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportTechnologyObject | PLC blocks / sources / import-export | req: softwarePath:string, folderPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportTechnologyObjectsFromDirectory | PLC blocks / sources / import-export | req: softwarePath:string, folderPath:string, dir:string; opt: regexName:string="", overwrite:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| ImportType | PLC tags / DB / types | req: softwarePath:string, groupPath:string, importPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| InvokeObject | TIA object reflection | req: objectKind:string, objectPath:string, methodName:string; opt: args:array[?]=null, softwarePath:string="", allowWrite:boolean=false | Solo schema | R4 | MCP conocido / Openness desconocido |
| InvokeService | TIA object reflection | req: objectKind:string, objectPath:string, serviceTypeSuffix:string, methodName:string; opt: args:array[?]=null, softwarePath:string="", allowWrite:boolean=false | Solo schema | R4 | MCP conocido / Openness desconocido |
| ListExports | PLC blocks / sources / import-export | req: —; opt: tool:string=null, limit:integer=20 | Solo schema | R1 | MCP conocido / Openness desconocido |
| ListObjectChildren | TIA object reflection | req: objectKind:string, objectPath:string, collectionProperty:string; opt: softwarePath:string="", limit:integer=200 | Solo schema | R1 | MCP conocido / Openness desconocido |
| ListPortalProcessProjects | Portal / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ListUnifiedHmiApiTypes | HMI | req: —; opt: nameContains:string="", limit:integer=500 | Solo schema | R1 | MCP conocido / Openness desconocido |
| MonitorWatchTableLiveS7 | PLC online / watch / monitor | req: softwarePath:string, watchTableName:string, ip:string; opt: rack:integer=0, slot:integer=1, expectModuleContains:string="" | Solo schema | R3 | MCP conocido / Openness desconocido |
| MoveBlockToGroup | PLC blocks / sources / import-export | req: softwarePath:string, blockName:string, targetGroupPath:string; opt: autoCreateGroup:boolean=true | Solo schema | R1 | MCP conocido / Openness desconocido |
| OpenProject | Project / session | req: path:string; opt: closeForeignProject:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| PlanGlobalLibraryTemplateReuse | HMI | req: libraryPath:string; opt: templateIntentJson:string="{}" | Solo schema | R0 | MCP conocido / Openness desconocido |
| PlanHardwareNetworkConfiguration | Hardware / IO / network | req: planJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| PlanOnlineReadOnlyDataProvider | PLC online / watch / monitor | req: provider:string, endpoint:string, tagPathsJson:string; opt: optionsJson:string="{}" | Solo schema | R0 | MCP conocido / Openness desconocido |
| PlanOnlineReadOnlyMonitoring | PLC online / watch / monitor | req: softwarePath:string, tagPathsJson:string; opt: mode:string="current-values" | Solo schema | R0 | MCP conocido / Openness desconocido |
| PlcBuildAndImport | PLC blocks / sources / import-export | req: softwarePath:string, kind:string, json:string; opt: typeGroupPath:string="", tagFolderPath:string="", blockGroupPath:string="", compileAfter:boolean=true, dryRun:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| PlugDeviceItem | Hardware / IO / network | req: deviceItemPath:string, orderNumber:string; opt: version:string="", positionNumber:integer=-1, name:string="", dryRun:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| ProbeGlobalLibrary | HMI | req: libraryPath:string; opt: maxItems:integer=500 | Solo schema | R1 | MCP conocido / Openness desconocido |
| ProbeHardwareHmiConnectionOwnerCandidates | Hardware / IO / network | req: plcRootPath:string, hmiRootPath:string; opt: deepScan:boolean=true | Solo schema | R1 | MCP conocido / Openness desconocido |
| ProbeHardwareHmiConnectionWhitelistedServices | Hardware / IO / network | req: plcRootPath:string, hmiRootPath:string; opt: deepScan:boolean=true | Solo schema | R1 | MCP conocido / Openness desconocido |
| ProbePlcMonitorOnlineCapabilities | PLC online / watch / monitor | req: softwarePath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ProbeS7CpuIdentity | PLC online / watch / monitor | req: ip:string; opt: rack:integer=0, slot:integer=1 | Solo schema | R3 | MCP conocido / Openness desconocido |
| ReadPlcLiveValuesOpcUa | PLC online / watch / monitor | req: endpointUrl:string, nodeIdsJson:string; opt: timeoutMs:integer=5000 | Solo schema | R3 | MCP conocido / Openness desconocido |
| ReadPlcLiveValuesS7 | PLC online / watch / monitor | req: ip:string, itemsJson:string; opt: rack:integer=0, slot:integer=1, expectModuleContains:string="", devicePath:string="" | Solo schema | R3 | MCP conocido / Openness desconocido |
| ReadPlcWatchTableCurrentValuesReadOnly | PLC online / watch / monitor | req: softwarePath:string, watchTableName:string; opt: maxEntries:integer=50 | Solo schema | R3 | MCP conocido / Openness desconocido |
| RebuildReleaseHandoffArtifacts | Reports / release metadata | req: offlineReleaseSuiteJsonPath:string, outputDirectory:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| RepairAndReimportBlock | PLC blocks / sources / import-export | req: softwarePath:string, importPath:string; opt: groupPath:string="", compileAfter:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| RunCapabilitySelfTest | Diagnostics / preflight | req: —; opt: connectIfNeeded:boolean=false, includeProjectTree:boolean=false, inspectPortalProcesses:boolean=false, expectedPlcSoftwarePath:string="PLC_1", expectedHmiSoftwarePath:string="HMI_RT_1" | Solo schema | R1 | MCP conocido / Openness desconocido |
| RunClassicHmiOfflineValidationSuite | HMI | req: reportDirectory:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| RunClassicHmiTemporaryImportPreflight | HMI | req: workspaceRoot:string, reportDirectory:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| RunHmiActionScriptRecipeSafetySelfTest | Diagnostics / preflight | req: —; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| RunHmiTemplatePlcSyncPrecheckSuite | HMI | req: templateDirectory:string, plcXmlPath:string, reportDirectory:string; opt: mappingFilePath:string="" | Solo schema | R0 | MCP conocido / Openness desconocido |
| RunOfflineReleaseValidationSuite | Other / utility | req: workspaceRoot:string, reportDirectory:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| RunOnlineMonitoringSafetySelfTest | Diagnostics / preflight | req: —; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| RunV2PlanCompletionAudit | Other / utility | req: workspaceRoot:string, reportDirectory:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| SamplePlcLiveValuesS7 | PLC online / watch / monitor | req: ip:string, itemsJson:string; opt: intervalMs:integer=100, durationMs:integer=5000, maxSamples:integer=600, rack:integer=0, slot:integer=1, expectModuleContains:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| SaveAsProject | Project / session | req: newProjectPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| SaveExport | PLC blocks / sources / import-export | req: exportId:string, outputPath:string; opt: raw:boolean=false, overwrite:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| SaveProject | Project / session | req: —; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| ScaffoldProject | Project / session | req: spec:string; opt: dryRun:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| SearchHardwareCatalog | Hardware / IO / network | req: keyword:string; opt: limit:integer=50 | Solo schema | R1 | MCP conocido / Openness desconocido |
| SearchInstalledGsdDevices | Hardware / IO / network | req: keyword:string; opt: limit:integer=50 | Solo schema | R1 | MCP conocido / Openness desconocido |
| SeedProjectFromReference | PLC software objects | req: plcSoftwarePath:string, hmiSoftwarePath:string, referenceDir:string; opt: placeholders:object[?]=null | Solo schema | R1 | MCP conocido / Openness desconocido |
| SetCpuCommonSettings | Hardware / IO / network | req: cpuPath:string, settingsJson:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| SetDeviceItemAttribute | Hardware / IO / network | req: deviceItemPath:string, attributeName:string, value:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| SetDeviceItemIoAddress | Hardware / IO / network | req: deviceItemPath:string, ioType:string, startAddress:integer; opt: dryRun:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| SetOpcUaInterfaceEnabled | PLC communications / OPC UA | req: softwarePath:string, interfaceName:string, enabled:boolean; opt: interfaceType:string="ServerInterface" | Solo schema | R2 | MCP conocido / Openness desconocido |
| SetPutGetAccess | Hardware / IO / network | req: devicePath:string; opt: enable:boolean=true | Solo schema | R2 | MCP conocido / Openness desconocido |
| SetUnifiedHmiButtonEventScriptCode | HMI | req: hmiSoftwarePath:string, screenName:string, buttonName:string, eventType:string, scriptCode:string; opt: globalDefinitionAreaScriptCode:string="", async:boolean=false, syntaxCheck:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| SetWatchTableModifyValue | PLC online / watch / monitor | req: softwarePath:string, tableName:string, address:string, modifyValue:string; opt: trigger:string="Permanent" | Solo schema | R4 | MCP conocido / Openness desconocido |
| SyncVersionControlWorkspace | Library / version control | req: —; opt: direction:string="ProjectToWorkspace", workspaceName:string="", dryRun:boolean=true, changedOnly:boolean=true | Solo schema | R0 | MCP conocido / Openness desconocido |
| TraceTagCause | PLC online / watch / monitor | req: softwarePath:string, tag:string; opt: blockScope:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| TraceTagCauseLive | PLC online / watch / monitor | req: softwarePath:string, tag:string, ip:string; opt: rack:integer=0, slot:integer=1, blockScope:string="", expectModuleContains:string="" | Solo schema | R0 | MCP conocido / Openness desconocido |
| ValidateAutomationContext | Diagnostics / preflight | req: —; opt: expectedPlcSoftwarePath:string="PLC_1", expectedHmiSoftwarePath:string="HMI_RT_1" | Solo schema | R1 | MCP conocido / Openness desconocido |
| ValidateClassicHmiMinimalPackageFiles | HMI | req: path:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| ValidateClassicHmiMinimalPackagePlcSync | HMI | req: path:string, plcSymbolsJson:string; opt: — | Solo schema | R0 | MCP conocido / Openness desconocido |
| WriteClassicHmiMinimalPackageFiles | HMI | req: packageJson:string, outputDirectory:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| WritePlcSclSourceFile | PLC blocks / sources / import-export | req: sclContent:string; opt: outputPath:string="" | Solo schema | R2 | MCP conocido / Openness desconocido |

**Bridge de perfil:** CallTool declara que puede invocar cualquier nombre del roster completo aunque no figure en la lista visible. La fila CallTool es R4 por alcance dinámico; no se agregan herramientas ocultas a este inventario ni se infiere su disponibilidad desde otro perfil. FindTools debe proporcionar el nombre y firma antes de considerar una llamada.

**Reflection:** InvokeService e InvokeObject son bridges genéricos a métodos Openness; se clasifican R4 porque el efecto depende del método y target elegidos y no hay mapeo validado por acción en la evidencia revisada.

### Computer Use y superficie gráfica

| Superficie | Estado observado | Evidencia y límite |
|---|---|---|
| Computer Use nativo / ventanas Windows | **Disponible en esta sesión** por plugin `computer-use`, `node_repl` y `@oai/sky`. La llamada `mcp__cua_repl` no mide esta superficie. | `sky.list_apps/list_windows` encontró una única ventana TIA V20 targetable. En el clon PLC se editó `PLC_1/Program blocks/FB_AgentDemo`, se compiló con 0 errores/0 advertencias, se guardó, se cerró y se reabrió para leer el SCL. En el clon HMI se inspeccionaron `HMI_1 [TP1200 Comfort]`, `Screens/Grundbild`, `Connections` y `HMI tags`. No se descargó ni se tocó un original, F-block o bloque protegido. [PLC](../../../70-runs/environment/computer-use-20260922-tia-gui-edit.json), [HMI/runtimes](../../../70-runs/environment/computer-use-20260922-native-runtime-hmi.json). |
| Captura previa de línea base | `nativeApps: []`, `nativeControlAvailable: false`. | [baseline.json](../../../70-runs/tia-capabilities/20260921-01-baseline/baseline.json) registra `cua.getState` a las 09:27 del 21/09/2026: solo evidencia de esa superficie browser, no un inventario nativo Windows. Se conserva como captura histórica no concluyente para Computer Use nativo. |

### Ejecución real en fixture — 2026-09-21

El roster anterior sigue siendo una instantánea de **schema**; esta tabla independiente marca solo
las llamadas y operaciones observadas en `90-tmp/e2e/20260921-iot2050-agent-probe-clean/`.

| Acción | Perfil MCP / superficie | Estado observado | Evidencia / límite |
|---|---|---|---|
| Doctor, Connect, OpenProject, GetProjectTree, GetSoftwareTree, GetBlocks, GetTags, CompileSoftware | `tia-inspect / read` | **Fixture: ejecutado** | [preflight](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/01-prewrite-preflight.json), [readback](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/18-independent-readback.json). Rutas leídas del árbol. |
| `PlcBuildAndImport` preview | `tia-create / lite` | **Preview: aprobado** | [preview](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/03-create-probe-preview.json). |
| `PlcBuildAndImport` apply | `tia-create / lite` | **Falló sin importación** | La cultura `zh-CN` no estaba instalada en el proyecto `en-US`; no reintentar sin corregir causa. [resultado](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/06-create-compile-save.json). |
| `WritePlcSclSourceFile`, `ImportPlcExternalSource`, `GenerateBlocksFromExternalSource` | `tia-create / lite`, métodos descubiertos con `FindTools` y llamados por `CallTool` | **Fixture: ejecutado** | Creación de `FB_AgentProbe_20260921`; el paso de grupo inexistente fue `NotFound` y no mutó. Importación desde raíz, generación, compile 0/0 y `SaveProject`: [secuencia](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/16-import-external-source-root.json), [generación/compilación](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/17-generate-compile-save.json). Es una ruta separada del intento `PlcBuildAndImport` fallido descrito arriba. |
| `GetBlockSource`, `GetBlocks`, lectura de tags y compile | `tia-inspect / read` | **Fixture: ejecutado** | Readback independiente: `isFailsafe=false`, SCL, consistente, sin protección, compile 0/0: [JSON/XML](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/18-independent-readback.json). |
| `FindTools` + `CallTool(GetDeviceIpAddress)` | `tia-create / lite` | **Fixture: lectura ejecutada** | La herramienta oculta se descubrió y llamó con `devicePath=PLC_1`, obtenido del árbol. `Data.ipAddress=192.168.200.20`, ocho nodos Ethernet; sesión desconectada: [secuencia](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/artifacts/32-device-ip-read.json). |
| `ExportBlock` | `tia-create / lite`, vía descubrimiento/bridge | **Fixture: ejecutado** | XML generado como fallback de inspección: [export](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/artifacts/FB_AgentProbe_20260921.export.xml/FB_AgentProbe_20260921.xml). |
| `ExportAsDocuments` | `tia-create / lite`, vía `FindTools`/`CallTool` | **Error tipado; no repetido** | Siemens/TIA devolvió `EngineeringNotSupportedException` sobre bloques de lenguajes mixtos. El nivel local de Update no quedó registrado. [resultado](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/artifacts/23-create-export-delete-preview.json). |
| `DeletePlcBlock` preview y apply del probe | `tia-create / lite`, vía descubrimiento/bridge | **Fixture: ejecutado** | Preview de ruta exacta y referencias; delete aplicado; compile 0/0, guardado y ausencia confirmada independientemente: [preview](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/artifacts/24-create-export-xml-delete-preview.json), [aplicación](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/artifacts/26-create-delete-compile-save.json), [readback](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/artifacts/27-independent-delete-readback.json). |
| Restauración del proyecto | Operación de archivos, fuera de TIA | **Hash verificado** | 31 archivos, sin extras/faltantes/mismatches; hash del `.ap20` coincide con original/backup: [reporte](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/artifacts/28-restore-report.json). |
| `Invoke-TiaSimulationAcceptance` guardas | Pruebas locales con servidores/adaptadores MCP simulados | **Mocks: aprobados; PLCSIM real: no ejecutado** | `Test-InvokeTiaSimulationAcceptance.ps1` y `Test-TiaSimulationAcceptanceSafety.ps1` cubren gates, plan funcional, compilación, IP y ruta inequívoca. No son evidencia de descarga ni de comportamiento PLC. |
| `RunOfflineReleaseValidationSuite` | `tia-create / lite`, descubierto con `FindTools` y ejecutado mediante `CallTool` | **Bloqueado por precondición; no es un PASS funcional** | Es offline-only y no hubo `Connect` ni `OpenProject`. El transporte MCP terminó, pero el JSON interno devolvió `meta.success=false` por falta de `TMP_EXPORT\_verify\UDT_Fault.xml`; el preflight enumera 5/5 golden PLC ausentes y `docs\hmi_templates` ausente. No se fabrican XML ni se copian ejemplos para satisfacerlo. Evidencia: [preflight](../../../70-runs/tia-capabilities/20260922-offline-release-preflight-final.json), [primer intento](../../../70-runs/tia-capabilities/20260922-offline-release-validation.json), [reproducción](../../../70-runs/tia-capabilities/20260922-offline-release-repro.json). |
| Builders PLC/HMI y manifiesto de símbolos offline | `tia-create / full` mediante `FindTools` + `CallTool` | **Verificado offline; importación V20 no verificada** | UDT, DB global, tabla de tags, FC/FB SCL, paquete HMI Classic y extracción de símbolos generaron XML/paquetes parseables sin conectar TIA. Las salidas PLC declaran V21 y Classic V18; no se elevan a fixture V20. Evidencia: [informe](../../../70-runs/tia-capabilities/20260922-noncu-family-offline-builders.md), [UDT](../../../70-runs/tia-capabilities/20260922-noncu-family-udt-rerun.json), [símbolos](../../../70-runs/tia-capabilities/20260922-noncu-family-symbol-manifest-clean.json). |

### Ejecución gráfica controlada — 2026-09-22

| Acción | Superficie | Estado observado | Evidencia / límite |
|---|---|---|---|
| Abrir, editar, compilar, guardar y leer de nuevo un bloque SCL | TIA Portal V20 / clon `AgentDemo_V20` | **Verificado en clon desechable** | Se añadió solo el comentario `// Computer Use visual probe 2026-09-22` en `PLC_1/Program blocks/FB_AgentDemo`; Compile mostró 0 errores y 0 advertencias, el guardado fue confirmado por TIA y la reapertura mostró el texto. El original quedó preservado. [evidencia](../../../70-runs/environment/computer-use-20260922-tia-gui-edit.json) |
| Abrir, editar y leer de nuevo un HMI Comfort | TIA Portal V20 / clon GamesCollection | **Verificado en clon desechable; compile/runtime pendientes** | `HMI_1 [TP1200 Comfort]`, `Screens/Grundbild`, `Connections` y `HMI tags` se observaron; se creó el objeto `Computer Use HMI probe 2026-09-22`, se guardó, se cerró/reabrió y se leyó visualmente. La tabla de conexiones no tenía PLC configurado. [inspección](../../../70-runs/environment/computer-use-20260922-native-runtime-hmi.json) · [edición](../../../70-runs/environment/computer-use-20260922-hmi-edit.json) |
| Inspeccionar PLCSIM Advanced | `S7-PLCSIM Advanced V6.0 Upd1` | **Disponibilidad verificada; comportamiento no verificado** | La interfaz mostró acceso `PLCSIM`, familia S7-1500 y ninguna instancia activa. No se creó instancia, no se descargó y no se ejecutó una prueba de ciclo. [evidencia](../../../70-runs/environment/computer-use-20260922-native-runtime-hmi.json) |
| Inspeccionar runtime HMI instalado | `SIMATIC Runtime Manager` | **Bloqueado para Runtime Advanced V20** | La aplicación observada es el Runtime Manager de WinCC Unified, con servidor `localhost`, lista vacía y error general; no es una prueba de Runtime Advanced. [evidencia](../../../70-runs/environment/computer-use-20260922-native-runtime-hmi.json) |

#### API Openness y Computer Use

| Superficie | Capacidad conocida | Evidencia local de acción | Estado |
|---|---|---|---|
| Siemens Openness V20 | Siemens documenta leer, crear, modificar, borrar, compilar, importar/exportar y diagnosticar ciertos objetos; depende de versión/tipo/modelo. | Probe independiente `.NET Framework 4.8/x64`: `Api.Global.Openness().Initialize(20)`, grupo Openness, carga de `Siemens.Engineering 20.0.0.0` y `TiaPortal.GetProcesses()` en solo lectura; no Attach/OpenProject/escritura. [evidencia](../../../70-runs/environment/direct-openness-20260922-final.json) | **Fixture read-only** para inicialización/enum. El mapeo acción a acción MCP → miembro Openness sigue sin probar. |
| `tia-inspect / read` | Inspección y lectura; el roster live actual publica 53 schemas. | Doctor, tree, tags, blocks, source, compile, readback. | **Fixture** solo para las acciones enumeradas arriba; el resto sigue en **Schema**. |
| `tia-inspect / write` | Snapshot aislado `--allow-write` actual, 84 schemas; la política exige fixture manifest. | No se usó este perfil para escribir en esta secuencia. | **Schema**; no atribuirle el write ejecutado vía `tia-create`. |
| `tia-create / lite` | Snapshot de 55 schemas y búsqueda dinámica con `FindTools`/`CallTool`. | Preview/importación alternativa/export/delete de probe y compile/save en la secuencia documentada. `PlcBuildAndImport` apply falló por cultura. | **Fixture** por las acciones enumeradas, no por todo el perfil. |
| `tia-create / full` | Snapshot de 222 schemas. | `Bootstrap → RunCapabilitySelfTest(connectIfNeeded=false) → Disconnect` terminó correctamente; además, `RunOnlineMonitoringSafetySelfTest` y `RunHmiActionScriptRecipeSafetySelfTest` pasaron offline sin abrir proyecto. La auditoría final verificó también los planificadores de hardware/red y monitorización read-only. [evidencia lite](../../../70-runs/tia-capabilities/20260922-create-lite-selftest.json), [evidencia full](../../../70-runs/tia-capabilities/20260922-create-full-selftest.json), [lote offline](../../../70-runs/tia-capabilities/20260922-offline-safe-tools-batch.md), [auditoría final](../../../70-runs/tia-capabilities/20260922-final-noncu-hardware-comms-analog-audit.json). | **Smoke/offline safety** para esas llamadas; el resto sigue en **Schema**. |
| Computer Use nativo | Puede inspeccionar y navegar la ventana TIA si el plugin nativo y el permiso para esa aplicación están activos. | En esta sesión se abrieron dos clones, se editó/compiló/guardó/leyó de nuevo un bloque SCL y se creó/guardó/leyó de nuevo un objeto de texto HMI. `cua_repl.apps=[]` no era un dato del inventario Windows. | **UI y ediciones gráficas verificadas en clones**; compile HMI, runtime HMI y comunicación desde GUI siguen sin probar. |

### Límites y acciones siguientes

- El perfil `tia-create / lite` no fue usado para todos sus métodos; `full` solo ejecutó el lote offline y el self-test, sin abrir proyecto.
- No se probaron modificación de hardware, red/protocolos, escritura independiente de tags/UDT/DB,
  binding HMI, alarmas, mediciones físicas, watch/force, descarga, comportamiento PLC en PLCSIM,
  Runtime ni escritura online. La interfaz de edición SCL y la edición visual de un objeto HMI ya
  están verificadas en clones; el compile HMI y el runtime siguen sin verificar. La auditoría final
  también verificó sin conexión las guardas de hardware/red y la planificación read-only de
  monitorización/OPC UA; la tabla de tags del scaffold fue exportada, normalizada y leída de vuelta
  como evidencia de inventario.
- La línea base y el test de fixture acreditan `GetBlocks.isFailsafe=false` antes/después del probe.
  Los tests de barrera acreditan rechazo sintético de safety o metadata incompleta; no se hizo una
  escritura real F ni se usó una F-CPU.
- Algunas configuraciones (por ejemplo `SetPutGetAccess` e interfaces OPC UA) no surtirán efecto en
  una CPU hasta descarga; descarga es otra acción y requiere target virtual confirmado o permiso actual
  para hardware físico.
- Openness directo: la inicialización V20 y la enumeración read-only de procesos ya están verificadas
  en una aplicación .NET independiente; todavía no se mapeó cada MCP tool a un miembro concreto de
  `Siemens.Engineering` ni se probó CRUD de proyecto desde ese cliente.
- El informe global de aceptación permanece `accepted=false`; PLCSIM/Runtime siguen pendientes o
  bloqueados. Consultar [status-20260922-final11.json](../../../70-runs/acceptance/status-20260922-final11.json)
  para el estado actual y volver a generarlo después de cada cambio relevante.
- La suite `RunOfflineReleaseValidationSuite` es una validación de release separada del workspace
  TIA-Claude. Antes de llamarla, ejecutar [R21](../../../10-kb/20-recetas/R21-preflight-offline-release.md)
  y exigir `readyForCall=true`. El preflight actual ([evidencia](../../../70-runs/tia-capabilities/20260922-offline-release-preflight-final.json)) es `BLOCKED`: faltan `TMP_EXPORT/_verify` con
  cinco golden XML y `docs/hmi_templates`; el servidor upstream tampoco incluye esos fixtures en el
  checkout clonado. No se deben inventar muestras ni elevar un éxito de transporte MCP a PASS funcional.

### Orden recomendado desde este punto

El trabajo que no necesita Computer Use debe cerrarse primero y conservar su evidencia fechada:

1. confirmar con el propietario la revocación/rotación de la credencial histórica y registrar el
   comprobante sin copiar el secreto;
2. repetir, si cambia el binario o el harness, `Doctor`, `tools/list`, `FindTools` y la sesión
   aislada read; completar el probe directo de Openness solo de lectura si se necesita distinguir
   la API .NET del wrapper MCP;
3. completar únicamente en fixtures las familias que tengan precondiciones reales: tags/UDT/DB,
   hardware/E/S, redes/comunicaciones, medidas analógicas y compilación HMI. Si falta catálogo,
   licencia, runtime o una clasificación segura, registrar `Bloqueado` y no improvisar una
   importación;
4. actualizar matriz, recetas, paquete y `Write-TiaAcceptanceStatus.ps1` con cada evidencia.

La fase Computer Use agrupada ya se ejecutó para el alcance disponible: se enumeraron las ventanas,
se identificaron dos clones, se hizo la edición PLC con compile/save/readback, se editó un objeto de
texto HMI con save/close/reopen/readback visual y se abrieron/cerraron PLCSIM Advanced y Runtime
Manager sin crear instancias ni descargar. TIA Portal quedó maximizado al finalizar. El siguiente
paso solo puede ser una fase separada de runtime/PLCSIM cuando haya un
fixture con CPU coincidente, instancia virtual desechable, adaptador e IP validados y un Runtime
Advanced V20 compatible. No se mezcla esa fase con una descarga o conexión física.

**Lectura segura:** usar las filas para decidir qué buscar y en qué perfil. Antes de llamar a una acción mutante, aplicar el contrato de [AGENTS.md](../../../AGENTS.md), obtener rutas de la instancia objetivo, preflight safety/protection, backup, preview, compilación y readback en fixture; la tabla no es autorización de llamada.
