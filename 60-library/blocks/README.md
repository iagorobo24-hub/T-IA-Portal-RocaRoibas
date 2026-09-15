# Librería de bloques

> ✅ **Los cinco compilan con 0 errores y 0 advertencias en TIA V20.**
> Verificado el 2026-09-14 importándolos de verdad en un proyecto y compilando.
> No son código "que debería funcionar".

| Bloque | Family | Qué hace | Receta |
|---|---|---|---|
| [`FB_Motor`](FB_Motor.scl) | `Drives` | Motor marcha/paro con confirmación y fallo enclavado | [R08](../../10-kb/20-recetas/R08-bloque-motor.md) |
| [`FB_ValveOnOff`](FB_ValveOnOff.scl) | `Valves` | Válvula todo-nada con dos finales de carrera | [R09](../../10-kb/20-recetas/R09-bloque-valvula.md) |
| [`FB_SequenceTemplate`](FB_SequenceTemplate.scl) | `Sequence` | **Plantilla** de máquina de estados. Se copia y se rellena | [R10](../../10-kb/20-recetas/R10-secuencia.md) |
| [`FB_ModeManager`](FB_ModeManager.scl) | `Modes` | Parado / Manual / Automático con precedencias | [R11](../../10-kb/20-recetas/R11-modos-manual-auto.md) |
| [`FB_AlarmLatch`](FB_AlarmLatch.scl) | `Diag` | Una alarma: enclava, reconoce, distingue los 4 estados | [R12](../../10-kb/20-recetas/R12-alarmas.md) |

Todos en **`VERSION 0.1`**. Suben de versión cuando cambie su comportamiento
([N5 de `naming.md`](../../20-standards/naming.md)).

---

## Cómo se meten en un proyecto

```powershell
30-tools\scripts\Invoke-TiaMcp.ps1 -AllowWrite -Calls @(
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

Dos pasos: la fuente externa **entra** en el proyecto, y después **genera** el bloque. Son
operaciones distintas y las dos hacen falta.

🔒 **Van a `90_Library/`** y **no se editan dentro del proyecto**
([`estructura-proyecto.md`](../../20-standards/estructura-proyecto.md)). Si hay que cambiar algo,
se cambia aquí, se prueba, se sube la versión y se reimporta. Editarlo in situ hace que la
siguiente reimportación se lleve el cambio por delante.

---

## Decisiones de diseño comunes a todos

Se repiten a propósito: un bloque de librería tiene que ser predecible.

### 🔒 El enclavamiento entra, no se calcula dentro

Todos tienen una entrada `Interlock`, y ninguno decide por su cuenta si puede arrancar.

Es la resolución de la tensión de [ADR-003](../../00-meta/decisiones/ADR-003-lenguajes.md): la
lógica va en SCL, pero **la cadena de condiciones que explica por qué algo no arranca se dibuja
en LAD en el punto de llamada** — que es lo que el mantenedor mira y fuerza delante de la máquina.

### 🔒 El paro y el fallo mandan sobre la marcha, siempre

En todos, la rama que **desactiva** va primero en el `IF`. Así se falla por el lado seguro sin
depender del orden de evaluación.

### 🔒 Las salidas se escriben en un solo sitio, al final

Y nunca se usan como memoria: el estado vive en variables `stat`. No es estilo, es lo que exige
el compilador — ver [`estilo-scl.md`](../../20-standards/estilo-scl.md).

### 🔒 El fallo es enclavado y con código

`Fault` no se borra solo: hace falta `CmdReset`. Y `FaultCode` dice **cuál** fue:

| Rango | Familia |
|---|---|
| `1xx` | Motores |
| `2xx` | Válvulas |
| `9xx` | Pasos de fallo de secuencia |

Un `Fault` booleano sin código obliga a adivinar. El código se lleva al HMI y se acabó la
adivinanza.

### 🔒 `*_Used` para el hardware que no está

`FeedbackUsed`, `FbUsed`. El mismo bloque sirve para un motor con retorno de contactor y para uno
sin él, sin tocar el código. En `FALSE`, el bloque no vigila lo que no existe.

---

## Lo que falta

- [ ] Probar en **PLCSIM** — compilar no es funcionar. Ninguno se ha ejecutado todavía
- [ ] `FB_AnalogInput` (escalado, límites, filtro)
- [ ] `FB_ValveAnalog`
- [ ] UDTs de interfaz HMI por dispositivo
- [ ] Faceplates de HMI que emparejen con estos bloques
