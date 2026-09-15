# R08 — Bloque de motor

**Objetivo.** Poner en marcha un motor con confirmación, enclavamiento y diagnóstico, siguiendo
los estándares, sin escribirlo desde cero cada vez.

**Servidor.** `tia-inspect` con `--allow-write`.

> ✅ **Verificado el 2026-09-14.** El bloque se importó en un proyecto real y compiló con
> **0 errores y 0 advertencias**. El código de [`60-library/blocks/FB_Motor.scl`](../../60-library/blocks/FB_Motor.scl)
> es el que pasó esa prueba, no una versión "parecida".

---

## 0. Antes de escribir nada: ¿ya existe?

🔒 **Mira [`60-library/blocks/`](../../60-library/blocks/) primero.** `FB_Motor` ya está hecho,
probado y versionado. Escribir otro es crear una divergencia que alguien tendrá que reconciliar.

Solo escribe uno nuevo si el existente **no puede** hacer lo que necesitas. Y entonces, plantéate
antes si cabe como parámetro del que ya hay.

---

## 1. Qué resuelve `FB_Motor`

| Entrada | |
|---|---|
| `CmdStart` / `CmdStop` / `CmdReset` | Órdenes. El paro manda sobre la marcha |
| `Interlock` | **TRUE = permitido arrancar.** Se calcula fuera |
| `Feedback` | Confirmación desde campo (contactor, detector de giro) |
| `FeedbackUsed` | `FALSE` si el motor no tiene retorno |
| `StartTimeout` / `StopTimeout` | Esperas máximas, por defecto 3 s |

| Salida | |
|---|---|
| `Run` | Al contactor |
| `Running` | Marcha **confirmada** |
| `Ready` | Disponible para arrancar |
| `Fault` / `FaultCode` | Fallo enclavado y su motivo |

**Códigos de fallo:** `101` no confirmó a tiempo · `102` confirmó y se perdió · `103` sigue
confirmando tras el paro.

> 💡 `101` y `102` son fallos distintos con la misma pinta. `101` suele ser el contactor que no
> pega o un térmico. `102` es algo que se soltó en marcha. Distinguirlos ahorra la mitad del
> tiempo de diagnóstico, y por eso el bloque lleva un `statWasConfirmed`.

---

## 2. El enclavamiento se calcula FUERA, en LAD

🔒 **Esta es la decisión de diseño que hay que entender.**

[ADR-003](../../00-meta/decisiones/ADR-003-lenguajes.md) dice lógica en SCL, LAD para lo que mira
el mantenedor. Un bloque de motor es las dos cosas a la vez. La resolución:

> **La lógica del motor va en SCL dentro del FB. La cadena de condiciones que explica por qué no
> arranca va en LAD, en el network donde se llama al bloque.**

Porque cuando una máquina no arranca, el mantenedor no abre `FB_Motor`: abre el network de la
llamada y busca qué contacto está abierto. Si esa cadena estuviera dentro del FB en SCL, tendría
que leer código.

```
Network: "M01 Cinta de entrada - permisos de marcha"

"DI_ES01_Ok" ─┤├─ "DI_QM01_Ok" ─┤├─ "M_Sys_AutoMode" ─┤├─ NOT "DI_S05_Jam" ─┤/├─┐
                                                                                 │
                                                    ┌────────────────────────────┘
                                                    │  ┌──────────────────┐
                                                    └──┤ Interlock        │
                                                       │  "FB_Motor"      │
                                                       │  iDB_M01         │
```

Ahí se ve de un vistazo que falta la seta, o el guardamotor, o que hay atasco.

---

## 3. Meterlo en el proyecto

```powershell
30-tools\scripts\Invoke-TiaMcp.ps1 -AllowWrite -TimeoutSeconds 900 -Calls @(
    @{ name='Connect' },
    @{ name='OpenProject'; args=@{ path='...\Proyecto.ap20' } },
    @{ name='CreateExternalSourceFromFile'; args=@{
         softwarePath='PLC_1'; groupPath=''; name='FB_Motor'
         filePath='...\60-library\blocks\FB_Motor.scl' } },
    @{ name='GenerateBlocksFromSource'; args=@{ softwarePath='PLC_1'; sourcePath='FB_Motor' } },
    @{ name='CompileSoftware'; args=@{ softwarePath='PLC_1' } },
    @{ name='SaveProject' }
)
```

