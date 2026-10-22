# Skills del workspace — 30-tools/skills/

> Skills personalizadas del proyecto: **acciones compuestas** que activan varias recetas
> y el contrato del agente de una tacada. No cambian ninguna regla de [`AGENTS.md`](../../AGENTS.md):
> las compuertas (backup, preview, 0/0, evidencia, candado GUI) se aplican igual en cada skill.

## Cómo se ordenan

- `SKILL.md` con frontmatter `name` + `description`. La `description` es la que usa el
  harness para disparar esa descripcion debe contener las frases del usuario tal como las
  escribe.
- Estados de una skill: `BORRADOR` (estructura y disparadores) → `BORRADOR AVANZADO`
  (pasos verificados de punta a punta) → `ACTIVA` (ensayada en sesión real y notas de
  uso). Ninguna se promociona a `ACTIVA` sin el ensayo registrado en `70-runs/`.

## Matriz

| Skill | Estado | Fuente de Paths | Documento detalle |
|---|---|---|---|
| [tia-analyze-project](tia-analyze-project/SKILL.md) | BORRADOR | R04, ADR-015 | dossier con directrices del operario (checklist) |
| [tia-document-project](tia-document-project/SKILL.md) | BORRADOR | R04, R24, standards | README vivo del proyecto, mapa de calls, señales |
| [tia-scl-worksession](tia-scl-worksession/SKILL.md) | BORRADOR MUTANTE | AGENTS §6, warehouse proposals | ciclo backup→compila→guarda→exporta→commit |
| [tia-hmi-screen](tia-hmi-screen/SKILL.md) | BORRADOR MUTANTE | Inv TiaHmiScreen, R31, ADR-017 | pantallas desde JSON + contract 14/14 |
| [tia-plcsim-acceptance](tia-plcsim-acceptance/SKILL.md) | BORRADOR MUTANTE | R28, R31, ADR-015 | descarga + plan funcional + diálogo de certificado |
| [tia-create-project](tia-create-project/SKILL.md) | BORRADOR AVANZADO | R30, ADR-016 | proyecto completo desde un spec |
| [tia-error-triage](tia-error-triage/SKILL.md) | BORRADOR | 50-errores | triage guiado + hallazgos (documentar cualquiera) |
| [tia-gui-click](tia-gui-click/SKILL.md) | BORRADOR REFERENCIA | playbook GUI, candado | el nivel 2 de la GUI con hit-test y evidencia |

## Cómo se llevan a los harnesses

Las skills viven aquí y se exportan al harness correspondiente con
[`Sync-HarnessConfigs.ps1`](../scripts/Sync-HarnessConfigs.ps1) // de momento pendiente:
el script no copia `skills/` todavía — añadir el paso (o la variable de ruta al crear la
primera ACTIVA). Regla provisional: si el harness no carga la skill, el agente en su
lugar abre el `SKILL.md` y sigue sus pasos manual.

## Cómo se ensaya

1. Ejecutar la skill en una tarea real registrando pasos y evidencia.
2. Registrar el ensayo en `70-runs/<fecha>-<skill>/` (no versionado) y el resumen en la
   skill misma.
3. Promocionar solo cuando el estado de la skill cambie a `ACTIVA` con alegato mejor:
   pasar BORRADOR→ACTIVA en el mismo commit que el ensayo exitoso.
