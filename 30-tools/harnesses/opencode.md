# OpenCode

OpenCode debe recibir el mismo ejecutable V20 y los mismos argumentos que el manifest central.
Genera `30-tools/mcp/servers.local.json` y traduce sus campos a la configuración MCP de la
versión instalada de OpenCode.

No se incluye un fichero automático con un esquema supuesto: los nombres de configuración cambian
entre versiones. La prueba de humo es que el proceso se inicia, publica `Doctor` y `Connect`, y la
primera operación de proyecto es `GetProjectTree`. Usa el perfil read hasta que esa prueba pase.

## Cómo confirmar tu ruta de configuración

1. Consulta la documentación oficial de **tu versión instalada** de OpenCode buscando "MCP
   server configuration" o `mcpServers` — la ruta cambia entre versiones y no se fija aquí con un
   nombre de fichero inventado.
2. Genera el fragmento ya traducido al formato de OpenCode:

   ```powershell
   30-tools\scripts\Export-HarnessAdapter.ps1 -Harness opencode -Profile read -OutputPath <ruta-descubierta>
   ```

3. Impórtalo en la configuración de OpenCode y repite la prueba de humo (`Doctor` → `Connect` →
   `GetProjectTree`) antes de subir de perfil.

## Verificado frente a no verificado

| | |
|---|---|
| ✅ **Verificado** | Contrato `AGENTS.md` + transporte MCP stdio; comando y `args` de `servers.local.json`; perfil `read` como punto de partida; `Export-HarnessAdapter.ps1 -Harness opencode` genera JSON determinista |
| ⚠️ **No verificado aquí** | La ruta exacta del fichero de configuración de tu versión instalada de OpenCode — depende de tu cliente y no se asume |

Estado general de interoperabilidad entre harnesses:
[`TIA-Claude_Portable/docs/harnesses.md`](../../TIA-Claude_Portable/docs/harnesses.md).
