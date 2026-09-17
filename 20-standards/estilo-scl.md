# Estilo SCL

> **Guía completa:** [`10-kb/30-lenguajes/scl.md`](../10-kb/30-lenguajes/scl.md) — ejemplo de
> bloque entero, antipatrones y estado de UDTs. Esta página es la referencia corta citable en
> revisión de código; si difieren, la guía completa manda porque es la más reciente.
>
> ✅ Las reglas marcadas *Verificado* salieron de compilar de verdad los cinco bloques de
> [`60-library/blocks/`](../60-library/blocks/) en TIA V20 — todos con 0 errores y 0 advertencias.

## Checklist de revisión

### Formato
- Sangría de 3 espacios, no tabuladores. Una instrucción por línea. Palabras clave en MAYÚSCULAS.
- 🔒 `REGION`/`END_REGION` en vez de comentarios de separación — se pliegan en el editor, un
  `//-----` no.

### Contenido
- 🔒 Nada de números mágicos: constante de usuario o parámetro con valor por defecto.
- 🔒 Una salida se escribe **en un solo sitio, al final del bloque, y nunca se lee**. ✅
  *Verificado*: leerla antes produce `The parameter '#X' might not be initialized.` en el
  compilador — no es preferencia.
- 🔒 El paro y el fallo mandan sobre la marcha, siempre: la rama que desactiva va primero en el
  `IF`.
- 🔸 `CASE` mejor que cadenas de `ELSIF` para máquinas de estado; numera los pasos de 10 en 10.

### Comentarios
- En español, explican *por qué* no *qué*. Cabecera obligatoria (qué hace, cómo falla, qué
  supone). Cada `VAR_INPUT`/`VAR_OUTPUT` comentado en su línea.

### Lo que no se hace
- ❌ Acceso absoluto (`%MW100`), `GOTO`, bucles sin cota superior, bloques de más de ~200 líneas.

## Cómo llega el SCL al proyecto

| Camino | Cuándo | Cómo |
|---|---|---|
| Fuente externa | SCL complejo, `FOR`/`CASE`/expresiones largas | `ImportPlcExternalSource` → `GenerateBlocksFromExternalSource` |
| Documento SIMATIC SD | Edición de un bloque existente, flujo de git | `.s7dcl` ↔ `GetBlockSource`/`ImportFromDocuments` (requiere V20+) |

Detalle, ejemplo completo y antipatrones: [`10-kb/30-lenguajes/scl.md`](../10-kb/30-lenguajes/scl.md).
