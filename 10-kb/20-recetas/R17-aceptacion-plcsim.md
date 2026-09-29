# R17 — Aceptación conductual en PLCSIM Advanced

## Objetivo y alcance

Demostrar que un programa descarga a una instancia PLCSIM virtual y responde a un plan
especificado de entradas y observaciones. Compilar, descargar o ver `Online` no prueba por sí solo
el comportamiento del PLC.

Esta receta cubre solo la ruta PLC. Runtime HMI tiene su propio preflight por modelo. No se usa una
NIC física como sustituto si la instancia virtual no está disponible. Si el PLC es una F-CPU, no se
editan F-blocks ni tags de Safety.

## Herramientas y precondiciones

- TIA Portal V20 y el proyecto desechable exacto están verificados.
- Identifica la CPU y su firmware desde el proyecto, y comprueba esa combinación en la tabla
  **Supported CPUs** de la versión instalada de PLCSIM. La compatibilidad cambia por familia,
  firmware y versión; si la CPU no aparece literalmente en esa tabla, detente y determina qué
  edición de S7-PLCSIM corresponde. Aunque Siemens admite algunas F-CPU en PLCSIM Advanced, el
  contrato de este workspace excluye descargas de proyectos con F-blocks/tags Safety: este flujo
  solo acepta un programa clasificado completamente como estándar.
- El preflight de `Write-TiaSimulationReadiness.ps1` confirma `plcToolchainReady=true` y
  `tiaInstanceSafeForApply=true`. La instancia debe confirmar en runtime `status=ready`, modelo
  estándar no F, y modo `SOFTBUS` (predeterminado) o TCP/IP local aislado. El estado `Up` de una
  NIC no demuestra conectividad.
- En las propiedades del proyecto (pestaña **Protection**) está activa **Support simulation
  during block compilation**. Siemens indica que esta opción viene desactivada por defecto. Debe
  guardarse y recompilarse el proyecto después de activarla. En la fixture `AgentDemo_V20`, el
  2026-09-24 se activó en TIA, se guardó y compiló con `Success`, 0 errores y 0 avisos. Una nueva
  lectura de `GetBlocks` confirmó `PLCSimAdvancedSupport=true` y `isConsistent=true` en `Main` y
  `FB_AgentDemo`. Evidencia: `70-runs/acceptance/plcsim-visible-compile-20260924.json` y
  `plcsim-postcompile-inspection-20260924.json`. El snapshot con esta opción activa y su backup
  coincidente están en `90-tmp/e2e/20260924-plcsim-simulation-support-enabled/`; su manifiesto fue
  validado. La relectura de la copia final adjunta a la ventana visible volvió a dar `true` en ambos
  bloques: `plcsim-enabled-fixture-readback-20260924.json`. La fixture original se restauró desde su
  backup y también volvió a validar su manifiesto.
- Esa lectura **no autorizaba la descarga con el contrato antiguo del runner**: el perfil
  `tia-create full` ya publica `GetTags` y `GetBlocks.isFailsafe` gracias al build local
  descrito en [`tia-create/README.md`](../../30-tools/mcp/tia-create/README.md). El binario
  patched expone `GetBlocks.isFailsafe` y `GetTags` con `items`, `meta.count`, `meta.complete`
  y `meta.success`; `DownloadToPlc` vuelve a hacer preflight global F/Safety/protección dentro
  de la misma sesión Openness (`EnsureNoSafetyObjectsForDownload`), inmediatamente antes de
  cualquier configuración de descarga. El runner repite esa clasificación en su preflight y el
  servidor la repite en la sesión de descarga: defensa en profundidad, no sustitución. Lectura
  live estándar: dos bloques no F y no protegidos, dos tags no Safety en
  [`20260925-tia-create-safety-live-read-built.json`](../../70-runs/tia-capabilities/20260925-tia-create-safety-live-read-built.json).
  No se ha probado todavía el rechazo live de una fixture Safety.
