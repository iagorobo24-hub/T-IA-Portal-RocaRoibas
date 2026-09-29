# R20 — Aceptación HMI según modelo y Runtime

## Objetivo

Aceptar por separado la ingeniería, la visualización, el enlace HMI–PLC y la ejecución en el
target concreto. La familia/modelo y la pareja de versiones determinan qué runtime y simulador
sirven; un proyecto que compila, una pantalla abierta o el PLC en PLCSIM no demuestran por sí
solos que la HMI funciona.

## Estado local

- **Verificado en la documentación del workspace:** hay recetas iniciales R13/R14, pero no
  distinguen acceptance por familia, los modelos reales incluyen paneles Comfort y Unified, y la
  interfaz MCP no renderiza una pantalla. `tia-create` está destinado a ingeniería de WinCC
  Unified; `tia-inspect` es principalmente PLC. La inspección visual necesita la GUI/runtime.
- **Verificado localmente/documentado:** TIA Portal V20; WinCC Runtime Advanced encontrado en
  V17.0 HF8; el proyecto de juegos HMI V20 falló con “device is not supported and cannot be
  compiled”. Esto bloquea la aceptación Runtime Advanced de ese caso hasta disponer de una
  combinación compatible. No extrapolar el error a todos los modelos.
- **No verificado ahora:** instalación/licencia de Runtime Unified, Runtime Advanced V20 o
  Runtime Professional; compatibilidad efectiva de PLCSIM V19 con el proyecto V20; firmware,
  runtime e imagen de cualquier panel físico.
- **Computer Use:** el plugin nativo de Codex (`node_repl` + `@oai/sky`) está disponible en la
  sesión del 2026-09-21. Se abrió y navegó visualmente un clon PLC IOT2050, pero no se abrió ni
  editó un proyecto HMI ni se ejecutó un Runtime HMI. `mcp__cua_repl` es una superficie browser-only;
  su `apps=[]` no diagnostica acceso a ventanas Windows. Antes de cada operación GUI, comprobar el
  plugin nativo, enumerar ventanas y verificar identidad/estado del target. Si el plugin no está
  habilitado o el target no se identifica sin ambigüedad, dejar el paso pendiente y pedir evidencia
  identificable.
- **Alcance de este documento:** procedimiento y matriz. No se editó ni ejecutó un proyecto HMI;
  la navegación visual comprobada en otro clon no cuenta como aceptación HMI.

Antes de cada prueba, actualizar los informes locales con
`Write-TiaEnvironmentReport.ps1` y `Write-TiaSimulationReadiness.ps1`. Un inventario guardado
de otra fecha no demuestra que runtime, licencia o adaptador sigan instalados.

## Matriz para elegir ruta de aceptación

