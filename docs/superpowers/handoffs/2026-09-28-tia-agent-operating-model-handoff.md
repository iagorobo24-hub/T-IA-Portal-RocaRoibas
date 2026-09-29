# Handoff — TIA agent operating model

**Fecha:** 2026-09-28  
**Objetivo:** continuar el plan maestro en `docs/superpowers/plans/2026-09-21-tia-agent-operating-model.md`.  
**Estado global:** abierto; `accepted=false`. Se preparó primero el trabajo local y luego se hizo una inspección gráfica; no hubo descarga ni cambios de ingeniería guardados deliberadamente. Al intentar cerrar el proyecto, TIA mostró un aviso de cambios sin guardar, por lo que el estado exacto del documento debe volver a observarse antes de actuar.

## Resultado live recuperable de PLCSIM

La fixture para la siguiente prueba es:

`70-runs/e2e/20260928-objective-resume-acceptance-supported/isolated-fixture/`

El manifiesto validó y el hash del `.ap20` coincidió con su backup: `4817178749bd4ef8b23586d65665ae0ac673773a9a307868a411aca9b05896c4`. La secuencia MCP guardada en `%TEMP%` se resumió en [20260928-objective-resume-preflight.json](../../../70-runs/simulation/20260928-objective-resume-preflight.json).

**Preflight verificada:** proyecto `AgentDemo_V20`, árbol con `PLC_1`, compilación `Success` con 0 errores y 0 avisos, bloques `Main` y `FB_AgentDemo` estándar/no protegidos/consistentes, `PLCSimAdvancedSupport=true` en ambos, dos tags con clasificación completa y `isSafety=false`, IP `192.168.0.1`, readiness `Ready=true` y una ruta exacta `PLCSIM`. La CPU virtual V7 se inició por Softbus dentro del runner.

**Aceptación no verificada:** el runner no produjo el informe final. No hay resultado guardado de `DownloadToPlc`, `Online`, plan de E/S ni limpieza API confirmada. El proceso de prueba que había quedado activo se interrumpió desde su sesión de shell. Computer Use mostró en PLCSIM Advanced V7 una instancia registrada `TIAClaudeAcceptance_1513`, CPU1513, `192.168.0.1`; la lista dice `1 Active PLC Instance(s)`. La selección UIA habilita los controles RUN/STOP, pero el árbol no informa el estado LED y no hay respuesta API `stopped`. **No se pulsó RUN, STOP, Power ni Unregister**; no se puede concluir que el PLC esté en RUN, que recibiera el programa ni que la instancia pertenezca exclusivamente a esta ejecución. Mantenerla intacta hasta verificar identidad/estado y decidir la limpieza.

### Fixture limpia preparada fuera de TIA

Como la instancia GUI conserva un diálogo de guardado cuyo estado quedó indeterminado, se preparó una
copia nueva sin abrirla en TIA:

`70-runs/e2e/20260928-objective-resume-hardware-compile/isolated-fixture/`

Su `.ap20` se copió del backup verificado de la fixture anterior. El hash del árbol de ingeniería
del clon y su backup coincide (`00d108f3ef9b10de26788fb348b5020268828457bda7922b68262fb6f176c814`),
y `Assert-TiaFixtureManifest.ps1` pasó. Los baselines de inventario se preservaron fuera de los dos
árboles comparados para que no contaminaran el snapshot. Esta copia aún no se ha abierto, compilado
ni modificado en TIA; debe volver a validarse justo antes de usarla.

### Hallazgo gráfico de compilación y certificado — 2026-09-28

En `Load preview`, TIA mostró `The software needs to be compiled` y
`Compilation of hardware configuration was completed with error`; el panel Compile indicaba 3
errores y 1 aviso. El error visible dice que no se puede configurar el certificado de comunicación
del PLC sin la contraseña de los datos de configuración confidenciales. El aviso indica que el
display de la CPU no tiene protección por contraseña. No se inició la descarga. Esto no contradice
el resultado MCP `CompileSoftware=Success` 0/0: ese resultado fue de software y no eliminó el fallo
de compilación de hardware mostrado por TIA.

El usuario aclara que los proyectos del workspace son fixtures generadas o proyectos abiertos
migrados, y que no debe haber contraseña que pedir o introducir. Para esta prueba no inventar ni
crear una clave. La siguiente acción, una vez que el proyecto vuelva a estar libre y se valide una
nueva copia desechable con backup/manifiesto coincidentes, es desactivar en esa copia
`PLC_1 > Properties > Protection & Security > Protection of the PLC configuration data`, compilar
hardware/software y volver a leer los errores antes de considerar una descarga.

