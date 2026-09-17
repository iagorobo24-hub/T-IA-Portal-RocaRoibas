# Lenguajes — sintaxis, patrones, antipatrones

> Qué lenguaje usar para qué, y cómo se escribe cada uno en este workspace. La decisión de fondo
> vive en [ADR-003](../../00-meta/decisiones/ADR-003-lenguajes.md); aquí está la guía operativa.

## Matriz de decisión

| Situación | Lenguaje | Motivo |
|---|---|---|
| Cálculo, escalado, tratamiento de datos, comunicaciones | **SCL** | Texto plano: el agente lo genera bien y diffea en git |
| Secuencias, máquinas de estado, gestión de modos | **SCL** | Un `CASE` legible vale más que 30 networks de contactos |
| Lógica que un mantenedor mira y fuerza delante de la máquina | **LAD** | Enclavamientos, mandos de motor/válvula, condiciones de marcha |
| Seguridad (si aplica) | **LAD** | Convención del sector y trazabilidad en auditoría |

**El agente nunca escribe LAD a mano.** Si duda entre SCL y LAD, elige SCL y lo dice.

## Estado por lenguaje

| Lenguaje | Estado | Contenido |
|---|---|---|
| [`scl.md`](scl.md) | 🟢 Guía completa, verificada compilando | Estructura de bloque, formato, antipatrones, UDTs (⚠️ pendiente) |
| [`lad/README.md`](lad/README.md) | 🟡 Generado por receta, nunca a mano | Flujo de importación, riesgo en-US sin confirmar, receta de enclavamiento |
| [`patrones-por-bloque.md`](patrones-por-bloque.md) | 🟢 8 patrones extraídos de código compilado | Enclavamiento, salidas únicas, `Fault`/`FaultCode`, secuencia, precedencias, alarmas |
| [`fbd.md`](fbd.md) | ⬜ No elegido | Por qué no, con el hueco para documentarlo si algún día aporta algo |
| [`stl.md`](stl.md) | ⬜ No elegido como lenguaje de autor | Por qué no; matiz sobre lectura de bloques heredados |
| [`graph.md`](graph.md) | ⬜ No usado, decisión documentada | Por qué SCL en vez de GRAPH, y cuándo sí tendría sentido |

## Si solo vas a leer dos cosas

1. **[`patrones-por-bloque.md`](patrones-por-bloque.md)** — los ocho patrones que hacen que un
   bloque de librería sea predecible, con el código real que los usa.
2. **[`scl.md`](scl.md)** — cómo se escribe SCL aquí, con el bloque de ejemplo completo y los
   antipatrones ya corregidos una vez.

Recetas de aplicación a un caso concreto (motor, válvula, secuencia, modos, alarmas):
[`10-kb/20-recetas/`](../20-recetas/README.md) R08-R12.
