# Viabilidad de Openness en V15.1 – V18 sobre `EQUIPOTECNICO` — 2026-09-22

> **Evidencia de entorno:** `70-runs/doctor/equipotecnico.json`. Contexto: ADR-002, ADR-015.

---

## ⚑ ACTUALIZACIÓN — el port está hecho y funciona

> Este documento se escribió como **estudio previo**. El port se ejecutó después, el mismo día, y
> **la recomendación se confirmó en la práctica**. Resultados medidos en
> **[`70-runs/v18/RESUMEN.md`](../70-runs/v18/RESUMEN.md)**:
>
> - Compila con **0 errores**; Doctor da `Active Version: V18` y ve V16/V17/V18.
> - **49 herramientas MCP**, ninguna de documentos.
> - `Connect` → `OpenProject` → `GetProjectTree` → `GetBlocks` **funcionan contra un `.ap18` real**.
> - **`GenerateBlockSource` produjo `FB_ScaleValue.scl` (677 B, SCL legible)** — el export textual
>   sobrevive, como predecía la sección D4.
> - **`GetCrossReferences` devolvió referencias reales** con `%FB1`, tipos y dispositivo.
> - `GetBlockSource format=document` devuelve `"format":"xml"`: el fallback se comporta como se diseñó.
>
> **Tres cosas que este estudio no había previsto** y que la compilación reveló:
> 1. **`PlcTagTable.Name` y `PlcTag.Name` son de solo lectura antes de V20** — ver la corrección en D4.
> 2. `Program.cs` no inicializaba Openness por debajo de V20 (`Active Version: V0`).
> 3. V18 tiene una **whitelist de aplicaciones Openness**: todo binario nuevo falla el primer intento.

---

## Recomendación en una línea

**Portar a V18 — el subconjunto completo menos SIMATIC Source Documents.** Es un port
sustancialmente más barato de lo que ADR-002 estimaba para V19, y no se pierde el export textual.
**Pero antes hay que desbloquear el toolchain: hoy en esta máquina no se puede compilar nada.**
*(Hecho: .NET SDK 10.0.401 y Dev Pack 4.8.1 instalados el 2026-09-22.)*

---

## 0. El bloqueo que manda sobre todo lo demás

Antes de discutir qué API existe: **`EQUIPOTECNICO` no tiene con qué compilar.**

| | |
|---|---|
| .NET SDK | ❌ `dotnet --info` → *"No SDKs were found"* (solo runtimes 5.0/6.0) |
| .NET Framework 4.8 Developer Pack | ❌ Reference Assemblies llegan a `v4.5`; el `csproj` targetea `net48` |
| VS Build Tools modernos | ❌ `vswhere.exe` no existe |

`build.ps1` lanza `throw "No se encuentra dotnet… winget install Microsoft.DotNet.SDK.10"`.

> **Ningún port, ni a V18 ni a nada, empieza sin instalar esas dos piezas.** Es un prerrequisito
> barato (dos instaladores) pero es un prerrequisito duro, y ninguna estimación de horas de este
> documento lo incluye.

---

## D1. Qué descartó ADR-002 exactamente, y por qué

ADR-002 (2026-09-14) fijó **V20 como versión operativa** y descartó V19. La medición fue real,
no estimada:

| Objetivo | Resultado medido |
|---|---|
| V20 | ✅ 0 errores tras un parche de 2 líneas |
| V19 | ❌ **~15 errores `CS0246`**, concentrados en la API de documentos |

**Qué falta exactamente en V19:** los tipos `ImportDocumentOptions` y `DocumentExportResult`, es
decir toda la funcionalidad de **documentos SIMATIC SD** (`.s7dcl` / `.s7res`), repartida por
`Portal.Documents.cs`, `Portal.cs` y `McpServer.cs`.

**El argumento de fondo de ADR-002 — y aquí está el punto que hay que revisar:**