La revisión de la API Openness V20 halló una vía sin clave: `PlcMasterSecretConfigurator` expone
`MasterSecretConfiguration`; cuando vale `WithoutPassword`, `Unprotect()` sin argumentos la deja en
`None`. Siemens documenta esta operación. En ese momento no existía wrapper MCP acotado; la
actualización al final de este handoff registra el wrapper implementado, su build y el estado de su
primera prueba live.

Después de cancelar `Load preview`, se intentó cerrar el proyecto y TIA mostró `Project has been
modified. Do you want to save changes?`. No se guardó. La interacción siguiente fue rechazada por
el detector de actividad del usuario; no se conoce el estado actual de ese diálogo o la ventana. En
la próxima fase gráfica, primero volver a observar estado e identidad; no enviar una tecla basada en
la observación antigua.

En la reobservación posterior de esta sesión, `list_windows` devolvió una ventana de proceso TIA V20
con título genérico `Totally Integrated Automation Portal`; `get_window_state` indicó que está
minimizada. El intento de restaurarla fue interrumpido por detección de actividad del usuario y una
segunda lectura confirmó que seguía minimizada. No se enviaron más acciones. Proyecto/diálogo actual
y estado maximizado **no confirmados**; la próxima sesión debe refrescar y verificar la identidad
antes de interactuar.

## Estado de Computer Use — 2026-09-28

- `Doctor` de `tia-inspect` V20: `Connected=False`, `No project open`, V19/V20 Engineering y Portal `OK`, grupo Openness `True`, solo lectura.
- La primera enumeración entregó el ID TIA `133036` con un título antiguo de la fixture `20260928-objective-resume`; `get_window` rechazó el ID como inexistente. El inventario actualizado no contenía TIA.
- Se inició el ejecutable V20 exacto (`C:\Program Files\Siemens\Automation\Portal V20\Bin\Siemens.Automation.Portal.exe`). El primer retorno no expuso ventana; tras refrescar más tarde apareció TIA en la página Start, sin proyecto abierto. Se maximizó (la ventana final permanece maximizada).
- Después se abrió correctamente, mediante el diálogo estándar, el archivo exacto del manifiesto validado: `70-runs/e2e/20260928-objective-resume-acceptance-supported/isolated-fixture/project/AgentDemo_V20/AgentDemo_V20.ap20`. El título de TIA mostró esa ruta y confirmó que el proyecto se abrió. Se dejó la ventana maximizada. El diálogo empezó en otra copia con el mismo nombre; por ello la ruta exacta debe comprobarse antes de seleccionar un proyecto reciente.
- En TIA se inspeccionaron `PLC_1 [CPU 1513-1 PN]`, `Main [OB1]`, `FB_AgentDemo [FB1]`, el SCL del FB y Device configuration. No se editó ni guardó el proyecto. Se abrió el menú Online, pero no se obtuvo el asistente de descarga ni evidencia visual de destino; no se intentó descargar. Firmware no confirmado visualmente.
- Computer Use sí inspeccionó PLCSIM Advanced V7. Su árbol UIA devuelve el nombre `TIAClaudeAcceptance_1513 / CPU1513 / 192.168.0.1` y `Run/Stop LED`, pero no el valor actual de los LED. Esto demuestra que UIA puede leer controles de este panel; no prueba automatización aceptada ni funcionamiento del PLC.
- La preferencia de ventana queda satisfecha: TIA permanece maximizada con la fixture exacta abierta. El asistente de descarga debe volver a identificar inequívocamente el destino antes de seguir.

La ejecución anterior sobre otra copia se bloqueó correctamente porque sus dos bloques tenían `PLCSimAdvancedSupport=false`. No mezclar esa evidencia con la fixture `supported` de arriba.

## Cambios de preparación realizados

