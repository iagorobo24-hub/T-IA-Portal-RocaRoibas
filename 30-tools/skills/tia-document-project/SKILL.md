---
name: tia-document-project
description: Genera o actualiza la documentación automática de un proyecto TIA Portal ya abierto y leído. Usar cuando el usuario pide "documenta el programa", "genera el README del proyecto", "hazme el mapa de llamadas", "tabla de señales" o quiere documentación viva antes de una obra o revisión. No inventa nada: todo sale del readback de la sesión.
---

# tia-document-project — documentación automática desde el readback

> **Estado: BORRADOR.** Los pasos de bloque funcionan (exportación verificada en
> proyectos pasados); la composición del documento único es lo que falta ensayar.

## Cuándo usarlo

- Antes de una obra: el operario necesita material de apoyo del programa actual.
- Después de una sesión de cambios: la documentación queda al día con el commit.
- Cualquier petición del tipo "no entiendo este programa": primero se lee, luego se
  documenta, y la explicación se respalda con el documento.

## Antes de empezar

1. `AGENTS.md` cargado y `Doctor` en verde; sesión MCP active.
2. Proyecto identificado y adjuntado (Attach si hay ventana; nunca segunda instancia).
3. Si el proyecto es de cliente: lo generado va a `70-runs/` y no se versiona sin
   autorización (AGENTS §3.4); los nombres de cliente se anonimizan si se extrae algo
   a la librería.

## Pasos

1. [⭐] `GetProjectTree` + `GetSoftwareTree`: esqueleto del documento.
2. [⭐] `GetBlocks` + `GetBlockSource` por bloque: cabecera, estado, lenguajes, comentarios.
3. [⭐] Fuentes ya exportadas a `src/` si el proyecto es propio: son la base, no se
   re-exporta lo ya presente salvo que el bloque cambie.
4. [⭐] F/Safety` y know-how: el documento los declara como *no tocables* antes de
   describirlos más allá de la interfaz.
5. [⚠] Mapa de llamadas con `GetCrossReferences` (progresivo en profundidad) y diagrama
   de invocaciones en texto (mermaid,formato por decidir en el ensayo).
6. [⚠] Tabla de señales: entradas/salidas del PLC y su uso por bloque; creada desde
   export de tabla de tags verificado (R24) para no leer a ciegas.
7. [⚠] Ensamblar el documento: README del proyecto con objetivo, inventario, mapa,
   señales, hallazgos y changelog apuntando a commits; se guarda en `40-projects/<x>/docs/`
   o `ops/` según estructura estándar (ver estructuración en 20-standards).
8. [⚠] Espejo en `50-examples/` solo si el proyecto es demo propio, según ADR-005.

## Verificación

- Cada frase técnica del documento rastrea a una llamada o export citado en un colofón
  de fuentes.
- Se imprime el número de bloques, tags y pantallas: el lector puede recortar el conteo
  contra TIA en dos clics.
- Cero texto "de desarrollador" generado por intuición: si una sección no tiene fuente,
  sale con la etiqueta *(sin verificar)*.
- Al terminar: MCP `GetState` + 0 errores en readback, para asegurar que la lectura no
  dejo nada en modo raro.

## Si falla

| Fallo | Acción |
|---|---|
| Un bloque no exporta o no se puede leer | declared en el documento con motivo real |
| La sesión se corta a mitad | se guarda el esqueleto ya hecho y se mascara lo que falta |
| El usuario quiere verter palabras (opiniones) en el doc | se van a una sección separada con autoría explícita, no se meten como técnico |

## Referencias

- Recetas: `R04-entender-un-bloque.md`, `R24-tabla-tags-offline.md`
- Estándar: `20-standards/estructura-proyecto.md`
