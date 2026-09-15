# ADR-002 — Versión de TIA Portal objetivo

- **Fecha:** 2026-09-14
- **Estado:** ⚠️ Aceptada con una corrección respecto a lo pedido
- **Pregunta origen:** TDD Q3 — respuesta: *"ambas, conmutables"*

## Decisión

**V20 es la versión operativa hoy. V19 queda conmutable en el diseño pero no está soportada
todavía, y soportarla cuesta más de lo que parecía.**

El script `30-tools/mcp/tia-inspect/build.ps1` ya acepta `-TiaMajor` y tiene el mapa de paquetes
NuGet para 19, 20 y 21, así que la conmutación está preparada estructuralmente. Lo que falta es
el trabajo de compatibilidad de V19.

## Por qué V19 no sale gratis

Compilado y medido, no supuesto:

| Objetivo | Resultado |
|---|---|
| **V20** | ✅ 0 errores tras un parche de 2 líneas |
| **V19** | ❌ ~15 errores `CS0246` concentrados en la API de documentos |

Los tipos `ImportDocumentOptions` y `DocumentExportResult` **no existen en Openness V19**. Son
toda la funcionalidad de **documentos SIMATIC SD** (`.s7dcl` / `.s7res`), repartida por
`Portal.Documents.cs`, `Portal.cs` y `McpServer.cs`.

Y ahí está la ironía: **esa es exactamente la funcionalidad que hace que versionar en git sirva
de algo.** Todo lo demás que exporta Openness es XML SimaticML, que diffea fatal.

Es decir: un `tia-inspect` para V19 sería un `tia-inspect` **sin la razón principal para usarlo**.

## Consecuencias

- Todo el workspace (estándares, plantillas, recetas) se escribe asumiendo **V20**.
- Los ejemplos V16 se migran a **V20**.
- **V19 queda como trabajo pendiente explícito**, no como algo olvidado: hay que envolver la
  funcionalidad de documentos en `#if TIA_V20_PLUS` (~10 puntos de llamada en 3 ficheros) y
  hacer que esas herramientas devuelvan `NotSupported` en V19. Estimación: 2-3 h.
- `bulaofen` (el motor de creación) tampoco soporta V19: su bundle es **V20 y V21**. Así que en
  V19 te quedarías sin los dos motores, no solo sin uno.

## Pregunta abierta para ti

¿Para qué necesitas V19 exactamente?

- **a)** Tienes proyectos vivos de cliente en V19 que no se pueden migrar → entonces sí merece
  la pena invertir las 2-3 h, sabiendo que pierdes el export textual.
- **b)** Es solo que está instalado y prefieres no cerrar la puerta → entonces no invirtamos
  ahora; el `build.ps1` ya está preparado y se hace el día que haga falta.

Mientras no respondas, asumo **(b)** y sigo con V20.
