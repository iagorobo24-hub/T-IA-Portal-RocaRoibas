# STL — no es el lenguaje elegido aquí

## Decisión

STL (lista de instrucciones) es el ensamblador de bajo nivel de Siemens: cada línea es una
instrucción sobre el acumulador. [ADR-003](../../00-meta/decisiones/ADR-003-lenguajes.md) elige
SCL para toda la lógica de cálculo y secuencias porque es texto plano igual de versionable pero
mucho más legible y mantenible — STL no aporta ninguna ventaja sobre SCL para lo que se programa
en este workspace, y sí más riesgo de error (sin comprobación de tipos tan estricta, lógica
implícita sobre el resultado de la instrucción anterior).

## Estado

⬜ **No usado como lenguaje de autor.** No hay ningún bloque STL en `60-library/` ni receta que lo
use ni se prevé escribir uno.

## Matiz sobre exportación

📄 **Documentado, no explotado aquí.** Los propios servidores MCP de Openness reconocen STL como
uno de los lenguajes que puede devolver `GetBlockSource`/`GenerateBlockSource` cuando el bloque
**ya está escrito en STL** en el proyecto (por ejemplo, bloques heredados de un proyecto
migrado) — eso es leer/exportar lo que ya existe, no una decisión de escribir STL nuevo. Si
aparece un bloque STL heredado en un proyecto real, se lee y se entiende igual que cualquier
otro, pero **no se genera STL nuevo**: si hace falta tocarlo, se reescribe en SCL siguiendo
[`scl.md`](scl.md), no se edita STL a mano.

⚠️ **Por confirmar** el comportamiento exacto de exportación STL en esta versión de `tia-inspect`
— no hay evidencia propia registrada todavía.