> *"esa es exactamente la funcionalidad que hace que versionar en git sirva de algo. Todo lo demás
> que exporta Openness es XML SimaticML, que diffea fatal. Un `tia-inspect` para V19 sería un
> `tia-inspect` sin la razón principal para usarlo."*

ADR-002 estimó **2-3 h** de trabajo (envolver ~10 puntos de llamada en 3 ficheros con `#if`) y
señaló un daño colateral: **`bulaofen` (`tia-create`) tampoco soporta V19** — su bundle es V20/V21.

**Esa frase era demasiado pesimista, y la evidencia de la sección D4 lo demuestra.** ADR-002
equiparó "export textual" con "SIMATIC Source Documents". Son dos cosas distintas, y la otra
sobrevive hasta V15.1.

---

## D2. El paquete NuGet `18.0.x` — **existe**

Consultado en `api.nuget.org` (HTTP 200, 35 versiones publicadas del paquete
`Siemens.Collaboration.Net.TiaPortal.Packages.Openness`):

| Major | Versiones disponibles | Más alta |
|---|---|---|
| 14.0 | 5 | `14.0.1685432634` |
| 15.0 | 6 | `15.0.1685432628` |
| **15.1** | 5 | **`15.1.1685432631`** |
| **16.0** | 6 | **`16.0.1685432614`** |
| **17.0** | 5 | **`17.0.1685432625`** |
| **18.0** | 5 | **`18.0.1685432622`** |
| 19.0 / 20.0 / 21.0 | 1 cada uno | `19.0.1725520202` / `20.0.1744190253` / `21.0.1765349347` |

> **La vía B no muere aquí.** Existen paquetes para **las cuatro versiones instaladas en esta
> máquina**. El mapa de `build.ps1` solo necesita cuatro entradas más.

Metadatos del 18.0 (nuspec): *"This transitive package will automatically reference TIA Portal 18.0
Openness references into your project"*, autor Siemens AG, repositorio
`github.com/tia-portal-applications/tia-portal-openness-packages`. Licencia de fichero
(`requireLicenseAcceptance: true`) — **revisar los términos antes de usarlo en producción**.

Los paquetes 14.0–18.0 llevan sufijos de mayo de 2023 y no se han tocado desde entonces: están
**congelados pero disponibles**. Los de 19/20/21 son posteriores.

Dependencias del `csproj` que también hay que validar:
`Siemens.Collaboration.Net.TiaPortal.Openness.Resolver` (última: `2.0.1765367256`) y
`Siemens.Collaboration.Net.OperatingSystem.Windows` (última: `3.0.1725521661`). El resolver es
genérico —lee el registro de Windows— y **ya demostró cargar correctamente en esta máquina** durante
la prueba de Fase A. No se espera problema, pero **no está verificado contra V18**.

---

## D3. Coste real del port — medido contra las DLL, no estimado

**Método:** en vez de suponer qué API tiene cada versión, se cargaron por reflexión (solo
metadatos, sin ejecutar nada) los cuatro `Siemens.Engineering.dll` instalados y se comparó su
superficie pública completa.

| Versión | Tipos públicos exportados |
|---|---|
| V15.1 | 573 |
| V16 | 1 479 |
| V17 | 1 679 |
| V18 | 1 806 |

### Superficie por namespace usado por el código

| Namespace (`Siemens.Engineering.*`) | V15.1 | V16 | V17 | **V18** |
|---|---|---|---|---|
| `SW.Blocks` | 28 | 28 | 32 | **32** |
| `SW.Types` | 11 | 11 | 11 | **11** |
| `SW.Tags` | 13 | 13 | 13 | **13** |
| `SW.WatchAndForceTables` | 14 | 14 | 14 | **14** |
| `SW.ExternalSources` | 9 | 9 | 9 | **9** |
| `Compiler` | 5 | 5 | 5 | **5** |
| `CrossReference` | **0** | **0** | **0** | **11** |
| `Safety` | 0 | 1 | 15 | **15** |
| `Multiuser` | 0 | 0 | 17 | **17** |
| `HW` | 153 | 648 | 687 | **740** |

