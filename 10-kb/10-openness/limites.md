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

📄 Los bloques F y las tags de safety rechazan casi cualquier edición, a veces pidiendo la
contraseña de safety. `tia-inspect` **no intenta adivinar** las reglas de Siemens: deja pasar el
error original tal cual.

> Tienes **STEP 7 Safety** instalado en V19 y V20 ✅ *verificado*. Así que esto te va a tocar.
> Regla: **el agente no edita safety.** Reporta y para.

---

## Versiones — qué necesita cada cosa

✅ *Verificado compilando contra los paquetes de Openness V19, V20 y V21.*

| Funcionalidad | Versión mínima |
|---|---|
| Exportar/importar bloques como **documentos SIMATIC SD** (`.s7dcl`/`.s7res`) | **V20** |
| Exportar/importar **tipos de datos PLC** como documentos | **V21** |
| `PlcWatchTable.Name` escribible (renombrar tabla de observación) | **V21** |
| Version Control Interface completo | **V21** |

🔴 **Por qué importa:** los documentos SIMATIC SD son **la única exportación que diffea bien**.
Todo lo demás es XML SimaticML, que en un `git diff` es ruido. En V19 no existe → en V19 git no
sirve de mucho. Es el fondo del ADR-002.

**Las tablas de tags y las tablas de observación no tienen API de documentos ni siquiera en
V21**: son XML y punto.

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
| **Migrar un proyecto de versión** | ❌ **Ninguno.** Openness no expone "migrar". Se hace a mano desde TIA, una vez por proyecto (ver [`50-examples/MIGRACION-V16-a-V20.md`](../../50-examples/MIGRACION-V16-a-V20.md)) |
