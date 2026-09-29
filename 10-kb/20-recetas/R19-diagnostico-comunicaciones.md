# R19 — Diagnóstico de comunicaciones

## Objetivo

Localizar una pérdida o degradación de comunicación siguiendo capas, empezando siempre en modo
de solo lectura: proyecto/configuración → interfaz y dispositivo accesible →
conexión/diagnóstico de CPU → estado de protocolo y aplicación. La prueba que modifica tags o
estado de conexión es una fase distinta y opcional, limitada a un fixture virtual desechable.
La receta no cambia IP, nombre PROFINET, certificados, firmware, modo de CPU ni parámetros de
conexiones.

## Estado en este workspace

- **Verificado en ejemplos:** `npatel-iot` contiene proyectos de comunicación S7, OPC UA y MQTT;
  los flujos documentan lectura S7, cliente OPC UA y publicación MQTT.
- **Límite MQTT:** los ejemplos son material de referencia, no un procedimiento de diagnosis.
  MQTT queda fuera de esta receta ejecutable hasta que exista un procedimiento propio con broker,
  identidad del cliente, topic, QoS, keepalive, consumidor, estados/códigos esperados, tratamiento
  de certificados/credenciales y prueba reversible en broker y cliente aislados.
- **Pendiente local:** no hay una receta aceptada que realice y guarde diagnosis completa por
  familia/protocolo; los ejemplos prueban que hay material de referencia, no que exista una
  conexión viva ahora.
- **Superficie agente:** `tia-inspect` es útil para el inventario PLC y la lectura de fuente. Los
  detalles de conexión/red y su estado online deben confirmarse en el esquema vivo del perfil o
  en la vista de TIA; no inventar una herramienta MCP. La vista `Online & diagnostics` y los
  diagnósticos detallados de conexiones son procedimientos de TIA Portal.
- **Computer Use:** para TIA GUI, comprobar el plugin nativo de la sesión (`node_repl` +
  `@oai/sky`), elegir una ventana de la lista devuelta y verificar título/estado antes de actuar.
  `mcp__cua_repl` es solo navegador; su `apps=[]` no mide el control nativo de Windows. No declarar
  ejecutadas acciones visuales si no se observó el objetivo y la operación concreta. Si el plugin
  está deshabilitado o la ventana/proyecto no se identifica de forma inequívoca, detener el paso GUI
  y solicitar evidencia con contexto.

## Precondiciones

1. Ejecutar Doctor. Si hay una ventana TIA visible, identificarla primero con Computer Use nativo
   (`node_repl` + `@oai/sky`) y confirmar título, proyecto y versión antes de cualquier `Connect`.
   Si el objetivo no es inequívoco, detenerse sin conectar ni abrir otra instancia. Después, usar
   `Attach` solo si el perfil MCP real lo expone y apunta al proyecto identificado; `Connect` no
   adjunta por sí solo la ventana visible. Leer `GetProjectTree` y `GetSoftwareTree` y copiar las
   rutas exactas. Toda secuencia MCP pasa por
   `30-tools/scripts/Invoke-McpToolSequence.ps1`, que conserva una sesión y el lease
   `Local\TIA-Claude-McpSession`; si está ocupado, esperar hasta timeout y fallar, sin lanzar
   otra sesión concurrente. Si la ventana TIA visible no es inequívocamente ese proyecto, no abrir
   otra ni sustituirla; solo usar `Attach` si el servidor activo la expone y apunta al proyecto
   objetivo.
2. Definir una sola conexión y escribir su tipo: PROFINET IO, conexión S7, HMI–PLC, OPC UA,
   TCP/UDP abierto u otra familia con procedimiento específico. MQTT, por ahora, solo se inventaría
   sin declarar diagnóstico ejecutable. Registrar endpoint local/remoto, partner, IP/subred/puerto o
   nombre de conexión, símbolo de estado del programa (`STATUS`/código o status OPC UA) y la
   lectura/heartbeat inocua que servirá como prueba de aplicación.
3. Para datos online, confirmar interfaz PG/PC y target por tipo, nombre, MAC/IP u otra identidad
   suficiente. Si no se puede distinguir con certeza una CPU de prueba de una física, asumir
   física y limitarse a lectura no intrusiva.
