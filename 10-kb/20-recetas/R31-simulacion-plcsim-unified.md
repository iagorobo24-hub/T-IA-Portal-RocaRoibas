# R31 — Simular el PLC con S7-PLCSIM y arrancar la HMI Unified en TIA V20

> Qué hace falta para que un PLC y una HMI Unified **simulados** funcionen en TIA Portal V20,
> medido el 2026-10-22 con `DEMO-Cinta01`, incluidos los cuatro bloqueos que aparecen en orden y
> los mensajes exactos de cada uno.

## Requisito que se comprueba al principio

**La simulación de una HMI Unified usa el WinCC Unified Runtime instalado, y ese runtime tiene que
ser de la misma versión que el TIA Portal del proyecto.** No basta con "que haya un runtime
instalado".

Medido en esta máquina el 2026-10-22:

| Qué | Versión |
|---|---|
| TIA Portal del proyecto | **V20** |
| Runtime Unified instalado (`SIMATIC WinCC Unified PC V19`) | **V19** |
| Formato de runtime que genera el proyecto HMI | `0_Chrom_20.0.0.0_Rdf_20.0.0.0` |
| `GfxRTS.exe` instalado | `500.30.8901.3` |

Con esa mezcla, la simulación de la HMI **no arranca**: TIA intenta la conexión online con el
dispositivo HMI `HM_RT_1`, agota 26 s y cancela. Ver
[ADR-017](../../00-meta/decisiones/ADR-017-runtime-unified-igual-version.md).

Para simular una HMI de un proyecto V20 hace falta **`SIMATIC WinCC Unified PC V20`** (el runtime
V20 del Support Center de Siemens). Con el runtime V19, la simulación del PLC sí funciona; la de la
HMI no.

---

## Los cuatro bloqueos, en el orden en que aparecen

### 1. `Enable Simulation Support (0626:000013)` — la propiedad que V20 deja desactivada

Síntoma: el botón de simulación no hace nada visible, o el PLC simulado arranca pero sin bloques.

> The blocks contained in this project cannot be simulated with S7-PLCSIM. Do you want to enable the
> 'Support simulation during block compilation' option in the project properties?

Es una **propiedad del proyecto**, y **V20 la deja desactivada por defecto**. Sin ella, TIA no
compila los bloques con soporte de simulación y el PLC virtual se queda *"PLC sin configurar"*.

**Arreglo:** botón `OK` del diálogo. Queda activada en las propiedades del proyecto (protección).

### 2. `Enable Simulation Support (0626:000002)` — el aviso de interfaces online

> Starting simulation will disable all online interfaces.

Informativo. Botón `OK` y seguir.

### 3. `Establish connection to device` — el certificado autofirmado del PLC virtual

> **"PLC_1" might not be a trustworthy device.**
> - The IP address of the device does not match the addresses of the associated certificate.
> - The device uses an unknown, self-signed certificate.

Botones: `Display certificates` / **`Connect`** / `Abort connection`.

**Este es el bloqueo silencioso**: si nadie responde, la descarga **se cancela sola a los ~70
segundos** y el panel de salida solo muestra `Action cancelled before download`. No dice nada del
certificado.

**Arreglo:** `Connect` (el PLC virtual es de fiar). Con eso el panel registra
`Connected to PLC_1, via address IP=192.168.0.1`.

### 4. El destino de descarga guardado en el proyecto

Después de aceptar el certificado aparece:

> The target PLC_1 in the offline project is different from the target in the online project (addr…)

y la conexión termina. `GetOnlineState` responde:

```json
{"State":"Incompatible","IsOnline":false,"IsReachable":false,
 "Message":"'PLC_1' online but firmware/config mismatch. Download required."}
```

**Causa:** el proyecto guarda un *destino de descarga* (una CPU virtual de una sesión anterior, con
otra dirección) que ya no corresponde al simulador actual. La IP del proyecto sí es la buena
(`GetDeviceIpAddress` → `192.168.0.1`, la que usa el Softbus de S7-PLCSIM).

