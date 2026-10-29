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

## Próxima acción
**Empezar FASE 1.1:** Inventariar bloques FC/OB disponibles en copia desechable y evaluar viabilidad con `GetBlocks`.

## Reglas
- Un bloque por vez
- Siempre copia desechable
- Fail-closed ante duda
- Readback obligatorio en mutación
- Documentar todo con evidencia
- Sin hardware/download/online
- Ampliar arnés antes de E2E real cuando aplique
