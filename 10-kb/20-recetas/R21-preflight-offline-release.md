# R21 — Preflight de la suite offline de release

## Propósito

`RunOfflineReleaseValidationSuite` es un helper de validación de archivos. No conecta TIA
Portal, no abre un `.ap20` y no autoriza ninguna escritura. Su nombre puede hacer que un agente
lo ejecute contra este workspace de ingeniería, aunque el contrato de la herramienta espera un
paquete de release distinto.

## Precondiciones

Ejecutar primero, desde la raíz del workspace:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
& .\30-tools\scripts\Test-TiaOfflineReleasePreconditions.ps1 `
  -WorkspaceRoot (Get-Location).Path `
  -OutputPath ".\70-runs\tia-capabilities\offline-release-preflight-$stamp.json"
```

La salida debe ser `READY`. El preflight comprueba:

- `TMP_EXPORT/_verify/UDT_Fault.xml` con `SW.Types.PlcStruct`.
- `TMP_EXPORT/_verify/TagTable_StartStop.xml` con `SW.Tags.PlcTagTable` y `SW.Tags.PlcTag`.
- `TMP_EXPORT/_verify/FC_StartStop.xml` con `SW.Blocks.FC` y `StructuredText`.
- un golden LAD/FlgNet en la ruta `TMP_EXPORT/Source/.../05-故障保护.xml` o en una alternativa
  documentada, con `SW.Blocks.FC` y `FlgNet`.
- `TMP_EXPORT/_verify/Sim_Data_roundtrip.xml/Sim_Data.xml` con `SW.Blocks.GlobalDB`.
- `docs/hmi_templates/unified_*.json` y el mapping de release si el paquete lo proporciona; si
  existe, el mapping debe ser JSON parseable (si no lo es, queda como advertencia y la suite debe
  seguir clasificándose por su `ok` interno).

Los cinco XML son muestras golden de la release del servidor. No se fabrican a partir de ejemplos
de `50-examples/`, no se copian desde un proyecto de cliente y no se modifican para hacer pasar el
preflight. Si falta cualquiera, el estado es **Bloqueado** y el siguiente paso es obtener el
paquete de fixtures autorizado o ejecutar solo las suites offline que crean sus propias fixtures.

## Ejecución

Solo con `READY`, invocar `RunOfflineReleaseValidationSuite` mediante la secuencia MCP normal,
con `workspaceRoot` exactamente igual al usado en el preflight y un `reportDirectory` bajo
`90-tmp/` o `70-runs/`. La respuesta debe tener `offlineOnly=true`, `ok=true` y todos los items
en `PASS`. Si el wrapper devuelve una respuesta nominal pero el texto interno contiene
`success=false`, se clasifica como **Bloqueado** y se conserva el JSON completo.

## Evidencia y parada

Guardar el JSON y Markdown de la suite, el informe de preflight y los hashes de los fixtures.
Una compilación offline o un resultado de esta suite no prueba importación en TIA, compilación de
un proyecto, PLCSIM, Runtime HMI ni comportamiento de máquina. Para esas capas usar las recetas
correspondientes y sus precondiciones.
