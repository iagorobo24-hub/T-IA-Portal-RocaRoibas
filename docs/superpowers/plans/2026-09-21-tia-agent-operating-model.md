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

## Estado de continuación — 2026-09-28

Handoff resumido y orden de continuación: [2026-09-28](../handoffs/2026-09-28-tia-agent-operating-model-handoff.md).

El trabajo local previo de remediación/paquete y el runner de simulación están disponibles en el
árbol actual. La comprobación guardada del workspace terminó con 47 PASS, 2 WARN y 0 BLOCKED
([evidencia](../../../70-runs/checks/20260928-objective-resume.json)); eso cubre checks locales, no
aceptación conductual live.

En la fixture nueva
`70-runs/e2e/20260928-objective-resume-acceptance-supported/isolated-fixture/`, el manifiesto y el
backup coinciden. Una preflight live completó `OpenProject → GetProjectTree → GetSoftwareTree →
GetDeviceIpAddress → CompileSoftware → GetBlocks → GetTags → CheckDownloadReadiness → Disconnect`.
Leyó compilación `Success` con 0 errores/0 avisos; `Main` y `FB_AgentDemo` estándar, no protegidos,
consistentes y con `PLCSimAdvancedSupport=true`; dos tags completos y no Safety; IP
`192.168.0.1`; y una ruta exacta `PLCSIM`. La CPU virtual Advanced V7 arrancó en Softbus durante el
runner.

La secuencia se interrumpió antes de producir un informe final. No hay respuesta guardada de
`DownloadToPlc`, lectura `Online`, plan conductual ni limpieza confirmada para ese intento. No
presentar la preflight como aceptación. Antes de repetir, recuperar el estado del runner/instancia y
obtener confirmación visual de TIA para el target simulado según R17. El runner ahora exige el JSON
de `-SimulationTargetEvidencePath` ligado al mismo proyecto/dispositivo/IP/ruta y reciente; su
esquema y bloqueo cruzado ya tienen cobertura mock, pero todavía no hay un artefacto generado desde
una observación live ni una descarga. El estado global sigue `accepted=false`.

La inspección gráfica previa de `Load preview` encontró un fallo que el `CompileSoftware` MCP 0/0
no cubría: compilación de hardware con 3 errores/1 aviso. El error visible pide una contraseña para
configurar el certificado de comunicación PLC. El usuario confirma que las fixtures no deben tener
contraseñas. Ese mensaje no demuestra que haya una clave guardada: Siemens distingue el estado
`WithoutPassword` (protección marcada, sin Master Secret configurado). No pedir ni generar una clave.
En esa primera revisión todavía no existía un wrapper MCP acotado; la actualización de abajo registra
su implementación y lo que falta para probarlo live. `Load` permaneció deshabilitado y no hubo
descarga. Véase el handoff del 2026-09-28.

La API Openness V20 expone `PlcMasterSecretConfigurator`: cuando
`MasterSecretConfiguration=WithoutPassword`, `Unprotect()` sin argumento desactiva la opción y el
readback esperado es `None`. Siemens advierte que `Reset` elimina configuración y certificados;
no se usa. La implementación local no invoca reflection genérica y está restringida al perfil
aislado con manifiesto de fixture.

Para no depender del documento abierto, se regeneró una fixture limpia desde su backup verificado en
`70-runs/e2e/20260928-objective-resume-hardware-compile/isolated-fixture/`; el clon y el backup
coinciden y `Assert-TiaFixtureManifest.ps1` pasó con hash
`00d108f3ef9b10de26788fb348b5020268828457bda7922b68262fb6f176c814`. Sigue sin abrir ni modificar
en TIA. Esta preparación deja lista la fase gráfica; no cuenta como compilación ni como descarga.
La reobservación nativa posterior devolvió TIA V20 minimizado y título genérico; activar la ventana
fue interrumpido por detección de actividad del usuario. No se confirmó el proyecto/diálogo ni se
envió otra acción; volver a identificar la ventana antes de continuar.

La elección para acelerar Computer Use queda documentada en
[`tia-interfaz-y-computer-use.md`](../../../10-kb/00-fundamentos/tia-interfaz-y-computer-use.md):
Playwright es para una UI web, no TIA Portal Desktop; Windows UI Automation es candidato para flujos
repetibles si TIA V20 publica controles semánticos adecuados. Se añadió
`30-tools/scripts/Get-TiaUiAutomationInventory.ps1` para capturar selectores de una ventana en solo
lectura; su sintaxis se comprobó, pero no se ha ejecutado sobre una ventana ni acepta acciones UIA.
La guía y la matriz reflejan explícitamente esa limitación.

### Actualización de continuación — 2026-09-28

- Se implementó `DisableUnconfiguredPlcConfigurationProtection` en el `tia-inspect` local V20 y en
  el parche canónico del upstream. Solo admite `WithoutPassword`, llama `Unprotect()` sin clave,
  exige readback `None`, y rechaza `WithPassword` o estados desconocidos. La barrera `Guarded`
  mantiene el requisito de fixture/manifiesto, transacción exclusiva y barrido global F/Safety.
- El build limpio V20 completó con 0 errores y 2 warnings nullable en `McpPrompts.cs` y
  `Portal.Documents.cs`; `Doctor` devolvió V20 activo, Openness=true, desconectado y sin proyecto.
  Evidencia: [build log](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/tia-inspect-v20-clean-build.log).
- `tools/list` del perfil `--isolated --fixture-root ... --allow-write` devolvió 85 herramientas e
  incluyó el esquema nuevo. El perfil aislado de lectura enumeró 53 y excluyó la mutación. [Resumen
  de ambos perfiles](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/isolated-fixture/write-tool-registration-evidence.json)
  y [roster completo](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/isolated-fixture/write-tools-list-after-clean-build.json).
- La fixture `20260928-objective-resume-hardware-compile` volvió a pasar el validador; hash clon y
  backup `00d108f3ef9b10de26788fb348b5020268828457bda7922b68262fb6f176c814`. La evidencia de
  manifiesto está en
  [manifest-validation.json](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/isolated-fixture/manifest-validation.json).
- La fixture se abrió en `tia-inspect --isolated`. `GetProjectTree` confirmó el CPU path
  `PLC_1/PLC_1`; `GetBlocks` leyó 2 bloques coherentes, no F y sin know-how; `GetTags` leyó 2 tags,
  ambos no Safety. La herramienta nueva devolvió `WithoutPassword → None`; una segunda llamada
  leyó `None → None` sin cambio. `CompileSoftware` dio 0 errores y 0 warnings. Cerré el proyecto sin
  `SaveProject`, porque la compilación hardware aún no está verificada; clon y backup siguen
  idénticos al hash del manifiesto. [Lecturas y preflight](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/read-preflight-metadata.json)
  y [ejecución live de la herramienta](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/plc-configuration-protection-live-evidence.json).
  `GetDeviceItemInfo` devolvió un error genérico en esa fixture; no se usó para inferir ni para
  autorizar la operación.
- La fixture anterior `20260928-objective-resume` falló el validador de manifiesto y quedó descartada;
  no se usó para escribir.
- Computer Use identificó TIA Portal V20, mostró `Project closed` y se dejó maximizado. La captura
  siguiente se interrumpió por Escape al leer los controles; no se abrió un proyecto por GUI ni se
  intentó compilar hardware, simular o descargar. `accepted=false` sigue siendo el estado correcto.
- La distribución portable se reconstruyó después de preservar íntegra la anterior en
  `90-tmp/portable-dist-pre-20260928-objective-resume`. El hash del servidor en `dist` coincide con
  el build local (`EB3D5F3B...1678E41A`); pasaron `Test-PortablePackage.ps1`,
  `Test-PortablePackageContent.ps1` y `Test-PortableInstallRelocation.ps1`. Evidencias: [build](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/portable-build-20260928.log),
  [manifiestos de dist](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/portable-dist-manifest-test-20260928.log),
  [contenido](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/portable-content-test-20260928.log)
  e [instalación/relocación](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/portable-install-relocation-20260928.log).
- `Test-DocumentationState.ps1` pasó tras actualizar el plan y el handoff; `git diff --check` no
  encontró errores (solo avisos de normalización LF/CRLF). [Evidencia](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/documentation-state-test-20260928.log).

