# PLCSIM Advanced runtime probes

Este componente comprueba la presencia y la inicialización de la API nativa de
PLCSIM Advanced. Incluye dos niveles:

- el probe administrado, que solo inicializa la API y consulta el contador;
- el adaptador C++ nativo, que además registra una CPU virtual temporal y la
  desregistra inmediatamente, sin encenderla ni descargar ningún programa.

El probe administrado busca las APIs instaladas y selecciona la versión más reciente que tenga
tanto el DLL como la cabecera Siemens. Lee `DAPI_DLL_INTERFACE_VERSION` de la cabecera junto al DLL
para que ambos valores coincidan. La instalación actual expone API 7.0:

- `Siemens.Simatic.Simulation.Runtime.Api.x64.dll`
- `SimulationRuntimeApi.h`
- entry points `RuntimeApiEntry_Initialize` y `RuntimeApiEntry_DestroyInterface`

El probe valida esos dos entry points, puede consultar el número de instancias
registradas y libera inmediatamente el manager. El adaptador nativo añade una
prueba aislada de registro y limpieza, manteniendo apagados los controladores.

```powershell
dotnet run --project .\30-tools\plcsim\TiaClaude.PlcSimProbe.csproj -- --json
```

Para incluir la consulta del contador del Runtime Manager:

```powershell
dotnet run --project .\30-tools\plcsim\TiaClaude.PlcSimProbe.csproj -- --json --manager-count
```

La ruta por defecto es `CommonProgramFiles(x86)\Siemens\PLCSIMADV\API\<versión>` y se elige la
versión más alta completa. Para probar otra, se puede pasar `--api-dll <ruta-completa>`; la
cabecera `SimulationRuntimeApi.h` correspondiente debe estar junto al DLL.

El adaptador nativo requiere LLVM `clang-cl`, Visual Studio Build Tools con el
Windows SDK y la API instalada por PLCSIM Advanced:

```powershell
.\30-tools\plcsim\Build-PlcSimAdapter.ps1 -Force
.\30-tools\plcsim\bin\v7\tia-claude-plcsim-adapter.exe --inspect
.\30-tools\plcsim\bin\v7\tia-claude-plcsim-adapter.exe --register-inspect
.\30-tools\plcsim\bin\v7\tia-claude-plcsim-adapter.exe --register-disposable
.\30-tools\plcsim\bin\v7\tia-claude-plcsim-adapter.exe --power-on-disposable
```

`--register-inspect` crea una instancia temporal, informa de sus propiedades y
la limpia; sirve para comprobar la base de la ruta de simulación.
`--register-disposable` es una prueba de ciclo de vida, no una prueba de
comportamiento del PLC. `--power-on-disposable` añade un arranque y apagado
controlados de la CPU virtual, pero tampoco descarga un proyecto ni lee/escribe
tags. La descarga y la prueba de comportamiento requieren una fase de
simulación explícita y sus propios gates de seguridad.

## Compatibilidad TIA Portal / S7-PLCSIM Advanced

**Sí se conectan, con versiones compatibles.** Siemens documenta Softbus (`PLCSIM`) y TCP/IP entre
STEP 7 y PLCSIM Advanced. El manual V6.0 UPD1 cubre proyectos TIA V14–V19 y CPU FW V1.8–V3.1;
Advanced V7.0 cubre TIA V14–V20 y CPU FW V1.8–V4.0. Este host tiene TIA V20, PLCSIM Standard V20
y PLCSIM Advanced V7.0.0.0/API 7.0; la pareja cumple el rango general documentado por Siemens.
La inicialización del API y el ciclo nativo de una CPU desechable están verificados; la descarga de
un proyecto TIA V20 y su comportamiento siguen pendientes. `Go online` por sí solo no prueba una
descarga ni el comportamiento.

Una vez emparejadas las versiones, Softbus es la ruta local recomendada porque limita comunicación
al mismo PC/VM y evita cambiar la red de Windows. TCP/IP solo se usa cuando la prueba necesita
Ethernet, en `<Local>`, con la NIC Siemens aislada y dirección IP comprobada.

**Procedimiento oficial del workspace:** los agentes deben seguir [R17 — Aceptación conductual en
PLCSIM Advanced](../../10-kb/20-recetas/R17-aceptacion-plcsim.md) de principio a fin. Selecciona el
producto consultando la tabla de CPU/firmware de la versión instalada; no infieras compatibilidad
solo por la familia del PLC. Si esa matriz no incluye el modelo y firmware exactos, no descargues.
Para una CPU S7-1500 compatible, el orden es: fixture aislada → preflight Safety/protección → activar
simulación durante compilación y compilar → `PLCSIM`/Softbus → una instancia virtual compatible →
confirmar `CPU-1500 Simulation` y el aviso de target simulado → descargar → RUN → prueba de E/S con
expectativas → apagar/desregistrar. Nunca se considera suficiente que el proceso esté instalado,
la instancia esté encendida, la compilación pase o TIA muestre `Online`.

