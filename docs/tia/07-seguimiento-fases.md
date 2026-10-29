# Seguimiento de fases - Ampliación control TIA Portal

> Inicio: 2026-10-29 | Objetivo: máximo control posible manteniendo seguridad fail-closed
> Regla de este documento: **DONE exige evidencia reproducible**. Un arnés PASS no es un E2E live.

## Corrección de estado (2026-10-29, reauditoría)

La actualización anterior marcó `FASE 1.4` y `FASE 2` como completas. La reauditoría de la evidencia
en disco **no lo respalda** y se corrige aquí:

| Afirmación anterior | Evidencia real | Corrección |
|---|---|---|
| E2E FC/OB `APPLIED_AND_VERIFIED` | `90-tmp/e2e/attached-route-live-20261028-130710/` solo contiene un informe `PREVIEW`; el preflight dio `BLOCKED` (`no-tia-process`) | `1.4` vuelve a **PENDIENTE** |
| El E2E de ADR-018 validó un bloque | ADR-018: el E2E del 2026-10-28 llegó a `APPLIED_AND_VERIFIED` con **`FB_Motor`**, y quedó invalidado por un delta solo-`VERSION` | No es evidencia FC/OB |
| FASE 2 completa | `2.3` y `2.4` seguían `PENDIENTE`; el runner bloqueaba todo `groupPath` no vacío | FASE 2 **no completa** |
| "No code change needed" en 2.2 | El código sí bloquea: `Assert-TiaAttachedRouteTopLevelBlock` (antes, `throw` inline) | 2.2 corregido; 2.3 ejecutado |

En esta sesión **no hay TIA Portal abierto** (solo `TiaAdminNotifier`), así que ningún E2E live es
posible. El trabajo hecho es de arnés, gates y documentación.

## Estado global

- [x] **FASE 0** - Auditoría y línea base
- [ ] **FASE 1** - Ampliar tipos de bloque (FC/OB/DB) — implementación y arnés DONE; E2E FC/OB PENDIENTE
- [ ] **FASE 2** - Bloques anidados — política endurecida y probada; E2E anidado PENDIENTE
- [ ] **FASE 3** - UDT / PLC data types — viabilidad evaluada por roster; sin proyecto con UDTs
- [ ] **FASE 4** - Tags escritura — herramientas auditadas; runner de escritura PENDIENTE
- [ ] **FASE 5** - Librerías / multi-instancia / robustez — parcial
- [ ] **FASE 6** - Cobertura por versión y cierre — arnés ampliado e informe final hechos

## FASE 0: Auditoría y línea base

| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 0.1 | Inventario rutas en runner/safety/tests | **DONE** | Leídos `TiaSclSafety.ps1`, `Invoke-TiaSclProposalApply.ps1`, `Test-TiaProposalApplyAttachedRoute.ps1`, `Test-TiaSclProposalApply.ps1` |
| 0.2 | Tests base | **DONE** | `Test-TiaProposalApplyAttachedRoute.ps1` PASS (13 casos, re-ejecutado 2026-10-29), `Test-TiaSclProposalApply.ps1` PASS |
| 0.3 | Matriz capacidades | **DONE** | `docs/tia/06-capacidades-por-version.md` (estados corregidos 2026-10-29) |
| 0.4 | Seguimiento de fases | **DONE** | `docs/tia/07-seguimiento-fases.md` |

**Resultado FASE 0:** línea base estable. Puntos de extensión identificados: mapeo de tipos
(`FB/OB/FC`), restricción de raíz en la ruta adjunta, gates de bloque/tags y puerta de delta de
contenido.

## FASE 1: Ampliar tipos de bloque (FC/OB/DB)

| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 1.1 | Inventario real FC/OB/DB | **DONE** | DEMO-Cinta01: `FB_Motor` (FB/SCL), `Main` (OB/SCL), `iDB_M01` (InstanceDB). No hay FC en el proyecto |
| 1.2 | Ampliar `TiaSclSafety.ps1` | **DONE** | `Assert-TiaCreateBlockWritable`: `FUNCTION_BLOCK→FB`, `ORGANIZATION_BLOCK→OB`, `FUNCTION→FC`; `DATA_BLOCK` fail-closed (sin evidencia live). `Assert-TiaSclSourceTarget` y `Assert-TiaSclDeclarationMatchesBlock` cubren los 4 tipos |
| 1.3 | Ampliar runner | **DONE** | El runner delega en safety; sin bloqueo duro a FB |
| 1.4 | E2E real con FC/OB | **PENDIENTE** | No existe informe live FC/OB. El único run reciente es `PREVIEW` y su preflight fue `BLOCKED` |

