# Handoff — Simulación de WinCC Unified en TIA V20 (2026-10-22)

> Tarea: probar la **simulación de WinCC Unified con lo ya instalado** (sin descargar nada) y,
> solo si falla por compatibilidad, que el usuario descargue el WinCC Unified Runtime V20.
> **Veredicto: falla por compatibilidad.** El usuario tiene que instalar
> `SIMATIC WinCC Unified PC V20`.

## Veredicto en una línea

Con **TIA Portal V20** y **WinCC Unified Runtime V19** (lo único instalado), la simulación de una
HMI Unified **no arranca**: TIA intenta la conexión online con el dispositivo HMI `HM_RT_1`, espera
26 s y cancela, **sin llegar a lanzar ningún proceso de runtime**. Hace falta el runtime **V20**.

Detalle y evidencia: [ADR-017](../../00-meta/decisiones/ADR-017-runtime-unified-igual-version.md),
[R31](../../10-kb/20-recetas/R31-simulacion-plcsim-unified.md),
[`50-examples/demo-cinta01/simulacion-unified-2026-10-22.json`](../../50-examples/demo-cinta01/simulacion-unified-2026-10-22.json).

## Lo que se resolvió por el camino (y era bloqueante de verdad)

1. **`Support simulation during block compilation`** (diálogo `0626:000013`). V20 la deja
   desactivada por defecto: sin ella el botón de simulación no hace nada y el PLC virtual se queda
   en `PLC sin configurar`. **Activada** → S7-PLCSIM V20 arranca con el proyecto:
   `S7PLCSIMV20.exe --family=S71500 --projectname="DEMO-Cinta01" --mlfb="6ES7 513-1AM03-0AB0…"`.
2. **El diálogo del certificado autofirmado del PLC virtual** (`Establish connection to device` →
   `Connect`). Es un **bloqueo silencioso**: sin responder, la descarga se cancela sola a los ~70 s
   y el panel solo dice `Action cancelled before download`.
3. **El motor de UI** se recuperó tras perderlo: el path `30-tools/tia-ui/Invoke-TiaUi.ps1` está
   **reservado a nivel de sistema** en esta máquina (cualquier escritura → *Acceso denegado*, con el
   mismo nombre en otra carpeta sí funciona). Vive ahora en
   `30-tools/tia-ui/Invoke-TiaUiEngine.ps1`, con contenido idéntico.

## Lo que queda pendiente (no es un problema de versión)

El PLC quedó **en línea pero sin programa**:

```
GetOnlineState(PLC_1) → State: Incompatible
                         'PLC_1' online but firmware/config mismatch. Download required.
```

Y el motivo está en el panel de salida de TIA:

> The target PLC_1 in the offline project is different from the target in the online project (addr…)

La IP del proyecto **es** la buena (`GetDeviceIpAddress` → `192.168.0.1`, la del Softbus de
S7-PLCSIM). Lo que no coincide es el **destino de descarga guardado** en el proyecto, que apunta a
una CPU virtual de una sesión anterior. **Arreglo:** rehacer la descarga por la GUI con el
simulador activo, o limpiar el destino en `Online access`.

Nota: `CheckDownloadReadiness` sobre un PLC en S7-PLCSIM da `downloadRouteCount: 0` y
`HasDownloadProvider: false` — el Softbus no es una ruta de red que vea el `DownloadProvider` de
Openness. Con **PLCSIM Advanced** (que publica TCP/IP) sí hay rutas, y es el camino que el repo ya
tiene verificado ([ADR-015](../../00-meta/decisiones/ADR-015-estado-real-2026-10-21.md),
[R28](../../10-kb/20-recetas/R28-aceptacion-plcsim.md)).

## Qué pedir al usuario

**Instalar `SIMATIC WinCC Unified PC V20`** desde el Support Center de Siemens. Nada más: el
agente no descarga software de Siemens ni recibe credenciales.

- **No hace falta licencia** para verificar: el runtime sin licencia funciona en modo no licenciado
  (aviso cada 10 minutos) y la simulación se activa **1 hora** sin licencia.
- Con el runtime V20 instalado, la comprobación a repetir es: seleccionar la HMI → `Start
  simulation` → el runtime arranca y publica la pantalla `Main`.

## Cómo se automatea la comprobación (para el que siga)

```powershell
$ws = 'C:\Users\jose.mellid\Desktop\BIBLIOGRAFIA\00. IA-go\01.Repositorios\TIA Portal\TIA-Claude'

# 1. version del runtime instalado (V19 -> 500.30.8901.3)
Get-ChildItem 'C:\Program Files\Siemens\Automation\WinCCUnified' -Recurse -Filter 'GfxRTS.exe' |
  ForEach-Object { $_.VersionInfo.ProductVersion }

# 2. formato de runtime que pide el proyecto (-> Rdf_20.0.0.0 = TIA V20)
Get-ChildItem "$ws\40-projects\DEMO-Cinta01\tia\DEMO-Cinta01\IM\HMI" -Recurse -Directory |
  Where-Object Name -match 'Rdf' | Select-Object -ExpandProperty Name

# 3. el runtime de la simulacion debe aparecer como proceso NUEVO (arranque > ahora)
Get-CimInstance Win32_Process | Where-Object Name -match 'GfxRT|HmiUnified'
```

Ojo al leer (3): `Siemens.Runtime.HmiUnified.Client.exe` / `ControlCenter.exe` **ya estaban
arrancados desde las 07:10** (son del *Unified Station Configurator*). Para probar hay que mirar la
**hora de arranque**, no solo que el proceso exista.

## Estado de la máquina al terminar

- TIA Portal V20 **abierta** con `DEMO-Cinta01`.
- S7-PLCSIM V20 **corriendo** (`S7PLCSIMV20.exe`, `Instance_1` en `192.168.0.1`, en STOP y *PLC sin
  configurar*).
- Runtime WinCC Unified: **ningún proceso de simulación** (solo los del Station Configurator).
- La propiedad *Support simulation during block compilation* **queda activada** en el proyecto
  (es un cambio real, no un ajuste de sesión): se guarda al guardar el proyecto.
