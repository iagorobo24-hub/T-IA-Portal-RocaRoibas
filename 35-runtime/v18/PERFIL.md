# Perfil V18 — **verificado y en uso**

| | |
|---|---|
| TIA Portal | **V18 SP1 Upd5** |
| Paquete NuGet Openness | `18.0.1685432622` |
| Servidor | `35-runtime/v18/bin/tia-inspect/TiaMcpServer.exe --tia-major-version 18` |
| Verificado en | `EQUIPOTECNICO`, 2026-09-22 |
| Evidencia | `35-runtime/v18/runs/RESUMEN.md` |
| Construir | `30-tools/mcp/tia-inspect/build.ps1 -TiaMajor 18` |
| Configurar | `30-tools/scripts/Sync-HarnessConfigs.ps1 -Profile read -TiaMajorVersion 18` |

## Estado: ejecutado y observado, no inferido

| Comprobación | Resultado |
|---|---|
| Compilación | **0 errores** |
| Doctor | `Active Version: V18`; ve V16/V17/V18 con `Engineering: OK`; grupo `True` |
| Herramientas MCP (perfil `read`) | **49**, ninguna de documentos |
| **Las 49 a nivel `Fixture`** | ✅ **todas ejecutadas** contra un `.ap18` real — [INVENTARIO-LECTURA.md](runs/INVENTARIO-LECTURA.md) |
| `GetSoftwareTree`, `GetBlocks` | ✅ — `isFailsafe:false`, `isKnowHowProtected:false` |
| **Export textual** `GenerateBlockSource` | ✅ — `.scl`, `.db` y `.udt` legibles |
| **`GetCrossReferences`** / `WhereUsed` | ✅ — referencias reales con `%FB1` / `%DB1` |
| `GetBlockSource format=document` | ✅ cae a XML y lo declara en `Format` |
| `CompileSoftware` | ✅ `Success`, 0 errores, 0 avisos |

Todo con perfil de **lectura**. La escritura (`--allow-write`) **no se ha ejercitado en V18**: sus
80 herramientas siguen a nivel `Esquema`.

**Dos bugs de upstream corregidos** durante el inventario, ambos ocultos en V20 y visibles solo en
V18: argumentos intercambiados en el fallback de `GetTypeSource`, y un ciclo de objetos al
serializar atributos que tumbaba `GetProject`, `GetDevices`, `GetDeviceInfo` y `GetDeviceItemInfo`.
Detalle en el inventario.

## Lo que NO tienes en V18

- **SIMATIC Source Documents** (`.s7dcl`/`.s7res`). La API no existe antes de Openness V20.
  `GetBlockSource` con `format=document` **cae a XML automáticamente y lo dice**: no es un fallo.
  Consecuencia real: no se puede leer LAD/FBD ajeno como texto.
- **Renombrar tags y tablas de tags.** `PlcTagTable.Name` y `PlcTag.Name` son de solo lectura antes
  de V20; `RenameTagTable` y el rename de `UpdateTag` devuelven `NotSupported`.
  Renombrar **bloques y tipos de datos sí funciona**.
- **`tia-create`.** Su bundle es V20/V21 y no hay vía de port. Sin creación de proyectos, hardware,
  redes ni HMI.

## La trampa de la whitelist

TIA V18 mantiene `HKLM\SOFTWARE\Siemens\Automation\Openness\18.0\Whitelist\<app>.exe`. **Un binario
que TIA no ha visto nunca falla el primer intento** con `EngineeringSecurityException: Security
error` + *"The operation has timed out"*, aunque el grupo y la licencia estén bien. Ese intento crea
la entrada; **reintenta antes de diagnosticar nada más**. V15.1, V16 y V17 no tienen whitelist.

## Fixtures

`tools/fixture-generator/` crea proyectos `.ap18` **desechables** con CPU 1511-1 PN, un OB1 en LAD y
un `FB_ScaleValue` en SCL, compilados con 0 errores:

```powershell
35-runtime\v18\tools\fixture-generator\bin\Release\net48\TiaClaude.V18Fixture.exe <directorio>
```

`fixtures/source/` es el original; `fixtures/isolated/` es la pareja `project/` + `backup/` con el
manifiesto `.tia-agent-fixture.json` que exige `OpenProject`.

> **`project/` y `backup/` deben ser idénticos byte a byte.** TIA escribe en el proyecto al abrirlo,
> así que tras una sesión hay que recrear ambos desde `source/` antes de regenerar el manifiesto.
> `New-TiaFixtureManifest.ps1` lo comprueba y se niega si no coinciden — es la barrera funcionando,
> no un error.

**Nunca apuntes un fixture-root a `40-projects/` ni a un original de `50-examples/`.**

## Pendiente

- Ejercitar el perfil `write` en V18. `GetBlocks` devuelve `isFailsafe`, así que la barrera de
  AGENTS.md §3.3 es construible, pero no se ha probado ninguna mutación.
- Comprobar si el roster del perfil `write` en V18 registra `ImportSources` / `ImportFromDocuments`.
  Las notas de AGENTS.md §3.3 y §6 sobre eso se midieron en **V20**, no aquí.