**Arreglo:** rehacer la descarga por la GUI con el simulador activo, para que TIA reescriba el
destino; o borrar el destino guardado en `Online access`.

---

## Orden de operaciones que funciona

1. Activar **Support simulation during block compilation** (diálogo `0626:000013` → `OK`).
2. Seleccionar la **CPU** en el árbol de proyecto → botón **Start simulation** de la barra.
   - TIA compila y arranca `S7PLCSIMV20.exe`:
     `--family=S71500 --projectname="DEMO-Cinta01" --mlfb="6ES7 513-1AM03-0AB0…"`.
   - Aceptar `0626:000002` (`OK`).
   - Aceptar `Establish connection to device` → **`Connect`**.
3. Verificar con la API (modo *attach*, no destructivo):

   ```powershell
   Invoke-McpToolSequence.ps1 -ExecutablePath <TiaMcpServer.exe> `
       -Arguments '--tia-major-version 20 --profile lite --logging 1' -Calls @(
       @{ name='Connect' },
       @{ name='AttachToOpenProject'; args=@{ projectName='DEMO-Cinta01' } },
       @{ name='CallTool'; args=@{ name='GetDeviceIpAddress';   argumentsJson='{"devicePath":"PLC_1"}' } },
       @{ name='CallTool'; args=@{ name='GetOnlineState';       argumentsJson='{"softwarePath":"PLC_1"}' } },
       @{ name='Disconnect' })
   ```

   `GetDeviceIpAddress` → `192.168.0.1` (coincide con el Softbus del simulador).
4. Seleccionar la **HMI** en el árbol → botón **Start simulation**.
   - Con runtime Unified de la misma versión: el runtime arranca y muestra la pantalla.
   - Con runtime de otra versión: `Start downloading to device` → `HM_RT_1` →
     `Online connection to HM_RT_1 failed` a los 26 s → `Action cancelled before download`.

## Notas de la GUI (medidas)

- Los diálogos de TIA son WPF: **`mouse_event` los ignora, `SendInput` funciona** (ver
  [R27](R27-automatizacion-ui-tia.md)).
- El botón de simulación de la barra es un **conmutador**: pulsarlo con la simulación ya activa la
  **detiene**. Por eso "volver a pulsar" no reintenta nada.
- La **UI web de S7-PLCSIM V20** (`http://localhost:8101`) muestra el estado real de la instancia
  (`RUN/STOP`, `PLC sin configurar`, IP de X1) y es la única forma fiable de verlo sin la ventana
  delante.

## Qué queda fuera de esta receta

- La **descarga por API** al PLC simulado: `CheckDownloadReadiness` devuelve `downloadRouteCount: 0`
  porque el Softbus de S7-PLCSIM no es una ruta de red que vea el `DownloadProvider` de Openness.
  Con PLCSIM Advanced (que publica una interfaz TCP/IP) sí hay rutas.
- La **simulación 1 hora sin licencia**: el runtime Unified sin licencia avisa cada 10 minutos y
  funciona igual. No hace falta comprar nada para verificar.

---

## Actualización 2026-10-22 — Primer ensayo real con skills 	ia-plcsim-acceptance / 	ia-hmi-screen

### Resumen del día
- **Proyecto**: DEMO-Cinta01 (CPU S7-1513, IP 192.168.0.1, HMI Unified HMI_RT_1).
- **Entorno**: TIA V20 (PID 30048), PLCSIM V20, WinCC Unified Runtime V19 (mismatch).
- **Evidencia**: $run\ (JSONs 01..21, PNGs ui/22..33).

