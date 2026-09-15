# Scripts

Herramientas de consola para operar TIA Portal por Openness sin depender de un cliente MCP.
Útiles para lotes, para depurar, y para trabajar sin reiniciar la sesión del agente.

| Script | Qué hace |
|---|---|
| [`Invoke-TiaMcp.ps1`](Invoke-TiaMcp.ps1) | Cliente MCP mínimo por stdio. La base de todo lo demás |
| [`Invoke-McpToolsSmoke.ps1`](Invoke-McpToolsSmoke.ps1) | Comprueba transporte stdio y roster de herramientas sin tocar TIA |
| [`Invoke-McpToolCall.ps1`](Invoke-McpToolCall.ps1) | Ejecuta una llamada MCP aislada para fixtures y pruebas |
| [`Invoke-McpToolSequence.ps1`](Invoke-McpToolSequence.ps1) | Ejecuta una secuencia ordenada sobre una única sesión MCP |
| [`Inspect-McpToolSchemas.ps1`](Inspect-McpToolSchemas.ps1) | Lee `tools/list` y guarda las firmas exactas del roster MCP sin conectar a un proyecto |
| [`Invoke-AgentDemoScaffold.ps1`](Invoke-AgentDemoScaffold.ps1) | Dry-run y scaffold controlado del proyecto PLC de aceptación |
| [`Export-HarnessAdapter.ps1`](Export-HarnessAdapter.ps1) | Exporta perfiles a Claude Code, Codex u OpenCode sin tocar sus configuraciones |
| [`Migrate-Examples.ps1`](Migrate-Examples.ps1) | Migra, compila e inventaría los proyectos de `50-examples` |
| [`Export-Sources.ps1`](Export-Sources.ps1) | Exporta el código a `.s7dcl` para git — receta [R03](../../10-kb/20-recetas/R03-exportar-a-git.md) |
| [`Invoke-TiaStandardsSweep.ps1`](Invoke-TiaStandardsSweep.ps1) | Inventaría todos los `.ap20` V20 y ejecuta el checker en **solo lectura** |
| [`Write-TiaAcceptanceStatus.ps1`](Write-TiaAcceptanceStatus.ps1) | Genera el estado honesto de aceptación: verificado, no verificado, bloqueado y supuesto |
| [`Find-TiaRuntimeMedia.ps1`](Find-TiaRuntimeMedia.ps1) | Busca medios de instalación Runtime/TIA sin instalar nada y exige confirmación para el siguiente paso |
| [`Write-TiaSimulationReadiness.ps1`](Write-TiaSimulationReadiness.ps1) | Preflight de simulación: separa disponibilidad PLC, compatibilidad HMI V20 y evidencia conductual |
| [`Invoke-TiaSimulationAcceptance.ps1`](Invoke-TiaSimulationAcceptance.ps1) | Preflight y aceptación PLC en PLCSIM: compila, valida rutas y descarga solo con confirmación virtual explícita |
| [`Invoke-TiaProjectAnalysis.ps1`](Invoke-TiaProjectAnalysis.ps1) | Genera un dossier semántico de solo lectura desde un inventario MCP y fuentes exportadas |
| [`New-TiaIoList.ps1`](New-TiaIoList.ps1) | Genera lista JSON/CSV/Markdown de E/S solo si hay tags detalladas verificables |
| [`New-TiaFunctionalDescription.ps1`](New-TiaFunctionalDescription.ps1) | Compone una descripción funcional trazable desde dossier e I/O |
| [`Convert-TiaTagTableExportToInventory.ps1`](Convert-TiaTagTableExportToInventory.ps1) | Normaliza XML real de `ExportPlcTagTable` para R15, sin depender de `GetTags` |
| [`Merge-TiaTagEvidenceIntoInventory.ps1`](Merge-TiaTagEvidenceIntoInventory.ps1) | Une tags detalladas al inventario de bloques usando el `softwarePath` exacto |
| [`New-TiaSclProposal.ps1`](New-TiaSclProposal.ps1) | Genera una propuesta SCL, copia, diff y hashes sin modificar el original ni TIA |
| [`Invoke-TiaWorkflow.ps1`](Invoke-TiaWorkflow.ps1) | Orquesta `analyze`, `propose` y `apply` con preview local y perfil de escritura explícito |
| [`Stop-TiaPortal.ps1`](Stop-TiaPortal.ps1) | Cierra las instancias headless que `Disconnect` **no** cierra |

---

## `Invoke-TiaMcp.ps1`

