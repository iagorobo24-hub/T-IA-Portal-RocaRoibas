# Patrones SCL transversales

> ✅ Cada patrón de esta página está extraído de código que **compiló con 0 errores y 0
> advertencias en TIA V20** (`60-library/blocks/`, verificado 2026-09-14). No son preferencias de
> estilo: son las decisiones de diseño que se repiten a propósito porque hacen que un bloque de
> librería sea predecible. Las recetas [R08](../20-recetas/R08-bloque-motor.md)-[R12](../20-recetas/R12-alarmas.md)
> muestran **cómo aplicar cada uno a un caso concreto**; esta página los centraliza para no
> repetir la justificación en cada receta.

## 1. El enclavamiento entra por parámetro, nunca se calcula dentro

Ningún bloque de dispositivo decide por su cuenta si puede arrancar. `FB_Motor` y
`FB_ValveOnOff` reciben `Interlock` como `VAR_INPUT` y se limitan a obedecerlo.

```pascal
// FB_ValveOnOff — Interlock llega de fuera, el bloque solo lo respeta
IF #CmdClose OR #statFault OR NOT #Interlock THEN
   #statOpenLatch := FALSE;
ELSIF #CmdOpen THEN
   #statOpenLatch := TRUE;
END_IF;
```

**Por qué:** la lógica del dispositivo va en SCL, pero la cadena de condiciones que explica *por
qué* algo no arranca se dibuja en LAD, en el network donde se llama al bloque — es lo que un
mantenedor delante de la máquina abre y mira, no el interior del FB (ver
[`lad/README.md`](lad/README.md) y [ADR-003](../../00-meta/decisiones/ADR-003-lenguajes.md)).

## 2. Paro y fallo mandan sobre la marcha, siempre

En todos los bloques de dispositivo, la rama que **desactiva** va primero en el `IF`.

```pascal
// FB_Motor
IF #CmdStop OR #Fault OR NOT #Interlock THEN
   #statRunLatch := FALSE;
ELSIF #CmdStart THEN
   #statRunLatch := TRUE;
END_IF;
```

**Por qué:** así se falla por el lado seguro sin depender del orden de evaluación del compilador.

## 3. Las salidas se escriben en un solo sitio, al final del bloque

🔒 No es estilo, **lo exige el compilador**: leer una `VAR_OUTPUT` dentro de la lógica produce
`The parameter '#X' might not be initialized.` (verificado compilando `FB_Motor`, ver
[R08 §6](../20-recetas/R08-bloque-motor.md#6-si-falla)). El estado vive en variables `stat`; las
salidas solo lo publican al final:

```pascal
// FB_ValveOnOff, REGION 4 - Salidas (última región del bloque)
#Solenoid  := #statOpenLatch AND NOT #statFault;
#Fault     := #statFault;
#FaultCode := #statFaultCode;
```

Con esto es imposible que dos ramas peleen por la misma salida: la pregunta "¿quién enciende
esto?" tiene una sola respuesta y está a la vista en una única región.

## 4. `Fault` + `FaultCode` enclavado, con rangos por familia

Un `Fault` booleano sin código obliga a adivinar. `FaultCode` dice **cuál** fue, y el rango dice
de qué familia es:

| Rango | Familia | Ejemplo real |
|---|---|---|
| `1xx` | Motores | `FB_Motor`: `101` sin confirmación, `102` se perdió en marcha, `103` sigue confirmando tras el paro |
| `2xx` | Válvulas | `FB_ValveOnOff`: `201` timeout abriendo, `202` timeout cerrando, `203` los dos finales de carrera a la vez (imposible físicamente) |
| `9xx` | Pasos de fallo de secuencia | `FB_SequenceTemplate`: `S_FAULT := 900` |

`Fault` no se borra solo: hace falta `CmdReset` explícito, y si la causa sigue presente, **vuelve
a fallar** — es el caso de verificación que más se olvida (ver
[R08 §5](../20-recetas/R08-bloque-motor.md#5-verificación)).

## 5. `*_Used` para el hardware que no está

`FeedbackUsed` (`FB_Motor`), `FbUsed` (`FB_ValveOnOff`). El mismo bloque sirve para un equipo con
retorno de contactor/final de carrera y para uno sin él, sin tocar código — en `FALSE`, el
bloque deja de vigilar lo que no existe. Se parametriza por instancia en los valores de arranque
del DB, no por variante del bloque.

## 6. Secuencia: cuatro regiones en orden fijo, y los pasos no escriben salidas

Patrón completo en [R10](../20-recetas/R10-secuencia.md). El orden **no es negociable**:

```
REGION 1 - Aborto, rearme y pérdida de permiso   ← ANTES del CASE
REGION 2 - Vigilancia de tiempo de paso
REGION 3 - El CASE (numeración por decenas: 0, 10, 20... S_FAULT := 900)
REGION 4 - Salidas derivadas del paso            ← DESPUÉS del CASE
```

Dentro del `CASE` solo hay condiciones de transición; las salidas se derivan del paso, fuera:

```pascal
#DoForward  := #statStep = #S_FORWARD;
#DoBackward := #statStep = #S_BACKWARD;
```

Así es imposible que dos pasos escriban la misma salida — el fallo más común y más difícil de
depurar en secuencias escritas a mano.

## 7. Precedencias como un único `IF/ELSIF`, no cuatro `IF` sueltos

`FB_ModeManager` resuelve Parado/Manual/Automático con una sola cadena `IF/ELSIF` donde el orden
de las ramas **es** la precedencia — al ser excluyentes, es imposible acabar en dos modos a la
vez:

```pascal
IF #statEmergency OR NOT #EmergencyOk THEN
   #statMode := #MODE_STOPPED;
ELSIF #CmdStop THEN
   #statMode := #MODE_STOPPED;
ELSIF #CmdManual THEN
   #statMode := #MODE_MANUAL;
ELSIF #CmdAuto AND #AutoConditions AND NOT #SequenceRunning THEN
   #statMode := #MODE_AUTO;
END_IF;
```

Cuatro `IF` independientes (sin `ELSIF`) permitirían que más de una condición se cumpliera a la
vez y el resultado dependería del orden de ejecución, no de una precedencia declarada.

## 8. Matriz activa/reconocida para alarmas, no un booleano suelto

`FB_AlarmLatch` separa dos dimensiones independientes — si la condición está activa, y si fue
reconocida — porque confundirlas es el error clásico de las listas de alarmas caseras:

|  | sin reconocer | reconocida |
|---|---|---|
| **condición activa** | `ACTIVA NO ACK` | `ACTIVA ACK` |
| **condición ida** | `IDA NO ACK` ← se olvida | (se borra) |

```pascal
#Unacked     := #statLatched AND NOT #statAcked;
#GoneUnacked := #statLatched AND NOT #statAcked AND NOT #tempActive;
```

El cuadrante `IDA NO ACK` es el que se pierde con un booleano simple: la causa ya no está, pero
nadie se enteró de que pasó. Ese caso **no debe desaparecer solo** — solo se borra cuando se dan
las dos cosas a la vez (causa ida **y** reconocida).

---

Ver también: [`scl.md`](scl.md) para el estilo de escritura de estos patrones, y
[`lad/README.md`](lad/README.md) para dónde vive la parte que no está aquí (el enclavamiento en
el punto de llamada).