### Lo que funcionó
1. **Reinicio limpio de TIA** (PID 28328 → 30048): el TIA anterior tenía shell muerta (menús/toolbar/F10/atajos no respondían tras attach/detach MCP repetidos). El TIA fresco tiene tiles, árbol, menú Online vivos.
2. **MCP OpenProject(path=...)** abre proyecto; AttachToOpenProject(projectName) adjunta a ventana abierta. **Argumento es path (no projectPath)**.
3. **CompileSoftware("PLC_1")** → Success (0 err / 0 warn).
4. **CheckDownloadReadiness("PLC_1")** → eady=true, 5 rutas, incluye Siemens PLCSIM Virtual Ethernet Adapter.
5. **GetDeviceIpAddress("PLC_1")** → 192.168.0.1 (X1) ✓.
6. **PLCSIM sin args + Ctrl+1** crea instancia Instance_1 (S7-1500, X1:192.168.0.1). Capturas 22, 29.
7. **Power ON instancia** (botón ⏻) → arranca (toast "Arrancando Instance_1"). Capturas 24, 25, 28, 30.
8. **HMI Runtime arranca**: menú Online → HMI → Start runtime → procesos Siemens.Runtime.HmiUnified.Client (PID 6960) + ControlCenter (PID 10152). Capturas 31, 32.

### Bloqueo PLC: Softbus sin IP
- Adaptador Windows Ethernet 2 (Siemens PLCSIM Virtual Ethernet Adapter) con IP **192.168.0.100/24** asignada vía 
etsh/PowerShell admin.
- **Pero el driver NDIS no propaga la IP al stack Softbus**: registro HKLM\...\0001 muestra IPAddress: vacío; CheckDownloadReadiness y DownloadToPlc ven ruta PLCSIM [no IP] → 1 X1.
- **Causa raíz**: MSI del mediodía (11:57-12:08) reconfiguró stack (WinCC Unified PC V20 + plugins AWB Host); Event 1038 "requiere reinicio" a las 11:57; reboot ~12:20. El bindeo NDIS quedó pendiente.
- **Solución**: **reiniciar la máquina** (fuerza rebind del driver). Sin reboot, la descarga a PLCSIM no conectará.

### Bloqueo HMI: Runtime versión incorrecta
- TIA V20 + Runtime Unified V19 instalado (GfxRTS.exe 500.30.8901.3).
- **La simulación de HMI Unified exige runtime de la misma versión que TIA** (ADR-017). Con V19 no arranca pantalla; el proceso Client sube pero no hay interfaz web expuesta en puertos estándar.

### Hallazgos de GUI/Interacción (para R27/playbook)
- **Toolbar TIA V20 NO tiene icono "Start simulation"**: la vía es menú Online → Simulation ▶ → Start (Ctrl+Shift+X).
- **Tooltip de iconos requiere**: clic de activación previo en la barra + ratón quieto ~3.5 s.
- **Posiciones toolbar (monitor 1920px offset)**:
  - (2586,71) = "Accessible devices"
  - (2610,71) = **"Start CPU"** (NO "Start simulation")
  - (2632,71) = "Stop CPU"
- **Regla de selección**: con PLC_1 seleccionado en el árbol → item "Start" del menú Online está NEGRO (habilitado); si se pierde selección → GRIS. Siempre re-clic en árbol tras activaciones.
- **PLCSIM args --projectname/--mlfb**: arrancan app con cabecera "DEMO-Cinta01" pero workspace inexistente en disco → instancia no se crea (botón + mudo). **Sin args + Ctrl+1** sí crea instancia.

### Próximos pasos
1. **Reboot máquina** → rebinde NDIS → reintentar DownloadToPlc (MCP) con instancia PLCSIM activa.
2. **Instalar WinCC Unified PC V20** para HMI simulation completa.
3. Tras reboot + runtime V20: cadena completa PLC + HMI en una sesión.


---

## Actualización 2026-10-23 — la descarga por API no es posible con el Softbus

**Contexto:** reinicio de máquina a las 07:09:34, TIA guardado/cerrado/reabierto (PID 23304), proyecto reabierto con `OpenProject` (08:02:21), `IsSimulationDuringBlockCompilationEnabled=true`, `CompileSoftware` OK y `CheckDownloadReadiness.ready=true`.

### Corrección a lo dicho el 2026-10-22