```powershell
# Diagnóstico
.\Invoke-TiaMcp.ps1 -Calls @(@{ name='Doctor' })

# Cadena sobre la misma conexión
.\Invoke-TiaMcp.ps1 -TimeoutSeconds 900 -Calls @(
    @{ name='Connect' },
    @{ name='OpenProject';   args=@{ path='...\Proyecto.ap20' } },
    @{ name='GetPlcSummary'; args=@{ softwarePath='PLC_1' } },
    @{ name='CloseProject' },
    @{ name='Disconnect' }
)
```

🔒 **Todas las llamadas van sobre la misma conexión**, en orden. Eso importa: `Connect` y
`OpenProject` dejan estado en el servidor, así que lo que venga después tiene que ir en la misma
invocación.

| Parámetro | |
|---|---|
| `-TimeoutSeconds` | 300 por defecto. **`OpenProject` con migración tarda 30-130 s**; sube a 900 para proyectos grandes |
| `-ContinueOnError` | Por defecto la cadena para al primer fallo. Con esto sigue — para lotes de items independientes |
| `-AllowWrite` | ⚠️ Registra las 40 herramientas destructivas. Ver [ADR-006](../../00-meta/decisiones/ADR-006-limites-seguridad.md) |
| `-TiaMajor` | 20 por defecto |

Devuelve objetos con `Tool`, `IsError`, `Seconds`, `Text` (el JSON de respuesta) y `Raw`.

## `Invoke-McpToolSequence.ps1`

Usa una única sesión MCP para una secuencia genérica, incluso con servidores distintos de
`tia-inspect`. Es el adaptador adecuado para flujos con estado como `Bootstrap → Connect →
Attach/Open → leer → Close/Disconnect`.

```powershell
.\Invoke-McpToolSequence.ps1 `
  -ExecutablePath "..\mcp\tia-create\bin\v20\TiaMcpServer.exe" `
  -Arguments "--tia-major-version 20 --profile lite" `
  -Calls @(
    @{ name = 'Bootstrap' },
    @{ name = 'Connect' },
    @{ name = 'GetState' },
    @{ name = 'Disconnect' }
  )
```

La prueba permanente `Test-McpToolSequence.ps1` verifica el protocolo y que todas las llamadas
quedan registradas en el mismo informe. El helper no concede permisos de escritura: los decide
el perfil del ejecutable.

## `Inspect-McpToolSchemas.ps1`

El perfil `lite` mantiene pequeño el roster visible, pero no elimina capacidades: `tia-create`
puede exponerlas a través de `FindTools`/`CallTool`. Cuando haya que automatizar una capacidad no
listada, inspecciona primero el esquema real con el perfil `full`:

```powershell
.\Inspect-McpToolSchemas.ps1 `
  -ExecutablePath "..\mcp\tia-create\bin\v20\TiaMcpServer.exe" `
  -Arguments "--tia-major-version 20 --profile full" `
  -ToolName CheckDownloadReadiness,DownloadToPlc,GetDeviceIpAddress,GetOnlineState `
  -OutputPath "..\..\70-runs\mcp\schemas.json"
```

Es una operación de solo lectura: solo ejecuta el handshake y `tools/list`. No conecta con TIA,
no abre proyectos y no modifica red, PLC ni archivos de proyecto. La salida es la fuente de verdad
para construir el JSON de `CallTool` y evita inventar nombres o parámetros.

## `Invoke-TiaSimulationAcceptance.ps1`

El modo predeterminado solo genera un preview. La ejecución real exige que el preflight tenga
operativos el toolchain PLC, el adaptador virtual y la sesión TIA, además de los datos exactos del
proyecto y `-AcknowledgeVirtualTarget`. La herramienta inspecciona `CheckDownloadReadiness` y
rechaza la descarga si ninguna ruta contiene el adaptador PLCSIM solicitado.

```powershell
.\Invoke-TiaSimulationAcceptance.ps1 `
  -ProjectFile "...\\Sorting Plant Control_V20.ap20" `
  -ProjectName "Sorting Plant Control_V20" `
  -SoftwarePath "Sorting Plant Controller" `
  -TargetIpAddress "192.168.0.1" `
  -StartVirtualPlc -AcknowledgeVirtualTarget -Run
```

El runner utiliza por defecto `tia-create` V20 con el perfil `full` para disponer de los esquemas
de descarga. Con `-StartVirtualPlc` también mantiene viva la instancia nativa 1516F y la limpia
en `finally`; si no se pasa, la instancia debe estar gestionada externamente. No se debe cambiar
`-VirtualInterfacePattern` a una NIC física para el acceptance PLC.

