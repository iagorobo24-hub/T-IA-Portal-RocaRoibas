# V18-A — Inventario de lectura a nivel `Fixture` — 2026-09-22

Las **49 herramientas** del perfil `read` de `tia-inspect` V18, ejecutadas contra un `.ap18` real y
desechable. Ninguna quedó sin probar.

| | |
|---|---|
| Fixture | `35-runtime/v18/fixtures/isolated/` — CPU 1511-1 PN, compilado 0/0 |
| Contenido | 3 bloques (`Main` LAD, `FB_ScaleValue` SCL, `DB_PlantState` DB), 1 UDT, 4 tags, 2 constantes, 1 watch table, 1 force table, 3 fuentes externas |
| Perfil | `--tia-major-version 18 --isolated --fixture-root <root>`, **sin `--allow-write`** |
| Evidencia | `20-lote1.json` … `26-devices-fix.json` |

## Resultado

| Nivel | Antes de V18-A | Después |
|---|---|---|
| `Fixture` (ejecutado y releído) | 8 | **49 — todas** |
| `Esquema` (solo en `tools/list`) | 41 | **0** |
| Falla | 0 conocidas | **0** (5 fallaban; los dos bugs que lo causaban están corregidos) |

**Las 49 herramientas del perfil de lectura funcionan contra un proyecto `.ap18` real.**

## Las 49, por familia

### Sesión y proyecto — 8/8 ✅
`Doctor` · `GetState` · `Connect` · `Disconnect` · `OpenProject` · `OpenTiaProject` ·
`CloseProject` · `GetProject`*

### Árbol y lectura de objetos — 17/17 ✅
`GetProjectTree` · `GetSoftwareTree` · `GetSoftwareInfo` · `GetPlcSummary` · `GetBlocks` ·
`GetBlocksWithHierarchy` · `GetBlockInfo` · `GetBlockInterface` · `GetTypes` · `GetTypeInfo` ·
`GetTagTables` · `GetTagTableInfo` · `GetTags` · `GetTagInfo` · `GetConstants` ·
`GetWatchTables` · `GetWatchTableInfo` · `GetForceTables` · `GetExternalSources` ·
`GetExternalSourceInfo`

### Búsqueda y referencias — 4/4 ✅
`ResolveObjectPath` · `FindInCode` · `WhereUsed` · `GetCrossReferences`

`WhereUsed('UDT_MotorStatus')` devolvió que lo usa `DB_PlantState` en `%DB1`: referencias reales,
no listas vacías.

### Export y generación de fuentes — 12/12 ✅
`ExportBlock` · `ExportBlocks` · `ExportType` · `ExportTypes` · `ExportTagTable` ·
`ExportWatchTable` · `ExportPlcAsSourceTree` · `GenerateBlockSource` · `GenerateTypeSource` ·
`GenerateSources` · `GetBlockSource` · `GetTypeSource`

**16 ficheros producidos**, incluido el árbol textual completo:

```
gen/Bloques de programa/FB_ScaleValue.scl     ← SCL legible
gen/Bloques de programa/DB_PlantState.db      ← DB legible
gen/Tipos de datos PLC/UDT_MotorStatus.udt    ← UDT legible
tree/…                                        ← snapshot SimaticML del árbol
```

### Compilación — 1/1 ✅
`CompileSoftware` → `Success`, 0 errores, 0 avisos.

### Importación (preview) — 1/1 ✅
`PreviewImport` sobre el XML de `FB_ScaleValue` detectó `effect: "overwrite"` y
`note: "Already exists in the target"`. **Preview, sin mutar.**

### Dispositivos — 4/4 ✅
`GetDevices` · `GetDeviceInfo` · `GetDeviceItemInfo` · (y `GetProject`)

Estas cuatro **fallaban** al empezar, por el bug 2. Tras corregirlo devuelven datos reales:
`GetProject` da el nombre del proyecto con sus atributos (`Author`, `Copyright`…), `GetDevices` y
`GetDeviceInfo` dan `PLC_1` con los suyos, y `GetDeviceItemInfo` el `DeviceItem`.
Evidencia: [27-devices-fix2.json](runs/27-devices-fix2.json).

