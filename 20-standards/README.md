# Estándares

> **Estado: PROPUESTA, pendiente de tu revisión.**
> No tenías estándar previo (TDD Q12-Q19), así que esto es una propuesta completa basada en las
> convenciones más extendidas del sector: Siemens SCE, PLCopen e ISA-5.1.
> Todo lo marcado 🔸 es gusto y se cambia sin coste. Lo marcado 🔒 tiene una razón técnica
> detrás, y está explicada.

| Documento | Qué fija |
|---|---|
| [`naming.md`](naming.md) | Nombres de bloques, tags, UDTs, pantallas, ficheros |
| [`estructura-proyecto.md`](estructura-proyecto.md) | Cómo se organiza un proyecto por dentro |
| [`estilo-scl.md`](estilo-scl.md) | Cómo se escribe SCL aquí |
| [`definition-of-done.md`](definition-of-done.md) | Cuándo un proyecto está terminado de verdad |

## Estado

✅ **La nomenclatura está cerrada.** Las 5 dudas que quedaban se resolvieron el 2026-09-14
contrastándolas con los 7 proyectos reales de [`50-examples/`](../50-examples/) — ver
[ADR-008](../00-meta/decisiones/ADR-008-nomenclatura-cerrada.md).

Cuatro de las cinco coinciden con lo que hace la gente en proyectos reales. **Una va a
contracorriente a propósito** (los DBs de instancia) y está marcada como la primera candidata a
revisión si molesta al usarla.

## Cómo revisarlo sin perder una tarde

1. Lee la sección **"Las 5 dudas — cerradas"** al final de [`naming.md`](naming.md). Cada
   decisión dice qué hacen los proyectos reales y por qué se sigue o no. 10 minutos.
2. Mira el árbol de [`estructura-proyecto.md`](estructura-proyecto.md) y dime si se parece a cómo
   organizas tú.
3. Lo demás se ajusta sobre el primer proyecto real, que es cuando de verdad se ve.

## Por qué importa más de lo que parece

Un estándar no es burocracia: es lo que hace que un agente genere **tu** código en vez de código
genérico correcto. Sin esto, produce bloques que compilan y funcionan pero que no se parecen a
nada de lo que tienes, y acabas reescribiéndolos. Con esto, produce algo que puedes meter en un
proyecto sin tocarlo.
