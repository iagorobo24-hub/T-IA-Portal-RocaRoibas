# R15 — Generar la lista de E/S

## Objetivo

Producir una lista revisable de entradas, salidas, memoria y tags simbólicas sin inventar señales
a partir de un contador o del texto resumido del árbol.

## Precondiciones

- Doctor y conexión MCP completados.
- `GetSoftwareTree` ha identificado las tablas de tags.
- Se han obtenido los detalles mediante `GetTags`, una exportación `ExportPlcTagTable`, o un
  inventario equivalente con `tagTables[].tags[]`. La herramienta disponible puede variar por
  servidor y perfil; consulta [ADR-013](../../00-meta/decisiones/ADR-013-evidencia-tags-por-exportacion.md).

## Secuencia

1. Ejecutar la secuencia de lectura: `Doctor` → `Connect` → `GetProjectTree` →
   `GetSoftwareTree(sections="tags")`.
2. Para cada tabla real, leer sus tags completas y conservar nombre, tipo, dirección y comentario.
   Si `ExportPlcTagTable` está oculto, usa `FindTools` → `CallTool` y después:

```powershell
.\30-tools\scripts\Convert-TiaTagTableExportToInventory.ps1 `
  -ExportPath ".\70-runs\...\tag-table.xml" `
  -OutputPath ".\70-runs\...\tag-inventory.json" `
  -SoftwarePath "<softwarePath real>"
```

3. Si partes de un inventario de bloques separado, combínalo con
   `Merge-TiaTagEvidenceIntoInventory.ps1`; el `softwarePath` debe identificar exactamente un PLC.
4. Guardar el resultado en un inventario `readOnly`.
5. Ejecutar:

```powershell
.\30-tools\scripts\New-TiaIoList.ps1 `
  -InventoryPath ".\70-runs\...\inventory.json" `
  -OutputPath ".\70-runs\documentation\io-list.json" `
  -Objective "Documentar las señales de la máquina"
```

## Verificación

El script genera JSON, CSV y Markdown, clasifica `%I` como entrada, `%Q` como salida y `%M` como
memoria. Las tags sin dirección se conservan como `Symbolic`; las direcciones desconocidas o
tipos ausentes quedan con `requiresReview=true`.

## Si falla

Si el inventario solo tiene `defaultTagCount` o `softwareTree`, el script se detiene. Eso es
intencionado: hay que volver a leer las tablas y tags; no se debe rellenar la lista a mano.
