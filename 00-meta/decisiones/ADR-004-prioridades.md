# ADR-004 — Orden de construcción de la base de conocimiento

- **Fecha:** 2026-09-14
- **Estado:** ✅ Aceptada
- **Pregunta origen:** TDD Q26 — respuesta: **las cuatro opciones marcadas**

## Contexto

Marcaste las cuatro: lógica repetitiva, estructura inicial + tags, entender proyectos ajenos,
y HMI + documentación. Es una respuesta legítima —duele todo— pero no ordena el trabajo, así que
lo ordeno yo por un criterio explícito y lo pongo aquí para que puedas discutirlo.

## Criterio: valor entregado ÷ riesgo técnico

| # | Área | Valor | Riesgo | Por qué ahí |
|---|---|---|---|---|
| **1** | **Entender proyectos ajenos** | Alto | **Bajo** | Solo lectura. Cero riesgo de romper nada, y `tia-inspect` ya está compilado y funcionando. Se puede usar **mañana**. |
| **2** | **Estructura inicial + tags** | Alto | Bajo-medio | Muy repetitivo, muy reglado, fácil de validar (compila o no). `ScaffoldProject` lo cubre casi entero. |
| **3** | **Lógica repetitiva** | **Muy alto** | Medio | Es donde más tiempo ganas, pero depende de que existan tus estándares (M4) y tu librería de bloques (`60-library/`). Sin eso el agente genera código correcto pero que no es *el tuyo*. |
| **4** | **HMI y documentación** | Medio | **Alto** | WinCC Unified por `designJson` es lo menos maduro de los dos servidores, y la documentación depende de plantillas tuyas que aún no tenemos. |

## Decisión

Escribir `10-kb/20-recetas/` en ese orden. Concretamente:

**Tanda 1 — leer y entender** (sirve desde el día 1, sin tus estándares)
- `R01-inventariar-proyecto.md` — árbol, PLCs, bloques, tags, resumen
- `R02-donde-se-usa.md` — cross-references, `WhereUsed`, `FindInCode`
- `R03-exportar-a-git.md` — export textual `.s7dcl` y primer commit
- `R04-entender-un-bloque.md` — interfaz, dependencias, qué hace

**Tanda 2 — esqueleto y tags**
- `R05-proyecto-nuevo-desde-cero.md` — `ScaffoldProject` con tu plantilla
- `R06-tablas-de-tags.md` — desde lista de E/S a tabla importada
- `R07-udts-y-dbs.md`

**Tanda 3 — lógica** (bloqueada por M4, tus estándares)
- `R08-bloque-motor.md`, `R09-bloque-valvula.md`, `R10-secuencia.md`
- `R11-modos-manual-auto.md`, `R12-gestion-alarmas.md`

**Tanda 4 — HMI y docs**
- `R13-pantalla-unified.md`, `R14-binding-tags-hmi.md`
- `R15-generar-lista-es.md`, `R16-descripcion-funcional.md`

## Cómo cambiar esto

Si tienes un proyecto real con fecha, este orden salta por los aires y se reordena para servirlo.
Dímelo y lo rehago.
