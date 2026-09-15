# R09 — Bloque de válvula

**Objetivo.** Maniobrar una válvula todo-nada con finales de carrera y diagnóstico útil.

> ✅ **Verificado el 2026-09-14:** [`FB_ValveOnOff.scl`](../../60-library/blocks/FB_ValveOnOff.scl)
> importado y compilado en TIA V20 con **0 errores y 0 advertencias**.

**Lee [R08](R08-bloque-motor.md) primero.** El procedimiento de importación, la regla del
enclavamiento en LAD y la nomenclatura de instancias son los mismos. Aquí solo va lo que cambia.

---

## Lo que diferencia una válvula de un motor

### 🔒 Una sola salida, no dos

```
Solenoid = TRUE   → abrir
Solenoid = FALSE  → cerrar
```

Es lo más común y lo más seguro: la válvula de doble efecto con dos solenoides puede quedarse
**en medio** si se corta la alimentación. Con una sola bobina y retorno por muelle, un corte la
lleva a su posición de reposo, que es la que has elegido como segura.

🔴 **Por eso el bloque desenergiza ante fallo:** `#Solenoid := #statOpenLatch AND NOT #statFault`.
Fallo = ir a reposo. No es un detalle de implementación, es la decisión de seguridad del bloque.

### 🔒 Dos finales de carrera, y uno de ellos imposible

```pascal
IF #FbUsed AND #FbOpen AND #FbClosed THEN
   #statFault     := TRUE;
   #statFaultCode := #FAULT_BOTH_LIMITS;   // 203
END_IF;
```

**Abierta y cerrada a la vez no puede pasar físicamente.** Si lo lees, es un cable cortado, un
sensor mal ajustado, o un NC cableado como NA.

💡 Esta comprobación va **antes** que el tiempo de carrera, porque si los sensores mienten,
cualquier otra conclusión que saques de ellos también miente.

### Tres posiciones, no dos

| Salida | |
|---|---|
| `IsOpen` | Confirmada abierta |
| `IsClosed` | Confirmada cerrada |
| `Moving` | **En tránsito** — ni una cosa ni la otra |

Un motor está en marcha o parado. Una válvula tiene un tercer estado que dura segundos y en el
que la mitad de las condiciones de proceso no valen. Ignorarlo es la causa de los "a veces falla
y no sé por qué".

**Códigos:** `201` no llegó a abierta · `202` no llegó a cerrada · `203` los dos finales a la vez.

---

## Válvula sin finales de carrera

```
FbUsed = FALSE
```

El bloque deja de vigilar lo que no existe y deduce la posición de la orden:
`IsOpen := statOpenLatch`. Honesto: dice lo que ha mandado, no lo que ha pasado.

⚠️ **Y hay que saberlo.** Sin final de carrera no hay forma de detectar una válvula agarrotada.
Si el proceso depende de que esté realmente abierta, hace falta el sensor — o un caudalímetro
como confirmación indirecta cableado a `FbOpen`.

---

## Verificación en PLCSIM

| Caso | Qué debe pasar |
|---|---|
| Abrir, `FbOpen` no llega | A los 5 s: `Fault`, código **201**, solenoide cae |
| Cerrar, `FbClosed` no llega | Código **202** |
| Forzar `FbOpen` y `FbClosed` a la vez | Código **203**, inmediato |
| Abrir sin `Interlock` | No se energiza |
| Fallo estando abierta | **Se desenergiza y cierra.** Comprueba que eso es lo que quieres |

🔴 **Ese último es una decisión de proceso, no de programa.** Si en tu máquina lo seguro ante
fallo es quedarse abierta —un venteo, una refrigeración— este bloque **no vale tal cual** y hay
que invertir la lógica del solenoide. Piénsalo antes de copiarlo.