> **El núcleo del servidor —bloques, tipos, tags, watch tables, fuentes externas, compilador— es
> idéntico en las cuatro versiones.** Los escalones están en `CrossReference`, `Safety`,
> `Multiuser` y `Blocks.Interface`.

### Símbolos concretos, verificados por reflexión

| Símbolo | V15.1 | V16 | V17 | **V18** |
|---|---|---|---|---|
| `ImportDocumentOptions` | ❌ | ❌ | ❌ | ❌ |
| `DocumentExportResult` | ❌ | ❌ | ❌ | ❌ |
| `ExportAsDocuments` / `ImportFromDocuments` | ❌ | ❌ | ❌ | ❌ |
| **`GenerateSource`** | ✅ | ✅ | ✅ | **✅** |
| `IGenerateSource`, `GenerateOptions`, `GenerateBlockOption` | ✅ | ✅ | ✅ | **✅** |
| **`GetCrossReferences`** | ❌ | ❌ | ❌ | **✅** |
| `CrossReferenceService` + 10 tipos del namespace | ❌ | ❌ | ❌ | **✅** |
| `Safety.SafetyAdministration`, `SafetySignature`, `SafetySettings` | ❌ | ❌ | ✅ | **✅** |
| `Safety.GlobalSettings` | ❌ | ✅ | ✅ | **✅** |
| `Blocks.Interface.Member` / `PlcBlockInterface` | ❌ | ❌ | ✅ | **✅** |
| `Multiuser.ProjectServer` | ❌ | ❌ | ✅ | **✅** |
| `PlcWatchTable.Name` **con setter** | ❌ | ❌ | ❌ | ❌ |

### Fichero a fichero: ¿separable con `#if` o entretejido?

| Fichero | Líneas | Depende de | Veredicto |
|---|---|---|---|
| `Siemens/Portal.Documents.cs` | 601 | `DocumentExportResult` ×7, `ImportDocumentOptions` ×3 | ✅ **Fichero entero dedicado.** Se excluye del `<Compile>` o se envuelve completo. Limpio |
| `ModelContextProtocol/McpServerWrite.Documents.cs` | 127 | 2 ocurrencias, **ambas strings `[Description]`** | ✅ **Fichero entero dedicado.** Las strings compilan aunque el tipo no exista |
| `ModelContextProtocol/McpServer.Documents.cs` | 170 | — | ✅ Fichero entero dedicado |
| `Siemens/Portal.cs` (2 586 l.) | 3 puntos: l. 1545, 1605, 1658 | `DocumentExportResult`, `ImportDocumentOptions` | ⚠️ **Parcialmente entretejido**, pero los 3 caen dentro de métodos dedicados a documentos (`ImportFromDocuments`, `ImportBlocksFromDocuments` y un exportador `.s7dcl`/`.s7res`). Se envuelven los métodos, no hay que trocear lógica ajena |
| `ModelContextProtocol/McpServer.cs` (1 980 l.) | 9 ocurrencias | De ellas, **2 son strings `[Description]`** y 7 están en `ParseImportDocumentOption` (l. 1921-1947), un método dedicado, más 2 tool methods | ⚠️ Concentrado, no disperso. Se envuelve el método + los 2 tools |
| `ModelContextProtocol/McpServerWrite.LegacyMutations.cs` | 259 | 2 ocurrencias, **ambas strings `[Description]`** | ✅ Solo texto. Basta retirar los tools que llaman a lo eliminado |
| `Siemens/Portal.Write.cs` → `RenameWatchTable` | l. 290 | Ya está tras `#if TIA_V21_PLUS` | ✅ **Cero trabajo.** Verificado: `PlcWatchTable.Name` no tiene setter en V15.1–V18, igual que en V20. El `#if` existente ya es correcto |
| `Siemens/Diagnostics.cs` | 239 | `MinTiaMajorVersion = 19` (l. 43) | ✅ **Una línea.** Y el código ya contempla el caso antiguo: *"older installations ship a single Siemens.Engineering.dll"* |
| `Siemens/Portal.GenerateSource.cs` | 430 | `IGenerateSource`, `GenerateOptions` | ✅ **Cero trabajo.** Toda su API existe desde V15.1 |
| `Siemens/Portal.ExternalSources.cs` | 94 | `SW.ExternalSources` | ✅ **Cero trabajo.** 9/9 tipos en todas |
| `Siemens/Portal.CrossReferences.cs` | 115 | `CrossReferenceService` | ✅ **Cero trabajo en V18** (existe). Fichero entero a envolver en V17 y por debajo |
| `Siemens/Portal.Safety.cs` | 188 | `Siemens.Engineering.Safety` | ✅ **Cero trabajo en V18/V17.** Se cae entero en V16/V15.1 |

