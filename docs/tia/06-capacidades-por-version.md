# Capacidades por versión - TIA Portal Agent

> Estado: VIVO | Última actualización: 2026-10-29 (corregido tras reauditoría) | Enfoque: V20 con evidencia real parcial, resto por validar

## Leyenda

- **SO** = Soportado (verificado con evidencia real de ejecución)
- **PA** = Parcial (implementado y probado en arnés, o verificado solo por partes; falta E2E)
- **PV** = Pendiente de validar (hay binario, no hay evidencia)
- **PD** = Pendiente de desarrollar (no implementado)
- **EX** = Excluido por diseño (seguridad)
- **ND** = No disponible / desconocido

> Regla: un PASS de arnés mock **no** asciende una fila a **SO**.

## Matriz por funcionalidad

| Funcionalidad | V17 | V18 | V19 | V20 | Notas |
|---|---|---|---|---|---|
| **Lectura de proyecto (árbol, bloques, fuentes)** | PV | PV | PV | SO | Evidencia live en `70-runs/live-read` y `70-runs/analysis` |
| **Ruta aislada (fixture) — lectura/export** | PV | PV | PV | SO | `tia-inspect --isolated --fixture-root`; manifiesto validado |
| **Ruta aislada — escritura** | PV | PV | PV | PA | Staging y gates probados; mutación bloqueada por roster de importadores |
| **Ruta adjunta (`-Route attached`)** | PV | PV | PV | PA | Identidad/roster/gates/readback verificados **en arnés**; E2E live pendiente (ADR-018) |
| **Bloque FB raíz SCL** | PV | PV | PV | PA | Arnés PASS; E2E live con la puerta nueva pendiente |
| **Bloque FC raíz SCL** | PV | PV | PV | PA | Mapeo `FUNCTION→FC` + arnés PASS; sin E2E live |
| **Bloque OB raíz SCL** | PV | PV | PV | PA | Mapeo `ORGANIZATION_BLOCK→OB` + arnés PASS; sin E2E live |
| **Bloque DB (Data Block)** | PV | PV | PV | PD | `Assert-TiaCreateBlockWritable` lo rechaza: sin evidencia de generación |
| **Bloques anidados** | PV | PV | PV | PD | Ruta adjunta los rechaza (`groupPath` no verificado); ruta aislada solo los estagia |
| **UDT / PLC data types** | PV | PV | PV | PD | `ImportType`/`BuildPlcUdtXml` existen; falta proyecto con UDTs y verificación |
| **Tags - solo lectura + gates** | PV | PV | PV | SO | `GetTags`/`ExportPlcTagTable` + veto Safety global |
| **Tags - escritura/edición** | PV | PV | PV | PA | Runner `Invoke-TiaTagProposalApply.ps1` + 69 aserciones de arnés; E2E live pendiente (ADR-019) |
| **Librerías globales/proyecto** | PV | PV | PV | PD | Sin proyecto de prueba con librerías |
| **Multi-instancia / referencias cruzadas** | PV | PV | PV | PD | Solo lectura prevista; sin fixture |
| **HMI Unified** | PV | PV | PV | PA | PLC verificado; HMI exige runtime de la misma versión (ADR-017) |
| **Redes/IO/Hardware config** | ND | ND | ND | EX | Fuera de alcance |
| **Descarga a CPU virtual (PLCSIM Advanced)** | ND | ND | ND | SO | ADR-015: `FB_AlarmLatch` 65/65, `FC_Escalado` 33/33 |
| **Descarga a hardware físico / GoOnline** | ND | ND | ND | EX | Requiere confirmación explícita en el momento |
| **Bloques Failsafe** | PV | PV | PV | SO | Bloqueados por gates (fail-closed) |
| **Bloques KnowHowProtected** | PV | PV | PV | SO | Bloqueados por gates (fail-closed) |
| **Bloques inconsistentes** | PV | PV | PV | SO | Bloqueados por gates (fail-closed) |
| **Readback vivo + verificación de contenido** | PV | PV | PV | PA | Implementado y probado con mismatch/truncado/crash en arnés; falta E2E live |
| **Veto de cabeceras ignoradas (VERSION/AUTHOR/FAMILY/TITLE)** | PV | PV | PV | SO | Sondas reales 2026-10-29: Openness V20 las ignora y el gate bloquea el guardado |
| **Compile gate (0 errores / 0 avisos)** | PV | PV | PV | SO | Implementado y ejercitado en vivo |

## Notas

- V20 es el único con verificación real. V17-V19 no tienen binario en esta máquina.
- Cualquier ampliación debe mantener: gates, readback, fail-closed, copia desechable, sin hardware.
- "PD" significa no implementado aún, **no** significa "imposible".
- El detalle de cada clase y su evidencia está en `docs/tia/07-estado-control-maximo.md`.
- El plan y los pendientes están en `docs/tia/07-seguimiento-fases.md`.