4. No copiar secretos a los informes: contraseñas, PSK, claves privadas, tokens y credenciales
   se redactan. Conservar fingerprint/identificador del certificado si resulta útil, nunca la
   clave privada.
5. Esta ruta online es de lectura: no escribir tags, cambiar el estado de una conexión, reiniciar,
   compilar con cambios pendientes ni alterar PG/PC, direcciones o dispositivos. La sección D no
   forma parte del diagnóstico de lectura; solo se habilita tras preparar y verificar un fixture
   virtual desechable con backup y evidencia de aislamiento.

## Secuencia

### A. Revisar lo configurado sin conexión

1. Leer el árbol de dispositivos y la vista `Devices & networks`; localizar PLC, CP, switch,
   IO-device, HMI, endpoint OPC UA u otro partner. No deducir el partner por un nombre de bloque.
2. Comparar los valores de proyecto con la especificación: IP/subred, interfaz, nombre PROFINET,
   relación IO-controller/device, connection ID, dirección/puerto, tipo de conexión, parámetros
   de seguridad/certificado y recursos configurados. Si el MCP no expone un atributo, abrir su
   objeto en TIA y marcar el dato como leído allí.
3. Para el programa, leer completo el bloque de comunicación y su interfaz. Identificar el
   parámetro `STATUS`/diagnóstico, el estado de conexión y la política de reintento. En OPC UA,
   revisar endpoint, seguridad, confianza del certificado y NodeIds sin revelar credenciales.
4. La ruta de lectura no compila el proyecto original. Si hace falta verificar compilación o
   direcciones, hacerlo en una copia/fixture desechable con backup; guardar errores y avisos.
   Una compilación limpia no demuestra conectividad online.

### B. Comprobar la presencia del endpoint en la interfaz adecuada

