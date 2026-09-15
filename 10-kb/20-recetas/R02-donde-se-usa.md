# R02 — Dónde se usa una tag, qué la escribe, qué la lee

**Objetivo.** Responder a la pregunta que más se hace en un proyecto ajeno: *"¿de dónde sale
esto?"* — y la más peligrosa de responder mal: *"¿qué pasa si lo toco?"*

**Precondiciones.** `Doctor` en verde, proyecto abierto, `softwarePath` sacado de
`GetProjectTree`.

**Servidor.** `tia-inspect` — es lo que mejor hace y `tia-create` no cubre.

> ✅ **Ejecutada el 2026-09-14** sobre la tag `pcCylinderHeadExtend_SetActive` (`%Q0.3`) de
> `npatel-sorting-plant`. El resultado real está al final, y confirma por qué las tres
> herramientas no son intercambiables.

---

## Las tres herramientas, y cuándo usar cada una

| Herramienta | Qué hace | Cuándo |
|---|---|---|
| `GetCrossReferences` | Referencias cruzadas **reales de TIA** | 🥇 Siempre que exista para ese objeto |
| `WhereUsed` | Dónde se usa un objeto con nombre | Bloques, tipos, tags |
| `FindInCode` | Búsqueda de **texto** en el código | Cuando lo anterior no llega: comentarios, literales, nombres parciales |

🔒 **Empieza siempre por `GetCrossReferences`.** Es lo que TIA sabe de verdad, no una búsqueda de
texto. `FindInCode` es el último recurso: encuentra coincidencias en comentarios y en cadenas,
que no son usos.

---

## Secuencia

### 1. Referencias cruzadas del objeto

```
GetCrossReferences(softwarePath: "PLC_1",
                   objectPath:   "00_Hardware/Tabla_E_S",
                   maxDepth:     1)
```

🔒 **`maxDepth` por defecto es 1. Déjalo en 1.** Acepta 1-3, y el crecimiento es exponencial: a
profundidad 3 en un PLC mediano la respuesta es inmanejable. Sube solo si a profundidad 1 te
falta información concreta, y sube a 2, no a 3.

⚠️ **No hay referencias cruzadas** para tablas de observación, tablas de forzado ni fuentes
externas: devuelve `NotSupported`. No es un fallo, es un [límite de la
API](../10-openness/limites.md).

### 2. Distinguir quién escribe de quién lee

Esta es la parte que de verdad importa, y donde las referencias cruzadas solas se quedan cortas:
te dicen *dónde aparece*, no *si escribe*.

Para separarlo hay que mirar el código:

```
GetBlockSource(softwarePath: "PLC_1", blockPath: "30_Sequences/FB_L01_Sequence")
```

Y en el fuente:

| En SCL | Lectura o escritura |
|---|---|
| `#Tag := ...` a la izquierda de `:=` | **escribe** |
| `IF #Tag THEN`, `... := #Tag` | lee |
| pasada a un `VAR_IN_OUT` de un FB | **puede escribir** ⚠️ |
| pasada a un `VAR_INPUT` | lee |
| pasada a un `VAR_OUTPUT` | **escribe** |

| En LAD | Lectura o escritura |
|---|---|
| bobina, `SET`, `RESET`, `MOVE` al destino | **escribe** |
| contacto, comparador | lee |

🔴 **El caso que se escapa siempre: `VAR_IN_OUT`.** Una tag pasada a un `IN_OUT` puede ser
modificada dentro del bloque sin que se vea en el punto de llamada. Si `GetCrossReferences`
señala un bloque y no ves una asignación obvia, **mira la interfaz de ese bloque** antes de
concluir que solo lee:

```
GetBlockInterface(softwarePath: "PLC_1", blockPath: "...")
```

### 3. Cuando las referencias cruzadas no bastan

```
FindInCode(softwarePath: "PLC_1", pattern: "Motor_Marcha")
```

Útil para:
- Encontrar el nombre en **comentarios** — a menudo ahí está la explicación de por qué existe
- Nombres parciales, cuando no sabes cómo se llama exactamente
- Direccionamiento **absoluto** (`%M10.3`, `%DB5.DBX0.0`) que no aparece como símbolo

⚠️ **Devuelve coincidencias de texto, no usos.** Un acierto en un comentario no es una escritura.
Filtra a mano.

---

## Verificación

Antes de decir "esta tag se usa en X sitios", comprueba:

- [ ] `GetCrossReferences` ejecutado, no solo `FindInCode`
- [ ] Cada punto clasificado como **lectura** o **escritura**, no solo listado
- [ ] Revisados los `VAR_IN_OUT` de los bloques implicados
- [ ] Mirado si hay **direccionamiento absoluto** a la misma dirección con otro nombre