Fuentes Siemens: [novedades V20 y compatibilidad Advanced V7](https://docs.tia.siemens.cloud/r/en-us/v20/what-s-new-in-tia-portal/changes-in-previous-versions-of-tia-portal/changes-in-tia-portal-v19/engineering-options), [manual Advanced V7.0](https://support.industry.siemens.com/cs/attachments/109977691/s7-plcsim_advanced_function_manual_en-US_en-US.pdf), [manual Advanced V6.0 UPD1](https://cache.industry.siemens.com/dl/files/578/109955578/att_1267815/v1/s7-plcsim_advanced_function_manual_en-US.pdf), [qué es Advanced y Softbus](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_20/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced-api/product-overview/what-is-s7-plcsim-advanced), [Control Panel](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_20/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced/simulating/simulating-a-cpu/control-panel-user-interface/s7-plcsim-advanced-control-panel),
[adaptador virtual Siemens V20](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_itit_20/comprehensive-information/cpu-function-manuals/s7-plcsim-advanced/simulating/simulating-a-cpu/network-addresses-in-the-simulation/siemens-plcsim-virtual-ethernet-adapter?contentId=RFch406CfaoJt7FYIXsVMw),
[comunicación local vía Softbus y descarga, manual oficial PLCSIM Advanced V6.0 UPD1](https://cache.industry.siemens.com/dl/files/578/109955578/att_1267815/v1/s7-plcsim_advanced_function_manual_en-US.pdf), [propiedad de simulación en TIA Portal V20](https://docs.tia.siemens.cloud/r/en-us/v20/editing-projects/creating-and-managing-projects/displaying-properties-of-the-project). El procedimiento y la matriz de CPU se deben volver a cotejar si cambia TIA, PLCSIM o el firmware instalado.

En `S7-PLCSIM Advanced Control Panel`:

1. Para la ruta normal, elige **`PLCSIM` (Softbus)** en `Online Access`. Es el valor
   predeterminado; TIA y la instancia deben estar en el mismo PC/VM. Esta ruta limita el acceso a
   la máquina local y evita comunicar o descargar accidentalmente a hardware real.
2. Enciende una sola instancia compatible con la CPU estándar del proyecto y deja apagadas las
   demás. En Softbus varias instancias pueden compartir la IP predeterminada y el diálogo de TIA
   no distinguirlas.
3. Usa TCP/IP solo cuando la prueba necesite Ethernet. Elige `TCP/IP Single Adapter`, configura
   `<Local>`, no puentes adaptadores físicos a la red y asigna una IP fija al adaptador Siemens en
   la misma subred de la IP PLC leída del proyecto.

Configurar la IP del adaptador es una operación de Windows que necesita PowerShell elevado. El
helper siguiente comprueba identidad exacta del adaptador, subred, conflicto de IP y ausencia de
otra interfaz activa en esa subred; guarda la configuración anterior antes de cambiarla. El
preview es solo lectura:

```powershell
.\30-tools\scripts\Set-TiaPlcSimVirtualAdapterIp.ps1 `
  -TargetIpAddress '192.168.0.1' `
  -VirtualAdapterIpAddress '192.168.0.2' `
  -PrefixLength 24
```

Para aplicar (solo desde una consola elevada y con `<Local>` confirmado en el panel):

```powershell
.\30-tools\scripts\Set-TiaPlcSimVirtualAdapterIp.ps1 `
  -TargetIpAddress '192.168.0.1' `
  -VirtualAdapterIpAddress '192.168.0.2' `
  -PrefixLength 24 -Apply -AcknowledgeLocalOnly
```

Los valores son ejemplo: la IP de CPU, máscara y subred de host deben leerse del proyecto y
adaptador live. Para restaurar la configuración previa:

```powershell
.\30-tools\scripts\Set-TiaPlcSimVirtualAdapterIp.ps1 -TargetIpAddress '192.168.0.1' `
  -VirtualAdapterIpAddress '192.168.0.2' -PrefixLength 24 -Restore
```

### Iniciar y cargar el proyecto — Softbus (predeterminado)

La CPU virtual debe ser estándar (no F) y corresponder al modelo del proyecto. El modo
`--register-acceptance` solo acepta las familias estándar 1511, 1513, 1515 y 1517; nunca registra
una F-CPU. Ejemplo para una fixture cuyo árbol/modelo live y dirección confirman una 1513:

```powershell
.\30-tools\plcsim\bin\v7\tia-claude-plcsim-adapter.exe `
  --register-acceptance --name TIAClaudeAcceptance_1513 --cpu 1513 `
  --transport softbus --timeout-ms 60000
```

El resultado inicial debe ser `status: ready`, `networkMode: SOFTBUS`, `binding: local-only`,
`interfaceName: PLCSIM`, `ip: null` y códigos API `0x0`. El proceso conserva la instancia hasta
recibir `stop` por stdin; entonces apaga, desregistra y destruye la instancia. Verifica que la
limpieza termine en `status: stopped`.

### Consultar una instancia ya registrada (solo lectura)

Antes de crear, encender, apagar o descargar, se puede leer el estado de una instancia existente:

    .\30-tools\plcsim\bin\v7\tia-claude-plcsim-adapter.exe --inspect-registered-instance --name TIAClaudeAcceptance_1513

El comando devuelve nombre, CPU, interfaz, estado operativo, IP y códigos de lectura/liberación.

En una instancia ya registrada, `--behavioral-smoke-existing` comprueba una transición
del programa mediante los tags `Cmd_Enable` y `Status_Active`. Solo acepta una instancia
registrada, CPU estándar 1513, Softbus y estado RUN; pone `Cmd_Enable` a falso y a verdadero,
verifica `Status_Active` y restaura el valor inicial de `Cmd_Enable`. No descarga, apaga ni
desregistra la instancia. Usar únicamente tras confirmar en TIA que el destino es CPU simulada:

```powershell
.\30-tools\plcsim\bin\v7\tia-claude-plcsim-adapter.exe `
  --behavioral-smoke-existing --name TIAClaudeAcceptance_1513
```
No registra ni elimina instancias, no la enciende ni apaga, y no descarga. Los estados API Stop y
Run se deben distinguir del mero conteo de instancias registradas; la interfaz gráfica por sí sola
no siempre deja claro el estado cíclico. Si el nombre no existe, no crea un reemplazo.

En TIA Portal, antes de la primera descarga:

1. En propiedades del proyecto, pestaña **Protection**, activa **Support simulation during block
   compilation**. En TIA Portal V20 está desactivada por defecto. Guarda y recompila después de
   cambiarla. Openness V20 expone `Project.IsSimulationDuringBlockCompilationEnabled`; en el host
   la propiedad se activó por Computer Use sobre el fixture desechable. Después de recompilar,
   `GetBlocks` confirmó `PLCSimAdvancedSupport=true` en `Main` y `FB_AgentDemo`.
   [Evidencia de compilación](../../70-runs/acceptance/plcsim-visible-compile-20260924.json) y
   [lectura posterior](../../70-runs/acceptance/plcsim-postcompile-inspection-20260924.json). El
   snapshot y backup reproducibles quedaron en
   `90-tmp/e2e/20260924-plcsim-simulation-support-enabled/`; al crearla, el manifiesto se validó.
   La relectura de la copia final adjunta a la ventana visible confirmó el atributo en ambos
   bloques: [GetBlocks live](../../70-runs/acceptance/plcsim-enabled-fixture-readback-20260924.json).
   **Estado actual (2026-09-25):** el manifiesto ya no valida: TIA regeneró archivos de
   `IM/SearchIndex` en `project/` y esa carpeta dejó de coincidir byte a byte con `backup/`. No
   reutilices la fixture para descargar hasta restaurar una copia exacta del backup y volver a
   validar el manifiesto. La lectura anterior es evidencia histórica, no autorización de descarga.
2. Antes de descargar, exige un inventario que incluya `isFailsafe=false` para cada bloque,
   `isKnowHowProtected=false`, clasificación explícita de todos los tags Safety y conteos completos.
   `tia-inspect` sí obtuvo esa clasificación en otra fixture aislada
   ([lectura F/Safety](../../70-runs/acceptance/plcsim-inspect-safety-readback-20260925.json));
   `tia-create full`, que anuncia `DownloadToPlc`, no expuso `GetTags` ni `GetBlocks.isFailsafe`.
   No combines respuestas de sesiones/proyectos distintos como permiso para escribir. La descarga
   automatizada sigue bloqueada hasta que un runner ate ambas lecturas a la misma identidad/hash de
   fixture y las vuelva a comprobar antes de descargar. No infieras seguridad por el modelo de CPU.
3. Compila y confirma `Success`, 0 errores y 0 avisos.
4. En `Download to device`, elige `PLCSIM` como interfaz PG/PC (Softbus). No elijas Ethernet,
   Wi-Fi, VPN ni una interfaz física.
5. Revisa la previsualización de carga: exige el mensaje de TIA **“The downloads are performed on
   a simulated CPU”** y el dispositivo `CPU-1500 Simulation` en la primera descarga. Cancela si
   TIA muestra una CPU física o un destino ambiguo. Siemens especifica que la instancia se inicializa
   con la primera descarga desde TIA Portal.
6. Tras cargar, confirma tipo/firmware e identidad online. Ejecuta el plan funcional con entradas
   virtuales y lectura de salidas/tags; conserva cada respuesta y resultado esperado.
7. Un online correcto o una compilación correcta no demuestra comportamiento. La aceptación solo
   queda verificada si las transiciones del plan pasan y la instancia se limpia.

Para automatización, usa `Invoke-TiaSimulationAcceptance.ps1` solo en una fixture exacta, tras
validar el manifiesto y el backup. El runner consulta en la preflight live `GetBlocks.isFailsafe`,
protección, consistencia, `PLCSimAdvancedSupport` y el inventario completo `GetTags`; el servidor
repite las barreras de Safety/protección en la llamada de descarga. Además, el runner exige
`-SimulationTargetEvidencePath` con el contrato de R17 antes de iniciar el adaptador o contactar al
servidor. Esta declaración debe proceder de Computer Use nativo y estar vinculada a proyecto,
dispositivo, versión, IP y ruta exactos; no la rellenes basándote solo en que Softbus esté activo.

Las pruebas mock comprueban el fail-closed, la identidad del target y el formato del informe, pero
no prueban una descarga live ni validan por OCR la captura. El agente debe leer el diálogo real de
TIA, exigir `CPU-1500 Simulation` y **“The downloads are performed on a simulated CPU”**, guardar la
observación/evidencia y solo entonces ejecutar el runner. No llames directamente a `DownloadToPlc`
para omitir esta puerta ni marques aceptación por conectar o compilar. La preflight live de
2026-09-28 pasó en una fixture nueva, pero su runner fue interrumpido antes de generar un informe
final; por ello no hay evidencia de descarga ni comportamiento aceptado.

Si el proyecto o la instancia son nuevos, `GoOnline` puede fallar antes de la primera descarga:
Siemens indica que el primer download inicializa la instancia y muestra el dispositivo compatible
en el diálogo de carga. Por eso `NotReachable` antes de esa carga no sustituye la prueba de la
ruta de descarga. Después de cargar, si `GoOnline` falla, revisa primero el modo activo y la ruta
PG/PC: `PLCSIM` para Softbus; NIC Siemens con IP fija y `<Local>` para TCP/IP.

### Revalidación de la fixture AgentDemo — 2026-09-25

La lectura MCP de la copia en `70-runs/e2e/20260925-plcsim-scaffold/isolated-fixture/` encontró
`PLCSimAdvancedSupport=true` para ambos bloques estándar y metadata completa sin F/Safety. Sin
embargo, una nueva validación del manifiesto quedó bloqueada porque un proceso TIA mantiene abierto
el `.ap20`; la ventana visible muestra el título de esa fixture, pero su barra de estado dice
`Project closed`, y existe además un proceso Portal sin ventana titulada. No se detuvo ningún
proceso y no se intentó descargar. Revisa el estado anotado en
[`plcsim-fixture-readiness.md`](../../70-runs/e2e/20260925-plcsim-scaffold/plcsim-fixture-readiness.md)
y la [captura de Computer Use](../../70-runs/e2e/20260925-plcsim-scaffold/computer-use-tia-window-20260925.json).
La descarga sigue bloqueada hasta que se libere el handle, el backup/manifiesto vuelva a validar y
la instancia virtual se identifique positivamente como destino simulado.

### Evidencia histórica de TCP/IP — 2026-09-24

- **Verificado:** PLCSIM Advanced V6.0 Update 1 en TCP/IP Single Adapter + `<Local>`; el runtime
  nativo registró y encendió una instancia estándar 1513, configuró `192.168.0.1` y limpió la
  instancia con todos los códigos `0x0`.
- **Verificado:** TIA V20 leyó `AgentDemo_V20`, CPU estándar 1513-1 PN, IP `192.168.0.1`, y la
  compilación quedó en 0 errores/0 avisos. `CheckDownloadReadiness` listó exactamente la ruta
  `Siemens PLCSIM Virtual Ethernet Adapter`.
- **Verificado:** la NIC virtual Windows solo tenía `169.254.242.16/16`; la Wi-Fi estaba en
  `192.168.1.0/24`. Con esa configuración TIA `GoOnline` devolvió `NotReachable`.
- **Bloqueado:** asignar `192.168.0.2/24` a la NIC virtual requiere elevación. El intento
  read-only/actualización devolvió `Access denied` y no cambió ninguna interfaz. Hay que ejecutar
  el helper elevado una vez; el estado previo está documentado en
  `70-runs/acceptance/plcsim-tia-ip-state-20260924.json`.
- **Bloqueado entonces:** no se descargó el programa porque el perfil usado no exponía
  `isFailsafe`. La inspección aislada posterior del 2026-09-25 sí obtuvo esa propiedad para una
  fixture exacta; esto no cambia el estado de descarga pendiente.

La evidencia de llamadas MCP está en `70-runs/acceptance/plcsim-tia-*-20260924.json`. El intento
anterior de 2026-09-17 con mapping/binding (`plcsim-ip-binding-20260917.json`) queda supersedido
para la ruta TCP/IP local: no se debe repetir `SetNetInterfaceMapping` ni cambiar bindings globales
para esta ruta.

- **Verificado:** PLCSIM Advanced V6 registró y encendió una CPU estándar 1513 en modo Softbus
  (`status=ready`, `networkMode=SOFTBUS`, códigos API `0x0`). TIA Portal V20 conectó visualmente
  `PLC_1` a esa instancia desde `Go online`; la barra de estado confirmó `Connected to PLC_1`.
- **No verificado:** la descarga y el comportamiento cíclico aún no se han aceptado. La prueba de
  conexión Softbus fue solo `Go online`, sin descarga de programa ni observación de comportamiento.
- **Alternativa TCP/IP local bloqueada:** la NIC Siemens estaba en APIPA `169.254.242.16/16`, no en
  la subred PLC `192.168.0.0/24`; asignar una IP fija requiere elevación. Véase el helper
  `30-tools/scripts/Set-TiaPlcSimVirtualAdapterIp.ps1`.

- **Verificado — preflight independiente, 2026-09-24:** en una fixture desechable, `tia-inspect`
  clasificó los dos bloques (`isFailsafe=false`, sin know-how protection) y las dos tags
  (`isSafety=false`); la comprobación de manifiesto confirmó que la lectura no alteró el proyecto.
  Esta lectura resuelve el dato F/Safety para esa copia, pero no habilita la descarga: ambos bloques
  reportaron `PLCSimAdvancedSupport=false`. Después, en otra sesión Computer Use sobre el fixture
  exacto, se activó la propiedad y se recompiló 0/0; `tia-create full` aún omitió `isFailsafe` y
  devolvió `Unknown tool` para `GetTags`, por lo que se restauró la fixture original y se creó el
  nuevo snapshot con soporte de simulación. [Informe F/Safety](../../70-runs/acceptance/plcsim-inspect-safety-readback-20260925.json),
  [inspección posterior](../../70-runs/acceptance/plcsim-postcompile-inspection-20260924.json).

Fuentes Siemens V20 para simulabilidad del proyecto y la API: [propiedades del proyecto y opción
de simulación](https://docs.tia.siemens.cloud/r/en-us/v20/editing-projects/creating-and-managing-projects/displaying-properties-of-the-project),
[propiedad Openness `IsSimulationDuringBlockCompilationEnabled`](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/tia-portal-openness-api/functions-for-projects-and-project-data/updating-project-properties).

Mientras la instancia está viva acepta comandos de stdin, uno por línea, y devuelve un JSON por
línea. Las áreas admitidas son `input`, `output` y `marker`; el offset es un byte:

```text
read-area-size input
write-bit input 0 0 1
read-bit output 0 0
write-byte input 1 255
read-byte output 0
write-bool-tag Control_HMI.fromHMI.resetSimulation 1
read-bool-tag Control_HMI.toHMI.resetStatus
read-uint8-tag Control_HMI.toHMI.numWorkpieces
read-float-tag Control_HMI.fromHMI.longConveyor.varSpeedPercentage
stop
```

Este protocolo permite que una aceptación escriba sensores virtuales y lea salidas sin tocar un
PLC físico. Las operaciones `*-tag` usan los símbolos descargados de la CPU y permiten accionar
controles HMI y observar contadores sin depender de direcciones absolutas. El runner debe comprobar
`status: ok` y registrar cada respuesta; un error de lectura o escritura invalida la evidencia de
comportamiento.