| Familia/configuración exacta | Runtime/simulador que hay que verificar | Ruta visual y enlace PLC | Gate y límite específico | Situación local |
|---|---|---|---|---|
| **Basic Panel clásico** | Simulación Basic compatible con la versión del proyecto y device version | Simulación visual de la familia; tag/PLC solo por la ruta de conexión que Siemens documente para ese modelo y combinación | Aplican las restricciones de Basic Panel; no asumir compatibilidad PLCSIM, teclas ni enlace PLC por poder abrir la simulación | Ingeniería V20 y ejemplos; runtime/pareja local no comprobados |
| **Comfort Panel clásico** | Device simulation de Comfort o Runtime Advanced de versión compatible, según el objetivo concreto | Simulación visual en la ruta compatible; para tags HMI–PLC se requiere prueba conectada a PLCSIM compatible | No mezclar restricciones Basic con Comfort; la simulación PC no valida pantalla física, teclas, brillo ni hardware | Runtime Advanced V17.0 HF8 localizado; proyecto de juegos V20 rechazado en esa combinación concreta |
| **WinCC Runtime Advanced PC** | Runtime Advanced PC de la versión compatible | Runtime PC para display; PLCSIM solo para el test PLC conectado | Gatea Runtime Advanced únicamente a esta fila. No sustituirlo por Unified o Professional | Runtime Advanced V20/licencia no verificados |
| **WinCC Runtime Professional PC** | Runtime Professional de la versión configurada | Runtime Professional PC y PLC virtual aislado con driver/canal del proyecto para la prueba conectada | Requiere verificar Professional, su licencia/opciones y canal concreto. Runtime Advanced no satisface este gate | Instalación/licencia no verificadas |
| **WinCC Unified Basic Panel** | Unified Simulator/Runtime compatible con el device version Basic exacto | Probar funciones soportadas por la simulación; enlace PLC solo con la ruta Unified + PLCSIM documentada y target virtual | El simulador Unified independiente no simula PLC tags externas; no usarlo como aislamiento de red | Runtime/licencia Unified no verificados |
| **WinCC Unified Comfort Panel** | Unified Simulator/Runtime compatible con el device version Comfort exacto | Como Basic, seleccionar la ruta Unified de esa familia y añadir PLCSIM solo para el test PLC | Registrar diferencias PC/panel y funciones específicas que el simulador no cubra | Runtime/licencia Unified no verificados |
| **WinCC Unified PC Runtime** | Runtime/Simulator Unified PC de la versión configurada | Solo PLCSIM virtual desechable para HMI–PLC; probar aparte navegación/display | No gatear por licencia Runtime Advanced ni Professional. Respetar límites de versión de Unified Simulator; no equivale a commissioning | Runtime/licencia Unified no verificados |
| **Panel físico de cualquiera de las familias** | Modelo, firmware/image y versión de proyecto que correspondan al panel real | La aceptación física solo se realiza como FAT/SAT aprobado; la prueba PLC requiere el target acordado | Antes de transferir, cambiar imagen o modificar datos: backup del proyecto y del panel/datos necesarios, verificación de restauración y confirmación explícita vigente para el panel exacto y la acción | No hay panel conectado verificado |

Basic/Comfort clásicos, Runtime Advanced, Runtime Professional y Unified Basic/Comfort/PC son
rutas diferentes. No exigir Runtime Advanced para Unified o Professional ni llamarlos a todos
“HMI V20”: registrar ingeniería, versión de proyecto, familia/modelo, device version, runtime,
licencia y firmware/image aplicables a ese target. La API Openness también tiene cobertura HMI
dependiente de familia; una pantalla accesible por API no implica que la herramienta la represente
visualmente. [Listado oficial de objetos Openness V20](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/tia-portal-openness-api/tia-portal-openness-object/object-list).

## Precondiciones

1. Ejecutar Doctor. Si hay una ventana TIA visible, identificarla primero con Computer Use nativo
   (`node_repl` + `@oai/sky`) y confirmar título, proyecto y versión antes de cualquier `Connect`.
   Si no se puede identificar sin ambigüedad, detenerse y no abrir ni conectar otra instancia.
   Después, usar `Attach` solo si el perfil MCP real lo expone y corresponde al proyecto; `Connect`
   no adjunta por sí solo la ventana visible. Leer las rutas del proyecto desde el árbol y confirmar
   que el proyecto HMI corresponde a un proyecto de prueba o a una copia desechable antes de
   cualquier compilación, simulación o escritura.
2. Leer para cada target: nombre real del HMI, familia y modelo exactos, versión del proyecto,
   device version, runtime configurado, CPU/partner, conexión integrada/no integrada, licencia y
   versión/runtime instalado. Para panel físico, registrar también image version/firmware.
3. Revisar mediante el preflight la instalación y licencia del runtime que corresponde a la
   familia elegida en la matriz. Este gate solo bloquea la modalidad de runtime que se pretende
   ejecutar; una licencia Runtime Advanced ausente no bloquea la inspección/compilación Unified
   o Professional. Si no se puede confirmar la edición, versión o compatibilidad exacta, bloquear
   esa modalidad; no buscar equivalencias por nombre.
4. Leer pantallas, tags, conexiones, alarmas, users/roles, ciclos, scripts y recetas del proyecto.
   MCP/Openness puede exponer objetos HMI sin mostrar su renderizado o permitir toda edición de
   esa familia. Si se necesita inspección visual en GUI, confirmar primero que el plugin nativo
   Computer Use controle la aplicación en esta sesión y verificar la ventana objetivo. `apps=[]`
   de `cua_repl` no es un bloqueo de UI Windows. Si no se puede identificar la ventana, dejar el
   paso bloqueado o pedir al usuario capturas/export verificables. El árbol PLC de `tia-inspect` no
   sustituye la inspección del HMI.