- La raíz de la fixture tiene `.tia-agent-fixture.json` con la ruta exacta del `.ap20` y backup.
- Se obtuvo `DevicePath` y `SoftwarePath` de `GetProjectTree` y `GetSoftwareTree` en esa sesión.
- Se leyó la IP configurada con `GetDeviceIpAddress` para el `DevicePath` exacto. En `tia-create
  lite`, buscar primero con `FindTools` y ejecutar con `CallTool`; el runner full llama la herramienta
  directamente. `TargetIpAddress` debe coincidir con la IP del proyecto. En Softbus, el runtime debe
  informar `ip=null`, por lo que no se compara con la IP configurada del PLC; en TCP/IP local, la IP
  del runtime/adaptador virtual sí debe coincidir con esa IP objetivo.
- PLCSIM Advanced crea y mantiene una instancia virtual desechable. Para Softbus se espera
  `networkMode=SOFTBUS`, `interfaceName=PLCSIM`, `binding=local-only`; para TCP/IP local se espera
  `TCPIP_SINGLE_ADAPTER`, NIC Siemens e IP fija en la misma subred. Estar `Up` no prueba que la CPU
  esté registrada o sea accesible.
- Se reconoce explícitamente `-AcknowledgeVirtualTarget`. El runner exige que se gestione la
  instancia con `-StartVirtualPlc`; no acepta un target externo sin identidad leída por el runner.
- La descarga exige además `-SimulationTargetEvidencePath` con una observación reciente de
  Computer Use. El runner comprueba que coincida con el proyecto, dispositivo, TIA, IP y ruta de
  esta ejecución, y que registre la ventana maximizada, `CPU-1500 Simulation` y el aviso de CPU
  simulada. El switch de reconocimiento por sí solo no autoriza la descarga.
- El plan existe, es JSON válido con `schemaVersion=1`, tiene pasos conocidos por el adaptador y
  cada operación de lectura comprueba un valor funcional además de `status`/`op`. El plan se
  valida antes de iniciar PLCSIM o llamar a `DownloadToPlc`.
- Toda observación simbólica del plan debe apuntar a un tag de salida confirmado por la tabla de
  tags/logic exportada del proyecto. El runner compara el valor que devuelve PLCSIM; no deduce por
  sí solo la dirección funcional de un tag.

## Procedimiento operativo y compatibilidad de versiones

Sí: TIA Portal/STEP 7 y S7-PLCSIM Advanced se conectan para cargar y ejecutar el PLC virtual.
Siemens documenta Softbus (`PLCSIM`) y TCP/IP. **La compatibilidad de versiones es un gate previo
obligatorio:** el manual V6.0 UPD1 cubre proyectos TIA V14–V19 y CPU FW V1.8–V3.1; para proyectos
TIA V20 Siemens especifica S7-PLCSIM Advanced V7.0, que cubre TIA V14–V20 y CPU FW V1.8–V4.0.
Por tanto, V20 + Advanced V6 no es una combinación aceptada para descargar, aunque una conexión
`Go online` parcial se haya observado antes. Esa conexión histórica no demuestra compatibilidad ni
comportamiento. Este host tiene TIA V20, PLCSIM Standard V20 y Advanced V7.0.0.0/API 7.0; el probe
inicializó la interfaz `0x00070000` y el adaptador completó registro/PowerOn/PowerOff/limpieza de una
CPU virtual desechable. Aún no hay descarga de un proyecto TIA ni aceptación conductual. Se mantiene
bloqueada hasta validar fixture, clasificación completa F/Safety/protección en la sesión exacta,
destino virtual visible y plan funcional. No se salta ningún gate por Softbus, CPU compatible ni
una ruta de descarga visible.

Una vez emparejadas las versiones, Softbus local es el transporte predeterminado: limita la
comunicación al PC/VM y evita cambiar la red de Windows. Siemens documenta `PLCSIM` como interfaz
PG/PC para Softbus y `Siemens PLCSIM Virtual Ethernet Adapter` para TCP/IP. TCP/IP queda reservado
a pruebas que necesiten Ethernet, en modo `<Local>` y con NIC Siemens aislada. La selección se hace
por versión TIA, versión de simulador, CPU y firmware exactos; nunca se infiere compatibilidad del
número de familia.

