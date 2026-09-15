# ADR-010 — Estado real actualizado del workspace a 2026-09-15

- **Estado:** aceptada; sustituye como fotografía operativa a ADR-009.
- **Evidencia primaria:** `70-runs/environment/latest.json`,
  `70-runs/environment/tia-create-smoke.json`,
  `70-runs/standards/sweep-20260915-all/sweep-report.json`.

## Decisiones y hechos verificados

1. TIA Portal V20 y Openness V20 son la plataforma canónica. V19 queda fuera del flujo textual.
2. `tia-inspect` V20 está operativo: lectura por defecto y escritura solo con `--allow-write`.
3. `tia-create` V20 `2.7.2` está compilado desde `TiaMcpServer.V20.csproj`, publicado en el
   workspace y verificado por MCP: el perfil `lite` publica 55 herramientas, incluyendo
   `CreateProject` y `ScaffoldProject`.
4. El perfil `read` sigue exponiendo únicamente `tia-inspect`; `create` y `full` requieren
   reconocimiento explícito al generarse.
5. El scaffold mínimo tiene dry-run verificado. La creación real permanece pendiente porque la
   instancia de TIA con ventana abierta no debe ser sustituida por el agente.
6. Los siete ejemplos V20 fueron abiertos e inventariados en solo lectura, sin errores de
   colección. El checker encontró 3 bloqueos y 36 advertencias documentales; no se corrigieron
   automáticamente.
7. Runtime Advanced V17 HF8 sigue sin ser compatible como evidencia de simulación HMI V20.
8. La simulación funcional PLC y la simulación HMI siguen sin demostrarse; compilar no cuenta como
   prueba de comportamiento.
9. `Write-TiaAcceptanceStatus.ps1` mantiene separadas las comprobaciones verdes del workspace de
   la aceptación E2E completa; el estado aceptado sigue siendo falso mientras falten esas pruebas.

## No afirmamos todavía

- Que `ScaffoldProject` haya creado y compilado un proyecto real en esta máquina.
- Que PLCSIM haya ejecutado una transición funcional del sorting plant.
- Que los juegos WinCC V20 funcionen con Runtime Advanced V17.
- Que Codex, OpenCode, Antigravity o Cursor tengan configuración automática verificada.