**Siguiente acción:** al reanudarse Computer Use, verificar que TIA sigue maximizado y sin proyecto;
revalidar el manifiesto `objective-resume-hardware-compile` y abrir solo esa fixture. Repetir la
operación aislada, compilar software, guardar el cambio en el clon y compilar la configuración
hardware desde TIA. Si hardware compila sin errores/avisos, capturar el resultado y restaurar el
clon desde el backup; si falla, guardar los diagnósticos y restaurar. No descargar ni iniciar
PLCSIM hasta resolver la aceptación R17.

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
| tia-inspect read/write actuales | La captura live histórica registró read **53** y write aislado **84**; el roster V20 reconstruido el 2026-09-28 registra **85** herramientas tras añadir `DisableUnconfiguredPlcConfigurationProtection`. [Roster y esquema actuales](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/isolated-fixture/write-tool-registration-evidence.json). `ImportSources` y `ImportFromDocuments` siguen ausentes del perfil write probado. | Los conteos son enumeraciones `tools/list`; la nueva protección también tiene evidencia de ejecución en fixture. Write sigue limitado a fixture/manifiesto. |
| tia-create lite actual | Captura live **55** tools; incluye `FindTools` y `CallTool`. [JSON](../../../70-runs/tia-capabilities/20260921-06-create-lite-tools-live.json). | Roster/schema sin proyecto; enumera herramientas, no acredita que cada acción se haya ejecutado ni que sea segura en cualquier target. |
| tia-create full actual | Captura live **222** tools; incluye `DownloadToPlc` y los self-tests `RunHmiActionScriptRecipeSafetySelfTest` y `RunOnlineMonitoringSafetySelfTest`. [JSON](../../../70-runs/tia-capabilities/20260921-07-create-full-tools-live.json). El 24/09/2026 se repitieron Doctor + `tools/list`: V20/Openness listos, no conectado, roster idéntico (222 schemas; huella del array `98ac0aaf09b0d18eb1a20af9ac123601164ea84d435eaa15b5d8254e757ef3a4`) en [secuencia](../../../70-runs/tia-capabilities/20260924-doctor-create-full-readonly.json). | Roster/schema solamente para `DownloadToPlc`; los dos self-tests sí se ejecutaron después en el lote offline, sin proyecto conectado ni mutación ([evidencia](../../../70-runs/tia-capabilities/20260922-offline-safe-tools-batch.md)). La presencia del resto no autoriza su uso. Computer Use observó TIA V20 maximizado en el selector «Abrir proyecto», sin proyecto abierto identificable; no se conectó ni se lanzó otra instancia. |
| Openness Siemens V20 | Base de automatización que usan TIA y las herramientas locales; el probe independiente [direct-openness-20260922-final.json](../../../70-runs/environment/direct-openness-20260922-final.json) inicializó el resolver V20 desde un proyecto .NET Framework separado, comprobó el grupo y ejecutó `TiaPortal.GetProcesses()` en solo lectura. | El probe no adjuntó ni abrió proyecto y no valida todavía cada acción del API ni las operaciones de proyecto. |
| Computer Use/UI | Nativo disponible en esta sesión por `node_repl` + `@oai/sky`; `mcp__cua_repl` solo expone navegador y su `apps: []` no mide Windows. TIA V20 se abrió con los clones exactos de los fixtures, se mantuvo maximizado (1920×1040) y se navegó visualmente al PLC y al HMI. | La edición PLC y la edición visual HMI quedan verificadas solo en clones; el compile HMI se intentó y quedó bloqueado con 1 error porque TIA reportó el dispositivo no soportado; el runtime sigue sin evidencia. El acceso depende de la sesión, el permiso de la app y políticas de workspace. |
| PLC fixture | En un clon IOT2050 aislado, el preview de `PlcBuildAndImport` pasó pero su apply falló por cultura, sin importación y con integridad confirmada. En una secuencia separada, el import de fuente SCL generó un bloque probe, compiló 0/0, guardó, exportó, se releyó y luego se borró/restauró el clon. Evidencia bajo `90-tmp/e2e/20260921-iot2050-agent-probe-clean/`. | La ruta de fuente externa no demuestra `Invoke-TiaSclProposalApply`; tampoco valida acciones ajenas a la secuencia ni comportamiento PLCSIM/HMI. La instancia original no se modificó. |
| Runtime | [status-20260922-final14.json](../../../70-runs/acceptance/status-20260922-final14.json) y `status-latest.json` mantienen `accepted=false`; el scaffold live, el ciclo de tags y la fase gráfica de clones están verificados, mientras PLCSIM y Runtime Advanced V20 siguen pendientes/bloqueados. El JSON incorpora el bloque `computerUse` y la evidencia del ciclo MCP de tags. | El informe de aceptación separa compilación/mocks de comportamiento real; no autoriza descarga ni runtime. |

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
  `allowWrite=false`. Esa captura histórica no llevaba `--fixture-root` y no se considera aceptación
  conforme al contrato actual. La prueba corregida del 24/09/2026 usó una raíz con manifiesto exacto,
  confirmó `project="-"` y preservó el hash de copia y backup antes/después ([informe](../../../70-runs/environment/20260924-isolated-read-acceptance.json),
  [secuencia MCP](../../../70-runs/environment/20260924-isolated-read-sequence.json)).
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
| PLC blocks y tipos | ImportBlock/ImportFromDocuments, CreateFB/CreateInstanceDB, DeletePlcBlock/DeletePlcType, export, compile, readback | Siemens V20 documenta import/export y creación/borrado de objetos de proyecto. Revisar diferencias por tipo/versión. | La ruta experimental de fuente externa sigue acotada al clon IOT2050. En el fixture `AgentDemo_V20`, `CreateFB` aparece en el roster write (84 herramientas) pero falla con `CreateFB failed` para SCL y LAD, tanto en raíz como en grupos; el `.ap20` conserva el hash de backup. Computer Use sí creó FC1 y FB2, los guardó, leyó de nuevo y borró en otro clon; además compiló `CU_Compile_Probe [FB2]` en LAD con 0/0. El lenguaje del FB inicial no quedó probado como SCL. Se verificó la ruta profesional de `CreateInstanceDB` para un FB SCL estándar con número explícito libre: creación, consistencia tras compile 0/0, exportación, guardado, referencias, borrado, segundo compile/save, lectura independiente y restauración de hash en [mcp-instancedb-acceptance-20260923.json](../../../70-runs/e2e/mcp-instancedb-acceptance-20260923.json). `autoNumber=true` con `number=0` produjo DB0 inválida y queda bloqueado hasta corregir/probar el wrapper. |
| Tags, UDT, DB, tablas y watch | GetPlcTagTables/GetTags, import/export de tags/UDT/DB, watch/force discovery y SetWatchTableModifyValue | Tags PLC, constantes y objetos HMI import/export según modelo. Force/write online implica riesgo físico. UI para tabla/force sólo lectura en este plan. | El scaffold `AgentDemo_V20` creó `Agent_Signals` con dos tags y la inspección posterior exportó la tabla. Se verificó el ciclo estándar de tags (`CreateTag` → `GetTagInfo/GetTags` → `UpdateTag` → `ExportTagTable` → compile 0/0 → `SaveProject` → `DeleteTag` → readback independiente). También se verificó en otro clon el ciclo offline de tabla Watch vacía (`CreateWatchTable` → `GetWatchTables/GetWatchTableInfo` → `ExportWatchTable` → compile 0/0 → `SaveProject` → `DeleteWatchTable` → compile/save → segunda sesión sin residuos → restauración de hash), en [mcp-watch-acceptance-20260922.json](../../../70-runs/e2e/mcp-watch-acceptance-20260922.json). La Instance DB estándar, las tablas de tags y un UDT raíz sencillo V20 quedan cubiertos por sus aceptaciones enlazadas; sigue sin probarse DB global, UDT anidados/referenciados, constantes de usuario, otros tipos de tags y operaciones online. El apply bloquea tags Safety o clasificación incompleta. |
| Hardware e IO | SearchHardwareCatalog, AddDevice/PlugDeviceItem, direcciones IO, CPU settings, compilación | Openness documenta dispositivos, CAx, subredes e IO con requisitos por objeto/modelo. UI revisa Devices & Networks y modelo exacto. | Esquemas catalogados; mutaciones en copia pendientes; no hay descarga física. |
| Redes y comunicaciones | PROFINET/subnet/node, OPC UA, MQTT, HMI connections, diagnostics; usar FindTools si falta nombre en lite | La presencia de un objeto connection no demuestra tráfico ni autenticación. Runtime requiere endpoint de test; certificados/detalles pueden requerir UI. | Receta R19 documentada tras auditoría; no hubo mutación de comunicación ni handshake/tráfico real. |
| HMI | Classic/Basic/Comfort/RT Advanced/Unified: screens, templates, tags, bindings, alarms, actions, scripts, dynamizations, compile | Openness soporta conjuntos de objetos según el modelo; los exports son internos y dependientes de versión. Siemens indica que Openness con UI no puede usar el editor HMI. Computer Use/runtime prueba apariencia e interacción. | Receta R20 separa las familias/modelos; no se ejecutó ni aceptó runtime HMI. Computer Use nativo disponible; falta runtime HMI compatible. |
| Analógicas y medidas | AI/AO hardware, tags, escala/diagnóstico SCL, PLC virtual | Ajuste depende de MLFB, rango/cableado y unidad física; escalado puede probarse con vectores, medida eléctrica no. UI para comparar runtime/trends. | Receta R18 documentada; no hay aceptación local hardware/runtime. |
| Compilación/diagnóstico/export/recuperación | CompileSoftware, CompileAndDiagnosePLC/HMI, diagnostics, import/export, backup/restore | Siemens describe interfaces de diagnóstico e intercambio; import/export format es interno y específico por versión. UI para warnings completos truncados. | Compile fixture histórico; hace falta evidencia actual por versión/modelo. |
| Librería y versionado | master copies, library, VCI workspace/sync | Openness modela library/project objects; verificar referencias. UI para estado de librería cuando aplique. | Schemas; no prueba local. |
| Online y simulación | GetOnlineState, GoOnline/Offline, live read, watch, CheckDownloadReadiness, DownloadToPlc | Readiness sólo verifica; Download y SetWatchTableModifyValue escriben target. UI debe demostrar instancia simulada antes de actuar. | No ejecutado. Exigir `plcsimVirtualAdapterReady=true`, instancia virtual desechable, conexión/IP hacia ella y aislamiento de rutas antes de cualquier escritura online. Target ambiguo se considera físico. |
| Computer Use | No es herramienta TIA MCP: cada sesión debe comprobar el plugin nativo `computer-use` mediante `node_repl` + `@oai/sky`, enumerar ventanas y leer estado/título antes de interactuar. `mcp__cua_repl` es solo navegador. | Útil para ventana TIA, LAD visual, editor/runtime HMI, diálogos y errores visuales. | Nativo disponible en esta sesión; TIA V20 mostró y editó clones del fixture. Se verificaron PLC SCL y HMI text/readback; el compile HMI quedó bloqueado por dispositivo no soportado. `apps: []` de la superficie browser no es evidencia de indisponibilidad nativa. |

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
la edición visual HMI en clones; el compile HMI se intentó y quedó bloqueado por soporte de
dispositivo, y el runtime sigue sin evidencia.

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

**Revalidación focalizada 2026-09-25:** `Test-TiaSclSafetyGate.ps1` y
`Test-TiaSclProposalApply.ps1` terminaron exit 0. Cubren rechazo de `isFailsafe=true`, null/ausente,
tag Safety/incompleta y validación del helper del runner; el test de apply sigue usando servidor
simulado y `.s7dcl` continúa bloqueado antes de mutar porque no hay importador live registrado.
Salida: [regresión focalizada](../../../70-runs/tia-capabilities/20260925-scl-safety-write-barrier-regression.txt).

**Recomprobación del runner — 2026-09-24:** `Test-TiaSclSafetyGate.ps1` rechazó explícitamente
`isFailsafe=true`, clasificación F ausente/nula, tags Safety y metadata incompleta. La revisión del
runner confirma que ejecuta `Assert-TiaSclBlockWritable` sobre `GetBlocks` antes de importar y vuelve
a exigir esa clasificación y el readback exacto después de importar; registra `noBlockingFindings`
como dato de propuesta no confiable. `Test-TiaSclProposalApply.ps1` pasó y comprobó además el
bloqueo sin mutación ante proyecto/fixture no autorizado, perfil y manifiesto inválidos. El perfil
live actual sigue sin publicar `ImportSources`/`ImportFromDocuments`, así que la aplicación normal
continúa cerrada antes de importar. **Verificado estáticamente y con pruebas locales; no es una
escritura F live ni aceptación funcional del apply.**

Repetición dirigida de esta sesión: `Test-TiaSclSafetyGate.ps1` y `Test-TiaSclProposalApply.ps1`
terminaron con código 0. Los negativos incluyen `isFailsafe=true`, ausente/nulo, lenguaje F, tags
Safety y metadata/inventario incompletos; el test del runner confirma preview local, claims no
confiables y bloqueos antes de conectar/escribir. No se conectó TIA ni hubo mutación en estas pruebas.
[Resumen de resultados](../../../70-runs/tia-capabilities/20260924-tia-scl-safety-revalidation.json).

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

**Revalidación 2026-09-25:** el helper actual exige `isFailsafe=false`, `programmingLanguage=SCL`,
`isKnowHowProtected=false` e `isConsistent=true`, y bloquea propiedades ausentes/nulas o idioma F.
La revisión de la ruta del runner confirma que esta barrera se repite después de `GetBlocks` antes
de importar y después de volver a leer el bloque importado. Pasaron
`Test-TiaSclSafetyGate.ps1` y `Test-TiaSclProposalApply.ps1`; el informe fechado está en
[priority-remediation-tests](../../../70-runs/tia-capabilities/20260924-priority-remediation-tests.json).
La suite CI segura actual terminó con 13 PASS, 1 WARN y 0 BLOCKED; el único aviso es que no hay
ejecuciones de evaluación en `00-meta/eval/runs` ([informe](../../../70-runs/checks/20260924-priority-ci-safe.json)).
Esto verifica la lógica local y sus regresiones, no una importación F ni una ejecución live del runner:
el perfil aislado actual sigue sin registrar el importador y no se intentó mutar TIA.

La repetición del 2026-09-25 terminó con PASS en `Test-TiaSclSafetyGate.ps1` y
`Test-TiaSclProposalApply.ps1`; no se conectó a TIA ni se mutó proyecto alguno. Véase
[revalidación P0](../../../70-runs/tia-capabilities/20260925-priority-revalidation.md).
Repetición adicional de este turno: ambas suites volvieron a pasar y se registraron hashes de los
scripts/helpers/tests probados en [revalidación SCL con hash](../../../70-runs/tia-capabilities/20260925-scl-safety-current-revalidation.json).
Esto sigue siendo regresión estática; el perfil/importador live y el roundtrip de apply permanecen
sin aceptación.

Refresco live sin conectar proyecto del perfil `tia-inspect/read` en este turno: `Doctor` confirmó
TIA V20, pertenencia al grupo Openness y `Connected=false`; `tools/list` devolvió 53 tools, entre
ellas `PreviewImport`, pero no `ImportSources` ni `ImportFromDocuments`. Por tanto, el apply SCL
real sigue correctamente bloqueado antes de mutar en este perfil. Evidencia MCP serializada:
[Doctor + tools/list](../../../70-runs/tia-capabilities/20260925-tia-inspect-read-roster-refresh.json).
Comparado con la captura de 2026-09-21, el roster conserva 53/53 nombres; la ausencia del importador
no es un cambio de perfil accidental ([diff](../../../70-runs/tia-capabilities/20260925-tia-inspect-read-roster-diff.json)).

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

**Revalidación 2026-09-24:** la fuente versionada sigue siendo JSON parseable, el nodo MindConnect
contiene `privatekey` vacío y `agentconfig.content` usa solo el marcador de configuración local. El
escaneo actual devuelve cero hallazgos en `50-examples/` y `TIA-Claude_Portable/dist/`; ambos flujos
coinciden en SHA-256. También pasaron `Test-TiaExampleSecrets.ps1` y
`Test-PortablePackageContent.ps1` ([evidencia](../../../70-runs/tia-capabilities/20260924-priority-remediation-tests.json),
[scan y hashes](../../../70-runs/tia-capabilities/20260924-priority-secret-recheck.json)). La ficha del
ejemplo registra que el secreto estuvo en commits anteriores; por tanto “limpio” describe el árbol
actual y el paquete generado, no el historial Git. Antes de publicar/compartir el historial hay que
confirmar la revocación con el propietario y coordinar un saneamiento de historial.

**Auditoría histórica redactada 2026-09-24:** a `HEAD=2f422eea38b2f1cbb76fbade92297d7325ba356c`,
el mismo patrón JWT-like del escáner se aplicó a los 66 snapshots alcanzables de este archivo: hubo
hallazgo en 47 commits. También se inspeccionaron 17 copias actuales del flujo (todas con el mismo
SHA-256 y cero hallazgos) y 437 ZIP sin entradas de ese flujo. No se registraron valores ni hashes
del secreto. Evidencia: [auditoría histórica redactada](../../../70-runs/tia-capabilities/20260924-mindsphere-history-redacted-audit.json).
Esto no demuestra revocación del tenant ni sanea history; la aprobación para reescribir history sigue
pendiente y la historia no se debe compartir.

**Revalidación 2026-09-25:** las suites `Test-TiaExampleSecrets.ps1`,
`Test-PortablePackage.ps1` y `Test-PortablePackageContent.ps1` volvieron a pasar. Fuente actual y
archivo generado siguen idénticos por SHA-256 y el test de contenido reconstruyó/eliminó su scratch.
La revocación externa permanece pendiente del propietario. [Registro](../../../70-runs/tia-capabilities/20260925-priority-revalidation.md).

La búsqueda de copias actuales se repitió además sobre todos los archivos accesibles: 18 flujos JSON,
un único hash fuente/paquete y 0 coincidencias del patrón JWT-like. [Auditoría redactada](../../../70-runs/tia-capabilities/20260925-mindsphere-current-distribution-audit.json).

