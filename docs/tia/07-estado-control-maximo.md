# Estado de control máximo — TIA Portal V20

> Fecha: 2026-10-29 | Ámbito: workspace TIA-Claude, TIA Portal V20, Openness, MCP `tia-inspect` + `tia-create`
> Este informe responde a una sola pregunta: **¿qué puede hacer el agente hoy, con qué evidencia, y qué no?**

## Regla de clasificación

| Clase | Significado |
|---|---|
| **Soportado** | Ejecutado sobre TIA real, con readback y gates, y con evidencia guardada |
| **Parcial** | Implementado y probado en arnés, o ejecutado en vivo solo por partes; falta el E2E completo |
| **No soportado** | Evaluado y descartado por riesgo o por falta de contrato verificable |
| **Excluido por diseño** | No se hace por política de seguridad (hardware, download, online) |

Un PASS de mock **nunca** se cuenta como Soportado.

## Resumen ejecutivo

- **Soportado de punta a punta:** lectura del proyecto (árbol, bloques, tags), export textual,
  compilación, guardado guardado, creación de proyecto desde spec, descarga a **CPU virtual**
  (PLCSIM Advanced) con aceptación funcional de dos bloques.
- **Parcial:** escritura de un bloque SCL existente en el proyecto abierto mediante
  `-Route attached`. Toda la cadena está implementada y el arnés cubre 13 casos, pero el E2E con
  la puerta de readback sigue pendiente en TIA real.
- **No soportado hoy:** bloques anidados en la ruta adjunta, `DATA_BLOCK` por generación externa,
  UDT por el flujo SCL, escritura de tags (solo auditoría de herramientas).
- **Excluido por diseño:** descarga a hardware físico, cambios online, edición de F-blocks,
  bloques con know-how protection.

## Capacidades

| Capacidad | Clase | Evidencia | Nota |
|---|---|---|---|
| Doctor / entorno | **Soportado** | `70-runs/environment/latest.json`; `Test-EnvironmentReport.ps1` | Detecta grupo Openness, versiones y ensamblados |
| Conectar / adjuntar a proyecto abierto | **Soportado** | `70-runs/tia-capabilities/20260925-tia-create-safety-live-read-built.json`; ADR-015 | `AttachToOpenProject` solo en `tia-create --profile full` |
| Árbol de proyecto / software | **Soportado** | `70-runs/live-read/*`; ADR-016 | Rutas reales, nunca inventadas |
| Leer bloques y fuentes | **Soportado** | `70-runs/analysis/*`; ADR-018 | Incluye `isFailsafe`, `isKnowHowProtected`, `isConsistent` |
| Export textual a `src/` | **Soportado** | `40-projects/DEMO-Cinta01/src/`; ADR-016 | Requisito del ciclo de trabajo |
| Compilar (`CompileSoftware`) | **Soportado** | ADR-016 (0/0) | El runner exige 0 errores **y** 0 avisos |
| Guardar (`SaveProject`) | **Soportado** | ADR-015; `SaveGuarded` | Fuera de la transacción de mutación |
| Crear proyecto desde spec | **Soportado** | ADR-016, R30 | DEMO-Cinta01 compila 0/0 |
| Descarga a PLCSIM Advanced | **Soportado** | ADR-015, R28 | `FB_AlarmLatch` 65/65, `FC_Escalado` 33/33; solo CPU virtual |
| Escribir FB raíz SCL (ruta adjunta) | **Parcial** | ADR-018; `Test-TiaProposalApplyAttachedRoute.ps1` PASS | E2E del 2026-10-28 llegó a `APPLIED_AND_VERIFIED` pero quedó invalidado por delta solo-`VERSION`; la puerta nueva no se ha ejecutado live |
| Escribir FC raíz SCL | **Parcial** | `Test-TiaBlockTypeCoverage.ps1` PASS; `Assert-TiaCreateBlockWritable` mapea `FUNCTION→FC` | Sin E2E live FC |
| Escribir OB raíz SCL | **Parcial** | `Test-TiaBlockTypeCoverage.ps1` PASS; mapeo `ORGANIZATION_BLOCK→OB` | Sin E2E live OB |
| Escribir `DATA_BLOCK` | **No soportado** | `Assert-TiaCreateBlockWritable` rechaza `DATA_BLOCK` | No hay evidencia de generación de DB por esta ruta |
| Bloques anidados (ruta adjunta) | **No soportado** | `Assert-TiaAttachedRouteTopLevelBlock`; ADR-015/R28 | `ImportPlcExternalSource` con `groupPath` no vacío sin verificar |
| Bloques anidados (ruta aislada) | **Parcial** | `Test-TiaSclProposalApply.ps1` (staging anidado) | El staging soporta grupos; la mutación sigue bloqueada por roster |
| UDT / PLC data types | **No soportado** | `20260924-find-db-udt-import-tools-expanded.json` | Herramientas existen (`ImportType`, `BuildPlcUdtXml`) pero no se ha verificado con un proyecto con UDTs |
| Tags: lectura + clasificación Safety | **Soportado** | `GetTags`/`ExportPlcTagTable`; ADR-013 | El veto es global y conservador |
| Tags: escritura | **No soportado** | Roster auditado (FASE 4.1) | `ImportPlcTagTable`, `CreateTag`, `UpdateTag` existen; no hay runner ni E2E |
| Librerías globales/proyecto | **No soportado** | FASE 5.1 | DEMO-Cinta01 no tiene librerías; no se ha probado resolución |
| Multi-instancia / referencias cruzadas | **No soportado** | FASE 5.2 | Solo lectura prevista; sin proyecto de prueba |
| F-blocks / Safety | **Excluido por diseño** | `Assert-TiaSclBlockWritable`, `Assert-TiaCreateBlockWritable` | Se bloquean, no se editan |
| Know-how protection | **Excluido por diseño** | mismos gates | Se pide al usuario quitar la protección en TIA |
| Descarga a hardware físico | **Excluido por diseño** | AGENTS.md §3.1 | Requiere confirmación explícita en el momento |
| Cambios online / GoOnline de CPU | **Excluido por diseño** | ADR-018 | `GoOffline` es un paso local de ingeniería |
| HMI Unified | **Parcial** | ADR-017, R31 | Requiere runtime de la misma versión que TIA (V20) |

