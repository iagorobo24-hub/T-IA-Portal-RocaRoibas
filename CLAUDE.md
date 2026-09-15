# CLAUDE.md

El contrato completo de este workspace está en **[AGENTS.md](AGENTS.md)**. Léelo entero antes de
tocar nada.

Resumen de lo que no se negocia:

- **Nunca** descargues a un PLC físico sin confirmación explícita del usuario en ese momento.
  PLCSIM sí, libre.
- **Nunca** inventes una ruta de Openness: sale de `GetProjectTree` o no existe.
- **Nunca** escribas LAD a mano. SCL para lógica, LAD solo desde recetas.
- Backup antes de escribir. Compila con 0 errores antes de guardar. Exporta a `src/` y commitea.
