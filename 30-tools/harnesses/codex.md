# Codex

El contrato común es `AGENTS.md` y el transporte es MCP stdio. El archivo portable
`30-tools/mcp/servers.local.json` contiene el comando absoluto y los argumentos generados para
esta máquina.

La configuración exacta de MCP de Codex depende del cliente/versión y no se fija aquí con una ruta
inventada. En la interfaz de Codex, añade el servidor local usando los campos `command` y `args`
de `servers.local.json`, manteniendo el perfil read para la primera conexión. Verifica Doctor y
GetProjectTree antes de permitir escritura.