### Un punto no cubierto por el enunciado, y que importa

`Siemens/Engineering.cs` l. 146 resuelve la instalación leyendo
`HKLM\SOFTWARE\Siemens\Automation\_InstalledSW\TIAP{majorVersion}`. Comprobado en esta máquina:

```
TIAP15_1  → C:\Program Files\Siemens\Automation\Portal V15_1\     ← ¡no es "TIAP15"!
TIAP16    → C:\Program Files\Siemens\Automation\Portal V16\
TIAP17    → C:\Program Files\Siemens\Automation\Portal V17\
TIAP18    → C:\Program Files\Siemens\Automation\Portal V18\       ✅ con subclave TIA_Opns
```

> Para **V18, V17 y V16 la resolución funciona sin tocar una línea**. Para **V15.1 no**: el código
> formatea un `int`, produce `TIAP15` y no encuentra nada. V15.1 exige código adicional, no solo un
> número más en el `ValidateSet`.

### Estimación de esfuerzo (V18)

| Tarea | Coste |
|---|---|
| Instalar .NET SDK + Dev Pack 4.8 | **prerrequisito duro**, no incluido abajo |
| `build.ps1`: `ValidateSet` + 4 entradas en el mapa NuGet | 15 min |
| `Sync-HarnessConfigs.ps1`: su `ValidateSet(20,21)` también bloquea el 18 | 10 min |
| `Diagnostics.cs`: `MinTiaMajorVersion` 19 → 18 | 1 línea |
| Envolver Documents tras `#if TIA_V20_PLUS` (3 ficheros dedicados + 2 puntos concentrados) | 2-3 h |
| Compilar, iterar sobre los `CS0246` que aparezcan | **desconocido** |
| Fixture `.ap18` + smoke test de lectura | 2-3 h |

> **Honestidad sobre la incertidumbre:** ADR-002 midió ~15 errores para V19 **compilando**. Aquí no
> se puede compilar, así que el recuento de errores de V18 es **una proyección basada en
> comparación de API, no una medición**. La comparación dice que V18 ⊃ V19 en superficie, luego se
> esperan **≤ 15 errores** y de la misma familia. No está verificado.

---

## D4. Qué se pierde en V18 — y qué NO se pierde

### ✅ Lo que sobrevive: el export textual, que era la preocupación principal

**Sí queda export textual utilizable.** `GenerateSource` existe en V15.1, V16, V17 y V18,
verificado por reflexión sobre las DLL reales.

El propio código distingue las tres cosas, y ADR-002 las confundió
(`Portal.GenerateSource.cs`, comentario de cabecera):

| Mecanismo | Qué produce | ¿En V18? |
|---|---|---|
| **`GenerateSource`** (fuentes externas del compilador) | **`.scl`, `.awl`, `.db`, `.udt`** — texto plano que diffea | ✅ **SÍ** (desde V15.1) |
| `ExportBlock` (SimaticML) | XML posicional, diffea mal | ✅ SÍ |
| `ExportAsDocuments` (SIMATIC SD) | `.s7dcl` / `.s7res` — texto legible de **LAD/FBD** | ❌ **NO** (V20+) |

