# TIA-Claude V18: ruta de trabajo para agentes en `EQUIPOTECNICO`

> **Adaptación del plan V20** [`2026-09-21-tia-agent-operating-model.md`](2026-09-21-tia-agent-operating-model.md),
> que Codex ejecuta en el otro ordenador. **Este documento no lo duplica: lo hereda y declara la delta.**
> Todo lo que no aparezca aquí sigue rigiendo tal cual desde el plan V20.

**Fecha:** 2026-09-22 · **Host:** `EQUIPOTECNICO` · **Agente:** Claude Code (desktop)
**Contrato normativo:** [AGENTS.md](../../../AGENTS.md) · **Perfil:** [35-runtime/v18/PERFIL.md](../../../35-runtime/v18/PERFIL.md)
**Estado:** Fases 0 y 6 cerradas · Fase 7 abierta

---

## 1. La delta V20 → V18, medida

No estimada: capturada con `tools/list` en ambas máquinas y comparada nombre a nombre.

| Perfil | V20 | V18 | Delta |
|---|---|---|---|
| `tia-inspect` read | 53 | **49** | **−4** |
| `tia-inspect` write (aislado) | 84 | **80** | **−4** |

Las cuatro que faltan, en ambos perfiles, son **exactamente las mismas**:

```
ExportAsDocuments   ExportBlocksAsDocuments   ExportTypeAsDocuments   ExportTypesAsDocuments
```

Todas de SIMATIC Source Documents (`.s7dcl`/`.s7res`), cuya API no existe antes de Openness V20.
**Ninguna otra herramienta cambia.** El 92% del roster es idéntico, así que **el inventario del plan
V20 (Fase 6 y su apéndice) es reutilizable casi entero**: basta marcar esas cuatro filas como
`No disponible en V18` y revisar las excepciones de la sección 3.

Evidencia: [01-tools-list.json](../../../35-runtime/v18/runs/01-tools-list.json) (read) ·
[11-write-tools-list.json](../../../35-runtime/v18/runs/11-write-tools-list.json) (write).

### Lo que se conserva y conviene subrayar

`ImportSources`, `ImportFromDocuments` e `ImportBlocksFromDocuments` **siguen sin registrarse** en el
perfil write de V18, igual que en V20. El fail-closed de la Fase 1 del plan V20 **se mantiene intacto
aquí**: no hay que rehacer esa fase, pero tampoco se puede dar por superada.

---

## 2. Qué se hereda sin tocar

Estas fases del plan V20 **no dependen de la versión de Openness**. No se repiten:

| Fase V20 | Por qué no se repite |
|---|---|
| **1** — Fail closed del apply SCL | El helper, los tests y el veto de tags Safety son PowerShell + lógica. Verificado que los importadores genéricos tampoco están en V18 |
| **2** — Credencial Node-RED | Es un fichero de `50-examples/`, ajeno a la versión |
| **3** — Alinear instrucciones | Documentación transversal |
| **4** — Distribución y fixtures | El empaquetador portable es agnóstico |
| **5** — Recetas profesionales (R18–R21) | Conocimiento de ingeniería, no de API |

También se heredan **íntegras** las 12 guardas de la sección *"Guardas que gobiernan toda prueba"* y
la escala de evidencia (Documentado → Esquema → Smoke → Fixture → Compilado → Simulado → Gráfico →
Bloqueado). **No se relaja ninguna.**

> La regla que más importa aquí: *"No elevar el estado de una herramienta por analogía con otra del
> mismo grupo."* Que el roster de V18 sea el de V20 menos cuatro **no convierte en `Fixture` ninguna
> fila que en V20 se probó y aquí no.**

---

## 3. Lo que NO se hereda: específico de V18

### 3.1 Tres herramientas están en el roster pero fallan en ejecución

`PlcTagTable.Name` y `PlcTag.Name` son de solo lectura antes de Openness V20. Estas aparecen en
`tools/list` y **devuelven `NotSupported` al llamarlas**:

| Herramienta | Comportamiento en V18 |
|---|---|
| `RenameTagTable` | `NotSupported` |
| `UpdateTag` con `newName` | `NotSupported` (el resto de propiedades sí se aplican) |
| `RenameWatchTable` | `NotSupported` (ya lo era en V20; el setter llega en V21) |

Renombrar **bloques y tipos de datos sí funciona**: `PlcBlock.Name` y `PlcType.Name` tienen setter en
las cuatro versiones instaladas.

> Es el ejemplo perfecto de la tesis del plan V20: **el schema no acredita la ejecución.** Aquí hay
> tres filas que un inventario basado solo en `tools/list` marcaría como disponibles y no lo están.

### 3.2 `GetBlockSource` cambia de comportamiento, no de disponibilidad

