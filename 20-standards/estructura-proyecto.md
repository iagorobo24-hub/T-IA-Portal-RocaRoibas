# Estructura de un proyecto

> **Estado: PROPUESTA.** Ver [`README.md`](README.md).

## Dentro de TIA Portal

### Program blocks

```
Program blocks/
├── 00_System/        OB_Main, OB_Startup, OBs de error y diagnóstico
├── 10_Modes/         modos manual / automático / paro / emergencia
├── 20_Safety/        lógica de seguridad no-F (enclavamientos duros)
├── 30_Sequences/     secuencias de proceso, una por área o máquina
├── 40_Devices/       llamadas a FB_Motor, FB_Valve... una por equipo
├── 50_Analog/        escalado, filtrado, lazos PID
├── 60_Comms/         PROFINET, OPC-UA, Modbus, intercambio con otros PLC
├── 70_HMI/           lo que existe solo para servir al HMI
├── 80_Diagnostics/   alarmas, contadores, estadísticas, horas de marcha
└── 90_Library/       FB/FC reutilizables importados de 60-library/
```

🔒 **Numeración en decenas, con hueco.** Deja sitio para meter `35_` sin renumerar treinta
carpetas. El número comunica además el orden de ejecución mental: sistema → modos → seguridad →
secuencia → actuadores.

🔒 **`90_Library` es sagrada.** Lo que entra ahí viene de `60-library/` y **no se edita dentro
del proyecto**. Si hay que cambiar un bloque de librería, se cambia en la librería, se prueba, y
se reimporta. Si lo editas in situ, la próxima reimportación se lo lleva por delante y no te
enteras hasta que falla.

### PLC data types

```
PLC data types/
├── 10_Devices/       UDT_Motor, UDT_Valve, UDT_AnalogInput
├── 20_Process/       UDT_Recipe, UDT_Batch
└── 30_System/        UDT_Alarm, UDT_Diagnostic
```

### PLC tags

```
PLC tags/
├── 00_Hardware/      E/S físicas, una tabla por módulo o por armario
├── 10_Internal/      marcas de sistema y de coordinación
├── 20_HMI/           lo que lee y escribe el HMI
└── 30_Constants/     constantes de usuario
```

🔒 **No uses la `Default tag table`.** Es donde TIA tira todo lo que no clasificas, y crece
hasta ser inmanejable. Crea tablas con intención desde el primer día. *(Nota técnica: la tabla
por defecto tampoco se puede borrar por Openness, así que si se llena, te la quedas.)*

### HMI

```
Screens/
├── 00_Templates/     plantilla base, cabecera, pie, barra de navegación
├── 10_Overview/      sinóptico general
├── 20_Areas/         una pantalla por área o máquina
├── 30_Manual/        mando manual por equipo
├── 40_Alarms/
├── 50_Recipes/
└── 90_System/        login, ajustes, diagnóstico
```

---

## Fuera de TIA Portal: la carpeta del proyecto

```
40-projects/<cliente>-<maquina>/
├── README.md          ← qué máquina es, qué hace, estado, quién la mantiene
├── tia/               ← .ap20 + carpeta del proyecto          [NO versionado]
├── src/               ← export textual .s7dcl/.s7res/.scl     [★ versionado]
│   ├── Program blocks/
│   ├── PLC data types/
│   └── PLC tags/
├── specs/             ← JSON/YAML de ScaffoldProject y PlcBuildAndImport
├── docs/
│   ├── lista-es.xlsx           lista de entradas/salidas
│   ├── descripcion-funcional.md
│   ├── matriz-alarmas.md
│   └── esquemas/               PDF eléctricos, P&ID
└── ops/               ← logs de compilación, informes         [NO versionado]
```

🔒 **`tia/` no va a git, `src/` sí.** Un `.ap20` es binario: git guarda una copia entera en cada
commit y no puedes ver qué cambió. El export textual `.s7dcl` sí diffea. La regla:

> Después de cada cambio significativo: exportar a `src/` y commitear con un mensaje que diga
> **qué cambió funcionalmente**, no "update".

Esto es lo que convierte *"el agente tocó el proyecto"* en *"el agente tocó estas tres líneas del
enclavamiento del motor 1, y aquí están"*.

---

## El README de cada proyecto

Plantilla mínima. Sin esto, dentro de seis meses no te acuerdas.

    # <Cliente> — <Máquina>

    **Estado:** en desarrollo | FAT | en planta | mantenimiento
    **TIA:** V20   **CPU:** S7-1516-3 PN/DP   **HMI:** TP1200 Unified

    ## Qué hace
    Dos párrafos en lenguaje llano. Qué entra, qué sale, qué transforma.

    ## Arquitectura
    - PLC_1 — control principal
    - HMI_1 — panel de operador en el armario A1
    - Red — PROFINET 192.168.0.0/24

    ## Estado del trabajo
    - [x] Estructura y tags
    - [ ] Secuencia de llenado
    - [ ] Pantallas HMI

    ## Decisiones y cosas raras
    Lo que sorprendería a quien llegue nuevo. Por qué ese timeout es de 8 s y no de 5.

    ## Pendiente
    Lo que sabes que falta y aún no has hecho.