- El runner `Invoke-TiaSimulationAcceptance.ps1` resuelve `ProjectFile` relativo contra `WorkspaceRoot` y lo registra como ruta absoluta.
- Guarda snapshots atómicos del informe antes de arrancar, al abrir cada secuencia MCP y después de recibirla. Un informe interrumpido conserva `phase`, `activeSequence` y `outputPath` para no confundir una espera con una aceptación terminada.
- Si una preflight devuelve fallo y un archivo de secuencia, conserva las llamadas recibidas en el informe en vez de perderlas tras lanzar un error genérico.
- El runner exige ahora `-SimulationTargetEvidencePath` antes de arrancar adaptador/MCP. Valida vigencia (30 min), versión, `.ap20`, nombre de proyecto, dispositivo, IP, ruta PG/PC, ventana maximizada, nombre `CPU-1500 Simulation` y aviso de CPU simulada; el informe registra el hash SHA-256 de la evidencia.
- La prueba dirigida `Test-InvokeTiaSimulationAcceptance.ps1` pasó, incluidas las negativas F/Safety/metadata/simulación y el caso de ruta relativa.
- `AGENTS.md`, la matriz de conexión y la guía de interfaz ahora distinguen TIA Desktop de un runtime web y documentan UI Automation como candidato condicionado a controles semánticos verificados.

## Playwright y automatización de escritorio

Playwright automatiza páginas en navegadores, no los controles nativos de TIA Portal Desktop. Para la aplicación de ingeniería:

1. Usar MCP/Openness primero cuando el perfil exponga la operación.
2. Usar Computer Use nativo para descubrir el flujo, comprobar identidad y leer renderizado/diálogos. Mantener TIA maximizado.
3. Solo después inspeccionar UI Automation (UIA) y automatizar controles con `Name`/`AutomationId` y patrón único. No usar posiciones de pantalla ni `SendKeys` ciego para mutaciones.
4. Revalidar el estado visual y por MCP tras cada acción. Empezar en una fixture desechable.
5. Reservar Playwright para una HMI/runtime realmente servido en navegador; la compatibilidad por modelo/runtime todavía requiere prueba.

Se añadió `30-tools/scripts/Get-TiaUiAutomationInventory.ps1` como herramienta **solo lectura** para enumerar el árbol UIA de una ventana seleccionada por PID y título. No activa ventanas ni ejecuta patrones; no lee valores de campos. Aún no se ha ejecutado ni aceptado. La presencia de nombres UIA observados con Computer Use justifica esta inspección controlada, pero no prueba que sus selectores sean estables ni que una acción UIA funcione.