Sigue en el roster. Pero con `format=document`, al no existir SIMATIC SD, **cae a XML y lo declara en
`Format`**. Verificado. No es un fallo y no debe registrarse como tal: es el fallback diseñado.

Consecuencia de ingeniería: **no se puede leer LAD/FBD ajeno como texto en V18.** Para SCL, STL, DB y
UDT el export textual funciona igual que en V20, vía `GenerateSource`.

### 3.3 `tia-create` no existe en esta máquina

Su bundle es V20/V21 y no hay vía de port. **Todo el trabajo del plan V20 que pasa por `tia-create`
queda BLOQUEADO aquí**, incluidas las rutas que aquel plan usó en su Fase 7:

- `PlcBuildAndImport`, `WritePlcSclSourceFile`, `ImportPlcExternalSource`,
  `GenerateBlocksFromExternalSource`
- `FindTools` / `CallTool` y el roster dinámico de 222 herramientas
- Los self-tests `RunOnlineMonitoringSafetySelfTest`, `RunHmiActionScriptRecipeSafetySelfTest`
- `ScaffoldProject` y todo el runner `agent-demo`

**Esto es la mayor pérdida funcional respecto al plan V20**, mucho mayor que las cuatro herramientas
de documentos. La creación de proyectos, hardware, redes y HMI **no es posible desde MCP en V18**.

**Alternativa verificada:** el generador propio
[`35-runtime/v18/tools/fixture-generator/`](../../../35-runtime/v18/tools/fixture-generator/) crea
proyectos `.ap18` desechables con CPU, OB1 en LAD y un FB en SCL, compilados 0/0, usando Openness
directamente. Cubre la necesidad de *fixtures*, **no** la de creación asistida para trabajo real.

### 3.4 La whitelist de aplicaciones Openness

TIA **V18** mantiene `HKLM\SOFTWARE\Siemens\Automation\Openness\18.0\Whitelist\<app>.exe`. Un binario
que TIA no ha visto nunca **falla el primer intento** con `EngineeringSecurityException: Security
error` + *"The operation has timed out"*, aunque el grupo y la licencia estén bien. Ese intento crea
la entrada; **el segundo funciona**.

> **Añadir como guarda 13 para esta máquina:** ante ese error con un binario recién compilado,
> reintentar **antes** de diagnosticar entorno, permisos o licencia. V15.1, V16 y V17 no tienen whitelist.

### 3.5 Computer Use: **parcial — accesibilidad sí, píxeles no**

*(Corregido el 2026-09-22 tras comprobarlo. La primera versión de esta sección decía "no disponible"
y era demasiado tajante.)*

**No existe herramienta nativa de Computer Use de Windows.** Verificado: las dos herramientas
`computer` de esta sesión (`claude-in-chrome` y `Claude_Browser`) operan sobre páginas web — una
exige `tabId`, la otra actúa sobre el panel del navegador. El plugin `node_repl` + `@oai/sky` del
plan V20 es de **Codex**, no de Claude Code.

**Pero UIAutomation sí está disponible y funciona.** Probado en esta máquina:

| Capacidad | Estado | Prueba |
|---|---|---|
| Enumerar ventanas top-level (título, clase, PID) | ✅ **funciona** | 4 ventanas enumeradas |
| Leer el árbol de controles de una ventana | ✅ **funciona** | 206 elementos con tipo y nombre |
| Identificar qué proyecto muestra una ventana TIA | ✅ **habilitado** | [`Get-TiaWindowIdentity.ps1`](../../../30-tools/scripts/Get-TiaWindowIdentity.ps1) |
| **Captura de pantalla** | ❌ **denegada** | bloqueada por el clasificador de permisos (`Create Unsafe Agents`) |
| Invocar botones / teclado sobre TIA | ⬜ no probado | `InvokePattern`; es acción, no lectura |

**Lo que esto cambia respecto a la primera lectura:**

- **La regla de AGENTS.md §3.5 sí se puede cumplir.** `Get-TiaWindowIdentity.ps1` identifica las
  ventanas de TIA y el proyecto que muestra cada una, por título, en solo lectura y sin píxeles.
  **Ejecutarlo antes de cualquier `Connect`.** Una instancia headless del agente no aparece en su
  salida, que es exactamente lo que se quiere: no confundirla con una ventana del usuario.
- **Sigue sin poder alcanzarse el nivel `Gráfico`** de la escala de evidencia para nada que requiera
  *ver*: LAD dibujado, aspecto de una pantalla HMI, Runtime. Sin captura de pantalla no hay
  inspección visual, y la captura está denegada por política de permisos, no por falta de medio.

**Norma operativa mientras tanto:**
1. `Get-TiaWindowIdentity.ps1` antes de conectar. Si hay una ventana con proyecto que no es el
   objetivo, **parar y preguntar**.
