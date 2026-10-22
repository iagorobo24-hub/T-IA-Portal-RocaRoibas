---
name: tia-analyze-project
description: Analiza un proyecto TIA Portal desde cero y entrega un dossier con las directrices del operario convertidas en checklist verificada. Usar cuando el usuario pide "analiza este proyecto", "qué hace este programa", "revisa este plano" o arranca el estudio de un proyecto nuevo o de terceros. Solo lectura: nunca muta el proyecto.
---

# tia-analyze-project — análisis completo con directrices del operario

> **Estado: BORRADOR.** Estructura definida; los pasos marcados ⚠ hay que ensayarlos de
> punta a punta antes de promocionar la skill. Las llamadas marcadas ⭐ ya están
> verificadas en recetas.

## Cuándo usarlo

- El usuario trae un proyecto `.ap20` (propio, de un ejemplo o de un cliente) y quiere
  entenderlo antes de tocarlo.
- El usuario da "directrices" o "cosas que quiero comprobar" en cualquier formato. Esta
  skill las convierte en checklist y cierra cada punto con evidencia.
- Nunca se combina con una tarea de escritura en la misma sesión.

## Antes de empezar

1. Cargar `AGENTS.md`; el análisis respeta su reparto de perfiles.
2. `Doctor` obligatorio. Si el grupo Openness es falso, parar y avisar.
3. Identificar el proyecto objetivo. Si TIA ya tiene otro abierto: no cerrarlo ni
   sustituirlo; consultar al usuario cómo seguir.
4. Recoger las directrices del usuario y fijarlas al principio del dossier, tal como
   llegó, para no reinterpretarlas a la hora de devolverlas.
5. Origen del proyecto: si es de cliente, separar hallazgos y exportaciones a `70-runs/`
   y no versionar nada sin autorización (AGENTS §3.4).

## Pasos

1. [⭐] Sesión MCP con `Invoke-McpToolSequence.ps1` (lease `Local\TIA-Claude-McpSession`):
   `Bootstrap` → `Connect` → `AttachToOpenProject` (u `OpenProject` si no hay instancia).
2. [⭐] `GetProjectTree`: las rutas reales de todo el dossier salen de aquí.
3. [⭐] `GetSoftwareTree` por cada PLC: bloques, tipos, tags, watch y fuentes.
4. [⭐] Metadatos de seguridad en la misma sesión: `GetBlocks.isFailsafe` +
   `GetTags.isSafety`. Sin ambas, el dossier queda incompleto y se declara.
5. [⭐] `GetDeviceInfo` por CPU: modelo exacto. La "F" de una CPU de seguridad aparece
   aquí (o en el árbol de la GUI) y manda parar y avisar.
6. [⚠] `GetCrossReferences` con `maxDepth` progresivo (1, luego 2-3): mapa de llamadas.
7. [⚠] Export textual a `70-runs/<fecha>-<proyecto>-analisis/` de lo que el perfil
   permita; el árbol completo no siempre exporta: se documenta lo exportado.
8. [⚠] Inventario de hardware y red; solo se recurre a la GUI (candado del playbook) si
   la API no da el dato que una directriz exige.
9. [⚠] Dossier con `Invoke-TiaProjectAnalysis.ps1 -InventoryPath <json> -SourceRoot <export>
   -Objective "<resumen de las directrices>"`.

## Verificación

- Cada directriz queda clasificada: **verificado / supuesto / no verificado / bloqueado**,
  con la evidencia (llamada y respuesta) a su lado.
- Entrega: dossier Markdown en `70-runs/` y resumen corto en la conversación.
- Un hallazgo sin llamada que lo sustente no es un hallazgo: se retira o se marca supuesto.

## Si falla

| Fallo | Acción |
|---|---|
| Openness no puede abrir el proyecto | se informa; no se cierra nada ya abierto |
| `GetSoftwareTree` corta o gigante | pedir por `sections`; no pedir todo de golpe |
| Directrices incompletas | volver al usuario antes de seguir actuando |
| Aparece F/Safety u otra protección | se para: se analiza, pero esas piezas no se tocan |

## Referencias

- Fundamento: `10-kb/00-fundamentos/tia-interfaz-y-computer-use.md`
- Límites de la API: `10-kb/10-openness/limites.md`
- Receta: `10-kb/20-recetas/R04-entender-un-bloque.md`
