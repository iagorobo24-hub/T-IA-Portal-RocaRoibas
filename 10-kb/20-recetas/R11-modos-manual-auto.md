# R11 — Modos manual / automático

**Objetivo.** Que la máquina esté **siempre en exactamente un modo**, y que se sepa cuál y por qué.

> ✅ **Verificado el 2026-09-14:** [`FB_ModeManager.scl`](../../60-library/blocks/FB_ModeManager.scl)
> compilado en TIA V20 con **0 errores y 0 advertencias**.

> ⚠️ **Límite funcional:** esta receta implementa permisos e interlocks de proceso estándar.
> `EmergencyOk`, `statEmergency` y `ModeStopped` son nombres y estados de la lógica ordinaria; no
> constituyen una parada de emergencia ni una función F/Safety certificada, no sustituyen un
> relé/PLC de seguridad y no acreditan SIL/PL. La parada de emergencia debe diseñarse y validarse
> por separado bajo el proceso de seguridad de la máquina. El agente no modifica F-blocks ni tags
> Safety.

---

## El problema que resuelve

El antipatrón es repartir la decisión: cada bloque mira por su cuenta si hay un selector en
manual, un bit de auto o un permiso de proceso. Acabas con la cinta en automático y el motor en
manual, un estado que nadie sabe reproducir.

🔒 **Un solo bloque decide el modo. El resto del programa solo lee sus salidas.**

---

## Las precedencias, que son la mitad del bloque

```
1. Permiso de proceso retirado (EmergencyOk = FALSE) → ModeStopped; no es la parada certificada
2. Orden de paro                          → Parado
3. Orden de manual                        → Manual
4. Orden de auto, si hay permisos         → Automático
```

Y se implementan como un único `IF/ELSIF`, no como cuatro `IF` sueltos:

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

🔒 **El orden de las ramas ES la precedencia**, y al ser excluyentes **es imposible acabar en dos
modos a la vez** dentro de este gestor. Esto solo describe estados de proceso y no valida ninguna
función de seguridad certificada.

---

## Tres detalles que parecen menores y no lo son

### 🔴 Rearmar mientras falta el permiso estándar no debe hacer nada

```pascal
IF NOT #EmergencyOk THEN
   #statEmergency := TRUE;
ELSIF #CmdReset THEN
   #statEmergency := FALSE;
END_IF;
```

El `ELSIF` es el detalle: el rearme **solo llega** si `EmergencyOk` ya es TRUE. Escrito como dos
`IF` sueltos, activar el rearme mientras falta el permiso estándar borraría la memoria y el
proceso podría quedar listo para arrancar. Esta lógica no sustituye el circuito de parada de
emergencia de la máquina.

Es el error clásico de los gestores de modo caseros, y el que peores consecuencias tiene.

### 🔴 Solo se ENTRA en automático desde reposo

```pascal
ELSIF #CmdAuto AND #AutoConditions AND NOT #SequenceRunning THEN
```

Entrar en automático con una secuencia a medias dejaría la máquina en un paso que nadie eligió,
con actuadores en posiciones que el paso da por supuestas. `NOT #SequenceRunning` lo impide.

### 🟡 Sin orden, el modo se mantiene

No hay `ELSE`. Es **intencionado**: soltar el pulsador no cambia el modo. Si tus mandos son
selectores mantenidos en vez de pulsadores, esto hay que cambiarlo — y es la primera línea a
tocar al adaptar el bloque.

---

## Cómo se conecta con lo demás

```
FB_ModeManager
├── ModeAuto    → Enable  de FB_SequenceTemplate  (R10)
├── ModeManual  → habilita los mandos del HMI
├── ModeStopped → fuerza CmdStop en los dispositivos
└── Mode (Int)  → al HMI: 0 Parado, 1 Manual, 2 Auto
```

**En manual**, las órdenes vienen del HMI directamente a `CmdStart`/`CmdStop` de cada
dispositivo. **En automático**, vienen de la secuencia. El enclavamiento (`Interlock`) **manda en
los dos** — el modo manual no salta los enclavamientos, solo cambia quién da la orden.

🔴 **Eso último es una regla de diseño de proceso.** "Manual" no puede significar "sin
enclavamientos": si en manual se puede mover un cilindro con la puerta abierta, el modo manual
puede crear un riesgo. Este interlock estándar no es una función certificada ni reemplaza el
análisis de riesgos o el circuito de seguridad. Si necesitas un modo que salte enclavamientos para
mantenimiento, eso es un **tercer modo con llave**, sujeto a diseño y validación propios.

---

## Verificación en PLCSIM

| Caso | Qué debe pasar |
|---|---|
| Retirar `EmergencyOk` estándar en automático (simulado) | `ModeStopped`, secuencia abortada; no prueba una parada de emergencia certificada |
| Rearmar mientras `EmergencyOk` sigue FALSE | **No pasa nada.** `EmergencyLatched` sigue TRUE |
| Restaurar `EmergencyOk` y rearmar | Se desenclava el estado de proceso, pero sigue en Parado hasta pedir modo |
| Pedir auto con secuencia en marcha | Se ignora |
| Pasar a manual en mitad de un ciclo | Cambia a manual y la secuencia aborta |
| Pedir auto sin `AutoConditions` | Se ignora |
| Dos órdenes a la vez (manual + auto) | **Gana manual**, por precedencia |

🔴 **El segundo caso es el que hay que probar sí o sí** para esta lógica ordinaria de proceso.
