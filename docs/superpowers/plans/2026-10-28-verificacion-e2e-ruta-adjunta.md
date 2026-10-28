# Verificación E2E de `-Route attached` contra un TIA Portal real abierto

> **Estado:** **ejecutado el 2026-10-28**. Pasos 0–7 **PASS** (informe `APPLIED_AND_VERIFIED`);
> **paso 8 FAIL**: el cambio propuesto no quedó reflejado en el proyecto reabierto
> (`VERSION : 0.1` en vivo, `0.2` estagiado). ADR-018 **no** pasa a `verificado`; bloqueo exacto
> en el ADR y registro completo en §8.
> **Fecha:** 2026-10-28 · **Ámbito:** TIA Portal V20 + `tia-create --profile full` +
> `Invoke-TiaSclProposalApply.ps1 -Route attached`.
> **Requiere presencia humana:** abrir/cerrar TIA, confirmar el proyecto y decidir la parada.

---

## 1. Qué se verifica y qué no

**Se verifica de punta a punta sobre un proyecto real abierto (copia desechable):**

1. Guardia de sesión: el runner exige un TIA visible y no lanza ni cierra ninguna instancia.
2. Identidad: `AttachToOpenProject(<nombre>)` + raíz de `GetProjectTree` coinciden con el proyecto.
3. Roster: `tools/list` expone las 10 herramientas del ciclo antes de tocar nada.
4. Gates: bloque único, SCL, top-level, no-F, no Know-How, consistente; inventario completo de
   tags sin Safety ni clasificación desconocida.
5. Mutación: `GoOffline → ImportPlcExternalSource → GenerateBlocksFromExternalSource →
   DeletePlcExternalSource → CompileSoftware → GetBlocks → SaveProject`.
6. Compile-gate: 0/0 antes de guardar; con error, informe `FAILED`, sin `SaveProject` y con
   instrucción de no guardar.
7. Informe final: `APPLIED_AND_VERIFIED`, `tiaMutation=true`, `readOnly=false`, `applied=true`.
8. Restauración: reimportar la fuente original con el mismo runner (o reponer la copia prístina).

**No se verifica aquí:**

- Export textual automático: la ruta adjunta no lo hace (`export.reason`); se ejecuta después con
  R03 sobre la copia, con TIA cerrado.
- Descarga/online: prohibido. `GoOffline` es local de sesión, no un download.
- Importación `.s7dcl`: bloqueada por diseño en esta ruta.
- Bloques anidados: bloqueados por diseño (solo `groupPath` vacío).
- Aceptación humana: este documento no la declara; la firma el usuario tras revisar la evidencia.

---

## 2. Hechos del entorno comprobados en solo lectura (2026-10-28)

| Hecho | Resultado |
|---|---|
| TIA Portal V20 instalado | `C:\Program Files\Siemens\Automation\Portal V20` (2000.0.9501.1) |
| TIA Portal V19 instalado | `C:\Program Files\Siemens\Automation\Portal V19` (1900.3.501.1) |
| Procesos TIA en ejecución | **ninguno** (el runner no abre ninguna instancia) |
| `tia-create` V20 | `30-tools\mcp\tia-create\bin\v20\TiaMcpServer.exe` presente (1.0.0+218e829) |
| `tia-inspect` V20 | `30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe` presente |
| Proyecto demo disponible | `40-projects\DEMO-Cinta01\tia\DEMO-Cinta01\DEMO-Cinta01.ap20` |
| Export/sources del demo | `40-projects\DEMO-Cinta01\src` con `inventory.json`, `sources\FB_Motor.scl`, `Program blocks\*.xml` |
| PLC del demo | `PLC_1` (árbol del inventario y `ops\compile-report.json`) |
| Bloque elegido | `FB_Motor` (FB top-level, SCL, consistente, no protegido) |

Ninguna de estas comprobaciones abrió TIA, conectó a un PLC ni modificó el proyecto.

