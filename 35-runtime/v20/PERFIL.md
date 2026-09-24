# Perfil V20 — **no ejecutable en `EQUIPOTECNICO`**

| | |
|---|---|
| TIA Portal | V20 |
| Paquete NuGet Openness | `20.0.1744190253` |
| Servidores | `35-runtime/v20/bin/tia-inspect/` y `35-runtime/v20/bin/tia-create/` |
| Estado en `EQUIPOTECNICO` | ❌ **no utilizable** — no hay TIA ≥ V19 instalado |
| Estado en el equipo de origen | ✅ era el perfil operativo. **Pendiente de revalidar** (ver abajo) |

## En esta máquina

Los binarios **arrancan** — exit 0, sin stderr, resolver de Openness cargado — pero Doctor reporta:

```
├─ Active Version: V20
├─ Installed TIA Portal versions: none found (>= V19)
```

No es un fallo del binario ni del entorno: **no existe la clave `HKLM\...\Openness\20.0`** porque
V20 no está instalado. Un `Connect` fallaría al resolver `Siemens.Engineering 20.0.0.0`.

**No los uses aquí.** El perfil activo en esta máquina es `v18`.

## ⚠️ Revalidación pendiente en el equipo que sí tiene V20

El port a V18 tocó código compartido. Los cambios están **todos tras `#if TIA_V20_PLUS`**, que en un
build de V20 queda definido y compila exactamente lo mismo que antes — pero **eso no se ha podido
verificar aquí**, y bajo ninguna circunstancia debe darse por bueno sin comprobarlo.

**Por qué no se puede verificar en `EQUIPOTECNICO`:** el paquete NuGet de Siemens **no trae ninguna
DLL**. Es un `.targets` que referencia la instalación local de TIA Portal. Sin V20 en disco, su
build falla con **160 × `CS0234: 'Engineering' no existe en 'Siemens'`** — por la ausencia del
producto, no por el port.

### Qué hacer en el equipo con V20

```powershell
# 1. Recompilar y comprobar que sigue en 0 errores
30-tools\mcp\tia-inspect\build.ps1 -TiaMajor 20

# 2. Regenerar la configuración con las rutas de esa máquina
30-tools\scripts\Sync-HarnessConfigs.ps1 -Profile read -TiaMajorVersion 20

# 3. Generar el artefacto de entorno de esa máquina (ADR-015)
#    -> 70-runs/doctor/<hostname>.json
```

Comprobar en concreto que **siguen funcionando**, porque son lo que el `#if` protege:

- `ExportAsDocuments` / `ImportFromDocuments` y el resto de SIMATIC Source Documents
- `RenameTagTable` y el renombrado en `UpdateTag` (en V18 devuelven `NotSupported`)
- El roster del perfil `write` (84 herramientas medidas el 2026-09-21)

Ficheros afectados por el port: `Portal.cs`, `Portal.Documents.cs`, `Portal.Source.cs`,
`Portal.ImportSources.cs`, `Portal.Write.cs`, `Engineering.cs`, `Diagnostics.cs`, `Program.cs`,
`McpServer.cs`, `McpServer.Documents.cs`, `McpServerWrite.Documents.cs`,
`McpServerWrite.LegacyMutations.cs`, `TiaMcpServer.csproj`.

**El parche canónico `patches/0001-tia-agent-workspace.patch` se regeneró** (79 372 B → ~92 KB).
Es el que `build.ps1` aplica sobre el commit fijado `9c1883c8`.

## ⚠️ Dos correcciones de bugs de upstream — **revalidar con prioridad**

Durante el inventario de lectura de V18 (2026-09-22) se encontraron y corrigieron dos bugs que
**estaban en upstream, no en el port**. Ninguno de los dos está tras un `#if`, así que **ambos
cambian el código que compila V20**:

1. **`Portal.Source.cs` — `GetTypeSource`.** La llamada de fallback era
   `ExportType(softwarePath, dir, typePath)` cuando la firma es
   `ExportType(softwarePath, typePath, exportPath)`: argumentos intercambiados. **En V20 nunca se
   ejecuta** ese fallback (el camino normal usa `ExportTypeAsDocuments`), así que el bug estaba
   latente. Corregido al orden correcto. En V20 no debería cambiar nada; confirmar que
   `GetTypeSource` sigue devolviendo el documento SIMATIC SD y no el XML.

2. **`ModelContextProtocol/Helper.cs` — `GetAttributeList`.** Asignaba `Value = value` como `object`
   crudo; con atributos que devuelven objetos del modelo (`DirectoryInfo`, `CultureInfo`,
   `MultilingualText`) System.Text.Json abortaba con *"A possible object cycle was detected"* y
   tumbaba `GetProject`, `GetDevices`, `GetDeviceInfo` y `GetDeviceItemInfo`. Ahora los tipos
   simples conservan su tipo JSON y el resto se convierte a texto, igual que ya hacía
   `ResponseConstantInfo.Value`.
   **Comprobar en V20 que esas cuatro herramientas siguen devolviendo lo mismo** y que ningún
   consumidor dependía de recibir un objeto anidado en `attributes[].value`.

## Dos cambios que afectan a V20 aunque no sean del `#if`

1. **`Engineering.cs`** — la extensión de fixture ya no es el literal `.ap20`: se deriva de
   `TiaMajorVersion`. En un build de V20 sigue resolviendo a `.ap20`, así que el comportamiento es
   idéntico, pero conviene comprobarlo.
2. **`Diagnostics.cs`** — `MinTiaMajorVersion` bajó de 19 a 16. En V20 esto solo hace que Doctor
   **informe también** de instalaciones V16/V17/V18 si las hubiera. No cambia qué versión se usa.

## `tia-create`

Solo existe en V20/V21 (bundle de bulaofen, v2.7.2, perfil `lite`). **No hay vía de port a V18.**
Si se necesita creación de proyectos en `EQUIPOTECNICO`, la única salida es instalar V20 allí.
