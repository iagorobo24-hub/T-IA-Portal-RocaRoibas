# R27 · Automatización de la interfaz de TIA Portal

> Cómo pilotar TIA Portal V20 desde un agente sin depender de la vista humana: UIA donde
> TIA se expone, OCR de Windows donde no, y entrada sintética para el resto.

## Por qué existe

Openness (la API de TIA) cubre el **contenido** del proyecto, no la **interfaz**. Para lo que
solo existe en la GUI —el diálogo *Extended download to device*, el *Load preview*, el buscador
de destinos— hace falta automatizar la ventana. Esta receta documenta el motor
`30-tools/tia-ui/Invoke-TiaUi.ps1` y, sobre todo, **qué expone TIA V20 y qué no**, medido.

## Qué expone TIA V20 (medido el 2026-10-21)

| Superficie | UIA | Notas |
|---|---|---|
| Ventana principal | **Sí** | `AutomationId=ApplicationFrame`, clase `WindowsForms10.Window.8...` |
| Portal (pantalla de inicio) | **Sí, todo** | `m_OpenButton`, `m_BrowseButton`, `m_RemoveButton`, `PortalStartOpen/New/Migrate/Close`, `PortalStartWelcome`, `PortalStartFirstSteps`, `Grid-Control` con las filas de proyectos recientes (`1:Project`, `1:Path`, `1:LastChange`), `ContextNavigator.GoToProjectView.Title` |
| Pestaña *Project view* | **Sí** | es un `ListItem` con id `264348` |
| Árbol de proyecto | **No** (los ítems) | el panel es `NavigationTreeHostFrame`, un `Pane`; no expone `TreeItem` |
| **Ribbon** (pestañas y botones) | **No** | hay que leerlo por OCR |
| **Menú contextual del árbol** | **Sí** | `WindowsForms10.Window.808...`, nombre `ContextMenu`, con los **nombres internos de Siemens**, p. ej. `...LoadService.LoadCommandsUI:MenuItemDownload` |
| Diálogos modales (p. ej. *Extended download to device*) | **Sí** | `Button`, `ComboBox`, `List`, `Text` con `AutomationId` y `Name` |

Conclusión práctica: **el menú contextual y los diálogos son la vía limpia; el árbol y el ribbon
solo se tocan por OCR.**

## El motor: `30-tools/tia-ui/Invoke-TiaUi.ps1`

```powershell
Invoke-TiaUi.ps1 -Action ListWindows                     # ventanas del escritorio
Invoke-TiaUi.ps1 -Action Dump      -ProcessId 11856     # árbol UIA completo
Invoke-TiaUi.ps1 -Action Find       -ProcessId 11856 -Text 'PLC_1'
Invoke-TiaUi.ps1 -Action ClickText  -ProcessId 11856 -Text 'Project view'
Invoke-TiaUi.ps1 -Action RightClickText -ProcessId 11856 -Text 'PLC_1'
Invoke-TiaUi.ps1 -Action ClickId    -ProcessId 11856 -AutomationId 'm_OpenButton'
Invoke-TiaUi.ps1 -Action SetText    -ProcessId 11856 -AutomationId 'X' -Value 'texto'
Invoke-TiaUi.ps1 -Action Ocr        -ProcessId 11856     # lectura con coordenadas
```

### Piezas que no son evidentes

| Tema | Decisión | Por qué |
|---|---|---|
| **Captura de pantalla** | `PrintWindow` por ventana, **nunca** `CopyFromScreen` | `CopyFromScreen` falla en la sesión del agente (*"Object is currently in use elsewhere"*: el DC de pantalla no es accesible). `PrintWindow` renderiza la ventana concreta. |
| **Captura obsoleta** | `PrintWindow` devuelve el frame cacheado; `RedrawWindow` **no** lo invalida (WPF) | la única forma de repintar de verdad es **minimizar + restaurar** la ventana (`-ForceRepaint`). Pero eso reinicia el contexto de foco: hay que **reactivar la ventana después de capturar** y antes de clicar. |
| **Foco** | `AttachThreadInput` al hilo del primer plano + `BringWindowToTop` + `SetForegroundWindow` | `SetForegroundWindow` a secas se deniega cuando el proceso llamante no es el del primer plano. |
| **Z-order** | `SetWindowPos(HWND_TOPMOST)` temporal mientras se clica | otras aplicaciones (p. ej. SEE Electrical) cubren la zona y el clic caería en ellas. `WindowFromPoint` sirve para **verificar** a quién pertenece el punto. |
| **Clics** | `SendInput` (no `mouse_event`) | `mouse_event` es la vía legacy y algunos controles WPF la ignoran. |
| **OCR** | Windows OCR (`Windows.Media.Ocr`), idioma `es-ES` | disponible en el host; devuelve **texto con bounding box**, que es lo que permite clicar por etiqueta. |
| **OCR tolerante** | se normaliza el texto (se quitan separadores) y se mapean confusiones (`I`→`1`, `O`→`0`, `S`→`5`…) | el mismo rótulo se segmenta distinto en cada pasada (`PLC_1` / `PLC_I` / `_J Age ntDe mo_V20.a p20`). |
| **Menú contextual** | se abre con clic derecho y **se lee con UIA** | es una ventana propia; no aparece en los píxeles de la ventana madre. Y se cierra en cuanto otro proceso toma el foco: **clic y lectura deben ir en el mismo proceso**. |
| **Cultura** | se fuerza `InvariantCulture` | el locale del host usa coma decimal y `[int]` sobre `"8,5"` revienta. |

## Receta: abrir un proyecto en TIA desde cero

Probado de principio a fin:

1. `Start-Process 'C:\Program Files\Siemens\Automation\Portal V20\Bin\Siemens.Automation.Portal.exe'`
2. `-Action ClickId -AutomationId 'm_OpenButton'` tras seleccionar la fila `1:Project` del grid
   de proyectos recientes (o `-Action ClickId -AutomationId 'm_BrowseButton'` para ruta explícita)
3. `-Action ClickId -AutomationId '264348'` → cambia a la **vista de proyecto**
4. `-Action Ocr` → el árbol se lee (`AgentDemo_V20`, `PLC_1`, `EI 1513-1 PN`)

## Lo que NO se ha podido automatizar

El **clic derecho sobre un ítem del árbol** no abre el menú contextual de forma fiable desde la
automatización: el clic sí llega a TIA (verificable con `WindowFromPoint`, que devuelve el PID de
TIA) pero el menú no aparece. Se ha probado con `mouse_event` y con `SendInput`, con y sin
`topmost`, con y sin repintado forzado, y con la ventana en el monitor principal y en el
secundario. El menú **sí** se ").documentó" cuando se consiguió: expone
`...LoadCommandsUI:MenuItemDownload`.

**Alternativa recomendada**: pedir **un único clic humano** en el ítem del árbol (el
clic derecho y elegir *Descargar a dispositivo*) y **seguir a partir de ahí**: el diálogo
*Extended download to device* sí está expuesto a UIA (botones, combo de interfaz PG/PC, lista de
destinos), de modo que a partir de ahí la cadena se puede automatizar entera.

## Relación con la descarga a PLCSIM

El camino de **Openness** (`DownloadToPlc`) no resuelve el destino en esta máquina: la interfaz
PG/PC se anuncia como `[no IP]` porque la herramienta *Set PG/PC interface* de **Siemens
Automation Tools** no está instalada y el almacén de la OAM (`Simatic OAM\data\LogDevices\*.xml`)
no guarda ninguna dirección para las interfaces TCP/IP. La GUI sí lo resuelve porque su
búsqueda de destino es una difusión DCP que no necesita dirección previa.