**Mitad offline validada en dry-run (2026-10-28):** pasos 1–3 ejecutados sobre una fixture
`90-tmp\e2e\attached-route-dryrun-*`: hash del original = hash de la copia, análisis con
`FB_Motor`/`PLC_1`/SCL, propuesta `PROPOSED` con `path=FB_Motor` y `projectPath` de la copia, y
preview `PREVIEW` con `localValidation.success=true`, `groupPath=''` y
`sourceDeclaration.kind=FUNCTION_BLOCK`. La parte que toca TIA (pasos 4–9) **no se ha ejecutado**.

> **Nota sobre el inventario:** `40-projects\DEMO-Cinta01\src\inventory.json` tiene el esquema
> plano (`blocks[]` en la raíz, `plcs` vacío). El análisis semántico espera
> `plcs[].softwarePath` + `plcs[].blocks[]`. En el Paso 2 se construye un **dossier de fixture**
> envolviendo esos mismos bloques bajo `PLC_1` y reescribiendo solo `projectPath` a la copia.
> Es un artefacto de fixture, no evidencia live; los gates reales los decide el runner contra TIA.
> El análisis (`Invoke-TiaProjectAnalysis.ps1`) normaliza `path` vacío a `path=name` en bloques
> top-level, así que el dossier no necesita parchear bloque a bloque.

---

## 3. Reglas duras y criterios de aborto

**Nunca:** escribir en producción, abrir un PLC real, download/online, cerrar o reiniciar el TIA
del usuario, modificar el proyecto original `40-projects\DEMO-Cinta01\...`, ni saltarse un gate.

**Abortar sin reintentar** si ocurre cualquiera de estas:

- El proyecto abierto no es la **copia** (título/nombre o ruta no coinciden) o hay otra instancia.
- El nombre del proyecto en TIA no es exactamente `DEMO-Cinta01`.
- Aparece cualquier tag Safety, bloque F, Know-How o inconsistencia.
- `CompileSoftware` devuelve errores o **advertencias** (>0 en cualquiera).
- TIA muestra un diálogo de conexión online, download, licencia o firmware.
- Se pierde la ventana visible o el lease `Local\TIA-Claude-McpSession`.
- Cualquier mensaje pide credenciales o datos que no estén en el repositorio.
- El usuario no está delante para confirmar pasos humanos.

En aborto: no guardar, no cerrar TIA, conservar el informe y restaurar si hubo mutación.

---

## 4. Checklist pre-vuelo (antes de tocar nada)

Marcar todo antes del Paso 6. `[A]` = agente, `[H]` = humano.

| # | Comprobación | Cómo | Esperado | Quién |
|---|---|---|---|---|
| 1 | Árbol git limpio o solo cambios conocidos | `git status --short` | sin sorpresas ajenas | A |
| 2 | Base verde | `pwsh -File 30-tools/scripts/Run-WorkspaceChecks.ps1` | `success=true`, 0 BLOCKED | A |
| 3 | Sin TIA abierto al empezar | `Get-Process Siemens.Automation.Portal*` | vacío | A |
| 4 | Copia desechable creada y hasheada | Paso 1 | hash original = hash copia; original intacto | A |
| 5 | Backup prístino guardado | Paso 1 | carpeta `pristine/` completa | A |
| 6 | Propuesta generada y revisada | Paso 2 | `proposal.json` + diff; `groupPath` vacío; hashes OK | A |
| 7 | Preview local sin TIA | Paso 3 | `status=PREVIEW`, sin conexión | A |
| 8 | Copia abierta en TIA | Paso 4 | título `DEMO-Cinta01`, ruta = copia | H |
| 9 | Ventana maximizada y sin diálogos | observación | ventana visible, sin avisos | H |
| 10 | Sin conexión online ni PLC real | observar TIA | offline, ningún PLC físico | H |
| 11 | Licencia OK (sin aviso) | observar TIA | sin mensaje de licencia | H |
| 12 | El usuario autoriza la mutación sobre la copia | confirmación explícita | "sí, aplica sobre la copia" | H |
| 13 | `AttachProjectName` exacto | `DEMO-Cinta01` | coincide con el título | A+H |
| 14 | Preflight automatizado READY | Paso 4.5 | `status=READY`, exit 0 | A |

---

## 5. Procedimiento

### Paso 0 — Congelar base

```powershell
git status --short
pwsh -NoProfile -File 30-tools/scripts/Run-WorkspaceChecks.ps1
```

