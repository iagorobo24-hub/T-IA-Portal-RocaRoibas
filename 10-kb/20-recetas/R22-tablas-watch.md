# R22 — Tablas de monitorización PLC (offline)

## Objetivo

Crear, inspeccionar, exportar y borrar una tabla de monitorización PLC en un clon
desechable de TIA Portal V20. La receta valida el ciclo de ingeniería offline y deja
evidencia de lectura, compilación, guardado, exportación, lectura independiente y
restauración. No conecta con una CPU ni modifica valores online.

**Riesgo:** R2 (mutación reversible en fixture).  
**Servidor:** `tia-inspect` V20 con `--isolated --fixture-root <run-dir> --allow-write`.  
**Timeout de conexión observado:** usar al menos 120 s; en esta máquina `Connect` puede
tardar más de 30 s al arrancar la instancia Openness.

## Alcance y exclusiones

Esta receta cubre únicamente objetos `Watch` vacíos. No añade entradas, no lee valores
de una CPU, no escribe valores, no fuerza señales y no usa `GoOnline`,
`MonitorWatchTableLiveS7`, `ReadPlcWatchTableCurrentValuesReadOnly` ni
`SetWatchTableModifyValue`. La tabla de fuerza del sistema no se crea, renombra ni borra.

No es una prueba de comportamiento de máquina ni de comunicación con un PLC.

## Precondiciones

1. Ejecuta `Doctor`. Si falla el grupo `Siemens TIA Openness`, detente.
2. Trabaja solo con un fixture cuyo manifiesto `.tia-agent-fixture.json` señale el
   `.ap20` y su backup exactos. No apuntes a `40-projects/`, a un proyecto de cliente ni
   al original de `50-examples/`.
3. Comprueba que el hash inicial del proyecto coincide con el hash del backup.
4. Conecta y abre el path exacto del proyecto; después lee `GetProjectTree` y
   `GetSoftwareTree`. En el fixture de referencia el `softwarePath` es `PLC_1`.
5. Antes de cualquier mutación registra `GetBlocks` y `GetTags`:
   - todos los bloques deben tener `isFailsafe=false`, `isKnowHowProtected=false` y
     `isConsistent=true`;
   - todos los tags deben tener `isSafety=false`;
   - si una propiedad falta o es `null`, o aparece cualquier F-block/tag Safety, detente.
6. Lee `GetWatchTables` y confirma que el nombre de prueba no existe.

## Herramientas y firmas

| Acción | Herramienta y parámetros |
|---|---|
| Crear | `CreateWatchTable(softwarePath, groupPath, name)`; `groupPath=""` crea en la raíz de tablas Watch |
| Listar | `GetWatchTables(softwarePath, regexName="")` |
| Inspeccionar | `GetWatchTableInfo(softwarePath, watchTablePath)` |
| Exportar | `ExportWatchTable(softwarePath, watchTablePath, exportPath, preservePath=false)` |
| Compilar | `CompileSoftware(softwarePath)` |
| Guardar | `SaveProject()` en una llamada separada, fuera de la transacción de la mutación |
| Borrar | `DeleteWatchTable(softwarePath, watchTablePath)` |

El path devuelto por `GetWatchTables` es la única fuente válida para las llamadas que
reciben `watchTablePath`. No se debe inventar el nombre de un grupo del árbol del sistema
(`Watch and force tables` no forma parte del path raíz).

## Secuencia ejecutable

1. `Connect` y `OpenProject` con el `.ap20` exacto del fixture.
2. `GetState`, `GetProjectTree`, `GetSoftwareTree(PLC_1, blocks,types,tags,watch)`.
3. `GetBlocks(PLC_1)` y `GetTags(PLC_1)`; aplicar las barreras de seguridad anteriores.
4. `GetWatchTables(PLC_1, regexName="^CU_MCP_Watch_Probe_")`; exigir cero coincidencias.
5. `CreateWatchTable(PLC_1, "", "CU_MCP_Watch_Probe_<run>")`.
6. Volver a llamar `GetWatchTables`; exigir una tabla con `kind="Watch"`, path exacto,
   `isConsistent=true` y `entryCount=0`.
7. Llamar `GetWatchTableInfo` con ese path; exigir `entryCount=0` y `entries=[]`.
8. Exportar a una carpeta de evidencia dentro del fixture. Comprobar que existe un XML
   cuyo elemento `Name` coincide y conservar su SHA-256.
9. Ejecutar `CompileSoftware`; exigir `state="Success"`, `errorCount=0` y
   `warningCount=0`.
10. Ejecutar `SaveProject` por separado. La respuesta puede conservar
    `meta.pendingSave=true`; la persistencia se verifica mediante la segunda sesión y el
    hash, no por ese campo aislado.
11. Confirmar con `GetWatchTables` que la tabla sigue presente antes de borrarla.
12. `DeleteWatchTable` con el path leído; después listar de nuevo y exigir cero
    coincidencias. `GetSoftwareTree(PLC_1, "watch")` solo debe mostrar la Force table
    del sistema.
13. Compilar y guardar una segunda vez con 0/0.
14. `Disconnect`. Una llamada `CloseProject` puede probarse aparte, pero no debe ocultar
    el resultado de la secuencia si el cierre del objeto Openness no responde; registra el
    error y limpia solo el proceso aislado identificado por PID y argumentos.
15. Abre una segunda sesión independiente, repite `Connect`, `OpenProject`,
    `GetSoftwareTree(PLC_1, "watch")` y `GetWatchTables` filtrado; exige cero tablas y
    finaliza con `Disconnect`.
16. Restaura el directorio `project` desde `backup` y comprueba que el `.ap20` vuelve a
    tener exactamente el hash inicial. Comprueba también que el proyecto fuente no cambió.

## Evidencia mínima

Guarda en `70-runs/e2e/`:

- manifiesto y hash inicial del fixture;
- roster `tools/list`, árbol, bloques, tags y preflight F/Safety;
- respuestas de creación, lectura, metadata, exportación, compilación, guardado y borrado;
- XML exportado y su hash;
- lectura independiente con cero coincidencias;
- hashes antes de restaurar y después de restaurar;
- informe resumido con el veredicto y las limitaciones.

El ciclo V20 ejecutado el 2026-09-22 está documentado en
[`mcp-watch-acceptance-20260922.json`](../../70-runs/e2e/mcp-watch-acceptance-20260922.json),
con informes de sesión en `mcp-watch-lifecycle-20260922.json` y
`mcp-watch-independent-readback-20260922.json`.
El veredicto registrado es
`VERIFIED_WATCH_TABLE_CREATE_EXPORT_COMPILE_SAVE_DELETE_AND_INDEPENDENT_READBACK`.

## Recuperación y parada

- Si aparece Safety, know-how protection, clasificación nula, proyecto ambiguo o un
  error de protección, no reintentes: restaura el fixture e informa.
- Si una mutación falla, no ejecutes la siguiente. Conserva la respuesta tipada, cierra
  la sesión aislada y restaura desde el backup.
- Si queda un proceso Openness después de un timeout, verifica PID, padre y argumentos;
  termina únicamente el proceso aislado cuyo argumento contiene
  `Openness.Loader.BootStrap`. Nunca termines la instancia TIA visible del usuario.
- No presentes `dryRun`, una exportación local o una respuesta de creación como prueba de
  comportamiento online.
