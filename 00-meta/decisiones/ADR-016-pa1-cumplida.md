# ADR-016 — PA-1 cumplida: proyecto creado desde una frase y trazabilidad respondida

- **Estado:** foto real del 2026-10-21, después de la aceptación en PLCSIM
  ([ADR-015](ADR-015-estado-real-2026-10-21.md)). Actualiza a ADR-015; no lo sustituye.
- **Alcance:** el objetivo global **PA-1** de `00-meta/02-plan.md`: crear el proyecto
  `DEMO-Cinta01` desde una frase y responder una pregunta de trazabilidad sobre un proyecto
  existente.
- **Evidencia primaria:** `50-examples/demo-cinta01/pa1-evidencia.json` y el proyecto vivo en
  `40-projects/DEMO-Cinta01/`.
- **Relevo:** [`docs/superpowers/handoffs/2026-10-21-pa1-demo-cinta01-handoff.md`](../../docs/superpowers/handoffs/2026-10-21-pa1-demo-cinta01-handoff.md).

## Hechos verificados

### 1. Los cinco entregables de PA-1 están

| # | Entregable | Verificación |
|---|---|---|
| 1 | Proyecto que abre en TIA V20 | `40-projects/DEMO-Cinta01/tia/DEMO-Cinta01/DEMO-Cinta01.ap20`, abierto y cerrado con `OpenProject` y `AttachToOpenProject` en varias sesiones |
| 2 | Compilación 0/0 con informe en `ops/` | `state=Success, errorCount=0, warningCount=0`; informe real en `ops/compile-report.json` y `.txt` |
| 3 | Nomenclatura y estructura conformes | `Check-TiaStandards.ps1` **sale con código 0** (0 hallazgos bloqueantes, 3 bloques, 8 ficheros de export) |
| 4 | Export textual en `src/` | Bloques en XML, tabla de tags exportada, fuentes SCL y definición de la pantalla. El espejo versionado está en `50-examples/demo-cinta01/` |
| 5 | README del proyecto desde la plantilla | `40-projects/DEMO-Cinta01/README.md`, con la plantilla de `20-standards/estructura-proyecto.md` |

### 2. El proyecto tiene lo que pedía la frase

S7-1500 (`6ES7 513-1AM03-0AB0`) con **un motor (M01)**, **enclavamiento** y **seta de
emergencia (ES01)**, más **HMI Unified** (`6AV2123-3GB32-0AW0`) con **pantalla de operación**.

- Bloques: `FB_Motor` (FB), `iDB_M01` (DB de instancia), `Main` (OB1 cíclico).
- Tags: 10 en la tabla `Cinta_Signals`, ninguno en la tabla por defecto.
- La seta de emergencia hace **las dos** cosas obligatorias y las dos están en el punto de
  llamada, no dentro del bloque: prohíbe arrancar (`Interlock`) **y ordena parar en marcha**
  (`CmdStop` incluye `NOT "DI_ES01_Ok"`). Con solo la primera, el motor seguiría girando con
  la seta pulsada, y eso no es una seta de emergencia.
- HMI: conexión `HMI_Connection_1`, 7 tags con binding simbólico **y** dirección absoluta,
  pantalla `Main` 1280×720 con 8 controles, botones con `SetBitInTag` y lámparas con
  `TagDynamization` en `BackColor`.

### 3. La segunda frase de PA-1 se responde con datos reales

> *"¿Dónde se usa la tag `Motor_Marcha` y qué bloques la escriben?"*

**La tag `Motor_Marcha` no existe**, y hay una razón de fondo: `20-standards/naming.md` la cita
expresamente como el **contraejemplo** de su propia regla — *«identificadores en inglés:
`Motor_Start` lo entiende cualquiera; `Motor_Marcha` obliga al siguiente a traducir»* — cerrada en
[ADR-008](ADR-008-nomenclatura-cerrada.md).

La equivalente es **`DI_M01_Start`** (`Cinta_Signals/DI_M01_Start`, `%M0.1`):

- **Quién la escribe:** ningún bloque del PLC. La escribe la **HMI**: el botón `BTN_Start` de la
  pantalla `Main` ejecuta `HMIRuntime.Tags.SysFct.SetBitInTag("StartPB", 0)` sobre el tag HMI
  `StartPB`, ligado por binding simbólico a `DI_M01_Start`.
- **Quién la lee:** el OB cíclico `Main` (OB1, SCL), en la llamada al DB de instancia `iDB_M01`
  del `FB_Motor`: `CmdStart := "DI_M01_Start"`.

Referencias cruzadas reales: `Program blocks/Main.xml` (`<Component Name="DI_M01_Start" UId="34">`),
`sources/OB_Main.scl` y `tags/Cinta_Signals.xml`.

