# ADR-007 — Estándares propuestos desde cero

- **Fecha:** 2026-09-14
- **Estado:** 🟡 Propuesta escrita, **pendiente de tu revisión**
- **Pregunta origen:** TDD Q12-Q19 — respuesta: *no tengo estándar aún, propón tú*

## Contexto

No hay un estándar previo del que partir, ni proyectos propios que analizar. Así que en vez de
hacerte rellenar formularios en abstracto, he escrito una propuesta completa y opinada.
Es más fácil corregir algo concreto que inventar de cero.

## Base usada

- **Siemens SCE** (Siemens Automation Cooperates with Education): el material formativo oficial,
  que es de facto lo que la mayoría de ingenieros españoles ha visto primero.
- **PLCopen**: convenciones de bloques reutilizables y separación mando/estado/parámetro.
- **ISA-5.1**: códigos de equipo (`M01`, `V12`, `PT01`), porque es lo que ya está en los P&ID y
  en los esquemas eléctricos. El software debe hablar el idioma del papel, no al revés.

## Decisiones con razón técnica (marcadas 🔒 en los documentos)

| Decisión | Por qué |
|---|---|
| Identificadores en inglés, comentarios en español | El proyecto cambia de manos; el comentario es para ti y tu compañero |
| Sin acentos ni ñ en identificadores | Openness, los exports XML y los nombres de fichero sufren |
| No numerar bloques a mano | Openness no tiene copy/move nativo: se emula con export+import y **el número viaja con el bloque**. Numerar a mano garantiza colisiones |
| Señales de seguridad como `_Ok`, no `_Fault` | Convención de contacto NC: si se rompe el cable, para. Nombrarlo al revés invita a escribir la lógica al revés |
| No usar la `Default tag table` | Crece hasta ser inmanejable, y Openness **no permite borrarla** |
| `90_Library` no se edita dentro del proyecto | La siguiente reimportación se lleva el cambio por delante |
| La tag de HMI se llama igual que la de PLC | Renombrarla es la forma más rápida de perder la trazabilidad |

## Decisiones que son puro gusto (marcadas 🔸)

Notación húngara (propuesta: no), `iDB_M01` vs `FB_Motor_M01` (propuesta: `iDB_M01`), prefijo de
área generalizado o solo en bloques de proceso (propuesta: solo en proceso).

## Cómo cerramos esto

Los estándares **no se validan leyéndolos**, se validan usándolos. El plan:

1. Tú respondes las 5 dudas del final de `20-standards/naming.md` y miras el árbol de
   `estructura-proyecto.md`. 15 minutos.
2. Generamos el primer proyecto real con ellos.
3. Lo que chirríe al verlo en TIA, se corrige. **Ahí** es donde se descubre lo que no funciona.

Hasta el paso 3 esto sigue siendo una hipótesis razonada, no un estándar probado, y así está
marcado en todos los documentos.
