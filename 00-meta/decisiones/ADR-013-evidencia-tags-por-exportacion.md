# ADR-013 — Evidencia detallada de tags por exportación Openness

**Fecha:** 2026-09-15  
**Estado:** aceptada

## Contexto

La capacidad visible de los dos servidores no es idéntica a su documentación o a su roster
completo. En la instalación V20 comprobada:

- `tia-inspect` V0.1 devuelve el árbol, pero su binario no publica `GetPlcTagTables`.
- `tia-create` V2.7.2 en perfil `lite` publica `GetPlcTagTables`.
- `ExportPlcTagTable` existe en el roster completo de `tia-create`, pero se obtiene mediante
  `FindTools` y se ejecuta mediante `CallTool`; no debe suponerse que estará en `tools/list`.

## Decisión

Para documentar E/S se usa esta ruta compatible y solo de lectura:

```
Bootstrap → Connect → GetProjectTree → GetPlcTagTables
→ FindTools("export PLC tag table")
→ CallTool("ExportPlcTagTable", argumentos exactos)
→ Convert-TiaTagTableExportToInventory.ps1
→ New-TiaIoList.ps1
```

Si además se necesita análisis semántico, se combina el inventario detallado con el inventario
de bloques mediante `Merge-TiaTagEvidenceIntoInventory.ps1`, verificando el `softwarePath` exacto.
No se rellena una lista desde contadores, texto del árbol o nombres inferidos.

## Evidencia

La ruta se ejecutó sobre el ejemplo V20 `Sorting Plant Control_V20`: la tabla real `Sorting Plant
Tags` exportó 15 tags, que R15 clasificó como 5 entradas y 10 salidas, con 0 pendientes de
revisión. Los artefactos están en `70-runs/live-read/` y no se incorporan al paquete público.

## Consecuencias

- R15 no depende de que un servidor concreto implemente `GetTags`.
- Un harness puede descubrir herramientas ocultas con `FindTools` antes de declarar una capacidad
  ausente.
- Las rutas de exportación se guardan como evidencia local y se convierten a un esquema estable.
- El sistema conserva un bloqueo explícito cuando no puede resolver un único PLC o faltan campos.
