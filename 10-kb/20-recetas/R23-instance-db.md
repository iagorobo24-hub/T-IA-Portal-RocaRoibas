# R23 — Instance DB de un FB estándar (offline)

## Objetivo

Crear, compilar, exportar, guardar, borrar y leer de nuevo una Instance DB asociada a
un FB estándar en un fixture desechable de TIA Portal V20. La receta comprueba el ciclo
de ingeniería offline y conserva evidencia independiente. No descarga, no conecta con
una CPU y no escribe valores online.

**Riesgo:** R2 (mutación reversible en fixture).  
**Servidor:** `tia-inspect` V20 con `--isolated --fixture-root <run-dir> --allow-write`.  
**Timeout observado:** usar al menos 120 s; `Connect` puede superar 30 s al crear la
instancia Openness.

## Resultado de la prueba V20

El ciclo se verificó en `mcp-instancedb-acceptance-20260923.json`:

`CreateInstanceDB → GetBlockInfo → CompileSoftware 0/0 → ExportBlock → SaveProject →
GetCrossReferences → DeleteBlock → CompileSoftware 0/0 → SaveProject → segunda sesión`

La ruta aceptada usó `autoNumber=false` y el número libre `2`. El nuevo objeto empezó
con `isConsistent=false`; solo se exportó después de compilar y leer
`isConsistent=true`. El XML exportado mide 2884 bytes. El proyecto se restauró al hash
original `1F7A19A7537E209633D165503F853F930BA2C21A7ACAD06EB07AA4E44131B526`.

## Hallazgo obligatorio sobre `autoNumber`

En esta versión del wrapper, `autoNumber=true` con el valor por defecto `number=0`
creó una DB0 inválida. `CompileSoftware` devolvió:

`The block ... DB has an invalid number 0`

El fixture de esa prueba no se guardó y volvió al hash del backup. Hasta que exista una
prueba que demuestre que el wrapper asigna un número válido, **no uses** la ruta automática:
lee los bloques existentes, elige un número libre y llama con `autoNumber=false` y ese
número explícito. Si el número está ocupado, detente y elige otro; no sobrescribas un
bloque existente.

## Alcance y exclusiones

Esta receta cubre una Instance DB de un FB estándar SCL. No autoriza crear DB globales,
multiinstancia, UDT, F-blocks, DB de Safety, ni editar tags Safety. No usa importadores de
fuentes, `GoOnline`, descarga, monitorización ni force. La exportación XML es evidencia de
ingeniería; no es una prueba de comportamiento de máquina.

## Precondiciones

1. Ejecuta `Doctor`. Si el grupo `Siemens TIA Openness` no es verdadero, detente.
2. Usa únicamente un fixture con `.tia-agent-fixture.json`, `.ap20` exacto y backup
   coincidente. Comprueba el SHA-256 inicial del proyecto y del backup.
3. Conecta y abre el proyecto. Lee `GetProjectTree` y `GetSoftwareTree`; usa solo los
   paths devueltos. En el fixture de referencia el software es `PLC_1` y el FB es
   `FB_AgentDemo`.
4. Ejecuta `GetBlocks`, `GetTags` y `GetTypes` antes de mutar. Cada bloque debe exponer
   `isFailsafe=false`, `isKnowHowProtected=false`, `isConsistent=true`; cada tag debe
   exponer `isSafety=false`. Una propiedad ausente o nula bloquea la secuencia.
5. Lee `GetBlockInfo` del FB elegido y exige `programmingLanguage=SCL`,
   `isFailsafe=false`, `isKnowHowProtected=false`. Si el FB es F/Safety, está protegido
   o no se puede clasificar, restaura y detente.
6. Filtra `GetBlocks` por el nombre de prueba y exige cero coincidencias. Calcula un
   número DB libre; no infieras que `0` es válido.

## Herramientas y firmas

