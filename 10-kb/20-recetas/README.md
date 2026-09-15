# Recetas — runbooks accionables

> Cada receta responde a *"cómo hago X"* con la secuencia exacta de llamadas, qué verificar, y
> qué hacer cuando falla. No son tutoriales: son procedimientos.

## Formato de una receta

```
Objetivo        una frase
Precondiciones  qué tiene que ser cierto antes
Servidor        tia-inspect | tia-create
Secuencia       las llamadas, en orden, con los parámetros que importan
Verificación    cómo sabes que salió bien
Si falla        los modos de fallo conocidos y su arreglo
```

## Índice

### Tanda 1 — leer y entender ✅ *sirve desde el día 1, no depende de los estándares*

| # | Receta | Estado |
|---|---|---|
| [R01](R01-inventariar-proyecto.md) | Inventariar un proyecto que no conoces | ✅ |
| [R02](R02-donde-se-usa.md) | Dónde se usa una tag, qué la escribe, qué la lee | ✅ |
| [R03](R03-exportar-a-git.md) | Exportar un proyecto a texto y meterlo en git | ✅ |
| [R04](R04-entender-un-bloque.md) | Entender qué hace un bloque | ✅ |

> ✅ **Las cuatro ejecutadas contra proyectos reales el 2026-09-14** (`npatel-basement-light`,
> `npatel-sorting-plant`, y los 7 en lote para R03).
>
> La pasada real corrigió **cuatro errores** de la versión escrita a partir del código:
>
> | Decía | Es |
> |---|---|
> | `OpenProject(projectPath:)` | **`path`** |
> | "Openness no migra proyectos, hay que hacerlo a mano" | **Migra solo**, vía `OpenWithUpgrade` |
> | "Empieza por `GetBlockInterface`" | Solo vale para **bloques de datos**; para FB/FC, `GetBlockSource` |
> | "El LAD sale como XML ilegible" | El LAD en `.s7dcl` **se lee perfectamente** |
>
> Los parámetros verificados están en
> [`90-referencia/parametros-tia-inspect.md`](../90-referencia/parametros-tia-inspect.md).

### Tanda 2 — esqueleto y tags

| # | Receta | Estado |
|---|---|---|
| R05 | Proyecto nuevo desde cero | ⬜ |
| R06 | De una lista de E/S a tablas de tags importadas | ⬜ |
| R07 | UDTs y bloques de datos | ⬜ |

### Tanda 3 — lógica ✅

| # | Receta | Bloque | Estado |
|---|---|---|---|
| [R08](R08-bloque-motor.md) | Bloque de motor | [`FB_Motor`](../../60-library/blocks/FB_Motor.scl) | ✅ |
| [R09](R09-bloque-valvula.md) | Bloque de válvula | [`FB_ValveOnOff`](../../60-library/blocks/FB_ValveOnOff.scl) | ✅ |
| [R10](R10-secuencia.md) | Secuencia / máquina de estados | [`FB_SequenceTemplate`](../../60-library/blocks/FB_SequenceTemplate.scl) | ✅ |
| [R11](R11-modos-manual-auto.md) | Modos manual / automático | [`FB_ModeManager`](../../60-library/blocks/FB_ModeManager.scl) | ✅ |
| [R12](R12-alarmas.md) | Gestión de alarmas | [`FB_AlarmLatch`](../../60-library/blocks/FB_AlarmLatch.scl) | ✅ |

> ✅ **Los cinco bloques compilan en TIA V20 con 0 errores y 0 advertencias.** Se importaron de
> verdad en un proyecto y se compilaron; el código publicado es el que pasó la prueba.
>
> ⚠️ **Compilar no es funcionar.** Ninguno se ha ejecutado en PLCSIM todavía. Cada receta lleva
> su tabla de casos a probar, y esa parte no se delega
> ([`definition-of-done.md`](../../20-standards/definition-of-done.md) nivel 4).

### Tanda 4 — HMI y documentación

| # | Receta | Estado |
|---|---|---|
| R13 | Pantalla WinCC Unified | ⬜ |
| R14 | Binding de tags HMI ↔ PLC | ⬜ |
| R15 | Generar la lista de E/S | ⬜ |
| R16 | Generar la descripción funcional | ⬜ |

El orden y su porqué están en [ADR-004](../../00-meta/decisiones/ADR-004-prioridades.md).

## Dónde probar todo esto

En [`50-examples/`](../../50-examples/) hay **siete proyectos TIA reales** desempaquetados y
listos. No son de nadie: si se rompen, no pasa nada. Empieza por
`npatel-basement-light`, que es el más pequeño.
