# Nomenclatura

> **Estado: cerrado a falta de usarlo.** No tenías estándar previo, así que esto es una propuesta
> completa sobre las convenciones más extendidas del sector (Siemens SCE, PLCopen, ISA-5.1),
> **contrastada con los 7 proyectos reales de [`50-examples/`](../50-examples/)**.
>
> Las 5 dudas que quedaban abiertas están resueltas al final, con el porqué de cada una.
> Si alguna no te convence, se cambia: es un fichero.
>
> Marcado con 🔸 lo que es decisión de gusto y cambiarías sin coste. Marcado con 🔒 lo que
> recomiendo no tocar porque hay una razón técnica detrás.

## Principio

🔒 **Identificadores en inglés. Comentarios y documentación en español.**

Por qué: un proyecto cambia de manos, de integrador y a veces de país. `Motor_Start` lo entiende
cualquiera; `Motor_Marcha` obliga al siguiente a traducir. Pero el comentario que explica *por
qué* ese enclavamiento está ahí lo escribes tú, para ti y para tu compañero, y eso va en español.

🔒 **Sin acentos, sin ñ, sin espacios en ningún identificador.** Openness, los exports XML y los
nombres de fichero sufren con ellos. En los comentarios, todos los que quieras.

---

## Bloques

| Objeto | Patrón | Ejemplos |
|---|---|---|
| **OB** | `OB_<Función>` | `OB_Main`, `OB_Startup`, `OB_Cyclic_100ms`, `OB_ProgramError`, `OB_RackFault` |
| **FB reutilizable** (dispositivo) | `FB_<Dispositivo>` | `FB_Motor`, `FB_ValveOnOff`, `FB_ValveAnalog`, `FB_AnalogInput`, `FB_Conveyor` |
| **FB de proceso** (específico de máquina) | `FB_<Area>_<Función>` | `FB_L01_Sequence`, `FB_Z30_Filling` |
| **FC** (sin estado) | `FC_<Verbo><Objeto>` | `FC_ScaleAnalog`, `FC_CheckLimits`, `FC_ConvertUnits` |
| **DB global** | `DB_<Contenido>` | `DB_Params`, `DB_HMI`, `DB_Recipe`, `DB_Alarms`, `DB_Stats` |
| **DB de instancia** | `iDB_<TagEquipo>` | `iDB_M01`, `iDB_V12`, `iDB_PT01` |
| **UDT** | `UDT_<Concepto>` | `UDT_Motor`, `UDT_Valve`, `UDT_Alarm`, `UDT_Recipe` |

