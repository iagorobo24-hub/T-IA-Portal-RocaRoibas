# R03 — Exportar un proyecto a texto y meterlo en git

**Objetivo.** Convertir un proyecto TIA (binario, indiferenciable) en texto que se pueda leer,
revisar en un diff y versionar.

**Por qué importa.** Es la receta que hace que todo lo demás tenga sentido. Sin esto, "el agente
tocó el proyecto" es un `.ap20` de 40 MB distinto al anterior y nadie sabe qué cambió.

**Precondiciones**
- TIA **V20 o superior** 🔒 — la exportación como documentos SIMATIC SD no existe antes
- **El PLC compila con 0 errores** 🔒 — TIA nunca exporta objetos inconsistentes

**Servidor.** `tia-inspect`. Es el único que hace esto bien.

---

## Los dos formatos, y por qué uno no sirve

| Formato | Extensión | ¿Diffea? | Cobertura |
|---|---|---|---|
| **Documento SIMATIC SD** | `.s7dcl` + `.s7res` | ✅ **sí** | Bloques (V20+), tipos PLC (V21+) |
| XML SimaticML | `.xml` | ❌ no | Todo lo demás |

Un `.s7dcl` contiene la declaración y el cuerpo como texto SCL/LAD/STL. El `.s7res`, opcional,
lleva comentarios y recursos de idioma.

🔴 **Todo lo que no sea documento SD sale en XML SimaticML, que en un `git diff` es ruido.**
Las **tablas de tags y las tablas de observación no tienen API de documentos ni en V21**: son
XML y punto. Se versionan igual — para poder restaurarlas — pero no esperes leer sus diffs.

---

## Secuencia

### 1. Compilar primero. Sin excepción

```
CompileSoftware(softwarePath: "PLC_1")
```

🔒 **0 errores o no sigas.** TIA se niega a exportar objetos inconsistentes. En exportación
individual da `InvalidParams` diciendo que compiles. En exportación masiva es peor: **se los
salta en silencio** y los devuelve en una lista aparte.

### 2. Exportar el árbol completo

```
ExportPlcAsSourceTree(softwarePath: "PLC_1",
                      exportPath:   "40-projects/<proyecto>/src")
```

Es la forma corta. Si necesitas control fino:

```
ExportBlocksAsDocuments(softwarePath: "PLC_1",
                        exportPath:   ".../src/Program blocks",
                        preservePath: true)

ExportTypesAsDocuments(...)      ← requiere V21
ExportTagTable(...)              ← XML, no hay alternativa
ExportWatchTable(...)            ← XML
```

**`preservePath: true`** reproduce el árbol de grupos del proyecto por debajo de la carpeta de
sistema, usando el nombre tal y como TIA lo reporta **en el idioma de la interfaz**. Tu V20 está
en inglés ✅, así que sale `Program blocks/40_Devices/FB_Motor.s7dcl`.

### 3. 🔴 Mirar la lista de inconsistentes

La respuesta de una exportación masiva trae dos listas: `Items` y **`Inconsistent`**.

**Míralas las dos, siempre.** Si ignoras `Inconsistent`, crees que exportaste el PLC entero
cuando te has dejado bloques fuera, y el commit miente.

### 4. Commit

```bash
git add "40-projects/<proyecto>/src"
git status        # ¿cuadra con lo que esperabas?
git commit -m "Cinta 1: timeout de arranque de 3 s a 8 s tras el FAT"
```

🔒 **El mensaje dice qué cambió funcionalmente, no "update".** El diff ya dice qué líneas
cambiaron; el mensaje tiene que decir **por qué**.

---

## El ciclo completo, para no perderlo

```
leer → cambio mínimo → compilar (0 errores) → guardar → exportar a src/ → commit
```

Los dos últimos pasos **no son opcionales** (`AGENTS.md` §6). Un cambio guardado en el `.ap20` y
no exportado es un cambio que nadie podrá revisar ni deshacer.

---

## La vuelta: de git a TIA

```
ImportFromDocuments(softwarePath: "PLC_1",
                    sourcePath:   ".../src/Program blocks/40_Devices/FB_Motor.s7dcl")
```

Una importación masiva descubre el juego de documentos **por nombre base**, no asumiendo una
extensión: coge el `.s7dcl` y su `.s7res` si existe.

### Dos trampas conocidas

⚠️ **LAD desde documentos SD.** 📄 Exige que el `.s7res` lleve etiquetas **en-US** para todos los
elementos, o falla. Es un bug de Openness, no del servidor. Sin confirmar en esta máquina — hay
que probarlo. Es otra razón de la regla de [ADR-003](../../00-meta/decisiones/ADR-003-lenguajes.md):
**la lógica en SCL**, que no tiene este problema.

⚠️ **Nombre de tipo PLC ya existente.** El nombre es único en **todo el PLC**, no dentro del
grupo. Importarlo en otro grupo falla aunque uses `Override`. Apunta `groupPath` al grupo donde
ya vive.

---

## Verificación

- [ ] `CompileSoftware` con 0 errores **antes** de exportar
- [ ] Lista `Inconsistent` revisada y vacía (o justificada)
- [ ] Los `.s7dcl` se abren en un editor de texto y se leen
- [ ] `git diff` de un cambio pequeño muestra **solo ese cambio**, no el fichero entero
- [ ] `40-projects/<proyecto>/tia/` **no** está en el commit — es binario, va ignorado

Ese cuarto punto es la prueba real. Si un cambio de una línea produce un diff de 400 líneas,
algo va mal en el formato de exportación.

---

## Si falla

| Síntoma | Causa | Arreglo |
|---|---|---|
| `ExportFailed` en un bloque | Inconsistente | Compila. Si sigue, ábrelo en TIA: suele faltar una instrucción o un tipo |
| `NotSupported` al exportar tipos | TIA V20 | Los documentos de tipos PLC necesitan **V21**. Exporta los tipos como XML |
| `ExportBlock` falla con solo un nombre | Falta la ruta completa | Necesita `Grupo/Subgrupo/Nombre`. El error suele **sugerir** las rutas probables: léelo |
| El diff sigue siendo ilegible | Exportaste XML, no documentos | Usa `ExportAsDocuments` / `ExportPlcAsSourceTree`, no `ExportBlock` |
| Faltan bloques en `src/` | Ignoraste `Inconsistent` | Vuelve al paso 3 |

---

## Pruébalo aquí

`50-examples/npatel-basement-light/` — pequeño, así que el árbol exportado se revisa entero a
ojo y puedes comprobar que el formato es el que esperas.

**Ejercicio completo:** exporta, cambia una constante en TIA, vuelve a exportar, y mira el
`git diff`. Si sale una línea, la cadena funciona. Ese es el momento en que este workspace
empieza a valer para algo.
