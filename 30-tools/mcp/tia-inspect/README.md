# tia-inspect

Servidor MCP de **lectura y análisis** de proyectos TIA Portal.
Upstream: [heilingbrunner/tiaportal-mcp](https://github.com/heilingbrunner/tiaportal-mcp) (MIT).

## Estado

✅ **Código fuente compilado para Openness V20** (2026-09-21; 0 errores). La aceptación runtime en
fixture está pendiente y no se debe inferir de la compilación.

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
.\build.ps1 -Clean       # limpia outputs de compilacion; preserva upstream/
```

El script clona el upstream sin checkout si falta, lo fija al SHA de `patches/UPSTREAM-COMMIT.txt`
y aplica un único parche canónico si aún no está presente. Los parches antiguos están preservados
en `patches/archive/` y no se aplican. Después compila y ejecuta `--doctor`. Nunca revierte ni borra
cambios de `upstream/`; si el SHA difiere o el parche no encaja, se detiene conservando los archivos.
`upstream/` y `bin/` no se versionan.

## Por qué hay parches

Upstream targetea TIA **V21**. Los tres cambios mínimos para V20:

| Fichero | Cambio | Motivo |
|---|---|---|
| `TiaMcpServer.csproj` | Versión del paquete Openness parametrizable (`$(OpennessPackageVersion)`) | Con el paquete 21.0.x y sin V21 instalado: **241 errores CS0246** |
| `TiaMcpServer.csproj` | `System.Management` sin `HintPath` fijo | El Developer Pack instala `v4.8.1`, no `v4.8` |
| `Portal.Write.cs` | `RenameWatchTable` tras `#if TIA_V21_PLUS` | `PlcWatchTable.Name` es de solo lectura antes de V21 |
| `Diagnostics.cs` | Suelo de detección V21 → V19 | Si no, `--doctor` dice "ninguna versión instalada" teniendo dos |
| `Portal.cs`, `CliOptions.cs`, `Engineering.cs`, `Program.cs` | `--isolated --fixture-root` y manifiesto con ruta exacta/backup | No permite abrir otro proyecto ni adjuntar a la ventana visible |
| `Responses.cs`, `SafetyClassification.cs`, `Portal.Safety.cs` | Clasifica bloques F y veta proyectos con F, tags Safety, know-how o clasificación desconocida | Preflight dentro de acceso exclusivo y transacción |
| `McpServerWrite*.cs`, `WritePolicy.cs`, `Portal.Transactions.cs` | Escrituras sólo con raíz de fixture, bloqueo de importaciones opacas y rollback en cancelación | No expone importaciones de tipos F-compliant sin clasificador verificable |

## Mantenimiento

Al actualizar upstream, un parche puede dejar de aplicar. `build.ps1` lo detecta y se detiene sin
revertir el árbol. El parche canónico contiene el conjunto completo de cambios locales contra el SHA
fijado; no se debe añadir en paralelo otro parche que repita hunks. Para actualizar la base, primero
revisa las diferencias de API y vuelve a generar y probar el parche completo en un clon limpio:

```powershell
cd upstream
git status --short
git rev-parse HEAD
# Tras actualizar y revisar, escribir un nuevo SHA en patches/UPSTREAM-COMMIT.txt,
# crear un clon limpio en una carpeta temporal y validar el parche canónico allí.
```

El parche completo activo es `patches/0001-tia-agent-workspace.patch`; los dos parches anteriores
se conservan en `patches/archive/` como historial, no como pasos de aplicación.

## Uso

```
bin\v20\TiaMcpServer.exe --tia-major-version 20
```

Por defecto **solo lectura**. Las herramientas mutantes sólo se registran con
`--isolated --fixture-root <run-dir> --allow-write`; `run-dir` debe contener
`.tia-agent-fixture.json`, con el `.ap20` exacto y una copia de backup. Las importaciones de bloques,
fuentes y PLC types permanecen fuera del roster hasta que haya clasificación de payload. El
`.mcp.json` de este workspace permanece deliberadamente en solo lectura.

Para preparar una raíz desechable, copiar el proyecto completo y su backup, luego ejecutar
`New-TiaFixtureManifest.ps1`. No crear el manifiesto para proyectos de cliente ni para originales
de `50-examples/`.
