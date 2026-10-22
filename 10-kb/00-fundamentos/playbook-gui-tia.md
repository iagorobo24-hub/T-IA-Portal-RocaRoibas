# Playbook GUI — cómo opera el agente la interfaz gráfica de TIA en esta máquina

> Documento operativo. El marco general (qué herramienta usar en cada caso y por qué) está en
> [`tia-interfaz-y-computer-use.md`](tia-interfaz-y-computer-use.md); este playbook traduce el
> marco a pasos listos para ejecutar, con los candados que evitan los fallos medidos durante la
> sesión de simulación Unified de 2026-10-22 (proyecto `DEMO-Cinta01`, commit `3a4693b`).
>
> En una frase: **Openness para lo que el perfil exponga; GUI solo para lo que Openness no da;
> y ningún clic sintetizado sin candado de hit-test antes de pulsar.**

---

## 1. Jerarquía de herramientas (siempre, en este orden)

| Nivel | Herramienta | Cuándo |
|---|---|---|
| 1 | **MCP / Openness** (`30-tools/scripts/Invoke-McpToolSequence.ps1`, lease `Local\TIA-Claude-McpSession`) | Todo lo que el perfil exponga: leer, compilar, guardar, `GoOffline`, `AttachToOpenProject`, `DownloadToPlc`… |
| 2 | **Candado de clic** (`30-tools/tia-ui/Invoke-TiaGuiClick.ps1`) | Un clic aislado en la GUI cuando no hay herramienta MCP equivalente (diálogos, menús contextuales, botón de inicio de simulación). |
| 3 | **Motor de UI** (`30-tools/tia-ui/Invoke-TiaUiEngine.ps1`) | Flujos con varios pasos sintetizados (teclado + clic + captura), cuando el nivel 2 no llega. |
| 4 | **UI Automation** (`Get-TiaUiAutomationInventory.ps1`) | Solo *inventario* de controles, nunca una mutación. |
| 5 | **Humano** | UAC, ficheros del sistema, cualquier duda razonable. |

Nada de `mouse_event`: todo `SendInput`. TIA es WPF y esa es la única inyección probada.

---

## 2. Reglas de esta máquina (cada una sale de un fallo recorrido y medido)

1. **La ventana objetivo tiene que estar en el escritorio virtual activo y en primer plano.**
   Antes de pulsar, `WindowFromPoint` debe devolver el PID esperado.
2. **No buscar la ventana cambiando de escritorio virtual.** El 2026-10-22, unos cuantos saltos con
   `Win+Ctrl+Flecha` dejaron el fondo de todos los escritorios en negro (bug de DWM en Win11; ver
   [`50-errores/README.md`](../50-errores/README.md)). Si la ventana no está en el escritorio
   activo, se para y se le avisa al usuario; nunca se resuelve a oscuras.
3. **El topmost no persiste.** Otro proceso al primer plano lo desecha: cada clic debe re-aplicarlo
   (el candado lo hace con `-RaiseTopmost`) y, si conviene, retirarlo después (`-RemoveTopmostAfter`).
4. **Las coordenadas no viajan entre sesiones.** Se recalculan al inicio de cada sesión y se dejan
   registradas en el JSON de evidencia como *coordenadas de esa sesión y esa disposición*. Nunca se
   citan como verdades generales.
5. **Punto = PID.** Si el hit-test devuelve otro proceso (explorador de archivos, Excel, el
   navegador…), el clic no se envía. El 2026-10-22 un clic lanzado creyendo que iba a TIA cayó
   sobre Excel; con el candado habría abortado.
6. **Nombres de fichero reservados.** El path `30-tools/tia-ui/Invoke-TiaUi.ps1` está bloqueado
   a nivel de sistema en esta máquina (*Acceso denegado*, cualquier contenido). El motor vive en
   `Invoke-TiaUiEngine.ps1` y el candado en `Invoke-TiaGuiClick.ps1`.
7. **Evidencia por paso:** captura antes, captura después (PNG) y registro
   JSON (`-EvidencePath`). Un paso sin evidencia no pasó.
8. **Una mutación por paso.** Menú → opción → captura → verificar → siguiente. Nada de
   encadenar cuatro clics y mirar el resultado.
9. **Las ventanas del usuario mandan.** Con Excel, SEE u otra app del usuario delante, si el
   objetivo queda tapado, se para y se consulta al usuario: **no se eleva, no se minimiza, no se
   cambia nada** sin consentimiento. Fue el bloqueo real de la tarde del 2026-10-22.
10. **Los diálogos de sesión adjunta se resuelven en TIA** (por ej. `Establish connection to
    device → Connect` del certificado del PLC virtual); su resolución se documenta en la
    evidencia de la sesión. Detalle en [R31](../20-recetas/R31-simulacion-plcsim-unified.md).

