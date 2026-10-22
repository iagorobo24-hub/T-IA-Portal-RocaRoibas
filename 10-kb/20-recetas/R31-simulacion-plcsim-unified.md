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
