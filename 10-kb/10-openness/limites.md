# Lo que Openness NO puede hacer

> Estos no son fallos de los servidores MCP: son huecos de la propia API de Siemens.
> Saberlos de antemano ahorra horas intentando algo imposible y culpando a la herramienta.
>
> Fuente: limitaciones documentadas por el autor de `tia-inspect`, contrastadas con los snippets
> oficiales de Siemens.

## Bloques

### ❌ No existe "crear bloque" genérico

📄 Solo hay dos constructores: **`CreateFB`** y **`CreateInstanceDB`**.

Todo lo demás — OB, FC, DB global, ArrayDB — **solo puede entrar por importación**:

```
opción A:  ImportBlock              desde XML SimaticML
opción B:  ImportPlcExternalSource  →  GenerateBlocksFromExternalSource   (SCL)
opción C:  ImportFromDocuments      desde .s7dcl + .s7res   (V20+)
```

🔒 **Consecuencia práctica:** cuando el usuario pida "crea un FC que haga X", el camino es
**escribir el SCL y generarlo desde fuente externa**, no buscar una herramienta `CreateFC` que
no existe.

### ❌ No existe copiar ni mover bloques

📄 `CopyBlock`, `MoveBlock`, `CopyType` y `MoveType` de `tia-inspect` están **compuestos** a
mano: exportar → importar → (para mover) borrar el origen.

Eso tiene dos consecuencias visibles que hay que anticipar:

1. **El bloque tiene que estar consistente.** TIA se niega a exportar un bloque inconsistente,
   así que hay que **compilar antes**.
2. 🔴 **El número de bloque viaja con él.** Copiar dentro del mismo PLC puede chocar con un
   número ya ocupado. Es la razón de la regla de [`20-standards/naming.md`](../../20-standards/naming.md):
   no numerar bloques a mano.

📄 Tampoco se puede **renombrar durante una copia**: implicaría reescribir el XML exportado.

### ❌ Los bloques inconsistentes no se exportan

📄 TIA nunca exporta algo inconsistente. En exportación individual sale `InvalidParams` con un
mensaje que dice que compiles primero. En exportación masiva, los inconsistentes **se saltan** y
vuelven en una lista `Inconsistent` aparte de `Items`.

> ⚠️ **Cuidado con esto en una exportación masiva:** si no miras la lista `Inconsistent`, creerás
> que exportaste todo el PLC cuando te has dejado bloques fuera. Compruébala siempre.

---

## Tablas de observación y forzado

| Limitación | Detalle |
|---|---|
| ❌ Sin entradas de tabla de observación | 📄 La composición de Openness solo expone un creador de filas de comentario. Añadir una entrada real requiere una llamada de creación sin tipar |
| ❌ La tabla de forzado no se crea ni se borra | 📄 El sistema mantiene una por PLC |
| ❌ Renombrar tabla de observación | ✅ **Verificado compilando:** `PlcWatchTable.Name` es de **solo lectura** antes de V21. Es uno de los parches que lleva nuestro build (ADR-002) |
| ❌ Sin referencias cruzadas | 📄 Para tablas de observación, forzado y fuentes externas, `GetCrossReferences` devuelve `NotSupported` |

---

## Objetos de solo lectura

📄 No se pueden crear, cambiar ni borrar:

- **Constantes de sistema**
- **Tabla de forzado** (una por PLC, la crea el sistema)
- **Tabla de tags por defecto** — no se puede borrar
- **Grupos de sistema** (`Program blocks`, `PLC data types`, `PLC tags`...) — ni renombrar ni borrar

Todos fallan con `NotSupported`, que al menos es un error claro.

---

## Protección y seguridad

### 🔒 Bloques con know-how protection

📄 Se rechazan **antes** de cualquier edición, con un mensaje pidiendo quitar la protección desde
TIA. El agente no puede saltarse esto, y no debe intentarlo: está en `AGENTS.md` §3.3.

### 🔒 Programa de seguridad (F-blocks)

Siemens documenta importación y exportación de F-blocks mediante Openness V20, además de una API
relacionada con firmas Safety. Por tanto, **no se debe depender de que TIA/Openness rechace una
escritura F**. Que una operación esté documentada no la autoriza en este workspace.

> Regla local: **el agente no lee para modificar, importa, edita, borra, compila como parte de un
> cambio ni descarga F-blocks o tags Safety.** La escritura debe rechazarse en una barrera
> independiente antes de llamar a la API. Si el tipo Safety no puede clasificarse explícitamente,
> se para. Ante un error de protección o Safety no se reintenta.

Referencias: Siemens, [exportar F-blocks en Openness V20](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/importing/exporting-data-of-a-plc-device/blocks/exporting-failsafe-blocks?contentId=IsqKGWiwDrgkeO8LIjZWJA)
y [SafetySignatureProvider](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/tia-portal-openness-api/f-related-openness/safetysignatureprovider).

---

## Versiones — formatos y evidencia

La documentación de Siemens distingue el formato por versión y tipo de objeto. No extrapolar una
capacidad de una versión de TIA, de un modelo HMI o de una implementación MCP a los demás.

