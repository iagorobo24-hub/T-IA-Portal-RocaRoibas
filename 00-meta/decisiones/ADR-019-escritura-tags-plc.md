# ADR-019 — Contrato para escritura de tags PLC

> Estado: **implementado y verificado con arnés mock; E2E live pendiente** · Fecha: 2026-10-29 · Ámbito: TIA Portal V20, Openness, `tia-inspect --isolated --allow-write` y `tia-create`

## Contexto

La FASE 4 del plan pide escritura de tags. La auditoría de rosters (FASE 4.1) confirma que las
herramientas existen, pero no hay runner ni E2E. Este ADR fija el contrato **antes** de escribir
código, para que la implementación no invente gates ni elija la herramienta por comodidad.

Evidencia de roster:

| Servidor | Perfil | Herramientas de tags |
|---|---|---|
| `tia-create` | lite (55 tools) | `GetPlcTagTables`, `ImportPlcTagTable(softwarePath, folderPath, importPath)` |
| `tia-inspect` | write (84 tools) | `GetTags`, `GetTagInfo`, `GetTagTables`, `GetTagTableInfo`, `CreateTag`, `UpdateTag`, `DeleteTag`, `CreateTagTable`, `RenameTagTable`, `DeleteTagTable`, `ExportTagTable` |

Ficheros: `70-runs/acceptance/plcsim-tia-attach-capability-20260924.json` y
`70-runs/acceptance/plcsim-inspect-write-tools-20260925.json`.

## Decisión

### 1. Herramienta por tipo de cambio

| Cambio | Herramienta | Motivo |
|---|---|---|
| Un tag: alta, rename, tipo, dirección, flags HMI/OPC UA | `UpdateTag` / `CreateTag` / `DeleteTag` (`tia-inspect`) | Granular; permite leer de vuelta el objeto exacto con `GetTagInfo` |
| Tabla completa desde XML | `ImportPlcTagTable` (`tia-create`) | Solo para import masivo; no se usa para un cambio mínimo |

**Un cambio mínimo nunca usa `ImportPlcTagTable`.** Importar una tabla entera puede reemplazar tags
que el usuario no pidió tocar y el contrato de recuento de esa herramienta no está verificado.

### 2. Ruta de ejecución

- **Ruta elegida:** `tia-inspect --isolated --fixture-root <run-dir> --allow-write` sobre un fixture
  con manifiesto válido. Es la misma ruta que ya exige backup, lectura previa y compilación.
- **No se usa** la ruta adjunta (`AttachToOpenProject`) para tags en la primera implementación: no
  hay evidencia live de `CreateTag`/`UpdateTag` sobre el proyecto abierto, y la ruta aislada ya
  tiene el contrato de manifiesto.

### 3. Contrato de propuesta (JSON)

La propuesta de tags debe ser un fichero versionable, no una llamada suelta:

```json
{
  "schemaVersion": 1,
  "status": "PROPOSED",
  "readOnly": true,
  "applied": false,
  "tiaMutation": false,
  "projectPath": "C:/.../fixture.ap20",
  "plc": "PLC_1",
  "tagTable": { "path": "Cinta_Signals", "name": "Cinta_Signals" },
  "operation": "update",
  "target": {
    "path": "Cinta_Signals/Cmd_Enable",
    "name": "Cmd_Enable",
    "before": { "dataTypeName": "Bool", "logicalAddress": "%I0.0" }
  },
  "after": { "dataTypeName": "Bool", "logicalAddress": "%I0.1" },
  "checks": { "exactTable": true, "exactTag": true, "noBlockingFindings": true },
  "findings": []
}
```

`operation` ∈ `create | update | delete`. `before` es obligatorio en `update` y `delete`: sin lectura
previa no se escribe.

### 4. Gates obligatorios, en este orden

1. **Fixture:** manifiesto válido y snapshot sin cambios (`Assert-TiaFixtureManifest`).
2. **Proyecto:** `projectPath` de la propuesta == `.ap20` del manifiesto.
3. **Inventario completo:** `GetTags` con `meta.success=true`, `complete=true`, `count` coherente,
   **todos** los tags con `isSafety` booleano y **ninguno** Safety. Es el mismo veto global que ya
   aplica `Invoke-TiaSclProposalApply`; un tag Safety bloquea la propuesta entera.
4. **Tabla exacta:** `GetTagTables` debe listar la tabla objetivo; si no, `BLOCKED`.
5. **Tag exacto:** en `update`/`delete`, `GetTagInfo` debe devolver el tag y coincidir con `before`.
   En `create`, `GetTagInfo` debe fallar con "no existe"; si existe, `BLOCKED` (no se sobrescribe).
