# ADR-005 — Estrategia de versionado

- **Fecha:** 2026-09-14
- **Estado:** ✅ Aceptada
- **Pregunta origen:** TDD Q9 — respuesta: *workspace público + proyectos aparte*

## Decisión

**Dos ámbitos de versionado separados, con perímetros distintos.**

| Ámbito | Repo | Visibilidad | Contenido |
|---|---|---|---|
| **Workspace** | `TIA-Claude` | **público** | `00-meta/`, `10-kb/`, `20-standards/`, `30-tools/`, `50-examples/`, `60-library/`, `AGENTS.md` |
| **Proyectos** | uno por cliente, o uno común | **privado** | `40-projects/<cliente>-<maquina>/` |

`40-projects/` queda **fuera** del repo público. En el `.gitignore` del workspace, no como una
excepción que haya que recordar.

## Consecuencias

**A favor**
- El conocimiento y las herramientas son reutilizables y compartibles: es trabajo que sirve a
  más gente y no tiene nada confidencial dentro.
- El perímetro de lo confidencial es una carpeta entera, no un criterio que haya que aplicar
  fichero a fichero. Eso es mucho más difícil de romper por descuido.

**En contra y hay que vigilarlo**
- 🔴 **`60-library/` es la frontera peligrosa.** Cuando extraigas un bloque bueno de un proyecto
  de cliente a la librería, ese bloque pasa de privado a **público**. Regla dura, ya escrita en
  `AGENTS.md` §3.4: al promover un bloque a la librería hay que **anonimizar** nombres de
  cliente, de máquina y de producto, y el usuario tiene que aprobarlo explícitamente.
- 🔴 **`50-examples/` también.** Los proyectos de npatel y Orsin son MIT y de terceros: se
  documentan e indexan, pero **no se republican los binarios**. Enlace al original.
- Un secreto publicado no se retira: queda en el historial de git y en los forks. Ante la duda,
  privado.

## Regla operativa

> Antes de mover cualquier cosa de `40-projects/` a `60-library/` o a `10-kb/`:
> parar, decir qué se va a mover y qué hay que anonimizar, y esperar confirmación.