No continuar si hay BLOCKED o cambios sin explicar.

### Paso 1 — Copia desechable + backup prístino

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$fixture = "90-tmp\e2e\attached-route-$stamp"
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
Copy-Item '40-projects\DEMO-Cinta01\tia\DEMO-Cinta01' (Join-Path $fixture 'pristine') -Recurse -Force
Copy-Item (Join-Path $fixture 'pristine') (Join-Path $fixture 'Demo_Copy') -Recurse -Force
$originalProject = '40-projects\DEMO-Cinta01\tia\DEMO-Cinta01\DEMO-Cinta01.ap20'
$copyProject = (Resolve-Path (Join-Path $fixture 'Demo_Copy\DEMO-Cinta01.ap20')).Path
(Get-FileHash -Algorithm SHA256 $originalProject).Hash
(Get-FileHash -Algorithm SHA256 $copyProject).Hash          # debe ser igual
```

Registrar `$fixture` y ambos hashes. El proyecto original no se abre en ningún momento.

### Paso 2 — Dossier offline y propuesta SCL (sin TIA)

```powershell
$dossier = Join-Path $fixture 'dossier'
New-Item -ItemType Directory -Path (Join-Path $dossier 'src') -Force | Out-Null
Copy-Item '40-projects\DEMO-Cinta01\src\*' (Join-Path $dossier 'src') -Recurse -Force

# Fixture: envolver los bloques existentes bajo PLC_1 y apuntar projectPath a la COPIA.
# El analisis normaliza path='' (top-level) a path=name; no hay que parchear bloques.
$inv = Get-Content '40-projects\DEMO-Cinta01\src\inventory.json' -Raw | ConvertFrom-Json
$fixtureInventory = [ordered]@{
    schemaVersion = 1
    readOnly      = $true
    generatedAt   = (Get-Date).ToString('o')
    projectPath   = $copyProject
    projectTree   = $inv.projectTree
    plcs          = @([ordered]@{
        name         = 'PLC_1'
        softwarePath = 'PLC_1'
        blocks       = @($inv.blocks)
    })
    # El analisis tambien recorre blocks[] de nivel raiz; se repiten los mismos
    # bloques y los deduplica por path+name ya normalizados.
    blocks        = @($inv.blocks)
}
$fixtureInventory | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $dossier 'inventory.json') -Encoding UTF8

# SourceRoot debe ser src\sources: si se pasa todo src, el analisis encuentra antes los
# XML de Program blocks y la propuesta rechaza la fuente por no ser .scl/.s7dcl.
pwsh -NoProfile -File 30-tools/scripts/Invoke-TiaProjectAnalysis.ps1 `
  -InventoryPath (Join-Path $dossier 'inventory.json') `
  -SourceRoot (Join-Path $dossier 'src\sources') `
  -OutputPath (Join-Path $dossier 'analysis.json') `
  -Objective 'E2E ruta adjunta: cambio trazable y reversible en copia desechable'

pwsh -NoProfile -File 30-tools/scripts/New-TiaSclProposal.ps1 `
  -AnalysisPath (Join-Path $dossier 'analysis.json') `
  -BlockName FB_Motor `
  -FindText 'VERSION : 0.1' `
  -ReplaceText 'VERSION : 0.2' `
  -OutputDirectory (Join-Path $dossier 'proposal') `
  -Objective 'E2E ruta adjunta: subir version de FB_Motor en la copia desechable'
```

Revisar (obligatorio):

```powershell
Get-Content (Join-Path $dossier 'proposal\proposal.diff')
$p = Get-Content (Join-Path $dossier 'proposal\proposal.json') -Raw | ConvertFrom-Json
$p.status; $p.block; $p.source; $p.checks
```

Esperado: `PROPOSED`, bloque `FB_Motor`/`SCL`, `block.path` sin `/` (groupPath vacío),
`checks.uniqueReplacement=true`, hashes presentes. El cambio (0.1→0.2) es un ejemplo revisable:
cualquier reemplazo único y compilable sirve para verificar la ruta.

> Si `New-TiaSclProposal` rechaza el bloque por hallazgos, **parar**: no se fuerza el gate.

### Paso 3 — Preview local (sin TIA, sin `-Apply`)

```powershell
$proposal = (Resolve-Path (Join-Path $dossier 'proposal\proposal.json')).Path
pwsh -NoProfile -File 30-tools/scripts/Invoke-TiaSclProposalApply.ps1 `
  -ProposalPath $proposal `
  -ProjectFile $copyProject `
  -ReportRoot (Join-Path $fixture 'preview-reports')
```

