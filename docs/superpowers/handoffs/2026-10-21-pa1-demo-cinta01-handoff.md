# Handoff — PA-1: proyecto DEMO-Cinta01 y trazabilidad

**Fecha:** 2026-10-21 (tarde)
**Objetivo:** cerrar el objetivo global PA-1 de `00-meta/02-plan.md`: crear el proyecto
`DEMO-Cinta01` desde una frase y responder una pregunta de trazabilidad sobre un proyecto
existente.
**Estado global:** `accepted=false` (la aceptación HMI en runtime sigue siendo el hueco), pero
**PA-1 está cumplida y verificada**.

Documento de hechos: [ADR-016](../../../00-meta/decisiones/ADR-016-pa1-cumplida.md).
Evidencia con los valores: [`50-examples/demo-cinta01/pa1-evidencia.json`](../../../50-examples/demo-cinta01/pa1-evidencia.json).
Receta del flujo: [R30](../../../10-kb/20-recetas/R30-crear-proyecto-desde-spec.md).

## Qué se creó

`40-projects/DEMO-Cinta01/` con:

- `tia/DEMO-Cinta01/DEMO-Cinta01.ap20` — proyecto V20 con CPU 1513-1 PN (`6ES7 513-1AM03-0AB0`)
  y HMI Unified (`6AV2123-3GB32-0AW0`). TIA mete el proyecto en una subcarpeta con su nombre.
- `src/` — export real: `Program blocks/{FB_Motor,iDB_M01,Main}.xml`, `tags/Cinta_Signals.xml`,
  `sources/*.scl` y `hmi-screen.json`.
- `ops/compile-report.json` y `ops/standards.json` — informes reales.
- `README.md` — con la plantilla de `20-standards/estructura-proyecto.md`.

Espejo **versionado** en `50-examples/demo-cinta01/`, porque `40-projects/` está excluido de git
por ADR-005: el diff legible del proyecto vive en el espejo.

## El flujo, que es lo reutilizable

```powershell
# 1. Proyecto, CPU, HMI, tags, fuentes SCL, compilación y guardado. Dry-run primero.
.\30-tools\scripts\Invoke-AgentDemoScaffold.ps1 `
    -SpecPath .\50-examples\demo-cinta01\specs\scaffold.json -Apply

# 2. Pantalla HMI con sus bindings (idempotente; -DryRun solo valida).
.\30-tools\scripts\Invoke-TiaHmiScreenFromJson.ps1 `
    -ScreenJsonPath .\50-examples\demo-cinta01\hmi-screen.json `
    -ProjectFile <ruta>\DEMO-Cinta01.ap20

# 3. Preguntar por una tag.
.\30-tools\scripts\Invoke-TiaTagUsage.ps1 -Tag "DI_M01_Start" `
    -ProjectName DEMO-Cinta01 -ExportPath .\40-projects\DEMO-Cinta01\src
```

El runner del scaffold se llama `Invoke-AgentDemoScaffold` pero ya no está cableado al ejemplo del
agent-demo: acepta `-SpecPath` y sirve para cualquier spec. Queda pendiente renombrarlo a algo
neutro (`Invoke-TiaProjectFromSpec`).

## La respuesta de la segunda frase

> *«¿Dónde se usa la tag `Motor_Marcha` y qué bloques la escriben?»*

`Motor_Marcha` **no existe**: el inventario real son 10 tags en `Cinta_Signals` y ninguno se
llama así. El motivo está escrito: `20-standards/naming.md` la cita como el **contraejemplo** de
su propia regla de identificadores en inglés.

La equivalente es **`DI_M01_Start`** (`%M0.1`): la escribe la HMI (botón `BTN_Start` →
`SetBitInTag("StartPB", 0)` → tag HMI `StartPB` → binding a `DI_M01_Start`) y la lee el OB
`Main` en `CmdStart := "DI_M01_Start"`, dentro de la llamada a `iDB_M01`.

## Los cuatro hallazgos, con su arreglo

1. **Límite de 143 caracteres de TIA para la carpeta del proyecto.** En modo aislado el error se
   come y solo sale `Failed to open project`. La copia de inspección va a una ruta corta bajo
   `%TEMP%` y hay un guard que lo dice con el número.
2. **El OB cíclico lo nombra TIA**: `ORGANIZATION_BLOCK "OB_Main"` → *Type conflict: Object
   "OB_Main" cannot be overwritten*. El nombre es `"Main"`.
3. **El DB de instancia se declara en la fuente SCL** con `DATA_BLOCK "iDB_M01"`. Sin eso, 14
   errores de compilación.
4. **El modo aislado de `tia-inspect` no abre proyectos con WinCC Unified.** La inspección pasa a
   `tia-create` no aislado sobre copia.

Y un límite de las herramientas, no del proyecto: `TraceTagCause`, `DescribeBlockLogic` y
`GetCrossReferences` no resuelven un tag global pasado como parámetro formal de una llamada a un
FB en SCL. Las referencias salen del export textual.

## Qué queda

- **PA-1 repetido en frío**, sin máquina delante, para probar que el flujo no necesita a nadie.
- **WinCC Unified Runtime**: la pantalla está hecha y enlazada, pero nunca se ha arrancado. Es el
  hueco de R13, R14 y R20 y la razón de que `accepted` siga en `false`.
- **Renombrar `Invoke-AgentDemoScaffold.ps1`** a algo neutro, ahora que acepta cualquier spec.
- **`FB_Motor` de la librería no se ha ejecutado en este proyecto**: `fb-alarm-latch` y
  `fc-escalado` sí están verificados en CPU virtual, pero `FB_Motor` no. Si se quiere, el plan
  funcional de `DEMO-Cinta01` es el siguiente natural.

## Estado de la máquina al terminar

- TIA Portal: cerrado (no queda ningun proceso abierto).
- Sin instancias de PLCSIM ni Control Panel.
- `Ethernet 2` en APIPA, como estaba.
