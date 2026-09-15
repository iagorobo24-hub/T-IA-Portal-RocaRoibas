# Uso desde distintos agentes

La interoperabilidad se consigue manteniendo dos cosas estables:

1. El contrato operativo de `AGENTS.md`.
2. El protocolo MCP stdio y el manifiesto `30-tools/mcp/servers.json`.

Cada harness solo necesita un adaptador pequeño que transforme `servers.local.json` a su formato:

| Harness | Configuración | Estado esperado |
|---|---|---|
| Claude Code | `.mcp.json` en la raíz del workspace | verificado; `30-tools/harnesses/claude-code.md` |
| OpenCode | configuración MCP del proyecto | adaptar desde `servers.local.json`; sin esquema supuesto |
| Codex | servidor MCP local configurado en el cliente | adaptar desde `servers.local.json`; verificar en la UI |
| Antigravity/Cursor | configuración MCP local | probar después |

El ejecutable y los argumentos deben ser los mismos. Solo cambia el envoltorio de configuración.
