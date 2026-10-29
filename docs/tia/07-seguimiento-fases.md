# Seguimiento de fases - Ampliación control TIA Portal

> Inicio: 2026-10-29 | Objetivo: Máximo control posible manteniendo seguridad fail-closed

## Estado global
- [x] **FASE 0** - Auditoría y línea base
- [ ] **FASE 1** - Ampliar tipos de bloque (FC/OB/DB)
- [ ] **FASE 2** - Bloques anidados
- [ ] **FASE 3** - UDT / PLC data types
- [ ] **FASE 4** - Tags escritura
- [ ] **FASE 5** - Librerías / multi-instancia / robustez
- [ ] **FASE 6** - Cobertura por versión y cierre

## FASE 0: Auditoría y línea base
| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 0.1 | Inventario rutas en runner/safety/tests | **DONE** | Leídos `TiaSclSafety.ps1`, `Invoke-TiaSclProposalApply.ps1`, `Test-TiaProposalApplyAttachedRoute.ps1`, `Test-TiaSclProposalApply.ps1` |
| 0.2 | Tests base | **DONE** | `Test-TiaProposalApplyAttachedRoute.ps1` PASS (13), `Test-TiaSclProposalApply.ps1` PASS |
| 0.3 | Matriz capacidades | **DONE** | `docs/tia/06-capacidades-por-version.md` |
| 0.4 | Seguimiento de fases | **DONE** | `docs/tia/07-seguimiento-fases.md` |

**Resultado FASE 0:** Línea base estable. Puntos de extensión identificados:
- Restricción a `FB`/raíz en varios sitios
- `Assert-TiaCreateBlockWritable` con mapeo `FB/OB` hardcoded
- Validación `groupPath == ''` en ruta adjunta
- Gates de bloque centrados en SCL + checks de seguridad

## FASE 1: Ampliar tipos de bloque (FC/OB/DB)
| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 1.1 | Inventario real FC/OB/DB | **DONE** | DEMO-Cinta01: FB_Motor (FB/SCL), Main/OB_Main (OB/SCL). FC a buscar/evaluado |
| 1.2 | Ampliar TiaSclSafety.ps1 | **DONE** | `Assert-TiaCreateBlockWritable` permite FUNCTION->FC; `Assert-TiaSclDeclarationMatchesBlock` ya soporta FUNCTION |
| 1.3 | Ampliar runner | **DONE** | Delegado en safety, sin bloqueo duro a FB |
| 1.4 | E2E real con FC/OB | **PENDIENTE** | Requiere TIA abierto + propuesta válida sobre copia desechable |

## FASE 1.4: E2E con FC/OB
| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 1.4.1 | Preparar propuesta SCL para OB/Main | **PENDIENTE** | Evidencia: proposal.json generado offline a partir de analysis.json; readback pending TIA real |
| 1.4.2 | Ejecutar preflight attached-route | **PENDIENTE** | Debe dar READY con TIA abierto y visible (copia desechable) |
| 1.4.3 | Ejecutar apply con readback vivo | **PENDIENTE** | Solo APPLIED_AND_VERIFIED si readback coincide con propuesta; si mismatch → APPLIED_CONTENT_MISMATCH, sin SaveProject |
| 1.4.4 | Documentar resultados | **PENDIENTE** | Evidencia JSON, hash restauración contra pristine, decisión ADR-018 sobre si ampliar veto a AUTHOR/FAMILY/TITLE |

## Próxima acción
**FASE 2:** Bloques anidados - evaluar `groupPath` vacío vs rutas reales con bloques internos. Pendiente: analizar rutas tipo `40_Devices/FB_Motor` desde `GetBlocks` y `GetProjectTree`.

## Reglas
- Un bloque por vez
- Siempre copia desechable
- Fail-closed ante duda
- Readback obligatorio en mutación
- Documentar todo con evidencia
- Sin hardware/download/online
- Ampliar arnés antes de E2E real cuando aplique

