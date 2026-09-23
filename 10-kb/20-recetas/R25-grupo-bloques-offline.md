# R25 — Grupo vacío de bloques PLC (offline)

## Objetivo

Crear y borrar un grupo vacío bajo `Program blocks` en un fixture V20, verificando el
árbol antes y después, compilación, guardado, lectura independiente y restauración.
No crea bloques dentro, no mueve lógica y no toca hardware, Safety ni una CPU.

**Riesgo:** R2 (mutación reversible en fixture).  
**Servidor:** `tia-inspect` V20 con `--isolated --fixture-root <run-dir> --allow-write`.  
**Evidencia:** `mcp-blockgroup-acceptance-20260923.json`.

## Precondiciones

1. `Doctor` debe confirmar V20 y el grupo `Siemens TIA Openness`.
2. El manifiesto del fixture debe señalar el `.ap20` y backup exactos; compara SHA-256.
3. Ejecuta `Connect`, `OpenProject`, `GetProjectTree` y `GetSoftwareTree`; el softwarePath
   debe salir del árbol (`PLC_1` en el fixture aceptado).
4. Ejecuta `GetBlocks` y `GetTags`: todos los bloques estándar, no protegidos y consistentes;
   todos los tags `isSafety=false`. Si falta una propiedad o aparece Safety, detente.
5. Filtra el nombre único con `GetSoftwareTree`/`GetBlocks` y exige que el grupo no exista.

## Herramientas y firmas

| Acción | Herramienta y parámetros |
|---|---|
| Crear | `CreateBlockGroup(softwarePath, parentGroupPath="", name)` |
| Verificar | `GetSoftwareTree(softwarePath, sections="blocks")` |
| Borrar | `DeleteBlockGroup(softwarePath, groupPath)` |
| Compilar | `CompileSoftware(softwarePath, password="")` |
| Guardar | `SaveProject()` separado de las mutaciones |

El `groupPath` de borrado es el path devuelto por la respuesta de creación y visible en
el árbol. El grupo del sistema `Program blocks` no se puede borrar.

## Secuencia

1. Registra preflight, hash y árbol inicial.
2. Crea el grupo en raíz (`parentGroupPath=""`).
3. Lee el árbol y exige que el grupo aparezca debajo de `Program blocks`.
4. Borra el grupo con el path exacto; vuelve a leer el árbol y exige que no aparezca.
5. Compila con 0 errores y 0 avisos y llama `SaveProject`.
6. En una sesión independiente sin `--allow-write`, lee `GetState`, `GetSoftwareTree`
   y `GetBlocks`; exige `allowWrite=false`, grupo ausente y cero coincidencias.
7. Restaura desde `backup` y comprueba igualdad de hash del proyecto y de la fuente.

## Recuperación

- Si hay protección, Safety, path ambiguo o fallo de mutación, no reintentes la siguiente
  llamada: conserva el error y restaura.
- Un grupo con bloques dentro no se borra en esta receta; primero exporta y verifica
  referencias con una receta específica.
- Ante un proceso residual, identifica PID, padre y `Openness.Loader.BootStrap`; no cierres
  la instancia TIA visible del usuario.