Referencias oficiales: [Playwright — Browsers](https://playwright.dev/docs/browsers) y [Microsoft UI Automation](https://learn.microsoft.com/en-us/windows/win32/winauto/entry-uiauto-win32).

## Siguiente orden de trabajo

1. Computer Use identificó TIA Portal V20, mostró `Project closed` y la dejó maximizada. Al intentar leer los controles siguientes, la herramienta notificó que Computer Use se detuvo con Escape; en el próximo turno vuelve a inventariar y verifica la ventana antes de actuar. No hay proyecto abierto en la ventana observada.
2. La fixture válida para continuar es `70-runs/e2e/20260928-objective-resume-hardware-compile/isolated-fixture/`; su manifiesto y backup coinciden. No usar `20260928-objective-resume/isolated-fixture`, que ahora falla el validador.
3. Ya se ejecutó en el perfil aislado de escritura la secuencia `GetProjectTree` → clasificación completa `GetBlocks`/`GetTags` → `DisableUnconfiguredPlcConfigurationProtection`. Resultado: `WithoutPassword → None`; la segunda llamada leyó `None → None`, `changed=false`; `CompileSoftware` terminó con 0 errores/0 avisos. El proyecto se cerró sin guardar; hash clon y backup siguen `00d108f3ef9b10de26788fb348b5020268828457bda7922b68262fb6f176c814`. [Evidencia live](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/plc-configuration-protection-live-evidence.json). `GetDeviceItemInfo` dio error genérico; no se usó como autoridad.
4. Para demostrar que resuelve el error de certificado/configuración, repetir la mutación aislada en esta fixture, compilar software, guardar el cambio en el clon y abrirlo en TIA maximizado para compilar hardware. Capturar errores/avisos completos; restaurar el clon desde backup al terminar. No declarar arreglado el error hasta que compile hardware.
5. La distribución portable se reconstruyó desde el build V20 actual y las pruebas de contenido, manifiestos e instalación/relocación pasaron. La distribución antigua está preservada en `90-tmp/portable-dist-pre-20260928-objective-resume`.
6. Después de verificar la compilación hardware, confirmar firmware/modelo CPU en la matriz oficial V7 y revisar visualmente el asistente de descarga. Antes de descargar, exigir `CPU-1500 Simulation` y el aviso `The downloads are performed on a simulated CPU`; detenerse ante destino ambiguo. Guardar evidencia R17; `-AcknowledgeVirtualTarget` no reemplaza la observación visual.
7. Solo con evidencia de target reciente y manifiesto/backup vigentes, ejecutar descarga a PLCSIM por Softbus `PLCSIM`; exigir respuesta `Success`, estado `Online` y resultados funcionales. Identificar la instancia antes de reutilizarla o limpiarla; no pulsar RUN/STOP/Power/Unregister a ciegas.
8. Completar las fixtures conductuales de R18 (analógicas), R19 (diagnóstico/comunicaciones) y R20 (HMI por modelo/runtime), y cubrir la matriz de acciones MCP/Openness/UI.
9. Mantener pendientes externos explícitos: confirmación del propietario de que la credencial histórica MindSphere fue revocada y disponibilidad/aceptación de WinCC Runtime Advanced V20. No divulgar la credencial. Mantener `accepted=false` mientras falte evidencia runtime/comportamiento o revocación.

## Actualización posterior — wrapper sin contraseña

El usuario confirma que las fixtures del workspace son generadas o proceden de proyectos abiertos y
que no debe pedirse ni introducirse contraseña. `WithoutPassword` significa que la opción de
protección está activada pero el PLC no tiene Master Secret configurado; el mensaje de compilación
no prueba que exista una clave. El flujo no crea ni intenta adivinar contraseñas y nunca llama a
`Reset()`.

Se añadió la herramienta `DisableUnconfiguredPlcConfigurationProtection` al `tia-inspect` V20. La
operación exige perfil aislado con fixture/manifiesto, pasa por el barrido global F/Safety y la
transacción exclusiva, lee el estado antes de mutar, actúa solo ante `WithoutPassword` mediante
`Unprotect()` sin argumento y exige readback `None`. Ante `WithPassword`, servicio ausente o estado
desconocido, falla cerrada. El cambio permanece en memoria y requiere `SaveProject`.

**Verificado localmente:** build V20 limpio con 0 errores y 2 warnings nullable (`CS8602`) en
`McpPrompts.cs` y `Portal.Documents.cs`, fuera del wrapper; `Doctor` quedó desconectado, V20 activo y Openness=true.
El perfil aislado de escritura enumera 85 herramientas e incluye el esquema de la nueva operación;
el perfil read enumera 53 y la excluye. Ninguna de las dos llamadas `tools/list` conectó a un
proyecto.
Evidencias: [build](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/tia-inspect-v20-clean-build.log),
[esquema](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/isolated-fixture/write-tool-registration-evidence.json)
y [roster del build limpio](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/isolated-fixture/write-tools-list-after-clean-build.json).
El manifiesto y backup siguen coincidentes: SHA-256
`00d108f3ef9b10de26788fb348b5020268828457bda7922b68262fb6f176c814`.

**Verificado live:** `Connect`, `OpenProject`, `GetProjectTree`, `GetSoftwareTree`, `GetBlocks` y
`GetTags` funcionaron en la fixture. `GetDeviceItemInfo` devolvió un error genérico. La nueva
herramienta leyó `WithoutPassword`, pasó a `None`, y una segunda llamada confirmó `None` sin cambio;
`CompileSoftware` terminó con 0 errores y 0 avisos. El proyecto se cerró sin guardar porque falta
la compilación hardware; el clon sigue idéntico al backup. Ver
[lecturas](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/read-preflight-metadata.json)
y [resultado live](../../../70-runs/e2e/20260928-objective-resume-hardware-compile/plc-configuration-protection-live-evidence.json).

**Verificado portable/documentación:** `dist` ahora contiene el `tia-inspect` V20 del build local
(SHA-256 coincidente); pasaron los checks de manifiesto/contenido e instalación/relocación.
`Test-DocumentationState.ps1` también pasó. La distribución anterior se conservó en
`90-tmp/portable-dist-pre-20260928-objective-resume`.

**Pendiente:** compilar hardware después de guardar la corrección en la fixture; no se ha probado
PLCSIM ni se ha descargado a target alguno. Computer Use identificó TIA V20 maximizado y sin
proyecto; el siguiente paso de captura fue interrumpido por Escape. Reanudar con inventario nativo
nuevo y solo abrir la fixture validada. No pedir ni introducir contraseñas, no llamar `Reset()` y no
guardar si la compilación falla.

## Preservación

El árbol de trabajo contiene numerosas modificaciones previas sin commit. No ejecutar resets, limpieza recursiva ni restauraciones amplias. Revalidar cada manifiesto antes de abrir o escribir la fixture.