## FASE 2: Bloques anidados
| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 2.1 | Mapear jerarquía real de bloques | **PENDIENTE** | Ejecutar `GetProjectTree` + `GetBlocks` sobre copia desechable y listar `blockPath`/`groupPath` únicos |
| 2.2 | Evaluar relajar ADR-015 restricción `groupPath == ''` | **PENDIENTE** | Decidir si bloques internos son viables con el mismo flujo o requieren ramificación distinta |
| 2.3 | Ajustar runner para rutas anidadas | **PENDIENTE** | Actualizar validación de `blockPath` y propuesta path si la FASE 2.2 lo permite |
| 2.4 | E2E anidado mínimo | **PENDIENTE** | Probar sobre copia con bloque anidado SCL; readback + gates idénticos a FASE 1.4 |

## FASE 3: UDT / PLC data types
| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 3.1 | Inspeccionar UDTs en inventario | **PENDIENTE** | Ejecutar analysis sobre copia desechable; detectar `typeName` distintos a FB/OB/DB |
| 3.2 | Evaluar viabilidad GenerateBlocksFromExternalSource | **PENDIENTE** | Determinar si UDTs admiten el mismo flujo import/generate/compile o son read-only |
| 3.3 | Documentar hallazgo | **PENDIENTE** | ADR/KB: soportar, inspeccionar-only o excluir con razón |

## FASE 4: Tags escritura
| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 4.1 | Auditoriar herramientas tia-create tags | **PENDIENTE** | Revisar esquema real: ¿existen ImportTags/GenerateTags/DeleteTags en tia-create V20? |
| 4.2 | Implementar propuesta tags mínima | **PENDIENTE** | Si hay herramientas, crear flujo: proposal + preflight + readback + gates idénticos a SCL |
| 4.3 | E2E tags mínima | **PENDIENTE** | Cambio único en tabla de tags copia desechable; verify readback, no guardar si mismatch |

## FASE 5: Librerías / multi-instancia / robustez
| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 5.1 | Probar librerías en proyecto | **PENDIENTE** | Ejecutar sobre proyecto con librería; validar resolución de blockPath ante librerías globales |
| 5.2 | Multi-instancia / llamados cruzados | **PENDIENTE** | Verificar WhereUsed/GetCrossReferences no se rompe; mantener solo lectura salvo evidencia distinta |
| 5.3 | Hardening mensajes BLOCKED/FAILED | **PENDIENTE** | Mejorar causas accionables (roster/identidad/compile mismatch) |
| 5.4 | Idempotencia/restauración probada | **PENDIENTE** | Procedimiento documentado: reimportar fuente original si falla cualquier paso |

## FASE 6: Cobertura por versión y cierre
| ID | Tarea | Estado | Evidencia |
|---|---|---|---|
| 6.1 | Matriz versión completa | **PENDIENTE** | Documentar V17-V19 si binarios disponibles; V20 ya tiene evidencia real |
| 6.2 | Arnés ampliado por tipo | **PENDIENTE** | Añadir casos por cada tipo soportado (FC, DB, anidados) a Test-TiaProposalApplyAttachedRoute.ps1 |
| 6.3 | Hardening final de gates | **PENDIENTE** | Revisar cero bypasses silenciosos; todos los `if` under review |
| 6.4 | Informe final capacidad | **PENDIENTE** | `docs/tia/07-estado-control-maximo.md`: **Soportado / Parcial / No soportado / Excluido por diseño** + evidencia para cada uno |

---
**Leyenda final**
- **Soportado**: verificado con evidencia real (E2E con readback, gates, fail-closed) 
- **Parcial**: implementado pero sin E2E real, o con limitaciones documentadas 
- **No soportado**: evaluado y descartado por diseño o riesgos inaceptables 
- **Excluido por diseño**: seguridad, sin hardware, sin download/online
