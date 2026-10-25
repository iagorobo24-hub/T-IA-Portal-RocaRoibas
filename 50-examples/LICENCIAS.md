# Licencias de ejemplos y recursos

Revisión de WP-21 (2026-10-25). Licencia según la API de GitHub de cada repositorio de origen
(solo lectura) y según los ficheros presentes en este repositorio. No es asesoramiento legal.

## Contenido versionado en este repositorio

| Carpeta | Origen | Licencia | Decisión |
|---|---|---|---|
| `60-library/` | propio | MIT (`LICENSE`) | se queda |
| `50-examples/demo-cinta01/`, `50-examples/agent-demo/` | propio, generado por el agente con `ScaffoldProject` | MIT (`LICENSE`) | se queda |
| `50-examples/npatel-*/FICHA.md` (4) | notas propias sobre `npatel221/PLC_Projects` | el repo de origen **no declara licencia** | solo la ficha propia; el código y los binarios ya no se versionan |
| `50-examples/orsin-wincc-games/FICHA.md` | notas propias sobre `RobertOrsin/TIAPortalGames` | el repo de origen **no declara licencia** | igual que arriba |
| `50-examples/siemens-snippets/README.md` | notas propias sobre `siemens/tia-portal-openness-code-snippets` | licencia propia de Siemens (GitHub: «Other»), no MIT | solo el README; el código no se copia |
| `TIA-Claude_Portable/` | propio | MIT | se queda |

Las fichas citan nombres de proyectos y comentan su contenido; no reproducen el código. Una
ficha de un repositorio sin licencia es una nota crítica, no una redistribución.

## Terceros que se compilan o consultan (no se versionan)

| Proyecto | Licencia |
|---|---|
| `heilingbrunner/tiaportal-mcp` | MIT |
| `bulaofen0036-coder/TIA_Portal_Openness_MCP` | MIT |
| `Dego-Dantas/tia-integration-ai` | MIT |

## Pendiente (necesita a Iago)

1. **Historial público.** El commit `a7aba0a` retiró del índice el código y los binarios de
   `npatel-*` y `orsin-*`, pero siguen en el historial de git de un repositorio público.
   Reescribir el historial, o aceptar el riesgo, es decisión de Iago.
2. **ADR-005 dice otra cosa.** Afirma que los proyectos de npatel y Orsin «son MIT»; la API de GitHub no devuelve licencia para ninguno de los dos. Se ha seguido el dato de la API, que coincide con `NOTICE-THIRD-PARTY.md`. El ADR no se ha editado.
3. **Contenido de Roca.** Búsqueda de «roca» y «roibas» en los ficheros versionados: sin
   resultados. El único rastro es el nombre del repositorio remoto (`T-IA-Portal-RocaRoibas`).
   D-IAGO-08 sigue abierta; mientras tanto nada de Roca entra aquí.
4. **`10-kb/`.** No se ha revisado línea a línea si las recetas parafrasean en exceso los
   snippets de Siemens; esta revisión solo cubre ejemplos y recursos.
