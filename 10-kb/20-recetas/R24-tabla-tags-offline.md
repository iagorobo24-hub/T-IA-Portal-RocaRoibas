# R24 — Tabla de tags PLC vacía (offline)

## Objetivo

Crear, inspeccionar, exportar, guardar, borrar y leer de nuevo una tabla de tags PLC
vacía en un fixture V20. La receta valida el objeto de ingeniería y sus límites sin
crear tags, tocar Safety, conectar una CPU ni ejecutar force.

**Riesgo:** R2 (mutación reversible en fixture).  
**Servidor:** `tia-inspect` V20 con `--isolated --fixture-root <run-dir> --allow-write`.  
**Evidencia aceptada:** `mcp-tagtable-acceptance-20260923.json`.

## Alcance

Solo se prueba una tabla de usuario sin tags ni constantes. La importación XML de tablas
no pertenece a esta receta: no está expuesta en el roster `tia-inspect/write`; requiere
una prueba separada con `tia-create/full`, preflight equivalente y un fixture nuevo.

## Precondiciones

1. Ejecuta `Doctor` y detente si falta el grupo `Siemens TIA Openness`.
2. Usa un manifiesto `.tia-agent-fixture.json` que señale el `.ap20` y backup exactos;
   compara sus SHA-256 antes de abrir.
3. Ejecuta `Connect`, `OpenProject`, `GetProjectTree` y `GetSoftwareTree`; usa el
   `softwarePath` real devuelto. En el fixture aceptado fue `PLC_1`.
4. Lee `GetBlocks` y `GetTags`. Todos los bloques deben ser estándar, no protegidos y
   consistentes; todos los tags deben tener `isSafety=false`. Una propiedad ausente o
   nula bloquea la mutación.
5. Filtra `GetTagTables` por el nombre único de prueba y exige cero coincidencias.
   No uses ni borres `Default tag table`.

## Herramientas y firmas

| Acción | Herramienta y parámetros |
|---|---|
| Crear | `CreateTagTable(softwarePath, groupPath="", name)` |
| Listar | `GetTagTables(softwarePath, regexName)` |
| Inspeccionar | `GetTagTableInfo(softwarePath, tagTablePath)` |
| Exportar | `ExportTagTable(softwarePath, tagTablePath, exportPath, preservePath=false)` |
| Compilar | `CompileSoftware(softwarePath, password="")` |
| Guardar | `SaveProject()` separado de la mutación |
| Borrar | `DeleteTagTable(softwarePath, tagTablePath)` |

El `tagTablePath` debe ser el path devuelto por `GetTagTables`. El nombre del grupo no
se inventa desde la interfaz visual.

## Secuencia

1. Haz el preflight anterior y confirma destino ausente.
2. Crea la tabla en la raíz con `groupPath=""`.
3. Vuelve a listar y exige una tabla `kind="Tag table"`, `isDefault=false`, path exacto,
   `tagCount=0` y `userConstantCount=0`.
4. Lee `GetTagTableInfo` con ese path y conserva la respuesta.
5. Exporta a una carpeta de evidencia. Exige un XML no vacío y recalcula su SHA-256.
6. Compila con `Success`, 0 errores y 0 avisos; guarda en una llamada independiente.
7. Lee la tabla una vez más y borra con `DeleteTagTable` usando el path leído.
8. Lista y exige cero coincidencias; compila y guarda de nuevo con 0/0.
9. Abre una segunda sesión sin `--allow-write`, lee `GetState` y `GetTagTables` y exige
   `allowWrite=false` y cero tablas de prueba.
10. Restaura el `.ap20` desde el backup y comprueba igualdad de hash con el proyecto
    inicial y con el proyecto fuente.

## Paradas y recuperación

- Safety, know-how protection, tabla por defecto, path ambiguo, metadata nula o error de
  protección: no reintentes; restaura y documenta.
- Si falla crear/exportar/compilar/guardar/borrar, detén la secuencia. No llames a la
  siguiente mutación y conserva el error tipado.
- Si queda un proceso Openness, verifica PID, padre y argumentos y termina únicamente el
  proceso aislado `Openness.Loader.BootStrap`; nunca la ventana TIA del usuario.
- Esta aceptación no demuestra tags, importación, direcciones, Safety, runtime ni
  comportamiento de máquina.
