# R12 — Gestión de alarmas

**Objetivo.** Que una alarma no se pierda, no se borre sola, y diga qué pasó aunque la causa ya no
esté.

> ✅ **Verificado el 2026-09-14:** [`FB_AlarmLatch.scl`](../../60-library/blocks/FB_AlarmLatch.scl)
> compilado en TIA V20 con **0 errores y 0 advertencias**.

---

## Las dos dimensiones de una alarma

🔴 **Esto es lo que casi todas las listas de alarmas caseras hacen mal.** Una alarma tiene dos
estados **independientes**: si la causa está presente, y si alguien se ha enterado.

| | sin reconocer | reconocida |
|---|---|---|
| **causa activa** | ACTIVA NO ACK | ACTIVA ACK |
| **causa ida** | 🔴 **IDA NO ACK** | *(se borra)* |

El cuadrante rojo es el que se olvida: **la causa ya no está, pero nadie se enteró de que pasó**.
Un pico de presión de dos segundos a las 3 de la madrugada. Si la alarma desaparece sola, el
turno de mañana no sabe que ocurrió — y ese es justo el dato que explica la pieza mala.

```pascal
// Solo se borra cuando se dan las DOS cosas.
IF #statLatched AND #statAcked AND NOT #tempActive THEN
   #statLatched := FALSE;
   #statAcked   := FALSE;
END_IF;
```

Por eso el bloque saca `GoneUnacked` como salida propia: es el aviso de *"esto pasó y no lo
viste"*.

---

## Lo demás que hace el bloque

### Un ack anterior no vale para una alarma nueva

```pascal
IF #tempActive AND NOT #statLatched THEN
   #statLatched := TRUE;
   #statAcked   := FALSE;   // ← se reinicia
END_IF;
```

Si la alarma se va y vuelve, hay que reconocerla otra vez. Es una alarma nueva.

### Antirrebote con `OnDelay`

Sin filtro, un contacto que rebota genera diez entradas en el histórico y lo hace inservible.
`OnDelay = T#0S` desactiva el filtro y el comportamiento es inmediato.

### `Enable` para inhibir

Una alarma inhibida (bypass de mantenimiento, sensor averiado) **se borra**, no se queda
enclavada de fondo.

🔴 **Y hay que sacar al HMI qué alarmas están inhibidas.** Un bypass que nadie ve es un bypass
permanente. Una lista de "alarmas inhibidas" en la pantalla de diagnóstico es obligatoria.

### La sirena

```pascal
#Horn := #statLatched AND NOT #statAcked;
```

Suena mientras no se reconozca, **esté o no la causa**. Reconocer calla la sirena; no arregla
nada.

---

## Del bloque a una lista de alarmas

`FB_AlarmLatch` es **una** alarma. Para una máquina:

```
80_Diagnostics/
├── FB_AlarmCollector         una instancia por alarma + el OR general
└── DB_Alarms                 el array que lee el HMI
```

**Patrón:** un `FB_AlarmLatch` por condición, todas las instancias en un FB colector que además
calcula el resumen:

```pascal
#AnyUnacked := #almMotorFault.Unacked OR #almValveTimeout.Unacked OR ...;
#Horn       := #almMotorFault.Horn    OR #almValveTimeout.Horn    OR ...;
```

### Qué hace falta en la matriz de alarmas

De [`definition-of-done.md`](../../20-standards/definition-of-done.md), nivel 5. Por cada alarma:

| Campo | Ejemplo |
|---|---|
| Código | `101` |
| Texto | `M01 Cinta entrada: sin confirmación de marcha` |
| **Causa probable** | Contactor no pega, térmico disparado, cable de retorno suelto |
| **Acción** | Comprobar guardamotor QM01. Rearmar desde el HMI |
| Severidad | Paro de máquina / aviso |

🔴 **Sin las columnas de causa y acción, la matriz es una lista de textos.** Lo que convierte una
alarma en algo útil a las 3 de la madrugada es que diga qué mirar.

### Los códigos ya están repartidos

`1xx` motores · `2xx` válvulas · `9xx` pasos de fallo de secuencia
([`60-library/blocks/README.md`](../../60-library/blocks/README.md)). Cada `FaultCode` de un
bloque de dispositivo es una alarma candidata, y el mapeo es directo.

---

## Alternativa: alarmas de sistema de TIA

TIA tiene `PLC supervisions & alarms` (ProDiag) y `Program_Alarm`, que integran con el HMI sin
DBs intermedios y traen marca de tiempo del PLC.

| | |
|---|---|
| **A favor** | Menos código, timestamp en el PLC, integración directa con el HMI |
| **En contra** | Atado al ecosistema Siemens, más difícil de exportar a texto y versionar, y en HMI de terceros no sirve |

⚠️ **No lo he probado en este workspace.** Si tus proyectos son 100% Siemens y el HMI es WinCC,
merece evaluarlo antes de construir la lista a mano. Queda pendiente.

---

## Verificación en PLCSIM

| Caso | Qué debe pasar |
|---|---|
| Aparece la causa | `Active`, `Latched`, `Unacked`, `Horn` |
| Reconocer con la causa presente | `Horn` calla. `Latched` **sigue** |
| La causa se va, ya reconocida | Se borra todo |
| **La causa se va SIN reconocer** | 🔴 `GoneUnacked` = TRUE. **No se borra** |
| Reconocer después | Ahora sí se borra |
| Causa va y vuelve | Vuelve `Unacked`: es una alarma nueva |
| Rebote de 100 ms con `OnDelay = T#500ms` | **No se dispara** |
| Inhibir con la alarma activa | Se borra entera |

🔴 **El cuarto es el que distingue una gestión de alarmas de una lista de bits.**