5. Para tags PLC dependientes, leer tags/bloques PLC y compilar primero el software PLC; después
   compilar el dispositivo HMI. Si también se tienen que validar direcciones/IP, efectuar la
   compilación completa apropiada de `Devices & networks`, no solo `changes only`.
6. Para prueba HMI–PLC en simulación, preferir Softbus local: registrar `networkMode=SOFTBUS`,
   `PLCSIM` como PG/PC y la instancia virtual estándar identificada. Para TCP/IP local, exigir
   `plcsimVirtualAdapterReady=true`, `<Local>`, IP coincidente y subred aislada. Registrar IP del
   PLC y endpoint de cada partner; verificar que son destinos simulados del fixture. Si falla
   cualquier identificación, detenerse y asumir que es un PLC físico.
7. Antes de cualquier cambio HMI, confirmar el perfil MCP que realmente expone esa familia y
   operación, su esquema vigente y el reconocimiento explícito del perfil `create`/`full` si
   corresponde. Ejecutar `dryRun`/preview primero cuando la herramienta lo ofrezca y revisar el
   plan antes de aplicarlo; si el perfil, esquema o preview requerido no existe, no improvisar
   mediante una importación opaca. Para cualquier escritura usar fixture desechable, backup y
   lectura previa conforme al contrato del workspace.

## Secuencia

### A. Leer y preparar

1. Ejecutar `GetProjectTree` y obtener el dispositivo HMI exacto. Anotar family/model del árbol;
   completar en TIA GUI los campos que la API no entregue.
2. Registrar WinCC engineering instalado, versión del proyecto, familia/modelo, device version,
   runtime configurado, runtime instalado y licencia/opción aplicable; para panel, añadir
   firmware/image. Comprobar la compatibilidad de esa combinación exacta en la documentación
   Siemens de la familia y en la compilación de TIA. Una combinación sin soporte bloquea solo
   su runtime/simulación; no extrapolar el gate de Advanced a Unified o Professional.
3. Leer la conexión a PLC, tags externas/internas, tipo de datos, dirección y acquisition cycle;
   revisar propiedades de pantalla, scripts, faceplates, alarmas y niveles de acceso. Identificar
   un tag de prueba reversible que no actúe sobre maquinaria.
4. Antes de la primera escritura, hacer backup del `.ap20` y export/captura de baseline; leer la
   configuración afectada. Usar el perfil MCP que exponga esa operación/familia, reconocimiento
   explícito del perfil `create`/`full` cuando corresponda, `dryRun`/preview primero y cambio
   mínimo en el fixture. Toda secuencia MCP va por `Invoke-McpToolSequence.ps1` con el lease
   global; no paralelizar sesiones TIA. Si la operación no está expuesta o no tiene preview
   cuando se requiere, parar. R13/R14 siguen siendo referencia general, no evidencia de
   aceptación por modelo.

### B. Compilar sin descargar

1. Compilar el PLC de prueba y conservar errores y avisos.
2. Compilar completamente el HMI exacto y revisar sus errores/avisos, direcciones y recursos.
   TIA debe ser quien muestre si el modelo/device version no puede compilar. “Device is not
   supported” es bloqueo: registrar mensaje y detenerse, sin bajar versión a ciegas.
3. No abrir el diálogo de carga como siguiente paso en un target físico. En TIA, la carga puede
   ofrecer cambiar la imagen/device version y borrar datos, licencias o administración de
   usuarios del panel.
4. Si la compilación u otra comprobación requiere una GUI, no afirmar que se ejecutó visualmente
   cuando Computer Use no controle TIA en esta sesión; entregar al usuario los pasos y registrar
   el resultado como pendiente hasta recibir evidencia identificable.

### C. Ejecutar la prueba adecuada a la familia

Los casos visuales y de tags se ejecutan con nombres de caso estables y parámetros guardados.
No se prueban mandos contra salidas reales. Una ejecución HMI–PLC simulada se etiqueta
**prueba de integración HMI–PLC en simulación**; no llamarla “HMI SIL” ni presentarla como
validación de Safety Integrity Level.

