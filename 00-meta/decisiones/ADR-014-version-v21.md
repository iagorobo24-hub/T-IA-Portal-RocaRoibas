# ADR-014 — Soporte V21: receta preparada, sin verificar en esta máquina

**Fecha:** 2026-09-17
**Estado:** ⚠️ Aceptada como receta; **pendiente de verificación real** por quien tenga V21
**Supersede:** ninguna; amplía [ADR-002](ADR-002-version-tia.md), que fija V20 como versión
operativa

## Contexto

Esta máquina tiene **V19 y V20** instalados (`10-kb/README.md`, entorno de referencia). **No hay
V21 instalado aquí**, así que nada de lo que sigue se ha ejecutado contra un TIA Portal V21 real.
Un compañero sí tiene V21. Este ADR deja la receta lista para que la ejecute él y la convierta en
✅ verificado, en vez de que el agente le diga "prueba a ver".

## Decisión

Se prepara — no se activa por defecto — una rama V21 para los dos servidores MCP:

### `tia-inspect` (heilingbrunner) — ya estaba preparado

`30-tools/mcp/tia-inspect/build.ps1` acepta `-TiaMajor 21` desde antes de este ADR: el upstream
**targetea V21 por defecto**, y el parche `0001-tia-v19-v20-compat.patch` que este workspace
aplica ya define `TIA_V21_PLUS` como condición de compilación (línea `DefineConstants
Condition=" '$(TiaMajor)' == '21' "`). No hace falta tocar nada de código para probarlo:

```powershell
30-tools\mcp\tia-inspect\build.ps1 -TiaMajor 21
```

Esto compila contra el paquete NuGet `Siemens.Collaboration.Net.TiaPortal.Packages.Openness
21.0.1765349347` (mapeado en el propio script) y publica en
`30-tools/mcp/tia-inspect/bin/v21/`.

### `tia-create` (bulaofen) — hacía falta un `build.ps1` nuevo

El binario V20 instalado en este workspace se bajó a mano de un ZIP de release (ver
`00-meta/02-plan.md`, hito M0.3), así que no existía un script de compilación reproducible. Se
añadió `30-tools/mcp/tia-create/build.ps1`, con el mismo patrón que el de `tia-inspect`.

📄 **Verificado leyendo el código fuente del upstream** (clon temporal del commit fijado
`218e829df3f056b653d7831c60a6297818db72fd`, borrado tras la comprobación — no es el `_ref/`
persistente): el repo trae **dos `.csproj` separados y no intercambiables**
(`README.md` del propio repo, sección *"Dual-version support (V20 + V21)"`):

| Proyecto | Versión | Paquete Openness | Salida |
|---|---|---|---|
| `TiaMcpServer.V20.csproj` | V20 | `20.0.1744190253` | `src/TiaMcpServer/bin-v20/Release/net48/` |
| `TiaMcpServer.csproj` (sin sufijo) | V21 | `21.0.1765349347` | `src/TiaMcpServer/bin/Release/net48/` |

```powershell
30-tools\mcp\tia-create\build.ps1 -TiaMajor 21
```

publica en `30-tools/mcp/tia-create/bin/v21/`.

## Por qué esto es "receta", no "soporte V21"

- **`--doctor` en esta máquina no puede confirmar V21** porque no hay Portal V21 instalado aquí.
  El script lo ejecuta igualmente al final del build, pero el resultado esperable es que
  Diagnostics no encuentre la instalación — eso no es un fallo del build, es el estado real de
  esta máquina.
- Nadie ha corrido un scaffold ni una compilación real contra un proyecto V21. Las reglas de
  `10-kb/README.md` obligan a marcar esto **⚠️ Por confirmar**, no ✅.
- `AGENTS.md` §2 exige `Doctor` sano antes de cualquier otra cosa. En una máquina con V21, si
  `Doctor` no confirma V21 Engineering/Portal OK, el agente debe parar igual que pararía con
  cualquier otra versión — este ADR no baja esa guardia.

## Qué tiene que hacer quien sí tenga V21

1. `30-tools\mcp\tia-inspect\build.ps1 -TiaMajor 21` y `30-tools\mcp\tia-create\build.ps1
   -TiaMajor 21`.
2. Confirmar `--doctor` en ambos: Engineering V21 y Portal V21 en `OK`.
3. Generar un perfil de conexión apuntando a `bin/v21`:

   ```powershell
   30-tools\scripts\Sync-HarnessConfigs.ps1 -Profile read -TiaMajorVersion 21
   ```

   El script avisa con `Write-Warning` que la rama V21 no está verificada en la máquina de
   origen de este workspace (lee la nota de `servers.json`); eso es correcto y no bloquea, es
   solo el aviso de que este ADR sigue en ⚠️.
4. Repetir con un proyecto desechable el mismo camino de aceptación que ya se hizo para V20:
   `Doctor → Connect → GetProjectTree → scaffold/edición mínima → CompileSoftware (0 errores) →
   SaveProject → export a texto`.
5. Sustituir las marcas ⚠️ de este ADR por ✅, con la evidencia real (salida de `--doctor`,
   resultado de compilación, ruta del proyecto de prueba), y actualizar
   `10-kb/10-openness/capacidades-y-alcance-por-conexion.md` y la tabla de estado de
   `AGENTS.md` §9.

## Qué NO cambia

- V20 sigue siendo la versión operativa por defecto en este workspace (ADR-002 no queda
  derogada). `.mcp.json` y `servers.local.json` de esta máquina se generan igual, apuntando a
  V20.
- La regla de hardware físico (`AGENTS.md` §3.1) y todas las puertas de escritura (§3.2) aplican
  exactamente igual en V21. Una versión de Openness distinta no relaja ninguna confirmación.
- Los documentos SIMATIC SD (`.s7dcl`/`.s7res`) siguen disponibles desde V20; V21 no quita nada
  de lo que ya funciona, añade lo de `10-kb/10-openness/limites.md` §"Versiones" (tipos de datos
  PLC como documento, `PlcWatchTable.Name` escribible, Version Control Interface completo) — esas
  sí son ganancias reales de V21 **una vez verificadas**.

## Trabajo pendiente explícito

- `30-tools/mcp/servers.json` ya trae un bloque `versions` (`20`/`21`) por servidor, y
  `Sync-HarnessConfigs.ps1` acepta `-TiaMajorVersion 21` para generar `.mcp.json` apuntando a
  `bin/v21` sin tocar nada a mano. Esto se probó con `$TiaMajorVersion = 20` (el camino por
  defecto, sin cambios de comportamiento) porque es lo único verificable en esta máquina; el
  camino `21` no se ha ejercitado de punta a punta contra binarios reales — hacedlo vosotros y
  actualizad este punto.
- `TIA-Claude_Portable/manifests/repositories.json` fija el commit de `tia-create-reference`; si
  el build V21 se verifica contra un commit distinto, hay que actualizar ese manifiesto también.
- Los tests `30-tools/tests/Test-ServerManifest.ps1` y `Test-SyncHarnessConfigs.ps1` solo cubren
  el camino V20 por defecto. Si se quiere que CI verifique también la rama V21, hace falta un
  entorno con los binarios `bin/v21` construidos — no tiene sentido simularlo sin el ejecutable
  real.