**Cobertura exacta de `GenerateSource`** (`BlockSourceExtension`, l. 50-70): `DataBlock` → `.db`;
`ProgrammingLanguage.STL` → `.awl`; `ProgrammingLanguage.SCL` → `.scl`; tipos PLC → `.udt`.
Cualquier otro lenguaje devuelve `NotSupported`.

> **Traducido al contrato de este workspace:** `AGENTS.md` §4 manda **SCL para toda la lógica** y
> LAD solo desde recetas. El export textual de **todo lo que el agente escribe** sigue funcionando
> en V18. Lo que se pierde es leer como texto el **LAD que ya existe en proyectos de cliente** —
> que es precisamente lo que el agente no debe escribir.

### ✅ `GetCrossReferences` **sobrevive en V18**

Verificado: `CrossReferenceService` y los 11 tipos del namespace `Siemens.Engineering.CrossReference`
**existen en V18** y en ninguna versión anterior. `Portal.CrossReferences.cs` usa
`provider.GetService<CrossReferenceService>()`, disponible.

> **La detección de código muerto y la auditoría conservan su mejor herramienta en V18.**
> Y esto fija el suelo: **en V17 y por debajo, `GetCrossReferences` desaparece.**

### ❌ Lo que se pierde de verdad en V18

1. **SIMATIC Source Documents completo** — `ExportAsDocuments`, `ImportFromDocuments`,
   `ExportTypeAsDocuments`, `ImportTypeFromDocuments` y sus tools MCP. Pérdida real de **lectura**:
   ya no se puede leer LAD/FBD ajeno como texto.

1-bis. **⚑ CORRECCIÓN POSTERIOR — renombrar tags y tablas de tags.** Este estudio no lo detectó: al
   compilar salieron dos `CS0200` y la reflexión lo confirmó. **`PlcTagTable.Name` y `PlcTag.Name`
   son de solo lectura en V15.1, V16, V17 y V18**; solo V20 les da setter. `RenameTagTable` y el
   renombrado dentro de `UpdateTag` devuelven `NotSupported` en V18. `PlcBlock.Name` y
   `PlcType.Name` **sí** son escribibles en las cuatro versiones, así que renombrar bloques y tipos
   de datos sigue funcionando.
   *Por qué se escapó:* D3 comprobó `PlcWatchTable.Name` pero no el resto de propiedades `Name`.
   La lección es que la comparación de **tipos** no basta: hay que comparar también **miembros**.
2. **`tia-create` (bulaofen) entero.** Su bundle es V20/V21 (ADR-002). En V18 **no hay motor de
   creación de proyectos, hardware, redes ni HMI**. Esto es tan importante como el punto 1 y
   conviene no perderlo de vista: el port de `tia-inspect` deja a `tia-create` fuera.
3. El fixture `TestProject1.zap20` deja de servir; hace falta uno `.ap18`.

### Matiz que rebaja el coste del punto 1

Según `AGENTS.md` §3.3 y §6, **en el perfil V20 actual la escritura vía documentos ya está
bloqueada**: el roster de 84 herramientas del perfil `write` no registra `ImportSources` ni
`ImportFromDocuments`, los `.s7dcl` son *solo-preview*, y `Invoke-TiaSclProposalApply.ps1 -Apply`
debe parar en `BLOCKED`. Evidencia: `70-runs/tia-capabilities/20260921-04-write-tools-live.json`.

> Es decir: **buena parte de lo que se perdería al bajar a V18 es funcionalidad que hoy no está
> operativa de todos modos.** Lo que sí se pierde íntegro es el **export** `.s7dcl` de lectura.
> **NO VERIFICADO** que ese export funcione hoy en el equipo con V20 — no se ha podido comprobar
> desde aquí, y conviene confirmarlo antes de contabilizarlo como pérdida.

---

## D5. Hasta dónde baja el suelo — V17, V16, V15.1