0. **Compatibilidad primero.** Registra las versiones exactas de TIA, PLCSIM Advanced y firmware.
   Comprueba la matriz Siemens: TIA V20 requiere Advanced V7 para esta ruta; con TIA V14–V19,
   Advanced V6 puede servir si CPU y firmware también están soportados. Si no coinciden, detente
   antes de arrancar el adaptador o llamar `DownloadToPlc`.
1. **Aísla el proyecto.** Abre únicamente un clon desechable cuyo manifiesto y backup coincidan.
   Identifica visualmente TIA, proyecto y versión; maximiza TIA. No reemplaces ni cierres un proyecto
   ajeno.
2. **Comprueba la CPU.** Lee modelo, firmware, IP, árbol PLC, bloques y tags de esa misma fixture.
   Exige CPU incluida en la matriz de PLCSIM, modelo estándar no F para esta política, metadata
   completa `isFailsafe=false`, tags Safety clasificados, sin protección know-how y sin
   inconsistencias. Si falta una propiedad, detente.
3. **Activa la compilación simulable.** En propiedades del proyecto > **Protection**, activa
   **Support simulation during block compilation**. Cuando la CPU virtual necesite reutilizar
   bloques S7-1500, comprueba también **Allow use of S7-1500 blocks in virtual S7-1500 CPUs**.
   Guarda, compila, exige 0 errores/0 avisos y vuelve a leer la propiedad por todos los bloques.
4. **Arranca una sola CPU virtual.** Abre `S7-PLCSIM Advanced Control Panel`, elige `PLCSIM`
   (Softbus) en `Online Access`, asigna un nombre único y la familia de CPU correcta, y pulsa
   `Start`. Siemens indica que este paso crea e inicia la instancia; la primera descarga desde TIA
   la inicializa y después el panel muestra el tipo concreto de CPU. Confirma instancia/estado en el
   runtime antes de continuar. En Softbus las instancias pueden compartir la IP por defecto y TIA
   puede mostrar solo una; por eso esta receta permite una sola instancia a la vez.
5. **Prepara la descarga desde TIA.** En `Download to device`, selecciona la interfaz PG/PC
   `PLCSIM`. Ejecuta la búsqueda/selección de target y revisa el diálogo completo antes de aplicar.
   Para la primera descarga, Siemens indica que el diálogo presenta las instancias Advanced
   compatibles; si aún no se configuró la instancia, puede aparecer como `CPU-1500 Simulation`.
   Exige además que `Load preview` diga **“The downloads are performed on a simulated CPU”**.
   Cancela si el tipo, la instancia o el aviso faltan o son ambiguos. No continúes por una NIC
   Ethernet física.
   Si `Load preview` informa que el software necesita compilarse o que la compilación de hardware
   terminó con error, **no cargues** aunque una llamada MCP anterior a `CompileSoftware` diera
   `Success`: registra por separado el resultado visual de compilación de hardware y vuelve a
   compilar/revisar el panel Info de esa instancia TIA.
6. **Descarga y arranca.** Solo después de todos los gates anteriores confirma la descarga a la CPU
   virtual. Siemens especifica que después de la carga se debe pasar la instancia a `RUN` para
   iniciar la simulación. Hazlo desde TIA/PLCSIM si no arrancó ya; confirma el indicador/estado `RUN`
   de la instancia y el estado online desde TIA. Una conexión `Go online` aislada solo demuestra
   comunicación: no acredita descarga, ejecución cíclica ni comportamiento.
7. **Prueba el programa.** Ejecuta un plan con entradas virtuales conocidas y salidas esperadas que
   procedan de la lógica y tags leídos. Confirma cada transición, registra respuestas y evidencia.
   `Compile success`, descarga correcta y `Online` solo acreditan etapas, no comportamiento.
8. **Cierra limpiamente.** Detén y desregistra la instancia temporal, verifica `status=stopped`,
   cierra la sesión MCP y conserva logs, plan, versiones, hashes, target y resultados.

**Criterio de aceptación:** únicamente se marca `VERIFIED` si hubo preflight completo sobre el
fixture/hash exacto, CPU virtual identificada en el diálogo de descarga, descarga aceptada, estado
`Online`, expectativas funcionales pasadas y limpieza confirmada. Si falla un gate, registra
`BLOCKED` con su evidencia y no pruebes una ruta alternativa con hardware real.