El reinicio **no arregla** el `PLCSIM [no IP]` de forma fiable. Hoy, con la máquina reiniciada y la IP publicada en la clave de clase del adaptador (`IPAddress=192.168.0.100`, `SubnetMask=255.255.255.0`, `Restart-NetAdapter` hecho), `CheckDownloadReadiness` sigue devolviendo:

```json
{"downloadRouteCount":1,
 "downloadRoutes":[{"pgPcInterface":"PLCSIM","pgPcAddresses":"","targetAddresses":""}]}
```

Y `DownloadToPlc` falla igual con **tres** orígenes de instancia distintos: instancia clásica por CDP, instancia clásica tras reiniciar TIA, e instancia de **PLCSIM Advanced creada desde su Panel de Control** (encendida, `192.168.0.1`). Forzando `targetIpAddress`:

> `No download route reaches target IP '192.168.0.1'. Available routes: PN/IE / PLCSIM [no IP] -> 1 X1`

**Conclusión firme:** el Softbus no es una ruta de red para el `DownloadProvider` de Openness. La descarga por API **solo** puede funcionar con PLCSIM Advanced en **TCP/IP**, y eso es lo que está roto en este equipo (`-48`).

### Estado real de PLCSIM Advanced (diagnóstico cerrado)

| Comprobación | Resultado |
|---|---|
| `SetNetworkMode(TCPIP_SINGLE_ADAPTER)` sin admin y con admin | `0xffffffd0` (`-48 SREC_COMMUNICATION_INTERFACE_NOT_AVAILABLE`) |
| Driver `plcsimlwf` | RUNNING, v102 (2024), binding enabled en `Ethernet 2` |
| Componente de red | `netcfg -q plcsim_ndislwf` → "está instalado"; reinstalado con exit 0 |
| `AdapterConfigurator.exe` (configura el switch) | **aborta con `-999999`**, sin ventana ni salida |
| `msiexec /fa` del MSI en caché (Driver64) | **se cuelga en `ADSStartup`** (abortado sin daño) |
| Instalador original V7 en el equipo | **no está** (en Descargas solo hay el ISO de WinCC Unified RT V20) |

`CommAdapter` sigue vacío en `HKLM\SYSTEM\CurrentControlSet\Services\plcsimlwf\Parameters`, que es justo lo que escribiría el AdapterConfigurator.

**Vía de arreglo:** reinstalar **PLCSIM Advanced V7 desde su instalador original**. La reparación por MSI cacheado no sirve.

### Lo que sí funciona hoy

La descarga por **GUI** de TIA (la de esta receta, secciones 1-4) sigue siendo el único camino verificado:

1. Seleccionar `PLC_1` en el árbol del proyecto (si no, el ítem *Start* sale gris).
2. **Online → Simulation → Start** (`Ctrl+Shift+X`). La toolbar de V20 **no** tiene icono de simulación.
3. Aceptar `0626:000002` (OK).
4. `Establish connection to device` → **Conectar**, y luego **Cargar** (marcar *Arrancar módulo*).

### Receta nueva: instancia de Advanced sin ratón (UI Automation)

El Panel de Control es WPF y expone UIA (TIA no: su shell WinForms devuelve 0 botones). IDs verificados: `HeaderSite` (**Toggle**), `UIAutPLCSIMAdv_InstanceInfoName` (Value), `UIAutPLCSIMAdv_InstanceInfoStartButton` (**Invoke**), `UIAutPLCSIMAdv_RunningInstancesPowerOnOffButton` (**Toggle**), `UIAutPLCSIMAdv_RunningInstancesUnregisterButton` (Invoke).

**Trampa:** la instancia nace con `ToggleState = On`; togglear "para encender" la **apaga**.

### Próximos pasos (2026-10-23)

1. Descarga por GUI (pasos de arriba) para dejar la demo y la evidencia.
2. Reinstalar PLCSIM Advanced V7 desde instalador original → volver a probar `tcpip-local`; si da `ready`, la descarga por API queda automatizada.
3. Instalar **WinCC Unified RT V20** desde `SIMATIC_WinCC_Unified_RT_V20_Second_Edition.iso` (Descargas) para el bloqueo HMI de ADR-017.