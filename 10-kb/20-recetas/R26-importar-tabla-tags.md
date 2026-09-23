# R26 — Importar una tabla de tags PLC vacía (offline)

## Objetivo

Importar una tabla de tags PLC vacía desde XML V20 en un fixture desechable, comprobar
que TIA la crea, compilar y guardar el proyecto, leerla desde una sesión independiente
de solo lectura y restaurar la carpeta completa del proyecto. La receta prueba la
capacidad `ImportPlcTagTable` del perfil `tia-create/full`; no importa tags ni
constantes y no conecta con una CPU.

**Resultado:** **verificado** en TIA Portal V20 con `ImportPlcTagTable` y una tabla de
usuario vacía (`tagCount=0`, `userConstantCount=0`).

**Riesgo:** R2 (mutación reversible en fixture).  
**Servidor mutante:** `tia-create` V20, perfil `full`, con `ConnectIsolated`.  
**Servidor de preflight:** `tia-inspect` V20 aislado, con el fixture y el manifiesto
`.tia-agent-fixture.json`.  
**Evidencia:**
[`mcp-import-tagtable-acceptance-20260923.json`](../../70-runs/e2e/mcp-import-tagtable-acceptance-20260923.json).

## Alcance y exclusiones

La prueba importa solo el objeto `SW.Tags.PlcTagTable` que contiene un nombre. No
demuestra la importación de tags, constantes, direcciones, tipos, tablas HMI o tablas
con referencias Safety. No modifica hardware, F-blocks, tags Safety, force tables,
CPU, runtime, conexión online ni descarga.

El resultado de importación es una operación de ingeniería offline. `CompileSoftware`
con 0 errores y 0 avisos confirma la compilación del software, pero no demuestra el
comportamiento de una máquina.

## Clasificación por superficie

- **MCP:** capacidad `ImportPlcTagTable` verificada en `tia-create/full` V20 con un
  fixture aislado.
- **Siemens Openness:** el servidor la implementa sobre la importación de
  `PlcSoftware.TagTableGroup.TagTables` (con la opción `Override` preferida y un
  fallback reflejado), pero esta prueba no ejecuta una llamada .NET Openness directa;
  el estado verificado es el del wrapper MCP.
- **Computer Use:** no es necesario para esta receta. `ConnectIsolated` usa una
  instancia headless y no toca la ventana TIA visible.

## Precondiciones

1. Trabaja exclusivamente con un fixture desechable cuyo manifiesto señale el `.ap20`,
   su backup y el proyecto fuente. No apuntes a `40-projects/`, a un proyecto de
   cliente ni al original de `50-examples/`.
2. Registra un inventario de **toda** la carpeta `project` antes de abrirla: ruta
   relativa, tamaño y SHA-256 de cada archivo. Conserva también el inventario de
   `backup` y exige que coincidan. Incluye explícitamente
   `System/PEData.idx` y `System/PEData.plf`; TIA puede persistir el índice de la
   tabla fuera del `.ap20`.
3. Comprueba que el SHA-256 del `.ap20` del proyecto, el backup y el proyecto fuente
   coincide. La prueba aceptada usó
   `1F7A19A7537E209633D165503F853F930BA2C21A7ACAD06EB07AA4E44131B526`.
4. Ejecuta `Doctor` en ambos servidores. El grupo `Siemens TIA Openness` y las
   instalaciones V20 deben estar disponibles; si no, detente.
5. Haz un preflight independiente con `tia-inspect --isolated --fixture-root
   <run-dir> --allow-write` antes de importar:
   - `GetProjectTree` y `GetSoftwareTree` deben proporcionar el `softwarePath` real;
   - `GetBlocks` debe demostrar que todos los bloques son estándar, consistentes,
     `isFailsafe=false`, `isKnowHowProtected=false` y tienen lenguaje clasificado;
   - `GetTags` debe demostrar que todos los tags tienen `isSafety=false`;
   - `GetTagTables` debe demostrar que el nombre de prueba no existe y conservar la
     lista inicial;
   - una propiedad ausente o `null`, cualquier F-block, tag Safety, protección
     know-how o destino ambiguo bloquea la operación.