### Diagnóstico de certificado en hardware — fixture 2026-09-28

En `AgentDemo_V20`, el preflight MCP guardó `CompileSoftware=Success` (0 errores/0 avisos), pero el
`Load preview` de TIA dijo `The software needs to be compiled` y
`Compilation of hardware configuration was completed with error`; el panel Compile mostraba 3
errores y 1 aviso. El detalle visible incluye: `The PLC communication certificate cannot be
configured without the password for confidential PLC configuration data. Enter the password.`
También apareció el aviso `The S7-1500 CPU display does not contain any password protection.` No se
cargó el proyecto. El usuario confirma que los proyectos de este workspace son pruebas generadas o
migraciones de proyectos abiertos y que no debe haber contraseñas que recuperar. Por tanto, este
mensaje no autoriza a pedir ni inventar una contraseña: se trata como una opción de protección
incompatible con la fixture.

La API oficial V20 permite hacerlo sin contraseña desde el servicio Openness
`PlcMasterSecretConfigurator` de la `DeviceItem` CPU. La herramienta acotada
`DisableUnconfiguredPlcConfigurationProtection` aplica solo cuando Siemens informa
`MasterSecretConfiguration=WithoutPassword`: llama `Unprotect()` sin argumentos y exige readback
`None`. Ya está implementada y compila, pero su primer uso live sigue pendiente. Está disponible
solo en `tia-inspect --isolated --fixture-root <run-dir> --allow-write`; el guardado queda pendiente
para `SaveProject`. Si aparece `WithPassword`, para: no pruebes claves ni llames `Reset()` (Siemens
indica que `Reset` elimina la configuración de PLC y los certificados). No la ejecutes mediante
bridges genéricos de reflexión. También puede revisarse manualmente en `PLC_1 > Properties >
Protection & Security > Protection of the PLC configuration data`, solo en el clon desechable.
Después compila hardware y software, revisa todos los errores y avisos, guarda solo si los
resultados son aceptables y vuelve a validar manifiesto/readback conforme a la receta.

Hazlo únicamente en la copia aislada, nunca en el origen. Si la propiedad no está disponible o TIA
muestra un destino/proyecto distinto, para y registra el bloqueo. La regla de una instalación de
cliente/producción sigue siendo respetar su política; esta excepción no es aplicable allí.

