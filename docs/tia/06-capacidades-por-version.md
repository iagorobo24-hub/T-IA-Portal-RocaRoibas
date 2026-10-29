# Capacidades por versión - TIA Portal Agent

> Estado: VIVO | Última actualización: 2026-10-29 | Enfoque: V20 verificado, resto por validar

## Leyenda
- **SO** = Soportado (verificado con evidencia real o arnés que cubre el caso)
- **PA** = Parcial (implementado o parcialmente, falta E2E real)
- **PV** = Pendiente de validar
- **PD** = Pendiente de desarrollar
- **EX** = Excluido por diseño (seguridad)
- **ND** = No disponible / desconocido

## Matriz por funcionalidad

| Funcionalidad | V17 | V18 | V19 | V20 | Notas |
|---|---|---|---|---|---|
| **Ruta aislada (fixture)** | PV | PV | PV | SO | Verificado en arnés + uso previo |
| **Ruta adjunta (-Route attached)** | PV | PV | PV | SO | Identidad/roster/gates/readback verificados en V20 |
| **Bloque FB raíz SCL** | PV | PV | PV | SO | Caso base verificado |
| **Bloque FC raíz SCL** | PV | PV | PV | PD | FASE 1 |
| **Bloque OB raíz SCL** | PV | PV | PV | PD | FASE 1 |
| **Bloque DB (Data Block)** | PV | PV | PV | PD | Requiere evaluación caso a caso |
| **Bloques anidados** | PV | PV | PV | PD | FASE 2 (actualmente bloqueado por ADR-015) |
| **UDT / PLC data types** | PV | PV | PV | PD | FASE 3 (viabilidad a determinar) |
| **Tags - solo lectura + gates** | PV | PV | PV | PA | Gates implementados, falta escritura |
| **Tags - escritura/edición** | PV | PV | PV | PD | FASE 4 |
| **Librerías globales/proyecto** | PV | PV | PV | PD | FASE 5 |
| **Multi-instancia** | PV | PV | PV | PD | FASE 5 |
| **HMI** | PV | PV | PV | PD/EX | Mayormente fuera de alcance actual |
| **Redes/IO/Hardware config** | ND | ND | ND | EX | Excluido por diseño |
| **Descarga a CPU / GoOnline** | ND | ND | ND | EX | Excluido por diseño |
| **PLCSIM (descarga/carga)** | ND | ND | ND | EX | Excluido por diseño |
| **Bloques Failsafe** | PV | PV | PV | SO | Bloqueados por gates (fail-closed) |
| **Bloques KnowHowProtected** | PV | PV | PV | SO | Bloqueados por gates (fail-closed) |
| **Bloques inconsistentes** | PV | PV | PV | SO | Bloqueados por gates (fail-closed) |
| **Readback vivo + verificación** | PV | PV | PV | SO | Implementado + probado con mismatch |
| **Veto cabeceras ignoradas (VERSION/AUTHOR/FAMILY/TITLE)** | PV | PV | PV | SO | Confirmado con sondas reales 2026-10-29 |
| **Compile gate (0/0)** | PV | PV | PV | SO | Implementado |

## Notas
- V20 es el único con verificación real en proyecto abierto + sondas de cabeceras.
- Cualquier ampliación debe mantener: gates, readback, fail-closed, copia desechable, sin hardware.
- "PD" significa no implementado aún, **no** significa "imposible". Se abordará por fases.