6. Genera un XML V20 nuevo y único para la prueba. Debe usar codificación UTF-8 y
   contener `Engineering version="V20"` y un único
   `SW.Tags.PlcTagTable/AttributeList/Name`, sin elementos de tag ni constantes.
   No reutilices el nombre de una tabla existente.

## Firma estricta de `tia-create/full`

La herramienta aceptada es:

```text
ImportPlcTagTable(
    softwarePath: string,
    folderPath: string,
    importPath: string
)
```

Para una tabla en la raíz, usa `folderPath=""`. No añadas `overwrite`, `dryRun`,
`sections` ni otros campos: el perfil `full` valida los argumentos estrictamente y
rechaza campos desconocidos. En particular, su firma de
`GetSoftwareTree` es únicamente `GetSoftwareTree(softwarePath: string)`; no pases el
campo `sections` que acepta otro perfil. El primer intento de la prueba fue detenido
por esta validación antes de importar; la repetición con la firma exacta continuó.

`ImportPlcTagTable` no publica `dryRun`. La preflight independiente y el backup de la
carpeta son por tanto obligatorios; un preview local del XML no es una aplicación ni
autoriza a saltar el preflight.

## Mapeo Openness observado en el servidor

La implementación V20 auditada resuelve `PlcSoftware.TagTableGroup`, localiza el
`TagTableGroup` de destino y accede a su colección `TagTables`. Para importar, el
helper del servidor busca primero `TagTables.Import(FileInfo, ImportOptions)` y lo
invoca con `ImportOptions.Override`; si ese overload no existe, intenta
`TagTables.Import(FileInfo)`. Antes de la llamada aplica `PrepareXmlForImport`, que
copia el XML si necesita ajustar la versión `<Engineering>` a la versión conectada o
añadir BOM UTF-8. La herramienta MCP devuelve éxito al terminar la importación y no
incluye conteo importado; por eso la receta exige `GetPlcTagTables`, compile, guardado
y una sesión de lectura independiente.

Este es un mapeo comprobado del código de `tia-create` V20. **La llamada directa a
Openness no se ejecutó fuera del servidor MCP**; no se presenta como aceptación de un
cliente propio ni como prueba de todos los overloads instalados en TIA. El servidor
usa reflexión para escoger el overload disponible.

## Secuencia ejecutable

### 1. Preflight y conexión aislada

1. En `tia-create/full`, llama `Bootstrap` y después `Doctor(fix=false)`.
2. En el servidor de preflight, ejecuta `Connect`, `OpenProject`,
   `GetProjectTree`, `GetSoftwareTree`, `GetBlocks`, `GetTags` y `GetTagTables`. Usa
   únicamente el `softwarePath` devuelto; en la evidencia fue `PLC_1`.
3. Exige todas las barreras de F/Safety anteriores y que la tabla de prueba esté
   ausente. Registra el inventario completo de la carpeta y el hash de origen.
4. Cierra la sesión de preflight sin escribir. En el perfil `full`, llama
   `ConnectIsolated`; no uses `Connect` contra una ventana TIA visible ni cierres un
   proyecto ajeno.
5. Llama `OpenProject(path=<.ap20 exacto>, closeForeignProject=false)`, `GetState`,
   `GetProjectTree`, `GetSoftwareTree(softwarePath="PLC_1")` y
   `GetPlcTagTables(softwarePath="PLC_1")`. Antes de mutar deben aparecer las dos
   tablas existentes del fixture y no la tabla de prueba.

### 2. Importación, compilación y guardado

6. Llama exactamente:

   ```text
   ImportPlcTagTable(
       softwarePath="PLC_1",
       folderPath="",
       importPath="<ruta absoluta al XML V20>"
   )
   ```

   Si la llamada falla, conserva el error tipado, no la repitas sin cambiar la causa,
   cierra la sesión y restaura la carpeta.
7. Vuelve a llamar `GetPlcTagTables`. Exige que aumente en una la cantidad, que la
   tabla tenga el nombre exacto y que la respuesta incluya el objeto importado.
8. Llama `CompileSoftware(softwarePath="PLC_1", password="")`. Exige
   `state="Success"`, `errorCount=0` y `warningCount=0`.
9. Llama `SaveProject` en una llamada separada. Vuelve a leer
   `GetPlcTagTables` y conserva el resultado. La evidencia aceptada mostró tres
   tablas después de guardar, incluida la nueva tabla vacía.
