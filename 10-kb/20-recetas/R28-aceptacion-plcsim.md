# R28 · Aceptación en PLCSIM sin humano en el bucle

> Cómo ejecutar el protocolo de comportamiento de un bloque sobre una CPU virtual de
> PLCSIM Advanced desde el agente, con las cuatro condiciones que la API impone.

## Las cuatro condiciones

Ninguna es evidente y **las cuatro** hacen falta a la vez. Se midieron el 2026-10-21 sobre
`FB_AlarmLatch` (TIA Portal V20, PLCSIM Advanced V7.0, CPU 1513-1 PN FW V3.0).

| # | Condición | Qué pasa si no se cumple |
|---|---|---|
| 1 | La sesión Openness va **adjunta al TIA abierto** (`AttachToOpenProject`), no aislada (`ConnectIsolated`) | `DownloadToPlc` → `Connect to module PLC_1 failed`, aunque la CPU virtual esté viva y respondiendo por S7 |
| 2 | **~100 s de margen** tras arrancar el Control Panel de PLCSIM Advanced | La primera descarga falla; la segunda, ya asentada la OAM, funciona |
| 3 | `IInstance::UpdateTagList()` antes de la primera lectura simbólica | `-47` `SREC_NOT_UP_TO_DATE`: la lista de etiquetas vive en memoria compartida y la puebla `UpdateTagList()`, que lee los tags del VPLC |
| 4 | Los tags se nombran **sin el prefijo de tabla** (`Active`, no `Agent_Signals.Active`) | `-4` `SREC_DOES_NOT_EXIST` |

La 3 y la 4 son propiedades de la **API de PLCSIM Advanced**, no del proyecto: el plan
original usaba el nombre cualificado que muestra TIA y por eso no resolví.

## Receta

```powershell
# 1. Control Panel de PLCSIM Advanced (lo publica en la OAM) y esperar a que asiente
Start-Process 'C:\Program Files (x86)\Siemens\Automation\PLCSIMADV\bin\Siemens.Simatic.PlcSim.Advanced.UserInterface.exe'
Start-Sleep -Seconds 100

# 2. Instancia virtual: el adaptador la registra, la enciende y la deja viva
#    (--transport tcpip-local exige una sesion elevada)
#    -> 30-tools/plcsim/bin/v7/tia-claude-plcsim-adapter.exe
#       --register-acceptance --name PLC_1 --cpu 1513 --transport tcpip-local
#       --ip 192.168.0.1 --mask 255.255.255.0
#       --interface "Siemens PLCSIM Virtual Ethernet Adapter"

# 3. Descarga y online, con la sesion ADJUNTA al TIA abierto
Invoke-McpToolSequence.ps1 -ExecutablePath 30-tools/mcp/tia-create/bin/v20/TiaMcpServer.exe `
  -Arguments '--tia-major-version 20 --profile full' -CallsJson $calls
#    calls: AttachToOpenProject(projectName) -> CompileSoftware -> DownloadToPlc -> GoOnline

# 4. Plan de comportamiento contra la instancia YA descargada
Invoke-PlcSimPlanOnExisting.ps1 -PlanPath <io-plan.json>
```

`Invoke-PlcSimPlanOnExisting.ps1` engancha la instancia con `CreateInterface` —no la registra,
no la apaga, no la da de baja— y ejecuta los pasos del plan comprobando las expectativas de
cada uno. Debe correr **elevado**: la API de PLCSIM Advanced no inicializa sin privilegios
(`InitializeCode = 0xFFFFFFFF` sin elevar).

## Modo `--plan-existing` del adaptador

`--plan-existing --name <instancia>` se engancha a una instancia ya registrada e informa, antes
de aceptar comandos, de:

- `tagListStatus` / `tagListUpdate` / `tagListNeedsUpdate`: estado de la lista de etiquetas.
- `tagCount` y `tags`: los nombres reales que la API resuelve, **sin** prefijo de tabla.

Esa lista es la forma barata de descubrir el formato de nombres sin adivinar.

## Modo `--register-acceptance` en TCP/IP

Con `--transport tcpip-local` la instancia se registra con `SetNetworkMode(TCPIP_SINGLE_ADAPTER)`
y queda enlazada a la NIC virtual de Siemens. El orden que impone el runtime:

1. `SetNetInterfaceMapping(IE1, <índice de la NIC>)` — con la instancia **parada**; la sobrecarga
   de **índice** es la fiable, la de nombre devuelve `-32` porque el nombre del OAM va
   entrecomillado.
2. `SetNetInterfaceBindings(0)` — solo comunicación local con el PC.
3. `PowerOn`.
4. `SetIPSuite(0, ip, máscara)` — con la instancia **corriendo**; si no, `-14`.

Y `ParseIp` tiene que rellenar `IPs[3 - n]`: la API guarda los octetos invertidos
(`IPs[3]` es el primero) y llenarlos en orden de texto entrega una dirección byte-reversed
que el runtime acepta con `0x0` y descarta en silencio.

## Caso especial: la IP de la NIC

La CPU virtual espera `192.168.0.1` y la NIC virtual de Siemens (`Ethernet 2`) necesita
`192.168.0.2/24`. Configurar la IP de la NIC exige una sesión elevada.

```powershell
New-NetIPAddress -InterfaceAlias 'Ethernet 2' -IPAddress 192.168.0.2 -PrefixLength 24
```

Para volver atrás: quitar esa dirección y dejar que la NIC vuelva a APIPA.