Aceptación: JSON parseable, secreto ausente del árbol actual y paquete distribuible, escaneo limpio,
revocación registrada y cualquier limpieza de historial coordinada. El valor se tratará comprometido
hasta confirmar la revocación.

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
- [x] Cerrar contradicciones heredadas de escritura: README, scripts, conexión MCP, catálogo de
  errores, ADR-010/011 y R08 ahora exigen instancia aislada + fixture manifiesto + `--allow-write`;
  la receta SCL de motor ya no ofrece comandos de importación no disponibles. Los generadores
  `Sync-HarnessConfigs.ps1` y `Export-HarnessAdapter.ps1` validan que `write/full` reciba una raíz
  manifiesta y añaden los argumentos obligatorios. Comprobaciones: `Test-ServerManifest.ps1`,
  `Test-ExportHarnessAdapter.ps1`, `Test-SyncHarnessConfigs.ps1`, `Test-DocumentationState.ps1` y
  `Test-TiaIsolatedMode.ps1 -RunLive` con `Connect → GetState → Disconnect` y hashes preservados
  pasaron el 2026-09-24; `git diff --check` limpio. [Evidencia](../../../70-runs/checks/20260924-write-profile-isolation.json).

Reejecutadas el 2026-09-25: `Test-DocumentationState.ps1`, `Test-ServerManifest.ps1`,
`Test-ExportHarnessAdapter.ps1` y `Test-SyncHarnessConfigs.ps1` terminaron PASS; la sincronización
de perfiles dejó `servers.local.json` sin cambios en git. La evidencia común de revalidación está en
[20260925-priority-revalidation](../../../70-runs/tia-capabilities/20260925-priority-revalidation.md).

Aceptación: recetas consistentes con AGENTS; ningún ejemplo lee una salida como memoria ni sugiere
que un interlock estándar sea safety certificada.

### Fase 4 — Distribución y fixtures (P1)

**Archivos:** TIA-Claude_Portable/manifests/package-info.json, scripts de build/manifest,
TIA-Claude_Portable/tests/Test-PortablePackage.ps1, 50-examples/README.md y agent-demo.

- [x] Generar en una carpeta aislada el candidato actualizado: 321 archivos core y 658 de ejemplos,
  incluida la nueva validación de manifiesto y la regla de escritura aislada. El contenido, los
  hashes y la instalación relocalizada pasaron; evidencia en
  [20260924-fixture-write-guard-validation.json](../../../70-runs/portable-package/20260924-fixture-write-guard-validation.json).
  La ruta validada fue `90-tmp/portable-candidate-20260924-fixture-write-guard`.
- [x] Revalidar el 24/09 el empaquetado desde el árbol fuente después de corregir R07 y sus
  aserciones: `Test-PortablePackageContent.ps1` creó el paquete en scratch, pasó el escaneo de
  credenciales JWT-like, verificó manifiestos/conteos e instalador y eliminó su salida temporal.
  El 24/09 se promovió el candidato validado a `TIA-Claude_Portable/dist`; su árbol de 983 archivos
  coincide con el candidato y vuelve a pasar `Test-PortablePackage.ps1` y `Verify-CorePackage.ps1`
  (321 hashes core). Evidencia: [promoción y verificación](../../../70-runs/portable-package/20260924-portable-dist-promotion.json).
  La distribución anterior 307/658 se conservó íntegra en `90-tmp/portable-dist-stale-20260924`.
  El flujo actual y las 17 copias halladas conservan el placeholder local y no tienen JWT-like; la
  rotación externa y cualquier saneamiento del historial siguen pendientes.
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

Aceptación parcial: `TIA-Claude_Portable/dist` ahora contiene el candidato 321/658 validado, la
comprobación CI segura está verde y el roundtrip live de `FB_AgentDemo` ya está verificado. Siguen abiertas las familias no ejecutadas, la
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