10. Cierra el proyecto y desconecta. Comprueba por PID, argumentos y proceso padre
    que no queda un `Openness.Loader.BootStrap` aislado; nunca termines la ventana TIA
    visible del usuario.

### 3. Lectura independiente y restauración completa

11. Abre una segunda sesión con `tia-inspect` **sin** `--allow-write`, ejecuta
    `Connect`, `OpenProject`, `GetState`, `GetSoftwareTree` y `GetTagTables`. Exige
    `allowWrite=false`, una coincidencia con el nombre de prueba,
    `isDefault=false`, `tagCount=0` y
    `userConstantCount=0`. Esta lectura independiente es la evidencia de persistencia
    después de `SaveProject`.
12. Desconecta y resuelve las rutas absolutas de `project` y `backup`; comprueba que
    ambas están dentro del `run-dir` desechable del manifiesto y que ninguna apunta a
    `40-projects/`, a `50-examples/` ni a una ruta de cliente. Restaura **la carpeta
    completa** `project` desde `backup`, con una copia espejo que elimine cualquier
    archivo adicional. No restaures solamente el `.ap20`: la prueba observó que la importación también cambió
    `System/PEData.idx` y `System/PEData.plf`, y que dejar esos sidecars conservaba
    visible la tabla importada.
13. Recalcula el inventario de la carpeta restaurada. Exige cero diferencias de
    archivos, igualdad de los hashes del `.ap20`, igualdad de los sidecars y hash
    inalterado del proyecto fuente.
14. En otra sesión `tia-inspect` read-only, vuelve a abrir el proyecto y exige que la
    tabla de prueba ya no exista. El resultado aceptado fue `probeTableCount=0` y
    `directoryFileDiffCountAfterRestore=0`.

## Evidencia mínima

Conserva en `70-runs/e2e/`:

- roster, argumentos y versión de `tia-create/full`;
- manifiesto del fixture, inventarios/hash de `project`, `backup` y fuente;
- preflight F/Safety independiente y lista inicial de tablas;
- XML de entrada y su codificación;
- llamadas exactas de `ImportPlcTagTable`, `GetPlcTagTables`, `CompileSoftware` y
  `SaveProject`;
- lectura independiente read-only con la tabla visible y metadata vacía;
- inventario completo, restauración y lectura read-only posterior sin la tabla;
- límites: tabla vacía, sin tags/constantes, sin hardware, Safety, online o runtime.

La evidencia V20 aceptada es:

- resumen y veredicto:
  [`mcp-import-tagtable-acceptance-20260923.json`](../../70-runs/e2e/mcp-import-tagtable-acceptance-20260923.json);
- preflight:
  `mcp-import-tagtable-preflight-20260923-1730.json`;
- aplicación `tia-create/full`:
  `mcp-import-tagtable-20260923-1730-retry.json`;
- lectura independiente:
  `mcp-import-tagtable-independent-read-20260923-1730.json`;
- lectura después de restaurar la carpeta:
  `mcp-import-tagtable-restored-read-20260923-1730.json`.

El veredicto registrado es
`VERIFIED_PLC_TAG_TABLE_IMPORT_COMPILE_SAVE_INDEPENDENT_READBACK_AND_DIRECTORY_RESTORE`.
La aceptación demuestra la importación de una tabla vacía en V20. No eleva a aceptadas
las importaciones de tablas con tags Safety, tablas HMI, importación masiva de
directorios ni las operaciones online.

## Recuperación y parada

- Si `Doctor`, la preflight F/Safety o el inventario inicial falla, no importes.
- Si aparece Safety, protección know-how, una propiedad nula, destino existente o
  argumento desconocido, detente y registra el motivo.
- Si falla importar, compilar o guardar, no llames a la siguiente mutación. Conserva
  la respuesta y restaura la carpeta completa desde el backup.
- Si la lectura independiente no confirma la tabla, no presentes `success=true` como
  persistencia; restaura y documenta el resultado.
- Si queda un proceso Openness, termina únicamente el proceso aislado identificado
  por `Openness.Loader.BootStrap`. Nunca cierres la instancia TIA visible.
- No uses la aceptación como autorización para importar una tabla con tags Safety ni
  para conectar o descargar a un PLC físico.