2. Operar siempre con `--isolated --fixture-root`: instancia headless propia, nunca una ventana ajena.
3. No usar `InvokePattern` sobre TIA sin aprobación explícita: un clic en un editor abierto es una
   mutación sin preview ni readback, fuera del ciclo de AGENTS.md §6.

**Si necesitas el nivel `Gráfico`**, hay dos vías y ambas requieren tu decisión: autorizar la captura
de pantalla añadiendo una regla de permiso, o hacer tú la comprobación visual y pegar el resultado.

### 3.6 PLCSIM Advanced es V5.0, no V6

La Fase 8 del plan V20 exige `plcsimVirtualAdapterReady=true` y un Runtime Advanced **V20**. Aquí hay
**PLCSIM Advanced V5.0 Upd2** (API 5.0) y S7-PLCSIM clásico V15.1/V17/V18 SP2 — **no hay V16**.
La fase de simulación hay que replantearla contra V5.0; no se hereda.

---

## 4. Estado actual — lo ya cerrado hoy

| Fase | Estado en V18 | Evidencia |
|---|---|---|
| **0** — Línea base y acceso | ✅ **cerrada** | [equipotecnico.json](../../../70-runs/doctor/equipotecnico.json) · [RESUMEN.md](../../../35-runtime/v18/runs/RESUMEN.md) |
| **6** — Inventario por tool | ✅ **cerrada para lectura**: 49/49 a nivel `Fixture` | [INVENTARIO-LECTURA.md](../../../35-runtime/v18/runs/INVENTARIO-LECTURA.md) |
| **7** — Acción sobre clon | 🟡 **lectura completa**; escritura pendiente | `20-lote1.json` … `27-devices-fix2.json` |
| **8** — PLCSIM / HMI Runtime | ⬜ no iniciada | — |
| **9** — Integración y acceso | 🟡 `.mcp.json` apunta a V18 | [.mcp.json](../../../.mcp.json) |

Nivel `Fixture` alcanzado en lectura, sobre `.ap18` real y desechable: `Connect`, `OpenProject`,
`GetProjectTree`, `GetSoftwareTree`, `GetBlocks`, `GetBlockSource`, `GenerateBlockSource` y
`GetCrossReferences`. Compilación del servidor: **0 errores**.

**Nivel `Fixture` en escritura: ninguno.** El perfil write solo se ha enumerado.

---

## 5. Plan de trabajo desde aquí

Ordenado por lo que da más capacidad con menos riesgo. **Cada paso para y reporta.**

### V18-A — Cerrar el inventario de lectura a nivel `Fixture` (R1) — ✅ **CERRADO 2026-09-22**

**Las 49 herramientas del perfil read están a nivel `Fixture`**, ejecutadas contra un `.ap18` real.
Informe: [INVENTARIO-LECTURA.md](../../../35-runtime/v18/runs/INVENTARIO-LECTURA.md).

Se encontraron y corrigieron **dos bugs de upstream** por el camino, ambos invisibles en V20 y
visibles solo en V18. Son código compartido: **revalidar en V20** (ver
[35-runtime/v20/PERFIL.md](../../../35-runtime/v20/PERFIL.md)).

Lo que se hizo, para referencia:

1. [ ] Ejecutar sobre el fixture las read no probadas, en lotes por familia: `GetTypes`, `GetTags`,
   `GetPlcTagTables`, `FindInCode`, `WhereUsed`, `ResolveObjectPath`, `GetBlockInterface`,
   `GetWatchTables`, `ExportBlock`, `ExportPlcAsSourceTree`, `GenerateSources`…
2. [ ] Registrar por herramienta: llamada exacta, respuesta, y **si devolvió vacío, si es por el
   fixture o por la versión**. Un fixture con 2 bloques y 0 tags devolverá vacíos legítimos.
3. [ ] Enriquecer el fixture donde haga falta para que la prueba sea significativa: UDT, DB global,
   tabla de tags con contenido, watch table. Vía `fixture-generator`, no a mano.
4. [ ] Volcar el resultado como tabla en este documento, con el mismo formato del apéndice V20.

**Riesgo R1.** Sin mutación. Es el trabajo de mayor valor pendiente y el único que no depende de
ninguna decisión tuya.

### V18-B — Primera escritura en clon desechable (R2)

**Requiere tu aprobación explícita** (AGENTS.md §3.5: el perfil write exige reconocimiento).

1. [ ] Recrear `project/` y `backup/` desde `source/` y regenerar el manifiesto. *(TIA escribe en el
   proyecto al abrirlo; si no se recrean, `New-TiaFixtureManifest.ps1` se niega — y hace bien.)*
2. [ ] Preflight completo: `GetBlocks` con `isFailsafe=false` en todos, `isKnowHowProtected=false`,
   `GetTags` sin ningún tag Safety.