**Revisión Siemens V20 de R19 — 2026-09-25:** se revalidaron la búsqueda por interfaz PG/PC,
la posibilidad de cancelar al hallar el endpoint, el buffer diagnóstico y la limitación de
Connection information cuando solo un extremo está online. Se añadió el gate de compatibilidad
TIA/PLCSIM antes de iniciar cualquier prueba PLC virtual; esto no constituye un handshake ni una
aceptación de tráfico real. Fuentes: [dispositivos accesibles](https://docs.tia.siemens.cloud/r/en-us/v20/using-online-and-diagnostics-functions/displaying-accessible-devices), [connection diagnostics](https://docs.tia.siemens.cloud/r/en-us/v20/device-and-network-diagnostics/connection-diagnostics/overview-of-connection-diagnostics), [diagnostic buffer](https://docs.tia.siemens.cloud/r/en-us/v20/device-and-network-diagnostics/hardware-diagnostics/checking-a-module-for-defects/reading-out-the-diagnostics-buffer-of-a-cpu) y [OPC UA server/client diagnostics](https://docs.tia.siemens.cloud/r/en-us/v20/configuring-automation-systems/using-opc-ua-communication-s7-1200-s7-1500-s7-1500t/using-diagnostics-options-s7-1200-s7-1500-s7-1500t/diagnostics-of-the-opc-ua-server-s7-1500-s7-1500t). R19 sigue **Documentada**; no se ejecutó descubrimiento online ni tráfico sobre red.

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
9. Mantener la configuración generada `write/full` acotada a un único `.tia-agent-fixture.json`;
   no generar adapters mutables genéricos sin `FixtureRoot`. Esta barrera se probó para Claude Code
   y el sincronizador común el 2026-09-24.

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
7. En un fixture aislado `AgentDemo_V20`, el roster write de 84 herramientas expuso `CreateFB`,
   `CreateBlockGroup` y `DeleteBlock`, pero no los importadores. La preflight global leyó los bloques
   y tags no Safety, sin protección, antes de cada intento. `CreateFB` falló con el mensaje genérico
   `CreateFB failed` en la raíz y en dos grupos, para SCL y LAD; el hash del `.ap20` permaneció igual
   al backup. No se reintentó con un importador genérico. El detalle está en
   `70-runs/e2e/mcp-createfb-20260922-1125-createfb-report.json` y deja bloqueada la creación MCP
   de bloques nuevos hasta una implementación acotada y probada.
8. Computer Use nativo creó temporalmente `CU_ComputerUse_Probe [FC1]` y
   `CU_ComputerUse_FB_SCL [FB2]` en otro clon, guardó, cerró, reabrió y confirmó ambos nombres por
   lectura visual; después borró los dos bloques con confirmación y guardó. El diálogo permaneció en
   LAD, por lo que el lenguaje SCL del FB queda **no verificado**; la compilación específica de estos
   bloques nuevos también queda **no verificada**. En una repetición controlada se creó
   `CU_Compile_Probe [FB2]` en LAD, se compiló desde el botón de TIA con 0 errores/0 avisos, se borró
   y se guardó. El clon se dejó con el proyecto cerrado y TIA maximizado. Evidencia:
   `70-runs/environment/computer-use-20260922-tia-gui-create-delete.json`.
9. En un fixture aislado `AgentDemo_V20` se ejecutó el ciclo MCP de tags estándar: creación de
   `CU_MCP_Tag_Probe`, lectura de metadata no Safety, renombre y cambio de dirección, exportación
   antes/después/restaurada, compilación 0/0, guardado, borrado, segundo compile/save y readback
   independiente con cero restos. El primer intento reveló que `SaveProject` dentro de la
   transacción Openness fallaba con `The operation is not permitted within a transaction`; se corrigió
   con `SaveGuarded`, que mantiene el escaneo F/Safety y guarda fuera de la transacción. El test
   estructural y el parche upstream están en [Test-TiaMcpSaveBoundary.ps1](../../../30-tools/tests/Test-TiaMcpSaveBoundary.ps1)
   y la evidencia completa en [mcp-tag-lifecycle-20260922-save-boundary.json](../../../70-runs/e2e/mcp-tag-lifecycle-20260922-save-boundary.json).
10. En un fixture aislado se verificó `CreateInstanceDB` para `FB_AgentDemo` SCL: la DB2 se creó
    con número explícito, inicialmente quedó inconsistente, compiló con 0/0, se exportó a XML,
    guardó, leyó mediante `GetCrossReferences`, borró, volvió a compilar/guardar y desapareció en
    una tercera sesión de solo lectura. El `.ap20` se restauró al hash del backup. La misma prueba
    con `autoNumber=true` y `number=0` produjo una DB0 inválida en `CompileSoftware`; esa ruta queda
    bloqueada hasta corregir o probar el wrapper. Evidencia resumida en
    [mcp-instancedb-acceptance-20260923.json](../../../70-runs/e2e/mcp-instancedb-acceptance-20260923.json)
    y receta [R23](../../../10-kb/20-recetas/R23-instance-db.md).
11. En otro fixture aislado se verificó la tabla PLC de usuario vacía: `CreateTagTable` en raíz,
    `GetTagTableInfo`, `ExportTagTable` (XML 1464 bytes), compile/save 0/0, `DeleteTagTable`,
    segundo compile/save y lectura independiente read-only con cero coincidencias. El proyecto y
    la fuente volvieron a sus hashes iniciales. Evidencia en
    [mcp-tagtable-acceptance-20260923.json](../../../70-runs/e2e/mcp-tagtable-acceptance-20260923.json)
    y receta [R24](../../../10-kb/20-recetas/R24-tabla-tags-offline.md). La importación XML de
    tablas sigue sin publicarse en `tia-inspect/write`.
12. Se verificó un grupo vacío de bloques en raíz: `CreateBlockGroup` → árbol con path exacto →
    `DeleteBlockGroup` → árbol sin el grupo → compile/save 0/0 y segunda sesión read-only sin
    coincidencias. El hash del `.ap20` y de la fuente se restauró. No se introdujeron bloques dentro
    del grupo. Evidencia en [mcp-blockgroup-acceptance-20260923.json](../../../70-runs/e2e/mcp-blockgroup-acceptance-20260923.json)
    y receta [R25](../../../10-kb/20-recetas/R25-grupo-bloques-offline.md).
13. Se verificó la importación de una tabla PLC vacía mediante `tia-create/full` V20:
    preflight F/Safety independiente en `tia-inspect`, `ConnectIsolated`,
    `ImportPlcTagTable(softwarePath, folderPath="", importPath)` con la firma estricta,
    lectura posterior, compile 0/0, `SaveProject` y lectura independiente read-only.
    La tabla importada tuvo `tagCount=0` y `userConstantCount=0`. La restauración exigió
    copiar la carpeta completa porque TIA también modificó `System/PEData.idx` y
    `System/PEData.plf`; el `.ap20`, los sidecars y el proyecto fuente volvieron a sus
    hashes iniciales. Evidencia en
    [mcp-import-tagtable-acceptance-20260923.json](../../../70-runs/e2e/mcp-import-tagtable-acceptance-20260923.json)
    y receta [R26](../../../10-kb/20-recetas/R26-importar-tabla-tags.md).
14. Se verificó en una fixture nueva la importación de una tabla V20 con dos tags Bool estándar:
    preflight independiente `tia-inspect` confirmó dos bloques no F, consistentes y sin
    protección, los tags existentes `isSafety=false` y destino/nombres/direcciones sin
    colisiones; `tia-create/full` importó y exportó la tabla, compiló 0/0 y guardó. El
    readback independiente read-only confirmó los dos tags y `isSafety=false`; tras
    sobrescribir los 9 archivos de la fixture desde el backup, la comparación de carpeta
    dio 0 diferencias y el readback posterior ya no encontró tabla ni tags de prueba.
    Evidencia consolidada en
    [mcp-import-tagtable-member-acceptance-20260923.json](../../../70-runs/e2e/mcp-import-tagtable-member-acceptance-20260923.json).
15. El 24/09/2026 se amplió R26 con esta segunda aceptación y su verificador persistente:
    `Test-TiaAcceptanceStatus.ps1`, `Test-TiaCreationRecipes.ps1` y
    `Test-DocumentationState.ps1` pasaron. `Run-WorkspaceChecks.ps1` terminó con 47 PASS,
    2 WARN y 0 BLOCKED en [latest.json](../../../70-runs/checks/latest.json). Los WARN
    corresponden a una fixture E2E temporal ausente y a que no hay ejecuciones de evaluación;
    la primera corrida tuvo un fallo transitorio al compilar el adaptador PLCSIM, pero su prueba
    aislada y la segunda suite completa pasaron.
16. El 24/09/2026 se aceptó `ImportType` y `DeletePlcType` para un UDT raíz `PlcStruct` con un
    miembro DInt y cero referencias en un clon `AgentDemo_V20`: clasificación independiente de
    bloques/tags, importación con `groupPath=""`, compile 0/0, guardado, exportación, readback en
    otro clon, preview/borrado, segundo compile/save, readback independiente de ausencia y copia
    restaurada idéntica al backup (9/9 archivos). El hash del `.ap20` fue igual en origen/backup y
    copia restaurada. La carpeta de trabajo de TIA tuvo sidecars de índice distintos, por lo que
    no se afirma restauración in-place. Alcance: solo raíz, un DInt y cero referencias; DB global,
    grupos anidados, referencias y tipos complejos continúan sin verificar. Evidencia consolidada:
    [registro](../../../70-runs/e2e/mcp-udt-import-acceptance-20260924.json),
    [paquete de evidencia](../../../70-runs/e2e/mcp-udt-import-acceptance-20260924/README.md).
17. El 25/09/2026 se creó una fixture `AgentDemo_V20` desde cero con `Invoke-AgentDemoScaffold.ps1`:
    dry-run, compilación TIA V20 `Success` 0/0, cierre, lectura de árbol, export PLC/bloque y
    estándares con cero findings. `tia-inspect --isolated` clasificó ambos bloques como no F,
    sin protección y consistentes; los dos tags resultaron `isSafety=false`. El manifiesto siguió
    validando con snapshot de proyecto/backup idéntico tras la lectura. `PLCSimAdvancedSupport`
    quedó `false` en ambos bloques. Computer Use no consiguió entregar una ventana TIA targetable;
    no se intentó descarga ni se abrió otra instancia. Evidencia:
    [fixture nueva y lectura](../../../70-runs/e2e/20260925-plcsim-scaffold/plcsim-fixture-readiness.md),
    [scaffold](../../../70-runs/e2e/20260925-plcsim-scaffold/scaffold-report.json),
    [preflight](../../../70-runs/e2e/20260925-plcsim-scaffold/safety-preflight.json).

Los artefactos completos están en `90-tmp/e2e/20260921-iot2050-agent-probe-clean/`, en especial
`artifacts/01-prewrite-preflight.json`, `06-create-compile-save.json`, `16-import-external-source-root.json`,
`17-generate-compile-save.json`, `18-independent-readback.json`, `19-read-source-and-export-schema.json`,
`23-create-export-delete-preview.json`,
`24-create-export-xml-delete-preview.json`, `26-create-delete-compile-save.json`,
`27-independent-delete-readback.json` y `28-restore-report.json`.

**No probado por acción:** escritura de DB globales, UDT anidados/referenciados y multiinstancia, modificación de hardware,
módulos, redes, HMI, medición física, comunicación con una CPU, online/watch, descarga y runtime.
La importación aceptada cubre una tabla PLC vacía y una tabla con dos tags Bool estándar no
Safety; no acredita constantes de usuario, otros tipos, DB global ni tablas Safety. El UDT raíz
sencillo tiene la aceptación acotada del punto 16, no aplicable a otros tipos. Las guardas
offline de hardware/red y los planes read-only de monitorización/OPC UA sí quedaron
verificados en la auditoría final; no elevan ninguna de esas acciones a nivel Fixture.
No se actuó sobre originales de ejemplos, `40-projects/` ni PLC físico.

**Regla de creación:** la ruta experimental anterior queda etiquetada como `experimental`, no como
capacidad profesional aceptada. La creación de un bloque nuevo permanece bloqueada hasta que exista
un flujo de dos fases con creación vacía, preflight global de F-blocks/tags Safety/protección,
clasificación live y descarte/restauración si alguna metadata falta. La prueba MCP de `CreateFB` del
22/09/2026 añade un bloqueo operativo: la herramienta registrada falla genéricamente incluso con
preflight limpio. La GUI de TIA demuestra que la creación estándar es posible en un clon, pero no
sustituye la clasificación de seguridad ni una compilación específica y reproducible del bloque.

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
  un objeto de texto `Computer Use HMI probe 2026-09-22`; la compilación HMI se intentó desde
  `HMI_1 > Compile > Software (only changes)` y quedó bloqueada con 1 error/0 advertencias porque
  TIA reportó `The device is not supported and cannot be compiled.` El runtime por modelo sigue
  pendiente. La prueba adicional de creación/borrado de bloques quedó documentada por separado;
  al terminar la sesión la ventana TIA quedó maximizada (1920×1040) y el proyecto cerrado.
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
  [HMI/runtimes](../../../70-runs/environment/computer-use-20260922-native-runtime-hmi.json) y
  [creación/borrado](../../../70-runs/environment/computer-use-20260922-tia-gui-create-delete.json).
  La preferencia operativa es dejar TIA maximizado al finalizar.
- [ ] Verificar el perfil read y una sesión MCP nueva: adaptadores Claude/Codex/OpenCode/genérico,
  manifest, sincronización y `tia-inspect --isolated --fixture-root` pasan. El 24/09/2026
  `Test-TiaIsolatedMode.ps1 -RunLive -FixtureRoot <fixture>` ejecutó
  `Connect → GetState → Disconnect` con el mutex, confirmó que no quedó proyecto abierto y preservó
  los hashes de copia/backup. El test ahora exige y valida el manifiesto y el snapshot antes de
  arrancar Openness. El reinicio de cada harness externo concreto queda pendiente de ejecutarse en
  ese host; el contrato local y el binario V20 están verificados en
  [doctor-20260922-final.json](../../../70-runs/environment/doctor-20260922-final.json),
  [Test-TiaIsolatedMode](../../../30-tools/tests/Test-TiaIsolatedMode.ps1) y la
  [evidencia live actual](../../../70-runs/environment/20260924-isolated-read-acceptance.json).
- [x] Ejecutar la suite final de guards, el runner de propuesta SCL en modo negativo, el ciclo MCP
  de tags y `Write-TiaAcceptanceStatus.ps1`; el informe fechado [status-20260922-final14.json](../../../70-runs/acceptance/status-20260922-final14.json)
  y `status-latest.json` mantienen correctamente `accepted=false`, incorporan el inventario
  `computerUse` y conservan los bloqueos de runtime y recetas.
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

El 24/09/2026, `Doctor` confirmó TIA/Openness V20 instalados, grupo Openness presente y estado
desconectado; la repetición del roster `tia-create/full` tuvo los mismos 222 schemas ([secuencia](../../../70-runs/tia-capabilities/20260924-doctor-create-full-readonly.json)). Una captura posterior volvió a verificar
`tia-inspect/read`: 53 schemas y hash `30396a1d60f9b7584f91f47a6bb57bc26a886d2921f2ea612f91d9a3482ed1f7`
(SHA-256 de `response.tools` serializado en JSON compacto); Doctor informó `isConnected=false` y
`allowWrite=false` ([secuencia](../../../70-runs/tia-capabilities/20260924-live-read-profile-refresh.json)). Las búsquedas
dinámicas `FindTools` confirmaron firmas de importación PLC, creación de DB/UDT y borrado por tipo
([secuencia](../../../70-runs/tia-capabilities/20260924-find-db-udt-import-tools-expanded.json)),
pero no se conectó un proyecto ni se ejecutó ninguna mutación. Computer Use mostró el selector de
Windows identificó TIA V20 en su ventana principal maximizada (1920×1040), sin proyecto abierto
([observación](../../../70-runs/environment/20260924-computer-use-tia-window.json)). La sesión aislada
posterior usó únicamente el fixture manifiesto; no abrió el proyecto.

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
| tia-inspect / read | 09:03:41 | 53 | 30396A1D60F9B7584F91F47A6BB57BC26A886D2921F2EA612F91D9A3482ED1F7 | --tia-major-version 20 | [Secuencia Doctor + tools/list](../../../70-runs/tia-capabilities/20260924-live-read-profile-refresh.json); sin proyecto |
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

#### Conteo de clasificación por perfil — captura histórica 2026-09-21

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
| ExportBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: preservePath:boolean=false | Fixture ejecutado en el FB estándar `FB_AgentDemo`; TIA creó `FB_AgentDemo.xml` dentro del directorio `exportPath`; readback XML completo, SCL, 4685 chars. | R1 | Verificado en V20 aislado; el parámetro se comporta como directorio. |
| ExportBlocks | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlocksAsDocuments | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportPlcAsSourceTree | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: — | Fixture ejecutado: informó 3 objetos, 0 omitidos/errores; el árbol físico incluyó tablas de tags y `Main.s7dcl`, pero no `FB_AgentDemo`. No es un export completo de este programa. | R1 | Verificado en V20 aislado, con limitación observada. |
| ExportTagTable | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportType | PLC tags / DB / types | req: softwarePath:string, exportPath:string, typePath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypeAsDocuments | PLC tags / DB / types | req: softwarePath:string, typePath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypes | PLC tags / DB / types | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypesAsDocuments | PLC tags / DB / types | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportWatchTable | PLC online / watch / monitor | req: softwarePath:string, watchTablePath:string, exportPath:string; opt: preservePath:boolean=false | Fixture ejecutado | R1 | Verificado en `mcp-watch-acceptance-20260922.json`; XML V20 exportado, sin entradas, hash conservado. |
| FindInCode | Other / utility | req: softwarePath:string, pattern:string; opt: nameFilter:string="", maxResults:integer=200 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateBlockSource | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: withDependencies:boolean=false, preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateSources | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", withDependencies:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateTypeSource | PLC tags / DB / types | req: softwarePath:string, typePath:string, exportPath:string; opt: withDependencies:boolean=false, preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockInfo | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockInterface | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlocks | PLC blocks / sources / import-export | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockSource | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: format:string="document", maxChars:integer=40000 | Fixture ejecutado sobre `FB_AgentDemo`; completo y sin truncamiento (4685 chars). Aun solicitando `format=document`, esta ejecución devolvió `format=xml`. | R1 | Verificado en V20 aislado; observar el formato real de la respuesta. |
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
| GetWatchTableInfo | PLC online / watch / monitor | req: softwarePath:string, watchTablePath:string; opt: — | Fixture ejecutado | R1 | Verificado: tabla `Watch` consistente, `entryCount=0`, `entries=[]`. |
| GetWatchTables | PLC online / watch / monitor | req: softwarePath:string; opt: regexName:string="" | Fixture ejecutado | R1 | Verificado antes, después de crear/borrar y en segunda sesión independiente. |
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
| CompileSoftware | Diagnostics / compilation | req: softwarePath:string; opt: password:string="" | Fixture ejecutado en `PLC_1`: `Success`, 0 errores, 0 advertencias; metadata F/Safety releída. | R1 | Verificado en V20 aislado write; no equivale a comportamiento runtime. |
| Connect | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| CopyBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, targetGroupPath:string; opt: overwrite:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| CopyType | PLC tags / DB / types | req: softwarePath:string, typePath:string, targetGroupPath:string; opt: overwrite:boolean=false | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateBlockGroup | PLC blocks / sources / import-export | req: softwarePath:string, parentGroupPath:string, name:string; opt: — | Fixture ejecutado | R2 | Verificado en raíz V20: path leído en `GetSoftwareTree`, borrado, compile/save 0/0 y readback independiente. |
| CreateExternalSourceFromFile | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string, name:string, filePath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateExternalSourceGroup | PLC blocks / sources / import-export | req: softwarePath:string, parentGroupPath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateFB | Other / utility | req: softwarePath:string, groupPath:string, name:string; opt: language:string="LAD", autoNumber:boolean=true, number:integer=0 | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateInstanceDB | Other / utility | req: softwarePath:string, groupPath:string, name:string, instanceOfName:string; opt: autoNumber:boolean=true, number:integer=0 | Fixture ejecutado | R2 | Verificado en fixture V20 con `autoNumber=false`, número 2, compile 0/0, readback seguro y restauración; `autoNumber=true`/`number=0` bloqueado por DB0 inválida. |
| CreateTag | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, name:string; opt: dataTypeName:string="", logicalAddress:string="" | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateTagTable | PLC tags / DB / types | req: softwarePath:string, groupPath:string, name:string; opt: — | Fixture ejecutado | R2 | Verificado con tabla de usuario vacía en V20: path/metadata, exportación, compile/save 0/0, borrado y readback independiente. |
| CreateTagTableGroup | PLC tags / DB / types | req: softwarePath:string, parentGroupPath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateTypeGroup | PLC tags / DB / types | req: softwarePath:string, parentGroupPath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateUserConstant | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, name:string; opt: dataTypeName:string="", value:string="" | Solo schema | R2 | MCP conocido / Openness desconocido |
| CreateWatchTable | PLC online / watch / monitor | req: softwarePath:string, groupPath:string, name:string; opt: — | Fixture ejecutado | R2 | Verificado en clon: raíz (`groupPath=""`), path leído, tabla estándar vacía y restauración posterior. |
| CreateWatchTableGroup | PLC online / watch / monitor | req: softwarePath:string, parentGroupPath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DisableUnconfiguredPlcConfigurationProtection | Hardware / device protection | req: deviceItemPath:string; opt: — | Fixture live: `WithoutPassword → None`; repetición idempotente; compile software 0/0; fixture cerrada sin guardar y hash original conservado. [acción](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/plc-configuration-protection-live-evidence.json) · [esquema](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/isolated-fixture/write-tool-registration-evidence.json) | R2 | Acción verificada; guardado y compile hardware pendientes. |
| DeleteBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Fixture ejecutado | R2 | Verificado en el mismo ciclo Instance DB: path leído, borrado, compile/save 0/0 y cero coincidencias en sesión independiente. |
| DeleteBlockGroup | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string; opt: — | Fixture ejecutado | R2 | Verificado para grupo vacío; el grupo de sistema `Program blocks` y grupos con contenido quedan fuera. |
| DeleteExternalSource | PLC blocks / sources / import-export | req: softwarePath:string, sourcePath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteExternalSourceGroup | PLC blocks / sources / import-export | req: softwarePath:string, groupPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteTag | PLC tags / DB / types | req: softwarePath:string, tagPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteTagTable | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string; opt: — | Fixture ejecutado | R2 | Verificado en el mismo ciclo: path leído, cero coincidencias tras borrar, compile/save 0/0 y segunda sesión read-only. |
| DeleteTagTableGroup | PLC tags / DB / types | req: softwarePath:string, groupPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteType | PLC tags / DB / types | req: softwarePath:string, typePath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteTypeGroup | PLC tags / DB / types | req: softwarePath:string, groupPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteUserConstant | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, name:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| DeleteWatchTable | PLC online / watch / monitor | req: softwarePath:string, watchTablePath:string; opt: — | Fixture ejecutado | R2 | Verificado con path de `GetWatchTables`, readback 0 y segunda sesión sin residuos. |
| DeleteWatchTableGroup | PLC online / watch / monitor | req: softwarePath:string, groupPath:string; opt: — | Solo schema | R2 | MCP conocido / Openness desconocido |
| Disconnect | Project / session | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| Doctor | Diagnostics / compilation | req: —; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportAsDocuments | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlock | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: preservePath:boolean=false | Dos fixtures: XML Instance DB V20 (evidencia 2026-09-23) y FB estándar `FB_AgentDemo` (export/readback completo en `retry-fixture-01`). El parámetro `exportPath` fue un directorio que recibió `FB_AgentDemo.xml`. | R1 | Verificado en V20 aislado para ambos objetos indicados. |
| ExportBlocks | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportBlocksAsDocuments | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportPlcAsSourceTree | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: — | Fixture ejecutado: informe 3 objetos, 0 omitidos/errores; omitió el FB SCL `FB_AgentDemo` del árbol exportado, que se exportó luego con `ExportBlock`. | R1 | Verificado en V20 aislado con alcance parcial observado. |
| ExportTagTable | PLC tags / DB / types | req: softwarePath:string, tagTablePath:string, exportPath:string; opt: preservePath:boolean=false | Fixture ejecutado | R1 | XML de tabla vacía V20 exportado (1464 bytes) y hash recalculado en `mcp-tagtable-acceptance-20260923.json`. |
| ExportType | PLC tags / DB / types | req: softwarePath:string, exportPath:string, typePath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypeAsDocuments | PLC tags / DB / types | req: softwarePath:string, typePath:string, exportPath:string; opt: preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypes | PLC tags / DB / types | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportTypesAsDocuments | PLC tags / DB / types | req: softwarePath:string, exportPath:string; opt: regexName:string="", preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| ExportWatchTable | PLC online / watch / monitor | req: softwarePath:string, watchTablePath:string, exportPath:string; opt: preservePath:boolean=false | Fixture ejecutado | R1 | Verificado en `mcp-watch-acceptance-20260922.json`; XML V20 exportado, sin entradas, hash conservado. |
| FindInCode | Other / utility | req: softwarePath:string, pattern:string; opt: nameFilter:string="", maxResults:integer=200 | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateBlocksFromSource | PLC blocks / sources / import-export | req: softwarePath:string, sourcePath:string; opt: targetGroupPath:string="", keepOnError:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateBlockSource | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string, exportPath:string; opt: withDependencies:boolean=false, preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateSources | PLC blocks / sources / import-export | req: softwarePath:string, exportPath:string; opt: regexName:string="", withDependencies:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GenerateTypeSource | PLC tags / DB / types | req: softwarePath:string, typePath:string, exportPath:string; opt: withDependencies:boolean=false, preservePath:boolean=false | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockInfo | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockInterface | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: — | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlocks | PLC blocks / sources / import-export | req: softwarePath:string; opt: regexName:string="" | Solo schema | R1 | MCP conocido / Openness desconocido |
| GetBlockSource | PLC blocks / sources / import-export | req: softwarePath:string, blockPath:string; opt: format:string="document", maxChars:integer=40000 | Fixture ejecutado sobre `FB_AgentDemo`: respuesta completa, 4685 chars y `truncated=false`; devolvió XML aunque se solicitó documento. | R1 | Verificado en V20 aislado; no depender del formato solicitado sin revisar `meta.format`. |
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
| GetWatchTableInfo | PLC online / watch / monitor | req: softwarePath:string, watchTablePath:string; opt: — | Fixture ejecutado | R1 | Verificado: tabla `Watch` consistente, `entryCount=0`, `entries=[]`. |
| GetWatchTables | PLC online / watch / monitor | req: softwarePath:string; opt: regexName:string="" | Fixture ejecutado | R1 | Verificado antes, después de crear/borrar y en segunda sesión independiente. |
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
| SaveProject | Project / session | req: —; opt: — | Fixture ejecutado después de compile 0/0. El hash de proyecto tras guardar continuó idéntico al backup/manifiesto. | R2 | Verificado en V20 aislado; esta ejecución no produjo un cambio persistente de contenido. |
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
| ImportPlcTagTable | PLC tags / DB / types | req: softwarePath:string, folderPath:string, importPath:string; opt: — | Fixture ejecutado | R2 | MCP: verificados en `tia-create/full` V20 dos casos en fixtures aisladas: tabla vacía y tabla con dos tags Bool no Safety; ambos compile/save 0/0, readback independiente y restauración completa de carpeta. Openness directo: mapeado en el código del servidor a `PlcSoftware.TagTableGroup.TagTables.Import(FileInfo, ImportOptions.Override)` preferido, con fallback reflejado a `Import(FileInfo)`; la llamada directa independiente aún no se ejecutó. |
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
| Computer Use nativo / ventanas Windows | **Disponible en esta sesión** por plugin `computer-use`, `node_repl` y `@oai/sky`. La llamada `mcp__cua_repl` no mide esta superficie. | `sky.list_apps/list_windows` encontró una única ventana TIA V20 targetable. En el clon PLC se editó `PLC_1/Program blocks/FB_AgentDemo`, se compiló con 0 errores/0 advertencias, se guardó, se cerró y se reabrió para leer el SCL. En el clon HMI se inspeccionaron `HMI_1 [TP1200 Comfort]`, `Screens/Grundbild`, `Connections` y `HMI tags`, se editó un texto y la compilación devolvió 1 error/0 advertencias por dispositivo no soportado. No se descargó ni se tocó un original, F-block o bloque protegido. [PLC](../../../70-runs/environment/computer-use-20260922-tia-gui-edit.json), [HMI/compile](../../../70-runs/environment/computer-use-20260922-hmi-edit.json), [HMI/runtimes](../../../70-runs/environment/computer-use-20260922-native-runtime-hmi.json). |
| Captura previa de línea base | `nativeApps: []`, `nativeControlAvailable: false`. | [baseline.json](../../../70-runs/tia-capabilities/20260921-01-baseline/baseline.json) registra `cua.getState` a las 09:27 del 21/09/2026: solo evidencia de esa superficie browser, no un inventario nativo Windows. Se conserva como captura histórica no concluyente para Computer Use nativo. |

### Ejecución real en fixture — 2026-09-21

El roster anterior sigue siendo una instantánea de **schema**; esta tabla independiente marca solo
las llamadas y operaciones observadas en `90-tmp/e2e/20260921-iot2050-agent-probe-clean/`; la fila
de importación de tabla enlaza el fixture V20 separado de R26.

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
| `CreateFB` en `tia-inspect / write` | Perfil aislado `--allow-write` con fixture manifest | **Bloqueado por fallo live** | La preflight de bloques/tags no Safety pasó, pero la llamada devolvió `CreateFB failed` para SCL y LAD en raíz y grupos; el hash del `.ap20` no cambió. [informe](../../../70-runs/e2e/mcp-createfb-20260922-1125-createfb-report.json) |
| `ImportPlcTagTable` | `tia-create / full` en fixture V20 aislado, con preflight `tia-inspect / write` independiente | **Verificado: tabla vacía** | `Bootstrap → ConnectIsolated → OpenProject → GetSoftwareTree(softwarePath) → ImportPlcTagTable(softwarePath, folderPath="", importPath) → GetPlcTagTables → CompileSoftware 0/0 → SaveProject`; la sesión `tia-inspect / read` confirmó la tabla y la restauración completa eliminó también los cambios de `System/PEData.idx` y `System/PEData.plf`. [veredicto](../../../70-runs/e2e/mcp-import-tagtable-acceptance-20260923.json) |
| Restauración del proyecto | Operación de archivos, fuera de TIA | **Hash verificado** | 31 archivos, sin extras/faltantes/mismatches; hash del `.ap20` coincide con original/backup: [reporte](../../../90-tmp/e2e/20260921-iot2050-agent-probe-clean/artifacts/28-restore-report.json). |
| `Invoke-TiaSimulationAcceptance` guardas | Pruebas locales con servidores/adaptadores MCP simulados | **Mocks: aprobados; PLCSIM real: no ejecutado** | `Test-InvokeTiaSimulationAcceptance.ps1` y `Test-TiaSimulationAcceptanceSafety.ps1` cubren gates, plan funcional, compilación, IP y ruta inequívoca. No son evidencia de descarga ni de comportamiento PLC. |
| `RunOfflineReleaseValidationSuite` | `tia-create / lite`, descubierto con `FindTools` y ejecutado mediante `CallTool` | **Bloqueado por precondición; no es un PASS funcional** | Es offline-only y no hubo `Connect` ni `OpenProject`. El transporte MCP terminó, pero el JSON interno devolvió `meta.success=false` por falta de `TMP_EXPORT\_verify\UDT_Fault.xml`; el preflight enumera 5/5 golden PLC ausentes y `docs\hmi_templates` ausente. No se fabrican XML ni se copian ejemplos para satisfacerlo. Evidencia: [preflight](../../../70-runs/tia-capabilities/20260922-offline-release-preflight-final.json), [primer intento](../../../70-runs/tia-capabilities/20260922-offline-release-validation.json), [reproducción](../../../70-runs/tia-capabilities/20260922-offline-release-repro.json). |
| Builders PLC/HMI y manifiesto de símbolos offline | `tia-create / full` mediante `FindTools` + `CallTool` | **Verificado offline; esos builders siguen sin importación V20** | UDT, DB global, tabla de tags, FC/FB SCL, paquete HMI Classic y extracción de símbolos generaron XML/paquetes parseables sin conectar TIA. Las salidas PLC declaran V21 y Classic V18; no se elevan a fixture V20. La importación V20 de una tabla vacía se acepta por separado en R26. Evidencia: [informe](../../../70-runs/tia-capabilities/20260922-noncu-family-offline-builders.md), [UDT](../../../70-runs/tia-capabilities/20260922-noncu-family-udt-rerun.json), [símbolos](../../../70-runs/tia-capabilities/20260922-noncu-family-symbol-manifest-clean.json). |

### Ejecución gráfica controlada — 2026-09-22

| Acción | Superficie | Estado observado | Evidencia / límite |
|---|---|---|---|
| Abrir, editar, compilar, guardar y leer de nuevo un bloque SCL | TIA Portal V20 / clon `AgentDemo_V20` | **Verificado en clon desechable** | Se añadió solo el comentario `// Computer Use visual probe 2026-09-22` en `PLC_1/Program blocks/FB_AgentDemo`; Compile mostró 0 errores y 0 advertencias, el guardado fue confirmado por TIA y la reapertura mostró el texto. El original quedó preservado. [evidencia](../../../70-runs/environment/computer-use-20260922-tia-gui-edit.json) |
| Crear, compilar y borrar un FB estándar | TIA Portal V20 / clon `AgentDemo_V20` | **Verificado en clon desechable para LAD** | TIA creó `CU_Compile_Probe [FB2]`; Compile mostró `errors: 0; warnings: 0` y `Block was successfully compiled`. El FB se borró con confirmación y el clon se guardó/cerró. La prueba separada `CU_ComputerUse_FB_SCL` confirmó creación y readback, pero dejó el lenguaje SCL sin verificar. [evidencia](../../../70-runs/environment/computer-use-20260922-tia-gui-create-delete.json) |
| Abrir, editar y leer de nuevo un HMI Comfort | TIA Portal V20 / clon GamesCollection | **Edición/readback verificados; compile bloqueado por dispositivo no soportado** | `HMI_1 [TP1200 Comfort]`, `Screens/Grundbild`, `Connections` y `HMI tags` se observaron; se creó el objeto `Computer Use HMI probe 2026-09-22`, se guardó, se cerró/reabrió y se leyó visualmente. La compilación de software mostró 1 error/0 advertencias: `The device is not supported and cannot be compiled.` La tabla de conexiones no tenía PLC configurado. [inspección](../../../70-runs/environment/computer-use-20260922-native-runtime-hmi.json) · [edición/compile](../../../70-runs/environment/computer-use-20260922-hmi-edit.json) |
| Inspeccionar PLCSIM Advanced | `S7-PLCSIM Advanced V6.0 Upd1` | **Disponibilidad verificada; comportamiento no verificado** | La interfaz mostró acceso `PLCSIM`, familia S7-1500 y ninguna instancia activa. No se creó instancia, no se descargó y no se ejecutó una prueba de ciclo. [evidencia](../../../70-runs/environment/computer-use-20260922-native-runtime-hmi.json) |
| Inspeccionar runtime HMI instalado | `SIMATIC Runtime Manager` | **Bloqueado para Runtime Advanced V20** | La aplicación observada es el Runtime Manager de WinCC Unified, con servidor `localhost`, lista vacía y error general; no es una prueba de Runtime Advanced. [evidencia](../../../70-runs/environment/computer-use-20260922-native-runtime-hmi.json) |

#### API Openness y Computer Use

Cruce inicial de importadores PLC basado en documentación oficial Siemens V20. Esto identifica
miembros API documentados; no demuestra que un wrapper MCP concreto los llame ni que la acción se
haya ejecutado localmente:

| Objeto | API Siemens V20 documentada | Evidencia local | Estado |
|---|---|---|---|
| Bloque PLC, incluido GlobalDB estándar | `PlcSoftware.BlockGroup.Blocks.Import(FileInfo, ImportOptions.Override)` | `ImportBlock`/`PlcBuildAndImport` aparecen en roster; falta roundtrip GlobalDB V20. `BuildPlcGlobalDbXml` genera XML V21 y no autoriza importarlo como V20. | API documentada; wrapper MCP y fixture V20 no verificados. [Importing block](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/importing/exporting-data-of-a-plc-device/blocks/importing-block), [UDT & DB](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/importing/exporting-data-of-a-plc-device/blocks/export/import-of-udt-db) |
| UDT desde SimaticML XML | `plcSoftware.TypeGroup.Types.Import(FileInfo, ImportOptions.Override)` | `ImportType` y `DeletePlcType` aceptados para un UDT raíz `PlcStruct` de un miembro DInt y cero referencias; compile/save/export/readback independiente y restauración comparada. | **Fixture V20 aceptado solo para ese alcance**; no generalizar a tipos anidados, referenciados, complejos ni `.s7dcl`. [Evidencia](../../../70-runs/e2e/mcp-udt-import-acceptance-20260924/README.md), [Importing user data type](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/importing/exporting-data-of-a-plc-device/blocks/importing-user-data-type) |
| UDT desde documento `.s7dcl` | `plcSoftware.TypeGroup.Types.ImportFromDocuments(DirectoryInfo, fileNameWithoutExtension, ImportDocumentOptions.Override)`; devuelve estado, tipos importados y mensajes | El roster publica `ImportTypesFromDocuments`; no se han probado conteos ni readback exacto para una importación UDT. | API documentada; wrapper MCP y fixture V20 no verificados. [Importing UDT from document](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/importing/exporting-data-of-a-plc-device/blocks/importing-udt-from-document) |
| Tabla de tags PLC | `plcSoftware.TagTableGroup.TagTables.Import(FileInfo, ImportOptions.Override)` | Dos fixtures V20 aceptadas: tabla vacía y dos tags Bool estándar no Safety, compile/save 0/0, readback independiente y restauración. | API documentada y ruta MCP fixture verificada; cliente Openness independiente pendiente. [Importing PLC tag table](https://docs.tia.siemens.cloud/r/es-es/v20/tia-portal-openness-api-para-la-automatizacion-de-flujos-de-trabajo-de-ingenieria/exportacion/importacion/importacion/exportacion-de-datos-de-un-dispositivo-plc/tablas-de-variables/importar-tabla-de-variables-plc) |

Siemens V20 documenta que la API puede importar/exportar F-blocks. La capacidad de Siemens no elimina
la exclusión local: no importar ni editar F-blocks/tags Safety. Todo XML debe corresponder a la
versión/objeto y pasar el preflight local. Siemens también exige que los objetos raíz de un mismo
archivo sean de una sola clase y que todos sean válidos; si uno falla, no se importa ninguno. Por eso
las primeras aceptaciones deben usar un objeto por operación y leer el resultado completo después.
[Reglas oficiales de importación](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/overview/importing-configuration-data).

| Superficie | Capacidad conocida | Evidencia local de acción | Estado |
|---|---|---|---|
| Siemens Openness V20 | Siemens documenta leer, crear, modificar, borrar, compilar, importar/exportar y diagnosticar ciertos objetos; depende de versión/tipo/modelo. | Probe independiente `.NET Framework 4.8/x64`: `Api.Global.Openness().Initialize(20)`, grupo Openness, carga de `Siemens.Engineering 20.0.0.0` y `TiaPortal.GetProcesses()` en solo lectura; no Attach/OpenProject/escritura. [evidencia](../../../70-runs/environment/direct-openness-20260922-final.json) | **Fixture read-only** para inicialización/enum. El mapeo acción a acción MCP → miembro Openness sigue sin probar. |
| `tia-inspect / read` | Inspección y lectura; el roster live actual publica 53 schemas. | Doctor, tree, tags, blocks, source, compile, readback. | **Fixture** solo para las acciones enumeradas arriba; el resto sigue en **Schema**. |
| `tia-inspect / write` | Snapshot histórico `--allow-write`, 84 schemas; el build V20 con el wrapper nuevo enumera 85 y exige fixture manifest. | En fixture V20: `WithoutPassword → None`, segunda lectura idempotente `None → None`, preflight F/Safety completo y compile software 0/0; no se guardó mientras falte compile hardware. [Evidencia](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/plc-configuration-protection-live-evidence.json) | **Acción verificada en memoria**; persistencia y compilación hardware pendientes. |
| `tia-create / lite` | Snapshot de 55 schemas y búsqueda dinámica con `FindTools`/`CallTool`. | Preview/importación alternativa/export/delete de probe y compile/save en la secuencia documentada. `PlcBuildAndImport` apply falló por cultura. | **Fixture** por las acciones enumeradas, no por todo el perfil. |
| `tia-create / full` | Snapshot de 222 schemas. | `Bootstrap → RunCapabilitySelfTest(connectIfNeeded=false) → Disconnect` terminó correctamente; además, `RunOnlineMonitoringSafetySelfTest` y `RunHmiActionScriptRecipeSafetySelfTest` pasaron offline sin abrir proyecto. Se verificó `ImportPlcTagTable` con tabla vacía y con dos tags Bool no Safety en fixtures V20 aisladas: firma estricta, compile/save 0/0, readback independiente y restauración completa de carpeta. La auditoría final verificó los planificadores de hardware/red y monitorización read-only. [evidencia lite](../../../70-runs/tia-capabilities/20260922-create-lite-selftest.json), [evidencia full](../../../70-runs/tia-capabilities/20260922-create-full-selftest.json), [importación vacía](../../../70-runs/e2e/mcp-import-tagtable-acceptance-20260923.json), [importación con tags](../../../70-runs/e2e/mcp-import-tagtable-member-acceptance-20260923.json), [lote offline](../../../70-runs/tia-capabilities/20260922-offline-safe-tools-batch.md), [auditoría final](../../../70-runs/tia-capabilities/20260922-final-noncu-hardware-comms-analog-audit.json). | **Fixture** para tabla vacía y dos tags estándar; **smoke/offline safety** para las demás llamadas; el resto sigue en **Schema**. |
| Computer Use nativo | Puede inspeccionar y navegar la ventana TIA si el plugin nativo y el permiso para esa aplicación están activos. | En esta sesión se abrieron clones, se editó/compiló/guardó/leyó de nuevo un bloque SCL, se creó/compiló/borró un FB LAD con 0/0 y se creó/guardó/leyó de nuevo un objeto de texto HMI. La compilación HMI se intentó y TIA devolvió 1 error/0 advertencias por dispositivo no soportado. `cua_repl.apps=[]` no era un dato del inventario Windows. | **UI y ediciones gráficas verificadas en clones**; creación del FB SCL, compile HMI por modelo, runtime HMI y comunicación desde GUI siguen sin probar. |

### Límites y acciones siguientes

- El perfil `tia-create / lite` no fue usado para todos sus métodos; `full` tiene una prueba de fixture para
  `ImportPlcTagTable` y, fuera de ella, ejecutó el lote offline y el self-test.
- No se probaron modificación de hardware, red/protocolos, tablas con constantes u otros tipos, escritura de DB global,
  binding HMI, alarmas, mediciones físicas, watch/force, descarga, comportamiento PLC en PLCSIM,
  Runtime ni escritura online. La interfaz de edición SCL y la edición visual de un objeto HMI ya
  están verificadas en clones; el compile HMI está bloqueado por dispositivo no soportado y el runtime sigue sin verificar. La auditoría final
  también verificó sin conexión las guardas de hardware/red y la planificación read-only de
  monitorización/OPC UA; además, el ciclo de tags estándar fue exportado, compilado, guardado,
  borrado y leído de vuelta independientemente. La evidencia de importación cubre una tabla
  vacía y una tabla con dos tags Bool estándar no Safety; no cubre constantes de usuario,
  otros tipos ni DB global. El UDT raíz sencillo está cubierto únicamente por la aceptación del punto 16.
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
  bloqueados. Consultar [status-20260922-final14.json](../../../70-runs/acceptance/status-20260922-final14.json)
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
3. completar únicamente en fixtures las familias que tengan precondiciones reales: tablas con tags,
   UDT/DB,
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

### Registro de Computer Use — 2026-09-24

En la ventana TIA V20 identificada se hizo una prueba diagnóstica de UI sobre el clon desechable global DB. Se creó `DB_AgentGlobalAcceptance` como Global DB con `Counter : DInt`, se guardó y `Software (rebuild all)` terminó con 0 errores y 0 advertencias. La ventana quedó maximizada a 1920×1040. Al releer el objeto por `GetBlocks` y `GetBlockInfo`, TIA/MCP devuelve `isFailsafe=null` y lenguaje `DB`; `ImportBlock` no ofrece `dryRun`. Por tanto, **la creación gráfica observada no se acepta como flujo permitido de agente** y la importación MCP se bloqueó sin llamarla, conforme a la barrera de metadata desconocida. Evidencia y limitaciones completas: [registro Computer Use y exportación read-only](../../../90-tmp/e2e/20260924-globaldb-import-acceptance/artifacts/04-computer-use-globaldb.md), [XML exportado](../../../90-tmp/e2e/20260924-globaldb-import-acceptance/artifacts/DB_AgentGlobalAcceptance.xml/DB_AgentGlobalAcceptance.xml). La copia restaurada aparte coincide con el backup en 9/9 archivos; el clon abierto no se restauró in-place.

**Inspección adicional de PLCSIM Advanced — 2026-09-24:** Computer Use abrió la aplicación instalada V6.0 Update 1. La interfaz mostró `No Active PLC Instance` y las opciones `PLCSIM`, `TCP/IP Single Adapter` y `TCP/IP Multiple Adapter`. No se creó instancia ni se descargó. Al abrir el selector de switch virtual la acción UI falló; una captura nueva confirmó que la vista seguía en el panel principal, así que no se reintentó. No se validó adaptador, ruta/IP ni CPU coincidente; comportamiento de PLC y runtime siguen sin verificar. TIA volvió a maximizarse y se confirmó una captura de 1920×1040 con el rebuild visible en 0 errores/0 advertencias. [Evidencia de la inspección](../../../70-runs/tia-capabilities/20260924-computer-use-plcsim-ui-check.json).

La acción `ExportBlock` sí quedó verificada como lectura/exportación en el proyecto exacto `AgentDemo_V20`. La importación/edición de Global DB queda **bloqueada** hasta una clasificación F/Safety estándar explícita compatible con `AGENTS.md` y una ruta de escritura aprobada; no se infiere seguridad a partir de `GlobalDB`, lenguaje DB, tipo de CPU o compilación limpia.

### Actualización PLCSIM Advanced — 2026-09-24

La inspección de Siemens V20 confirma que **TIA Portal y PLCSIM Advanced sí se conectan**. Siemens ofrece Softbus local (predeterminado, punto PG/PC `PLCSIM`) y TCP/IP. En este equipo se adopta **Softbus como ruta predeterminada**: Siemens dice que limita la comunicación al PC/VM local y evita una descarga accidental a un PLC físico. TCP/IP queda como alternativa para integraciones que necesiten Ethernet; el modo `<Local>` apaga el switch hacia la red real.

- **Verificado:** el adaptador nativo PLCSIM Advanced V6 registró y encendió una CPU virtual estándar 1513 con `networkMode=SOFTBUS`, `status=ready` y códigos de API `0x0`. TIA V20, con la fixture `AgentDemo_V20` abierta, mostró `Connected to PLC_1, via address IP=192.168.0.1` tras `Go online` por la interfaz gráfica. La ventana se mantuvo maximizada. La instancia se detuvo después con `powerOffCode`, `unregisterCode` y `destroyCode` en `0x0`.
- **TCP/IP alternativo:** el equipo tuvo APIPA `169.254.242.16/16` en la NIC Siemens y CPU de prueba `192.168.0.1`; el helper read-only demostró la falta de subred coincidente. Asignar `192.168.0.2/24` devolvió `Access denied` sin modificar interfaces. Evidencia: [estado de NIC](../../../70-runs/acceptance/plcsim-tia-ip-state-20260924.json).
- **Verificado en fixtures:** el runner deja Softbus por defecto, exige modo/interfaz Softbus y selecciona `PLCSIM` como PG/PC; la ruta TCP/IP se conserva como opción expresa `-PlcSimTransport tcpip-local`. Las pruebas de aceptación cubren gates, limpieza del runtime, expectativa funcional explícita, ruta única, discrepancias de IP/TCP-IP y selección de Softbus. Evidencia de ejecución: `Test-InvokeTiaSimulationAcceptance.ps1` y `Test-TiaSimulationAcceptanceSafety.ps1`.
- **Bloqueado antes de descargar:** el perfil MCP leyó OB, FB y Global DB, pero `GetBlocks` no incluyó `isFailsafe`. El contrato exige clasificación F/Safety completa antes de cualquier escritura/descarga; CPU estándar, compilación limpia y ausencia aparente de bloques F no sustituyen esa metadata. Tampoco se ha leído de forma completa y autoritativa cada tabla de tags. No se descargó el programa ni se marcó comportamiento PLC como probado.
- **Siguiente paso necesario:** exponer/leer por una vía soportada la clasificación Safety de todos los bloques y todas las tablas de tags del fixture, registrar readback, y solo entonces intentar la primera descarga en Softbus. Exigir que TIA identifique `CPU-1500 Simulation`/simulated CPU en la vista previa; cancelar si aparece ambiguo. Después ejecutar un plan con entrada virtual y lectura de salida esperada, registrar evidencias y parar/desregistrar la instancia.

Fuentes Siemens: [qué es PLCSIM Advanced V20](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_20/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced-api/product-overview/what-is-s7-plcsim-advanced), [Control Panel V20 y sus modos](https://docs.tia.siemens.cloud/r/simatic_et_200sp_manual_collection_enus_20/general-information/cpu-function-manuals/s7-plcsim-advanced/simulating/simulating-a-cpu/control-panel-user-interface/s7-plcsim-advanced-control-panel), [descargar un proyecto STEP 7 a PLCSIM](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_21/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced/simulating/simulating-a-cpu/downloading-a-step-7-project).

### Revisión de simulabilidad y secuencia final — 2026-09-24

La documentación oficial V20 confirma que **Support simulation during block compilation** está
en propiedades del proyecto > Protection y desactivada por defecto. Openness V20 también expone
`Project.IsSimulationDuringBlockCompilationEnabled` como lectura/escritura. El perfil MCP probado no
publica una operación específica para esa propiedad. [Propiedades TIA](https://docs.tia.siemens.cloud/r/en-us/v20/editing-projects/creating-and-managing-projects/displaying-properties-of-the-project),
[API Openness](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/tia-portal-openness-api/functions-for-projects-and-project-data/updating-project-properties).

- **Verificado:** Siemens documenta que Softbus local usa el punto `PLCSIM`, limita el enlace al
  host/VM y evita descargas accidentales a CPUs físicas. La instancia se inicializa con su primera
  descarga desde TIA; el diálogo identifica `CPU-1500 Simulation` y declara que la descarga va a una
  CPU simulada. [Comunicación local V21](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_21/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced/communication-paths/local-communication),
  [descarga STEP 7 V21](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_21/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced/simulating/simulating-a-cpu/downloading-a-step-7-project).
- **Verificado en host:** en el proyecto exacto visible, `tia-create lite` ofreció `AttachToOpenProject`
  y adjuntó `AgentDemo_V20`. Computer Use activó **Support simulation during block compilation**
  en Protection; se guardó y compiló por Openness con `Success`, 0 errores y 0 avisos. La lectura
  posterior confirmó `PLCSimAdvancedSupport=true`, `isConsistent=true` y sin protección know-how
  en `Main` y `FB_AgentDemo`. La ventana de TIA quedó maximizada a 1920×1040.
- **Bloqueado antes de la primera descarga:** con `tia-create full`, `GetTags` respondió `Unknown
  tool` y los objetos `GetBlocks` no contienen el campo `isFailsafe`. Ambos datos son obligatorios
  para el veto Safety; no se permite inferirlos por el modelo de CPU o por nombres. PLCSIM Advanced
  mostraba `PLCSIM` seleccionado y `No Active PLC Instance`. No se arrancó instancia, no se descargó
  el programa ni se afirmó comportamiento. Evidencias: `plcsim-full-safety-preflight-20260924.json`,
  `plcsim-visible-compile-20260924.json`, `plcsim-postcompile-inspection-20260924.json` y
  `plcsim-ui-state-20260924.json`.
- **Verificado — integridad de fixtures:** se cerró el proyecto guardado, se restauró la fixture
  original desde su backup (su manifiesto volvió a pasar) y se guardó el snapshot con soporte de
  simulación en `90-tmp/e2e/20260924-plcsim-simulation-support-enabled/`, con backup idéntico y
  manifiesto validado. La lectura MCP adjunta a la ventana de ese snapshot volvió a confirmar
  `PLCSimAdvancedSupport=true` en los dos bloques; `isFailsafe` continuó ausente. Evidencia:
  `plcsim-enabled-fixture-readback-20260924.json`. El snapshot habilitado no equivale a aceptación
  de descarga.
- **Actualización 2026-09-25:** una fixture nueva confirmó preflight completo en `tia-inspect`
  (`isFailsafe=false` en cada bloque y `isSafety=false` en las dos tags); el manifiesto siguió
  pasando con los hashes del proyecto y backup idénticos. `PLCSimAdvancedSupport=false` en ambos
  bloques, por lo que aún requiere activación y compilación. Computer Use no entregó una ventana
  TIA targetable tras el lanzamiento y la enumeración posterior quedó vacía; no se cambió la
  propiedad ni se descargó. Véase [evidencia fresca de fixture](../../../70-runs/e2e/20260925-plcsim-scaffold/plcsim-fixture-readiness.md).
- **Siguiente paso necesario:** hacer que el perfil disponible proporcione un inventario completo
  y explícito de bloques Safety y tags Safety en la misma sesión que se adjunta al proyecto visible.
  Después repetir el preflight, iniciar una instancia Softbus estándar desechable, verificar en la
  vista previa de TIA `CPU-1500 Simulation`/simulated CPU, descargar y ejecutar el plan funcional.
- **No verificado:** descarga a PLCSIM, arranque de programa y respuesta funcional a un plan de E/S.
  El siguiente intento debe partir de una copia desechable identificada, activar la propiedad,
  recompilar 0/0, comprobar el target simulado en el diálogo, ejecutar el plan de entrada/salida,
  guardar evidencia y apagar/desregistrar la instancia.
- **Verificado en regresiones mock:** el runner bloquea metadata F/Safety/protección incompleta,
  simulabilidad desactivada, advertencia/error de descarga y estado online distinto de `Online`; los
  casos Softbus pasan `PLCSIM` como interfaz y se limpia la instancia. Las cuatro suites SCL,
  aceptación PLCSIM y secretos quedan en [evidencia fechada](../../../70-runs/acceptance/plcsim-safety-runner-regression-20260924.json).
  No se conectó TIA ni se descargó ningún programa en esas regresiones.

La receta reproducible queda en [R17](../../../10-kb/20-recetas/R17-aceptacion-plcsim.md) y el
procedimiento y límites del host en [PLCSIM README](../../../30-tools/plcsim/README.md).

### Revalidación posterior — 2026-09-25

Esta entrada supersede el estado anterior de la fixture nueva: la propiedad ya no está desactivada
y Computer Use sí encuentra TIA en esta sesión.

- **Verificado:** la lectura MCP más reciente en la ruta exacta de `AgentDemo_V20` marcó ambos
  bloques como estándar, desprotegidos y consistentes, con `PLCSimAdvancedSupport=true`; las dos
  tags tienen `isSafety=false`. Evidencia: [preflight serializado](../../../70-runs/e2e/20260925-plcsim-scaffold/simulation-ready-live-preflight.json).
- **Verificado:** Computer Use nativo identificó TIA Portal V20 y el título apunta al clon
  `AgentDemo_V20`; la ventana quedó maximizada. La barra de estado indicaba `Project closed`, así que
  el estado UI/Openness no es inequívoco. [Registro](../../../70-runs/e2e/20260925-plcsim-scaffold/computer-use-tia-window-20260925.json).
- **Bloqueado:** `Assert-TiaFixtureManifest.ps1` no pudo leer el `.ap20` porque un proceso lo tenía
  abierto. Se observaron dos procesos de TIA Portal, uno sin título de ventana. No se cerró ni mató
  ninguno; no se puede revalidar que fixture y backup coincidan byte a byte.
- **No verificado:** no se creó una instancia PLCSIM en esta continuación; no hubo descarga, online
  PLC ni prueba funcional de `Cmd_Enable` → `Status_Active`.
- **Siguiente paso:** identificar y liberar el handle solo después de determinar que pertenece al
  fixture desechable; validar manifiesto o crear una copia limpia desde el backup coincidente;
  repetir el gate completo; luego usar Softbus y exigir `CPU-1500 Simulation` en el diálogo de TIA
  antes de descargar. La evidencia histórica de Softbus/Go Online y la opción activada no sustituye
  la prueba de descarga y comportamiento.

### Aceptación de compile/export en el fixture limpio — 2026-09-25

El lock del primer clon se evitó creando `retry-fixture-01` desde su backup cuyo hash coincidía con
el manifiesto. La copia nueva y el backup se compararon antes de generar el manifiesto. La lectura
aislada en una sesión MCP obtuvo árboles, bloques y tags; confirmó metadata explícita F/Safety y
`PLCSimAdvancedSupport=true` para ambos bloques, sin tags Safety.

- **Verificado:** `CompileSoftware(PLC_1)` devolvió `Success`, 0 errores y 0 avisos; `SaveProject`
  terminó correctamente.
- **Verificado con alcance parcial:** `ExportPlcAsSourceTree` reportó 3 objetos, 0 omitidos y 0
  fallidos, pero el árbol físico solo incluye las tablas de tags y `Main.s7dcl`; no incluye
  `FB_AgentDemo`. Se ejecutó `ExportBlock` explícito para el FB y el XML exportado identificó
  `FB_AgentDemo`, lenguaje SCL, interfaz `Enable`/`Active`; `GetBlockSource` devolvió 4.685
  caracteres sin truncamiento. El `exportPath` de `ExportBlock` es un directorio, donde TIA crea
  `FB_AgentDemo.xml`.
- **Verificado:** el manifiesto volvió a pasar después del ciclo y conservó el mismo snapshot
  `7620c14dca12987a7823e1b7d721672bd332fa32a67de5a96df62496ad3899b8` que el backup. Compile/save
  no cambiaron el árbol serializado, así que no hizo falta restauración por copia.
- **No probado por esta aceptación:** modificación funcional, roundtrip de importación, descarga,
  instancia PLCSIM, IP de CPU o comportamiento runtime. `Main.s7dcl` contiene un rung vacío; el FB
  mapea `Active := Enable`, pero no está llamado desde `Main`, así que no debe usarse para alegar
  aceptación conductual hasta incorporar una ruta de ejecución verificada.
- Computer Use no se usó en esta fase; la consulta visual e identificación de IP/destino simulado
  quedan pendientes después de las cancelaciones con Escape. TIA no se descargó.

Evidencia: [resumen de aceptación](../../../70-runs/e2e/20260925-plcsim-scaffold/retry-fixture-01/acceptance-summary.md),
[preflight](../../../70-runs/e2e/20260925-plcsim-scaffold/retry-fixture-01/safety-preflight-retry.json),
[compile/save/export/readback](../../../70-runs/e2e/20260925-plcsim-scaffold/retry-fixture-01/compile-export-readback.json),
[export explícito del FB](../../../70-runs/e2e/20260925-plcsim-scaffold/retry-fixture-01/block-export-readback.json),
y [schema write aislado](../../../70-runs/e2e/20260925-plcsim-scaffold/retry-fixture-01/tia-inspect-write-tools.json).

### Resolución documental de PLCSIM Advanced — 2026-09-25

Sí, TIA Portal puede conectarse a PLCSIM Advanced y cargar el hardware/programa en una CPU virtual.
Siemens documenta Softbus (`PLCSIM`) y TCP/IP. La compatibilidad de versión es obligatoria:
Advanced V6.0 UPD1 cubre proyectos TIA V14–V19 y firmware V1.8–V3.1; Advanced V7.0 cubre TIA
V14–V20 y firmware V1.8–V4.0. Este equipo tiene TIA V20, PLCSIM Standard V19 y Advanced V6.0.0.1,
por tanto la descarga V20 está bloqueada. La observación histórica `Go online` por Softbus solo
prueba conectividad parcial, no compatibilidad de fabricante, descarga o ejecución.

La ruta de agente queda centralizada en [R17](../../../10-kb/20-recetas/R17-aceptacion-plcsim.md)
y enlazada desde [AGENTS.md](../../../AGENTS.md) y [PLCSIM README](../../../30-tools/plcsim/README.md).
Cuando se instale Advanced V7 o posterior con soporte V20 y se valide el adaptador/API, el flujo será:
fixture aislada; compatibilidad exacta TIA/Advanced/CPU/firmware; preflight F/Safety y protección;
activar compilación simulable y compilar 0/0; una instancia Softbus en `PLCSIM`; identificar en TIA
la CPU simulada; descargar, pasar a RUN, ejecutar un plan de E/S con valores esperados, apagar y
conservar evidencia. TCP/IP se reserva para pruebas Ethernet en `<Local>` con NIC Siemens aislada.

Fuentes Siemens: [compatibilidad Advanced V7 con proyectos TIA V14–V20](https://support.industry.siemens.com/forum/ww/uk/posts/simatic-s7-plcsim-advanced-v7-0-download-incl-trial-license/326239/?page=0&pageSize=10&viewmode=print), [manual Advanced V7](https://support.industry.siemens.com/cs/attachments/109977691/s7-plcsim_advanced_function_manual_en-US_en-US.pdf), [manual Advanced V6 UPD1](https://cache.industry.siemens.com/dl/files/578/109955578/att_1267815/v1/s7-plcsim_advanced_function_manual_en-US.pdf), [qué es Advanced/Softbus](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_20/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced-api/product-overview/what-is-s7-plcsim-advanced), [compilación simulable V20](https://docs.tia.siemens.cloud/r/en-us/v20/editing-projects/creating-and-managing-projects/displaying-properties-of-the-project).

**Estado local:** compilación 0/0, save y export/readback de la fixture se verificaron antes; no hubo descarga ni prueba funcional. La evidencia y el bloqueo por versiones están en [auditoría](../../../70-runs/tia-capabilities/20260925-plcsim-version-compatibility-audit.md) y [readiness](../../../70-runs/simulation/readiness-latest.json).
### Revalidación de gates y estado UI — 2026-09-25

Se revalidó el manifiesto de `retry-fixture-01`: snapshot y backup coinciden en
`7620c14dca12987a7823e1b7d721672bd332fa32a67de5a96df62496ad3899b8`. Pasaron las regresiones
`Test-InvokeTiaSimulationAcceptance.ps1` y `Test-TiaSimulationAcceptanceSafety.ps1`; su alcance es
adaptadores/servidores simulados, no una descarga live. `Test-TiaCreationRecipes.ps1` detectó que
R07 decía “no verificada” donde el contrato requiere el estado explícito “no verificado”; se corrigió
la redacción y pasó en la repetición. `Test-DocumentationState.ps1` también pasó.

El inventario nativo de Computer Use encontró TIA Portal V20 con una ventana cuyo título pertenece
a la fixture hermana `20260925-plcsim-scaffold/isolated-fixture`, no a la fixture objetivo
`retry-fixture-01/isolated-fixture`. Se leyó el estado visual, no se interactuó, reemplazó ni cerró
el proyecto. No se lanzó instancia PLCSIM ni hubo descarga, RUN o prueba funcional. Evidencia:
[revalidación de gates y UI](../../../70-runs/tia-capabilities/20260925-simulation-guard-and-documentation-revalidation.json).

### Auditoría oficial de compatibilidad TIA/PLCSIM Advanced — 2026-09-25

La revisión oficial encontró que la guía anterior “TIA V20 + PLCSIM Advanced V6” era incorrecta:
el manual Siemens de Advanced V6.0 UPD1 limita el soporte a TIA V14–V19/FW V1.8–V3.1; Siemens
indica que Advanced V7.0 admite proyectos TIA V14–V20 y firmware V1.8–V4.0. La evidencia histórica
de `Go online` por Softbus solo demuestra conectividad parcial; no acredita una descarga compatible.

- **Verificado:** están instalados TIA V20, PLCSIM Standard V19 y PLCSIM Advanced V6.0.0.1; consulte
  el inventario Windows del 2026-09-25 y `70-runs/simulation/readiness-latest.json`.
- **Bloqueado:** V20 + Advanced V6 no cumple la matriz de fabricante. No se debe iniciar el runner
  de descarga con esa pareja.
- **Ruta marcada para agentes:** comprobar versiones TIA/Advanced/CPU/FW; usar Advanced V7.0 o
  posterior con cobertura V20; validar el adaptador/API; trabajar en una fixture aislada; pasar
  preflight F/Safety/protección; activar compilación simulable y compilar 0/0; iniciar una sola CPU
  virtual por Softbus `PLCSIM`; verificar el aviso de destino simulado; descargar, pasar a RUN,
  ejecutar un plan funcional de E/S y limpiar la instancia. TCP/IP queda para pruebas Ethernet en
  `<Local>` con NIC Siemens aislada.
- **No verificado:** V7 no está instalado y el adaptador/API C++ actual se probó contra V6; hay que
  validar esa implementación con V7 antes de habilitar la descarga automatizada.

Fuentes: [compatibilidad Advanced V7 con TIA V14–V20](https://docs.tia.siemens.cloud/r/en-us/v20/what-s-new-in-tia-portal/changes-in-previous-versions-of-tia-portal/changes-in-tia-portal-v19/engineering-options), [manual Advanced V7](https://support.industry.siemens.com/cs/attachments/109977691/s7-plcsim_advanced_function_manual_en-US_en-US.pdf), [manual Advanced V6 UPD1](https://cache.industry.siemens.com/dl/files/578/109955578/att_1267815/v1/s7-plcsim_advanced_function_manual_en-US.pdf), [estado local](../../../70-runs/simulation/readiness-latest.json).

### Preparación de la aceptación tras instalar PLCSIM Advanced V7 — 2026-09-25

El usuario ha iniciado la instalación de PLCSIM Advanced V7. Mientras el instalador está activo,
no se interactúa con TIA/PLCSIM ni se ejecutan pruebas que creen o administren CPUs virtuales. La
instalación comunicada por el usuario no acredita todavía la versión instalada, la inicialización
del API, la compatibilidad del adaptador, la descarga ni el comportamiento runtime.

- **Verificado:** el paquete portable se reconstruyó desde el origen actual en un directorio
  temporal, pasó `Test-PortablePackage.ps1`, `Test-PortablePackageContent.ps1` y
  `Test-PortableInstallRelocation.ps1`; después se promovió a `TIA-Claude_Portable/dist`. La copia
  anterior se conservó en `90-tmp/portable-dist-before-refresh-20260925`. El paquete nuevo declara
  322 archivos core y 658 de ejemplos. Las pruebas de instalación y traslado verificaron hashes de
  322 archivos del core.
- **Verificado:** pruebas dirigidas de las regresiones `Test-TiaSimulationAcceptanceSafety.ps1` y
  `Test-TiaAcceptanceStatus.ps1` pasaron tras ajustar sus fixtures para que el resultado no dependa
  del orden de la suite ni de campos de readiness obsoletos. La prueba `Test-PlcSimNativeAdapter.ps1`
  también pasó contra el API V6 presente en ese momento; incluyó ciclo de vida y limpieza de una
  instancia virtual desechable, sin descargar un proyecto.
- **Revalidado durante la instalación:** volvieron a pasar las pruebas de aceptación local, estado,
  recetas y consistencia documental; `git diff --check` no encontró errores. El registro separa
  estos mocks de toda prueba live en [comprobaciones locales pre-V7](../../../70-runs/checks/20260925-plcsim-pre-v7-local-tests.md).
- **Corregido y verificado en prueba dirigida:** el adaptador rechazaba silenciosamente una opción
  `--interface` desconocida y podía continuar con el transporte configurado. Ahora falla antes de
  crear la instancia con `unsupported-interface-argument`; la prueba de regresión comprueba esa
  parada. Esta prueba no autoriza una interfaz de red ni demuestra Softbus con TIA.
- **No aceptada:** la primera suite completa guardada en
  [latest.json](../../../70-runs/checks/latest.json) terminó con 44 PASS, 2 WARN y 3 BLOCKED.
  Encontró los dos defectos de pruebas corregidos arriba; el bloqueo del adaptador ocurrió antes de
  confirmar la regresión de opción desconocida. Un segundo intento fue interrumpido antes de generar
  un informe final, así que no cuenta como suite completa aprobada.
- **Pendiente tras el instalador:** comprobar Doctor/inventario de versiones, versión real del API
  PLCSIM, compatibilidad con TIA V20 y CPU/FW objetivo; compilar y probar el adaptador contra V7; y
  después, solo si los gates de seguridad y manifiesto pasan, ejecutar la aceptación PLC en una
  fixture limpia con Softbus. La descarga simulada y los casos funcionales observados siguen
  pendientes.
- **Hallazgo de implementación para V7:** el builder nativo y el probe administrado apuntan
  actualmente a `API\6.0` de forma fija. Tras instalar, hay que comprobar la ruta/ABI real del API V7
  y cambiar la selección de versión para que el adaptador compile y cargue esa API explícitamente;
  no basta con que el panel V7 aparezca instalado ni con pasar la prueba histórica V6.

### Resultado de instalación y pruebas de PLCSIM Advanced V7 — 2026-09-25

El usuario confirmó que PLCSIM Advanced V7 terminó de instalarse. La aceptación se retomó sin cerrar
la aplicación: TIA Portal V20 quedó abierto y maximizado con el proyecto desechable
`70-runs/e2e/20260925-plcsim-scaffold/retry-fixture-01/isolated-fixture/project/AgentDemo_V20/AgentDemo_V20.ap20`.

- **Verificado:** el API instalado es 7.0.0.0 (`API\7.0`), declara la interfaz `0x00070000` e
  inicializa/libera correctamente. El adaptador nativo, compilado para V7, creó, encendió, apagó y
  limpió una instancia temporal por Softbus; los códigos fueron `0x0` y el recuento final fue cero.
  Evidencias: [probe V7](../../../70-runs/simulation/20260925-api7-probe.json), [ciclo V7](../../../70-runs/simulation/20260925-api7-native-lifecycle.json), [estado limpio](../../../70-runs/simulation/20260925-api7-posttest-clean.json) y repetición [ciclo V7](../../../70-runs/simulation/20260925-api7-native-lifecycle-repeat.json).
- **Verificado:** readiness detecta TIA V20 + Advanced V7 compatibles, API 7 y adaptador virtual
  listo. Las suites `Test-SimulationReadiness`, `Test-InvokeTiaSimulationAcceptance`,
  `Test-TiaSimulationAcceptanceSafety`, `Test-PlcSimRuntimeApiProbe`, `Test-PlcSimApiSelection`,
  `Test-PlcSimNativeAdapter`, `Test-TiaAcceptanceStatus`, `Test-TiaCreationRecipes`,
  `Test-DocumentationState` y `Test-PortablePackageContent` terminaron PASS. `git diff --check` no
  encontró errores; solo informó conversiones de fin de línea.
- **Verificado en UI:** TIA abrió con éxito `AgentDemo_V20` desde la ruta exacta de la fixture; el
  árbol muestra `PLC_1 [CPU 1513-1 PN]`. La ventana sigue maximizada. No se descargó el proyecto ni
  se afirmó comportamiento PLC.
- **Bloqueado por preflight del perfil de descarga:** `tia-create full` ofrece `DownloadToPlc`, pero
  el roster live no publica `GetTags` y `GetBlocks` no aporta metadata explícita `isFailsafe`.
  `tia-inspect` sí leyó metadata completa en una sesión distinta; esa evidencia no se combina para
  autorizar la descarga. Mantener el gate y no llamar `DownloadToPlc` hasta disponer de clasificación
  F/Safety completa en la misma sesión mutante.
- **Bloqueado el hash posterior a abrir:** `Assert-TiaFixtureManifest.ps1` no pudo calcular el hash
  del `.ap20` porque TIA lo mantiene bloqueado. No se guardó ni editó desde el agente; no se cierra
  TIA para liberar el archivo sin autorización. Verificar/restaurar el snapshot cuando el proyecto
  se libere, antes de cualquier escritura.
- **No verificado:** conexión de descarga TIA ↔ CPU virtual, primera descarga, paso a RUN y plan de
  E/S con observaciones funcionales. API Softbus y compatibilidad de versiones por sí solas no
  prueban esa ruta.

La solución local para seleccionar API ya no fija V6: `Resolve-PlcSimApi.ps1` elige la versión
instalada que tenga DLL y cabecera coincidentes, el builder genera `bin\v7`, y las pruebas
comprueban selección explícita y automática. La preflight F/Safety del perfil de descarga quedó
resuelta en el registro siguiente; aún falta regenerar/verificar la fixture libre y repetir R17 con
Softbus.

### Barrera F/Safety y preflight de descarga para tia-create — 2026-09-25

- **Implementado:** se versionó un patch contra el commit upstream fijado de `tia-create`.
  `GetBlocks` ahora devuelve `isFailsafe` nullable, `GetTags` enumera tags anidados con
  `isSafety`, y `DownloadToPlc` vuelve a clasificar globalmente el PLC dentro de la propia sesión
  antes de configurar una ruta o iniciar cualquier operación online. Rechaza clasificación nula,
  objetos F/Safety, cero bloques enumerados y bloques con know-how protection.
- **Verificado:** build reproducible desde `30-tools/mcp/tia-create/build.ps1`: 0 errores y dos
  advertencias existentes (MSB3539 de rutas de salida y CS8602 en `OpcUaLiveReader.cs`). Doctor
  confirmó TIA/Openness V20 y pertenencia al grupo Siemens. Smoke test lite detectó 56 tools,
  incluyendo `GetTags`; disponibilidad y `git diff --check` pasaron.
- **Verificado live, solo lectura:** desde el binario instalado en `30-tools/mcp/tia-create/bin/v20`,
  la secuencia serializada Bootstrap → Connect → AttachToOpenProject → GetProjectTree →
  GetBlocks → GetTags → Disconnect adjuntó `AgentDemo_V20`. El árbol confirmó `PLC_1`; leyó
  `Main` y `FB_AgentDemo` con `isFailsafe=false`, `isConsistent=true`,
  `isKnowHowProtected=false`, y los dos tags `isSafety=false`. Evidencia:
  [lectura live instalada](../../../70-runs/tia-capabilities/20260925-tia-create-safety-live-read-built.json).
- **No probado todavía:** ejecutar una descarga aceptada o probar en TIA una fixture con F/Safety
  para observar el veto; no se creó ningún objeto Safety. La barrera compila y la ruta está
  conectada antes de la operación mutante, pero la prueba de rechazo específica se mantiene
  pendiente. No se descargó el PLC.
- **Siguiente gate:** liberar/restaurar la fixture que TIA aún mantiene abierta, verificar hash del
  manifiesto, compilar para simulación, confirmar el diálogo `CPU-1500 Simulation`, y solo entonces
  usar R17 en Softbus para probar carga/RUN/comportamiento. La ventana de TIA sigue maximizada.