🔒 **Los DBs de instancia van por equipo, no por FB** (`iDB_M01`, no `FB_Motor_DB_7`). TIA te
propone lo segundo; renómbralo. El porqué, con la evidencia, en [N2](#n2--dbs-de-instancia--idb_equipo-y-voy-contra-lo-que-hacen-los-ejemplos).

### Numeración de bloques

🔸 **No numeres a mano.** Deja que TIA asigne el número y trabaja siempre por nombre simbólico.

Excepción: OBs con número fijo por sistema (OB1, OB100, OB82...). Esos conservan su número y
solo cambia el nombre simbólico.

> **Razón técnica que importa:** al copiar o mover un bloque entre PLCs, Openness no tiene
> operación nativa — se emula con export+import, y **el número de bloque viaja con él**.
> Si numeras a mano acabarás con colisiones al importar. Con numeración automática, no.

---

## Tags de PLC

### Tag de equipo (la parte `<Equipo>`)

🔒 Sigue **ISA-5.1**, que es lo que ya hay en tus P&ID y esquemas eléctricos:

| Prefijo | Equipo | Ejemplo |
|---|---|---|
| `M` | Motor | `M01`, `M12` |
| `V` | Válvula | `V01`, `V22` |
| `S` | Sensor / detector | `S01`, `S15` |
| `PT` / `TT` / `FT` / `LT` | Transmisor de presión / temperatura / caudal / nivel | `PT01` |
| `VFD` | Variador | `VFD01` |
| `HS` | Pulsador (hand switch) | `HS01` |
| `ES` | Seta de emergencia | `ES01` |

Si el P&ID del cliente usa otro código, **manda el P&ID**. El estándar cede ante la realidad de
la planta.

### Tags de E/S y memoria

| Tipo | Patrón | Ejemplos |
|---|---|---|
| Entrada digital | `DI_<Equipo>_<Señal>` | `DI_M01_Running`, `DI_S12_Present`, `DI_ES01_Ok` |
| Salida digital | `DO_<Equipo>_<Señal>` | `DO_M01_Run`, `DO_V12_Open`, `DO_HL01_Lamp` |
| Entrada analógica | `AI_<Equipo>_<Magnitud>` | `AI_PT01_Pressure`, `AI_TT03_Temp` |
| Salida analógica | `AO_<Equipo>_<Magnitud>` | `AO_VFD01_SpeedRef` |
| Marca interna | `M_<Ámbito>_<Señal>` | `M_Sys_AutoMode`, `M_L01_SeqRunning` |
| Constante de usuario | `C_<CONCEPTO>` en MAYÚSCULAS | `C_START_TIMEOUT`, `C_MAX_SPEED` |

🔒 **Señales de seguridad en negativo llevan `_Ok` o `_NC`, no `_Fault`.**
`DI_ES01_Ok` = TRUE cuando la seta **no** está pulsada. Es la convención de contacto normalmente
cerrado, y hace que la lógica se lea igual que el esquema eléctrico: si se rompe el cable, se
para. Nombrarlo `DI_ES01_Pressed` invita a escribir la lógica al revés.

🔒 **Sin notación húngara** (`xBool`, `iInt`, `rReal`). Prefijamos por **rol** (`DI_`, `AO_`), que
no cambia nunca, no por **tipo**, que el editor ya muestra y que envejece mal el día que pasas un
`Int` a `DInt`. Ninguno de los 7 proyectos de ejemplo la usa. Detalle en
[N1](#n1--notación-húngara--no).

---

## Miembros de UDT y de DB

`PascalCase`, sin prefijo de tipo:

```pascal
TYPE "UDT_Motor"
VERSION : 0.1
   STRUCT
      // Mandos
      CmdStart    : Bool;   // Orden de marcha
      CmdStop     : Bool;   // Orden de paro
      // Estado
      Running     : Bool;   // Confirmación de marcha
      Fault       : Bool;   // Fallo activo
      FaultCode   : Int;    // Código de fallo, ver DB_Alarms
      // Parámetros
      StartTimeout : Time;  // Tiempo máx. hasta confirmación
   END_STRUCT;
END_TYPE
```

🔒 **Agrupa por rol** (Mandos / Estado / Parámetros / Diagnóstico) y coméntalo. Un UDT sin
agrupar de 40 miembros es ilegible a los seis meses.

---

## Pantallas y objetos HMI

| Objeto | Patrón | Ejemplo |
|---|---|---|
| Pantalla | `Scr_<Función>` | `Scr_Overview`, `Scr_L01_Manual`, `Scr_Alarms`, `Scr_Recipe` |
| Faceplate | `FP_<Dispositivo>` | `FP_Motor`, `FP_Valve` |
| Popup | `Pop_<Función>` | `Pop_MotorDetail`, `Pop_Login` |
| Tag HMI | igual que la tag de PLC a la que apunta | `DI_M01_Running` |

🔒 **La tag de HMI se llama igual que la de PLC.** Renombrarla en el HMI es la forma más rápida
de perder la trazabilidad entre los dos lados.

---

## Ficheros y carpetas del workspace

| Cosa | Patrón | Ejemplo |
|---|---|---|
| Carpeta de proyecto | `<cliente>-<maquina>` en minúsculas y guiones | `acme-linea01`, `demo-cinta01` |
| Proyecto TIA | igual que la carpeta, en PascalCase | `AcmeLinea01.ap20` |
| Receta de la KB | `R<nn>-<tema>.md` | `R03-exportar-a-git.md` |
| ADR | `ADR-<nnn>-<tema>.md` | `ADR-003-lenguajes.md` |

---

## Las 5 dudas — cerradas

Resueltas el 2026-09-14 con la evidencia de los 7 proyectos de
[`50-examples/`](../50-examples/), ya inventariados. No es opinión en el aire: cada decisión
dice qué hacen los proyectos reales y por qué se sigue o no.

### N1 — ¿Notación húngara? → **No**

**Lo que hacen los ejemplos:** ninguno de los siete la usa. Cero.

Y lo que sí hace el mejor de ellos es más interesante: el sorting plant prefija por **origen
físico**, no por tipo de dato.

```
csLightSensorCube_Detected      cs = sensor de la cinta
osWorkpieceCube_SetActive       os = salida de simulación
pcCylinderHeadExtend_SetActive  pc = cilindro de empuje
```

🔒 **Esa es la distinción que importa: prefija por ROL, no por TIPO.** `DI_`, `DO_`, `AI_`, `AO_`
dicen de dónde viene la señal y eso no cambia nunca. `x`, `i`, `r` dicen el tipo de dato, que el
editor ya te muestra y que cambia el día que pasas un `Int` a `DInt` — dejándote el nombre
mintiendo.

### N2 — DBs de instancia → **`iDB_<Equipo>`**, y voy contra lo que hacen los ejemplos

**Lo que hacen los ejemplos: 6 de 6 usan `<NombreFB>_DB`.**

```
SortingPlantControl_DB   lightControl_DB   motorControl_DB
Intersection_DB          PressControl_DB   Temperature Control_DB
```

Es además lo que TIA propone solo al crear la instancia. Así que la observación es unánime — y
aun así **recomiendo lo contrario**, por un motivo concreto:

🔴 **Todos esos proyectos tienen UNA instancia por FB.** En cuanto tengas veinte motores con el
mismo `FB_Motor`, TIA te propone `FB_Motor_DB`, `FB_Motor_DB_1`, `FB_Motor_DB_2`… y
`FB_Motor_DB_7` **no te dice qué motor es**. Tienes que abrir el Main y buscar la llamada.

```
✅ iDB_M01   iDB_M12   iDB_V22   iDB_PT01
❌ FB_Motor_DB_7
```

`iDB_` agrupa todas las instancias juntas al ordenar, y el sufijo identifica el equipo físico —
el mismo código que está en el P&ID y en el esquema eléctrico. **El coste es renombrar lo que TIA
propone; se tarda tres segundos y se paga solo la primera vez que buscas algo.**

> Excepción razonable: un FB del que **solo va a haber una instancia** en todo el proyecto
> (un gestor de modos, un coordinador). Ahí `<FB>_DB` está bien y no aporta nada forzar `iDB_`.

### N3 — Prefijo de área → **solo en bloques de proceso; para organizar, usa grupos**

**Lo que hacen los ejemplos:** los proyectos IoT no prefijan nombres, usan **carpetas**:

```
Program blocks/01_S7/...        PLC data types/02_Types/S7-1500/...
Program blocks/LMQTTClient/...
```

Y el sorting plant tiene `CylinderControl` y `ConveyorControl` sin prefijo ninguno — y se leen
perfectamente, porque son **reutilizables**: no pertenecen a un área.

🔒 **La regla que sale de ahí:**

| Tipo de bloque | Prefijo de área |
|---|---|
| Reutilizable (`FB_Motor`, `FB_Valve`, `FC_ScaleAnalog`) | **No.** Pertenece a la librería, no a un área |
| De proceso (`FB_L01_Sequence`, `FB_Z30_Filling`) | **Sí.** Solo existe para esa línea |

**La organización la hacen los grupos** (`30_Sequences/`, `40_Devices/`), no los nombres. Meter el
área en el nombre *además* de en la carpeta es repetirse, y envejece mal el día que mueves un
bloque.

### N4 — Comentarios → **español**, y TIA te deja añadir otro idioma sin reescribir nada

**Lo que hacen los ejemplos:** todos en inglés, y los del sorting plant son de los buenos —
documentan el significado de cada estado:

```
csLightSensorCube_Detected: "0: cube workpiece not detected;
                             1: cube workpiece detected by the light sensor"
```

Copia **ese nivel de detalle**, no el idioma. Un comentario que dice qué significa el 0 y qué
significa el 1 vale más que diez que repiten el nombre de la variable.

🔒 **Y un dato técnico que resuelve la duda de raíz:** los comentarios de TIA son
**multi-idioma**. Verificado en el `.s7res` exportado:

```xml
<Comment Id="MLC_U4">
  <MultiLanguageText Lang="en-US">Trigger fault when the cylinder is set
  to extend and retract at the same time</MultiLanguageText>
</Comment>
```

Cada comentario se guarda **por idioma**. Así que escribes en español ahora, y si un día entregas
a un cliente extranjero, añades `en-US` como idioma del proyecto y traduces **sin tocar el
código**. No es una decisión irreversible: es una capa.

### N5 — Author / Family / Version → **sí, obligatorio en librería; opcional en proceso**

**Lo que hacen los ejemplos:** ninguno los rellena. El `.s7dcl` de `CylinderControl` sale así:

```
FUNCTION_BLOCK "CylinderControl"
    VAR_INPUT ...
```

Sin `AUTHOR`, sin `FAMILY`, sin `VERSION`. Es un hueco real, y se nota justo cuando más falta
hace: al reutilizar un bloque no sabes de dónde salió ni qué versión es.

| Campo | Valor | ¿Dónde? |
|---|---|---|
| `Author` | Tu nombre o el de la empresa | Todos |
| `Family` | El área funcional: `Drives`, `Valves`, `Sequence`, `Comms`, `Diag` | **Obligatorio** en `60-library/` |
| `Version` | Semántica, empezando en `0.1`. Sube la menor al cambiar comportamiento | **Obligatorio** en `60-library/` |

🔒 **Sin `Version` no hay librería, hay copias.** Es lo que te permite saber si el `FB_Motor` de
la máquina de 2024 es el mismo que el de la de hoy. En bloques de proceso, que viven en un solo
proyecto, es deseable pero no crítico.

---

## Lo que sigue abierto

Nada de nomenclatura. Lo que falta por validar es **el uso**: estas reglas están razonadas y
contrastadas con siete proyectos, pero **no se han aplicado todavía a un proyecto propio**.
Se ajustarán con el primero, que es cuando se ve lo que chirría.
