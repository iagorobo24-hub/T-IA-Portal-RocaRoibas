---
name: tia-hmi-screen
description: Programa o modifica pantallas HMI (WinCC Unified y Comfort) en TIA Portal: creación desde JSON, comprobación del contrato de pantalla, y simulación con el runtime de la versión exacta de TIA. Usar cuando el usuario pide "programa una pantalla", "crea una HMI", "añade el indicador en pantalla", "cambia el diseño de la HMI" o cualquier trabajo de visualización de operación.
---

# tia-hmi-screen — programación de pantallas HMI

> **Estado: BORRADOR MUTANTE.** Crear desde JSON está verificada; editar pantallas
> existentes y el ensayo de simulación final están pendientes del runtime correcto
> (ADR-017: mis misma versión que TIA Portal).

## Cuándo usarlo

- "Necesito una pantalla nueva" / "cambia el layout" / "añade un indicador de estado".
- Todo trabajo de interfaz de operario con WinCC Unified (o Comfort, con su receta).

## Antes de empezar

1. `AGENTS.md` cargado; `Doctor` en verde; sesión MCP activa.
2. Verificar la coppia **TIA / runtime**: sin el runtime de la misma versión que TIA no
   se puede simular; la skill lo explica y si no alcanza, para avisando el instalador
   que falta (ADR-017, R31).
3. Confirmar con el usuario el listado de elementos, los tags de PLC que leerán/acción
   y cualquier limitación de ventana/Tamaño antes de escribir en pantalla.

## Pasos

1. [⭐] Análisis del contexto: PLC al que atará, tags de conexión e HMI existente
   (`GetProjectTree` + `GetSoftwareTree` en la rama HMI; exportar tags si hace falta).
2. [⭐] Pantalla nueva desde JSON con `Invoke-TiaHmiScreenFromJson.ps1` (verified creación
   pura): layout, elementos, bindings de tag, nav.
3. [⭐] Contrato 14/14 con `Invoke-TiaHmiContractCheck.ps1`: propiedad de los elementos,
   binds y navegación sincronizados con el PLC. No pasa contrato → no se declara terminado.
4. [⚠] Compilación 0/0 del HMI y del PLC en el mismo ciclo.
5. [⚠] Simulación: `Start downloading to device` para HM_RT_1 con wizard: si no arranca
   process runtime en ~10 s, rastrear con los pasos del R31: al comunicado exacto el
   `GfxRTS.exe` nuevo procese instalado, sin proponer trabalenguas.
6. [⚠] Pruebas de navegación y textos por el candado de la GUI (skill `tia-gui-click`)
   donde la API no presenta el renderizado.
7. [⭐] Export + espejo `50-examples/` (proyectos demo) + commit.

## Verificación

- La pantalla existe con el número de elementos, binds y navegación declarados; el
  contrato 14/14 y la compilación 0/0 están citados con números.
- Si la simulación en runtime no se consiguió, se declara que la pantalla está aprobada
  *tal vez* pero no probada en runtime (sin fingirlo).

## Si falla

| Fallo | Acción |
|---|---|
| Runtime no coincide (V19 con TIA V20) | parar la simulación; la pantalla no queda aprobada se expone el instalador pendiente |
| La pantalla falla contrato | ninguna salida cursa: se ajustan los elementos o se deshace el cambio |
| Pantalla de Comfort legada | no entrar por Unified: ejecutar el receta que toca para Comfort concretas |

## Referencias

- Recetas: `R31-simulacion-plcsim-unified.md`, `R13`/`R14`/`R20` (HMI Comfort/Advanced)
- ADR-017: runtime = misma version que TIA