### FASE 1.4: E2E con FC/OB

| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 1.4.1 | Preparar propuesta SCL para FC y OB | **PENDIENTE** | No generada en esta sesión |
| 1.4.2 | Ejecutar preflight attached-route | **PENDIENTE** | Requiere TIA abierto con la copia desechable |
| 1.4.3 | Ejecutar apply con readback vivo | **PENDIENTE** | Solo `APPLIED_AND_VERIFIED` si el readback coincide; si no, `APPLIED_CONTENT_MISMATCH` sin `SaveProject` |
| 1.4.4 | Documentar resultados | **DONE (parcial)** | ADR-018: decisión de **no ampliar el veto** a `AUTHOR/FAMILY/TITLE`; las sondas reales del 2026-10-29 demuestran que Openness V20 los ignora y el gate los bloquea. Procede de sondas sobre FB, **no** de un E2E FC/OB |

## FASE 2: Bloques anidados

| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 2.1 | Mapear jerarquía real de bloques | **DONE** | `dossier/analysis.json`: `FB_Motor`, `iDB_M01`, `Main` con `path=""` (raíz). Un anidado resolvería `groupPath` tipo `40_Devices/PLC_1/Program blocks` |
| 2.2 | Evaluar relajar la restricción `groupPath == ''` | **DONE** | Decisión: **no relajar**. `ImportPlcExternalSource` con `groupPath` no vacío no está verificado live (ADR-015/R28). Se mantiene fail-closed |
| 2.3 | Ajustar runner para rutas anidadas | **DONE** | Nueva función única `Assert-TiaAttachedRouteTopLevelBlock` en `TiaSclSafety.ps1`, usada por el runner. El mensaje nombra `blockPath`, `groupPath` y R28. Probada en `Test-TiaBlockTypeCoverage.ps1` (raíz aceptada, 1 y 3 niveles rechazados) |
| 2.4 | E2E anidado mínimo | **PENDIENTE** | Requiere proyecto/copia con bloque anidado y TIA abierto; mismos gates que 1.4 |

**Nota de diseño:** un bloque anidado no se "soporta parcialmente": o se pasa `groupPath` a la
herramienta (sin evidencia) o se rechaza antes de MCP. Hoy se rechaza. La alternativa es la ruta
aislada, que sí transporta `groupPath`, pero sigue bloqueada por el roster de importadores.

## FASE 3: UDT / PLC data types

| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 3.1 | Inspeccionar UDTs en inventario | **DONE** | DEMO-Cinta01 no tiene UDTs de usuario; solo FB/InstanceDB/OB estándar |
| 3.2 | Evaluar viabilidad de importación de UDT | **DONE** | Roster real (`70-runs/tia-capabilities/20260924-find-db-udt-import-tools-expanded.json`): existen `BuildPlcUdtXml`, `ImportType(softwarePath, groupPath, importPath)`, `DeletePlcType`, `ExportType` e `ImportPlcProgramFromDirectory`. **No** usan el flujo `.scl → GenerateBlocksFromExternalSource`: son XML + `ImportType`. Viabilidad: sí, con cadena distinta y sin verificar |
| 3.3 | Documentar hallazgo | **DONE** | Decisión: **inspección/solo lectura** hasta que exista un proyecto con UDTs y se verifique `ImportType` con readback. No se excluye por diseño; no se implementa a ciegas |

## FASE 4: Tags escritura

| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 4.1 | Auditar herramientas de tags | **DONE** | `tia-create` lite (55 tools): `GetPlcTagTables`, `ImportPlcTagTable(softwarePath, folderPath, importPath)`. `tia-inspect` write (84 tools): `CreateTag`, `UpdateTag`, `DeleteTag`, `CreateTagTable`, `RenameTagTable`, `DeleteTagTable`, `ExportTagTable`, `GetTagInfo`. Evidencia: `70-runs/acceptance/plcsim-tia-attach-capability-20260924.json`, `70-runs/acceptance/plcsim-inspect-write-tools-20260925.json` |
| 4.2 | Implementar propuesta de tags mínima | **IN_PROGRESS** | Contrato cerrado en `00-meta/decisiones/ADR-019-escritura-tags-plc.md`: propuesta JSON, ruta aislada, `UpdateTag`/`CreateTag`/`DeleteTag` granulares, backup por `ExportTagTable`, readback por `GetTagInfo`, compile 0/0 y save. Código pendiente |
| 4.3 | E2E tags mínima | **PENDIENTE** | Requiere copia desechable y TIA abierto |