3. [ ] Mutación mínima y reversible sobre `FB_ScaleValue`: una sola, con preview previo.
4. [ ] `CompileSoftware` → exigir **0 errores**; si no, revertir.
5. [ ] `SaveProject` → `GenerateBlockSource` → readback independiente en sesión nueva.
6. [ ] Restaurar desde `backup/` y comparar fichero a fichero con hash.
7. [ ] Probar los **negativos**: que `RenameTagTable` devuelve `NotSupported` y no deja el proyecto
   a medias.

**Riesgo R2.** Nunca sobre `40-projects/` ni sobre un original de `50-examples/`.

### V18-C — Replantear simulación contra PLCSIM Advanced V5.0 (R3)

1. [ ] Adaptar `Write-TiaSimulationReadiness.ps1`: hoy busca `PLCSIM_V19\S7PLCSIMV19.exe`, que aquí
   no existe. Parametrizar por versión y apuntar a V18 SP2 / API 5.0.
2. [ ] Comprobar `plcsimVirtualAdapterReady` con la API 5.0.
3. [ ] **No pasar de aquí sin una instancia virtual desechable identificada.** Target ambiguo = físico.

### V18-D — Arreglar lo que quedó roto por la mudanza de máquina

1. [ ] `Invoke-TiaDirectOpennessProbe.ps1:25` apunta a `Portal V20\PublicAPI\V20\Siemens.Engineering.dll`,
   hardcodeado. **Aquí no existe.** Debe resolverse desde el registro
   `HKLM\SOFTWARE\Siemens\Automation\Openness\<ver>`, que tiene las cuatro versiones.
2. [ ] `Write-TiaSimulationReadiness.ps1:29` → `PLCSIM_V19` (ver V18-C).
3. [ ] `00-meta/01-arquitectura.md` sigue titulado con la ruta `C:\Users\jose.mellid\TIA-Claude`.

### V18-E — Cerrar el círculo con Claude Code

1. [ ] Reiniciar la sesión para que `.mcp.json` cargue el servidor V18 **como MCP nativo**, en vez de
   invocarlo por script. Hoy `tia-inspect` aparece como `CONNECTION_CLOSED` porque la sesión arrancó
   con la configuración vieja.
2. [ ] Verificar que las herramientas aparecen como `mcp__tia-inspect__*` y repetir un `Doctor` por esa vía.
3. [ ] Documentar el arranque en `35-runtime/v18/PERFIL.md`.

> Es el paso que convierte todo lo anterior en **trabajo diario** en lugar de en una demo.

---

## 6. Criterios de completado para V18

- [x] Delta V20→V18 medida por comparación de rosters, no estimada.
- [x] Perfil V18 compilado, con Doctor y lectura verificados sobre `.ap18` real.
- [ ] Las 49 herramientas read clasificadas por nivel de evidencia real.
- [ ] Una escritura completa en clon con compile 0 errores, readback y restauración exacta.
- [ ] Simulación replanteada contra PLCSIM Advanced V5.0, o declarada `Bloqueado` con su motivo.
- [ ] MCP nativo funcionando en Claude Code.
- [x] Bloqueos explícitos y no disimulados: `tia-create`, Computer Use, SIMATIC SD, renombrado de tags.

---

## 7. Diferencias de contexto frente al plan V20

| | Plan V20 (Codex, otro equipo) | Este plan (Claude Code, `EQUIPOTECNICO`) |
|---|---|---|
| TIA | V19 + V20 | V15.1, V16, V17, **V18 SP1 Upd5** |
| Servidores | `tia-inspect` + `tia-create` | **solo `tia-inspect`** |
| Roster read / write | 53 / 84 | **49 / 80** |
| Computer Use | nativo (`node_repl` + `@oai/sky`) | **no disponible** |
| PLCSIM Advanced | V6.0.0.1 | **V5.0 Upd2** |
| SIMATIC Source Documents | disponible | **no existe** |
| Export textual `.scl` | sí | **sí** — verificado |
| `GetCrossReferences` | sí | **sí** — verificado |
| Escritura probada | sí, en clon IOT2050 | **no** |
| Fixture | `IOT2050_S7_CompleteProject_V20` | `TiaClaudeFixture_V18`, generado aquí |

---

## 8. Lo que este plan NO afirma

- **No afirma que las 41 herramientas read no ejecutadas funcionen.** Están a nivel `Esquema`.
  Comparten binario con las 8 probadas, y eso no es evidencia de nada.
- **No afirma que la escritura funcione en V18.** El roster se enumeró; no se llamó a nada.
- **No afirma que el port no haya roto V20.** Eso solo se comprueba en el equipo que tiene V20 —
  ver [35-runtime/v20/PERFIL.md](../../../35-runtime/v20/PERFIL.md).
- **No afirma que los TIA instalados estén licenciados.** El Portal abre, que es evidencia indirecta
  suficiente para operar, no prueba formal.
