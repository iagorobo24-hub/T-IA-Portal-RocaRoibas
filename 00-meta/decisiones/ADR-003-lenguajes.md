# ADR-003 — Lenguaje de programación por defecto

- **Fecha:** 2026-09-14
- **Estado:** ✅ Aceptada
- **Pregunta origen:** TDD Q15 — respuesta: *SCL para lógica, LAD para planta*

## Decisión

| Situación | Lenguaje | Motivo |
|---|---|---|
| Cálculo, escalado, tratamiento de datos, comunicaciones | **SCL** | Texto plano: el agente lo genera bien y diffea en git |
| Secuencias, máquinas de estado, gestión de modos | **SCL** | Un `CASE` legible vale más que 30 networks de contactos |
| Lógica que un mantenedor mira y fuerza delante de la máquina | **LAD** | Enclavamientos, mandos de motor/válvula, condiciones de marcha |
| Seguridad (si aplica) | **LAD** | Convención del sector y trazabilidad en auditoría |

## Consecuencias para el agente

Esto se convierte en reglas duras de `AGENTS.md`:

1. **SCL se escribe directo.** Vía `ImportPlcExternalSource` + `GenerateBlocksFromExternalSource`,
   o como `.s7dcl`. Es texto: el agente lo escribe, lo revisa y lo versiona.
2. **LAD NO se escribe a mano nunca.** LAD es XML SimaticML posicional: generar un network a
   pelo es frágil y falla de formas que no dan error hasta la compilación. El agente **solo**
   produce LAD a partir de las recetas parametrizadas de `10-kb/30-lenguajes/lad/` y de los
   bloques probados de `60-library/`.
3. **Si el agente duda entre los dos, elige SCL y lo dice.** Convertir SCL→LAD después es
   trabajo humano de 10 minutos; depurar LAD mal generado son horas.

## Riesgo conocido y no resuelto

Hay una limitación documentada por el autor de `tia-inspect`: importar bloques **LAD** desde
documentos SIMATIC SD exige que el `.s7res` acompañante lleve etiquetas **en-US** para todos los
ítems, o la importación falla. Es un bug de Openness, no del servidor. Hay que probarlo pronto
con un bloque LAD real; afecta directamente al flujo "editar LAD en git y devolverlo a TIA".