## FASE 5: Librerías / multi-instancia / robustez

| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 5.1 | Probar librerías en proyecto | **DONE (limitado)** | DEMO-Cinta01 no tiene librerías externas y compila 0/0. No se ha probado resolución de `blockPath` contra librerías globales: falta un proyecto que las tenga |
| 5.2 | Multi-instancia / llamados cruzados | **PENDIENTE** | Verificar `WhereUsed`/`GetCrossReferences`; mantener solo lectura. Requiere proyecto con llamadas |
| 5.3 | Hardening de mensajes `BLOCKED`/`FAILED` | **DONE** | Roster nombra la herramienta que falta; identidad cita el proyecto esperado; compile informa errores/avisos y ordena no guardar; anidados nombra `blockPath`, `groupPath` y R28; readback distingue `MISMATCH` de `READBACK_FAILED` |
| 5.4 | Idempotencia/restauración probada | **PENDIENTE** | Procedimiento documentado (reimportar la fuente original), pero sin prueba de idempotencia repetida sobre la misma copia |

## FASE 6: Cobertura por versión y cierre

| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 6.1 | Matriz versión completa | **DONE** | `docs/tia/06-capacidades-por-version.md`, corregida: V20 es el único con evidencia live parcial; V17-V19 sin binarios |
| 6.2 | Arnés ampliado por tipo | **DONE** | `30-tools/tests/Test-TiaBlockTypeCoverage.ps1`: 43 aserciones sobre FB/FC/OB/DB, alias de `tia-create`, gates de seguridad, identidad por `path`, anidados y tags. Registrado en `Run-WorkspaceChecks.ps1` |
| 6.3 | Hardening final de gates | **DONE** | Revisión del runner: sin `catch` vacíos; compile exige 0 errores **y** 0 avisos; readback exacto antes de guardar; veto de cabeceras antes de MCP. Hallazgo corregido: `Assert-TiaCreateBlockWritable` ahora verifica `path` cuando el payload la expone (mismatch → `BLOCKED`), sin romper payloads que no la traen |
| 6.4 | Informe final de capacidad | **DONE** | `docs/tia/07-estado-control-maximo.md` |

---

## Evidencia de la sesión 2026-10-29

| Comando | Resultado |
|---|---|
| `Test-TiaBlockTypeCoverage.ps1` | PASS, 43 aserciones |
| `Test-TiaProposalApplyAttachedRoute.ps1` | PASS, 13 casos |
| `Test-TiaSclSafetyGate.ps1` | PASS |
| `Test-TiaSclProposalApply.ps1` | PASS |

## Próxima acción (cuando TIA esté disponible)

1. Abrir una **copia desechable** de DEMO-Cinta01 en TIA Portal V20, visible.
2. Ejecutar `Test-TiaAttachedRoutePreflight.ps1` → `READY`.
3. Generar propuesta para un `FC` y para `Main` (OB) y aplicar con `-Route attached`.
4. Guardar los informes en `70-runs/` y actualizar 1.4/2.4 con el JSON real.
5. Solo entonces marcar FASE 1 y FASE 2 como completas.

## Reglas

- Un bloque por vez.
- Siempre copia desechable.
- Fail-closed ante duda.
- Readback obligatorio en mutación.
- Documentar todo con evidencia.
- Sin hardware/download/online.
- Ampliar el arnés antes de un E2E real cuando aplique.
- Un PASS de arnés no se presenta como verificación live.

---

**Leyenda**
- **Soportado**: verificado con evidencia real (E2E con readback, gates, fail-closed)
- **Parcial**: implementado pero sin E2E real, o con limitaciones documentadas
- **No soportado**: evaluado y descartado por diseño o riesgos inaceptables
- **Excluido por diseño**: seguridad, sin hardware, sin download/online
