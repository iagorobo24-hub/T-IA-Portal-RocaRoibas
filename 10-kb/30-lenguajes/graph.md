# GRAPH — decisión "no-GRAPH"

> ✅ **Verificado el 2026-09-14:** [`FB_SequenceTemplate.scl`](../../60-library/blocks/FB_SequenceTemplate.scl)
> compilado en TIA V20 con **0 errores y 0 advertencias**, resolviendo con SCL lo que GRAPH
> resolvería con una máquina de estados gráfica.

## Por qué SCL y no GRAPH

| | |
|---|---|
| **GRAPH** | Necesita **licencia aparte**, y no se exporta como texto legible: en git es un binario |
| **SCL** | Un `CASE` hace lo mismo, diffea, y se lee sin abrir TIA |

Detalle completo del patrón que sustituye a GRAPH — cuatro regiones en orden fijo, numeración por
decenas, `S_FAULT := 900`, los pasos no escriben salidas: [R10](../20-recetas/R10-secuencia.md) y
[`patrones-por-bloque.md` #6](patrones-por-bloque.md#6-secuencia-cuatro-regiones-en-orden-fijo-y-los-pasos-no-escriben-salidas).

## Cuándo sí tendría sentido GRAPH

Si ya hay licencia de GRAPH en el equipo y el equipo de mantenimiento ya lo usa, es mejor que SCL
para secuencias largas (~40 pasos) con ramas paralelas reales — ahí una máquina de estados en
`CASE` se vuelve difícil de leer de un vistazo, mientras que GRAPH lo representa gráficamente sin
esfuerzo. Para todo lo demás, el `CASE` en SCL gana por mantenibilidad y porque diffea en git.

## Estado

⬜ **No usado en este workspace.** No hay licencia de GRAPH verificada ni ningún bloque GRAPH en
`60-library/`. Si en algún proyecto de cliente aparece una secuencia GRAPH heredada, se lee y se
documenta su comportamiento igual que cualquier otro bloque — no se convierte a SCL sin que el
usuario lo pida explícitamente, porque GRAPH sigue siendo válido para el caso de uso que lo
justifica (secuencias largas con ramas paralelas y licencia ya pagada).
