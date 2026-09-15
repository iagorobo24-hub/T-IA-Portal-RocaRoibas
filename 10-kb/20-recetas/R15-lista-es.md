# R15 — Generar la lista de E/S

## Objetivo

Producir una lista revisable de entradas, salidas, memoria y tags simbólicas sin inventar señales
a partir de un contador o del texto resumido del árbol.

## Precondiciones

- Doctor y conexión MCP completados.
- `GetSoftwareTree` ha identificado las tablas de tags.
- Se han obtenido los detalles mediante `GetTagTables` y `GetTags`, o se dispone de un inventario
  equivalente con `tagTables[].tags[]`.

## Secuencia

1. Ejecutar la secuencia de lectura: `Doctor` → `Connect` → `GetProjectTree` →
   `GetSoftwareTree(sections="tags")`.
2. Para cada tabla real, leer sus tags completas y conservar nombre, tipo, dirección y comentario.
3. Guardar el resultado en un inventario `readOnly`.
4. Ejecutar:

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