**Basic Panel clásico**

1. Aplicar las restricciones oficiales de simulación Basic para el modelo y device version
   exactos. `device/tag simulation` visual no demuestra que haya PLC virtual ni que un enlace
   HMI–PLC esté activo.
2. Usar tag simulator solo para tags/casos sin PLC y dejar los valores registrados como
   simulados. Si el test necesita PLC, verificar la ruta permitida por Siemens para ese Basic
   exacto antes de intentar conectar PLCSIM.

**Comfort Panel clásico**

1. Usar device simulation compatible o la ruta de Runtime Advanced prevista para ese proyecto;
   no aplicar automáticamente los límites de Basic a Comfort.
2. Para test sin PLC, usar tag simulator con valores conocidos y marcados como simulados.
3. Para probar tags HMI–PLC, unir el proyecto de prueba solo a la instancia PLCSIM compatible,
   después del preflight virtual. Device/tag simulation por sí sola no simula el PLC ni prueba
   el enlace.

**WinCC Runtime Advanced PC**

1. Verificar Advanced, device/runtime version y licencia/opciones exactas; lanzar esa edición
   en una instancia de prueba. No acepta Professional ni Unified.
2. Confirmar que la ventana/instancia abierta es la simulación de prueba y no un Runtime
   productivo. Si Computer Use no puede identificarlo, el agente no interactúa.
3. La prueba conectada usa exclusivamente la ruta preflight hacia PLCSIM y registra tag de
   lectura/escritura de prueba, alarmas y estados; el nombre del Runtime no demuestra que el
   endpoint sea virtual.

**WinCC Runtime Professional PC**

1. Verificar Professional, licencia/opciones, canal y versión; lanzar solo esa edición. No
   sustituirla por Advanced o Unified.
2. Confirmar que la sesión es una instancia de prueba, no un Runtime productivo. Para probar
   HMI–PLC, conectar exclusivamente la ruta preflight hacia PLCSIM y registrar las tags/casos
   ejecutados.

**WinCC Unified Basic Panel y Unified Comfort Panel**

1. Seleccionar el Unified Simulator/Runtime correspondiente a Basic o Comfort exacto,
   verificando device version y versión de ingeniería/proyecto Unified. No usar presencia de
   Runtime Advanced/Professional como gate Unified.
