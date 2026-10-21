# ADR-015 — Estado real del workspace a 2026-10-21

- **Estado:** fotografía real del 2026-10-21. Actualiza a ADR-010 (estado real del 2026-09-15);
  no lo sustituye, porque aquel sigue siendo la referencia de lo que había entonces.
- **Alcance:** la aceptación de **bloques** sobre CPU virtual y el camino de escritura en un
  proyecto abierto. **No** cubre el objetivo global PA-1, que sigue pendiente (ver
  [No afirmamos todavía](#no-afirmamos-todavía)).
- **Evidencia primaria:**
  - `awesome-tia-portal/bloques-de-funcion/fb-alarm-latch/evidencia-plcsim-2026-10-21.json`
    (65/65 pasos, 9 casos) y su `informe-ejecucion-2026-10-19.md`.
  - `awesome-tia-portal/bloques-de-funcion/fc-escalado/evidencia-plcsim-2026-10-21.json`
    (33/33 pasos, 9 casos).
  - `awesome-tia-portal/MATRIZ-TRAZABILIDAD.md` (qué hay en cada carpeta del pack público).
  - Recetas [R28](../../10-kb/20-recetas/R28-aceptacion-plcsim.md) y
    [R29](../../10-kb/20-recetas/R29-portabilidad-powershell.md).
  - Run del CI: `57abcd7` y `0ebbcdc` en verde (13 checks, 0 FAIL).

## Hechos verificados

### 1. La aceptación de bloques en CPU virtual está hecha

Es el cambio de estado de fondo. Antes de esta fecha no había ninguna descarga a PLCSIM
aceptada; ahora hay dos bloques con fuente, compilación 0/0, descarga y comportamiento observado.

| Recurso | Pasos | Casos | Evidencia |
|---|---|---|---|
| `FB_AlarmLatch` | 65/65 | 9/9 | `fb-alarm-latch/evidencia-plcsim-2026-10-21.json` |
| `FC_Escalado` | 33/33 | 9/9 | `fc-escalado/evidencia-plcsim-2026-10-21.json` |

Los dos se descargaron **solo a CPU virtual** (CPU 1513-1 PN, `6ES7 513-1AM03-0AB0`, FW V3.0),
con `Download Success` de 0 errores y 0 avisos, y con `GoOnline` → `Online, isReachable=true`.

### 2. Las cuatro condiciones que la API de PLCSIM Advanced impone

Ninguna es evidente y **las cuatro** hacen falta a la vez. Medidas el 2026-10-21:

| # | Condición | Qué pasa si no se cumple |
|---|---|---|
| 1 | La sesión Openness va **adjunta** al TIA abierto (`AttachToOpenProject`), no aislada | `Connect to module PLC_1 failed`, aunque la CPU virtual esté viva y respondiendo por S7 |
| 2 | **~100 s** de margen tras arrancar el Control Panel de PLCSIM Advanced | La primera descarga falla; la segunda, ya asentada la OAM, funciona |
| 3 | `IInstance::UpdateTagList()` antes de la primera lectura simbólica | `-47` `SREC_NOT_UP_TO_DATE` |
| 4 | Los tags se nombran **sin el prefijo de tabla** (`Active`, no `Agent_Signals.Active`) | `-4` `SREC_DOES_NOT_EXIST` |

La 3 y la 4 son propiedades de la **API**, no del proyecto: la lista de etiquetas vive en
memoria compartida y la puebla `UpdateTagList()`, que lee los tags del VPLC.

### 3. Dos bugs reales del adaptador de PLCSIM, corregidos

- **RC-1**: el parser de IP rellenaba los octetos en orden de texto, pero la API los guarda
  invertidos (`IPs[3]` es el primero). La CPU recibía `1.0.168.192` en vez de `192.168.0.1`, y
  el `SetIPSuite` lo aceptaba con `0x0` y lo descartaba en silencio.
- **RC-2**: el camino de registro **nunca** enlazaba el puerto IE1 con la NIC
  (`SetNetInterfaceMapping`/`SetNetInterfaceBindings` estaban en código muerto).

### 4. H-19 queda refutada y H-23 confirmada

- **H-19 (refutada)**: la causa del bloqueo de descarga **no** era S7-PLCSIM clásico. Instalar
  el clásico V20 no cambió nada.
- **H-23 (confirmada dos veces)**: el hash del `.ap20` **no cambia** al modificar bloques. Se
  comprobó al añadir la tabla `Agent_Escalado`, el bloque `FC_Escalado` y un OB1 nuevo: el
  `.ap20` seguía con `37C36C5A88F8D694263D9AEA5EA8C80A3A6AC9B34A3A64FF8E3EF94D404846E6`. Los
  cambios van al `.info` y a la carpeta de trabajo.

### 5. Escribir en el proyecto abierto: `GoOffline` primero

Con la vista live en modo online, TIA rechaza la escritura con *"This function is not
supported in online mode"*. Con `GoOffline(softwarePath)` funcionan
`ImportPlcExternalSource`, `GenerateBlocksFromExternalSource`, `DeletePlcExternalSource` y
`SaveProject`. Detalle en [R28](../../10-kb/20-recetas/R28-aceptacion-plcsim.md).

### 6. El generador de fuentes SCL de TIA V20 es más restrictivo con un `FUNCTION`

Un FC no admite `VERSION`, `AUTHOR` ni `FAMILY`, y exige el tipo de retorno en la cabecera
(`FUNCTION "X" : Void`); sin él el parser se descuadra y el error salta en la línea siguiente,
sin señalar la causa real. La forma buena está en
[`FC_Escalado.scl`](https://github.com/iagorobo24-hub/awesome-tia-portal/blob/main/bloques-de-funcion/fc-escalado/FC_Escalado.scl).

### 7. El acceso simbólico de PLCSIM es a `Real`, no a `Int`

La API resuelve y escribe `Bool`, `UInt8` y `Real`. Para ejercitar un `Int`, el arnés declara la
variable de prueba como `Real` y convierte con `REAL_TO_INT` en el OB1. Y las comparaciones de
`Real` necesitan **tolerancia**: el adaptador serializa con 6 dígitos significativos.

### 8. Los dos tests que tenían el CI en rojo eran gates que dejaron de ser comprobables

- `Invoke-TiaMcp.ps1` evaluaba el toolchain **antes** que el manifiesto, así que en CI (donde
  `bin/` no está versionado) el error del ejecutable enmascaraba el del manifiesto.
- `Test-TiaSimulationAcceptanceSafety.ps1` nunca se actualizó tras la puerta de evidencia del
  destino simulado: el runner cortaba antes de llegar al gate de compilación.

Y de debajo salieron tres fallos de portabilidad que hacían que el test no corriera en un host
con Windows PowerShell 5.1 (mojibake de los glifos de caja → comillas tipográficas → error de
sintaxis; `$PSScriptRoot` vacío en el `param`; `-AsHashtable` inexistente). Todo en
[R29](../../10-kb/20-recetas/R29-portabilidad-powershell.md).

### 9. Entorno a 2026-10-21

| | |
|---|---|
| TIA Portal | **V20** build `2000.0.9501.1` |
| PLCSIM Advanced | **V7.0.0.0** (API 7.0, `0x00070000`) |
| PowerShell | **7.6.7** (instalado el 2026-10-21 con winget; antes solo había 5.1 en el host) |
| CI | verde: 13 checks, 0 FAIL, 1 WARN (`eval-freshness`, que ya estaba) |
| Transports de PLCSIM | TCP/IP sobre `Siemens PLCSIM Virtual Ethernet Adapter`; Softbus queda como alternativa |

### 10. El pack público dice la verdad

`awesome-tia-portal` tiene **2 de 24 recursos** con código importable, compilado y ejecutado
(`fb-alarm-latch` y `fc-escalado`); los otros **22 son fichas de diseño sin código**, y su
`MATRIZ-TRAZABILIDAD.md` lo desglosa. El catálogo gana el estado `verified` con su leyenda.

## Qué cambia respecto a ADR-010

| Afirmación en ADR-010 | A 2026-10-21 |
|---|---|
| "La simulación funcional PLC […] sigue sin demostrarse" | **Demostrada** para dos bloques: 9/9 casos cada uno, con evidencia |
| "No afirmamos que PLCSIM haya ejecutado una transición funcional" | **Afirmado** y con valores observados |
| "El bloqueo está en cómo TIA V20 resuelve esa ruta en esta máquina" | **Resuelto**: sesión adjunta + margen del Control Panel + `UpdateTagList()` + nombres sin prefijo |
| "Aceptación global (`accepted`) sigue en `false`" | **Sigue en `false`**: PA-1 es más amplio que la aceptación de bloques (ver abajo) |
| "El último run del CI falló en 2 checks" | **Verde** desde `c250cf1` |

## No afirmamos todavía

- **PA-1 entero.** El objetivo global de `00-meta/02-plan.md` es crear un proyecto
  `DEMO-Cinta01` completo (S7-1500, control de motor, HMI Unified, compilación 0/0, export
  textual, README) **y** responder preguntas de trazabilidad, desde sesión fría y sin
  intervención manual. Lo verificado aquí es la aceptación de bloques y el camino de descarga;
  la creación del proyecto con HMI y la trazabilidad siguen sin hacerse.
- **HMI en runtime.** WinCC Unified y Comfort siguen documentados (R13, R14, R20) y sin
  verificar en runtime.
- **Las 22 fichas del pack público.** Son especificaciones, no código. `fb-motor`,
  `fb-analog-input`, `fb-valve` y `fb-hourmeter` son las siguientes candidatas, y `fb-motor`
  además necesita su UDT.
- **Compatibilidad con TIA Portal V21** (ADR-014): receta escrita, sin verificar.
- **La misma cadena sobre otro bloque cualquiera.** Lo verificado son dos bloques concretos;
  la receta está escrita para reutilizar, pero no se ha comprobado que el tercero salga bien a
  la primera.

## Lo que hay que tener en cuenta al retomar

1. El **Control Panel de PLCSIM Advanced** debe llevar al menos ~100 s de margen tras
   arrancarse, y la instancia virtual necesita una sesión **elevada**.
2. Para escribir en un proyecto abierto: `GoOffline` antes, y `GoOffline` → `SaveProject` →
   `CloseProject` para cerrar sin que aparezca el diálogo de cambios sin guardar (que además
   impide adjuntarse por la API).
3. Un `FUNCTION` en TIA V20 no admite `VERSION`/`AUTHOR`/`FAMILY` y necesita `: Void`.
4. El plan de comportamiento compara `Real` con tolerancia, y un paso sin `expect` es válido.
5. PowerShell 7 está instalado: los tests que antes no eran ejecutables en este host ya lo son.