1. En TIA, abrir `Online access`, seleccionar la interfaz PG/PC **conocida**, ejecutar
   `Update accessible devices` y capturar identidad/tipo/MAC/IP/nombre que TIA muestre.
   Antes de buscar, verificar que la interfaz y el alcance están autorizados; la búsqueda enumera
   dispositivos accesibles por esa interfaz y puede recorrer una red grande. Preferir una interfaz
   o red de prueba y detener la búsqueda cuando aparezca el endpoint objetivo. No escanear una
   interfaz conectada a la red de planta sin autorización expresa del responsable de esa red.
   Siemens documenta que la búsqueda se limita a la interfaz seleccionada y que los detalles pueden
   tardar en redes con muchos dispositivos ([dispositivos accesibles en V20](https://docs.tia.siemens.cloud/r/en-us/v20/using-online-and-diagnostics-functions/displaying-accessible-devices)).
   Es una consulta de solo lectura, pero no implica alcance cero. Si no hay plugin Computer Use nativo disponible o no se ha
   identificado de forma inequívoca la ventana objetivo, no afirmar que se abrió la vista ni que se
   ejecutó el escaneo: dejarlo pendiente y pedir evidencia al usuario. `apps=[]` de `cua_repl` no
   es un criterio para decidir disponibilidad de la GUI Windows.
2. Contrastar el dispositivo hallado con el hardware del proyecto. La presencia en la lista solo
   demuestra accesibilidad por esa interfaz; no acredita que sea el dispositivo previsto ni que
   la conexión de aplicación esté activa.
3. No asignar IP ni nombre de dispositivo, no parpadear LED para identificar un target sin
   autorización local, no cambiar adaptadores a ciegas y no ejecutar búsqueda amplia sobre una
   red de planta. Si la identidad no coincide, parar.

### C. Leer diagnosis del dispositivo y de la conexión

1. Desde el dispositivo identificado, abrir `Online & diagnostics` y leer estado general,
   interfaz/puerto, módulo/IO-device y diagnostic buffer. Registrar mensajes literales,
   timestamp, CPU y módulos asociados. No borrar buffer ni emitir comandos de mantenimiento.
2. En la vista de red/conexiones, seleccionar solo la conexión objetivo y abrir
   `Diagnostics > Connection information`. Guardar icono/estado, datos de conexión y detalles
   de dirección que se ofrezcan.
3. Registrar qué extremos estaban conectados online. Si solo hay online uno de los dos
   partners, el diagnóstico puede cubrir solo ese extremo; la vista no equivale a diagnóstico
   completo de una conexión configurada en ambos lados.
4. Para PROFINET, correlacionar estado de puerto y diagnóstico del IO-device con el buffer de la
   CPU y los contadores disponibles. Para OPC UA, registrar estado de servidor/sesión y
   `StatusCode` del cliente. Para `TSEND_C`/`TCON` u Open User Communication, registrar
   `STATUS`/`ERROR` del bloque y la diagnosis de la conexión configurada. Para HMI, registrar el
   estado de canal/conexión y el diagnóstico del runtime de su familia.
5. Si la vista correspondiente no existe para ese dispositivo/protocolo, consignar
   `NotSupported/no expuesto` y escoger la fuente de diagnosis específica del producto; no
   extrapolar datos de otro PLC o driver.

### D. Prueba mutante opcional: confirmar el flujo solo en fixture virtual

1. No iniciar esta fase desde un proyecto live ni desde la ruta de solo lectura. Crear/seleccionar
   una copia desechable cuyo manifiesto identifique el `.ap20` exacto y su backup coincidente;
   verificar hash/restauración prevista. Para escritura PLC, comprobar independientemente
   `GetBlocks.isFailsafe=false`, SCL, no protegido y ausencia de tags Safety cuando corresponda.
2. Antes de cualquier test PLC, regenerar `70-runs/simulation/readiness-latest.json` con
   `Write-TiaSimulationReadiness.ps1`. Exigir `plcsimCompatibleWithTia=true` para la pareja TIA /
   PLCSIM Advanced, además de la compatibilidad exacta CPU/firmware de Siemens. Si el gate falta,
   es falso o la versión del adaptador/API no está validada con ese runtime, parar antes de iniciar
   la instancia o llamar `DownloadToPlc`. Superado ese gate, Softbus exige registrar
   `networkMode=SOFTBUS` y `PLCSIM` como ruta PG/PC. TCP/IP exige `plcsimVirtualAdapterReady=true`.
   En ambos casos identificar la instancia virtual y el endpoint de cada partner. Softbus no tiene
   IP de runtime (`ip=null`): si hace falta una dirección PLC, usa la IP configurada en el proyecto.
   TCP/IP local exige IP de instancia/NIC coincidente y subred de prueba aislada. Verificar que no
   existe puente/ruta hacia la NIC física ni hacia la red de planta. Si endpoint o aislamiento no se
   pueden probar, detenerse y tratarlo como target físico.
3. Para una mutación de proyecto, usar el perfil correcto y su reconocimiento explícito:
   `tia-inspect --isolated --fixture-root <run-dir> --allow-write` para una escritura soportada,
   o `tia-create` `create`/`full` para la capacidad HMI/red correspondiente. Ejecutar primero
   `dryRun`/preview donde exista, verificar el plan antes de aplicarlo y serializar las llamadas
   MCP con `Invoke-McpToolSequence.ps1` y su lease global. Si el perfil, esquema, preview o gate
   de seguridad no está disponible, no hacer la mutación.
4. En el fixture, usar una tag/heartbeat de prueba acordada y un endpoint simulado que corresponda
   a la conexión concreta. La escritura de tag para demostrar bidireccionalidad solo se permite
   sobre esa instancia virtual desechable, con valores registrados y limpieza posterior. No usar
   tag de salida real ni valor que pueda mover actuadores.
5. Para una conexión configurada en ambos extremos, evaluar y registrar ambos endpoints.
   Un `ping`, `Connect`, acceso visible o compilación por sí solos no prueban que la aplicación
   intercambia los datos correctos.
6. No simular desconexión quitando cable, deshabilitando NIC/puerto o parando una CPU física.
   Para probar pérdida/recuperación, usar solo un entorno virtual aislado y un escenario
   reversible documentado.
7. Al terminar, restaurar el fixture desde el backup verificado, detener la instancia PLCSIM,
   devolver los valores de prueba a su baseline y registrar que no quedan escrituras/forzados.
   Si la restauración, el estado virtual o la limpieza no se verifican, informar el estado y no
   continuar con otra prueba.

## Interpretación por capas

| Evidencia | Permite afirmar | No demuestra |
|---|---|---|
| Configuración offline + compilación en copia desechable | La configuración/compilación de esa copia es coherente | Que el endpoint esté accesible |
| Endpoint aparece en Online access | Hay un dispositivo accesible en esa interfaz | Que sea el partner correcto o que la aplicación intercambie datos |
| Estado `Connection information` | Estado reportado por el extremo/partner online consultado | El estado del otro extremo si no está online o no soporta la diagnosis |
| `STATUS`/diagnóstico OPC UA + cambio de tag en PLCSIM dentro del fixture (fase D) | La ruta de aplicación probada en esa combinación | La red, certificados, firmware y timing de la instalación física |
| Intercambio en pruebas de FAT/SAT | Las variables/casos probados en esa instalación | Otras conexiones, secuencias o ventanas temporales no probadas |

## Evidencia

Guardar en el run de `70-runs/`:

- protocolo, función, ruta exacta, source/destination, target identity, interfaz PG/PC;
- captura/export de configuración offline y diagnóstico online con hora, mensajes literales,
  versión de TIA, CPU/CP/firmware y partners efectivamente online;
- `STATUS`/errores/counters y heartbeat/lectura, con el resultado esperado y observado;
- problemas descartados frente a hechos aún no comprobados;
- fixture, plan, logs y estado `stopped` si se usó PLCSIM;
- para fase mutante: manifiesto/backup/hash del fixture, identidad Softbus local o NIC Siemens TCP/IP
  con IP coincidente,
  IP/endpoints virtuales, evidencia de subred aislada y evidencia de limpieza/restauración;
- secretos eliminados del informe.

## Parar si

- proyecto, partner, interfaz o dispositivo no están identificados sin ambigüedad;
- aparece un PLC físico no autorizado, proyecto de cliente, CPU F/Safety para cualquier cambio,
  o riesgo de alterar el proceso;
- la solución aparente requiere descargar, cambiar modo CPU, asignar IP/nombre, actualizar
  firmware, cambiar certificados, aceptar confianza, reiniciar, resetear, forzar o desconectar;
- la diagnosis/driver no soporta el protocolo o falta un endpoint: reportar la evidencia que
  falta y dejarlo como bloqueado, sin declarar causa raíz;
- hay credenciales, certificados o estados de seguridad que no pueden capturarse sin exponerlos.

## Referencias Siemens

- [Acceso online e interfaces PG/PC, V20](https://docs.tia.siemens.cloud/r/en-us/v20/using-online-and-diagnostics-functions/configuring-the-pg/pc-interface/online-access)
- [Mostrar dispositivos accesibles, V20](https://docs.tia.siemens.cloud/r/en-us/v20/using-online-and-diagnostics-functions/displaying-accessible-devices)
- [Leer el diagnostic buffer de una CPU, V20](https://docs.tia.siemens.cloud/r/en-us/v20/device-and-network-diagnostics/hardware-diagnostics/checking-a-module-for-defects/reading-out-the-diagnostics-buffer-of-a-cpu)
- [Overview de connection diagnostics, V20](https://docs.tia.siemens.cloud/r/en-us/v20/device-and-network-diagnostics/connection-diagnostics/overview-of-connection-diagnostics)
- [Detailed connection diagnostics, V20](https://docs.tia.siemens.cloud/r/en-us/v20/device-and-network-diagnostics/connection-diagnostics/detailed-connection-diagnostics/detailed-connection-diagnostics-overview)
- [Cliente OPC UA S7-1500: estados de conexión, V20](https://docs.tia.siemens.cloud/r/en-us/v20/configuring-automation-systems/using-opc-ua-communication-s7-1200-s7-1500-s7-1500t/using-the-s7-1500-cpu-as-an-opc-ua-client-s7-1500-s7-1500t/useful-information-about-the-client-instructions-s7-1500-s7-1500t)