6. **Backup:** `ExportTagTable` de la tabla completa a `run/backup/` antes de mutar.
7. **Mutación única:** exactamente una llamada a `CreateTag`, `UpdateTag` o `DeleteTag`.
8. **Readback:** `GetTagInfo` del tag objetivo debe coincidir con `after` (o confirmar ausencia en
   `delete`). Si no coincide, `APPLIED_CONTENT_MISMATCH` y **no** se guarda.
9. **Compilación:** `CompileSoftware` con 0 errores y 0 avisos.
10. **Guardado:** `SaveProject` solo tras 8 y 9.
11. **Export:** `ExportTagTable` posterior a `src/tags/` para que el cambio sea visible en git.

### 5. Estados del runner

`PREVIEW` (sin TIA), `BLOCKED` (gate previo), `APPLIED_AND_VERIFIED`, `APPLIED_CONTENT_MISMATCH`
(mutado, sin guardar), `FAILED` (mutado, compile roto, sin guardar). Los tres últimos son exit 1.

### 6. Prohibiciones explícitas

- No `ImportPlcTagTable` para un cambio de un tag.
- No escritura si `GetTags` no clasifica Safety o si `GetTagInfo` no está disponible.
- No escritura sobre la tabla por defecto (`IsDefault`) si la operación la borra o renombra.
- No tags Safety, no hardware, no online, no descarga.
- No se presenta `PREVIEW` como cambio aplicado.

## Consecuencias

- La implementación puede construirse y probarse **enteramente con mocks** antes de tocar TIA:
  el contrato de propuesta, los gates y los estados son deterministas.
- El E2E real exige un fixture desechable con al menos una tabla de tags no default y TIA abierto
  en modo aislado; no se puede hacer en una sesión sin TIA.
- Si `GetTagInfo` no existe en un build futuro, la ruta queda `BLOCKED` por diseño, no degradada.

## Implementación (2026-10-29)

- Runner: `30-tools/scripts/Invoke-TiaTagProposalApply.ps1`.
- Gates reutilizables: `Assert-TiaTagApplyCapability`, `Assert-TiaTagTableInventoryReadable`,
  `Assert-TiaTagTableInfoMatches` y `Assert-TiaTagMatchesExpected` en `TiaSclSafety.ps1`.
- Arnés: `30-tools/tests/Test-TiaTagProposalApply.ps1` (**69 aserciones PASS**, sin TIA).
- Estados añadidos al contrato original: `APPLIED_EXPORT_FAILED` (guardado sin export) y
  `APPLIED_VERIFICATION_FAILED` (guardado, pero el readback post-guardado no coincide).
- El runner exige además un **readback post-guardado** en un proceso nuevo que reabre el `.ap20`
  y comprueba que el directorio del proyecto cambió respecto al snapshot del manifiesto. Esto
  prueba persistencia, no solo el estado en memoria.
- `update` sin ningún campo distinto de `before` se bloquea en validación local (no-op).

### Enmienda a la puerta de tabla exacta (gate 4)

La evidencia del 2026-09-23 (`70-runs/e2e/mcp-tagtable-lifecycle-20260923-1600.json`) muestra que
`GetTagTables` devolvió `items=[]`, `totalTagTables=0` en una sesión en la que `GetTags` ya leía dos
tags de la tabla `Agent_Signals` y `GetSoftwareTree` listaba esa tabla. La enumeración no es una
prueba fiable de existencia en ese build.

Por eso la implementación mantiene el gate 4 pero lo hace con dos comprobaciones:

1. `GetTagTables` debe responder `meta.success=true` y `meta.totalTagTables` coherente con `items`
   (fail-closed si el inventario de tablas es incoherente).
2. La existencia y la ruta exacta de la tabla se prueban con `GetTagTableInfo`, que hace una
   búsqueda directa por `tagTablePath` y devuelve `path`, `name` e `isDefault`.

Si `GetTagTables` no enumera la tabla pero `GetTagTableInfo` la confirma, el informe registra
`table.listedInGetTagTables=false` y una nota; no se bloquea. No es una relajación de seguridad:
la mutación sigue apuntando a una ruta exacta que Openness confirma, y una tabla inexistente
bloquea en `GetTagTableInfo`. El E2E de FASE 4.3 debe confirmar si la enumeración sigue vacía.

## Lo que no se ha verificado

- Que `UpdateTag` cambie realmente la dirección lógica y se refleje en `GetTagInfo` en V20.
- Que `CreateTag` cree el tag con el tipo por defecto correcto cuando `dataTypeName` va vacío.
- El efecto de `UpdateTag` en los enlaces de HMI/OPC UA (`externalAccessible`, `externalVisible`,
  `externalWritable`).
- Que `CompileSoftware` detecte un cambio de dirección incompatible con el programa.

Estos puntos se cierran en el E2E de FASE 4.3, no antes.
