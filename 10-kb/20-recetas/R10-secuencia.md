# R10 — Secuencia / máquina de estados

**Objetivo.** Escribir una secuencia de proceso que se entienda, se pueda abortar en cualquier
punto y diga **dónde** se ha quedado colgada cuando se cuelgue.

> ✅ **Verificado el 2026-09-14:** [`FB_SequenceTemplate.scl`](../../60-library/blocks/FB_SequenceTemplate.scl)
> compilado en TIA V20 con **0 errores y 0 advertencias**.

---

## Por qué SCL y no GRAPH

| | |
|---|---|
| **GRAPH** | Necesita **licencia aparte**, y no se exporta como texto legible: en git es un binario |
| **SCL** | Un `CASE` hace lo mismo, diffea, y se lee sin abrir TIA |

Si ya tienes licencia de GRAPH y tu equipo lo usa, úsalo — es mejor para secuencias de 40 pasos
con ramas paralelas. Para lo demás, el `CASE` gana por mantenibilidad.

Ver también: [`10-kb/30-lenguajes/graph.md`](../30-lenguajes/graph.md).

---

## El patrón, en cuatro regiones

🔒 **El orden importa y no es negociable.**

```
REGION 1 - Aborto, rearme y pérdida de permiso   ← ANTES del CASE
REGION 2 - Vigilancia de tiempo de paso
REGION 3 - El CASE
REGION 4 - Salidas derivadas del paso            ← DESPUÉS del CASE
```

### 1. Lo que aborta va primero

```pascal
IF #CmdAbort OR NOT #Enable THEN
   #statStep := #S_IDLE;
ELSIF #CmdReset AND #statStep = #S_FAULT THEN
   #statStep := #S_IDLE;
END_IF;
```

Antes del `CASE`, no dentro. Si cada paso tuviera que acordarse de comprobar el aborto, algún
paso se olvidaría — y sería justo el que te deja la máquina en marcha.

### 2. Numeración por decenas

```pascal
S_IDLE     : Int := 0;
S_FORWARD  : Int := 10;
S_WORK     : Int := 20;
S_BACKWARD : Int := 30;
S_DONE     : Int := 40;
S_FAULT    : Int := 900;
```

El día que haya que meter un paso entre avanzar y trabajar, es `15`. Sin renumerar nada, sin
tocar el HMI, sin invalidar los históricos.

💡 **`S_FAULT = 900`, lejos y reconocible.** Un `Step = 900` en el HMI se identifica de un vistazo
como "esto no es un paso normal".

### 3. 🔒 Los pasos NO escriben salidas

Dentro del `CASE` solo hay condiciones de transición. Las salidas se derivan del paso, después:

```pascal
#DoForward  := #statStep = #S_FORWARD;
#DoBackward := #statStep = #S_BACKWARD;
#DoWork     := #statStep = #S_WORK;
```

**Así es imposible que dos pasos peleen por la misma salida.** Es el fallo más común de las
secuencias escritas a mano y el más difícil de depurar: la salida parpadea y no sabes quién la
escribe. Con este patrón, la pregunta "¿quién enciende esto?" tiene una sola respuesta y está a
la vista.

### 4. Timeout por paso, con rearme automático al cambiar

```pascal
#tempStepChanged := #statStep <> #statPrevStep;
#statPrevStep    := #statStep;

#tonStep(IN := NOT #tempStepChanged
               AND #statStep <> #S_IDLE
               AND #statStep <> #S_DONE
               AND #statStep <> #S_FAULT,
         PT := #StepTimeout);

IF #tonStep.Q THEN
   #statFaultStep := #statStep;    // ← guarda DÓNDE se colgó
   #statStep      := #S_FAULT;
END_IF;
```

🔴 **`FaultStep` es la salida más valiosa del bloque.** Sin ella, "la secuencia falló" obliga a
reproducir el fallo mirando. Con ella, `FaultStep = 20` te dice que el trabajo no terminó y ya
sabes dónde mirar.

No se vigila en reposo, completado ni fallo: no son pasos con transición pendiente.

### 5. La rama `ELSE` no es paranoia

```pascal
ELSE
   #statFaultStep := #statStep;
   #statStep      := #S_FAULT;
END_CASE;
```

Un paso desconocido **no debería pasar nunca**. Si pasa —un DB de instancia corrupto, alguien
forzando `Step` desde el HMI— la máquina va a fallo en vez de quedarse colgada en un estado que
nadie programó. Cuesta tres líneas.

---

## Cómo se usa

1. Copia `FB_SequenceTemplate.scl` y renómbralo: `FB_L01_Sequence`
   ([N3 de `naming.md`](../../20-standards/naming.md): los de proceso **sí** llevan prefijo de área)
2. Cambia las constantes `S_*` por tus pasos reales, en decenas
3. Una condición de transición por paso, como entrada
4. Una orden por paso, como salida
5. Deja el resto de las regiones **como están**

🔒 **Va en `30_Sequences/`, no en `90_Library/`.** Una secuencia es de esa máquina y de ninguna
otra; la plantilla es lo reutilizable, la secuencia rellena no.

---

## Verificación en PLCSIM

| Caso | Qué debe pasar |
|---|---|
| Abortar en cada paso, uno a uno | Va a `S_IDLE` desde cualquiera. **Prueba los cinco** |
| Quitar `Enable` a media secuencia | Igual que abortar |
| No cumplir una condición de transición | A los 30 s: `S_FAULT` y `FaultStep` = el paso correcto |
| `CmdReset` fuera del paso de fallo | **No hace nada.** No es un botón de saltar pasos |
| `CmdStart` con la secuencia ya en marcha | Se ignora |
| Corte y vuelta de tensión a medio ciclo | Arranca en reposo, no retoma el paso |

🔴 **El primero hay que hacerlo entero, paso por paso.** Abortar desde el paso 10 y desde el 30
no son el mismo camino, y el que no pruebas es el que falla en planta.