Para añadir una aceptación conductual, `-IoPlanPath` recibe un JSON con `steps[].command` y
`steps[].expect`; exige además `-StartVirtualPlc` y registra todas las respuestas del protocolo
nativo. La receta completa está en [`R17`](../../10-kb/20-recetas/R17-aceptacion-plcsim.md).

## `Invoke-TiaProjectAnalysis.ps1`

Construye un dossier JSON y Markdown sin abrir ni modificar TIA. Consume un inventario `readOnly`
producido por MCP y el árbol de fuentes exportadas; reconoce declaraciones SCL (`.s7dcl` y `.scl`) y
exportaciones individuales XML (`ExportBlock`).

```powershell
.\Invoke-TiaProjectAnalysis.ps1 `
  -InventoryPath "...\inventory.json" `
  -SourceRoot "...\export" `
  -Objective "Entender la estructura antes de proponer cambios"
```

El informe calcula cobertura de fuentes, tipos y lenguajes, referencias de llamadas y hallazgos
de protección, inconsistencias, comentarios ausentes y tablas de tags por defecto. `-FailOnBlockingFindings`
devuelve código 1 si el inventario contiene objetos que no se pueden tocar.

## `Convert-TiaTagTableExportToInventory.ps1`

Convierte una exportación XML de `ExportPlcTagTable` en el inventario detallado que consume R15.
Es la ruta de compatibilidad cuando el servidor visible no publica `GetTags`: en `tia-create lite`
se localiza `ExportPlcTagTable` con `FindTools` y se invoca mediante `CallTool`.

```powershell
.\Convert-TiaTagTableExportToInventory.ps1 `
  -ExportPath "...\Sorting-Plant-Tags.xml" `
  -OutputPath "...\inventory-tags.json" `
  -ProjectPath "...\Project.ap20" `
  -SoftwarePath "Sorting Plant Controller"
```

El conversor conserva tipo, dirección, nombre y comentario multilingüe; no deduce tags que no
estén presentes en el XML.

`Merge-TiaTagEvidenceIntoInventory.ps1` combina ese resultado con el inventario de bloques de
`tia-inspect`. Rechaza si el `softwarePath` no identifica exactamente un PLC, de modo que el
análisis semántico y R16 reciben una única evidencia coherente.

## `New-TiaSclProposal.ps1`

Genera una propuesta de un único reemplazo textual en una fuente `.s7dcl` o `.scl` enlazada desde el
dossier. Rechaza bloques protegidos, inconsistentes, no-SCL, fuentes ausentes o reemplazos
ambiguos. La carpeta de salida contiene `proposal.json`, una copia propuesta, `proposal.diff` y
`proposal.md`; el fichero original y TIA permanecen intactos.

```powershell
.\New-TiaSclProposal.ps1 `
  -AnalysisPath "...\analysis.json" `
  -BlockName "FB_Motor" `
  -FindText '#Run := #CmdStart AND #Interlock;' `
  -ReplaceText '#Run := #CmdStart AND #Interlock AND #Ready;'
```

Aplicar una propuesta es deliberadamente otra operación y debe seguir el ciclo de escritura de
`AGENTS.md`.

## `Invoke-TiaSclProposalApply.ps1`

Valida una propuesta y, solo con `-Apply`, ejecuta el flujo de escritura V20. Sin `-Apply` no
conecta con TIA y deja un informe `PREVIEW`. Con `-Apply` exige proyecto exacto, backup,
instancia TIA no visible, lectura de árbol y bloque, importación, compilación con 0 errores y 0
advertencias, guardado, exportación y lectura posterior. Las fuentes `.s7dcl` usan
`PreviewImport` + `ImportFromDocuments`; las `.scl` se colocan en `Program blocks/<grupo>` y usan
`ImportSources`. Nunca descarga a hardware.

```powershell
.\Invoke-TiaSclProposalApply.ps1 `
  -ProposalPath "...\proposal.json" `
  -ProjectFile "...\Proyecto_V20.ap20" `
  -ReportRoot "...\70-runs\proposal-apply"       # preview local

# Aplicación real: revisar proposal.json/diff y cerrar TIA visible antes de usar -Apply
.\Invoke-TiaSclProposalApply.ps1 `
  -ProposalPath "...\proposal.json" `
  -ProjectFile "...\Proyecto_V20.ap20" `
  -Apply