🔴 **Ese último punto es el que muerde.** Si alguien escribe `%M10.3` directamente en un sitio y
la tag simbólica `M_Sys_AutoMode` apunta a `%M10.3`, las referencias cruzadas por símbolo **no lo
encuentran**. Busca también la dirección absoluta.

---

## Si falla

| Síntoma | Causa | Arreglo |
|---|---|---|
| `NotSupported` | Tablas de observación, forzado o fuentes externas | No hay cross-refs para eso. Usa `FindInCode` |
| Respuesta enorme | `maxDepth` > 1 | Bájalo a 1 |
| `NotFound` en el objeto | Ruta inventada | `GetSoftwareTree` y copia la ruta |
| No encuentra nada y sabes que se usa | El bloque está **know-how protegido** | No se puede leer su código. Reporta la limitación, no des por hecho que no se usa |
| No encuentra nada, el bloque es legible | Direccionamiento absoluto | Busca `%M...`, `%DB...`, `%I...`, `%Q...` |

---

## La respuesta que hay que dar

No listes referencias en crudo. Responde así:

```
La tag M_Sys_AutoMode (%M10.3) aparece en 7 sitios:

ESCRIBEN (2):
  10_Modes/FB_ModeManager         línea 45   ← la única fuente real
  00_System/OB_Startup            línea 12   ← inicialización a FALSE

LEEN (5):
  30_Sequences/FB_L01_Sequence    líneas 23, 67
  40_Devices/FB_Motor_Call        línea 15
  70_HMI/DB_HMI                   miembro AutoMode
  ...

⚠️ Además hay un acceso absoluto a %M10.3 en 80_Diagnostics/FC_Legacy
   línea 8, sin usar el símbolo.
```

**Lo que escribe primero, lo que lee después, y las rarezas señaladas.** Es lo que necesita quien
va a tocar algo.

---

## Caso real resuelto ✅

Tag `pcCylinderHeadExtend_SetActive` (`%Q0.3`, extender cilindro) en `npatel-sorting-plant`.

**`WhereUsed` y `GetCrossReferences` coinciden: 4 usuarios.**

```
HMI\Connections\HMI_Connection_1          Connection
HMI\Cycles\100 ms                         Cycle
HMI\HMI tags\PLC_Tags\pcCylinder...       HMI_Tag
Sorting Plant Controller\Program blocks\Main   %OB1, LAD-Organization block
```

Útil —se ve que la tag llega al HMI— pero dice **"se usa en Main"** y nada más. No dice dónde ni
cómo.

**`FindInCode` da las líneas concretas:**

```
Main:19             pcCylinderHeadRetract_SetActive => "pcCylinderHeadExtend_SetActive",
Main:20             pcCylinderHeadExtend_SetActive  => "pcCylinderHeadRetract_SetActive",
Main:64             "Cylinder Extend"               => "pcCylinderHeadExtend_SetActive",
ResetSimulation:11  pcCylinderHeadExtend_SetActive : Bool;
ResetSimulation:38  R_Coil( #pcCylinderHeadExtend_SetActive )
```

Y aquí están las dos lecciones:

### 🔴 `#` es ámbito local. Sin `#`, es tag global

Las dos líneas de `ResetSimulation` **no usan la tag**: son una **variable local del FC que se
llama igual**. `#pcCylinderHeadExtend_SetActive` y `"pcCylinderHeadExtend_SetActive"` son cosas
distintas.

Por eso las referencias cruzadas no listan `ResetSimulation`: **tienen razón**. `FindInCode`
encontró texto, no usos. Es exactamente el aviso de más arriba, con un caso real.

### 🔴 Y algo que solo aparece mirando las líneas

Fíjate en `Main:19-20`: las salidas de `ResetSimulation` van **cruzadas**.
`pcCylinderHeadRetract_SetActive` del bloque se conecta a la tag `"...Extend..."`, y al revés.

Puede ser deliberado —el bloque simula el proceso inverso— o un error de cableado de parámetros.
**No lo sabemos, y por eso hay que decirlo**, no callarlo. Ninguna de las dos herramientas de
referencias cruzadas lo habría enseñado: hacía falta `FindInCode`.

---

## Pruébalo aquí

`50-examples/npatel-sorting-plant/` (37 tags, 7 bloques) o `npatel-traffic-light/` (31 tags).
Ambos ya migrados a V20 e inventariados.

Evita `npatel-basement-light` y los `IOT2050_*` para esta receta: tienen **0 tags simbólicas** —
direccionan absoluto, así que no hay nada que rastrear por símbolo.
