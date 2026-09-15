# ADR-011 — Perfiles MCP y concurrencia con TIA abierto

**Estado:** aceptado  
**Fecha:** 2026-09-15  
**Supersede:** ninguna; concreta ADR-009 y el contrato de `AGENTS.md`

## Decisión

El workspace publica cuatro perfiles explícitos para los harnesses:

| Perfil | Servidor | Uso | Confirmación |
|---|---|---|---|
| `read` | `tia-inspect` | descubrir, leer, buscar y exportar | no |
| `write` | `tia-inspect --allow-write` | editar bloques existentes | sí, por la tarea |
| `create` | `tia-create --profile lite` | crear proyecto, hardware, red o HMI | sí |
| `full` | ambos | flujo combinado de análisis y creación | sí |

El perfil `read` es el predeterminado. `create` y `full` no se sincronizan ni se activan sin
reconocimiento explícito. Las operaciones de creación deben ejecutar primero `ScaffoldProject`
con `dryRun=true` y solo después aplicar el mismo plan en una ruta nueva y confirmada.

## Concurrencia

TIA Portal es un recurso de escritorio con estado. Antes de conectar, el agente debe comprobar
si existe una instancia abierta y seguir `Attach` cuando el proyecto abierto sea el objetivo y el
servidor lo exponga.
No debe abrir una segunda instancia ni cerrar/sustituir un proyecto que no haya sido confirmado.
Un intento de crear un proyecto nuevo mientras una instancia ocupada impide la operación se
clasifica como **bloqueado**, no como fallo del plan; el siguiente paso es que el usuario libere
la instancia o confirme el flujo de attach.

## Consecuencia

La automatización sigue siendo portable entre Claude Code, Codex, OpenCode y otros harnesses,
pero el permiso de escritura queda visible en la configuración y en los informes. La ejecución
real de un scaffold, la compilación y la simulación siguen necesitando evidencia independiente;
un smoke test MCP o un dry-run no prueba comportamiento PLC/HMI.