Esperado: informe `PREVIEW`, `localValidation.success=true`, sin llamada MCP. Esto valida
hashes, ruta de proyecto, SCL y top-level antes de implicar a TIA.

### Paso 4 — Abrir la copia en TIA (humano)

1. Abrir `Demo_Copy\DEMO-Cinta01.ap20` (no el original) con TIA Portal V20.
2. Confirmar que el título/nombre del proyecto es **`DEMO-Cinta01`**.
3. Maximizar la ventana y comprobar que no hay conexión online ni PLC real.
4. Confirmar que no hay otra instancia de TIA abierta.

No continuar hasta que 1–4 estén confirmados.

### Paso 4.5 — Preflight automatizado (solo lectura)

```powershell
pwsh -NoProfile -File 30-tools/scripts/Test-TiaAttachedRoutePreflight.ps1 `
  -ProposalPath $proposal `
  -ProjectFile $copyProject `
  -AttachProjectName 'DEMO-Cinta01' `
  -BackupProjectFile (Join-Path $fixture 'pristine\DEMO-Cinta01.ap20') `
  -OutputPath (Join-Path $fixture 'preflight.json')
```

Esperado: `"status": "READY"` y exit 0. Si devuelve `BLOCKED`, corregir el check señalado
(`tia-process`, `tia-create-binary`, `project-file`, `backup-copy`, `proposal-*`) y repetir;
no lanzar los Pasos 5–6. El script no abre MCP: no verifica roster ni identidad real, eso lo
decide el runner en la sesión live. También puede ejecutarse antes de abrir TIA para validar
copia y propuesta: entonces bloqueará solo en `tia-process`, que es lo esperado.

### Paso 5 — Gate negativo opcional (seguro, sin mutación)

Con la copia abierta, lanzar la misma orden con un nombre que no exista:

```powershell
pwsh -NoProfile -File 30-tools/scripts/Invoke-TiaSclProposalApply.ps1 `
  -ProposalPath $proposal `
  -ProjectFile $copyProject `
  -ReportRoot (Join-Path $fixture 'negative-reports') `
  -Route attached -Profile write -AcknowledgeWriteProfile -Apply `
  -AttachProjectName 'DEMO-Cinta01_NO_EXISTE'
```

Esperado: fallo en identidad/attach, `tiaMutation=false`, sin mutación. Si este caso llegara a
mutar, **abortar el E2E completo**: sería un fallo del gate.

### Paso 6 — Aplicación real sobre la copia

```powershell
pwsh -NoProfile -File 30-tools/scripts/Invoke-TiaSclProposalApply.ps1 `
  -ProposalPath $proposal `
  -ProjectFile $copyProject `
  -ReportRoot (Join-Path $fixture 'apply-reports') `
  -Route attached -Profile write -AcknowledgeWriteProfile -Apply `
  -AttachProjectName 'DEMO-Cinta01'
```

El runner imprime la ruta del `apply-report.json`. No interactuar con TIA durante la ejecución
(salvo que un diálogo bloquee; entonces abortar y documentar).

### Paso 7 — Verificación del informe

```powershell
$report = Get-ChildItem (Join-Path $fixture 'apply-reports') -Recurse -Filter apply-report.json |
  Sort-Object LastWriteTime | Select-Object -Last 1 | Get-Content -Raw | ConvertFrom-Json
