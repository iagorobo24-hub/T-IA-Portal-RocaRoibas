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
3. Hacer backup del `.ap20`.
4. Usar `CreateTagTable` + `CreateTag` para cambios pequeños, o `ImportPlcTagTable` para un XML
   preparado y revisado. No usar comodines ni una ruta inventada.
5. Compilar, verificar lectura posterior de cada tag, guardar y exportar.

## Verificación

R15 genera la documentación de salida a partir de la lectura detallada. Un contador de tags o el
texto de `GetSoftwareTree` no basta para demostrar que la dirección física es correcta.