### 4. Límite de las herramientas de análisis, documentado

`TraceTagCause`, `DescribeBlockLogic` y `GetCrossReferences` **no resuelven** un tag global pasado
como parámetro formal de una llamada a un FB en SCL: `writeSites` y `readSites` salen vacíos, y
`GetCrossReferences` responde *Cross reference service not available for tag*. Las referencias
salen del **export textual**, y `30-tools/scripts/Invoke-TiaTagUsage.ps1` las busca ahí.

## Cuatro hallazgos que costaron tiempo

1. **TIA no abre un proyecto cuya carpeta supere 143 caracteres.**
   `The specified path '…' (156 character) is too long. A maximum of 143 characters is allowed.`
   En modo aislado la excepción se come y solo queda `Failed to open project`, sin detalle. La
   copia de inspección va ahora a una ruta corta bajo `%TEMP%`, y el runner avisa con el número.
2. **El OB cíclico lo nombra TIA.** Una fuente externa con `ORGANIZATION_BLOCK "OB_Main"` falla con
   *Type conflict: Object "OB_Main" cannot be overwritten*. El nombre correcto es `"Main"`, y el
   patrón `OB_<Función>` del estándar aplica a los OB de arranque y de error.
3. **El DB de instancia se declara en la propia fuente SCL** con `DATA_BLOCK`. Sin esa declaración
   la llamada se resuelve como un tag y la compilación da 14 errores: *Tag "iDB_M01" not defined* y
   *The formal parameter '…' is invalid* para cada entrada.
4. **El modo aislado de `tia-inspect` no abre proyectos con WinCC Unified.** La inspección del
   post-apply pasa a `tia-create` en modo no aislado, sobre una copia desechable, con el session
   guard comprobando que no hay ninguna TIA visible con un proyecto abierto.

## Qué cambia respecto a ADR-015

| Afirmación en ADR-015 | A 2026-10-21, tarde |
|---|---|
| "PA-1 sigue pendiente" | **Cumplida**: los 5 entregables y la segunda frase, verificados |
| "El objetivo global PA-1 es crear un proyecto con HMI y responder trazabilidad" | Hecho, y con el límite de las herramientas de análisis medido |
| "La creación de proyecto con `ScaffoldProject` sigue sin ejecutarse de verdad" | **Ejecutada**: el runner tiene ahora `-SpecPath` y funciona con cualquier spec |

## No afirmamos todavía

- **Que el proyecto `DEMO-Cinta01` se haya descargado o ejecutado en una CPU virtual.** PA-1 no lo
  pedía. Los bloques sí están verificados en ejecución, pero en otro proyecto
  (`fb-alarm-latch` y `fc-escalado`).
- **Que la HMI se haya visto en un runtime.** La pantalla está creada y enlazada en el proyecto,
  pero **WinCC Unified Runtime no se ha arrancado**. La simulación HMI sigue siendo el hueco de
  R13, R14 y R20.
- **Que la cadena se repita sola, sin nadie delante.** La cadena se ejecutó **en frío dos veces
  seguidas** (234 s y 236 s, `exit 0`, árbol de software idéntico y los cinco entregables
  verificados en las dos: [`50-examples/demo-cinta01/pa1-en-frio.json`](../../50-examples/demo-cinta01/pa1-en-frio.json)),
  pero lo hizo este operador en este host. Lo que no está medido es que **otro agente**, desde
  sesión fría, la ejecute sin ayuda.

## Actualización posterior — la cadena completa, en frío y dos veces

El runner `Invoke-TiaProjectFromSpec.ps1` (antes `Invoke-AgentDemoScaffold.ps1`) encadena ya
**todo** el flujo, no solo el scaffold: proyecto y hardware → fuentes SCL → compilación → pantalla
HMI con sus bindings → export al `src/` del proyecto → informe del compilador en `ops/` →
`Check-TiaStandards` con **código de salida 0** → copia al espejo versionado → informe final.

```powershell
pwsh -File 30-tools/scripts/Invoke-TiaProjectFromSpec.ps1 `
    -SpecPath 50-examples/demo-cinta01/specs/scaffold.json `
    -HmiScreenPath 50-examples/demo-cinta01/hmi-screen.json `
    -MirrorPath 50-examples/demo-cinta01 `
    -ProjectReadmePath 50-examples/demo-cinta01/README.md `
    -OutputRoot 70-runs/e2e/pa1-cold-runN -Recreate -Apply
```

`-Recreate` borra el proyecto anterior y lo rehace desde cero, que es lo que hace la cadena
repetible. El runner sigue haciendo **dry-run primero** y comprobando con el session guard que
no haya ninguna TIA visible con un proyecto abierto.
