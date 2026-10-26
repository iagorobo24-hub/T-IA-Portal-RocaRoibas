---
name: tia-error-triage
description: Diagnostica errores de TIA Portal, Openness, MCP, compilación o scripts de este workspace consultando primero el catálogo de errores y los límites de la API. Usar cuando el usuario pega un error, algo compila mal, la sesión MCP falla, hay mensajes del tipo "por qué no funciona" o "qué significa este mensaje". Convierte cada error no catalogado en un hallazgo documentado en lugar de improvisar.
---

# tia-error-triage — triaje de errores con el catálogo

> **Estado: BORRADOR.** El catálogo (`10-kb/50-errores/README.md`) es el motor real; la
> skill su buena es la guía de orden de consulta y el hábito de documentar lo nuevo.

## Cuándo usarlo

- Cualquier mensaje de error de un,
  - un MCP tooling (ej. `Connect to module failed`, `NotReachable`, `SREC_NOT_UP_TO_DATE`),
  - un script PowerShell,
  - el compilador de TIA (ó a la inversa: errores extraños sin línea).
- El usuario dice "no va", "falla", "se queda colgado".

## Antes de empezar

1. Leer el mensaje completo (incl. InnerException): la clase del error (`NotFound`,
   `InvalidParams`, `NotSupported`, `ExportFailed`, `SREC_*`) indica la acción.
2. No reintentar a ciegas un error que mencione seguridad, F/Safety o protecciones:
   se informa y se para (AGENTS §3.3).

## Pasos

1. [⭐] **Antes de reintentar nada**, buscar el síntoma en `10-kb/50-errores/README.md`
   (arranque → lectura → escritura → sesión → PLCSIM/aceptación → scripts, y las
   entradas fechadas del final). Si está, aplicar ese arreglo. Si no está y se
   resuelve, añadirlo ahí en el mismo momento.
2. [?] Si el sintoma esta en `50-errores` con arreglo medido: aplicarlo y comprobar.
3. [⚠] Si no está: reproducir mínimo, separar causa-hipótesis-evidencia; con la respuesta
   completa de llamada/resultado en `70-runs/<fecha>-triage/`.
4. [⚠] Si el fix se encuentra: documentar **de inmediato** en `50-errores` con el formato
   estandarizado (síntoma, causa, diagnóstico, arreglo, prevención) y commitearlo.
5. [⚠] Si fuese límite de la API (no un defecto propio): salir con *"es un límite de
   Openness"* y con la vía alternativa que sí puede hacerse.

## Verificación

- La respuesta al usuario clasifica: error conocido (con el arreglo) / límite de API /
  hallazgo nuevo (con documentación añadida).
- Si se repite cada error novo: catálogo actualizado y número correcto en el commit.

## Si falla

- El error reaparece tras aplicar el arreglo conocido → no es el mismo; registrar la
  diferencia de contexto, buscar de nuevo, documentar si toca.
- No se puede reproducir → se declara suposición, no hay documentación con dos bases.

## Referencias

- `10-kb/50-errores/README.md` (catálogo)
- `10-kb/10-openness/limites.md`