2. Registrar funciones visuales soportadas por cada modelo. El Unified Runtime Simulator aislado
   no convierte ni aísla por sí solo las tags externas vinculadas a un PLC. Además, los scripts de
   simulación de cambios pueden escribir los valores calculados en las tags sin otra confirmación;
   si son tags externas ligadas a un PLC de proceso, pueden influir el proceso. Por tanto, no
   ejecutar scripts de simulación sobre tags externas mientras sigan conectadas a un PLC real o de
   proceso. Usar tags HMI internas sin conexión externa, o un target virtual cuya identidad y
   aislamiento se hayan comprobado. La simulación visual de una tag y la escritura de una tag PLC
   son pruebas distintas ([advertencia Siemens V20 para scripts Unified](https://docs.tia.siemens.cloud/r/en-us/v20/runtime-scripting-rt-unified/examples-rt-unified/simulating-value-changes-in-tags-rt-unified)).
3. Para enlace PLC, seguir la ruta Siemens Unified + PLCSIM con la instancia virtual preflighted;
   probar tags sintéticas, secuencia y alarmas necesarias. Guardar versión/configuración y
   evidencia de limpieza.
4. En Unified Panel físico, registrar diferencias de objetos entre PC simulator y panel. Las
   funciones específicas del panel requieren el modelo exacto en banco/FAT.

**WinCC Unified PC Runtime**

1. Verificar versión de ingeniería/proyecto, configuración de Unified PC Runtime y opción/licencia
   correspondiente. No gatear por Runtime Advanced o Professional.
2. Para enlace PLC, seguir la ruta Siemens Unified + PLCSIM preflighted; probar y registrar solo
   los casos sintéticos previstos para ese run.

### D. Casos repetibles por cada HMI

Antes de ejecutar, fijar para cada caso: `run-id`, HMI/familia/device version/runtime, pantalla,
tag/objeto, valor inicial, estímulo, unidad, tiempo de espera, tolerancia, resultado esperado y
observado. Guardar la tabla con los valores reales usados; nombres de caso estables permiten
repetir la aceptación tras un cambio.

| ID de caso | Estímulo parametrizado | Resultado esperado y evidencia |
|---|---|---|
| HMI-START | Arrancar la instancia seleccionada y registrar hora/versión | Pantalla inicial identificada; sin error o diálogo inesperado |
| HMI-NAV-01 | Secuencia de botones/pantallas definida en el plan; registrar cada destino | Cada destino coincide con la ruta definida y permite volver; capturas con HMI identificado |
| HMI-VALUE-01 | Escribir solo `TagTest` del fixture con `ValueTest`/unidad; esperar `WaitMs` | Texto, formato, unidad, calidad y límites coinciden con lo esperado dentro de `Tolerance` |
| HMI-CMD-01 | Accionar mando enlazado solo a tag reversible del fixture, con salida física no conectada | Pulso/estado PLC virtual esperado; verificar ausencia de E/S física |
| HMI-ALARM-01 | Activar `AlarmTest` en `StimulusValue`; registrar retardo/ack/reset | Texto, prioridad, timestamp, estado y rearme según matriz de alarmas |
| HMI-ROLE-01 | Cuenta de prueba `RoleTest`, acción permitida y denegada definidas | Visibilidad y permisos coinciden con la matriz; no usar cuentas/credenciales productivas |
| HMI-COMM-01 | Interrumpir/restituir solo el endpoint simulado según `OutageMs` | Estado degradado, obsolescencia/calidad y recuperación esperados; no se emite mando no solicitado |

No hay caso por defecto que toque una salida física, usuario productivo o endpoint de planta.
Si un caso exige un tipo de prueba no soportado por esa familia, registrar `no aplicable` con el
motivo, sin sustituirlo por otra familia.

No declarar seguridad funcional probada porque un objeto HMI se llame `Emergency`, `Safety` o
`EmergencyOk`: el HMI presenta estados/permisos estándar, no valida el safety program.

## Niveles de aceptación y evidencia

Guardar por HMI bajo `70-runs/<run-id>/hmi/<hmi-id>/`:

- identity del dispositivo, catálogo/modelo, familia, proyecto/engineering/device/runtime/image
  versions, update, runtime y licencia;
- configuración y compilación HMI/PLC por separado, con 0 errores/avisos acordes a la puerta
  local y mensajes completos;
- capturas de pantallas/alarma/navigation, tag-value exacto, pasos ejecutados y resultado;
- test plan y log PLCSIM si hay interacción PLC, IP/interface objetivo declaradas como virtuales,
  respuestas y prueba de parada/limpieza;
- lista de casos no ejecutados, incompatibilidades y límites del simulador frente al modelo;
- si se usa panel físico en FAT/SAT, identidad de panel e imagen y registro de transferencia y
  backup aprobado por el responsable. No guardar credenciales.
- datos de limpieza: runtime/cuenta de prueba cerrados, PLCSIM detenido, valores restaurados al
  baseline y lista de forces vacía. Borrar únicamente datos temporales creados para ese run en
  fixture; no limpiar datos persistentes previos de un panel real ni recetas/usuarios productivos.

| Nivel | Evidencia mínima | Estado que admite |
|---|---|---|
| HMI Engineering | Compilación del HMI y revisión de diagnóstico | Configuración compilable en esa versión |
| HMI Visual | Runtime/simulador correcto + capturas de cada caso visual | Navegación, display y casos sin PLC revisados |
| Integración HMI–PLC en simulación | Runtime/simulador conectado solo a PLC virtual + resultados de tags/casos | Enlace y comportamiento de los casos ejecutados en esa combinación; no es una calificación SIL |
| Panel FAT | Modelo físico exacto + pruebas de pantalla, comunicación, teclas/alarma y versión | Funciones probadas en ese panel y fixture |
| Commissioning/SAT | Autorización del sitio y registro de la instalación | Solo los casos registrados de la máquina en sitio |

Los niveles no se heredan: `HMI Engineering` no implica `HMI Visual`; la integración HMI–PLC en
simulación no implica `Panel FAT`; una prueba en PC no verifica luminosidad/táctil/teclas/
rendimiento de panel.

## Límites físicos y parada

- No transferir un proyecto ni instalar/cambiar imagen en un panel real sin acordar explícitamente
  el target y la ventana de trabajo con el responsable. Exigir confirmación explícita vigente en
  ese momento para ese panel, proyecto, imagen y acción; confirmar impacto si el Runtime está en
  marcha. Antes de la primera escritura, crear y comprobar backup del proyecto y respaldo de los
  datos del panel que deban conservarse/restaurarse. Puede interrumpir el Runtime o reemplazar
  datos; cambiar device image puede borrar usuarios, recetas y licencias. Una confirmación previa
  o para otro target no autoriza esta transferencia.
- No conectar un runtime de prueba a PLC físico; en Unified las tags externas no se aíslan por
  escoger “simulation”. Si hay dudas del target, parar.
- No escribir o forzar tag que afecte a salidas, proceso, permisos o Safety; para probar mandos,
  usar únicamente PLC simulado desechable y tags inventariadas del fixture.
- Parar por family/version no soportada, licencia no comprobada, warning/error no revisado,
  proyecto/ventana ambigua, conexión que apunta a una red real, pantalla que exige transferencia,
  excepción/certificado inesperado o PLCSIM que no queda detenido.

## Referencias Siemens

- [Compatibilidad de versiones Classic WinCC V20](https://docs.tia.siemens.cloud/r/en-us/v20/using-global-functions-basic-panels-panels-comfort-panels-rt-advanced-rt-professional/using-wincc-version-compatibility-basic-panels-panels-comfort-panels-rt-advanced-rt-professional/basics-on-version-compatibility-basic-panels-panels-comfort-panels-rt-advanced-rt-professional)
- [Simulación Runtime Advanced V20: device y tag simulation](https://docs.tia.siemens.cloud/r/en-us/v20/compiling-and-loading-basic-panels-panels-comfort-panels-rt-advanced-rt-professional/runtime-advanced-and-panels-panels-comfort-panels-rt-advanced/simulating-projects-panels-comfort-panels-rt-advanced/wincc-runtime-advanced-simulation-panels-comfort-panels-rt-advanced)
- [Notas de compatibilidad y diferencias de Unified Panel/Simulation V20](https://docs.tia.siemens.cloud/r/en-us/v20/readme-wincc-unified/notes-on-the-operation-of-unified-panel)
- [Unified Runtime simulation: alcance y advertencia sobre tags PLC](https://docs.tia.siemens.cloud/r/en-us/v20/simulate-runtime-rt-unified/simulate-unified-comfort-panel-rt-unified/basics-of-simulation-rt-unified)
- [Usar PLCSIM con Unified V20](https://docs.tia.siemens.cloud/r/en-us/v20/compiling-and-loading-rt-unified/simulating-control-with-plcsim-rt-unified/using-plcsim-rt-unified)
- [Preparar un proyecto PLCSIM para Unified V20](https://docs.tia.siemens.cloud/r/en-us/v20/compiling-and-loading-rt-unified/simulating-control-with-plcsim-rt-unified/preparing-simulation-with-plcsim-rt-unified)
- [Restricciones de simulación Basic Panels V20](https://docs.tia.siemens.cloud/r/en-us/v20/compiling-and-loading-basic-panels-panels-comfort-panels-rt-advanced-rt-professional/basic-panels-basic-panels/simulating-projects-basic-panels/simulation-restrictions-basic-panels)
- [Compilar/descargar paneles y Runtime Advanced; compatibilidad e impacto de image](https://docs.tia.siemens.cloud/r/en-us/v20/compiling-and-loading-basic-panels-panels-comfort-panels-rt-advanced-rt-professional/runtime-advanced-and-panels-panels-comfort-panels-rt-advanced/loading-projects-panels-comfort-panels-rt-advanced/loading-a-project-panels-comfort-panels-rt-advanced)
- [Compilación WinCC V20 y comprobación de direcciones](https://docs.tia.siemens.cloud/r/en-us/v20/readme-wincc-basic-advanced-professional/important-information/compiling-and-loading)
