# Claude Code

Es el adaptador principal verificado en este workspace. Claude Code lee `.mcp.json` en la raíz
del workspace; se genera así:

```powershell
30-tools\scripts\Sync-HarnessConfigs.ps1 -WorkspaceRoot (Get-Location).Path -Profile read
```

El perfil `read` solo expone `tia-inspect` sin `--allow-write`. Para una sesión de escritura el
usuario debe seleccionar deliberadamente el perfil write y reconocer el riesgo; el flujo
recomendado sigue siendo `Invoke-TiaWriteE2E.ps1` o una receta equivalente con backup, preview,
compilación y guardado.

Comprobación: abre Claude Code en la raíz, ejecuta primero Doctor y continúa con Connect y
GetProjectTree. Nunca copies una ruta absoluta de otro ordenador.