⚠️ **Son dos pasos, no uno.** `CreateExternalSourceFromFile` mete el fichero en el proyecto;
`GenerateBlocksFromSource` lo convierte en bloque. Si haces solo el primero, tienes una fuente
externa y ningún bloque.

⚠️ **Todo esto es en memoria.** Cada respuesta lo dice: *"The change is in memory; call
'SaveProject' to persist it"*. Sin `SaveProject`, al cerrar no queda nada.

### Reimportar una versión nueva

```powershell
@{ name='DeleteBlock';          args=@{ softwarePath='PLC_1'; blockPath='FB_Motor' } },
@{ name='DeleteExternalSource'; args=@{ softwarePath='PLC_1'; sourcePath='FB_Motor' } },
# ...y vuelta a importar
```

Borra los dos. Si dejas la fuente vieja, acabas con dos fuentes del mismo nombre.

---

## 4. Una instancia por motor

🔒 **`iDB_<Equipo>`**, no lo que TIA propone ([N2 de `naming.md`](../../20-standards/naming.md)):

```
iDB_M01   iDB_M02   iDB_M12
```

`FB_Motor_DB_7` no te dice qué motor es. `iDB_M12` sí, y coincide con el código del P&ID.

Parametrización por instancia, en los valores de arranque del DB:

```
iDB_M01.StartTimeout = T#3s     motor pequeño, arranca directo
iDB_M07.StartTimeout = T#8s     motor grande con arrancador suave
iDB_M12.FeedbackUsed = FALSE    este no tiene retorno de contactor
```

💡 **El mismo bloque, comportamiento distinto, cero código duplicado.** Esto es lo que hace que
merezca la pena una librería.

---

## 5. Verificación

- [ ] Compila con **0 errores y 0 advertencias**
- [ ] El DB de instancia se llama `iDB_<Equipo>`
- [ ] El bloque está en `90_Library/` y **no se ha editado dentro del proyecto**
- [ ] El network de llamada tiene título y se entiende sin abrir el FB
- [ ] `Interlock` viene de una cadena LAD, no de un `TRUE` fijo
- [ ] `FaultCode` llega al HMI

### Lo que hay que probar en PLCSIM, no razonar

🔴 **Compilar no es funcionar.** Casos mínimos:

| Caso | Qué debe pasar |
|---|---|
| Start sin `Interlock` | No arranca. `Ready` = FALSE |
| Start y no llega `Feedback` | A los 3 s: `Fault`, `FaultCode` = 101, `Run` cae |
| En marcha, se pierde `Feedback` | `Fault`, `FaultCode` = **102** |
| `CmdReset` con la causa aún presente | Se rearma y **vuelve a fallar**. Correcto |
| `CmdStart` y `CmdStop` a la vez | **Gana el paro** |
| Caída y vuelta de tensión | Arranca parado, no retoma la marcha solo |

El último es el que más se olvida y el que más daño hace.

---

## 6. Si falla

| Síntoma | Causa | Arreglo |
|---|---|---|
| `The parameter '#X' might not be initialized` | Lees una salida antes de escribirla | Usa una variable `stat` y publica la salida al final. Ver abajo |
| `GenerateBlocksFromSource` da 0 objetos | Error de sintaxis en el SCL | Pasa `keepOnError: true` para que deje la fuente y poder mirarla en TIA |
| El bloque no aparece | Falta `GenerateBlocksFromSource` o `SaveProject` | Los dos pasos, y guardar |
| Compila pero el motor no arranca en PLCSIM | `Interlock` a FALSE | Es lo primero que hay que mirar, siempre |

### 🔴 La lección que costó una recompilación

La primera versión leía `#Fault` dentro de la lógica. El compilador dio **4 advertencias**:

```
The parameter '#Fault' might not be initialized.
```

Tiene razón: una `VAR_OUTPUT` se **escribe**, no se usa como memoria. El arreglo —mover el estado
a `statFault` y publicar `#Fault := #statFault` al final— quitó las cuatro y además hizo que el
bloque cumpliera su propia regla de "cada salida se escribe en un solo sitio".

**Está ahora como regla dura en [`estilo-scl.md`](../../20-standards/estilo-scl.md).**
