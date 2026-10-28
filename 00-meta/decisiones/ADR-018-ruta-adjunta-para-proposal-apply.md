# ADR-018 — Ruta adjunta para `Invoke-TiaSclProposalApply` mediante `tia-create` full

> Estado: **implementado; verificado en arnés mock; pendiente verificación end-to-end en TIA real** · Fecha: **2026-10-28** · Ámbito: TIA Portal V20, Openness, `tia-create --profile full`

## Contexto

El runner de propuestas SCL (`30-tools/scripts/Invoke-TiaSclProposalApply.ps1`) solo soportaba la
ruta aislada: el agente abre su propia instancia TIA con `tia-inspect --isolated` sobre un fixture
manifiesto. Para reemplazar un bloque en el proyecto que el usuario ya tiene abierto, la vía de
gegniería es el servidor `tia-create --profile full` adjuntado (`AttachToOpenProject`), tolerando
que la ventana visible es del usuario y jamás puede ser cerrada por el runner.

## Decisión

Añadir `-Route attached` (por defecto `isolated`, que queda intacta) al runner, fail-closed:

- Solo `.scl` y bloque en el nivel raíz (`groupPath` vacío): lo único que ADR-015/R28 y la lectura
  live del 2026-09-25 verificaron sobre el proyecto real. Un `.s7dcl` o un bloque anidado devuelven
  `BLOCKED` antes de abrir sesión MCP.
- Exige `-AttachProjectName` y una ventana TIA Portal visible con proceso detectado; sin esa
  guardia no hay llamada al servidor.
- Roster completo exigido en `tools/list`: `AttachToOpenProject`, `GetProjectTree`, `GetBlocks`,
  `GetTags`, `GoOffline`, `ImportPlcExternalSource`, `GenerateBlocksFromExternalSource`,
  `DeletePlcExternalSource`, `CompileSoftware`, `SaveProject`.
- Identidad del proyecto adjunto: el mensaje exacto de `AttachToOpenProject` y la primera línea de
  `GetProjectTree` deben coincidir con `-AttachProjectName`; un `Connect` correcto no es `Attach`
  (ADR-012).
- Gates completos por los contratos reales de `tia-create` (evidencia
  `70-runs/tia-capabilities/20260925-tia-create-safety-live-read-built.json`): `GetBlocks` con
  `meta.success`, bloque objetivo único, no F (`isFailsafe≠true`), sin `isKnowHowProtected`,
  `isConsistent` y `programmingLanguage=SCL`; `GetTags` con `meta.success`, `complete` y `count>`
  coherentes y ningún tag `isSafety` ni marcado sin clasificar. La inyección
  `-McpExecutablePath`/`-McpArguments` solo existe para `-Route attached` (harness de pruebas);
  en `isolated` se rechaza.
- Mutación con orden no negociable: `GoOffline → ImportPlcExternalSource →
  GenerateBlocksFromExternalSource → DeletePlcExternalSource → CompileSoftware → GetBlocks →
  SaveProject`. La entrada a la opción de mutación es puerta única: guardia de sesión, identidad y
  gates explícitos previos. Compile != 0/0 ⇒ informe `FAILED` con mutación registrada y SIN
  `SaveProject`; el informe dicta no guardar y reimportar la fuente original como restauración
  (sin copia del `.ap20`).
- No descarga hardware, no cambia el modo online de la CPU, no cierra TIA ni el proyecto del
  usuario (el lease `Local\\TIA-Claude-McpSession` serializa la sesión); `GoOffline` es un paso
  local de sesión de ingeniería, no un download.

## Implementado

| Pieza | Fichero | Estado |
|---|---|---|
| Aserciones de contrato de `tia-create` adjuntado | `30-tools/scripts/TiaSclSafety.ps1` (`Assert-TiaCreateAttachIdentity`, `Assert-TiaCreateBlockWritable`, `Assert-TiaCreateTagInventoryWritable`) | implementado |
| Ruta adjunta fail-closed y mutación/supervivencia de informe | `30-tools/scripts/Invoke-TiaSclProposalApply.ps1` | implementado |
| Arnés de 9 casos (identidad, roster, gates F/Safety, compile gate, orden exacto feliz) | `30-tools/tests/Test-TiaProposalApplyAttachedRoute.ps1` | PASS local |
| Check registrado (y CI-safe) | `30-tools/scripts/Run-WorkspaceChecks.ps1` | implementado |

La ruta aislada se mantuvo sin cambios de comportamiento; `Test-TiaSclProposalApply.ps1` sigue
en PASS completo como prueba de no regresión.

## Qué está verificado y qué no

- **Verificado en vivo, por partes:** `GoOffline → ImportPlcExternalSource →
  GenerateBlocksFromExternalSource → SaveProject` contra proyecto real (ADR-015, R28) y lectura
  adjuntada `AttachToOpenProject → GetProjectTree → GetBlocks/GetTags` con `isFailsafe`/`isSafety`
  (2026-09-25).
- **Solo arnés mock, sin TIA real:** la ruta completa con gates (identidad, roster,
  compile-gate fail-closed, orden exacto) sobre esta máquina. Un mock no substituye la sesión de
  Openness.
- **No verificado todavía:** `-Route attached` contra un proyecto de usuario abierto con la
  ventana visible. Debe pasar con el permiso del usuario y lectura previa; hay que ejecutarlo
  sobre la copia de trabajo o fixture desechable antes de considerar el estado `verificado`.
  Procedimiento preparado y checklist: [`docs/superpowers/plans/2026-10-28-verificacion-e2e-ruta-adjunta.md`](../../docs/superpowers/plans/2026-10-28-verificacion-e2e-ruta-adjunta.md).

## Bloqueo tras la ejecución E2E del 2026-10-28

El E2E se ejecutó hasta `APPLIED_AND_VERIFIED` (attach, gates, orden de mutación, compile 0/0,
save) sobre `C:\TIA-E2E\r-20261028-131155\`, pero **el paso 8 (export + diff) falló**: el fichero
estagiado llevaba `VERSION : 0.2` (hash `d348a47b…`) y el proyecto reabierto regenera
`VERSION : 0.1` (`HeaderVersion=0.1`). La propuesta solo cambiaba esa línea, así que su efecto
observable en el proyecto es nulo.

Por eso el estado **no** pasa a `verificado`: la verificación de la ruta adjunta reafirma solo
metadatos (tia-create no expone `GetBlockSource`) y un cambio sin efecto declararía éxito igual.
Falta una puerta de delta de contenido en la ruta adjunta antes de emitir `APPLIED_AND_VERIFIED`.
Registro completo: runbook §8. Restauración completada desde `pristine/` (fingerprint idéntico);
el original del repo está intacto.

## Nota de corrección incluida

Durante la implantación se detectó que en el binding del runner existía una colisión
inconsistente entre el parámetro `McpArguments` y el interno `mcpArguments` (los nombres de
variable de PowerShell no distinguen mayúsculas): el valor inyectado se descartaba y el runner
usaba argumentos por defecto. Se renombró la interna a `mcpServerArguments`; sin ello la prueba
del caso roster no podía pasar.
