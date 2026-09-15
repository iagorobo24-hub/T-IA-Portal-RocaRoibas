# OpenCode

OpenCode debe recibir el mismo ejecutable V20 y los mismos argumentos que el manifest central.
Genera `30-tools/mcp/servers.local.json` y traduce sus campos a la configuración MCP de la
versión instalada de OpenCode.

No se incluye un fichero automático con un esquema supuesto: los nombres de configuración cambian
entre versiones. La prueba de humo es que el proceso se inicia, publica `Doctor` y `Connect`, y la
primera operación de proyecto es `GetProjectTree`. Usa el perfil read hasta que esa prueba pase.