| | **V18** | **V17** | **V16** | **V15.1** |
|---|---|---|---|---|
| Paquete NuGet | ✅ `18.0.1685432622` | ✅ `17.0.1685432625` | ✅ `16.0.1685432614` | ✅ `15.1.1685432631` |
| Resolución por registro | ✅ `TIAP18` | ✅ `TIAP17` | ✅ `TIAP16` | ❌ clave es `TIAP15_1`, el código genera `TIAP15` |
| Leer árbol, bloques, tipos, tags | ✅ | ✅ | ✅ | ✅ |
| Compilar (`ICompilable`) | ✅ | ✅ | ✅ | ✅ |
| Watch tables | ✅ | ✅ | ✅ | ✅ |
| **Export textual `GenerateSource`** | ✅ | ✅ | ✅ | ✅ |
| **`GetCrossReferences`** | ✅ | ❌ | ❌ | ❌ |
| **API `Safety` (núcleo)** | ✅ | ✅ | ❌ (solo `GlobalSettings`) | ❌ |
| `Blocks.Interface` (`PlcBlockInterface`, `Member`) | ✅ | ✅ | ❌ | ❌ |
| `Multiuser` | ✅ | ✅ | ❌ | ❌ |
| SIMATIC Source Documents | ❌ | ❌ | ❌ | ❌ |
| `tia-create` | ❌ | ❌ | ❌ | ❌ |
| Superficie `HW` | 740 | 687 | 648 | **153** |
| S7-PLCSIM clásico instalado | ✅ V18 SP2 | ✅ V17 | ❌ **no hay** | ✅ V15.1 |

### El suelo duro no es técnico, es de seguridad

**V16 y V15.1 no tienen la API `Safety`.** `AGENTS.md` §3.3 exige, antes de *cualquier* escritura,
leer `isFailsafe=false` del proyecto vivo, y ordena parar si el servidor **no expone `isFailsafe` o
devuelve `null`**.

> Sin `Siemens.Engineering.Safety` esa barrera **no se puede construir**. Por tanto, en **V16 y
> V15.1 la escritura queda prohibida por el propio contrato**, no meramente "no implementada". Solo
> serían admisibles perfiles de **lectura pura**.

### Veredicto por versión

- **V18 — recomendado.** Pierde solo Documents. Mantiene cross-references, safety y export textual.
- **V17 — degradado pero utilizable en lectura.** Pierde `GetCrossReferences`: se va la detección de
  código muerto. Conserva la API Safety, luego la barrera de escritura es construible.
- **V16 — solo lectura, y con reservas.** Sin Safety, sin cross-references, sin `Blocks.Interface`.
  Además no hay S7-PLCSIM V16 en esta máquina: no hay dónde simular.
- **V15.1 — no recomendado.** Todo lo anterior, más superficie `HW` de 153 tipos (un 21 % de la de
  V18) y un fallo de resolución por registro que exige código específico. El coste por versión más
  antigua crece justo cuando el valor cae.

---

## D6. Recomendación

### **Portar a V18. Subconjunto completo menos SIMATIC Source Documents.**

**Por qué sí:**

1. **El paquete NuGet existe** (D2). La vía B seguía viva y ADR-015 la daba por dudosa.
2. **No se pierde el export textual** (D4). ADR-002 rechazó V19 sobre la premisa de que un
   `tia-inspect` sin documentos es *"un `tia-inspect` sin la razón principal para usarlo"*. Esa
   premisa **confundía SIMATIC SD con `GenerateSource`**. `.scl`/`.db`/`.udt` siguen saliendo en
   V18 — y en V15.1.
3. **`GetCrossReferences` sobrevive en V18** y solo en V18. La auditoría conserva su mejor
   herramienta.
4. **El núcleo del servidor no cambia**: bloques, tipos, tags, watch tables, fuentes externas y
   compilador tienen superficie idéntica en las cuatro versiones.