| Funcionalidad | Documentación Siemens | Evidencia local de esta sesión |
|---|---|---|
| SIMATIC SD (`.s7dcl`/`.s7res`) para bloques LAD puros, DB y tipos PLC | Disponible en V20; la ayuda V20 base describe LAD, DB y tipos PLC. | No se hizo round-trip local de UDT. |
| SIMATIC SD para bloques SCL/FBD y redes mixtas | Ampliado en **TIA V20 Update 4**. | `tia-create 2.7.2` recibió rechazo al exportar el FB SCL de prueba: “export or import of blocks with mixed programming languages is not possible”. Se conservó el XML de Openness como respaldo. No se verificó el nivel de actualización instalado ni otro bloque SCL. |
| Exportación XML SimaticML | Openness V20 documenta PLC/HMI y recalca que el formato es interno y exclusivo de la versión actual. | `ExportBlock` generó XML del FB de prueba; inspección y readback independientes. |
| Importar/actualizar proyectos antiguos | `Projects.OpenWithUpgrade` actualiza proyectos de la versión anterior; una versión más antigua puede dar excepción. | En este workspace se midió un proyecto V16 concreto; no se considera prueba general para todas las rutas V16→V20. |

Referencias: Siemens, [principios de importación/exportación Openness V20](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/overview/basic-principles-of-importing/exporting), [bloques SIMATIC SD V20](https://docs.tia.siemens.cloud/r/en-us/v20/creating-and-managing-blocks/exporting-and-importing-blocks-in-simatic-sd-format-s7-1200-s7-1500/exporting-and-importing-blocks-in-simatic-sd-format-s7-1200-s7-1500), [mejoras de V20 Update 4](https://docs.tia.siemens.cloud/r/en-us/v20-updates/tia-portal-updates-readme/improvements-in-step-7/improvements-in-update-4), y [apertura de proyectos V20](https://docs.tia.siemens.cloud/r/en-us/v20/tia-portal-openness-api-for-automation-of-engineering-workflows/tia-portal-openness-api/functions-for-projects-and-project-data/opening-a-project).

El export/import de formatos XML y SIMATIC SD depende de la versión y de las capacidades del
objeto. Que Openness lo documente no demuestra que un servidor MCP concreto exponga esa llamada o
que una llamada determinada funcione en la instalación local.

---

## Rarezas concretas que muerden

### ⚠️ Importar LAD desde documentos SD

📄 *(Limitación conocida de Openness, documentada 2025-09-02)*

Importar bloques **LAD** desde documentos SIMATIC SD exige que el `.s7res` acompañante contenga
etiquetas **en-US** para todos los elementos. Si no, la importación falla.

🔴 Esto afecta directamente al flujo "editar LAD en git y devolverlo a TIA". Es otra razón
más de la regla de [ADR-003](../../00-meta/decisiones/ADR-003-lenguajes.md): **SCL para la
lógica**. El SCL no tiene este problema.

⚠️ **Sin confirmar en esta máquina.** Hay que probarlo con un bloque LAD real. Es una de las
primeras cosas a verificar cuando Openness funcione.

### ⚠️ Exportación masiva de LAD y SCL mezclados

✅ **Verificado en V20 durante la aceptación del scaffold.** `ExportBlocksAsDocuments` puede
rechazar un conjunto que contenga bloques con lenguajes de programación mezclados, devolviendo
un error explícito sobre la imposibilidad de exportar/importar bloques de distintos lenguajes en
la misma operación. No se debe interpretar ese fallo como que el bloque no existe ni como que el
proyecto está dañado.

El fallback determinista es exportar el bloque individual con `tia-inspect.ExportBlock` a XML
SimaticML y conservar el error de la exportación masiva en el informe. Para una exportación
textual diffeable, separar los bloques por lenguaje y validar cada grupo; el XML individual es
un respaldo de inspección, no sustituye al `.s7dcl/.s7res` de V20.

### ⚠️ Nombre de tipo único en todo el PLC

📄 Un nombre de tipo de datos PLC es único **en todo el PLC**, no dentro de su grupo. Importar un
nombre que ya existe en **otro** grupo falla con *"an object with the name ... already exists in
the plc"*, incluso con `importOption: Override`. Solución: apuntar `groupPath` al grupo donde ya
vive.

### 🔴 Openness no es thread-safe

✅ *Verificado en el código de `tia-inspect`: `Operation.Run` serializa todas las llamadas tras un
lock global.*

El SDK de MCP puede despachar llamadas concurrentes. Sin ese lock, y con escritura activada, una
carrera **corrompería el estado del proyecto**, no simplemente devolvería datos viejos.

No paralelices operaciones de Openness. Nunca.

---

## Y lo que directamente no está en ningún servidor

| Falta | Dónde sí está |
|---|---|
| Crear proyecto, añadir hardware, red | `tia-create` (bulaofen) — `tia-inspect` no lo cubre |
| WinCC Unified por API | `tia-create` |
| `WhereUsed`, `FindInCode`, export textual | `tia-inspect` — `tia-create` no lo cubre bien |
| Abrir/actualizar un proyecto de otra versión | `Projects.OpenWithUpgrade` en Openness; la ayuda V20 garantiza la versión anterior y advierte excepción para versiones más antiguas. Revisar la ruta concreta y usar copia. |
