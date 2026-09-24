# Claude Code

Es el adaptador principal verificado en este workspace. Claude Code lee `.mcp.json` en la raíz
del workspace; se genera así:

```powershell
30-tools\scripts\Sync-HarnessConfigs.ps1 -WorkspaceRoot (Get-Location).Path -Profile read
```

El perfil `read` solo expone `tia-inspect` sin mutaciones. Un perfil `write/full` necesita
reconocimiento explícito y quedar ligado a una copia desechable con manifiesto:

```powershell
30-tools\scripts\Sync-HarnessConfigs.ps1 -Profile write -AcknowledgeWriteProfile `
  -FixtureRoot '90-tmp\runs\<fixture>'
```

La configuración generada inicia `tia-inspect` con `--isolated --fixture-root ... --allow-write`.
Regénérala para cada fixture. La sesión aún debe cumplir backup, lectura y clasificación F/Safety,
preview, compilación, guardado y readback; las herramientas de importación SCL que falten en el
roster actual siguen bloqueadas.

Comprobación: abre Claude Code en la raíz, ejecuta primero Doctor y continúa con Connect y
GetProjectTree. Nunca copies una ruta absoluta de otro ordenador.
