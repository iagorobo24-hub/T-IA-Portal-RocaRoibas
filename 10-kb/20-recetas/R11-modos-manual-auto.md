# R11 — Modos manual / automático

**Objetivo.** Que la máquina esté **siempre en exactamente un modo**, y que se sepa cuál y por qué.

> ✅ **Verificado el 2026-09-14:** [`FB_ModeManager.scl`](../../60-library/blocks/FB_ModeManager.scl)
> compilado en TIA V20 con **0 errores y 0 advertencias**.

---

## El problema que resuelve

El antipatrón es repartir la decisión: cada bloque mira por su cuenta si hay un selector en
manual, un bit de auto, una condición de emergencia. Acabas con la cinta en automático y el motor
en manual, un estado que nadie sabe reproducir y que en planta se arregla apagando y encendiendo.

🔒 **Un solo bloque decide el modo. El resto del programa solo lee sus salidas.**

---

## Las precedencias, que son la mitad del bloque

```
1. Emergencia    (EmergencyOk = FALSE)   → Parado, y no se sale sin rearme
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
modos a la vez**. Eso no se consigue con cuatro `IF` independientes por muy bien que los escribas.

---

## Tres detalles que parecen menores y no lo son

### 🔴 Rearmar con la seta pulsada no debe hacer nada

```pascal
IF NOT #EmergencyOk THEN
   #statEmergency := TRUE;
ELSIF #CmdReset THEN
   #statEmergency := FALSE;
END_IF;
```

El `ELSIF` es el detalle: el rearme **solo llega** si `EmergencyOk` ya es TRUE, es decir, con la
seta liberada. Escrito como dos `IF` sueltos, pulsar rearme con la seta aún pulsada borraría la
memoria y la máquina quedaría lista para arrancar con la emergencia activa.

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

🔴 **Eso último es la regla de seguridad de todo esto.** "Manual" no puede significar "sin
enclavamientos": si en manual se puede mover un cilindro con la puerta abierta, el manual es una
forma de hacerse daño. Si necesitas un modo que salte enclavamientos para mantenimiento, eso es
un **tercer modo con llave**, no el manual del operador.

---

## Verificación en PLCSIM

| Caso | Qué debe pasar |
|---|---|
| Pulsar seta en automático | `ModeStopped` inmediato, secuencia abortada |
| Rearmar **con la seta aún pulsada** | **No pasa nada.** `EmergencyLatched` sigue TRUE |
| Liberar seta y rearmar | Se desenclava, pero sigue en Parado hasta pedir modo |
| Pedir auto con secuencia en marcha | Se ignora |
| Pasar a manual en mitad de un ciclo | Cambia a manual y la secuencia aborta |
| Pedir auto sin `AutoConditions` | Se ignora |
| Dos órdenes a la vez (manual + auto) | **Gana manual**, por precedencia |

🔴 **El segundo caso es el que hay que probar sí o sí.** Es el que convierte un rearme en un
peligro.
