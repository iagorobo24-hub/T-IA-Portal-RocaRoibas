# Protocolo de eval de la base de conocimiento

## Qué hay y qué valida hoy

- [`kb-quiz.md`](kb-quiz.md) — 10 preguntas abiertas (`Q01`-`Q10`) sobre el contrato del agente y
  la base de conocimiento.
- [`kb-answer-key.md`](kb-answer-key.md) — 10 respuestas de referencia, cada una citando el
  fichero fuente entre backticks.
- `30-tools/tests/Test-KnowledgeIndex.ps1` — el único consumidor automatizado hoy. Comprueba que
  hay exactamente 10 preguntas y 10 respuestas, y que cada referencia citada en la clave de
  respuestas existe en disco.

🔴 **Lo que NO valida:** si un agente real responde bien a las preguntas. Comprobar que una
referencia existe no es comprobar que la respuesta es correcta ni que la base de conocimiento es
suficiente por sí sola para que un agente sin contexto previo llegue a esa respuesta.

## Por qué esto es un protocolo manual, no un CI semántico

Juzgar si la respuesta de un agente a una pregunta abierta es correcta requiere invocar un LLM y
comparar semántica, no sintaxis. Eso no se puede hacer desde un test de PowerShell sin coste ni
credenciales, y prometer una automatización así sin tener el mecanismo real rompería la propia
regla de este repo de no afirmar sin evidencia (`10-kb/README.md`). Por eso esto es un protocolo
documentado y repetible, con evidencia registrada a mano, no una pieza de CI.

## Cómo correr una evaluación

1. Abre una sesión nueva de un agente (Claude Code u otro harness ya configurado en este
   workspace) **sin darle contexto adicional** más allá de lo que ya tiene acceso en el repo —
   el objetivo es medir si la base de conocimiento es suficiente por sí sola, no si el agente
   recuerda una conversación anterior.
2. Pásale las 10 preguntas de [`kb-quiz.md`](kb-quiz.md), una por una o todas juntas.
3. Para cada respuesta, compárala con [`kb-answer-key.md`](kb-answer-key.md) y clasifícala:
   - ✅ **correcta** — coincide en sustancia y cita la fuente correcta (o una equivalente).
   - ⚠️ **parcial** — sustancia correcta pero sin citar fuente, o le falta una parte.
   - ❌ **incorrecta** — contradice la clave de respuestas o inventa algo no verificable.
4. Registra el resultado en `00-meta/eval/runs/<fecha-AAAAMMDD>.md` (crea la carpeta `runs/` si no
   existe) con una tabla: pregunta, veredicto, nota breve, y qué modelo/harness la ejecutó.

Ejemplo de fila de evidencia:

```markdown
| Pregunta | Veredicto | Nota | Modelo/harness |
|---|---|---|---|
| Q04 | ✅ | Cita ADR-003 y AGENTS.md §4 correctamente | Claude Sonnet 5 / Claude Code |
```

## La única pieza automatizable sin invocar un LLM

`30-tools/scripts/Check-EvalFreshness.ps1` no juzga contenido — solo comprueba si existe algún
fichero reciente en `00-meta/eval/runs/`. Es informativo (`WARN`), nunca bloqueante: hoy no hay
ninguna corrida registrada, así que un check bloqueante rompería el estado verde del repo nada
más crearlo. Sirve para acordarse de repetir el protocolo periódicamente, no para sustituirlo.