## Gates que sostienen lo anterior

1. **Identidad del proyecto adjunto:** mensaje exacto de `AttachToOpenProject` + primera línea de
   `GetProjectTree` (`Assert-TiaCreateAttachIdentity`).
2. **Roster completo:** si falta una herramienta del ciclo, `BLOCKED` antes de mutar.
3. **Clasificación del bloque:** nombre único, `programmingLanguage=SCL`, `isFailsafe=false`,
   `isKnowHowProtected=false`, `isConsistent=true`, tipo coherente con la declaración.
4. **Tags:** `meta.success`, `complete=true`, `count` coherente, todo tag con `isSafety` booleano y
   ningún tag Safety.
5. **Raíz obligatoria en adjunta:** `groupPath` vacío, o `BLOCKED`.
6. **Compilación:** 0 errores y 0 avisos, o no se guarda.
7. **Readback de contenido:** texto vivo comparado con la propuesta antes de `SaveProject`; si
   difiere, `APPLIED_CONTENT_MISMATCH` y no se guarda.
8. **Veto de cabeceras:** un delta solo-`VERSION` se rechaza antes de abrir MCP.

## Lo que falta para subir de clase

| De | A | Qué falta | Bloqueo |
|---|---|---|---|
| FB/FC/OB Parcial | Soportado | E2E con readback sobre copia desechable y TIA visible | TIA cerrado en esta sesión |
| Anidados No soportado | Parcial/Soportado | Verificar `ImportPlcExternalSource` con `groupPath` y readback por ruta anidada | Requiere evidencia live |
| Tags No soportado | Parcial | Runner de propuesta de tags con gates + E2E de una tabla | Requiere diseño y copia |
| UDT No soportado | Parcial | Proyecto con UDT + `ImportType` + readback | Requiere fixture con UDTs |
| Librerías No soportado | Parcial | Proyecto con librería + `GetCrossReferences` | Requiere fixture |

## Conclusión

El agente **lee y entiende** un proyecto V20 con solidez y **crea** proyectos que compilan y se
descargan a una CPU virtual. La **escritura fina sobre un proyecto abierto** está construida con
gates estrictos y probada en arnés, pero todavía no tiene un E2E live que la declare Soportada.
Ese es el único paso que separa el estado actual de "control máximo verificado" para bloques SCL
raíz.