Si otro proyecto de origen trae protección habilitada, eso no demuestra que tenga una contraseña
que conozcamos: no pruebes claves ni solicites credenciales. Para pruebas, documenta y desactiva la
opción solo en un clon. Siemens indica que, cuando se usa la protección, TIA vuelve a pedir la
contraseña al cargar la configuración de hardware y que esta no queda almacenada en el proyecto.
Fuentes: [protección de datos de configuración
confidenciales V20](https://docs.tia.siemens.cloud/r/en-us/v20/editing-devices-and-networks/configure-networks/secure-communication-s7-1200-s7-1500-s7-1500t/requirements-for-secure-communication-s7-1200-s7-1500-s7-1500t/protection-of-confidential-configuration-data-s7-1200-s7-1500-s7-1500t)
y [API Openness V20 para administrar Master Secret](https://docs.tia.siemens.cloud/r/fr-fr/v20/tia-portal-openness-api-pour-l-automatisation-du-workflow-d-ingenierie/tia-portal-openness-api/fonctions-pour-l-acces-aux-donnees-d-un-automate-programmable/fonctions-de-chargement-de-donnees-dans-l-api/gerer-les-secrets-maitres-dans-les-automates-programmables)
y [descripción S7-1500 V20](https://docs.tia.siemens.cloud/r/en-us/v20/functional-description-of-s7-1500-cpus-s7-1500/setting-the-operating-behavior-s7-1500/protection-security-s7-1500/protection-of-confidential-configuration-data-s7-1500).

Fuentes oficiales Siemens: [novedades V20 y compatibilidad Advanced V7 V14–V20](https://docs.tia.siemens.cloud/r/en-us/v20/what-s-new-in-tia-portal/changes-in-previous-versions-of-tia-portal/changes-in-tia-portal-v19/engineering-options), [manual Advanced V7.0](https://support.industry.siemens.com/cs/attachments/109977691/s7-plcsim_advanced_function_manual_en-US_en-US.pdf), [manual Advanced V6.0 UPD1 y compatibilidad V14–V19](https://cache.industry.siemens.com/dl/files/578/109955578/att_1267815/v1/s7-plcsim_advanced_function_manual_en-US.pdf), [qué es Advanced y cómo carga/ejecuta la CPU virtual](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_20/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced-api/product-overview/what-is-s7-plcsim-advanced), [Softbus, TCP/IP y límites de comunicación](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_20/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced/communication-paths/communication), [crear/iniciar instancia en Control Panel V20](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_20/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced/simulating/simulating-a-cpu/control-panel-user-interface/s7-plcsim-advanced-control-panel), [procedimiento de descarga a una instancia simulada](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_21/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced/simulating/simulating-a-cpu/downloading-a-step-7-project), [opción de compilación simulable V20](https://docs.tia.siemens.cloud/r/en-us/v20/editing-projects/creating-and-managing-projects/displaying-properties-of-the-project). La matriz de CPU y los límites deben volverse a cotejar si cambia TIA, PLCSIM o el firmware instalado.

## Secuencia

Ejecuta la secuencia MCP con `Invoke-McpToolSequence.ps1`, que adquiere el lease compartido:

1. Ejecuta `Doctor` en `tia-inspect` read. Si falla, para.
2. Con el proyecto desechable ya abierto e identificado visualmente, conecta y adjunta
   (`AttachToOpenProject` con el nombre exacto) sin abrir, cerrar ni sustituir ningún
   proyecto. El runner nunca llama `OpenProject`: el servidor rechaza abrir sobre un
   proyecto ajeno abierto (`closeForeignProject=false`) y el preflight verifica que el
   attach confirma el nombre exacto y que `GetProjectTree` contiene proyecto, `DevicePath`
   y `SoftwarePath`.
3. Lee `GetProjectTree` y `GetSoftwareTree`; copia sus rutas exactas al comando.
4. Lee la IP de `GetDeviceIpAddress` para el dispositivo del proyecto y pásala como `TargetIpAddress`.
   En Softbus se espera `ip=null` en el objeto runtime; la IP de proyecto se valida contra
   `GetDeviceIpAddress` pero **no** se reenvía a `DownloadToPlc`: el servidor filtra
   `targetIpAddress` contra `TargetAddresses` y las rutas Softbus/no configuradas las traen
   vacías, así que reenviarla rechazaría la descarga. Solo TCP/IP local reenvía interfaz
   exacta + IP objetivo.
5. Valida el plan de E/S; el runner lo hace antes de iniciar una instancia.
6. El runner inicia PLCSIM en Softbus y exige `status: ready`, identidad de instancia, CPU estándar
   no F, `networkMode=SOFTBUS` y alcance local. Para TCP/IP alternativo comprueba además NIC e IP.
7. Exige clasificación completa F/Safety, tags Safety y protección antes de descargar.
   Contrato exacto del build local: `GetBlocks` devuelve `items[]` con `isFailsafe`,
   `isKnowHowProtected`, `isConsistent`, `programmingLanguage` explícitos más
   `meta.success`; `GetTags(softwarePath)` —un solo parámetro— devuelve `items[]` con
   `isSafety` más `meta.success=true`, `meta.complete=true` y `meta.count == items.Count`.
   Cualquier metadata ausente/nula, `complete=false` o conteo incoherente bloquea antes de
   descargar. Si el perfil seleccionado no entrega este contrato, detente sin descarga.
   Confirma
  `CompileSoftware=Success`, 0 errores y 0 avisos; `CheckDownloadReadiness` devuelve `Ready=true`
   e `IsConsistent=true`. Para Softbus exige **exactamente una** ruta con
   `pgPcInterface` igual a `PLCSIM` (comparación exacta, no subcadena: la NIC TCP/IP se llama
   `Siemens PLCSIM Virtual Ethernet Adapter` y confundirlas seleccionaría Ethernet). Si no hay
   ruta `PLCSIM` enumerada —el caso live observado: cinco rutas PN/IE de NICs físicas/virtuales,
   sin direcciones y sin preferida—, el runner se bloquea con mensaje explícito de configuración
   Softbus y **nunca** cae a una NIC. Para la descarga Softbus solo reenvía
   `pgPcInterface='PLCSIM'`; confirma en el diálogo que el destino
   es una CPU simulada y muestra **“The downloads are performed on a simulated CPU”**. En la primera
   carga debe identificar `CPU-1500 Simulation`. Para TCP/IP exige ruta única con el adaptador
   Siemens e IP coincidente y aislamiento local.
8. Descarga solo al destino virtual identificado y desechable. Si la ruta o el diálogo no distinguen
   inequívocamente PLCSIM de hardware, cancela.
9. Ejecuta el plan y compara todas las expectativas. Solo después registra `status=VERIFIED`.
10. Detiene y desregistra la instancia; la limpieza debe confirmar `status: stopped`.

**Estado de las capacidades:** se observó antes que TIA V20 llegó a mostrar `Go online` con una CPU
Advanced V6 por Softbus. Esa evidencia histórica se conserva como conectividad parcial, no como
combinación compatible para un proyecto V20 ni como aceptación. Ahora V7.0/API 7.0 está instalado;
la inicialización, selección Softbus y ciclo nativo de CPU desechable están probados, pero no se ha
descargado ningún proyecto. `tia-inspect` sí clasificó bloques
y tags en una fixture aislada. El runner comprueba metadata F/Safety, protección, simulabilidad,
`DownloadToPlc=Success`, `GetOnlineState=Online` y el plan de comportamiento, y falla cerrado si
falta un dato. Las regresiones del runner pasan con servidores y adaptadores simulados
(`Test-InvokeTiaSimulationAcceptance.ps1` y `Test-TiaSimulationAcceptanceSafety.ps1`, 10+10 PASS
el 2026-09-25 bajo pwsh 7.5.2 portable); no prueban que se haya descargado un programa en TIA.
La descarga inicial y el comportamiento cíclico siguen sin aceptación en vivo. El rechazo live
de `DownloadToPlc` ante una fixture Safety tampoco está probado: no existe fixture Safety
autorizada y la política prohíbe crear contenido F.

Ejemplo de invocación con valores que deben leerse del proyecto y del preflight:

```powershell
.\30-tools\scripts\Invoke-TiaSimulationAcceptance.ps1 `
  -ProjectFile '<fixture .ap20 exacto>' `
  -ProjectName '<nombre leído del proyecto>' `
  -DevicePath '<ruta leída de GetProjectTree>' `
  -SoftwarePath '<ruta leída de GetSoftwareTree>' `
  -TargetIpAddress '<IP leída con GetDeviceIpAddress>' `
  -SimulationTargetEvidencePath '<JSON reciente de Computer Use>' `
  -IoPlanPath '<plan revisado>' `
  -StartVirtualPlc -AcknowledgeVirtualTarget -Run
```

El JSON de confirmación usa este contrato (todos los valores deben proceder de la observación real
de la ventana/diálogo, no de una inferencia por la interfaz o el nombre de la instancia):

```json
{
  "schemaVersion": 1,
  "source": "native-computer-use",
  "confirmed": true,
  "observedAt": "<fecha-hora ISO 8601 con zona>",
  "tiaMajorVersion": 20,
  "projectFile": "<ruta absoluta del .ap20 visible>",
  "projectName": "<nombre visible>",
  "devicePath": "<ruta exacta leída del árbol>",
  "targetIpAddress": "<IP de la CPU>",
  "pgPcInterface": "PLCSIM",
  "targetDisplayName": "CPU-1500 Simulation",
  "downloadNotice": "The downloads are performed on a simulated CPU",
  "windowState": "maximized",
  "stage": "before-download"
}
```

Para Softbus, `pgPcInterface` debe ser exactamente `PLCSIM`; para TCP/IP, exactamente el nombre
de la NIC Siemens confirmada. La observación caduca a los 30 minutos. Guarda el JSON junto a la
captura/evidencia de la sesión. El runner conserva la ruta y SHA-256 de este archivo. Una
confirmación ausente, antigua, de otro proyecto/CPU/IP o de otra ruta bloquea antes de iniciar la
instancia virtual, abrir MCP o enviar `DownloadToPlc`.

## Forma del plan

Usa tags y direcciones leídas del proyecto. Define los valores esperados según la especificación
funcional y los interlocks del proceso; el ejemplo es una plantilla, no una receta de señales:

```json
{
  "schemaVersion": 1,
  "name": "<nombre-del-caso>",
  "steps": [
    {
      "command": "write-bool-tag <tag-de-entrada-leido> 1",
      "expect": { "status": "ok", "op": "write-bool-tag" }
    },
    {
      "command": "read-bool-tag <tag-de-salida-leido>",
      "expect": { "status": "ok", "op": "read-bool-tag", "value": true },
      "delayMs": 250
    }
  ]
}
```

El step de lectura tiene que comprobar el resultado funcional de una salida o tag simbólico de
salida. Leer el tamaño de un área o hacer eco de la entrada no demuestra respuesta del programa. Un
plan que solo espera `status` y `op` demuestra transporte, no comportamiento, y se bloquea antes de
descargar. Los comandos permitidos incluyen lectura y escritura de bits/bytes,
tags bool/uint8/float y tamaño de área, según `30-tools/plcsim/README.md`.

## Evidencia y condiciones de parada

Conserva `acceptance-latest.json`, el plan y su SHA-256, versión de TIA/PLCSIM, nombre y tipo de
CPU virtual, IP de proyecto, instancia, interfaz, ruta seleccionada, respuestas de todos los pasos
y el resultado de limpieza. Distingue claramente:

- compilación offline;
- conexión y disponibilidad del target;
- descarga a PLCSIM;
- comportamiento observado mediante expectativas;
- validación de Runtime HMI;
- puesta en servicio física.

No marques comportamiento como verificado por `CompileSoftware`, `DownloadToPlc` o
`GetOnlineState` solamente. Si falta una ruta única, una IP coincidente o identidad virtual, para
antes de descargar. Si `CheckDownloadReadiness=false`, registra el mensaje exacto y corrige la
configuración; no repitas sin cambio. `NotReachable`/`Incompatible` requiere registrar IP, firmware
y ruta antes de modificar nada. Si un tag no aparece, vuelve a leer los tags del proyecto, no
sustituyas el símbolo por un offset supuesto. Si la limpieza no confirma `stopped`, la aceptación
queda incompleta.

### Estado del build local V20 y último preflight — 2026-09-25 (actualizado en sesión)

La sección histórica que decía que `tia-create full` no expone `GetTags/isFailsafe` quedó
supersedida por el build local descrito en
[`tia-create/README.md`](../../30-tools/mcp/tia-create/README.md). El binario patched expone
`GetBlocks.isFailsafe` y `GetTags` con `items`, `meta.count`, `meta.complete` y
`meta.success`; `DownloadToPlc` vuelve a hacer preflight global F/Safety/protección dentro de
la misma sesión. Lectura live estándar: dos bloques no F y no protegidos, dos tags no Safety en
[`20260925-tia-create-safety-live-read-built.json`](../../70-runs/tia-capabilities/20260925-tia-create-safety-live-read-built.json).
No se ha probado todavía el rechazo live de una fixture Safety.

`Invoke-TiaSimulationAcceptance.ps1` quedó alineado con ese contrato en esta sesión:
`GetTags` exige `meta.count/meta.complete/meta.success` (antes esperaba el inexistente
`meta.totalTags`, lo que bloqueaba cualquier lectura live válida); la llamada usa solo
`softwarePath`; el preflight usa `AttachToOpenProject` en vez de `OpenProject` (el servidor
rechaza abrir sobre el proyecto ajeno abierto); la ruta Softbus exige `pgPcInterface`
exactamente igual a `PLCSIM` y no reenvía `targetIpAddress` (las rutas live traen
`TargetAddresses` vacías y el servidor filtraría la descarga); TCP/IP local sigue exigiendo
interfaz exacta + triple acuerdo de IP. Los suites `Test-InvokeTiaSimulationAcceptance.ps1`
(10 PASS) y `Test-TiaSimulationAcceptanceSafety.ps1` (10 PASS, incluido el caso nuevo que
repite la forma live de 5 rutas sin `PLCSIM` y exige bloqueo sin caída a NIC) pasaron el
2026-09-25 con pwsh 7.5.2 portable. Nota de entorno: los suites exigen pwsh (PS7);
Windows PowerShell 5.1 no sirve (rompe `$PSScriptRoot` en defaults, `ConvertFrom-Json
-AsHashtable` y el paso de JSON por `-File`).

El último `CheckDownloadReadiness` live dio Ready=true, pero publicó cinco rutas PN/IE sin
direcciones ni preferencia, mientras el proyecto declara `192.168.0.1`; no es prueba de ruta
ni de conexión. El panel V7 mostraba Softbus seleccionado y ninguna instancia activa. La
instancia temporal de diagnóstico posterior se limpió correctamente con todos los códigos `0x0`.

**Estado de aceptación PLC: bloqueado antes de descarga.** A 2026-09-25 13:15 +02:00 no hay
proceso TIA Portal en ejecución (ventana `AgentDemo_V20` ya no visible; solo quedan los
procesos de fondo PLCSIM Advanced UI y Runtime Manager). El `.ap20` de `retry-fixture-01` está
libre y coincide con su backup, pero `Assert-TiaFixtureManifest` sigue sin validar (deriva
`IM/SearchIndex` de la sesión TIA anterior). Falta: regenerar fixture válida desde backup con
manifiesto del runner, abrirla en TIA V20, confirmar firmware, y que TIA identifique
visualmente el destino como `CPU-1500 Simulation`. Después se requiere descarga simulada, RUN
y plan funcional con salida esperada. No se descargó ningún programa. La confirmación visual
del diálogo requiere Computer Use nativo (`node_repl` + `@oai/sky`, disponible solo en sesión
Codex/Windows): este host no la expone, así que ese paso queda para el propietario o una
sesión con esa capacidad.

### Continuación del preflight y nuevo gate visual — 2026-09-28

El estado anterior corresponde a la sesión del 25/09. La fixture de esta continuación está en
`70-runs/e2e/20260928-objective-resume-acceptance-supported/isolated-fixture/`; manifiesto y backup
validaron con hash `4817178749bd4ef8b23586d65665ae0ac673773a9a307868a411aca9b05896c4`. En la preflight
live, `CompileSoftware` terminó con 0 errores/0 avisos, ambos bloques estándar/no protegidos y con
`PLCSimAdvancedSupport=true`, las dos tags clasificadas completas como no Safety y
`CheckDownloadReadiness` expuso una sola ruta `PLCSIM`. Véase el resumen local
[`20260928-objective-resume-preflight.json`](../../70-runs/simulation/20260928-objective-resume-preflight.json).

La ejecución del runner se interrumpió antes de producir el informe final; no hay respuesta
registrada de `DownloadToPlc`, `Online`, comportamiento ni limpieza confirmada. Por ello **no hay
aceptación live**. La siguiente fase debe comprobar el estado del panel PLCSIM y el proyecto visible.

Como defensa en profundidad, el runner ahora exige `-SimulationTargetEvidencePath`. La evidencia
debe seguir el esquema de arriba, observarse en los últimos 30 minutos y coincidir con la ruta
exacta: `PLCSIM` en Softbus o el nombre exacto de la NIC Siemens en TCP/IP. El runner verifica el
proyecto `.ap20`, dispositivo, IP, versión TIA, `CPU-1500 Simulation`, aviso de CPU simulada y
ventana maximizada; conserva el SHA-256 en el informe. Las pruebas dirigidas incluyen evidencia
ausente/cruzada entre proyecto y ruta y pasan con mocks; todavía falta generar un artefacto desde
Computer Use y completar la aceptación conductual live.
