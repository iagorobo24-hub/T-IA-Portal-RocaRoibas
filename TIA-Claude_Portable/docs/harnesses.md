# Uso desde distintos agentes

La interoperabilidad se consigue manteniendo dos cosas estables:

1. El contrato operativo de `AGENTS.md`.
2. El protocolo MCP stdio y el manifiesto `30-tools/mcp/servers.json`.

Cada harness solo necesita un adaptador pequeño que transforme el manifiesto a su formato. El
workspace incluye `30-tools/scripts/Export-HarnessAdapter.ps1`; exporta fragmentos deterministas
y no modifica las configuraciones personales del usuario:

| Harness | Configuración | Estado esperado |
|---|---|---|
| Claude Code | `.mcp.json` en la raíz del workspace | verificado; `30-tools/harnesses/claude-code.md` |
| OpenCode | configuración MCP del proyecto | exportador verificado; revisar la ruta antes de activar |
| Codex | servidor MCP local configurado en el cliente | exportador verificado; revisar la ruta antes de activar |
| Antigravity/Cursor | configuración MCP local | usar el adaptador `generic` si aceptan `mcpServers` estándar; revisar la ruta antes de activar |

El ejecutable y los argumentos deben ser los mismos. Solo cambia el envoltorio de configuración.

Ejemplos desde la raíz del workspace:

```powershell
.\30-tools\scripts\Export-HarnessAdapter.ps1 -Harness claude-code -Profile read -OutputPath .\70-runs\harness\claude-read.json
.\30-tools\scripts\Export-HarnessAdapter.ps1 -Harness codex -Profile read -OutputPath .\70-runs\harness\codex-read.toml
.\30-tools\scripts\Export-HarnessAdapter.ps1 -Harness opencode -Profile read -OutputPath .\70-runs\harness\opencode-read.json
.\30-tools\scripts\Export-HarnessAdapter.ps1 -Harness generic -Profile read -OutputPath .\70-runs\harness\generic-read.json
```

Para perfiles `write`, `create` o `full` hay que añadir `-AcknowledgeWriteProfile`. El resultado
es un fragmento generado para inspección/importación manual; la activación sigue siendo una
decisión del usuario y queda sujeta a `AGENTS.md`.