5. **El recorte está concentrado, no disperso**: 3 ficheros dedicados + 2 puntos concentrados, y
   varias de las ocurrencias son strings `[Description]` que ni siquiera rompen la compilación.
6. **V18 es la única versión donde el suelo de Openness y el parque legacy coinciden**: da soporte a
   proyectos de cliente en V18, y expone además las superficies API de V17, V16 y V15.1.

**Por qué no todavía — dos condiciones previas:**

- **Instalar .NET SDK y .NET Framework 4.8 Developer Pack.** Sin esto no hay port, ni estimación
  fiable de errores de compilación.
- **Decidir qué pasa con `tia-create`.** No se porta: en V18 no hay creación de proyectos. Si eso es
  inaceptable, la salida correcta es **A (instalar V20)**, no B.

### Recorte propuesto (todo tras `#if`, sin borrar código)

```
#if TIA_V20_PLUS          ← nueva constante, se define solo para TiaMajor >= 20
    Portal.Documents.cs              (fichero entero)
    McpServer.Documents.cs           (fichero entero)
    McpServerWrite.Documents.cs      (fichero entero)
    Portal.cs            → ImportFromDocuments, ImportBlocksFromDocuments, exportador .s7dcl
    McpServer.cs         → ParseImportDocumentOption + 2 tools
    McpServerWrite.LegacyMutations.cs → 2 tools que llaman a lo anterior
#endif
```

Las tools eliminadas deben **devolver `NotSupported` con mensaje explícito**, no desaparecer en
silencio: `AGENTS.md` §7 exige que los errores tipados digan qué hacer.

### Lo que NO recomiendo

- **No portar por debajo de V18** salvo decisión estratégica explícita. V17 pierde
  cross-references; V16 y V15.1 pierden además la API Safety, lo que por contrato los deja en
  lectura pura, y V15.1 exige código extra solo para resolverse en el registro.
- **No tocar la ruta V20/V21.** El otro equipo depende de ella y funciona.
- **No usar este port para escribir hasta que se re-verifique la barrera de safety contra V18.**
  `Safety` existe en V18, pero *existe* no es *funciona*: hay que comprobar que `GetBlocks` devuelve
  `isFailsafe` no nulo contra un proyecto V18 real antes de habilitar `--allow-write`.

---

## Clasificación de la evidencia

**VERIFICADO**
- Paquetes NuGet 15.1/16.0/17.0/18.0 existen — `api.nuget.org`, HTTP 200, 35 versiones
- Superficie de API de las cuatro DLL — reflexión sobre `Siemens.Engineering.dll` instalados
- `GenerateSource` en V15.1–V18; `GetCrossReferences` solo en V18; `ExportAsDocuments` en ninguna
- `PlcWatchTable.Name` sin setter en las cuatro → el `#if TIA_V21_PLUS` existente ya es correcto
- Claves de registro `TIAP15_1`/`TIAP16`/`TIAP17`/`TIAP18` y sus rutas
- Ausencia de .NET SDK y de Developer Pack 4.8

**SUPUESTO**
- ≤ 15 errores de compilación en V18 — proyección por comparación de API; ADR-002 midió V19 compilando, aquí no se puede compilar
- `Siemens.Collaboration.Net.TiaPortal.Openness.Resolver 2.0.x` soporta V18 — es genérico y cargó bien en esta máquina, pero no probado contra V18
- PLCSIM Advanced V5.0 ↔ TIA V18

**NO VERIFICADO**
- Que `ExportAsDocuments` funcione hoy en el equipo con V20 — condiciona cuánto se pierde de verdad
- Que los TIA instalados aquí estén licenciados
- Que un `Connect` de Openness contra V18 funcione — requiere el binario portado
- Términos de la licencia del paquete NuGet de Siemens para este uso

**BLOQUEADO**
- Compilar cualquier cosa — falta .NET SDK y Developer Pack 4.8
- `tia-create` en cualquier versión ≤ V19 — bundle solo V20/V21, sin vía de port conocida