| Acción | Herramienta y parámetros |
|---|---|
| Crear | `CreateInstanceDB(softwarePath, groupPath, name, instanceOfName, autoNumber=false, number=<libre>)` |
| Leer lista | `GetBlocks(softwarePath, regexName)` |
| Leer metadata | `GetBlockInfo(softwarePath, blockPath)` |
| Referencias | `GetCrossReferences(softwarePath, objectPath, objectKind="block", filter="AllObjects", maxDepth=3)` |
| Compilar | `CompileSoftware(softwarePath, password="")` |
| Exportar | `ExportBlock(softwarePath, blockPath, exportPath, preservePath=false)` |
| Guardar | `SaveProject()` en una llamada separada de la mutación |
| Borrar | `DeleteBlock(softwarePath, blockPath)` |

El `blockPath` usado para exportar, borrar o leer debe ser el path exacto devuelto por
`GetBlocks`; no inventes rutas de grupos.

## Secuencia ejecutable

1. `Connect`, `OpenProject`, `GetState`, `GetProjectTree` y `GetSoftwareTree`.
2. Ejecuta el preflight de bloques, tags, tipos y FB descrito arriba.
3. Comprueba que la Instance DB de prueba no existe y registra el número libre.
4. Llama `CreateInstanceDB` con `autoNumber=false` y `number=<libre>`.
5. Lee la DB recién creada. Exige `typeName=InstanceDB`, `programmingLanguage=DB`,
   `isFailsafe=false` e `isKnowHowProtected=false`. Es normal que
   `isConsistent=false` antes de compilar; no exportes ni guardes todavía.
6. Ejecuta `CompileSoftware`. Exige `state=Success`, `errorCount=0` y
   `warningCount=0`. Vuelve a leer la DB y exige `isConsistent=true`. Si la compilación
   falla, conserva el diagnóstico, no llames `ExportBlock` ni `SaveProject`, y restaura.
7. Exporta la DB a una carpeta de evidencia del fixture. Exige un XML no vacío, conserva
   el SHA-256 y comprueba que el nombre coincide.
8. Llama `SaveProject` por separado. La lectura posterior debe confirmar el número,
   tipo, lenguaje y consistencia.
9. Ejecuta `GetCrossReferences` sobre la DB con `objectKind=block` y guarda las
   referencias a su FB y a sus miembros.
10. En una sesión aislada de borrado, vuelve a leer el path exacto y ejecuta
    `DeleteBlock`. Lista el nombre y exige cero coincidencias.
11. Compila y guarda después del borrado, ambos con 0 errores y 0 advertencias.
12. En una tercera sesión independiente de solo lectura, abre el mismo proyecto y exige
    cero coincidencias del nombre. Finaliza con `Disconnect`.
13. Copia el `.ap20` del backup sobre `project` y verifica que el hash coincide con el
    inicial; comprueba que el proyecto fuente no cambió.

## Evidencia mínima

Guarda en `70-runs/e2e/`:

- roster y argumentos del servidor, manifiesto y hashes del fixture;
- árboles, bloques, tags, tipos y preflight F/Safety;
- respuestas de creación, metadata antes/después de compilar, compilaciones y guardados;
- XML exportado y su SHA-256;
- referencias cruzadas y borrado;
- lectura independiente con cero coincidencias;
- informe resumido con veredicto y limitaciones.

La ejecución aceptada está en
[`mcp-instancedb-acceptance-20260923.json`](../../70-runs/e2e/mcp-instancedb-acceptance-20260923.json).
Los informes de sesión son `mcp-instancedb-create-20260923-1630.json`,
`mcp-instancedb-delete-20260923-1630.json` y
`mcp-instancedb-independent-read-20260923-1630.json`. El fallo de asignación automática
está documentado en `mcp-instancedb-create-20260923-1600.json`.

## Recuperación y parada

- Si aparece Safety, know-how protection, metadata nula, número ocupado o error de
  protección, no reintentes: restaura e informa.
- Si falla la compilación, no exportes ni guardes. Conserva el mensaje y descarta el
  proceso aislado.
- Si falla una mutación después de crear la DB, no continúes con la siguiente llamada;
  cierra la sesión y restaura desde el backup.
- Si queda un proceso Openness, verifica PID, padre y argumentos; termina únicamente el
  proceso aislado con `Openness.Loader.BootStrap`. Nunca termines la instancia TIA visible.
- No presentes una respuesta de creación ni una exportación local como prueba online o
  de funcionamiento de la máquina.