$report.status            # APPLIED_AND_VERIFIED
$report.applied           # True
$report.tiaMutation       # True
$report.readOnly          # False
$report.compile.errorCount    # 0
$report.compile.warningCount  # 0
$report.save.success      # True
$report.verification.success  # True
$report.sessionGuard      # open-tia-window, PIDs visibles
$report.attach.projectName    # DEMO-Cinta01
```

Comprobar además en TIA, a ojo: el bloque `FB_Motor` existe, la compilación está limpia y el
proyecto quedó guardado.

### Paso 8 — Export R03 y diff textual (cierre de evidencia)

La ruta adjunta **no exporta**. Con la copia ya guardada:

1. Cerrar la copia en TIA (humano; nunca cerrar otra instancia/proyecto).
2. Exportar la copia con R03 (`tia-inspect` aislado sobre `$copyProject`) a
   `$fixture\export\src`.
3. Comparar `export\src\sources\FB_Motor.scl` con `proposal\FB_Motor.scl`:

```powershell
$exported = Get-Content (Join-Path $fixture 'export\src\sources\FB_Motor.scl') -Raw
if ($exported -notmatch [regex]::Escape('VERSION : 0.2')) { throw 'El export no refleja el cambio aplicado.' }
```

Registrar hashes del `.ap20` copia antes/después y del original (debe seguir intacto).

### Paso 9 — Restauración

**Preferente (mismo runner):** generar una propuesta que devuelva el texto original (fuente
original del proposal → reemplazo inverso 0.2→0.1) y aplicarla igual que el Paso 6. Verificar
compile 0/0 y readback.

**Fallback:** con TIA cerrado, sustituir `Demo_Copy` por `pristine` (copia byte a byte) y
reasignar la ruta si hiciera falta. El original nunca se toca.

Documentar cuál se usó y el resultado.

### Paso 10 — Evidencia y estado

Guardar bajo `70-runs\e2e\attached-route-<stamp>\` (o el `$fixture`): `proposal.json`, `diff`,
`analysis.json`, informes `PREVIEW`/negativo/`APPLIED`, export y hashes.

Actualizar ADR-018 **solo si el flujo completo pasó**: cambiar “pendiente verificación
end-to-end” por “verificado en vivo el <fecha>” citando el informe. Si falló, añadir el bloqueo
exacto y no cambiar el estado. No declarar aceptación humana: eso lo firma el usuario.

---

## 6. Mapa informe → aserciones (fallos esperables)

| Señal en el informe | Significado | Acción |
|---|---|---|
| `sessionGuard.status=no-tia-process` | No hay TIA abierto | Abrir la copia; no relanzar el runner a ciegas |
| `sessionGuard.status=no-visible-tia-window` | Proceso sin ventana | Restaurar la ventana; no continuar con UI oculta |
| `attach` ausente / `BLOCKED` | Nombre de proyecto incorrecto | Verificar título exacto; no adivinar variantes |
| `capabilityAvailable=false` | Roster incompleto | Comprobar `--profile full`/binario; no improvisar |
| Bloqueo antes de mutación | gate F/Safety/Know-How/consistencia/SCL/top-level | Respetar el veto; elegir otro bloque, no forzar |
| `status=FAILED`, `save.success=false` | Compile >0/0 | No guardar; restaurar si hubo mutación |
| `export.reason` presente | Export no incluido en la ruta | Ejecutar R03 después (Paso 8) |

---

## 7. Estimación y paradas humanas

- Preparación offline (pasos 0–3): ~10 min de agente, sin TIA.
- Intervención humana: abrir copia (~2 min), confirmar checklist (~3 min), cerrar copia (~1 min).
- Aplicación: 1–3 min de runner (10 llamadas MCP serializadas).
- Export/diff/restauración: ~10–15 min según R03.

---

## 8. Registro de ejecución — 2026-10-28

**Fixture:** `C:\TIA-E2E\r-20261028-131155\` (raíz corta).

> **Hallazgo operativo (raíz del path largo):** el primer intento situó la copia bajo el árbol
> largo del repositorio y **TIA no abrió el proyecto por ruta demasiado larga**. Se recreó la
> fixture en `C:\TIA-E2E\...` (56 caracteres) y la copia abrió a la primera. Mantener las
> copias desechables fuera del árbol profundo del repo.

| Paso | Resultado | Evidencia |
|---|---|---|
| 0 — base congelada | PASS | `git status` conocido; checks previos en verde |
| 1–3 — copia, análisis, propuesta, preview | PASS | `fixture.json`, `dossier/`, `previewStatus=PREVIEW` |
| 4 — copia abierta en TIA | PASS (humano/agent) | título `C:\TIA-E2E\...\Demo_Copy\DEMO-Cinta01` |
| 4.5 — preflight | PASS `READY` | `preflight-before-open.json` (tras abrir TIA: `-ExpectedProjectSha256` porque TIA bloquea el `.ap20`, `Get-FileHash` no lo lee abierto) |
| 5 — gate negativo | **no ejecutado** | pendiente |
| 6 — aplicación real | PASS | `apply-reports/20261028-131815-078-3844f967…/apply-report.json` |
| 7 — informe | PASS | `status=APPLIED_AND_VERIFIED`, `applied=true`, `tiaMutation=true`, attach `DEMO-Cinta01`, roster 10/10, tags 10 sin Safety, import `Blocks generated from external source 'FB_Motor'`, compile **0/0**, `save.success=true` |
| 8 — export R03 + diff | **FAIL** | ver abajo |
| 9 — restauración | PASS | `Demo_Copy` rehecha desde `pristine/`: fingerprint `0b30cd0d…` idéntico, `.ap20` = `bf3332f4…` = original del repo (intacto) |
| 10 — evidencia | PASS | este documento + ADR-018 (bloqueo, sin cambiar estado) |

### Paso 8 — el fallo exacto

La ruta adjunta no exporta (`export.attempted=false`), y `tia-inspect.OpenProject` está
restringido al fixture aislado (manifiesto `.tia-agent-fixture.json` con snapshots idénticos,
imposible tras mutar la copia), así que el export se hizo **en modo attach** con la copia abierta:
`Connect → GenerateSources(PLC_1) → Disconnect`.

- Fichero estagiado para el import (hash del informe `d348a47b…`): **`VERSION : 0.2`** ✅
- Fuente regenerada desde el proyecto **reabierto**: **`VERSION : 0.1`** ❌
- Atributo live `HeaderVersion` = **`0.1`** ❌ (tras cierre y reapertura: estado en disco).
- El import **sí tocó el bloque** (`InterfaceModifiedDate`/`CodeModifiedDate` 12:18:4x), así que
  el fallo es específico: **la cabecera `VERSION` de la fuente estagiada no se aplicó**.
- La propuesta solo cambiaba esa línea (`0.1 → 0.2`), de modo que el efecto observable de la
  propuesta en el proyecto es **nulo**.

`ExportPlcAsSourceTree` no sirve para comprobarlo: omite los FB/OB SCL (limitación ya
registrada; solo exportó `iDB_M01.s7dcl` + tablas XML). `GenerateSources` sí los emite.

### Lectura honesta

El informe `APPLIED_AND_VERIFIED` es veraz sobre la **mecánica** (attach, gates, orden de
mutación, compile 0/0, guardado), pero **no prueba que el cambio propuesto haya quedado**: la
verificación de la ruta adjunta solo reafirma metadatos (SCL/no-F/no-protegido/consistente) porque
`tia-create` no expone `GetBlockSource` — el propio informe lo advierte y remite a este paso 8.
Resultado: un cambio sin efecto declararía igualmente éxito. **ADR-018 sigue `pendiente
verificación end-to-end`**; el bloqueo está escrito en el ADR.

**Para desbloquear (orden propuesto):** (1) añadir al runner una **puerta de delta de contenido**
en ruta adjunta — readback con `tia-inspect` en attach (`GenerateSources`/`GetBlockSource`,
comparación normalizada contra la propuesta) antes de emitir `APPLIED_AND_VERIFIED`;
(2) investigar/documentar si Openness V20 ignora las cabeceras SCL (`VERSION`/`AUTHOR`/`FAMILY`)
en `GenerateBlocksFromExternalSource` y, si es así, vetar propuestas cuyo único cambio sea la
cabecera; (3) reejecutar este runbook completo.

**Estado final de la sesión:** TIA cerrada por el agente (su propia instancia, 0 procesos
`Siemens.Automation.Portal`), copia restaurada, original del repositorio intacto.

Paradas obligatorias: Pasos 4, 6 (autorización), 8 (cierre) y 9 (decisión de restauración).
