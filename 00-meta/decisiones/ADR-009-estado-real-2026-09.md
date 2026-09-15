# ADR-009 — Estado real del workspace a 2026-09-15

- **Estado:** aceptada como fotografía operativa; se revisa cuando cambie el entorno.
- **Fecha:** 2026-09-15
- **Evidencia primaria:** `70-runs/environment/latest.json`

## Decisiones

1. La versión canónica de trabajo sigue siendo **TIA Portal V20**. V19 está instalado, pero no
   forma parte del flujo de exportación textual principal.
2. La pertenencia al grupo **Siemens TIA Openness** está verificada como `True` por el informe
   local y por el Doctor del MCP.
3. `tia-inspect` V20 está compilado y operativo en modo lectura. El `.mcp.json` del workspace no
   habilita `--allow-write` por defecto.
4. El modo escritura existe en el ejecutable y en `Invoke-TiaMcp.ps1`, pero aún debe superar el
   flujo E2E de backup, preview, importación, compilación, guardado y exportación sobre una copia.
5. `tia-create` no está instalado ni configurado.
6. El Runtime Advanced instalado es V17 HF8; no se considera demostrada la simulación del HMI V20
   hasta instalar o verificar un runtime compatible.
7. El workspace todavía no es un repositorio Git; no se debe afirmar que existe versionado o
   commit hasta inicializarlo y auditar los archivos que se van a publicar.

## No afirmamos todavía

- Que un agente pueda modificar de forma segura un bloque existente y devolverlo compilado.
- Que los siete proyectos funcionen en PLCSIM.
- Que la simulación de los juegos WinCC V20 funcione con el Runtime V17 instalado.
- Que `tia-create` pueda crear un proyecto V20 en esta máquina.
- Que el paquete portable sea una distribución completa: actualmente es un paquete de workspace y
  referencias, sin `tia-create` y sin los `.ap20` migrados del workspace principal.