---

## Dos bugs encontrados, ambos corregidos

Los dos son **de upstream**, no del port. El port a V18 los destapó porque en V20 quedan ocultos.

### Bug 1 — `GetTypeSource`: argumentos intercambiados

```
firma:    ExportType(softwarePath, typePath, exportPath)
llamada:  ExportType(softwarePath, dir,      typePath)   ← Portal.Source.cs:132
```

Pasaba el directorio como `typePath`, y fallaba con `Type not found`.

**Por qué en V20 no se ve:** el camino principal de `GetTypeSource` usa `ExportTypeAsDocuments` y
solo cae a este fallback XML si aquello lanza `NotSupported`. En V18, sin SIMATIC Source Documents,
**el fallback es el único camino**, así que falla siempre.

Corregido. `GetTypeSource` devuelve ahora el XML con `format: "xml"`.

### Bug 2 — ciclo de objetos al serializar atributos

```
System.Text.Json.JsonException: A possible object cycle was detected.
  Path: $.Items.Attributes.Value.Directory.Parent.Parent.Parent…        (GetProject)
  Path: $.Items.Attributes.Value.Items.Language.Culture.Parent.Parent…  (GetDevices)
```

`Helper.GetAttributeList` asignaba `Value = value` como `object` crudo. Cuando un atributo de
Openness devuelve un objeto del modelo (`DirectoryInfo`, `CultureInfo`, `MultilingualText`), su
grafo tiene ciclos `Parent`/`Root` y la serialización aborta — tumbando la herramienta entera.

Corregido con `NormalizeAttributeValue`: los tipos simples conservan su tipo JSON, y cualquier otro
se convierte a texto. **Es el mismo criterio que ya aplicaba `ResponseConstantInfo.Value`**, que se
stringifica a propósito *"para que el esquema de salida sea estable"*. El helper no lo aplicaba.

> ⚠️ **Revalidar en V20.** `Helper.GetAttributeList` es código compartido: no está tras ningún `#if`.
> El cambio conserva el tipo JSON de los valores simples, así que la salida de los atributos que ya
> funcionaban no debería cambiar — pero eso **no se ha verificado en V20** y hay que hacerlo.
> Ver `35-runtime/v20/PERFIL.md`.

---

## Comportamientos correctos que no son fallos

- **`GetBlockInterface` sobre un FB** devuelve error explícito: *"'FB_ScaleValue' is a FB, and
  Openness exposes an interface only for data blocks"*. Sobre `DB_PlantState` **sí funciona** y
  devuelve los miembros con sus valores iniciales. El error es la respuesta correcta.
- **`GetBlockSource` y `GetTypeSource` con `format=document`** devuelven `format: "xml"`. Es el
  fallback diseñado para V18, y viene declarado en la respuesta.
- **`PreviewImport` exige un directorio**, no un fichero. El mensaje de error lo dice.

## Límite del propio fixture

`PlcWatchTable.Entries` es un `PlcTableCommentEntryComposition` cuyo único `Create()` no acepta
argumentos: **en Openness V18 no se pueden añadir entradas a una watch table desde la API**. La vía
sería importarla desde XML. Por eso `WT_Motor` tiene `entryCount: 0`, y `GetWatchTables` /
`GetWatchTableInfo` / `ExportWatchTable` se probaron contra una tabla vacía. Es una limitación
observada de la API, no del servidor.

## Lo que este inventario NO acredita

- **Nada de escritura.** El perfil se ejecutó sin `--allow-write`. Las 80 herramientas del perfil
  write siguen a nivel `Esquema`.
- **Que estas 45 funcionen sobre un proyecto real de cliente.** El fixture tiene un PLC, 3 bloques y
  4 tags. Un proyecto con varias CPU, grupos anidados, F-blocks o bloques protegidos puede
  comportarse de otra forma.
- **Que el arreglo del bug 2 no cambie nada en V20.** Pendiente de revalidar allí.
