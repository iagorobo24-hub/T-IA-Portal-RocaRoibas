# Codex

El contrato común es `AGENTS.md` y el transporte es MCP stdio. El archivo portable
`30-tools/mcp/servers.local.json` contiene el comando absoluto y los argumentos generados para
esta máquina.

La configuración exacta de MCP de Codex depende del cliente/versión y no se fija aquí con una ruta
inventada. En la interfaz de Codex, añade el servidor local usando los campos `command` y `args`
de `servers.local.json`, manteniendo el perfil read para la primera conexión. Verifica Doctor y
GetProjectTree antes de permitir escritura.

## Cómo confirmar tu ruta de configuración

1. Consulta la documentación oficial de **tu versión instalada** de Codex buscando "MCP server
   configuration" o `mcpServers` — la ruta y el formato del fichero cambian entre versiones, así
   que no se puede fijar una única ruta válida para todas.
2. Una vez localizado ese fichero, genera el fragmento ya traducido en vez de copiarlo a mano:

   ```powershell
   30-tools\scripts\Export-HarnessAdapter.ps1 -Harness codex -Profile read -OutputPath <ruta-descubierta>
   ```

3. Importa/pega ese fragmento en el fichero de configuración de Codex y repite la prueba de humo
   (`Doctor` → `Connect` → `GetProjectTree`).

## Verificado frente a no verificado

| | |
|---|---|
| ✅ **Verificado** | Contrato `AGENTS.md` + transporte MCP stdio; comando y `args` de `servers.local.json`; perfil `read` como punto de partida; `Export-HarnessAdapter.ps1 -Harness codex` genera TOML determinista |
| ⚠️ **No verificado aquí** | La ruta exacta del fichero de configuración de tu versión instalada de Codex — depende de tu cliente y no se asume |

Estado general de interoperabilidad entre harnesses:
[`TIA-Claude_Portable/docs/harnesses.md`](../../TIA-Claude_Portable/docs/harnesses.md).