---

## 3. El ritual de clic (nivel 2)

```text
(1) Medir     ¿quién es la ventana objetivo y dónde está? PID + rect + título.
              Captura de la pantalla para confirmar contenido. TIA maximizada (preferencia del
              usuario) y en su monitor habitual.
(2) Localizar el elemento exacto que hay que pulsar, contando con el estado real del árbol o
              la vista. Si el elemento no es visible: resolverlo antes (expandir, scroll,
              abrir la vista correspondiente). Nunca pulsar a la ciega.
(3) Candado   .\Invoke-TiaGuiClick.ps1 -X <x> -Y <y> -ExpectedPid <pid> -InspectOnly
              Debe devolver OK y el PID del paso (1). Si da MISMATCH: resolver, no insistir.
(4) Pulsar    lo mismo sin -InspectOnly, con -RaiseTopmost y -EvidencePath hacia 70-runs/.
              Un solo clic, Left o Right según menú.
(5) Verificar captura después (-AfterShot) + confirmación cruzada del efecto: menú abierto,
              diálogo presente, checkbox marcado, estado MCP (GetOnlineState, GetState…).
              TIA no repinta al instante: espera ≥1 s entre pasos; 2-4 s si expandió un nodo.
(6) Registrar el JSON y los PNG van a 70-runs/<fecha>-<tarea>/ui/. Resumen al usuario:
              qué paso, qué se esperaba, qué se vio.
```

Flujo completo de menú contextual: candado `InspectOnly` → clic derecho con `-RaiseTopmost` →
captura (`AfterShot`) que confirme el menú → candado sobre la opción del menú (recalculada) →
captura → verificación en MCP. Si el menú no se abrió, se repite el ciclo desde (2), no a ciegas.

---

## 4. Anclajes de la sesión 2026-10-22 (referencia, no plantilla)

TIA V20, escala 100%, DEMO-Cinta01 abierto, maximizado en el monitor derecho (1912,2 → 3848,1050):

| Elemento | Coordenada | Condición de validez |
|---|---|---|
| Nodo `PLC_1` en el árbol de proyecto | `2022,249` | solo con esa ventana, ese escalado y ese estado del árbol |
| Otras posiciones del panel y de HMI | recalcular | nunca recortar de aquí |

⚠ Cambio de monitor, resolución, escala o estado del árbol ⇒ esas coordenadas **no valen**. El
ritual de la sección 3 las recalcula. Usarlas sin comprobar es el equivalente exacto a pinchar
clic sobre Excel.

### Herramientas vivas

| Herramienta | Path | Qué hace |
|---|---|---|
| **Candado de clic** | `30-tools/tia-ui/Invoke-TiaGuiClick.ps1` | clic con hit-test obligatorio + topmost opcional + evidencia JSON + captura PNG; `InspectOnly` para diagnosticar un punto sin pulsar |
| **Motor de flujo** | `30-tools/tia-ui/Invoke-TiaUiEngine.ps1` | secuencias largas con SendInput (el que abrió un proyecto GUI de principio a fin, ver R27) |
| **Inventario UIA** | `30-tools/scripts/Get-TiaUiAutomationInventory.ps1` | solo lectura de controles por PID y título |
| **Scripts temporales** (clicfiable, clic-simple, vdesktop, mbar2…) | en `%LOCALAPPDATA%\Temp\opencode\` | instrumentos de calibración de la sesión del 2026-10-22; su funcionalidad estable se va absorbiendo en el candado |

---

## 5. Qué NO hace la GUI (y por lo que se vuelve a MCP)

| Acción | Herramienta correcta |
|---|---|
| Leer bloques, tags, árboles | MCP `tia-inspect` |
| Compilar / guardar / exportar | MCP (0/0 con barrera `SaveGuarded`) |
| Cambiar a online / descargar a CPU virtual | MCP `GoOffline` + `DownloadToPlc` en sesión adjunta |
| Confirmar destino de descarga | GUI (visual, `CPU-1500 Simulation`) + prechecks del runner |
| Arrancar/parar PLCSIM Advanced | adaptador de `30-tools/plcsim/`, no el panel a golpe de clic |

## 6. Cómo se cierra una sesión con UI

1. TIA queda **como estaba** (maximizada, mismo monitor, mismo escritorio).
2. Lo que se haya quitado el topmost a ventanas ajenas, se devuelve.
3. MCP `GetState` final, y en la conversación se dice qué estado quedó.
4. No se matan procesos de simulación sin cerrar antes su ventana gráfica (Control Panel, TIA).
5. No se cambia de escritorio virtual. Nunca.
