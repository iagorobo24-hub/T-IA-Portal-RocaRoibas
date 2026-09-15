# Prompt único de arranque para Claude Code

Pega este prompt en la raíz del núcleo instalado, normalmente `C:\TIA-Claude`, después de ejecutar
`install\Install-CorePackage.ps1`. También sirve para cualquier otro agente que acepte instrucciones
de proyecto y MCP.

```text
Lee completamente `AGENTS.md` antes de tocar TIA Portal. Estás en la raíz del workspace instalado;
no inventes rutas ni copies rutas absolutas desde otro ordenador.

Objetivo: trabajar con Siemens TIA Portal V20 mediante MCP de forma reproducible, segura y trazable.
El conocimiento está en `10-kb/`, los estándares en `20-standards/`, las herramientas en `30-tools/`,
la librería probada en `60-library/` y los proyectos de trabajo en `40-projects/`. Los ejemplos
opcionales se copian aparte desde `TIA-Claude_Examples/50-examples/`.

Al comenzar una sesión:

1. Comprueba que existe `.mcp.json`; si falta, ejecuta
   `30-tools\\scripts\\Sync-HarnessConfigs.ps1 -WorkspaceRoot (Get-Location).Path -Profile read`.
2. Ejecuta Doctor y reporta literalmente si el grupo `Siemens TIA Openness` y las versiones de TIA
   están disponibles.
3. Usa la configuración `read` para entender el proyecto. No habilites escritura por iniciativa
   propia.
4. Si el usuario pide una mutación, explica antes el proyecto, los objetos y el efecto; solicita
   reconocimiento explícito para el perfil write/create/full en ese momento.

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
10. Guarda y exporta a `src/`.
11. Explica la evidencia y cualquier limitación.

Usa SCL para lógica y LAD solo desde recetas o bloques probados. No escribas LAD XML a mano. No
edites bloques know-how protected ni F-blocks. PLCSIM está permitido cuando el preflight lo declara
listo; hardware físico requiere confirmación explícita del usuario en ese momento. Si no puedes
distinguir un target real de uno virtual, trátalo como real y para.

Si el usuario pide crear algo, revisa primero `60-library/` y `10-kb/20-recetas/`. Si pide modificar
algo, lee el bloque entero y propone el cambio antes de ejecutarlo. Si una herramienta devuelve un
error tipado, respeta su categoría y no reintentes a ciegas.

La lista de herramientas de `tia-create lite` es parcial. Si necesitas una capacidad que no
aparece, usa `FindTools` y luego `CallTool` con la firma devuelta. Para una lista de E/S, si no
existe `GetTags`, exporta la tabla real con `ExportPlcTagTable` y normalízala con
`Convert-TiaTagTableExportToInventory.ps1`; combina inventarios con
`Merge-TiaTagEvidenceIntoInventory.ps1` solo con un `softwarePath` exacto.

Para cambios SCL usa primero `Invoke-TiaProjectAnalysis.ps1` y `New-TiaSclProposal.ps1`. Revisa
`proposal.json`, `proposal.diff` y sus hashes. El preview se ejecuta con
`Invoke-TiaWorkflow.ps1 -Workflow apply -Profile read`; no conecta con TIA. La aplicación real
solo se autoriza con `Invoke-TiaWorkflow.ps1 -Workflow apply -Profile write -Apply
-AcknowledgeWriteProfile`, usando el `.ap20` exacto de la propuesta. Nunca saltes el runner ni
edites directamente el fichero binario del proyecto. Si la fuente original cambió desde la
propuesta, regenera la propuesta.

Para un proyecto nuevo, ejecuta primero `ScaffoldProject` con `dryRun=true`. Usa `tia-create` solo
con el perfil create/full reconocido y verificado para V20. No trates un runtime V21 como compatible
con V20. Si el servidor no aparece en el manifest o el smoke test falla, informa del bloqueo en vez
de fingir que puedes crear hardware o una HMI.

Al finalizar, informa separando: verificado, no verificado, bloqueado y supuesto. Incluye los
informes/rutas de evidencia. Compilar correctamente no demuestra que el comportamiento de runtime
sea correcto. Nunca afirmes que una simulación HMI o un juego funciona si no se ha ejecutado con el
runtime compatible y se ha observado el resultado.
```
