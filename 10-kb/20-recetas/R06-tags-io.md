# R06 — Crear tablas de tags desde una lista de E/S

## Objetivo

Convertir una lista de E/S revisada en una tabla de tags simbólica, conservando tipo, dirección y
comentario, sin escribir sobre la `Default tag table` por defecto.

## Secuencia

### Proyecto nuevo

Incluir en `ScaffoldProject` una entrada `tagTable` con `tableName` y `tags`; cada tag debe tener
`name`, `dataTypeName` y `logicalAddress`. Ejecutar `dryRun=true`, revisar duplicados y rangos, y
solo después `dryRun=false`.

### Proyecto existente

1. Doctor → Connect → GetProjectTree → GetSoftwareTree(sections=`tags`).
2. Leer `GetPlcTagTables`/`GetTags` y comprobar que la tabla destino y sus tags no colisionan.
3. Hacer backup del `.ap20` y repetir la preflight global: todos los bloques deben declarar
   `isFailsafe=false`, todos los tags `isSafety=false` y ningún bloque debe estar protegido por
   know-how. Si falta una propiedad o devuelve `null`, detenerse.
4. Usar `CreateTagTable` + `CreateTag` para cambios pequeños. En V20, el perfil aislado write
   probado no registra `ImportTagTable` ni importadores equivalentes; no se debe sustituir ese
   bloqueo por un `CallTool` genérico. Solo se podrá importar cuando `tools/list`/`FindTools`
   exponga una herramienta acotada y exista preview, conteo, compilación y readback.
5. Compilar con 0 errores y 0 avisos, leer de nuevo cada tag, guardar y exportar. `SaveProject`
   debe ejecutarse fuera de la transacción Openness; el runner lo hace mediante `SaveGuarded` y
   conserva la barrera F/Safety.

### Ciclo probado en fixture V20

En `AgentDemo_V20` desechable se verificó `CreateTag` → `GetTagInfo/GetTags` → `UpdateTag`
(renombre y dirección) → `ExportTagTable` → `CompileSoftware` 0/0 → `SaveProject` → `DeleteTag`
→ compile/save → readback independiente sin el tag y export restaurado. La evidencia es
[mcp-tag-lifecycle-20260922-save-boundary.json](../../70-runs/e2e/mcp-tag-lifecycle-20260922-save-boundary.json).
El primer guardado falló correctamente al detectar que `Project.Save` estaba dentro de una
transacción; la corrección `SaveGuarded` y su prueba están en
[Test-TiaMcpSaveBoundary.ps1](../../30-tools/tests/Test-TiaMcpSaveBoundary.ps1).

## Verificación

R15 genera la documentación de salida a partir de la lectura detallada. Un contador de tags o el
texto de `GetSoftwareTree` no basta para demostrar que la dirección física es correcta.