```

## `Invoke-TiaWorkflow.ps1`

Punto de entrada semántico para snapshots y aplicación controlada:

```powershell
.\Invoke-TiaWorkflow.ps1 -Workflow analyze `
  -InventoryPath "...\inventory.json" -SourceRoot "...\export"

.\Invoke-TiaWorkflow.ps1 -Workflow propose `
  -AnalysisPath "...\analysis.json" -BlockName "FB_Motor" `
  -FindText '#Run := #CmdStart AND #Interlock;' `
  -ReplaceText '#Run := #CmdStart AND #Interlock AND #Ready;'

.\Invoke-TiaWorkflow.ps1 -Workflow apply `
  -ProposalPath "...\proposal.json" -ProjectFile "...\Proyecto_V20.ap20" `
  -Profile read                                      # preview local

.\Invoke-TiaWorkflow.ps1 -Workflow apply `
  -ProposalPath "...\proposal.json" -ProjectFile "...\Proyecto_V20.ap20" `
  -Profile write -Apply -AcknowledgeWriteProfile       # aplicación real
```

Cada ejecución deja `workflow.json` con estado, perfil, artefactos y la afirmación explícita de
que corresponde a la operación realizada. El preview no conecta con TIA; la aplicación real se
delega en `Invoke-TiaSclProposalApply.ps1`, que adquiere el lease MCP mediante el runner de
secuencias y mantiene los gates de backup, proyecto exacto, compilación y guardado.

---

## `Migrate-Examples.ps1`

```powershell
.\Migrate-Examples.ps1              # todos los pendientes
.\Migrate-Examples.ps1 -Only iot    # solo los que casen con 'iot'
.\Migrate-Examples.ps1 -SkipCompile # inventario rápido, sin compilar
```

Por proyecto: abrir (**migra solo** vía `OpenWithUpgrade`) → árbol → compilar → inventariar →
guardar → cerrar.

- Salta los que ya tienen su carpeta `<nombre>_V20` al lado. Reabrir un `.ap16` ya migrado
  crearía un segundo `_V20`.
- El detalle crudo va a `70-runs\migracion-<fecha>\`: un `.tree.txt` y un `.summary.json` por
  proyecto, más un `resumen.json`.
- Tolera fallos: si un proyecto revienta, lo anota y sigue.

⚠️ **Detección de PLCs por heurística.** Saca los `softwarePath` buscando `PlcSoftware: <nombre>`
en el árbol. Funciona en proyectos de un nivel; en un PC station, donde la ruta real es
`PC-System_1/Software PLC_1`, habría que componerla. Si un proyecto sale con 0 PLCs, mira su
`.tree.txt`.

---

## `Export-Sources.ps1`

```powershell
.\Export-Sources.ps1                                    # todos los *_V20
.\Export-Sources.ps1 -ProjectPath "...\X_V20\X_V20.ap20"
```

Compila (obligatorio: TIA no exporta objetos inconsistentes) y exporta a
`<ejemplo>\src\` con `ExportPlcAsSourceTree`.

El informe separa **`.s7dcl`** de **`.xml`**. Esa proporción es el dato que importa: los `.s7dcl`
diffean en git, los `.xml` no.

---

## `Invoke-TiaStandardsSweep.ps1`

```powershell
.\Invoke-TiaStandardsSweep.ps1
.\Invoke-TiaStandardsSweep.ps1 -ProjectPath "...\\Proyecto_V20.ap20"
```

Abre cada proyecto V20 de `50-examples`, obtiene el árbol, el resumen y los bloques con el
perfil read de `tia-inspect`, y ejecuta `Check-TiaStandards.ps1` sobre las fuentes `src` que ya
existen. **No compila, no guarda, no importa y no modifica proyectos.** Los resultados se dejan
en `70-runs\\standards\\sweep-<fecha>\\`.

Los ejemplos pueden tener hallazgos intencionados: por defecto el barrido los registra sin
fallar; usa `-FailOnFindings` si quieres convertirlos en código de salida 1.

---

## `Stop-TiaPortal.ps1`

```powershell
.\Stop-TiaPortal.ps1
.\Stop-TiaPortal.ps1 -Force    # aunque haya un proyecto abierto
```

✅ **Verificado: `Disconnect` no cierra TIA Portal.** El proceso sigue vivo con ~1,3 GB, y cada
`OpenProject` con migración puede dejar uno nuevo.

Antes de cerrar nada consulta por MCP si hay un proyecto abierto y se niega si lo hay. Intenta
`CloseMainWindow` primero, pero **una instancia headless no tiene ventana principal**, así que
casi siempre acaba forzando. Es normal.

> No la cierres entre tarea y tarea: una instancia caliente hace que `Connect` tarde **0,3 s en
> vez de 28 s**. Ciérrala al terminar la sesión de trabajo.
