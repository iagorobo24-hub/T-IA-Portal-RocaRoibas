# DEMO-Cinta01 - Cinta de transporte con motor M01

**Estado:** en desarrollo (demostración de la cadena de aceptación PA-1)
**TIA:** V20 · **CPU:** S7-1513-1 PN (`6ES7 513-1AM03-0AB0`) · **HMI:** WinCC Unified PC Runtime (`HMI_RT_1`, `6AV2123-3GB32-0AW0`)

## Qué hace

Una cinta de transporte con un único motor (M01) y seta de emergencia (ES01). La orden de
marcha, la de paro y el rearme de fallo llegan de la HMI o de pulsadores de campo; el contacto
auxiliar del contactor devuelve la confirmación de marcha. El bloque de control es
[`FB_Motor`](../../50-examples/demo-cinta01/sources/FB_Motor.scl) de la librería propia.

La seta de emergencia hace las dos cosas que tiene que hacer, y las dos están en el **punto de
llamada**, no dentro del bloque: **prohíbe arrancar** (el `Interlock` del FB exige `DI_ES01_Ok`) y
**ordena parar en marcha** (`CmdStop` incluye `NOT "DI_ES01_Ok"`). Si solo se hiciera la primera,
el motor seguiría girando con la seta pulsada, y eso no es una seta de emergencia: es un pulsador
de arranque.

## Arquitectura

- `PLC_1` — control principal. Bloques: `FB_Motor` (FB), `iDB_M01` (DB de instancia), `Main` (OB1 cíclico).
- `HMI_RT_1` — panel de operador. Conexión `HMI_Connection_1` a `PLC_1`, tabla `HMI_Tags` con 7
  tags de binding simbólico, pantalla `Main` (1280×720) con 3 botones, 4 lámparas y un rótulo.
- Red — PROFINET. La CPU virtual de las pruebas vive en `192.168.0.1`.

## Señales

Tabla de tags `Cinta_Signals` (10 tags, ninguno en la tabla por defecto). Nomenclatura de
[`20-standards/naming.md`](../../../20-standards/naming.md): prefijo por rol (`DI_`, `DO_`, `M_`),
equipo ISA-5.1 (`M01`, `ES01`), identificadores en inglés.

| Tag | Tipo | Papel |
|---|---|---|
| `DI_ES01_Ok` | Bool | Seta de emergencia, contacto normalmente cerrado: TRUE = **libre** |
| `DI_M01_Start` | Bool | Orden de marcha |
| `DI_M01_Stop` | Bool | Orden de paro |
| `DI_M01_Reset` | Bool | Rearme del fallo enclavado |
| `DI_M01_Feedback` | Bool | Confirmación de marcha (contacto auxiliar del contactor) |
| `DO_M01_Run` | Bool | Orden al contactor |
| `M_M01_Running` | Bool | Estado: marcha confirmada |
| `M_M01_Interlock` | Bool | Estado: arranque permitido |
| `M_M01_Fault` | Bool | Estado: fallo enclavado |
| `M_M01_FaultCode` | Int | Código de fallo (0 = sin fallo) |

## Estado del trabajo

- [x] Proyecto, CPU S7-1500 y HMI Unified creados desde un spec (`specs/scaffold.json`)
- [x] Tabla de tags `Cinta_Signals` con 10 tags
- [x] `FB_Motor` importado y `iDB_M01` + `Main` generados desde fuentes SCL
- [x] Compilación con **0 errores y 0 avisos** (software). Informe en [`ops/compile-report.json`](ops/compile-report.json)
- [x] Pantalla HMI `Main` con controles y bindings a tags
- [x] Export textual en [`src/`](src/) y nomenclatura verificada con `Check-TiaStandards.ps1` (exit 0)
- [ ] Descarga y ejecución en CPU virtual (PLCSIM): fuera del alcance de esta demostración

## Decisiones y cosas raras

- **El OB cíclico se llama `Main`, no `OB_Main`.** TIA nombra el OB1 del sistema y no admite que
  una fuente externa lo llame de otra forma: falla con *Type conflict: Object "OB_Main" cannot be
  overwritten*. El patrón `OB_<Función>` del estándar aplica a los OB de arranque y de error.
- **El DB de instancia se declara en la misma fuente SCL** (`DATA_BLOCK "iDB_M01"`). Sin esa
  declaración, la llamada `"iDB_M01"(...)` se resuelve como un tag y la compilación da 14
  errores: *Tag "iDB_M01" not defined* y *The formal parameter 'CmdStart' is invalid* para cada
  entrada.
- **`iDB_M01` y no `FB_Motor_DB`**: los DB de instancia van por equipo, no por bloque (ADR-008,
  N2), para que el número no aparezca cuando hay varios motores.
- **Los tags de la HMI llevan dirección absoluta** además del binding simbólico, porque sin
  dirección el read-back del binding no se puede verificar.

## Pendiente

- Descarga y plan funcional sobre CPU virtual, si esta demostración se quiere usar como
  acceptance de bloques y no solo como proyecto de muestra.
- Lógica de llenado de la cinta: hoy solo hay control de motor.
- Señalización yavisos de falta de tensión.

## Cómo se reproduce

```powershell
# 1. Proyecto, CPU, HMI, tags, fuentes SCL, compilación y guardado
.\30-tools\scripts\Invoke-AgentDemoScaffold.ps1 `
    -SpecPath .\50-examples\demo-cinta01\specs\scaffold.json -Apply

# 2. Pantalla HMI con sus bindings
.\30-tools\scripts\Invoke-TiaHmiScreenFromJson.ps1 `
    -ScreenJsonPath .\50-examples\demo-cinta01\hmi-screen.json `
    -ProjectFile <ruta>\DEMO-Cinta01.ap20
```

El runner del scaffold hace **dry-run primero** y solo crea con `-Apply`, y comprueba que no haya
ninguna TIA visible con un proyecto abierto antes de tocar nada.
