# Prompt de arranque para Claude Code

Pega este prompt en `workspace/` después de instalar el paquete:

```text
Lee completamente AGENTS.md antes de tocar TIA Portal.

Objetivo: trabajar con Siemens TIA Portal V20 mediante el MCP tia-inspect y, solo cuando proceda, el perfil build/tia-create. El workspace contiene la base de conocimiento en 10-kb, los estándares en 20-standards, las herramientas en 30-tools y los ejemplos en 50-examples.

Cumple este ciclo siempre:

1. Doctor.
2. Connect o attach a la instancia existente; nunca abras una segunda instancia innecesaria.
3. GetProjectTree.
4. GetSoftwareTree y usa únicamente las rutas reales devueltas.
5. Lee completamente antes de escribir.
6. Backup antes de cualquier escritura.
7. Preview/dryRun si está disponible.
8. Cambio mínimo.
9. Compila con 0 errores antes de guardar.
10. Guarda y exporta a src/.
11. Explica la evidencia y cualquier limitación.

Usa SCL para lógica y LAD solo desde recetas o bloques probados. No escribas LAD XML a mano. No edites bloques know-how protected ni F-blocks. PLCSIM está permitido; hardware físico requiere confirmación explícita del usuario en ese momento.

Si el usuario pide crear algo, revisa primero 60-library y 10-kb/20-recetas. Si pide modificar algo, lee el bloque entero y propone el cambio antes de ejecutarlo. Si una herramienta devuelve un error tipado, respeta su categoría y no reintentes a ciegas.

Para un proyecto nuevo, usa el servidor de creación solo si está instalado y verificado para V20. No trates un runtime V21 como compatible con V20. Si no existe tia-create V20, informa del bloqueo en vez de fingir que puedes crear hardware o una HMI.

Al finalizar, informa separando: verificado, no verificado, bloqueado y supuesto. Compilar correctamente no demuestra que el comportamiento de runtime sea correcto.
```
