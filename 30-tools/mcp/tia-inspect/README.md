# tia-inspect

Servidor MCP de **lectura y análisis** de proyectos TIA Portal.
Upstream: [heilingbrunner/tiaportal-mcp](https://github.com/heilingbrunner/tiaportal-mcp) (MIT).

## Estado

✅ **Compilado y verificado contra TIA V20 en esta máquina** (2026-09-14).

```
Active Version: V20
Installed TIA Portal versions:
  V19: C:\Program Files\Siemens\Automation\Portal V19   Engineering: OK   Portal: OK
  V20: C:\Program Files\Siemens\Automation\Portal V20   Engineering: OK   Portal: OK
User in 'Siemens TIA Openness' user group: True    <-- ✅ verificado por Doctor 2026-09-15
```

## Compilar

```powershell
.\build.ps1              # TIA V20 (por defecto)
.\build.ps1 -TiaMajor 21 # TIA V21
.\build.ps1 -Clean       # descarta upstream/ y vuelve a clonar
```

El script clona el upstream, aplica `patches/0001-tia-v19-v20-compat.patch`, compila y ejecuta
`--doctor`. `upstream/` y `bin/` no se versionan: el build es reproducible desde el parche.

## Por qué hay un parche

Upstream targetea TIA **V21**. Los tres cambios mínimos para V20:

| Fichero | Cambio | Motivo |
|---|---|---|
| `TiaMcpServer.csproj` | Versión del paquete Openness parametrizable (`$(OpennessPackageVersion)`) | Con el paquete 21.0.x y sin V21 instalado: **241 errores CS0246** |
| `TiaMcpServer.csproj` | `System.Management` sin `HintPath` fijo | El Developer Pack instala `v4.8.1`, no `v4.8` |
| `Portal.Write.cs` | `RenameWatchTable` tras `#if TIA_V21_PLUS` | `PlcWatchTable.Name` es de solo lectura antes de V21 |
| `Diagnostics.cs` | Suelo de detección V21 → V19 | Si no, `--doctor` dice "ninguna versión instalada" teniendo dos |

## Mantenimiento

Al actualizar upstream, el parche puede dejar de aplicar. `build.ps1` lo detecta y lo dice en
vez de compilar algo a medias. Para regenerarlo:

```powershell
cd upstream
git pull
# rehacer los cambios a mano, luego:
git diff -- src/TiaMcpServer > ..\patches\0001-tia-v19-v20-compat.patch
```

Commit de upstream contra el que está validado: ver `patches/UPSTREAM-COMMIT.txt`.

## Uso

```
bin\v20\TiaMcpServer.exe --tia-major-version 20
```

Por defecto **solo lectura** (59 herramientas). Las 40 de escritura necesitan `--allow-write`
y no se registran sin ella: el modelo no puede llamar a lo que no ve. El `.mcp.json` de este
workspace permanece deliberadamente en solo lectura; el modo escritura se reserva para sesiones
puntuales y debe seguir el backup/preview/compile/save/export de `AGENTS.md`.
